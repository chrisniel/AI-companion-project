"""Memory SQLAlchemy ORM model definition."""

from datetime import datetime
from typing import Optional
import sqlalchemy as sa
from sqlalchemy import Boolean, CheckConstraint, DateTime, Float, ForeignKey, Index, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import (
    OwnerMixin,
    ProfileMixin,
    SoftDeleteMixin,
    TimestampMixin,
    UUIDPrimaryKeyMixin,
)


class Memory(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin):
    """User fact, preference, or context memory indexed in FTS5."""

    __tablename__ = "memories"

    category: Mapped[str] = mapped_column(String(32), nullable=False, default="fact", server_default="fact")
    content: Mapped[str] = mapped_column(Text, nullable=False)
    importance: Mapped[float] = mapped_column(Float, nullable=False, default=1.0, server_default="1.0")
    source_type: Mapped[str] = mapped_column(String(32), nullable=False, default="manual", server_default="manual")
    source_message_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    user_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=sa.text("1"))

    # M3 Batch C1: Scoping, Temporal Validity & Core Fact Flags
    scope: Mapped[str] = mapped_column(String(16), nullable=False, default="profile", server_default="profile")
    character_instance_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("character_instances.id", ondelete="RESTRICT"),
        nullable=True,
    )
    valid_from: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=func.now(),
        server_default=func.now(),
    )
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    is_core: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=sa.text("0"),
    )

    __table_args__ = (
        CheckConstraint("scope IN ('profile', 'character')", name="ck_memories_scope"),
        CheckConstraint(
            "(scope = 'profile' AND character_instance_id IS NULL) OR (scope = 'character' AND character_instance_id IS NOT NULL)",
            name="ck_memories_character_scope",
        ),
        CheckConstraint("expires_at IS NULL OR expires_at >= valid_from", name="ck_memories_validity"),
        Index("ix_memories_profile_scope", "profile_id", "scope", "deleted_at"),
        Index("ix_memories_character_instance_id", "character_instance_id"),
        Index("ix_memories_expires_at", "expires_at", "deleted_at"),
        Index("ix_memories_is_core", "profile_id", "is_core", "deleted_at"),
    )

    def __repr__(self) -> str:
        return f"<Memory id={self.id} scope={self.scope} category={self.category} is_core={self.is_core}>"
