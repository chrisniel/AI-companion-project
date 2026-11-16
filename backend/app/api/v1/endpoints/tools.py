"""Authenticated endpoints for D9 deterministic policy, Kill Switch, audit, and confirmations."""

from __future__ import annotations

import ipaddress
import json
from typing import Optional
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, Security, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db, require_host_admin
from app.core.host_admin import require_host_admin as verify_host_admin_request
from app.core.profile_sessions import get_current_profile_session as resolve_bearer_session, validate_profile_session
from app.core.security import bearer_security
from app.models.base import utc_now
from app.models.profile_session import ProfileSession
from app.models.tool_audit_log import ToolAuditLog
from app.models.tool_confirmation import ToolConfirmation
from app.schemas.tools import (
    KillSwitchRequest,
    KillSwitchStateOut,
    ToolAuditLogListOut,
    ToolAuditLogOut,
    ToolCatalogItemOut,
    ToolCatalogOut,
    ToolConfirmationListOut,
    ToolConfirmationOut,
    ToolConfirmationResolveRequest,
    ToolConfirmationResolveResponse,
    ToolPolicyOut,
    ToolPolicyUpdate,
    WebApiKeyClearOut,
    WebConfigOut,
    WebConfigUpdateRequest,
    WebSourceRefOut,
)
from app.services.scheduler.service import as_utc
from app.services.tools.audit import record_tool_audit, serialize_tool_confirmation
from app.services.tools.executor import ConfirmationLookupError, resolve_confirmation_atomic
from app.services.tools.policy import (
    get_or_create_profile_tool_settings,
    get_or_create_runtime_config,
)
from app.services.tools.registry import PROHIBITED_RISK3_CATEGORIES, TOOL_REGISTRY
from app.services.tools.web_secret_store import (
    clear_web_search_api_key,
    has_web_search_api_key,
    write_web_search_api_key,
)

router = APIRouter(prefix="/tools", tags=["Tools & Safety"])


def _serialize_policy_out(profile_id: str, cfg, ps) -> ToolPolicyOut:
    return ToolPolicyOut(
        profile_id=profile_id,
        global_kill_switch=bool(cfg.global_kill_switch),
        kill_switch_updated_at=cfg.kill_switch_updated_at,
        kill_switch_reason=cfg.kill_switch_reason,
        risk0_policy=ps.risk0_policy,
        risk1_explicit_policy=ps.risk1_explicit_policy,
        risk1_suggested_policy=ps.risk1_suggested_policy,
        risk2_policy=ps.risk2_policy,
        weather_provider=cfg.weather_provider,
        web_search_provider=cfg.web_search_provider,
        searxng_base_url=cfg.searxng_base_url,
        search_api_key_configured=has_web_search_api_key(),
        updated_at=max(as_utc(cfg.updated_at) or utc_now(), as_utc(ps.updated_at) or utc_now()),
    )


async def require_session_or_host_admin(
    request: Request,
    auth_header: Optional[HTTPAuthorizationCredentials] = Security(bearer_security),
    x_host_admin_secret: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
) -> Optional[ProfileSession]:
    """FastAPI dependency enforcing either active Profile Session or native Host Admin (401/403 before body validation)."""
    if auth_header is not None and auth_header.credentials:
        session = await resolve_bearer_session(auth_header, db)
        await validate_profile_session(db, session)
        return session
    if x_host_admin_secret is not None:
        await verify_host_admin_request(request, x_host_admin_secret)
        return None
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required.",
    )


def _validate_searxng_url(raw_url: str) -> str:
    cleaned = raw_url.strip().rstrip("/")
    parts = urlsplit(cleaned)
    scheme = parts.scheme.lower()
    if scheme not in ("http", "https") or not parts.hostname:
        raise HTTPException(status_code=422, detail="searxng_base_url must be a valid http/https URL.")
    if parts.username is not None or parts.password is not None:
        raise HTTPException(status_code=422, detail="Embedded credentials in searxng_base_url are forbidden.")
    host = parts.hostname.strip().lower()
    try:
        ip = ipaddress.ip_address(host)
        if str(ip) == "169.254.169.254" or ip.is_link_local or ip.is_multicast or ip.is_unspecified:
            raise HTTPException(status_code=422, detail="searxng_base_url cannot target metadata or link-local ranges.")
    except ValueError:
        pass
    return f"{scheme}://{parts.netloc}{parts.path or ''}".rstrip("/")


