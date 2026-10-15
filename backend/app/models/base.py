"""Base model mixins for UUID primary keys, timestamps, and owner isolation."""

import uuid
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import Boolean, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column


def generate_uuid() -> str:
    """Generate a clean 32-character hexadecimal UUID string."""
    return uuid.uuid4().hex


def utc_now() -> datetime:
    """Return current timezone-aware UTC datetime."""
    return datetime.now(timezone.utc)


class UUIDPrimaryKeyMixin:
    """Provides a primary key string column populated with unique UUIDs."""

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=generate_uuid,
        index=True,
    )


class TimestampMixin:
    """Provides automatic created_at and updated_at UTC timestamps."""

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        server_default=func.now(),
        onupdate=utc_now,
        nullable=False,
    )


class OwnerMixin:
    """Provides owner_id scoping for legacy single-user compatibility."""

    owner_id: Mapped[str] = mapped_column(
        String(64),
        default="local_user",
        server_default="local_user",
        nullable=False,
        index=True,
    )


class ProfileMixin:
    """Requires explicit profile ownership for personal-data writes (PC-IDENTITY-002)."""

    profile_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )


from sqlalchemy import event


@event.listens_for(OwnerMixin, "init", propagate=True)
def _set_owner_default(target, args, kwargs):
    kwargs.setdefault("owner_id", "local_user")


class SoftDeleteMixin:
    """Provides soft deletion state and timestamp for client-side deletion safety (Section 16.1)."""

    is_deleted: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default=func.false(),
        nullable=False,
        index=True,
    )
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        default=None,
        nullable=True,
        index=True,
    )

