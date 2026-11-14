"""Alarm SQLAlchemy ORM model definition (D10 / PC-SCHED-002)."""

from datetime import datetime
from typing import List, Optional
import sqlalchemy as sa
from sqlalchemy import Boolean, DateTime, String
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


class Alarm(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin):
    """High-urgency interrupt entity supporting one-shot or recurring weekday alarms."""

    __tablename__ = "alarms"

    label: Mapped[str] = mapped_column(String(255), nullable=False)
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    time_of_day: Mapped[Optional[str]] = mapped_column(String(5), nullable=True)
    recurrence_days: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    timezone: Mapped[str] = mapped_column(String(64), default="UTC", server_default="UTC", nullable=False)
    enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default=sa.text("1"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        default="armed",
        server_default="armed",
        nullable=False,
        index=True,
    )
    snoozed_until: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    bypass_quiet_hours: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        server_default=sa.text("1"),
        nullable=False,
    )
    origin: Mapped[str] = mapped_column(
        String(32),
        default="host",
        server_default="host",
        nullable=False,
    )
    last_fired_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    acknowledged_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    @property
    def recurrence_days_list(self) -> List[int]:
        """Parse comma-separated weekday integers (0=Mon..6=Sun)."""
        return parse_recurrence_days_string(self.recurrence_days)

    def __repr__(self) -> str:
        return (
            f"<Alarm id={self.id} label={self.label!r} enabled={self.enabled} "
            f"status={self.status} scheduled_at={self.scheduled_at}>"
        )
