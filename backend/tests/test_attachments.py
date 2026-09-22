"""Tests for Attachment persistence foundation, Migration 006, ORM parity, and relationships.

Covers Phase 8B.1:
- Migration 006 lifecycle: fresh head, 005 -> 006, downgrade, re-upgrade
- Schema validation: columns, nullability, FKs with ON DELETE CASCADE, server defaults, indexes
- ORM / Migration parity assertions
- Deterministic model metadata registration via clean subprocess
- ORM relationship mechanics (Conversation.attachments, Message.attachments, staged vs committed)
"""

import os
import subprocess
import sys
import tempfile
import sqlite3
from pathlib import Path
import pytest
from alembic.config import Config
from alembic import command
from sqlalchemy import inspect, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.db.base import Base
from app.models.attachment import Attachment
from app.models.conversation import Conversation
from app.models.message import Message

BACKEND_DIR = Path(__file__).resolve().parent.parent


def _get_alembic_config(db_path: Path) -> Config:
    """Build isolated Alembic config pointing to an ephemeral SQLite database."""
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


# ===========================================================================
# 1. Migration 006 Lifecycle & Structure Tests (Section 8)
# ===========================================================================

def test_migration_006_fresh_database_upgrade_to_head():
    """Test A: Fresh SQLite database upgrades cleanly to 006_add_attachments head."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "fresh_006.db"
        cfg = _get_alembic_config(db_path)

        command.upgrade(cfg, "head")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
        assert ver is not None and ver[0] == "006_add_attachments"

        # Verify attachments table exists
        tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
        assert "attachments" in tables

        conn.close()


def test_migration_006_upgrade_from_005_and_schema_inspection():
    """Test B, E, F, G: Upgrading 005 -> 006 establishes exact columns, FKs, defaults, and indexes."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "upgrade_005_to_006.db"
        cfg = _get_alembic_config(db_path)

        # Upgrade to 005 first
        command.upgrade(cfg, "005_scope_message_constraints")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
        assert ver[0] == "005_scope_message_constraints"
        conn.close()

        # Upgrade to 006
        command.upgrade(cfg, "006_add_attachments")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
        assert ver[0] == "006_add_attachments"

        # F. Column definitions and nullability inspection
        # PRAGMA table_info returns: (cid, name, type, notnull, dflt_value, pk)
        columns_info = {col[1]: col for col in cur.execute("PRAGMA table_info(attachments);").fetchall()}

        expected_columns = {
            "id": {"type": "VARCHAR(36)", "notnull": 1, "pk": 1},
            "owner_id": {"type": "VARCHAR(64)", "notnull": 1, "pk": 0},
            "message_id": {"type": "VARCHAR(36)", "notnull": 0, "pk": 0},
            "conversation_id": {"type": "VARCHAR(36)", "notnull": 1, "pk": 0},
            "filename_display": {"type": "VARCHAR(255)", "notnull": 1, "pk": 0},
            "storage_filename": {"type": "VARCHAR(128)", "notnull": 1, "pk": 0},
            "storage_path": {"type": "VARCHAR(512)", "notnull": 1, "pk": 0},
            "mime_type": {"type": "VARCHAR(64)", "notnull": 1, "pk": 0},
            "size_bytes": {"type": "INTEGER", "notnull": 1, "pk": 0},
            "image_width": {"type": "INTEGER", "notnull": 0, "pk": 0},
            "image_height": {"type": "INTEGER", "notnull": 0, "pk": 0},
            "is_deleted": {"type": "BOOLEAN", "notnull": 1, "pk": 0},
            "deleted_at": {"type": "DATETIME", "notnull": 0, "pk": 0},
            "created_at": {"type": "DATETIME", "notnull": 1, "pk": 0},
            "updated_at": {"type": "DATETIME", "notnull": 1, "pk": 0},
        }

        for col_name, exp in expected_columns.items():
            assert col_name in columns_info, f"Missing column {col_name} in attachments table"
            actual = columns_info[col_name]
            assert actual[2].upper() == exp["type"].upper(), f"Type mismatch for {col_name}: got {actual[2]}, expected {exp['type']}"
            assert actual[3] == exp["notnull"], f"Nullability mismatch for {col_name}: got notnull={actual[3]}, expected {exp['notnull']}"
            assert actual[5] == exp["pk"], f"PK mismatch for {col_name}: got pk={actual[5]}, expected {exp['pk']}"

        # G. Server defaults
        # SQLite renders boolean false as 0 and func.now() as CURRENT_TIMESTAMP
        assert columns_info["is_deleted"][4] in ("0", "false", "FALSE"), f"Unexpected server_default for is_deleted: {columns_info['is_deleted'][4]}"
        assert columns_info["created_at"][4] is not None, "Missing server_default for created_at"
        assert columns_info["updated_at"][4] is not None, "Missing server_default for updated_at"
        assert "CURRENT_TIMESTAMP" in str(columns_info["created_at"][4]).upper() or "NOW" in str(columns_info["created_at"][4]).upper()

        # E. Foreign keys inspection
        # PRAGMA foreign_key_list returns: (id, seq, table, from, to, on_update, on_delete, match)
        fks = cur.execute("PRAGMA foreign_key_list(attachments);").fetchall()
        fk_map = {fk[3]: {"target_table": fk[2], "target_col": fk[4], "on_delete": fk[6]} for fk in fks}

        assert "message_id" in fk_map
        assert fk_map["message_id"]["target_table"] == "messages"
        assert fk_map["message_id"]["target_col"] == "id"
        assert fk_map["message_id"]["on_delete"].upper() == "CASCADE"

        assert "conversation_id" in fk_map
        assert fk_map["conversation_id"]["target_table"] == "conversations"
        assert fk_map["conversation_id"]["target_col"] == "id"
        assert fk_map["conversation_id"]["on_delete"].upper() == "CASCADE"

        # Indexes inspection
        idx_names = [idx[1] for idx in cur.execute("PRAGMA index_list(attachments);").fetchall()]
        required_indexes = [
            "ix_attachments_id",
            "ix_attachments_owner_id",
            "ix_attachments_message_id",
            "ix_attachments_conversation_id",
            "ix_attachments_is_deleted",
            "ix_attachments_deleted_at",
            "ix_attachments_staged_created",
        ]
        for req_idx in required_indexes:
            assert req_idx in idx_names, f"Missing index {req_idx} in attachments table"

        # Verify composite index columns: (message_id, created_at)
        comp_idx_info = cur.execute("PRAGMA index_info(ix_attachments_staged_created);").fetchall()
        comp_cols = [c[2] for c in comp_idx_info]
        assert comp_cols == ["message_id", "created_at"], f"Composite index columns mismatch: got {comp_cols}"

        conn.close()


