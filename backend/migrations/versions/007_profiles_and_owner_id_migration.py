"""Profiles and profile_id scoping migration with owner_id retention.

Revision ID: 007_profiles_and_owner_id_migration
Revises: 006_add_attachments
Create Date: 2026-10-12 16:00:00.000000

PC-IDENTITY-001: Profile Schema Foundation
- Creates `profiles` table and seeds Default Profile
- Strictly enforces the legacy owner allowlist (local_user, default_user); rejects unexpected/empty/NULL
- Adds `profile_id` NOT NULL with a per-installation server_default UUID and CASCADE FK
- Retains existing `owner_id` column for backward compatibility
- Safely cycles `memories_fts` triggers and rebuilds FTS5 index
- Enforces PRAGMA foreign_key_check
- Refuses downgrade if > 1 profile exists
"""
import uuid
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

from app.db.backup import MigrationAmbiguityError
from app.db.legacy_owner_validation import (
    APPROVED_LEGACY_OWNER_ALIASES,
    find_unapproved_owners,
)

# revision identifiers, used by Alembic.
revision: str = "007_profiles_and_owner_id_migration"
down_revision: Union[str, None] = "006_add_attachments"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

naming_convention = {
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
    "ix": "ix_%(table_name)s_%(column_0_name)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
}


