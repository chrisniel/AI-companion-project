"""Add character templates, profile-owned character instances, and neutral assistant fallback.

Revision ID: 009_character_foundation
Revises: 008_profile_sessions_and_tickets
"""

import uuid
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "009_character_foundation"
down_revision: Union[str, None] = "008_profile_sessions_and_tickets"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

naming_convention = {
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
    "ix": "ix_%(table_name)s_%(column_0_name)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
}

LEGACY_CHARACTER_NAMESPACE = uuid.UUID("7f9c2e14-6b5a-4d3e-9a1c-8e2f4b6d0a91")

DEFAULT_PERSONA = (
    "You are a helpful, local-first AI companion assistant running locally on Windows. "
    "Be concise, accurate, and supportive. "
    "When providing mathematical formulas or steps, use standard display LaTeX delimiters \\[ ... \\] or inline \\( ... \\) rather than fenced code blocks."
)

ALLOWED_PRESETS = (
    "custom",
    "warm_companion",
    "playful",
    "formal_advisor",
    "tsundere",
    "kuudere",
    "dandere",
    "yandere",
)


def derive_legacy_instance_id(profile_id: str, legacy_character_id: str) -> str:
    canonical = f"{len(profile_id)}:{profile_id}|{len(legacy_character_id)}:{legacy_character_id}"
    return f"legacy-{uuid.uuid5(LEGACY_CHARACTER_NAMESPACE, canonical)}"


