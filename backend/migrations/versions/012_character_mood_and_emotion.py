"""Add persistent mood and emotion state columns to character_instances (PC-CHAR-003).

Revision ID: 012_character_mood_and_emotion
Revises: 011_profile_memory_extraction_toggle
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "012_character_mood_and_emotion"
down_revision: Union[str, None] = "011_profile_memory_extraction_toggle"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

naming_convention = {
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
    "ix": "ix_%(table_name)s_%(column_0_name)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
}

MOOD_CHECK_SQL = """(
    is_legacy_placeholder = 0
    AND current_mood IS NOT NULL
    AND current_mood IN ('calm', 'cheerful', 'playful', 'thoughtful', 'empathetic', 'curious', 'attentive')
    AND mood_intensity IS NOT NULL
    AND mood_intensity BETWEEN 0 AND 100
) OR (
    is_legacy_placeholder = 1
    AND current_mood IS NULL
    AND mood_intensity IS NULL
    AND mood_updated_at IS NULL
)"""

TRIGGERS_TO_CYCLE = (
    "trg_character_instances_immutable_provenance",
    "trg_character_instances_deactivate_clear_profile",
    "trg_profiles_active_character_owner_insert",
    "trg_profiles_active_character_owner_update",
    "trg_conversations_character_owner_insert",
)


def _drop_dependent_triggers_and_partial_index() -> None:
    for trg in TRIGGERS_TO_CYCLE:
        op.execute(f"DROP TRIGGER IF EXISTS {trg};")
    op.drop_index("uq_character_instances_profile_legacy_id", table_name="character_instances")


def _restore_dependent_triggers_and_partial_index() -> None:
    op.create_index(
        "uq_character_instances_profile_legacy_id",
        "character_instances",
        ["profile_id", "legacy_character_id"],
        unique=True,
        sqlite_where=sa.text("is_legacy_placeholder = 1"),
    )

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


def upgrade() -> None:
    conn = op.get_bind()
    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(f"Migration 012 refused: existing foreign key violations ({violations})")

    # 1. Add nullable mood columns first so existing rows can be deterministically backfilled
    op.add_column("character_instances", sa.Column("current_mood", sa.String(32), nullable=True))
    op.add_column("character_instances", sa.Column("mood_intensity", sa.Integer(), nullable=True))
    op.add_column("character_instances", sa.Column("mood_updated_at", sa.DateTime(timezone=True), nullable=True))

    # 2. Backfill standard instances to calm / 50 and legacy placeholders to NULL
    op.execute("""
        UPDATE character_instances
        SET current_mood = 'calm',
            mood_intensity = 50,
            mood_updated_at = CURRENT_TIMESTAMP
        WHERE is_legacy_placeholder = 0;
    """)
    op.execute("""
        UPDATE character_instances
        SET current_mood = NULL,
            mood_intensity = NULL,
            mood_updated_at = NULL
        WHERE is_legacy_placeholder = 1;
    """)

    # 3. Cycle triggers and partial index during batch table recreation to attach mood CHECK constraint
    _drop_dependent_triggers_and_partial_index()

    with op.batch_alter_table("character_instances", naming_convention=naming_convention) as batch_op:
        batch_op.create_check_constraint(
            "ck_character_instances_mood_invariants",
            MOOD_CHECK_SQL,
        )

    _restore_dependent_triggers_and_partial_index()

    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(f"Foreign key violations detected after migration 012: {violations}")


def downgrade() -> None:
    conn = op.get_bind()
    _drop_dependent_triggers_and_partial_index()

    with op.batch_alter_table("character_instances", naming_convention=naming_convention) as batch_op:
        batch_op.drop_constraint("ck_character_instances_mood_invariants", type_="check")
        batch_op.drop_column("mood_updated_at")
        batch_op.drop_column("mood_intensity")
        batch_op.drop_column("current_mood")

    _restore_dependent_triggers_and_partial_index()

    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(f"Foreign key violations detected after migration 012 downgrade: {violations}")