def upgrade() -> None:
    conn = op.get_bind()

    # 1. Strictly validate legacy ownership BEFORE any schema change. Only the approved
    #    single-user aliases may map to the Default Profile; anything else (unexpected,
    #    empty, whitespace, case variants, NULL) refuses the migration with data untouched.
    tables_to_check = ["conversations", "messages", "memories", "tasks", "attachments"]
    offenders = find_unapproved_owners(conn, tables_to_check)
    if offenders:
        raise MigrationAmbiguityError(
            f"Ambiguous legacy ownership detected: {offenders!r}. "
            f"Only {sorted(APPROVED_LEGACY_OWNER_ALIASES)} may migrate to the Default Profile. "
            "No data was modified; resolve ownership explicitly before retrying."
        )

    # Unique identity for THIS installation/database (never shared across installs).
    default_profile_id = str(uuid.uuid4())

    # 2. Create profiles table
    op.create_table(
        "profiles",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("name", sa.String(32), nullable=False, server_default="Default Profile"),
        sa.Column("avatar_url", sa.String(255), nullable=True),
        sa.Column("pin_hash", sa.String(128), nullable=True),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(16), nullable=False, server_default="active"),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default="0"),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("purge_after", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_profiles_id", "profiles", ["id"])
    op.create_index("ix_profiles_is_default", "profiles", ["is_default"])
    op.create_index("ix_profiles_status", "profiles", ["status"])
    op.create_index("ix_profiles_is_deleted", "profiles", ["is_deleted"])
    op.create_index("ix_profiles_deleted_at", "profiles", ["deleted_at"])
    op.create_index("ix_profiles_purge_after", "profiles", ["purge_after"])
    op.create_index(
        "uq_profiles_single_default",
        "profiles",
        ["is_default"],
        unique=True,
        sqlite_where=sa.text("is_default = 1"),
    )

    # 3. Seed this installation's Default Profile (persisted; survives restart and backup)
    conn.execute(
        sa.text("""
            INSERT INTO profiles (
                id, created_at, updated_at, name, avatar_url, pin_hash,
                is_default, status, is_deleted, deleted_at, purge_after
            ) VALUES (
                :id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, :name, NULL, NULL,
                1, 'active', 0, NULL, NULL
            )
        """),
        {"id": default_profile_id, "name": "Default Profile"},
    )

    # 4. Batch alter conversations
    with op.batch_alter_table("conversations", naming_convention=naming_convention) as batch_op:
        batch_op.add_column(
            sa.Column(
                "profile_id",
                sa.String(36),
                nullable=False,
                server_default=default_profile_id,
            )
        )
        batch_op.create_foreign_key(
            "fk_conversations_profile_id_profiles",
            "profiles",
            ["profile_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.create_index("ix_conversations_profile_id", ["profile_id"])

    # 5. Batch alter messages
    with op.batch_alter_table("messages", naming_convention=naming_convention) as batch_op:
        batch_op.add_column(
            sa.Column(
                "profile_id",
                sa.String(36),
                nullable=False,
                server_default=default_profile_id,
            )
        )
        batch_op.create_foreign_key(
            "fk_messages_profile_id_profiles",
            "profiles",
            ["profile_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.create_index("ix_messages_profile_id", ["profile_id"])

    # 6. Batch alter tasks
    with op.batch_alter_table("tasks", naming_convention=naming_convention) as batch_op:
        batch_op.add_column(
            sa.Column(
                "profile_id",
                sa.String(36),
                nullable=False,
                server_default=default_profile_id,
            )
        )
        batch_op.create_foreign_key(
            "fk_tasks_profile_id_profiles",
            "profiles",
            ["profile_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.create_index("ix_tasks_profile_id", ["profile_id"])

    # 7. Batch alter attachments
    with op.batch_alter_table("attachments", naming_convention=naming_convention) as batch_op:
        batch_op.add_column(
            sa.Column(
                "profile_id",
                sa.String(36),
                nullable=False,
                server_default=default_profile_id,
            )
        )
        batch_op.create_foreign_key(
            "fk_attachments_profile_id_profiles",
            "profiles",
            ["profile_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.create_index("ix_attachments_profile_id", ["profile_id"])

    # 8. Batch alter memories with FTS5 trigger cycling
    op.execute("DROP TRIGGER IF EXISTS memories_fts_insert;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_update;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_delete;")

    with op.batch_alter_table("memories", naming_convention=naming_convention) as batch_op:
        batch_op.add_column(
            sa.Column(
                "profile_id",
                sa.String(36),
                nullable=False,
                server_default=default_profile_id,
            )
        )
        batch_op.create_foreign_key(
            "fk_memories_profile_id_profiles",
            "profiles",
            ["profile_id"],
            ["id"],
            ondelete="CASCADE",
        )
        batch_op.create_index("ix_memories_profile_id", ["profile_id"])

    # Recreate FTS5 triggers
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

    # Rebuild FTS5 index
    op.execute("INSERT INTO memories_fts(memories_fts) VALUES('rebuild');")

    # 9. Enforce foreign key check
    fk_violations = conn.execute(sa.text("PRAGMA foreign_key_check;")).fetchall()
    if fk_violations:
        raise RuntimeError(f"Foreign key violations detected after migration: {fk_violations}")


def downgrade() -> None:
    conn = op.get_bind()

    # Fail closed if multiple profiles exist
    profile_count = conn.execute(sa.text("SELECT COUNT(*) FROM profiles")).scalar()
    if profile_count is not None and profile_count > 1:
        raise RuntimeError(
            f"Downgrade refused: {profile_count} profiles exist. "
            "Cannot safely map multiple profiles back to single-user legacy state without data loss."
        )

    # 1. Drop profile_id from memories with trigger cycling
    op.execute("DROP TRIGGER IF EXISTS memories_fts_insert;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_update;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_delete;")

    with op.batch_alter_table("memories", naming_convention=naming_convention) as batch_op:
        batch_op.drop_index("ix_memories_profile_id")
        batch_op.drop_column("profile_id")

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

    # 2. Drop profile_id from attachments
    with op.batch_alter_table("attachments", naming_convention=naming_convention) as batch_op:
        batch_op.drop_index("ix_attachments_profile_id")
        batch_op.drop_column("profile_id")

    # 3. Drop profile_id from tasks
    with op.batch_alter_table("tasks", naming_convention=naming_convention) as batch_op:
        batch_op.drop_index("ix_tasks_profile_id")
        batch_op.drop_column("profile_id")

    # 4. Drop profile_id from messages
    with op.batch_alter_table("messages", naming_convention=naming_convention) as batch_op:
        batch_op.drop_index("ix_messages_profile_id")
        batch_op.drop_column("profile_id")

    # 5. Drop profile_id from conversations
    with op.batch_alter_table("conversations", naming_convention=naming_convention) as batch_op:
        batch_op.drop_index("ix_conversations_profile_id")
        batch_op.drop_column("profile_id")

    # 6. Drop profiles table
    op.drop_index("uq_profiles_single_default", table_name="profiles")
    op.drop_index("ix_profiles_purge_after", table_name="profiles")
    op.drop_index("ix_profiles_deleted_at", table_name="profiles")
    op.drop_index("ix_profiles_is_deleted", table_name="profiles")
    op.drop_index("ix_profiles_status", table_name="profiles")
    op.drop_index("ix_profiles_is_default", table_name="profiles")
    op.drop_index("ix_profiles_id", table_name="profiles")
    op.drop_table("profiles")
