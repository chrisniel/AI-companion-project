"""NotificationEvent SQLAlchemy ORM model definition (PC-HOST-003)."""

from datetime import datetime
from typing import Optional
import sqlalchemy as sa
from sqlalchemy import Boolean, DateTime, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import (
    OwnerMixin,
    ProfileMixin,
    SoftDeleteMixin,
    TimestampMixin,
    UUIDPrimaryKeyMixin,
)


class NotificationEvent(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin):
    """Runtime-owned durable notification backlog entry."""

    __tablename__ = "notification_events"
    __table_args__ = (
        Index(
            "ix_notification_events_dedup",
            "profile_id",
            "source_type",
            "source_id",
            "triggered_at",
        ),
    )

    source_type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    source_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    urgency: Mapped[str] = mapped_column(String(32), default="standard", server_default="standard", nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    body: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(
        String(32),
        default="unread",
        server_default="unread",
        nullable=False,
        index=True,
    )
    delivery_policy: Mapped[str] = mapped_column(
        String(32),
        default="immediate",
        server_default="immediate",
        nullable=False,
    )
    is_missed_catchup: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default=sa.text("0"),
        nullable=False,
    )
    triggered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    read_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    def __repr__(self) -> str:
        return (
            f"<NotificationEvent id={self.id} source_type={self.source_type!r} "
            f"status={self.status!r} urgency={self.urgency!r}>"
        )
