"""Tests for prepare_database_schema pre-migration backup integration (PC-RESILIENCE-002).

Validates:
1. Fresh database upgrades cleanly to head without triggering backup.
2. Existing database at older revision creates a verified backup before upgrade.
3. Pre-migration backup failure aborts upgrade safely leaving database untouched.
4. Database already at head revision does not trigger redundant backup.
"""

import sqlite3
import tempfile
from pathlib import Path
from unittest.mock import patch
import pytest
from alembic import command
from alembic.config import Config

from app.core.storage import prepare_database_schema, StorageError
from app.db.backup import SQLiteBackupError

BACKEND_DIR = Path(__file__).resolve().parent.parent


def _get_alembic_config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


def test_fresh_database_does_not_create_backup():
    """Fresh install upgrades to head without creating unnecessary backup files."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_root = Path(tmpdir)
        db_path = tmp_root / "database" / "companion.db"
        backup_dir = tmp_root / "backups"

        rev = prepare_database_schema(db_path, backup_dir=backup_dir)
        assert rev == "008_profile_sessions_and_tickets"

        # Verify no backups created
        if backup_dir.exists():
            backups = list(backup_dir.glob("pre_migration_*.db"))
            assert len(backups) == 0


def test_existing_older_database_creates_backup_before_upgrade():
    """Existing database at 006 must be backed up before upgrading to 007."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_root = Path(tmpdir)
        db_path = tmp_root / "database" / "companion.db"
        db_path.parent.mkdir(parents=True, exist_ok=True)
        backup_dir = tmp_root / "backups"

        # Initialize to 006
        cfg = _get_alembic_config(db_path)
        command.upgrade(cfg, "006_add_attachments")

        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO tasks (id, created_at, updated_at, owner_id, title, status, priority, is_deleted)
                VALUES ('task-backup-1', '2026-09-01 10:00:00', '2026-09-01 10:00:00', 'local_user', 'Pre-upgrade task', 'pending', 1, 0)
            """)
            conn.commit()
        finally:
            conn.close()

        # Run prepare_database_schema which should detect upgrade needed and trigger backup
        rev = prepare_database_schema(db_path, backup_dir=backup_dir)
        assert rev == "008_profile_sessions_and_tickets"

        # Verify backup was created
        assert backup_dir.exists()
        backups = list(backup_dir.glob("pre_migration_*.db"))
        assert len(backups) == 1

        # Verify backup integrity and content
        backup_conn = sqlite3.connect(backups[0])
        try:
            b_cur = backup_conn.cursor()
            b_ver = b_cur.execute("SELECT version_num FROM alembic_version;").fetchone()
            assert b_ver[0] == "006_add_attachments"
            task_title = b_cur.execute("SELECT title FROM tasks WHERE id = 'task-backup-1'").fetchone()[0]
            assert task_title == "Pre-upgrade task"
        finally:
            backup_conn.close()


def test_backup_failure_aborts_migration_and_leaves_database_untouched():
    """If pre-migration backup fails, upgrade is aborted immediately and DB remains at 006."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_root = Path(tmpdir)
        db_path = tmp_root / "database" / "companion.db"
        db_path.parent.mkdir(parents=True, exist_ok=True)
        backup_dir = tmp_root / "backups"

        # Initialize to 006
        cfg = _get_alembic_config(db_path)
        command.upgrade(cfg, "006_add_attachments")

        with patch("app.core.storage.create_pre_migration_backup", side_effect=SQLiteBackupError("Disk full or backup error")):
            with pytest.raises(StorageError) as exc_info:
                prepare_database_schema(db_path, backup_dir=backup_dir)

            assert "Pre-migration backup failed" in str(exc_info.value)

        # Verify database was NOT upgraded to 007
        conn = sqlite3.connect(db_path)
        try:
            cur = conn.cursor()
            ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
            assert ver[0] == "006_add_attachments"
        finally:
            conn.close()


