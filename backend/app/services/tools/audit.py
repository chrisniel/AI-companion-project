"""Redacted metadata-only D9 audit logging helpers."""

from __future__ import annotations

import json
from typing import Iterable, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.base import generate_uuid, utc_now
from app.models.tool_audit_log import ToolAuditLog
from app.models.tool_confirmation import ToolConfirmation
from app.schemas.tools import ToolConfirmationOut


def serialize_tool_confirmation(row: ToolConfirmation) -> ToolConfirmationOut:
    """Serialize ORM ToolConfirmation safely without exposing internal session keys."""
    return ToolConfirmationOut(
        id=row.id,
        conversation_id=row.conversation_id,
        tool_name=row.tool_name,
        risk_tier=row.risk_tier,
        provenance=row.provenance,
        target_summary=row.target_summary or row.tool_name,
        arguments_preview=row.arguments_json[:240],
        fingerprint=row.fingerprint,
        status=row.status,
        expires_at=row.expires_at,
        created_at=row.created_at,
        resolved_at=row.resolved_at,
    )


async def record_tool_audit(
    db: AsyncSession,
    *,
    profile_id: Optional[str],
    conversation_id: Optional[str],
    tool_name: str,
    risk_tier: int,
    provenance: str,
    decision: str,
    outcome_status: str,
    duration_ms: Optional[int] = None,
    source_domains: Optional[Iterable[str]] = None,
    error_code: Optional[str] = None,
    commit: bool = False,
) -> ToolAuditLog:
    """Persist a redacted audit log row containing zero prompts, arguments, or secrets."""
    clamped_risk = max(0, min(2, int(risk_tier)))
    clean_domains = sorted({str(d).strip().lower()[:120] for d in (source_domains or []) if str(d).strip()})
    row = ToolAuditLog(
        id=generate_uuid(),
        profile_id=profile_id,
        conversation_id=conversation_id,
        tool_name=str(tool_name)[:64],
        risk_tier=clamped_risk,
        provenance=str(provenance)[:32],
        decision=str(decision)[:32],
        outcome_status=str(outcome_status)[:32],
        duration_ms=duration_ms,
        source_domains_json=json.dumps(clean_domains) if clean_domains else None,
        error_code=str(error_code)[:64] if error_code else None,
        created_at=utc_now(),
    )
    db.add(row)
    if commit:
        await db.commit()
    else:
        await db.flush()
    return row
