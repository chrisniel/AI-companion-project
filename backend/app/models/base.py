"""Base model mixins for UUID primary keys, timestamps, and owner isolation."""

import uuid
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import Boolean, DateTime, ForeignKey, String, func, text
from sqlalchemy.orm import Mapped, mapped_column


def generate_uuid() -> str:
    """Generate a clean 32-character hexadecimal UUID string."""
    return uuid.uuid4().hex


def utc_now() -> datetime:
    """Return current timezone-aware UTC datetime."""
    return datetime.now(timezone.utc)


def resolve_default_profile_id(context) -> str:
    """Return THIS database's active Default Profile id (SQLAlchemy context-sensitive default).

    Executed on the same connection as the INSERT being prepared, so each installation/database
    resolves its own persisted Default Profile. Fails closed when none exists instead of
    inventing an identifier or writing a NULL.
    """
    row = context.connection.execute(
        text(
            "SELECT id FROM profiles "
            "WHERE is_default = 1 AND is_deleted = 0 AND status = 'active' "
            "ORDER BY created_at LIMIT 1"
        )
    ).first()
    if row is None:
        raise RuntimeError(
            "No active default Profile exists in this database; refusing to create an "
            "unowned record. Run database migrations to create the Default Profile."
        )
    return row[0]


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
    """Provides profile_id scoping for multi-profile isolation (PC-IDENTITY-001).

    During Batch A legacy compatibility the association is automatic: when a record is
    inserted without an explicit profile_id, it is attached to THIS database's Default
    Profile (looked up at insert time, never a hardcoded shared id). Migrated databases
    additionally carry a per-installation server_default for raw SQL inserts.
    """

    profile_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("profiles.id", ondelete="CASCADE"),
        default=resolve_default_profile_id,
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

