"""5-stage Decision D9 tool execution pipeline with atomic confirmation resolution."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import timedelta
import json
import re
import time
from typing import Any, Optional

from pydantic import ValidationError
from sqlalchemy import and_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.base import generate_uuid, utc_now
from app.models.profile import Profile
from app.models.profile_session import ProfileSession
from app.models.tool_confirmation import ToolConfirmation
from app.models.tool_runtime_config import ToolRuntimeConfig
from app.services.scheduler.service import as_utc
from app.services.tools import adapters_productivity as prod_adapters
from app.services.tools.audit import record_tool_audit
from app.services.tools.policy import (
    compute_confirmation_fingerprint,
    evaluate_tool_policy,
    get_or_create_profile_tool_settings,
    get_or_create_runtime_config,
)
from app.services.tools.registry import TOOL_REGISTRY, ToolSpec
from app.services.tools.web_secret_store import read_web_search_api_key
from app.services.web.providers import fetch_web_page, search_web, weather_lookup
from app.services.web.ssrf_guard import SSRFBlockedError

CONFIRMATION_TTL_SECONDS = 120
_CONFIRM_PHRASE_RE = re.compile(r"^\s*(confirm|approve|proceed\s+with|execute)\b(.*)$", re.IGNORECASE)
_VAGUE_AFFIRMATION_RE = re.compile(r"^\s*(yes|yep|yeah|ok|okay|sure|go\s+ahead|do\s+it)[.!?\s]*$", re.IGNORECASE)


@dataclass
class ToolExecutionOutcome:
    """Normalized result emitted by the 5-stage deterministic D9 pipeline."""

    tool_name: str
    risk_tier: int
    provenance: str
    decision: str  # "ALLOW" | "CONFIRM" | "DENY"
    executed: bool
    outcome_status: str
    summary: str
    duration_ms: Optional[int] = None
    error_code: Optional[str] = None
    payload: dict[str, Any] = field(default_factory=dict)
    sources: list[dict[str, Any]] = field(default_factory=list)
    confirmation: Optional[ToolConfirmation] = None


def _summarize_target(spec: Optional[ToolSpec], args: dict[str, Any]) -> str:
    if spec is None:
        return "Blocked capability"
    for key in ("title", "label", "query", "location", "url", "task_id", "reminder_id", "alarm_id"):
        if key in args and args[key]:
            return str(args[key])[:200]
    return spec.name


async def _dispatch_narrow_adapter(
    *,
    db: AsyncSession,
    profile_session: ProfileSession,
    profile: Optional[Profile],
    runtime_config: ToolRuntimeConfig,
    tool_name: str,
    validated_args: dict[str, Any],
    profile_id: Optional[str] = None,
) -> dict[str, Any]:
    pid = profile_id or profile_session.profile_id
    if tool_name == "weather_lookup":
        return await weather_lookup(
            location=validated_args["location"],
            provider_name=runtime_config.weather_provider,
        )
    if tool_name == "web_search":
        api_key = None
        if runtime_config.web_search_provider in ("tavily", "brave"):
            api_key = read_web_search_api_key()
        return await search_web(
            query=validated_args["query"],
            max_results=validated_args.get("max_results", 5),
            provider_name=runtime_config.web_search_provider,
            searxng_base_url=runtime_config.searxng_base_url,
            api_key=api_key,
        )
    if tool_name == "web_fetch":
        return await fetch_web_page(url=validated_args["url"])
    if tool_name == "list_tasks":
        return await prod_adapters.run_list_tasks(db, pid, validated_args, profile=profile)
    if tool_name == "list_reminders":
        return await prod_adapters.run_list_reminders(db, pid, validated_args, profile=profile)
    if tool_name == "list_alarms":
        return await prod_adapters.run_list_alarms(db, pid, validated_args, profile=profile)
    if tool_name == "search_memories":
        return await prod_adapters.run_search_memories(db, profile_session, validated_args)
    if tool_name == "create_task":
        tz_name = (getattr(profile, "quiet_hours_timezone", None) or "UTC") if profile is not None else "UTC"
        return await prod_adapters.run_create_task(db, pid, validated_args, tz_name=tz_name)
    if tool_name == "update_task":
        return await prod_adapters.run_update_task(db, pid, validated_args)
    if tool_name == "delete_task":
        return await prod_adapters.run_delete_task(db, pid, validated_args)
    if tool_name == "create_reminder":
        return await prod_adapters.run_create_reminder(db, pid, profile, validated_args)
    if tool_name == "delete_reminder":
        return await prod_adapters.run_delete_reminder(db, pid, validated_args)
    if tool_name == "create_alarm":
        return await prod_adapters.run_create_alarm(db, pid, profile, validated_args)
    if tool_name == "delete_alarm":
        return await prod_adapters.run_delete_alarm(db, pid, validated_args)
    raise LookupError(f"Unsupported tool adapter '{tool_name}'.")


async def execute_tool_intent(
    *,
    db: AsyncSession,
    profile_session: ProfileSession,
    conversation_id: str,
    tool_name: str,
    arguments: Optional[dict[str, Any]],
    provenance: str = "EXPLICIT_USER",
    commit: bool = True,
) -> ToolExecutionOutcome:
    """Execute one model/user tool intent through stages 2-5 under DEFAULT DENY."""
    started = time.perf_counter()
    normalized_name = (tool_name or "").strip().lower()
    spec = TOOL_REGISTRY.get(normalized_name)
    risk_tier = spec.risk_tier if spec is not None else 2

    runtime_config = await get_or_create_runtime_config(db)
    profile_settings = await get_or_create_profile_tool_settings(db, profile_session.profile_id)
    profile = await db.get(Profile, profile_session.profile_id)

    # Stage 2: Strict typed request validation before policy outcome
    validated_args: Optional[dict[str, Any]] = None
    if spec is not None:
        try:
            raw_args = arguments if isinstance(arguments, dict) else {}
            model_obj = spec.args_model.model_validate(raw_args)
            validated_args = model_obj.model_dump()
        except ValidationError:
            await record_tool_audit(
                db,
                profile_id=profile_session.profile_id,
                conversation_id=conversation_id,
                tool_name=normalized_name,
                risk_tier=risk_tier,
                provenance=provenance,
                decision="DENY",
                outcome_status="invalid_arguments",
                error_code="INVALID_ARGUMENTS",
                commit=commit,
            )
            return ToolExecutionOutcome(
                tool_name=normalized_name,
                risk_tier=risk_tier,
                provenance=provenance,
                decision="DENY",
                executed=False,
                outcome_status="invalid_arguments",
                summary=f"Rejected '{normalized_name}': invalid arguments.",
                error_code="INVALID_ARGUMENTS",
            )

    # Stage 3: Deterministic policy outside LLM
    evaluation = evaluate_tool_policy(
        spec=spec,
        tool_name=normalized_name,
        provenance=provenance,
        validated_args=validated_args,
        runtime_config=runtime_config,
        profile_settings=profile_settings,
        profile=profile,
    )

    if evaluation.decision == "DENY":
        deny_status = "killed" if evaluation.reason_code == "KILL_SWITCH_ACTIVE" else "denied"
        await record_tool_audit(
            db,
            profile_id=profile_session.profile_id,
            conversation_id=conversation_id,
            tool_name=normalized_name,
            risk_tier=risk_tier,
            provenance=provenance,
            decision="DENY",
            outcome_status=deny_status,
            error_code=evaluation.reason_code,
            commit=commit,
        )
        return ToolExecutionOutcome(
            tool_name=normalized_name,
            risk_tier=risk_tier,
            provenance=provenance,
            decision="DENY",
            executed=False,
            outcome_status=deny_status,
            summary=f"Tool '{normalized_name}' denied by policy ({evaluation.reason_code}).",
            error_code=evaluation.reason_code,
        )

    assert spec is not None and validated_args is not None

    if evaluation.decision == "CONFIRM":
        now = utc_now()
        expires_at = now + timedelta(seconds=CONFIRMATION_TTL_SECONDS)
        canonical_args = json.dumps(validated_args, sort_keys=True, separators=(",", ":"))
        fp = compute_confirmation_fingerprint(
            profile_id=profile_session.profile_id,
            session_id=profile_session.id,
            conversation_id=conversation_id,
            tool_name=spec.name,
            canonical_args_json=canonical_args,
            expires_at=expires_at,
        )
        conf = ToolConfirmation(
            id=generate_uuid(),
            profile_id=profile_session.profile_id,
            conversation_id=conversation_id,
            session_id=profile_session.id,
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=provenance,
            arguments_json=canonical_args,
            target_summary=_summarize_target(spec, validated_args),
            fingerprint=fp,
            status="pending",
            expires_at=expires_at,
        )
        db.add(conf)
        await record_tool_audit(
            db,
            profile_id=profile_session.profile_id,
            conversation_id=conversation_id,
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=provenance,
            decision="CONFIRM",
            outcome_status="pending_confirmation",
            commit=False,
        )
        if commit:
            await db.commit()
            await db.refresh(conf)
        else:
            await db.flush()
        return ToolExecutionOutcome(
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=provenance,
            decision="CONFIRM",
            executed=False,
            outcome_status="pending_confirmation",
            summary=f"Confirmation required for {spec.name} ({conf.target_summary}).",
            confirmation=conf,
        )

    # Stage 4 & 5: Narrow Adapter execution
    try:
        adapter_out = await _dispatch_narrow_adapter(
            db=db,
            profile_session=profile_session,
            profile=profile,
            runtime_config=runtime_config,
            tool_name=spec.name,
            validated_args=validated_args,
        )
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        sources = list(adapter_out.get("sources") or [])
        domains = [s.get("domain", "") for s in sources if isinstance(s, dict)]
        summary = str(adapter_out.get("summary") or f"Executed {spec.name}.")
        await record_tool_audit(
            db,
            profile_id=profile_session.profile_id,
            conversation_id=conversation_id,
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=provenance,
            decision="ALLOW",
            outcome_status="executed",
            duration_ms=elapsed_ms,
            source_domains=domains,
            commit=commit,
        )
        return ToolExecutionOutcome(
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=provenance,
            decision="ALLOW",
            executed=True,
            outcome_status="executed",
            summary=summary,
            duration_ms=elapsed_ms,
            payload=adapter_out,
            sources=sources,
        )
    except SSRFBlockedError:
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        await record_tool_audit(
            db,
            profile_id=profile_session.profile_id,
            conversation_id=conversation_id,
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=provenance,
            decision="ALLOW",
            outcome_status="blocked_ssrf",
            duration_ms=elapsed_ms,
            error_code="SSRF_BLOCKED",
            commit=commit,
        )
        return ToolExecutionOutcome(
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=provenance,
            decision="ALLOW",
            executed=False,
            outcome_status="blocked_ssrf",
            summary="Blocked outbound request violating SSRF containment policy.",
            duration_ms=elapsed_ms,
            error_code="SSRF_BLOCKED",
        )
    except Exception as exc:
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        await record_tool_audit(
            db,
            profile_id=profile_session.profile_id,
            conversation_id=conversation_id,
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=provenance,
            decision="ALLOW",
            outcome_status="failed",
            duration_ms=elapsed_ms,
            error_code=type(exc).__name__[:64],
            commit=commit,
        )
        return ToolExecutionOutcome(
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=provenance,
            decision="ALLOW",
            executed=False,
            outcome_status="failed",
            summary=f"Tool '{spec.name}' failed safely: {exc}",
            duration_ms=elapsed_ms,
            error_code=type(exc).__name__[:64],
        )


@dataclass
class ConfirmationResolutionResult:
    """Structured result of resolving a pending confirmation."""

    confirmation: ToolConfirmation
    executed: bool
    outcome_status: str
    summary: str
    error_code: Optional[str] = None
    sources: list[dict[str, Any]] = field(default_factory=list)


class ConfirmationLookupError(Exception):
    """Domain error with explicit HTTP status code for confirmation resolution."""

    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


async def resolve_confirmation_atomic(
    *,
    db: AsyncSession,
    confirmation_id: str,
    profile_session: ProfileSession,
    decision: str,
) -> ConfirmationResolutionResult:
    """Atomically validate, claim, and resolve a confirmation bound to profile + session + fingerprint."""
    pid = profile_session.profile_id
    sid = profile_session.id
    row = await db.get(ToolConfirmation, confirmation_id)
    if row is None or row.profile_id != pid:
        raise ConfirmationLookupError(404, "CONFIRMATION_NOT_FOUND", "Confirmation request not found.")

    if row.session_id != sid:
        raise ConfirmationLookupError(
            403,
            "CONFIRMATION_SESSION_MISMATCH",
            "Confirmation is bound to a different profile session.",
        )

    now = utc_now()
    runtime_config = await get_or_create_runtime_config(db)
    if runtime_config.global_kill_switch and decision == "approve":
        raise ConfirmationLookupError(
            409,
            "KILL_SWITCH_ACTIVE",
            "Global Tool Kill Switch is active; cannot execute confirmed action.",
        )

    exp = as_utc(row.expires_at)
    if exp is not None and exp <= now and row.status == "pending":
        row.status = "expired"
        row.resolved_at = now
        await db.commit()
        raise ConfirmationLookupError(410, "CONFIRMATION_EXPIRED", "Confirmation token has expired.")

    expected_fp = compute_confirmation_fingerprint(
        profile_id=row.profile_id,
        session_id=row.session_id,
        conversation_id=row.conversation_id,
        tool_name=row.tool_name,
        canonical_args_json=row.arguments_json,
        expires_at=row.expires_at,
    )
    if expected_fp != row.fingerprint:
        raise ConfirmationLookupError(
            409,
            "CONFIRMATION_FINGERPRINT_MISMATCH",
            "Confirmation fingerprint mismatch; request invalidated.",
        )

    target_status = "approved" if decision == "approve" else "rejected"
    claim_stmt = (
        update(ToolConfirmation)
        .where(
            and_(
                ToolConfirmation.id == confirmation_id,
                ToolConfirmation.profile_id == pid,
                ToolConfirmation.session_id == sid,
                ToolConfirmation.status == "pending",
                ToolConfirmation.expires_at > now,
            )
        )
        .values(status=target_status, resolved_at=now, updated_at=now)
        .execution_options(synchronize_session=False)
    )
    claim_res = await db.execute(claim_stmt)
    if (claim_res.rowcount or 0) != 1:
        await db.rollback()
        refreshed = await db.get(ToolConfirmation, confirmation_id)
        return ConfirmationResolutionResult(
            confirmation=refreshed or row,
            executed=False,
            outcome_status="already_resolved",
            summary="Confirmation was already claimed or resolved.",
        )

    if decision == "reject":
        await record_tool_audit(
            db,
            profile_id=pid,
            conversation_id=row.conversation_id,
            tool_name=row.tool_name,
            risk_tier=row.risk_tier,
            provenance=row.provenance,
            decision="CONFIRM",
            outcome_status="rejected_by_user",
            commit=True,
        )
        await db.refresh(row)
        return ConfirmationResolutionResult(
            confirmation=row,
            executed=False,
            outcome_status="rejected_by_user",
            summary=f"Rejected {row.tool_name} ({row.target_summary}).",
        )

    spec = TOOL_REGISTRY.get(row.tool_name)
    if spec is None:
        row.status = "failed"
        await db.commit()
        raise ConfirmationLookupError(400, "UNSUPPORTED_TOOL", "Tool is no longer registered.")

    started = time.perf_counter()
    try:
        parsed_args = spec.args_model.model_validate(json.loads(row.arguments_json)).model_dump()
        profile = await db.get(Profile, pid)
        adapter_out = await _dispatch_narrow_adapter(
            db=db,
            profile_session=profile_session,
            profile=profile,
            runtime_config=runtime_config,
            tool_name=spec.name,
            validated_args=parsed_args,
            profile_id=pid,
        )
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        summary = str(adapter_out.get("summary") or f"Executed {spec.name}.")
        row.status = "executed"
        row.result_summary_json = json.dumps({"summary": summary})
        row.updated_at = utc_now()
        sources = list(adapter_out.get("sources") or [])
        await record_tool_audit(
            db,
            profile_id=pid,
            conversation_id=row.conversation_id,
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=row.provenance,
            decision="CONFIRM",
            outcome_status="confirmed_executed",
            duration_ms=elapsed_ms,
            source_domains=[s.get("domain", "") for s in sources if isinstance(s, dict)],
            commit=True,
        )
        await db.refresh(row)
        return ConfirmationResolutionResult(
            confirmation=row,
            executed=True,
            outcome_status="confirmed_executed",
            summary=summary,
            sources=sources,
        )
    except Exception as exc:
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        row.status = "failed"
        row.updated_at = utc_now()
        await record_tool_audit(
            db,
            profile_id=pid,
            conversation_id=row.conversation_id,
            tool_name=spec.name,
            risk_tier=spec.risk_tier,
            provenance=row.provenance,
            decision="CONFIRM",
            outcome_status="failed",
            duration_ms=elapsed_ms,
            error_code=type(exc).__name__[:64],
            commit=True,
        )
        await db.refresh(row)
        return ConfirmationResolutionResult(
            confirmation=row,
            executed=False,
            outcome_status="failed",
            summary=f"Confirmed execution failed: {exc}",
            error_code=type(exc).__name__[:64],
        )


async def list_pending_confirmations_for_conversation(
    db: AsyncSession,
    *,
    profile_id: str,
    conversation_id: str,
) -> list[ToolConfirmation]:
    """Return all currently unexpired pending confirmations for a conversation."""
    now = utc_now()
    stmt = (
        select(ToolConfirmation)
        .where(
            ToolConfirmation.profile_id == profile_id,
            ToolConfirmation.conversation_id == conversation_id,
            ToolConfirmation.status == "pending",
            ToolConfirmation.expires_at > now,
        )
        .order_by(ToolConfirmation.created_at.asc())
    )
    return list((await db.execute(stmt)).scalars().all())


def is_unambiguous_confirmation_text(user_text: str, conf: ToolConfirmation) -> Optional[bool]:
    """Classify user text against one pending confirmation.

    Returns ``True`` ONLY when explicitly confirming the action/target,
    ``False`` when vague affirmation (``yes`` / ``ok``) is detected,
    and ``None`` for unrelated normal prompts.
    """
    if _VAGUE_AFFIRMATION_RE.match(user_text):
        return False

    match = _CONFIRM_PHRASE_RE.match(user_text)
    if not match:
        return None
    remainder = match.group(2).strip().lower()
    if not remainder:
        return False

    tool_token = conf.tool_name.lower()
    tool_words = tool_token.replace("_", " ")
    target = (conf.target_summary or "").strip().lower()

    if tool_token in remainder or tool_words in remainder:
        return True
    if target and len(target) >= 3 and target in remainder:
        return True
    return False
