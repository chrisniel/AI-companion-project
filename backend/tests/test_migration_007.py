"""Tests for Alembic Migration 007: Profiles & Profile ID Scoping (PC-IDENTITY-001).

Validates:
1. Fresh SQLite upgrade from base to 007.
2. Upgrade from populated 006 to 007 with 100% data retention and Default Profile association.
3. Legacy owner allowlist enforcement (fail-closed on unexpected owner IDs).
4. FTS5 trigger cycling and search consistency across migration.
5. Downgrade safety refusal when multiple profiles exist.
6. Clean downgrade/re-upgrade roundtrip when only default profile exists.
"""

import sqlite3
import tempfile
from pathlib import Path
import pytest
from alembic import command
from alembic.config import Config

from app.db.backup import MigrationAmbiguityError

BACKEND_DIR = Path(__file__).resolve().parent.parent


def _get_alembic_config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


def test_migration_007_fresh_database_upgrade():
    """Test A: Fresh SQLite database upgrades cleanly to 007 head."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "fresh_007.db"
        cfg = _get_alembic_config(db_path)

        command.upgrade(cfg, "007_profiles_and_owner_id_migration")

        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
            assert ver is not None and ver[0] == "007_profiles_and_owner_id_migration"

            # 1. Verify profiles table exists
            tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
            assert "profiles" in tables

            # 2. Verify profiles columns
            p_cols = {col[1]: col[2] for col in cur.execute("PRAGMA table_info(profiles);").fetchall()}
            for expected in ["id", "created_at", "updated_at", "name", "avatar_url", "pin_hash", "is_default", "status", "is_deleted", "deleted_at", "purge_after"]:
                assert expected in p_cols

            # 3. Verify Default Profile was seeded
            def_profile = cur.execute("SELECT id, name, is_default, status FROM profiles WHERE is_default = 1").fetchone()
            assert def_profile is not None  # unique per installation; see test_default_profile_identity.py
            assert len(def_profile[0]) == 36
            assert def_profile[1] == "Default Profile"
            assert def_profile[2] == 1  # True in SQLite
            assert def_profile[3] == "active"

            # 4. Verify all entity tables have both owner_id and profile_id
            for tbl in ["conversations", "messages", "memories", "tasks", "attachments"]:
                cols = {col[1]: col[2] for col in cur.execute(f"PRAGMA table_info({tbl});").fetchall()}
                assert "owner_id" in cols, f"{tbl} missing owner_id"
                assert "profile_id" in cols, f"{tbl} missing profile_id"

                # Check index on profile_id
                indexes = [r[1] for r in cur.execute(f"PRAGMA index_list({tbl});").fetchall()]
                assert f"ix_{tbl}_profile_id" in indexes, f"{tbl} missing ix_{tbl}_profile_id"
        finally:
            conn.close()


def test_migration_007_populated_006_upgrade_data_retention_and_fts5():
    """Test B: Populated 006 database upgrades to 007 with 100% data retention and FTS5 integrity."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "populated_006.db"
        cfg = _get_alembic_config(db_path)

        # 1. Upgrade to 006
        command.upgrade(cfg, "006_add_attachments")

        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()

            # Seed conversation with allowed legacy alias local_user
            cur.execute("""
                INSERT INTO conversations (id, created_at, updated_at, owner_id, title, character_id, is_deleted)
                VALUES ('conv-1', '2026-09-01 10:00:00', '2026-09-01 10:00:00', 'local_user', 'Legacy Chat', 'default', 0)
            """)
            # Seed message with default_user (allowed legacy alias)
            cur.execute("""
                INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, sequence_no, is_deleted)
                VALUES ('msg-1', '2026-09-01 10:00:01', '2026-09-01 10:00:01', 'default_user', 'conv-1', 'user', 'Hello world', 1, 0)
            """)
            # Seed memory
            cur.execute("""
                INSERT INTO memories (id, created_at, updated_at, owner_id, category, content, importance, is_deleted)
                VALUES ('mem-1', '2026-09-01 10:00:02', '2026-09-01 10:00:02', 'local_user', 'fact', 'User loves quantum computing', 1.0, 0)
            """)
            # Seed task
            cur.execute("""
                INSERT INTO tasks (id, created_at, updated_at, owner_id, title, status, priority, is_deleted)
                VALUES ('task-1', '2026-09-01 10:00:03', '2026-09-01 10:00:03', 'local_user', 'Legacy Task', 'pending', 1, 0)
            """)
            # Seed attachment
            cur.execute("""
                INSERT INTO attachments (id, created_at, updated_at, owner_id, conversation_id, filename_display, storage_filename, storage_path, mime_type, size_bytes, is_deleted)
                VALUES ('att-1', '2026-09-01 10:00:04', '2026-09-01 10:00:04', 'local_user', 'conv-1', 'test.png', 'store_test.png', 'attachments/test.png', 'image/png', 1024, 0)
            """)
            conn.commit()

            # Verify FTS5 worked in 006
            fts_count = cur.execute("SELECT count(*) FROM memories_fts WHERE memories_fts MATCH 'quantum'").fetchone()[0]
            assert fts_count == 1
        finally:
            conn.close()

        # 2. Upgrade to 007
        command.upgrade(cfg, "007_profiles_and_owner_id_migration")

        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            default_id = cur.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]

            # Verify conversation retained and assigned default_id
            c = cur.execute("SELECT id, owner_id, profile_id, title FROM conversations WHERE id = 'conv-1'").fetchone()
            assert c is not None
            assert c[0] == "conv-1"
            assert c[1] == "local_user"
            assert c[2] == default_id
            assert c[3] == "Legacy Chat"

            # Verify message retained and assigned default_id
            m = cur.execute("SELECT id, owner_id, profile_id, content FROM messages WHERE id = 'msg-1'").fetchone()
            assert m is not None
            assert m[0] == "msg-1"
            assert m[2] == default_id

            # Verify memory retained and assigned default_id
            mem = cur.execute("SELECT id, owner_id, profile_id, content FROM memories WHERE id = 'mem-1'").fetchone()
            assert mem is not None
            assert mem[0] == "mem-1"
            assert mem[2] == default_id

            # Verify task retained and assigned default_id
            t = cur.execute("SELECT id, owner_id, profile_id, title FROM tasks WHERE id = 'task-1'").fetchone()
            assert t is not None
            assert t[0] == "task-1"
            assert t[2] == default_id

            # Verify attachment retained and assigned default_id
            att = cur.execute("SELECT id, owner_id, profile_id, filename_display FROM attachments WHERE id = 'att-1'").fetchone()
            assert att is not None
            assert att[0] == "att-1"
            assert att[1] == "local_user"
            assert att[2] == default_id
            assert att[3] == "test.png"
            assert att[0] == "att-1"
            assert att[2] == default_id

            # Verify FTS5 query works after rebuild!
            fts_count_after = cur.execute("SELECT count(*) FROM memories_fts WHERE memories_fts MATCH 'quantum'").fetchone()[0]
            assert fts_count_after == 1

            # Insert new memory to verify triggers work after migration
            cur.execute("""
                INSERT INTO memories (id, created_at, updated_at, owner_id, profile_id, category, content, importance, is_deleted)
                VALUES ('mem-2', '2026-09-01 10:00:05', '2026-09-01 10:00:05', 'local_user', ?, 'fact', 'User enjoys astrophysics research', 1.0, 0)
            """, (default_id,))
            conn.commit()

            fts_count_new = cur.execute("SELECT count(*) FROM memories_fts WHERE memories_fts MATCH 'astrophysics'").fetchone()[0]
            assert fts_count_new == 1

            # Verify foreign key check passes
            fk_violations = cur.execute("PRAGMA foreign_key_check;").fetchall()
            assert len(fk_violations) == 0
        finally:
            conn.close()


