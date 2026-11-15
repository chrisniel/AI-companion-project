"""Reminder SQLAlchemy ORM model definition (D10 / PC-SCHED-002)."""

from datetime import datetime
from typing import Optional
import sqlalchemy as sa
from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import (
    OwnerMixin,
    ProfileMixin,
    SoftDeleteMixin,
    TimestampMixin,
    UUIDPrimaryKeyMixin,
)


class Reminder(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin):
    """Scheduled prompt/alert entity, standalone or optionally linked to a Task."""

    __tablename__ = "reminders"

    task_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("tasks.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    timezone: Mapped[str] = mapped_column(String(64), default="UTC", server_default="UTC", nullable=False)
    status: Mapped[str] = mapped_column(
        String(32),
        default="scheduled",
        server_default="scheduled",
        nullable=False,
        index=True,
    )
    snoozed_until: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    bypass_quiet_hours: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default=sa.text("0"),
        nullable=False,
    )
    center_popup: Mapped[bool] = mapped_column(
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
    fired_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    acknowledged_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    def __repr__(self) -> str:
        return (
            f"<Reminder id={self.id} title={self.title!r} status={self.status} "
            f"scheduled_at={self.scheduled_at} is_deleted={self.is_deleted}>"
        )
