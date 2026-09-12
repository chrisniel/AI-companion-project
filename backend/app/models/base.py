"""Base model mixins for UUID primary keys, timestamps, and owner isolation."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import DateTime, String, func
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
    """Provides owner_id scoping for OWASP API1 BOLA compliance."""

    owner_id: Mapped[str] = mapped_column(
        String(64),
        default="local_user",
        nullable=False,
        index=True,
    )
