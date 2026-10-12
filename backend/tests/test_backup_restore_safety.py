"""Regression tests for backup naming safety and quiesced, staged restore (PC-RESILIENCE-002).

All databases are disposable SQLite files under pytest tmp_path.
"""

import hashlib
import sqlite3
from pathlib import Path

import pytest

import app.db.backup as backup_mod
from app.db.backup import (
    SQLiteBackupError,
    create_pre_migration_backup,
    restore_database_from_backup,
    verify_sqlite_integrity,
)


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _make_db(path: Path, value: str = "v1") -> None:
    conn = sqlite3.connect(path)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, val TEXT NOT NULL);")
    conn.execute("INSERT INTO t (val) VALUES (?)", (value,))
    conn.commit()
    conn.close()


def _values(path: Path) -> list:
    conn = sqlite3.connect(path)
    try:
        return [r[0] for r in conn.execute("SELECT val FROM t ORDER BY id").fetchall()]
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Collision-proof, never-overwrite backups
# ---------------------------------------------------------------------------

def test_rapid_backups_with_same_label_get_distinct_files(tmp_path):
    db = tmp_path / "companion.db"
    _make_db(db, "first")
    backups = tmp_path / "backups"

    first = create_pre_migration_backup(db, backups, label="migration")
    first_hash = _sha(first)

    conn = sqlite3.connect(db)
    conn.execute("INSERT INTO t (val) VALUES ('second')")
    conn.commit()
    conn.close()

    second = create_pre_migration_backup(db, backups, label="migration")

    assert first != second
    assert first.exists() and second.exists()
    assert _sha(first) == first_hash, "prior verified snapshot must be untouched"
    assert _values(first) == ["first"]
    assert _values(second) == ["first", "second"]


def test_forced_name_collision_never_overwrites_prior_snapshot(tmp_path, monkeypatch):
    db = tmp_path / "companion.db"
    _make_db(db, "original")
    backups = tmp_path / "backups"

    monkeypatch.setattr(backup_mod, "_snapshot_name", lambda label: f"pre_{label}_fixed.db")
    first = create_pre_migration_backup(db, backups, label="migration")
    first_hash = _sha(first)

    conn = sqlite3.connect(db)
    conn.execute("INSERT INTO t (val) VALUES ('newer')")
    conn.commit()
    conn.close()

    with pytest.raises(SQLiteBackupError, match="already exists"):
        create_pre_migration_backup(db, backups, label="migration")

    assert _sha(first) == first_hash
    assert _values(first) == ["original"]
    leftovers = [p for p in backups.iterdir() if p != first]
    assert leftovers == [], f"failed attempt must not leave partial files: {leftovers}"


# ---------------------------------------------------------------------------
# Quiesced, staged, failure-safe restore
# ---------------------------------------------------------------------------

def test_restore_refuses_when_a_writer_is_active_and_leaves_target_untouched(tmp_path):
    db = tmp_path / "companion.db"
    _make_db(db, "good")
    backup = create_pre_migration_backup(db, tmp_path / "backups")

    writer = sqlite3.connect(db, isolation_level=None)
    writer.execute("BEGIN IMMEDIATE")
    writer.execute("INSERT INTO t (val) VALUES ('uncommitted-live-write')")
    try:
        with pytest.raises(SQLiteBackupError, match="quiesc"):
            restore_database_from_backup(backup, db)
        # Live writer still owns its transaction and can commit; nothing was clobbered.
        writer.execute("COMMIT")
    finally:
        writer.close()

    assert _values(db) == ["good", "uncommitted-live-write"]


def test_restore_never_unlinks_live_wal_or_shm_sidecars(tmp_path, monkeypatch):
    db = tmp_path / "companion.db"
    _make_db(db, "backed-up")
    backup = create_pre_migration_backup(db, tmp_path / "backups")

    # Idle reader keeps the WAL/SHM sidecars alive (no active writer => quiesced for writes).
    reader = sqlite3.connect(db)
    reader.execute("SELECT 1").fetchall()
    conn = sqlite3.connect(db)
    conn.execute("INSERT INTO t (val) VALUES ('post-backup')")
    conn.commit()
    conn.close()

    unlinked = []
    real_unlink = Path.unlink

    def spy_unlink(self, *args, **kwargs):
        unlinked.append(self.name)
        return real_unlink(self, *args, **kwargs)

    monkeypatch.setattr(Path, "unlink", spy_unlink)
    try:
        restore_database_from_backup(backup, db)
    finally:
        reader.close()

    assert not [n for n in unlinked if n.endswith("-wal") or n.endswith("-shm")]
    assert _values(db) == ["backed-up"]


def test_restore_keeps_pre_restore_safety_snapshot(tmp_path):
    db = tmp_path / "companion.db"
    _make_db(db, "backed-up")
    backup = create_pre_migration_backup(db, tmp_path / "backups")

    conn = sqlite3.connect(db)
    conn.execute("INSERT INTO t (val) VALUES ('newer-than-backup')")
    conn.commit()
    conn.close()

    restore_database_from_backup(backup, db)

    snapshots = sorted((tmp_path / "backups").glob("pre_restore_*.db"))
    assert len(snapshots) == 1, "newer live writes must remain recoverable"
    assert _values(snapshots[0]) == ["backed-up", "newer-than-backup"]
    assert _values(db) == ["backed-up"]


def test_restore_rejects_corrupt_backup_without_touching_target(tmp_path):
    db = tmp_path / "companion.db"
    _make_db(db, "live")
    before = _values(db)

    bad_backup = tmp_path / "bad.db"
    bad_backup.write_bytes(b"this is not a sqlite database" * 100)

    with pytest.raises(SQLiteBackupError):
        restore_database_from_backup(bad_backup, db)

    assert _values(db) == before
    assert verify_sqlite_integrity(db) is True


def test_failed_post_restore_verification_rolls_back_to_safety_snapshot(tmp_path, monkeypatch):
    db = tmp_path / "companion.db"
    _make_db(db, "old-backup-state")
    backup = create_pre_migration_backup(db, tmp_path / "backups")

    conn = sqlite3.connect(db)
    conn.execute("INSERT INTO t (val) VALUES ('live-state')")
    conn.commit()
    conn.close()

    real_verify = backup_mod.verify_sqlite_integrity
    state = {"failed_once": False}

    def flaky_verify(path):
        if Path(path) == db and not state["failed_once"]:
            state["failed_once"] = True
            raise SQLiteBackupError("simulated post-restore verification failure")
        return real_verify(path)

    monkeypatch.setattr(backup_mod, "verify_sqlite_integrity", flaky_verify)

    with pytest.raises(SQLiteBackupError, match="rolled back"):
        restore_database_from_backup(backup, db)

    assert _values(db) == ["old-backup-state", "live-state"]
    assert real_verify(db) is True