def test_migration_007_rejects_ambiguous_legacy_owner_ids_and_fails_closed():
    """Test C: Upgrade fails closed if unexpected legacy owner IDs are encountered."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "ambiguous_owner.db"
        cfg = _get_alembic_config(db_path)

        command.upgrade(cfg, "006_add_attachments")

        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            # Insert unexpected owner_id
            cur.execute("""
                INSERT INTO tasks (id, created_at, updated_at, owner_id, title, status, priority, is_deleted)
                VALUES ('task-err', '2026-09-01 10:00:00', '2026-09-01 10:00:00', 'rogue_tenant_user_42', 'Unauthorized Task', 'pending', 1, 0)
            """)
            conn.commit()
        finally:
            conn.close()

        # Upgrade must fail closed
        with pytest.raises(MigrationAmbiguityError) as exc_info:
            command.upgrade(cfg, "007_profiles_and_owner_id_migration")

        assert "Ambiguous legacy ownership detected" in str(exc_info.value)
        assert "rogue_tenant_user_42" in str(exc_info.value)

        # Verify database version was NOT advanced
        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
            assert ver[0] == "006_add_attachments"
            # Verify data is untouched
            task = cur.execute("SELECT owner_id, title FROM tasks WHERE id = 'task-err'").fetchone()
            assert task[0] == "rogue_tenant_user_42"
        finally:
            conn.close()


def test_migration_007_downgrade_and_reupgrade_cycle():
    """Test D: Clean downgrade to 006 and re-upgrade to 007 with single profile."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "cycle_007.db"
        cfg = _get_alembic_config(db_path)

        command.upgrade(cfg, "007_profiles_and_owner_id_migration")

        # Downgrade to 006
        command.downgrade(cfg, "006_add_attachments")

        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
            assert ver[0] == "006_add_attachments"

            tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
            assert "profiles" not in tables

            # Verify profile_id column was removed from conversations
            cols = [col[1] for col in cur.execute("PRAGMA table_info(conversations);").fetchall()]
            assert "profile_id" not in cols
            assert "owner_id" in cols
        finally:
            conn.close()

        # Re-upgrade to 007
        command.upgrade(cfg, "007_profiles_and_owner_id_migration")

        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
            assert ver[0] == "007_profiles_and_owner_id_migration"
            tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
            assert "profiles" in tables
        finally:
            conn.close()


def test_migration_007_downgrade_refuses_when_multiple_profiles_exist():
    """Test E: Downgrade fails closed if multiple profiles exist to prevent data loss."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "multi_profile_downgrade.db"
        cfg = _get_alembic_config(db_path)

        command.upgrade(cfg, "007_profiles_and_owner_id_migration")

        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            # Insert a second profile
            cur.execute("""
                INSERT INTO profiles (id, created_at, updated_at, name, is_default, status, is_deleted)
                VALUES ('custom-profile-uuid-2', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'Second Profile', 0, 'active', 0)
            """)
            conn.commit()
        finally:
            conn.close()

        # Downgrade must be refused
        with pytest.raises(Exception) as exc_info:
            command.downgrade(cfg, "006_add_attachments")

        assert "Downgrade refused" in str(exc_info.value)
        assert "2 profiles exist" in str(exc_info.value)
