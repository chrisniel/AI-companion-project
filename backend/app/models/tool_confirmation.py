"""Pending and resolved D9 tool confirmations bound to session, profile, and arguments."""

from datetime import datetime
from typing import Optional

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import ProfileMixin, TimestampMixin, UUIDPrimaryKeyMixin


class ToolConfirmation(Base, UUIDPrimaryKeyMixin, TimestampMixin, ProfileMixin):
    """Fingerprint-bound confirmation token required before executing Risk 1/2 actions."""

    __tablename__ = "tool_confirmations"
    __table_args__ = (
        CheckConstraint("risk_tier BETWEEN 0 AND 2", name="ck_tool_confirmations_risk_tier"),
        CheckConstraint(
            "status IN ('pending', 'approved', 'rejected', 'expired', 'executed', 'failed', 'killed')",
            name="ck_tool_confirmations_status",
        ),
    )

    conversation_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Plain indexed string so session revocation/purge never hits an FK constraint block.
    session_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    tool_name: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    risk_tier: Mapped[int] = mapped_column(Integer, nullable=False)
    provenance: Mapped[str] = mapped_column(String(32), nullable=False)
    arguments_json: Mapped[str] = mapped_column(Text, nullable=False)
    target_summary: Mapped[str] = mapped_column(String(255), nullable=False, default="", server_default="")
    fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="pending", server_default="pending", index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    resolved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    result_summary_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