@router.get("/catalog", response_model=ToolCatalogOut, summary="List Registered D9 Tools")
async def get_tool_catalog(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ToolCatalogOut:
    """Return all registered Decision D9 tools alongside permanently rejected Risk 3 classes."""
    await validate_profile_session(db, session)
    items = [
        ToolCatalogItemOut(
            name=spec.name,
            description=spec.description,
            risk_tier=spec.risk_tier,
            domain=spec.domain,
            reversible=spec.reversible,
        )
        for spec in TOOL_REGISTRY.values()
    ]
    return ToolCatalogOut(items=items, prohibited_capabilities=list(PROHIBITED_RISK3_CATEGORIES))


@router.get("/policy", response_model=ToolPolicyOut, summary="Get D9 Policy & Kill Switch State")
async def get_tool_policy(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ToolPolicyOut:
    """Return active profile's D9 policy, Global Kill Switch state, and non-secret Web config."""
    await validate_profile_session(db, session)
    cfg = await get_or_create_runtime_config(db)
    ps = await get_or_create_profile_tool_settings(db, session.profile_id)
    await db.commit()
    return _serialize_policy_out(session.profile_id, cfg, ps)


@router.patch("/policy", response_model=ToolPolicyOut, summary="Update Profile D9 Policy")
async def update_tool_policy(
    payload: ToolPolicyUpdate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ToolPolicyOut:
    """Update Risk 0-2 policy thresholds scoped strictly to the authenticated profile."""
    await validate_profile_session(db, session)
    cfg = await get_or_create_runtime_config(db)
    ps = await get_or_create_profile_tool_settings(db, session.profile_id)
    if payload.risk0_policy is not None:
        ps.risk0_policy = payload.risk0_policy
    if payload.risk1_explicit_policy is not None:
        ps.risk1_explicit_policy = payload.risk1_explicit_policy
    if payload.risk1_suggested_policy is not None:
        ps.risk1_suggested_policy = payload.risk1_suggested_policy
    if payload.risk2_policy is not None:
        ps.risk2_policy = payload.risk2_policy
    ps.updated_at = utc_now()
    await db.commit()
    await db.refresh(ps)
    return _serialize_policy_out(session.profile_id, cfg, ps)


@router.get("/kill-switch", response_model=KillSwitchStateOut, summary="Get Global Tool Kill Switch")
async def get_kill_switch_state(
    _: Optional[ProfileSession] = Depends(require_session_or_host_admin),
    db: AsyncSession = Depends(get_db),
) -> KillSwitchStateOut:
    """Read persistent Global Tool Kill Switch state (requires Profile Session or Host Admin)."""
    cfg = await get_or_create_runtime_config(db)
    await db.commit()
    return KillSwitchStateOut(
        global_kill_switch=bool(cfg.global_kill_switch),
        kill_switch_updated_at=cfg.kill_switch_updated_at,
        kill_switch_reason=cfg.kill_switch_reason,
    )


@router.post("/kill-switch", response_model=KillSwitchStateOut, summary="Toggle Global Tool Kill Switch")
async def set_kill_switch_state(
    request: Request,
    payload: KillSwitchRequest,
    session: Optional[ProfileSession] = Depends(require_session_or_host_admin),
    x_host_admin_secret: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
) -> KillSwitchStateOut:
    """Engage (Profile Session or Host Admin) or disengage (Host Admin ONLY) the persistent Kill Switch."""
    # Disabling Kill Switch strictly requires independent native Host Admin over loopback
    if not payload.enabled:
        if x_host_admin_secret is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Host Admin authority required to disengage Kill Switch.",
            )
        await verify_host_admin_request(request, x_host_admin_secret)

    cfg = await get_or_create_runtime_config(db)
    now = utc_now()
    cfg.global_kill_switch = bool(payload.enabled)
    cfg.kill_switch_updated_at = now
    cfg.kill_switch_reason = payload.reason
    cfg.updated_at = now

    await record_tool_audit(
        db,
        profile_id=session.profile_id if session is not None else None,
        conversation_id=None,
        tool_name="global_kill_switch",
        risk_tier=2,
        provenance="EXPLICIT_USER",
        decision="KILL_SWITCH_ON" if payload.enabled else "KILL_SWITCH_OFF",
        outcome_status="engaged" if payload.enabled else "disengaged",
        commit=False,
    )
    await db.commit()
    await db.refresh(cfg)
    return KillSwitchStateOut(
        global_kill_switch=bool(cfg.global_kill_switch),
        kill_switch_updated_at=cfg.kill_switch_updated_at,
        kill_switch_reason=cfg.kill_switch_reason,
    )


@router.put("/web-config", response_model=WebConfigOut, summary="Configure Web Info Providers (Host Admin)")
async def update_web_config(
    payload: WebConfigUpdateRequest,
    _: str = Depends(require_host_admin),
    db: AsyncSession = Depends(get_db),
) -> WebConfigOut:
    """Host-Admin-only update of Web provider routing and ACL-protected search API key."""
    cfg = await get_or_create_runtime_config(db)
    if payload.weather_provider is not None:
        cfg.weather_provider = payload.weather_provider
    if payload.web_search_provider is not None:
        cfg.web_search_provider = payload.web_search_provider
    if payload.searxng_base_url is not None:
        cfg.searxng_base_url = _validate_searxng_url(payload.searxng_base_url) if payload.searxng_base_url.strip() else None
    if payload.search_api_key is not None:
        write_web_search_api_key(payload.search_api_key)
    cfg.updated_at = utc_now()
    await db.commit()
    await db.refresh(cfg)
    return WebConfigOut(
        weather_provider=cfg.weather_provider,
        web_search_provider=cfg.web_search_provider,
        searxng_base_url=cfg.searxng_base_url,
        search_api_key_configured=has_web_search_api_key(),
    )


@router.delete("/web-config/api-key", response_model=WebApiKeyClearOut, summary="Clear Local Web Search API Key (Host Admin)")
async def delete_web_search_api_key(
    _: str = Depends(require_host_admin),
) -> WebApiKeyClearOut:
    """Delete device-local Web Search API key file on native Host Admin request."""
    removed = clear_web_search_api_key()
    return WebApiKeyClearOut(
        cleared=removed,
        search_api_key_configured=has_web_search_api_key(),
    )


@router.get("/audit", response_model=ToolAuditLogListOut, summary="List Redacted Tool Audit Logs")
async def list_tool_audit_logs(
    limit: int = Query(50, ge=1, le=200),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ToolAuditLogListOut:
    """List newest redacted tool audit logs for the authenticated profile."""
    await validate_profile_session(db, session)
    base_where = ToolAuditLog.profile_id == session.profile_id
    total = int((await db.scalar(select(func.count(ToolAuditLog.id)).where(base_where))) or 0)
    rows = (
        await db.execute(
            select(ToolAuditLog)
            .where(base_where)
            .order_by(ToolAuditLog.created_at.desc())
            .limit(limit)
        )
    ).scalars().all()
    items = []
    for r in rows:
        domains: list[str] = []
        if r.source_domains_json:
            try:
                parsed = json.loads(r.source_domains_json)
                if isinstance(parsed, list):
                    domains = [str(x) for x in parsed]
            except Exception:
                pass
        items.append(
            ToolAuditLogOut(
                id=r.id,
                profile_id=r.profile_id,
                conversation_id=r.conversation_id,
                tool_name=r.tool_name,
                risk_tier=r.risk_tier,
                provenance=r.provenance,
                decision=r.decision,
                outcome_status=r.outcome_status,
                duration_ms=r.duration_ms,
                source_domains=domains,
                error_code=r.error_code,
                created_at=r.created_at,
            )
        )
    return ToolAuditLogListOut(items=items, total=total)


@router.get("/confirmations", response_model=ToolConfirmationListOut, summary="List Tool Confirmations")
async def list_tool_confirmations(
    conversation_id: Optional[str] = Query(None),
    status_filter: Optional[str] = Query("pending", alias="status"),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ToolConfirmationListOut:
    """List profile-owned D9 confirmation requests filtered optionally by conversation/status."""
    await validate_profile_session(db, session)
    stmt = select(ToolConfirmation).where(ToolConfirmation.profile_id == session.profile_id)
    if conversation_id:
        stmt = stmt.where(ToolConfirmation.conversation_id == conversation_id)
    if status_filter:
        stmt = stmt.where(ToolConfirmation.status == status_filter)
    rows = (await db.execute(stmt.order_by(ToolConfirmation.created_at.desc()).limit(50))).scalars().all()
    items = [serialize_tool_confirmation(r) for r in rows]
    return ToolConfirmationListOut(items=items, total=len(items))


@router.post(
    "/confirmations/{confirmation_id}/resolve",
    response_model=ToolConfirmationResolveResponse,
    summary="Resolve Pending Tool Confirmation",
)
async def resolve_tool_confirmation(
    confirmation_id: str,
    payload: ToolConfirmationResolveRequest,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ToolConfirmationResolveResponse:
    """Atomically approve or reject a fingerprint-bound pending confirmation."""
    await validate_profile_session(db, session)
    try:
        res = await resolve_confirmation_atomic(
            db=db,
            confirmation_id=confirmation_id,
            profile_session=session,
            decision=payload.decision,
        )
    except ConfirmationLookupError as err:
        raise HTTPException(status_code=err.status_code, detail={"code": err.code, "message": err.message}) from None

    return ToolConfirmationResolveResponse(
        confirmation=serialize_tool_confirmation(res.confirmation),
        executed=res.executed,
        outcome_status=res.outcome_status,
        summary=res.summary,
        sources=[WebSourceRefOut(**s) for s in res.sources],
    )