def test_migration_006_downgrade_and_reupgrade_cycle():
    """Test C, D: Downgrade from 006 to 005 drops attachments, re-upgrade restores cleanly."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "cycle_006.db"
        cfg = _get_alembic_config(db_path)

        command.upgrade(cfg, "006_add_attachments")

        # Downgrade to 005
        command.downgrade(cfg, "005_scope_message_constraints")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
        assert ver[0] == "005_scope_message_constraints"

        # attachments table and its indexes must be completely removed
        tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
        assert "attachments" not in tables

        indexes = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='index';").fetchall()]
        for idx in [
            "ix_attachments_id",
            "ix_attachments_owner_id",
            "ix_attachments_message_id",
            "ix_attachments_conversation_id",
            "ix_attachments_is_deleted",
            "ix_attachments_deleted_at",
            "ix_attachments_staged_created",
        ]:
            assert idx not in indexes

        # Existing 005 schema remains valid
        assert "conversations" in tables
        assert "messages" in tables
        assert "tasks" in tables
        assert "memories" in tables
        conn.close()

        # Re-upgrade to 006
        command.upgrade(cfg, "006_add_attachments")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
        assert ver[0] == "006_add_attachments"
        tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
        assert "attachments" in tables
        conn.close()


# ===========================================================================
# 2. ORM / Migration Parity Tests (Section 9)
# ===========================================================================

def test_attachment_orm_parity_with_metadata_contract():
    """Verify Attachment ORM metadata exactly matches the migration contract."""
    mapper = inspect(Attachment)
    table = Attachment.__table__

    # 1. Column names and nullability
    assert "id" in table.columns
    assert table.columns["id"].nullable is False
    assert table.columns["id"].primary_key is True

    assert "owner_id" in table.columns
    assert table.columns["owner_id"].nullable is False

    assert "message_id" in table.columns
    assert table.columns["message_id"].nullable is True

    assert "conversation_id" in table.columns
    assert table.columns["conversation_id"].nullable is False

    assert "filename_display" in table.columns
    assert table.columns["filename_display"].nullable is False

    assert "storage_filename" in table.columns
    assert table.columns["storage_filename"].nullable is False

    assert "storage_path" in table.columns
    assert table.columns["storage_path"].nullable is False

    assert "mime_type" in table.columns
    assert table.columns["mime_type"].nullable is False

    assert "size_bytes" in table.columns
    assert table.columns["size_bytes"].nullable is False

    assert "image_width" in table.columns
    assert table.columns["image_width"].nullable is True

    assert "image_height" in table.columns
    assert table.columns["image_height"].nullable is True

    assert "is_deleted" in table.columns
    assert table.columns["is_deleted"].nullable is False

    assert "deleted_at" in table.columns
    assert table.columns["deleted_at"].nullable is True

    assert "created_at" in table.columns
    assert table.columns["created_at"].nullable is False

    assert "updated_at" in table.columns
    assert table.columns["updated_at"].nullable is False

    # 2. Foreign keys and cascade
    fks = {fk.parent.name: fk for fk in table.foreign_keys}
    assert "message_id" in fks
    assert fks["message_id"].target_fullname == "messages.id"
    assert fks["message_id"].ondelete.upper() == "CASCADE"

    assert "conversation_id" in fks
    assert fks["conversation_id"].target_fullname == "conversations.id"
    assert fks["conversation_id"].ondelete.upper() == "CASCADE"

    # 3. Indexes
    idx_dict = {idx.name: idx for idx in table.indexes}
    expected_indices = [
        "ix_attachments_id",
        "ix_attachments_owner_id",
        "ix_attachments_message_id",
        "ix_attachments_conversation_id",
        "ix_attachments_is_deleted",
        "ix_attachments_deleted_at",
        "ix_attachments_staged_created",
    ]
    for exp_idx in expected_indices:
        assert exp_idx in idx_dict, f"ORM model missing index {exp_idx}"

    # Verify composite index columns
    comp_idx = idx_dict["ix_attachments_staged_created"]
    comp_col_names = [col.name for col in comp_idx.columns]
    assert comp_col_names == ["message_id", "created_at"]

    # 4. Mixin verification
    # UUIDPrimaryKeyMixin: id String(36), PK
    assert table.columns["id"].type.length == 36
    # OwnerMixin: owner_id String(64)
    assert table.columns["owner_id"].type.length == 64
    # TimestampMixin: created_at, updated_at
    assert table.columns["created_at"].type.timezone is True
    assert table.columns["updated_at"].type.timezone is True
    # SoftDeleteMixin: is_deleted, deleted_at
    assert table.columns["deleted_at"].type.timezone is True


# ===========================================================================
# 3. Deterministic Metadata Registration via Clean Subprocess (Section 10)
# ===========================================================================

def test_deterministic_model_metadata_registration():
    """Verify that importing app.db.base in a clean process registers all 5 model tables on Base.metadata."""
    script = (
        "import sys; "
        "from app.db.base import Base; "
        "expected = {'tasks', 'conversations', 'messages', 'memories', 'attachments'}; "
        "registered = set(Base.metadata.tables.keys()); "
        "missing = expected - registered; "
        "assert not missing, f'Missing tables in Base.metadata: {missing}'; "
        "print('METADATA_REGISTRATION_VERIFIED')"
    )
    result = subprocess.run(
        [sys.executable, "-c", script],
        cwd=str(BACKEND_DIR),
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"Subprocess failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    assert "METADATA_REGISTRATION_VERIFIED" in result.stdout


# ===========================================================================
# 4. ORM Relationship Mechanics (Section 11)
# ===========================================================================

@pytest.mark.asyncio
async def test_attachment_orm_relationships_and_staged_vs_committed():
    """Verify Conversation.attachments, Message.attachments, and staged vs committed attachment lifecycle."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "orm_rel_test.db"
        cfg = _get_alembic_config(db_path)
        import asyncio
        await asyncio.to_thread(command.upgrade, cfg, "head")

        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path.as_posix()}")
        async_session = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

        try:
            async with async_session() as session:
                # Create a conversation
                conv = Conversation(
                    id="conv-test-1",
                    owner_id="user-1",
                    title="Multimodal Thread",
                    character_id="default",
                )
                session.add(conv)
                await session.flush()

                # 1. Staged attachment: message_id is None
                staged_att = Attachment(
                    id="att-staged-1",
                    owner_id="user-1",
                    conversation_id="conv-test-1",
                    message_id=None,
                    filename_display="sunset.png",
                    storage_filename="uuid-sunset.png",
                    storage_path="attachments/user-1/conv-test-1/uuid-sunset.png",
                    mime_type="image/png",
                    size_bytes=1024 * 500,
                    image_width=1920,
                    image_height=1080,
                )
                session.add(staged_att)
                await session.commit()

            # Query back and verify staged state
            async with async_session() as session:
                res = await session.execute(select(Attachment).where(Attachment.id == "att-staged-1"))
                loaded_staged = res.scalar_one()
                assert loaded_staged.message_id is None
                assert loaded_staged.conversation_id == "conv-test-1"
                assert loaded_staged.is_deleted is False

                # Verify relationship back to Conversation
                from sqlalchemy.orm import selectinload
                res_conv = await session.execute(
                    select(Conversation).options(selectinload(Conversation.attachments)).where(Conversation.id == "conv-test-1")
                )
                loaded_conv = res_conv.scalar_one()
                assert any(a.id == "att-staged-1" for a in loaded_conv.attachments)

                # 2. Commit a message and bind an attachment
                msg = Message(
                    id="msg-test-1",
                    owner_id="user-1",
                    conversation_id="conv-test-1",
                    sender="user",
                    content="Here is a sunset image",
                    status="completed",
                    sequence_no=1,
                )
                session.add(msg)
                await session.flush()

                committed_att = Attachment(
                    id="att-committed-1",
                    owner_id="user-1",
                    conversation_id="conv-test-1",
                    message_id="msg-test-1",
                    filename_display="mountain.jpg",
                    storage_filename="uuid-mountain.jpg",
                    storage_path="attachments/user-1/conv-test-1/uuid-mountain.jpg",
                    mime_type="image/jpeg",
                    size_bytes=1024 * 800,
                    image_width=2560,
                    image_height=1440,
                )
                session.add(committed_att)
                await session.commit()

            # Query back message and verify lazy="selectin" attachments relationship
            async with async_session() as session:
                res_msg = await session.execute(select(Message).where(Message.id == "msg-test-1"))
                loaded_msg = res_msg.scalar_one()
                assert len(loaded_msg.attachments) == 1
                assert loaded_msg.attachments[0].id == "att-committed-1"
                assert loaded_msg.attachments[0].filename_display == "mountain.jpg"
                assert loaded_msg.attachments[0].message_id == "msg-test-1"

                # Query committed attachment and verify relationship back to message and conversation
                res_att = await session.execute(
                    select(Attachment)
                    .options(selectinload(Attachment.message), selectinload(Attachment.conversation))
                    .where(Attachment.id == "att-committed-1")
                )
                loaded_att = res_att.scalar_one()
                assert loaded_att.message is not None
                assert loaded_att.message.id == "msg-test-1"
                assert loaded_att.conversation is not None
                assert loaded_att.conversation.id == "conv-test-1"
        finally:
            await engine.dispose()
