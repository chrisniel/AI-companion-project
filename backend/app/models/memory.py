"""Memory SQLAlchemy ORM model definition."""

from datetime import datetime
import json
from typing import List, Optional
import sqlalchemy as sa
from sqlalchemy import Boolean, CheckConstraint, DateTime, Float, ForeignKey, Index, Integer, String, Text, func
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

    # M3 Batch E: Keyword-Triggered Lorebooks & Recall Tracking
    trigger_keywords: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    recall_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )

    __table_args__ = (
        CheckConstraint("scope IN ('profile', 'character')", name="ck_memories_scope"),
        CheckConstraint(
            "(scope = 'profile' AND character_instance_id IS NULL) OR (scope = 'character' AND character_instance_id IS NOT NULL)",
            name="ck_memories_character_scope",
        ),
        CheckConstraint("expires_at IS NULL OR expires_at >= valid_from", name="ck_memories_validity"),
        CheckConstraint("recall_count >= 0", name="ck_memories_recall_count"),
        Index("ix_memories_profile_scope", "profile_id", "scope", "deleted_at"),
        Index("ix_memories_character_instance_id", "character_instance_id"),
        Index("ix_memories_expires_at", "expires_at", "deleted_at"),
        Index("ix_memories_is_core", "profile_id", "is_core", "deleted_at"),
    )

    @property
    def trigger_keywords_list(self) -> List[str]:
        """Parse stored JSON array of trigger keywords cleanly."""
        if not self.trigger_keywords:
            return []
        try:
            parsed = json.loads(self.trigger_keywords)
            if isinstance(parsed, list):
                return [str(k).strip() for k in parsed if str(k).strip()]
        except Exception:
            pass
        return [k.strip() for k in self.trigger_keywords.split(",") if k.strip()]

    @property
    def is_short_term(self) -> bool:
        """True when record holds temporary situational context with TTL or non-core context category."""
        if self.expires_at is not None:
            return True
        return self.category == "context" and not self.is_core and not bool(self.trigger_keywords_list)

    @property
    def is_fixed_knowledge(self) -> bool:
        """True when record belongs to locked Tier 1 Knowledge Base & User Profile."""
        if self.is_short_term:
            return False
        return self.is_core or self.source_type == "manual" or bool(self.trigger_keywords_list)

    @property
    def is_long_term(self) -> bool:
        """True when record is durable semantic/episodic Tier 2 memory."""
        return not self.is_short_term and not self.is_fixed_knowledge

    @property
    def tier(self) -> str:
        """Mutually exclusive tier classification: knowledge | long_term | short_term."""
        if self.is_short_term:
            return "short_term"
        if self.is_fixed_knowledge:
            return "knowledge"
        return "long_term"

    def __repr__(self) -> str:
        return f"<Memory id={self.id} scope={self.scope} category={self.category} is_core={self.is_core}>"