def upgrade() -> None:
    conn = op.get_bind()
    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(f"Migration 009 refused: existing foreign key violations ({violations})")

    # 1. Create character_templates table
    op.create_table(
        "character_templates",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("template_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("summary", sa.String(500), nullable=False, server_default=""),
        sa.Column("lore", sa.Text(), nullable=False, server_default=""),
        sa.Column("system_prompt", sa.Text(), nullable=False),
        sa.Column("avatar_asset", sa.String(255), nullable=False, server_default="default_avatar"),
        sa.Column("default_preset_id", sa.String(32), nullable=True),
        sa.Column("is_neutral_fallback", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("warmth", sa.Integer(), nullable=True),
        sa.Column("teasing", sa.Integer(), nullable=True),
        sa.Column("guardedness", sa.Integer(), nullable=True),
        sa.Column("directness", sa.Integer(), nullable=True),
        sa.Column("expressiveness", sa.Integer(), nullable=True),
        sa.Column("affection", sa.Integer(), nullable=True),
        sa.Column("formality", sa.Integer(), nullable=True),
        sa.Column("verbosity", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("template_version >= 1", name="ck_character_templates_version_pos"),
        sa.CheckConstraint("is_neutral_fallback IN (0, 1)", name="ck_character_templates_neutral_bool"),
        sa.CheckConstraint(
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
    op.create_index(
        "uq_character_templates_single_neutral",
        "character_templates",
        ["is_neutral_fallback"],
        unique=True,
        sqlite_where=sa.text("is_neutral_fallback = 1"),
    )

    # 2. Seed character_templates
    seed_templates = [
        {
            "id": "neutral-assistant",
            "template_version": 1,
            "name": "Neutral Assistant",
            "summary": "Objective, dependable system assistant fallback.",
            "lore": "",
            "system_prompt": DEFAULT_PERSONA,
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
    for tmpl in seed_templates:
        conn.execute(
            sa.text("""
                INSERT INTO character_templates (
                    id, template_version, name, summary, lore, system_prompt, avatar_asset,
                    default_preset_id, is_neutral_fallback,
                    warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                    created_at, updated_at
                ) VALUES (
                    :id, :template_version, :name, :summary, :lore, :system_prompt, :avatar_asset,
                    :default_preset_id, :is_neutral_fallback,
                    :warmth, :teasing, :guardedness, :directness, :expressiveness, :affection, :formality, :verbosity,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                )
            """),
            tmpl,
        )

    # 3. Create character_instances table
    op.create_table(
        "character_instances",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("profile_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("is_legacy_placeholder", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("legacy_character_id", sa.String(64), nullable=True),
        sa.Column("template_id", sa.String(64), sa.ForeignKey("character_templates.id", ondelete="RESTRICT"), nullable=True),
        sa.Column("source_template_version", sa.Integer(), nullable=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("summary", sa.String(500), nullable=False, server_default=""),
        sa.Column("lore", sa.Text(), nullable=False, server_default=""),
        sa.Column("system_prompt", sa.Text(), nullable=False, server_default=""),
        sa.Column("avatar_asset", sa.String(255), nullable=False, server_default="default_avatar"),
        sa.Column("preset_id", sa.String(32), nullable=True),
        sa.Column("warmth", sa.Integer(), nullable=True),
        sa.Column("teasing", sa.Integer(), nullable=True),
        sa.Column("guardedness", sa.Integer(), nullable=True),
        sa.Column("directness", sa.Integer(), nullable=True),
        sa.Column("expressiveness", sa.Integer(), nullable=True),
        sa.Column("affection", sa.Integer(), nullable=True),
        sa.Column("formality", sa.Integer(), nullable=True),
        sa.Column("verbosity", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(32), nullable=False, server_default="active"),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("id", "profile_id", name="uq_character_instances_id_profile"),
        sa.CheckConstraint("id NOT IN ('default', 'neutral-assistant')", name="ck_character_instances_not_reserved_id"),
        sa.CheckConstraint("status IN ('active', 'archived')", name="ck_character_instances_status"),
        sa.CheckConstraint("is_deleted IN (0, 1)", name="ck_character_instances_deleted_bool"),
        sa.CheckConstraint("is_legacy_placeholder IN (0, 1)", name="ck_character_instances_legacy_bool"),
        sa.CheckConstraint(
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
    op.create_index("ix_character_instances_profile_id", "character_instances", ["profile_id"])
    op.create_index("ix_character_instances_template_id", "character_instances", ["template_id"])
    op.create_index("ix_character_instances_is_deleted", "character_instances", ["is_deleted"])
    op.create_index(
        "uq_character_instances_profile_legacy_id",
        "character_instances",
        ["profile_id", "legacy_character_id"],
        unique=True,
        sqlite_where=sa.text("is_legacy_placeholder = 1"),
    )

    # 4. Backfill legacy non-neutral conversations into explicit legacy placeholders
    legacy_conversations = conn.execute(sa.text("""
        SELECT DISTINCT profile_id, character_id
        FROM conversations
        WHERE character_id NOT IN ('default', 'neutral-assistant')
    """)).fetchall()

    legacy_map = {}
    for profile_id, character_id in legacy_conversations:
        instance_id = derive_legacy_instance_id(profile_id, character_id)
        legacy_map[(profile_id, character_id)] = instance_id
        conn.execute(
            sa.text("""
                INSERT INTO character_instances (
                    id, profile_id, is_legacy_placeholder, legacy_character_id,
                    template_id, source_template_version, name, summary, lore, system_prompt,
                    avatar_asset, preset_id,
                    warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                    status, is_deleted, deleted_at, created_at, updated_at
                ) VALUES (
                    :id, :profile_id, 1, :legacy_character_id,
                    NULL, NULL, :name, 'Legacy conversation character placeholder', '', '',
                    'default_avatar', NULL,
                    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                    'archived', 0, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                )
            """),
            {
                "id": instance_id,
                "profile_id": profile_id,
                "legacy_character_id": character_id,
                "name": character_id,
            },
        )

    # 5. Add character_instance_id to conversations
    with op.batch_alter_table("conversations", naming_convention=naming_convention) as batch_op:
        batch_op.add_column(
            sa.Column(
                "character_instance_id",
                sa.String(64),
                sa.ForeignKey(
                    "character_instances.id",
                    ondelete="RESTRICT",
                    name="fk_conversations_character_instance_id_character_instances",
                ),
                nullable=True,
            )
        )
        batch_op.create_index("ix_conversations_character_instance_id", ["character_instance_id"])

    # Update conversations with backfilled legacy instances
    for (profile_id, character_id), instance_id in legacy_map.items():
        conn.execute(
            sa.text("""
                UPDATE conversations
                SET character_instance_id = :instance_id
                WHERE profile_id = :profile_id AND character_id = :character_id
            """),
            {
                "instance_id": instance_id,
                "profile_id": profile_id,
                "character_id": character_id,
            },
        )

    # 6. Add active_character_instance_id to profiles
    with op.batch_alter_table("profiles", naming_convention=naming_convention) as batch_op:
        batch_op.add_column(
            sa.Column(
                "active_character_instance_id",
                sa.String(64),
                sa.ForeignKey(
                    "character_instances.id",
                    ondelete="SET NULL",
                    name="fk_profiles_active_character_instance_id_character_instances",
                ),
                nullable=True,
            )
        )
        batch_op.create_index("ix_profiles_active_character_instance_id", ["active_character_instance_id"])

    # 7. Create defense-in-depth SQLite triggers
    op.execute("""
        CREATE TRIGGER trg_character_templates_protect_neutral_update
        BEFORE UPDATE ON character_templates
        FOR EACH ROW
        WHEN OLD.id = 'neutral-assistant' OR OLD.is_neutral_fallback = 1
        BEGIN
            SELECT RAISE(ABORT, 'immutable neutral-assistant fallback template cannot be modified or deleted');
        END;
    """)

    op.execute("""
        CREATE TRIGGER trg_character_templates_protect_neutral_delete
        BEFORE DELETE ON character_templates
        FOR EACH ROW
        WHEN OLD.id = 'neutral-assistant' OR OLD.is_neutral_fallback = 1
        BEGIN
            SELECT RAISE(ABORT, 'immutable neutral-assistant fallback template cannot be modified or deleted');
        END;
    """)

    op.execute("""
        CREATE TRIGGER trg_character_instances_immutable_provenance
        BEFORE UPDATE ON character_instances
        FOR EACH ROW
        WHEN NEW.profile_id IS NOT OLD.profile_id
          OR NEW.is_legacy_placeholder IS NOT OLD.is_legacy_placeholder
          OR NEW.legacy_character_id IS NOT OLD.legacy_character_id
          OR NEW.template_id IS NOT OLD.template_id
          OR NEW.source_template_version IS NOT OLD.source_template_version
        BEGIN
            SELECT RAISE(ABORT, 'character instance provenance and profile ownership are immutable');
        END;
    """)

    op.execute("""
        CREATE TRIGGER trg_profiles_active_character_owner_insert
        BEFORE INSERT ON profiles
        FOR EACH ROW
        WHEN NEW.active_character_instance_id IS NOT NULL
        BEGIN
            SELECT CASE
                WHEN NOT EXISTS (
                    SELECT 1 FROM character_instances ci
                    WHERE ci.id = NEW.active_character_instance_id
                      AND ci.profile_id = NEW.id
                      AND ci.status = 'active'
                      AND ci.is_deleted = 0
                      AND ci.is_legacy_placeholder = 0
                )
                THEN RAISE(ABORT, 'active_character_instance_id must reference an active, non-deleted, non-legacy CharacterInstance owned by the same Profile')
            END;
        END;
    """)

    op.execute("""
        CREATE TRIGGER trg_profiles_active_character_owner_update
        BEFORE UPDATE OF active_character_instance_id ON profiles
        FOR EACH ROW
        WHEN NEW.active_character_instance_id IS NOT NULL
        BEGIN
            SELECT CASE
                WHEN NOT EXISTS (
                    SELECT 1 FROM character_instances ci
                    WHERE ci.id = NEW.active_character_instance_id
                      AND ci.profile_id = NEW.id
                      AND ci.status = 'active'
                      AND ci.is_deleted = 0
                      AND ci.is_legacy_placeholder = 0
                )
                THEN RAISE(ABORT, 'active_character_instance_id must reference an active, non-deleted, non-legacy CharacterInstance owned by the same Profile')
            END;
        END;
    """)

    op.execute("""
        CREATE TRIGGER trg_character_instances_deactivate_clear_profile
        AFTER UPDATE ON character_instances
        WHEN NEW.status != 'active' OR NEW.is_deleted = 1
        BEGIN
            UPDATE profiles SET active_character_instance_id = NULL
            WHERE id = NEW.profile_id AND active_character_instance_id = NEW.id;
        END;
    """)

    op.execute("""
        CREATE TRIGGER trg_conversations_character_owner_insert
        BEFORE INSERT ON conversations
        FOR EACH ROW
        BEGIN
            SELECT CASE
                WHEN NEW.character_instance_id IS NULL
                     AND NEW.character_id NOT IN ('default', 'neutral-assistant')
                THEN RAISE(ABORT, 'non-neutral conversation requires a valid character_instance_id')
                WHEN NEW.character_instance_id IS NOT NULL
                     AND NOT EXISTS (
                         SELECT 1 FROM character_instances ci
                         WHERE ci.id = NEW.character_instance_id
                           AND ci.profile_id = NEW.profile_id
                           AND (
                               (ci.is_legacy_placeholder = 0 AND NEW.character_id = ci.id)
                               OR (ci.is_legacy_placeholder = 1 AND NEW.character_id = ci.legacy_character_id)
                           )
                     )
                THEN RAISE(ABORT, 'conversation character_instance_id must belong to the same Profile and match character_id or legacy_character_id')
            END;
        END;
    """)

    op.execute("""
        CREATE TRIGGER trg_conversations_character_immutable_update
        BEFORE UPDATE ON conversations
        FOR EACH ROW
        WHEN NEW.profile_id IS NOT OLD.profile_id
          OR NEW.character_id IS NOT OLD.character_id
          OR NEW.character_instance_id IS NOT OLD.character_instance_id
        BEGIN
            SELECT RAISE(ABORT, 'conversation character identity and profile ownership are permanently bound');
        END;
    """)

    # 8. Final verification
    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(f"Foreign key violations detected after migration 009: {violations}")


def downgrade() -> None:
    conn = op.get_bind()

    # Fail-closed check: refuse downgrade if user-created Character data exists or templates were altered
    user_instances = conn.execute(sa.text("SELECT COUNT(*) FROM character_instances WHERE is_legacy_placeholder = 0")).scalar() or 0
    if user_instances > 0:
        raise RuntimeError(
            f"Downgrade refused: {user_instances} user-created CharacterInstance(s) would be lost. "
            "Please restore from verified pre-migration backup instead."
        )

    active_selections = conn.execute(sa.text("SELECT COUNT(*) FROM profiles WHERE active_character_instance_id IS NOT NULL")).scalar() or 0
    if active_selections > 0:
        raise RuntimeError(
            f"Downgrade refused: {active_selections} profile(s) have an active character selection. "
            "Please restore from verified pre-migration backup instead."
        )

    template_count = conn.execute(sa.text("SELECT COUNT(*) FROM character_templates")).scalar() or 0
    if template_count != 4:
        raise RuntimeError(
            f"Downgrade refused: character_templates count is {template_count} (expected 4 seed templates). "
            "Please restore from verified pre-migration backup instead."
        )

    # 1. Drop triggers
    triggers = [
        "trg_character_templates_protect_neutral_update",
        "trg_character_templates_protect_neutral_delete",
        "trg_character_instances_immutable_provenance",
        "trg_profiles_active_character_owner_insert",
        "trg_profiles_active_character_owner_update",
        "trg_character_instances_deactivate_clear_profile",
        "trg_conversations_character_owner_insert",
        "trg_conversations_character_immutable_update",
    ]
    for trg in triggers:
        op.execute(f"DROP TRIGGER IF EXISTS {trg}")

    # 2. Drop indexes on columns about to be removed
    op.drop_index("ix_profiles_active_character_instance_id", table_name="profiles")
    op.drop_index("ix_conversations_character_instance_id", table_name="conversations")

    # 3. Drop active_character_instance_id from profiles
    with op.batch_alter_table("profiles", naming_convention=naming_convention) as batch_op:
        batch_op.drop_column("active_character_instance_id")

    # 4. Drop character_instance_id from conversations
    with op.batch_alter_table("conversations", naming_convention=naming_convention) as batch_op:
        batch_op.drop_column("character_instance_id")

    # 5. Drop tables
    op.drop_table("character_instances")
    op.drop_table("character_templates")