def test_database_already_at_head_creates_no_redundant_backup():
    """Database already at head revision does not trigger backup on subsequent startups."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_root = Path(tmpdir)
        db_path = tmp_root / "database" / "companion.db"
        backup_dir = tmp_root / "backups"

        # First run upgrades fresh to 008
        rev1 = prepare_database_schema(db_path, backup_dir=backup_dir)
        assert rev1 == "008_profile_sessions_and_tickets"

        # Subsequent startup
        rev2 = prepare_database_schema(db_path, backup_dir=backup_dir)
        assert rev2 == "008_profile_sessions_and_tickets"

        if backup_dir.exists():
            backups = list(backup_dir.glob("pre_migration_*.db"))
            assert len(backups) == 0


def _bytes(path):
    return path.read_bytes()


@pytest.mark.parametrize(
    "payload",
    [b"definitely not a sqlite database " * 200, b""],
    ids=["garbage-header", "zero-byte"],
)
def test_invalid_existing_database_fails_closed_before_any_upgrade(payload):
    """An existing but invalid canonical DB must never be upgraded, replaced or backed up."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_root = Path(tmpdir)
        db_path = tmp_root / "database" / "companion.db"
        db_path.parent.mkdir(parents=True)
        db_path.write_bytes(payload)
        backup_dir = tmp_root / "backups"

        with pytest.raises(StorageError, match="Refusing to upgrade"):
            prepare_database_schema(db_path, backup_dir=backup_dir)

        assert _bytes(db_path) == payload
        assert not (backup_dir.exists() and any(backup_dir.iterdir()))


def test_valid_database_with_failed_integrity_fails_closed_before_upgrade():
    """A real SQLite file whose pages are damaged must stop startup without modification."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_root = Path(tmpdir)
        db_path = tmp_root / "database" / "companion.db"
        db_path.parent.mkdir(parents=True)
        cfg = _get_alembic_config(db_path)
        command.upgrade(cfg, "006_add_attachments")

        conn = sqlite3.connect(db_path)
        conn.execute("PRAGMA journal_mode=DELETE")
        for i in range(400):
            conn.execute(
                "INSERT INTO tasks (id, created_at, updated_at, owner_id, title, status, priority, is_deleted) "
                "VALUES (?, '2026-09-01', '2026-09-01', 'local_user', ?, 'pending', 1, 0)",
                (f"t{i}", "x" * 200),
            )
        conn.commit()
        conn.close()

        raw = bytearray(db_path.read_bytes())
        page = 4096
        assert len(raw) > page * 6
        for offset in range(page * 4, page * 6):
            raw[offset] = 0xFF  # destroy b-tree interior pages
        db_path.write_bytes(bytes(raw))
        damaged = _bytes(db_path)

        with pytest.raises(StorageError, match="Refusing to upgrade"):
            prepare_database_schema(db_path, backup_dir=tmp_root / "backups")

        assert _bytes(db_path) == damaged
        assert not (tmp_root / "backups").exists() or not any((tmp_root / "backups").iterdir())


def test_each_upgrade_creates_a_distinct_never_overwritten_backup():
    """Repeated pre-upgrade backups must accumulate; earlier verified snapshots stay intact."""
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_root = Path(tmpdir)
        db_path = tmp_root / "database" / "companion.db"
        db_path.parent.mkdir(parents=True)
        backup_dir = tmp_root / "backups"
        cfg = _get_alembic_config(db_path)

        command.upgrade(cfg, "005_scope_message_constraints")
        prepare_database_schema(db_path, backup_dir=backup_dir)  # 005 -> head
        first = sorted(backup_dir.glob("pre_migration_*.db"))
        assert len(first) == 1
        first_bytes = _bytes(first[0])

        command.downgrade(cfg, "006_add_attachments")
        prepare_database_schema(db_path, backup_dir=backup_dir)  # 006 -> head, same second likely
        after = sorted(backup_dir.glob("pre_migration_*.db"))
        assert len(after) == 2
        assert _bytes(first[0]) == first_bytes
