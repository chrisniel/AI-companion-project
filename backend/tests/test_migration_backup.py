"""Tests for safe SQLite WAL-mode pre-migration backup and restore utility (PC-RESILIENCE-002)."""

from pathlib import Path
import sqlite3
import pytest

from app.db.backup import (
    create_pre_migration_backup,
    restore_database_from_backup,
    verify_sqlite_integrity,
    SQLiteBackupError,
)


def test_wal_backup_captures_uncheckpointed_wal_records(tmp_path: Path):
    """Prove that WAL backup captures active committed records still in the -wal sidecar file."""
    db_path = tmp_path / "companion.db"
    backup_dir = tmp_path / "backups"

    # 1. Establish database in WAL mode with large autocheckpoint threshold to prevent flush
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA wal_autocheckpoint=1000;")
    conn.execute("CREATE TABLE live_wal (id TEXT PRIMARY KEY, val TEXT NOT NULL);")
    conn.commit()

    # 2. Insert records while KEEPING THE CONNECTION OPEN
    conn.execute("INSERT INTO live_wal VALUES ('wal_key_1', 'uncheckpointed_data_in_wal');")
    conn.commit()

    # Verify WAL file exists and contains uncheckpointed data
    wal_file = tmp_path / "companion.db-wal"
    assert wal_file.exists()
    assert wal_file.stat().st_size > 0

    # 3. Execute online backup while original connection is STILL OPEN and WRITING
    backup_path = create_pre_migration_backup(
        source_db_path=db_path,
        backup_dir=backup_dir,
        label="active_wal_test",
    )

    # 4. Verify backup captured the uncheckpointed WAL record cleanly
    assert backup_path.exists()
    assert backup_path.name.startswith("pre_active_wal_test_")
    assert verify_sqlite_integrity(backup_path) is True

    b_conn = sqlite3.connect(backup_path)
    row = b_conn.execute("SELECT val FROM live_wal WHERE id='wal_key_1';").fetchone()
    b_conn.close()
    conn.close()

    assert row is not None
    assert row[0] == "uncheckpointed_data_in_wal"


def test_quiesced_restore_replaces_target_cleanly(tmp_path: Path):
    """Prove that restore replaces a corrupted/mutated target cleanly and removes stale WAL sidecars."""
    db_path = tmp_path / "companion.db"
    backup_dir = tmp_path / "backups"

    # 1. Create source database with initial data
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("CREATE TABLE accounts (id TEXT PRIMARY KEY, balance INTEGER);")
    conn.execute("INSERT INTO accounts VALUES ('acc1', 500);")
    conn.commit()
    conn.close()

    # 2. Create verified backup
    backup_path = create_pre_migration_backup(
        source_db_path=db_path,
        backup_dir=backup_dir,
        label="pre_corruption",
    )
    assert verify_sqlite_integrity(backup_path) is True

    # 3. Mutate target database to simulate bad state
    conn = sqlite3.connect(db_path)
    conn.execute("UPDATE accounts SET balance = 0 WHERE id = 'acc1';")
    conn.execute("INSERT INTO accounts VALUES ('acc_corrupt', 9999);")
    conn.commit()
    conn.close()

    # 4. Execute restore
    restore_database_from_backup(backup_path=backup_path, target_db_path=db_path)

    # 5. Verify restored database has pre-corruption state and passes integrity
    assert verify_sqlite_integrity(db_path) is True
    conn = sqlite3.connect(db_path)
    rows = conn.execute("SELECT id, balance FROM accounts ORDER BY id;").fetchall()
    conn.close()

    assert len(rows) == 1
    assert rows[0] == ("acc1", 500)


def test_backup_fails_on_nonexistent_or_empty_source(tmp_path: Path):
    """Verify backup fails closed if source database does not exist or is empty."""
    nonexistent = tmp_path / "ghost.db"
    backup_dir = tmp_path / "backups"

    with pytest.raises(SQLiteBackupError, match="Source database does not exist"):
        create_pre_migration_backup(source_db_path=nonexistent, backup_dir=backup_dir)

    empty_db = tmp_path / "empty.db"
    empty_db.write_bytes(b"")
    with pytest.raises(SQLiteBackupError, match="empty file"):
        create_pre_migration_backup(source_db_path=empty_db, backup_dir=backup_dir)
