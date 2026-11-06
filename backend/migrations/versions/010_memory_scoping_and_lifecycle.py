"""Add memory scoping, character instance association, and temporal validity lifecycle.

Revision ID: 010_memory_scoping_and_lifecycle
Revises: 009_character_foundation
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "010_memory_scoping_and_lifecycle"
down_revision: Union[str, None] = "009_character_foundation"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

naming_convention = {
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
    "ix": "ix_%(table_name)s_%(column_0_name)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
}


def upgrade() -> None:
    # 1. Cycle FTS5 triggers to allow table schema mutation without triggering FTS desync
    op.execute("DROP TRIGGER IF EXISTS memories_fts_insert;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_update;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_delete;")

    # 2. Batch alter memories table
    with op.batch_alter_table("memories", naming_convention=naming_convention) as batch_op:
        batch_op.add_column(
            sa.Column("scope", sa.String(16), nullable=False, server_default="profile")
        )
        batch_op.add_column(
            sa.Column("character_instance_id", sa.String(36), nullable=True)
        )
        batch_op.add_column(
            sa.Column("valid_from", sa.DateTime(timezone=True), nullable=True)
        )
        batch_op.add_column(
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True)
        )
        batch_op.add_column(
            sa.Column("last_verified_at", sa.DateTime(timezone=True), nullable=True)
        )
        batch_op.add_column(
            sa.Column("is_core", sa.Boolean(), nullable=False, server_default=sa.text("0"))
        )

        batch_op.create_foreign_key(
            "fk_memories_character_instance_id_character_instances",
            "character_instances",
            ["character_instance_id"],
            ["id"],
            ondelete="RESTRICT",
        )

        batch_op.create_index("ix_memories_profile_scope", ["profile_id", "scope", "deleted_at"])
        batch_op.create_index("ix_memories_character_instance_id", ["character_instance_id"])
        batch_op.create_index("ix_memories_expires_at", ["expires_at", "deleted_at"])
        batch_op.create_index("ix_memories_is_core", ["profile_id", "is_core", "deleted_at"])

        batch_op.create_check_constraint(
            "ck_memories_scope",
            "scope IN ('profile', 'character')",
        )
        batch_op.create_check_constraint(
            "ck_memories_character_scope",
            "(scope = 'profile' AND character_instance_id IS NULL) OR (scope = 'character' AND character_instance_id IS NOT NULL)",
        )
        batch_op.create_check_constraint(
            "ck_memories_validity",
            "expires_at IS NULL OR expires_at >= valid_from",
        )

    # 3. Backfill valid_from from created_at for all pre-existing records
    op.execute("UPDATE memories SET valid_from = created_at WHERE valid_from IS NULL;")

    # 4. Recreate FTS5 triggers and rebuild index
    op.execute("""
        CREATE TRIGGER memories_fts_insert AFTER INSERT ON memories
        WHEN NEW.deleted_at IS NULL
        BEGIN
            INSERT INTO memories_fts(rowid, id, content, category)
            VALUES(NEW.rowid, NEW.id, NEW.content, NEW.category);
        END;
    """)

    op.execute("""
        CREATE TRIGGER memories_fts_update AFTER UPDATE ON memories
        BEGIN
            INSERT INTO memories_fts(memories_fts, rowid, id, content, category)
            VALUES('delete', OLD.rowid, OLD.id, OLD.content, OLD.category);
            INSERT INTO memories_fts(rowid, id, content, category)
            SELECT NEW.rowid, NEW.id, NEW.content, NEW.category
            WHERE NEW.deleted_at IS NULL;
        END;
    """)

    op.execute("""
        CREATE TRIGGER memories_fts_delete AFTER DELETE ON memories
        BEGIN
            INSERT INTO memories_fts(memories_fts, rowid, id, content, category)
            VALUES('delete', OLD.rowid, OLD.id, OLD.content, OLD.category);
        END;
    """)

    op.execute("INSERT INTO memories_fts(memories_fts) VALUES('rebuild');")

    # 5. Foreign key verification
    conn = op.get_bind()
    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(f"Foreign key violations detected after migration 010: {violations}")


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS memories_fts_insert;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_update;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_delete;")

    op.drop_index("ix_memories_is_core", table_name="memories")
    op.drop_index("ix_memories_expires_at", table_name="memories")
    op.drop_index("ix_memories_character_instance_id", table_name="memories")
    op.drop_index("ix_memories_profile_scope", table_name="memories")

    with op.batch_alter_table("memories", naming_convention=naming_convention) as batch_op:
        batch_op.drop_constraint("ck_memories_validity", type_="check")
        batch_op.drop_constraint("ck_memories_character_scope", type_="check")
        batch_op.drop_constraint("ck_memories_scope", type_="check")
        batch_op.drop_constraint("fk_memories_character_instance_id_character_instances", type_="foreignkey")

        batch_op.drop_column("is_core")
        batch_op.drop_column("last_verified_at")
        batch_op.drop_column("expires_at")
        batch_op.drop_column("valid_from")
        batch_op.drop_column("character_instance_id")
        batch_op.drop_column("scope")

    op.execute("""
        CREATE TRIGGER memories_fts_insert AFTER INSERT ON memories
        WHEN NEW.deleted_at IS NULL
        BEGIN
            INSERT INTO memories_fts(rowid, id, content, category)
            VALUES(NEW.rowid, NEW.id, NEW.content, NEW.category);
        END;
    """)

    op.execute("""
        CREATE TRIGGER memories_fts_update AFTER UPDATE ON memories
        BEGIN
            INSERT INTO memories_fts(memories_fts, rowid, id, content, category)
            VALUES('delete', OLD.rowid, OLD.id, OLD.content, OLD.category);
            INSERT INTO memories_fts(rowid, id, content, category)
            SELECT NEW.rowid, NEW.id, NEW.content, NEW.category
            WHERE NEW.deleted_at IS NULL;
        END;
    """)

    op.execute("""
        CREATE TRIGGER memories_fts_delete AFTER DELETE ON memories
        BEGIN
            INSERT INTO memories_fts(memories_fts, rowid, id, content, category)
            VALUES('delete', OLD.rowid, OLD.id, OLD.content, OLD.category);
        END;
    """)

    op.execute("INSERT INTO memories_fts(memories_fts) VALUES('rebuild');")
