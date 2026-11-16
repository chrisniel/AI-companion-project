"""Profile-scoped D9 risk tier permissions."""

from sqlalchemy import CheckConstraint, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import TimestampMixin


class ProfileToolSettings(Base, TimestampMixin):
    """Per-profile deterministic Risk 0/1/2 policy defaults (Risk 3 permanently denied)."""

    __tablename__ = "profile_tool_settings"
    __table_args__ = (
        CheckConstraint("risk0_policy IN ('allow', 'confirm', 'deny')", name="ck_profile_tool_risk0"),
        CheckConstraint("risk1_explicit_policy IN ('allow', 'confirm', 'deny')", name="ck_profile_tool_risk1_exp"),
        CheckConstraint("risk1_suggested_policy IN ('confirm', 'deny')", name="ck_profile_tool_risk1_sug"),
        CheckConstraint("risk2_policy IN ('confirm', 'deny')", name="ck_profile_tool_risk2"),
    )

    profile_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("profiles.id", ondelete="CASCADE"),
        primary_key=True,
    )
    risk0_policy: Mapped[str] = mapped_column(String(16), nullable=False, default="allow", server_default="allow")
    risk1_explicit_policy: Mapped[str] = mapped_column(
        String(16), nullable=False, default="allow", server_default="allow"
    )
    risk1_suggested_policy: Mapped[str] = mapped_column(
        String(16), nullable=False, default="confirm", server_default="confirm"
    )
    risk2_policy: Mapped[str] = mapped_column(String(16), nullable=False, default="confirm", server_default="confirm")
