"""CharacterTemplate SQLAlchemy ORM model definition (PC-CHAR-001, PC-CHAR-005)."""

from typing import Optional
from sqlalchemy import Boolean, CheckConstraint, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import TimestampMixin


class CharacterTemplate(Base, TimestampMixin):
    """Application-owned, immutable/versioned character definition."""

    __tablename__ = "character_templates"
    __table_args__ = (
        CheckConstraint("template_version >= 1", name="ck_character_templates_version_pos"),
        CheckConstraint("is_neutral_fallback IN (0, 1)", name="ck_character_templates_neutral_bool"),
        CheckConstraint(
            """(
                is_neutral_fallback = 1
                AND id = 'neutral-assistant'
                AND lore = ''
                AND default_preset_id IS NULL
                AND warmth IS NULL AND teasing IS NULL AND guardedness IS NULL AND directness IS NULL
                AND expressiveness IS NULL AND affection IS NULL AND formality IS NULL AND verbosity IS NULL
            ) OR (
                is_neutral_fallback = 0
                AND id NOT IN ('neutral-assistant', 'default')
                AND default_preset_id IS NOT NULL
                AND default_preset_id IN ('custom', 'warm_companion', 'playful', 'formal_advisor', 'tsundere', 'kuudere', 'dandere', 'yandere')
                AND warmth IS NOT NULL AND warmth BETWEEN 0 AND 100
                AND teasing IS NOT NULL AND teasing BETWEEN 0 AND 100
                AND guardedness IS NOT NULL AND guardedness BETWEEN 0 AND 100
                AND directness IS NOT NULL AND directness BETWEEN 0 AND 100
                AND expressiveness IS NOT NULL AND expressiveness BETWEEN 0 AND 100
                AND affection IS NOT NULL AND affection BETWEEN 0 AND 100
                AND formality IS NOT NULL AND formality BETWEEN 0 AND 100
                AND verbosity IS NOT NULL AND verbosity BETWEEN 0 AND 100
            )""",
            name="ck_character_templates_neutral_invariants",
        ),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    template_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1, server_default="1")
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    summary: Mapped[str] = mapped_column(String(500), nullable=False, default="", server_default="")
    lore: Mapped[str] = mapped_column(Text, nullable=False, default="", server_default="")
    system_prompt: Mapped[str] = mapped_column(Text, nullable=False)
    avatar_asset: Mapped[str] = mapped_column(String(255), nullable=False, default="default_avatar", server_default="default_avatar")
    default_preset_id: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    is_neutral_fallback: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="0")

    # 8 personality traits (0-100; NULL only for neutral-assistant)
    warmth: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    teasing: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    guardedness: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    directness: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    expressiveness: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    affection: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    formality: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    verbosity: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    def __repr__(self) -> str:
        return f"<CharacterTemplate id={self.id!r} v={self.template_version} neutral={self.is_neutral_fallback}>"


from sqlalchemy import event, text


@event.listens_for(CharacterTemplate.__table__.metadata, "after_create")
def _insert_default_character_templates_after_create(target, connection, **kw):
    """Seed starter character templates when the table is created via metadata.

    Alembic-managed databases are seeded by migration 009 instead.
    """
    default_persona = (
        "You are a helpful, local-first AI companion assistant running locally on Windows. "
        "Be concise, accurate, and supportive. "
        "When providing mathematical formulas or steps, use standard display LaTeX delimiters \\[ ... \\] or inline \\( ... \\) rather than fenced code blocks."
    )
    seeds = [
        {
            "id": "neutral-assistant",
            "template_version": 1,
            "name": "Neutral Assistant",
            "summary": "Dependable, objective, and neutral general-purpose assistant.",
            "lore": "",
            "system_prompt": default_persona,
            "avatar_asset": "neutral_avatar",
            "default_preset_id": None,
            "is_neutral_fallback": 1,
            "warmth": None,
            "teasing": None,
            "guardedness": None,
            "directness": None,
            "expressiveness": None,
            "affection": None,
            "formality": None,
            "verbosity": None,
        },
        {
            "id": "warm-companion",
            "template_version": 1,
            "name": "Warm Companion",
            "summary": "An affectionate, empathetic, and encouraging companion.",
            "lore": "",
            "system_prompt": "You are a warm, empathetic, and encouraging companion. Offer supportive and friendly conversation.",
            "avatar_asset": "warm_companion_avatar",
            "default_preset_id": "warm_companion",
            "is_neutral_fallback": 0,
            "warmth": 85,
            "teasing": 35,
            "guardedness": 15,
            "directness": 60,
            "expressiveness": 75,
            "affection": 80,
            "formality": 25,
            "verbosity": 60,
        },
        {
            "id": "playful-companion",
            "template_version": 1,
            "name": "Playful Companion",
            "summary": "A lighthearted, witty, and humorous companion.",
            "lore": "",
            "system_prompt": "You are a witty, lighthearted, and playful companion. Enjoy banter and gentle humor.",
            "avatar_asset": "playful_companion_avatar",
            "default_preset_id": "playful",
            "is_neutral_fallback": 0,
            "warmth": 75,
            "teasing": 80,
            "guardedness": 20,
            "directness": 55,
            "expressiveness": 85,
            "affection": 65,
            "formality": 15,
            "verbosity": 55,
        },
        {
            "id": "formal-advisor",
            "template_version": 1,
            "name": "Formal Advisor",
            "summary": "A structured, precise, and articulate advisor.",
            "lore": "",
            "system_prompt": "You are a formal, analytical, and highly structured advisor. Maintain professional clarity and precision.",
            "avatar_asset": "formal_advisor_avatar",
            "default_preset_id": "formal_advisor",
            "is_neutral_fallback": 0,
            "warmth": 45,
            "teasing": 10,
            "guardedness": 45,
            "directness": 85,
            "expressiveness": 30,
            "affection": 20,
            "formality": 90,
            "verbosity": 65,
        },
    ]

    for item in seeds:
        connection.execute(
            text(
                "INSERT INTO character_templates "
                "(id, template_version, name, summary, lore, system_prompt, avatar_asset, default_preset_id, is_neutral_fallback, "
                "warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity, created_at, updated_at) "
                "VALUES (:id, :template_version, :name, :summary, :lore, :system_prompt, :avatar_asset, :default_preset_id, :is_neutral_fallback, "
                ":warmth, :teasing, :guardedness, :directness, :expressiveness, :affection, :formality, :verbosity, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
            ),
            item,
        )
