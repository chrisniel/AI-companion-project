"""Tests for preflight validation, atomic migration, restart safety, and ambiguity detection (8P.3C, 8P.3D)."""

import hashlib
import os
import shutil
import sqlite3
from pathlib import Path
import pytest

from app.core.storage import (
    CandidateInspectionResult,
    MigrationDecision,
    MigrationAmbiguityError,
    MigrationVerificationError,
    StorageError,
    inspect_legacy_candidate,
    assess_migration_preflight,
    execute_migration,
)
try:
    from app.core.storage import CorruptCanonicalDatabaseError
except ImportError:
    class CorruptCanonicalDatabaseError(StorageError):
        pass


def _create_sqlite_db(path: Path, alembic_version: str = "005_scope_message_constraints", extra_table: bool = True) -> None:
    """Helper to create a valid SQLite DB fixture with tables and alembic revision."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    cur = conn.cursor()
    cur.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL);")
    cur.execute("INSERT INTO alembic_version (version_num) VALUES (?);", (alembic_version,))
    if extra_table:
        cur.execute("CREATE TABLE messages (id INTEGER PRIMARY KEY, content TEXT);")
        cur.execute("INSERT INTO messages (content) VALUES ('test message');")
    conn.commit()
    conn.close()


def test_inspect_candidate_valid(tmp_path):
    """Valid non-empty SQLite database is properly inspected."""
    db_file = tmp_path / "valid.db"
    _create_sqlite_db(db_file, alembic_version="005_scope")

    res = inspect_legacy_candidate(db_file)
    assert res.is_valid is True
    assert res.size > 0
    assert len(res.sha256) == 64
    assert res.alembic_version == "005_scope"
    assert res.integrity_ok is True


def test_inspect_candidate_zero_byte_rejected(tmp_path):
    """Zero-byte file is rejected as invalid."""
    empty_db = tmp_path / "empty.db"
    empty_db.write_bytes(b"")

    res = inspect_legacy_candidate(empty_db)
    assert res.is_valid is False
    assert res.error == "Zero-byte file"


def test_inspect_candidate_corrupt_rejected(tmp_path):
    """Corrupt or non-SQLite file is rejected."""
    corrupt_db = tmp_path / "corrupt.db"
    corrupt_db.write_bytes(b"This is not a sqlite database header at all!")

    res = inspect_legacy_candidate(corrupt_db)
    assert res.is_valid is False
    assert "not a database" in (res.error or "").lower() or res.integrity_ok is False


def test_preflight_canonical_already_exists(tmp_path):
    """When canonical DB exists, preflight returns CANONICAL_EXISTS with no migration."""
    canonical_db = tmp_path / "database" / "companion.db"
    _create_sqlite_db(canonical_db)

    legacy_db = tmp_path / "legacy" / "companion.db"
    _create_sqlite_db(legacy_db)

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[legacy_db],
    )
    assert decision.action == "CANONICAL_EXISTS"
    assert decision.source is None


def test_preflight_no_legacy_candidates_fresh_install(tmp_path):
    """When canonical DB is absent and no legacy candidates exist, action is FRESH_INSTALL."""
    canonical_db = tmp_path / "database" / "companion.db"

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[tmp_path / "nonexistent.db"],
    )
    assert decision.action == "FRESH_INSTALL"
    assert decision.source is None


def test_preflight_single_valid_candidate_permits_migration(tmp_path):
    """Exactly one valid candidate yields MIGRATE decision."""
    canonical_db = tmp_path / "database" / "companion.db"
    legacy_db = tmp_path / "legacy" / "companion.db"
    _create_sqlite_db(legacy_db)

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[legacy_db, tmp_path / "backend" / "companion.db"],  # second doesn't exist
    )
    assert decision.action == "MIGRATE"
    assert decision.source == legacy_db.resolve()


def test_preflight_multiple_differing_candidates_raises_ambiguity(tmp_path):
    """Multiple differing non-empty candidates MUST raise MigrationAmbiguityError and create NO DB."""
    canonical_db = tmp_path / "database" / "companion.db"
    legacy_1 = tmp_path / "legacy1" / "companion.db"
    legacy_2 = tmp_path / "legacy2" / "companion.db"

    _create_sqlite_db(legacy_1, alembic_version="005_scope", extra_table=True)
    _create_sqlite_db(legacy_2, alembic_version="004_soft_delete", extra_table=False)

    with pytest.raises(MigrationAmbiguityError) as exc_info:
        assess_migration_preflight(
            canonical_db_path=canonical_db,
            legacy_candidates=[legacy_1, legacy_2],
        )

    assert "ambiguity" in str(exc_info.value).lower()
    assert not canonical_db.exists(), "Ambiguity must create NO canonical database!"


def test_preflight_multiple_byte_identical_candidates_handled_safely(tmp_path):
    """Multiple byte-identical candidates are detected as equivalent and do not raise ambiguity."""
    canonical_db = tmp_path / "database" / "companion.db"
    legacy_1 = tmp_path / "legacy1" / "companion.db"
    legacy_2 = tmp_path / "legacy2" / "companion.db"

    _create_sqlite_db(legacy_1, alembic_version="005_scope")
    legacy_2.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(legacy_1, legacy_2)  # byte identical!

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[legacy_1, legacy_2],
    )
    assert decision.action == "MIGRATE_EQUIVALENT"
    assert decision.source in [legacy_1.resolve(), legacy_2.resolve()]


def test_execute_migration_safe_copy_verification_and_backup(tmp_path):
    """Migration must copy (not move), verify SHA256 & integrity, promote atomically, and create backup."""
    canonical_dir = tmp_path / "canonical" / "database"
    canonical_db = canonical_dir / "companion.db"
    backup_dir = tmp_path / "canonical" / "backups"

    legacy_db = tmp_path / "legacy" / "companion.db"
    _create_sqlite_db(legacy_db, alembic_version="005_scope")

    original_stat = legacy_db.stat()
    original_sha256 = hashlib.sha256(legacy_db.read_bytes()).hexdigest()

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[legacy_db],
    )

    result = execute_migration(
        decision=decision,
        canonical_db_path=canonical_db,
        backup_dir=backup_dir,
    )

    assert result.migrated is True
    # Canonical DB exists and passes integrity check & retains alembic revision
    assert canonical_db.exists()
    canonical_info = inspect_legacy_candidate(canonical_db)
    assert canonical_info.is_valid is True
    assert canonical_info.integrity_ok is True
    assert canonical_info.alembic_version == "005_scope"

    # Legacy source remains untouched
    assert legacy_db.exists()
    assert hashlib.sha256(legacy_db.read_bytes()).hexdigest() == original_sha256
    assert legacy_db.stat().st_size == original_stat.st_size

    # Backup created from canonical DB
    backups = list(backup_dir.glob("companion.db.backup-*"))
    assert len(backups) == 1
    assert hashlib.sha256(backups[0].read_bytes()).hexdigest() == hashlib.sha256(canonical_db.read_bytes()).hexdigest()
    assert inspect_legacy_candidate(backups[0]).integrity_ok is True

    # No leftover .migrating file
    assert not (canonical_dir / "companion.db.migrating").exists()


def test_restart_safety_does_not_recopy(tmp_path):
    """On subsequent run with canonical DB already present, execute_migration does nothing."""
    canonical_dir = tmp_path / "canonical" / "database"
    canonical_db = canonical_dir / "companion.db"
    backup_dir = tmp_path / "canonical" / "backups"
    legacy_db = tmp_path / "legacy" / "companion.db"

    _create_sqlite_db(canonical_db, alembic_version="005_scope")
    _create_sqlite_db(legacy_db, alembic_version="005_scope")

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[legacy_db],
    )
    assert decision.action == "CANONICAL_EXISTS"

    result = execute_migration(
        decision=decision,
        canonical_db_path=canonical_db,
        backup_dir=backup_dir,
    )
    assert result.migrated is False
    assert len(list(backup_dir.glob("*"))) == 0


def test_stale_temp_file_cleaned_without_overwriting_canonical(tmp_path):
    """Stale .migrating files do not corrupt or overwrite an existing valid canonical DB."""
    canonical_dir = tmp_path / "canonical" / "database"
    canonical_dir.mkdir(parents=True, exist_ok=True)
    canonical_db = canonical_dir / "companion.db"
    _create_sqlite_db(canonical_db, alembic_version="005_scope")

    stale_temp = canonical_dir / "companion.db.migrating"
    stale_temp.write_bytes(b"stale partial content")

    backup_dir = tmp_path / "canonical" / "backups"

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[],
    )
    result = execute_migration(
        decision=decision,
        canonical_db_path=canonical_db,
        backup_dir=backup_dir,
    )
    assert result.migrated is False
    # Stale temp removed safely
    assert not stale_temp.exists()
    # Canonical DB untouched and valid
    conn = sqlite3.connect(canonical_db)
    assert conn.execute("PRAGMA integrity_check;").fetchone()[0] == "ok"
    conn.close()


def test_wal_safe_migration_preserves_uncheckpointed_committed_data(tmp_path):
    """Migration must preserve committed data in SQLite WAL without requiring checkpoint."""
    source_dir = tmp_path / "legacy"
    source_dir.mkdir(parents=True, exist_ok=True)
    source_db = source_dir / "companion.db"

    # Create DB in WAL mode and disable autocheckpoint
    conn = sqlite3.connect(source_db)
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA wal_autocheckpoint = 0;")
    conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL);")
    conn.execute("INSERT INTO alembic_version (version_num) VALUES ('005_scope_message_constraints');")
    conn.execute("CREATE TABLE wal_test_table (id INTEGER PRIMARY KEY, payload TEXT);")
    conn.commit()
    # Checkpoint initial DDL so main .db has tables
    conn.execute("PRAGMA wal_checkpoint(TRUNCATE);")

    # Insert committed transaction strictly into WAL
    conn.execute("INSERT INTO wal_test_table (payload) VALUES ('committed_in_wal_only');")
    conn.commit()

    wal_file = source_dir / "companion.db-wal"
    assert wal_file.exists()
    assert wal_file.stat().st_size > 0

    canonical_dir = tmp_path / "canonical" / "database"
    canonical_db = canonical_dir / "companion.db"
    backup_dir = tmp_path / "canonical" / "backups"

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[source_db],
    )
    assert decision.action == "MIGRATE"

    result = execute_migration(
        decision=decision,
        canonical_db_path=canonical_db,
        backup_dir=backup_dir,
    )
    assert result.migrated is True
    assert canonical_db.exists()

    # Query destination to prove uncheckpointed WAL row is preserved
    dest_conn = sqlite3.connect(canonical_db)
    rows = dest_conn.execute("SELECT payload FROM wal_test_table;").fetchall()
    dest_conn.close()
    conn.close()

    assert len(rows) == 1
    assert rows[0][0] == "committed_in_wal_only"


def test_corrupt_canonical_db_fails_closed(tmp_path):
    """Corrupt non-zero canonical database must raise CorruptCanonicalDatabaseError and fail closed."""
    canonical_dir = tmp_path / "canonical" / "database"
    canonical_dir.mkdir(parents=True, exist_ok=True)
    canonical_db = canonical_dir / "companion.db"
    canonical_db.write_bytes(b"corrupt non-sqlite content")

    legacy_db = tmp_path / "legacy" / "companion.db"
    _create_sqlite_db(legacy_db)

    with pytest.raises(CorruptCanonicalDatabaseError) as exc_info:
        assess_migration_preflight(
            canonical_db_path=canonical_db,
            legacy_candidates=[legacy_db],
        )
    assert "corrupt" in str(exc_info.value).lower() or "failed" in str(exc_info.value).lower()


def test_zero_byte_canonical_db_fails_closed(tmp_path):
    """Zero-byte canonical database must raise CorruptCanonicalDatabaseError and fail closed."""
    canonical_dir = tmp_path / "canonical" / "database"
    canonical_dir.mkdir(parents=True, exist_ok=True)
    canonical_db = canonical_dir / "companion.db"
    canonical_db.write_bytes(b"")

    legacy_db = tmp_path / "legacy" / "companion.db"
    _create_sqlite_db(legacy_db)

    with pytest.raises(CorruptCanonicalDatabaseError) as exc_info:
        assess_migration_preflight(
            canonical_db_path=canonical_db,
            legacy_candidates=[legacy_db],
        )
    assert "zero-byte" in str(exc_info.value).lower() or "corrupt" in str(exc_info.value).lower()


def test_candidates_with_active_wal_treated_as_ambiguous(tmp_path):
    """Multiple candidates where at least one has an active WAL cannot rely on main .db SHA256 alone."""
    canonical_db = tmp_path / "canonical" / "database" / "companion.db"
    legacy_1 = tmp_path / "legacy1" / "companion.db"
    legacy_2 = tmp_path / "legacy2" / "companion.db"

    _create_sqlite_db(legacy_1, alembic_version="005_scope")
    legacy_2.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(legacy_1, legacy_2)

    # Add an active WAL file to legacy_2
    wal_file = legacy_2.parent / "companion.db-wal"
    wal_file.write_bytes(b"active wal state")

    with pytest.raises(MigrationAmbiguityError):
        assess_migration_preflight(
            canonical_db_path=canonical_db,
            legacy_candidates=[legacy_1, legacy_2],
        )
