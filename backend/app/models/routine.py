"""Routine SQLAlchemy ORM model definition (D10 / PC-SCHED-005)."""

from datetime import datetime
from typing import List, Optional
import sqlalchemy as sa
from sqlalchemy import Boolean, DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import (
    OwnerMixin,
    ProfileMixin,
    SoftDeleteMixin,
    TimestampMixin,
    UUIDPrimaryKeyMixin,
    parse_recurrence_days_string,
)


class Routine(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin):
    """Bounded companion check-in schedule with deterministic fallback message."""

    __tablename__ = "routines"

    title: Mapped[str] = mapped_column(String(255), nullable=False)
    prompt_template: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    fallback_message: Mapped[str] = mapped_column(Text, nullable=False)
    time_of_day: Mapped[str] = mapped_column(String(5), nullable=False)
    recurrence_days: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    timezone: Mapped[str] = mapped_column(String(64), default="UTC", server_default="UTC", nullable=False)
    enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default=sa.text("1"),
        nullable=False,
        index=True,
    )
    bypass_quiet_hours: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default=sa.text("0"),
        nullable=False,
    )
    next_run_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    last_run_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_status: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)

    @property
    def recurrence_days_list(self) -> List[int]:
        """Parse comma-separated weekday integers (0=Mon..6=Sun)."""
        return parse_recurrence_days_string(self.recurrence_days)

    def __repr__(self) -> str:
        return (
            f"<Routine id={self.id} title={self.title!r} enabled={self.enabled} "
            f"next_run_at={self.next_run_at}>"
        )
