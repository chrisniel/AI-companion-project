import os
import tempfile
import sqlite3
from pathlib import Path
import pytest
from alembic.config import Config
from alembic import command

BACKEND_DIR = Path(__file__).resolve().parent.parent


def test_fresh_database_upgrade_base_through_004():
    """Test A: Fresh SQLite database upgrades cleanly from base through revision 004."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "fresh_004.db"
        cfg = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
        cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")

        command.upgrade(cfg, "004_add_soft_delete_columns")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        # Verify alembic version
        ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
        assert ver is not None and ver[0] == "004_add_soft_delete_columns"

        # Verify soft delete columns and indexes on all three tables
        for tbl in ["conversations", "messages", "memories"]:
            cols = [col[1] for col in cur.execute(f"PRAGMA table_info({tbl});").fetchall()]
            assert "is_deleted" in cols, f"Missing is_deleted in {tbl}"
            assert "deleted_at" in cols, f"Missing deleted_at in {tbl}"

            idx_names = [idx[1] for idx in cur.execute(f"PRAGMA index_list({tbl});").fetchall()]
            assert f"ix_{tbl}_is_deleted" in idx_names, f"Missing index ix_{tbl}_is_deleted in {tbl}"
            assert f"ix_{tbl}_deleted_at" in idx_names, f"Missing index ix_{tbl}_deleted_at in {tbl}"

        # Verify FTS5 virtual table and triggers
        triggers = [t[0] for t in cur.execute("SELECT name FROM sqlite_master WHERE type='trigger';").fetchall()]
        assert "memories_fts_insert" in triggers
        assert "memories_fts_update" in triggers
        assert "memories_fts_delete" in triggers

        conn.close()


def test_existing_003_database_upgrade_to_004_and_schema_parity():
    """Test B: Database at 003 with existing rows upgrades to 004 with exact schema parity."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # DB A: Fresh upgrade to 004
        db_path_a = Path(tmpdir) / "db_a_fresh.db"
        cfg_a = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg_a.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
        cfg_a.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path_a.as_posix()}")
        command.upgrade(cfg_a, "004_add_soft_delete_columns")

        # DB B: Upgrade to 003 first, insert existing rows, then upgrade to 004
        db_path_b = Path(tmpdir) / "db_b_upgraded.db"
        cfg_b = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg_b.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
        cfg_b.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path_b.as_posix()}")

        # Upgrade to 003
        command.upgrade(cfg_b, "003_conversations_messages_and_fts5_memory")

        # Insert test rows in 003 schema without is_deleted
        conn_b = sqlite3.connect(db_path_b)
        cur_b = conn_b.cursor()
        cur_b.execute("""
            INSERT INTO conversations (id, created_at, updated_at, deleted_at, owner_id, title, character_id)
            VALUES ('conv-test-1', '2026-09-14 00:00:00', '2026-09-14 00:00:00', NULL, 'owner-1', 'Test 003', 'aura');
        """)
        cur_b.execute("""
            INSERT INTO messages (id, created_at, updated_at, deleted_at, owner_id, conversation_id, sender, content, status, sequence_no)
            VALUES ('msg-test-1', '2026-09-14 00:00:00', '2026-09-14 00:00:00', NULL, 'owner-1', 'conv-test-1', 'user', 'Hello', 'completed', 1);
        """)
        cur_b.execute("""
            INSERT INTO memories (id, created_at, updated_at, deleted_at, owner_id, category, content, importance, source_type, user_verified)
            VALUES ('mem-test-1', '2026-09-14 00:00:00', '2026-09-14 00:00:00', NULL, 'owner-1', 'fact', 'Likes coding', 1.0, 'manual', 1);
        """)
        conn_b.commit()
        conn_b.close()

        # Upgrade DB B to 004
        command.upgrade(cfg_b, "004_add_soft_delete_columns")

        # Verify existing data preserved and defaulted to is_deleted = 0 (false)
        conn_b = sqlite3.connect(db_path_b)
        cur_b = conn_b.cursor()

        conv_row = cur_b.execute("SELECT id, title, is_deleted, deleted_at FROM conversations WHERE id = 'conv-test-1';").fetchone()
        assert conv_row == ("conv-test-1", "Test 003", 0, None)

        msg_row = cur_b.execute("SELECT id, content, is_deleted, deleted_at FROM messages WHERE id = 'msg-test-1';").fetchone()
        assert msg_row == ("msg-test-1", "Hello", 0, None)

        mem_row = cur_b.execute("SELECT id, content, is_deleted, deleted_at FROM memories WHERE id = 'mem-test-1';").fetchone()
        assert mem_row == ("mem-test-1", "Likes coding", 0, None)

        # Verify FTS5 virtual table still matches
        fts_match = cur_b.execute("SELECT id, content, category FROM memories_fts WHERE memories_fts MATCH 'coding';").fetchall()
        assert fts_match == [("mem-test-1", "Likes coding", "fact")]

        # Verify trigger preservation
        triggers_b = [t[0] for t in cur_b.execute("SELECT name FROM sqlite_master WHERE type='trigger';").fetchall()]
        assert "memories_fts_insert" in triggers_b
        assert "memories_fts_update" in triggers_b
        assert "memories_fts_delete" in triggers_b

        # Verify strict schema parity between fresh DB (A) and upgraded DB (B)
        conn_a = sqlite3.connect(db_path_a)
        cur_a = conn_a.cursor()

        for tbl in ["conversations", "messages", "memories"]:
            cols_a = cur_a.execute(f"PRAGMA table_info({tbl});").fetchall()
            cols_b = cur_b.execute(f"PRAGMA table_info({tbl});").fetchall()
            sig_a = [(c[1], c[2], c[3], c[4], c[5]) for c in cols_a]
            sig_b = [(c[1], c[2], c[3], c[4], c[5]) for c in cols_b]
            assert sig_a == sig_b, f"Schema mismatch for {tbl} between fresh and upgraded DB!"

        conn_a.close()
        conn_b.close()


def test_migration_004_downgrade_and_reupgrade_cycle():
    """Test C: Migration 004 downgrades cleanly to 003 and re-upgrades to 004."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "cycle.db"
        cfg = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
        cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")

        # Upgrade to 004
        command.upgrade(cfg, "004_add_soft_delete_columns")

        # Downgrade to 003
        command.downgrade(cfg, "003_conversations_messages_and_fts5_memory")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        for tbl in ["conversations", "messages", "memories"]:
            cols = [col[1] for col in cur.execute(f"PRAGMA table_info({tbl});").fetchall()]
            assert "is_deleted" not in cols, f"is_deleted still present after downgrade in {tbl}"
            idx_names = [idx[1] for idx in cur.execute(f"PRAGMA index_list({tbl});").fetchall()]
            assert f"ix_{tbl}_is_deleted" not in idx_names, f"Index ix_{tbl}_is_deleted still present in {tbl}"
        conn.close()

        # Re-upgrade to 004
        command.upgrade(cfg, "004_add_soft_delete_columns")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        for tbl in ["conversations", "messages", "memories"]:
            cols = [col[1] for col in cur.execute(f"PRAGMA table_info({tbl});").fetchall()]
            assert "is_deleted" in cols, f"is_deleted missing after re-upgrade in {tbl}"
            idx_names = [idx[1] for idx in cur.execute(f"PRAGMA index_list({tbl});").fetchall()]
            assert f"ix_{tbl}_is_deleted" in idx_names, f"Missing index ix_{tbl}_is_deleted in {tbl}"
        conn.close()
