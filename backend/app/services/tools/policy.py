"""Deterministic D9 policy evaluator, quiet-hours gate, and confirmation fingerprinting."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
from typing import Any, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.base import utc_now
from app.models.profile import Profile
from app.models.profile_tool_settings import ProfileToolSettings
from app.models.tool_runtime_config import ToolRuntimeConfig
from app.services.scheduler.service import as_utc, is_within_quiet_hours
from app.services.tools.registry import ALLOWED_PROVENANCES, PROHIBITED_RISK3_NAMES, ToolSpec


@dataclass(frozen=True)
class PolicyEvaluation:
    """Deterministic Stage-3 outcome outside LLM context."""

    decision: str  # "ALLOW" | "CONFIRM" | "DENY"
    reason_code: str
    quiet_hours_active: bool = False


def compute_confirmation_fingerprint(
    *,
    profile_id: str,
    session_id: str,
    conversation_id: str,
    tool_name: str,
    canonical_args_json: str,
    expires_at: datetime,
) -> str:
    """Compute SHA-256 signature binding action, parameters, profile, session, and expiry."""
    exp_utc = as_utc(expires_at) or utc_now()
    payload = json.dumps(
        {
            "profile_id": profile_id,
            "session_id": session_id,
            "conversation_id": conversation_id,
            "tool_name": tool_name,
            "arguments_json": canonical_args_json,
            "expires_at": exp_utc.isoformat(),
        },
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


async def get_or_create_runtime_config(db: AsyncSession) -> ToolRuntimeConfig:
    """Load or initialize the singleton host ToolRuntimeConfig row."""
    row = await db.get(ToolRuntimeConfig, "default")
    if row is None:
        row = ToolRuntimeConfig(
            id="default",
            global_kill_switch=False,
            weather_provider="open_meteo",
            web_search_provider="public_search",
        )
        db.add(row)
        await db.flush()
    return row


async def get_or_create_profile_tool_settings(
    db: AsyncSession,
    profile_id: str,
) -> ProfileToolSettings:
    """Load or initialize per-profile Risk 0-2 D9 policy settings."""
    row = await db.get(ProfileToolSettings, profile_id)
    if row is None:
        row = ProfileToolSettings(
            profile_id=profile_id,
            risk0_policy="allow",
            risk1_explicit_policy="allow",
            risk1_suggested_policy="confirm",
            risk2_policy="confirm",
        )
        db.add(row)
        await db.flush()
    return row


def evaluate_tool_policy(
    *,
    spec: Optional[ToolSpec],
    tool_name: str,
    provenance: str,
    validated_args: Optional[dict[str, Any]],
    runtime_config: ToolRuntimeConfig,
    profile_settings: ProfileToolSettings,
    profile: Optional[Profile],
    now: Optional[datetime] = None,
) -> PolicyEvaluation:
    """Evaluate tool invocation strictly outside the LLM context under DEFAULT DENY."""
    current_now = as_utc(now) or utc_now()

    if runtime_config.global_kill_switch:
        return PolicyEvaluation(decision="DENY", reason_code="KILL_SWITCH_ACTIVE")

    lowered_name = (tool_name or "").strip().lower()
    if lowered_name in PROHIBITED_RISK3_NAMES or spec is None:
        return PolicyEvaluation(decision="DENY", reason_code="DEFAULT_DENY_UNREGISTERED_OR_RISK3")

    if provenance not in ALLOWED_PROVENANCES or provenance == "EXTERNAL_CONTENT":
        return PolicyEvaluation(decision="DENY", reason_code="EXTERNAL_CONTENT_FORBIDDEN")

    quiet_now = bool(profile is not None and is_within_quiet_hours(profile, current_now))

    # Deterministic domain check for scheduling / notification quiet hours
    if spec.domain == "scheduling" and profile is not None:
        if spec.name == "create_reminder" and validated_args is not None:
            scheduled_raw = validated_args.get("scheduled_at")
            try:
                sched_dt = as_utc(datetime.fromisoformat(str(scheduled_raw).replace("Z", "+00:00")))
            except Exception:
                sched_dt = current_now
            in_quiet_at_due = bool(sched_dt and is_within_quiet_hours(profile, sched_dt))
            bypass_req = bool(validated_args.get("bypass_quiet_hours", False))
            if (bypass_req and (quiet_now or in_quiet_at_due)) or (in_quiet_at_due and provenance == "COMPANION_SUGGESTED"):
                # Bypassing quiet hours during quiet period requires explicit confirmation unless policy denies
                if profile_settings.risk1_suggested_policy == "deny" and provenance == "COMPANION_SUGGESTED":
                    return PolicyEvaluation(decision="DENY", reason_code="QUIET_HOURS_DENIED", quiet_hours_active=True)
                return PolicyEvaluation(decision="CONFIRM", reason_code="QUIET_HOURS_CONFIRM", quiet_hours_active=True)

    # Risk tier matrix resolution
    if spec.risk_tier == 0:
        outcome = profile_settings.risk0_policy.upper()
        return PolicyEvaluation(
            decision=outcome,
            reason_code=f"RISK0_{outcome}",
            quiet_hours_active=quiet_now,
        )

    if spec.risk_tier == 1:
        if provenance in ("EXPLICIT_USER", "APPROVED_ROUTINE", "SYSTEM_RECOVERY"):
            outcome = profile_settings.risk1_explicit_policy.upper()
            return PolicyEvaluation(
                decision=outcome,
                reason_code=f"RISK1_EXPLICIT_{outcome}",
                quiet_hours_active=quiet_now,
            )
        # COMPANION_SUGGESTED
        outcome = profile_settings.risk1_suggested_policy.upper()
        if outcome not in ("CONFIRM", "DENY"):
            outcome = "CONFIRM"
        return PolicyEvaluation(
            decision=outcome,
            reason_code=f"RISK1_SUGGESTED_{outcome}",
            quiet_hours_active=quiet_now,
        )

    if spec.risk_tier == 2:
        outcome = profile_settings.risk2_policy.upper()
        if outcome not in ("CONFIRM", "DENY"):
            outcome = "CONFIRM"
        return PolicyEvaluation(
            decision=outcome,
            reason_code=f"RISK2_{outcome}",
            quiet_hours_active=quiet_now,
        )

    return PolicyEvaluation(decision="DENY", reason_code="DEFAULT_DENY_FALLBACK")
