"""Profile SQLAlchemy ORM model definition (PC-IDENTITY-001)."""

from datetime import datetime
from typing import Optional
from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import SoftDeleteMixin, TimestampMixin, UUIDPrimaryKeyMixin

DEFAULT_PROFILE_ID: str = "00000000-0000-4000-8000-000000000001"


class Profile(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    """User Profile entity providing the root ownership context for all personal data."""

    __tablename__ = "profiles"

    name: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="Default Profile",
        server_default="Default Profile",
    )
    avatar_url: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    pin_hash: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    is_default: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="0",
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="active",
        server_default="active",
        index=True,
    )
    purge_after: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
    )

    def __init__(
        self,
        id: Optional[str] = None,
        name: str = "Default Profile",
        avatar_url: Optional[str] = None,
        pin_hash: Optional[str] = None,
        is_default: bool = False,
        status: str = "active",
        **kwargs,
    ):
        super().__init__(**kwargs)
        if id is not None:
            self.id = id
        self.name = name
        self.avatar_url = avatar_url
        self.pin_hash = pin_hash
        self.is_default = is_default
        self.status = status
        self.is_deleted = kwargs.get("is_deleted", False)
        self.deleted_at = kwargs.get("deleted_at", None)
        self.purge_after = kwargs.get("purge_after", None)

    def __repr__(self) -> str:
        return f"<Profile id={self.id!r} name={self.name!r} is_default={self.is_default} status={self.status!r}>"


from sqlalchemy import event, text


@event.listens_for(Profile.__table__, "after_create")
def _insert_default_profile_after_create(target, connection, **kw):
    connection.execute(
        text(
            f"INSERT OR IGNORE INTO profiles "
            f"(id, created_at, updated_at, name, is_default, status, is_deleted) "
            f"VALUES ('{DEFAULT_PROFILE_ID}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'Default Profile', 1, 'active', 0)"
        )
    )
