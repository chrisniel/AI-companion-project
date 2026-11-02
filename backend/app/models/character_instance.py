"""CharacterInstance SQLAlchemy ORM model definition (PC-CHAR-001, PC-CHAR-005)."""

from typing import Optional
from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import SoftDeleteMixin, TimestampMixin


class CharacterInstance(Base, TimestampMixin, SoftDeleteMixin):
    """Profile-owned mutable character snapshot initialized from a template or legacy conversation."""

    __tablename__ = "character_instances"
    __table_args__ = (
        UniqueConstraint("id", "profile_id", name="uq_character_instances_id_profile"),
        CheckConstraint("id NOT IN ('default', 'neutral-assistant')", name="ck_character_instances_not_reserved_id"),
        CheckConstraint("status IN ('active', 'archived')", name="ck_character_instances_status"),
        CheckConstraint("is_deleted IN (0, 1)", name="ck_character_instances_deleted_bool"),
        CheckConstraint("is_legacy_placeholder IN (0, 1)", name="ck_character_instances_legacy_bool"),
        CheckConstraint(
            """(
                is_legacy_placeholder = 0
                AND legacy_character_id IS NULL
                AND template_id IS NOT NULL
                AND template_id NOT IN ('neutral-assistant', 'default')
                AND source_template_version IS NOT NULL
                AND source_template_version >= 1
                AND preset_id IS NOT NULL
                AND preset_id IN ('custom', 'warm_companion', 'playful', 'formal_advisor', 'tsundere', 'kuudere', 'dandere', 'yandere')
                AND warmth IS NOT NULL AND warmth BETWEEN 0 AND 100
                AND teasing IS NOT NULL AND teasing BETWEEN 0 AND 100
                AND guardedness IS NOT NULL AND guardedness BETWEEN 0 AND 100
                AND directness IS NOT NULL AND directness BETWEEN 0 AND 100
                AND expressiveness IS NOT NULL AND expressiveness BETWEEN 0 AND 100
                AND affection IS NOT NULL AND affection BETWEEN 0 AND 100
                AND formality IS NOT NULL AND formality BETWEEN 0 AND 100
                AND verbosity IS NOT NULL AND verbosity BETWEEN 0 AND 100
            ) OR (
                is_legacy_placeholder = 1
                AND legacy_character_id IS NOT NULL
                AND legacy_character_id NOT IN ('default', 'neutral-assistant')
                AND template_id IS NULL
                AND source_template_version IS NULL
                AND preset_id IS NULL
                AND status = 'archived'
                AND lore = ''
                AND system_prompt = ''
                AND warmth IS NULL AND teasing IS NULL AND guardedness IS NULL AND directness IS NULL
                AND expressiveness IS NULL AND affection IS NULL AND formality IS NULL AND verbosity IS NULL
            )""",
            name="ck_character_instances_legacy_or_standard",
        ),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    profile_id: Mapped[str] = mapped_column(String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    is_legacy_placeholder: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="0")
    legacy_character_id: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    template_id: Mapped[Optional[str]] = mapped_column(String(64), ForeignKey("character_templates.id", ondelete="RESTRICT"), nullable=True, index=True)
    source_template_version: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    summary: Mapped[str] = mapped_column(String(500), nullable=False, default="", server_default="")
    lore: Mapped[str] = mapped_column(Text, nullable=False, default="", server_default="")
    system_prompt: Mapped[str] = mapped_column(Text, nullable=False, default="", server_default="")
    avatar_asset: Mapped[str] = mapped_column(String(255), nullable=False, default="default_avatar", server_default="default_avatar")
    preset_id: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)

    # 8 personality traits (0-100; NULL for legacy placeholders)
    warmth: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    teasing: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    guardedness: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    directness: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    expressiveness: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    affection: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    formality: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    verbosity: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    status: Mapped[str] = mapped_column(String(32), nullable=False, default="active", server_default="active")

    def __repr__(self) -> str:
        return f"<CharacterInstance id={self.id!r} profile_id={self.profile_id!r} name={self.name!r} status={self.status!r}>"
