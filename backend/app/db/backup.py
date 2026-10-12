"""SQLite WAL-safe pre-migration backup and restore utility (PC-RESILIENCE-002).

This module provides thread-safe, WAL-consistent online database snapshots using
Python's native sqlite3 Connection.backup API, integrity verification via SQLite
pragmas, and safe quiesced restoration.
"""

from datetime import datetime, timezone
import logging
import os
from pathlib import Path
import sqlite3
from typing import Optional

logger = logging.getLogger(__name__)


class SQLiteBackupError(Exception):
    """Raised when SQLite backup or restore operations fail."""
    pass


class MigrationAmbiguityError(Exception):
    """Raised when legacy data contains unexpected owner_id values that cannot be safely mapped."""
    pass


def verify_sqlite_integrity(db_path: Path) -> bool:
    """Run PRAGMA integrity_check and PRAGMA foreign_key_check on an existing database file.

    Returns True if both checks pass. Raises SQLiteBackupError if corrupt or invalid.
    """
    if not db_path.exists() or not db_path.is_file():
        raise SQLiteBackupError(f"Database file does not exist: {db_path}")

    if db_path.stat().st_size == 0:
        raise SQLiteBackupError(f"Database file is an invalid zero-byte file: {db_path}")

    conn: Optional[sqlite3.Connection] = None
    try:
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        # Check structural and page integrity
        integrity_res = cur.execute("PRAGMA integrity_check;").fetchall()
        if not integrity_res or integrity_res[0][0] != "ok":
            error_details = "; ".join(row[0] for row in integrity_res)
            raise SQLiteBackupError(f"Integrity check failed for {db_path}: {error_details}")

        # Check foreign key consistency
        fk_violations = cur.execute("PRAGMA foreign_key_check;").fetchall()
        if fk_violations:
            raise SQLiteBackupError(f"Foreign key violations found in {db_path}: {len(fk_violations)} violations")

        return True
    except sqlite3.DatabaseError as exc:
        raise SQLiteBackupError(f"SQLite error inspecting {db_path}: {exc}") from exc
    finally:
        if conn:
            conn.close()


def create_pre_migration_backup(
    source_db_path: Path,
    backup_dir: Path,
    label: str = "migration",
) -> Path:
    """Create an atomic, WAL-consistent online backup of the source database.

    Uses sqlite3 Connection.backup() to cleanly capture active uncheckpointed WAL pages.
    Verifies destination file integrity before returning.
    """
    if not source_db_path.exists():
        raise SQLiteBackupError(f"Source database does not exist: {source_db_path}")

    if source_db_path.stat().st_size == 0:
        raise SQLiteBackupError(f"Source database is an empty file: {source_db_path}")

    backup_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    backup_filename = f"pre_{label}_{timestamp}.db"
    backup_path = backup_dir / backup_filename

    source_conn: Optional[sqlite3.Connection] = None
    dest_conn: Optional[sqlite3.Connection] = None

    try:
        source_conn = sqlite3.connect(source_db_path)
        dest_conn = sqlite3.connect(backup_path)

        # Online WAL-safe backup: blocks concurrent page writes per step, captures active WAL state
        source_conn.backup(dest_conn)
        dest_conn.commit()
    except Exception as exc:
        if backup_path.exists():
            try:
                backup_path.unlink()
            except OSError:
                pass
        raise SQLiteBackupError(f"Failed to create pre-migration backup for {source_db_path}: {exc}") from exc
    finally:
        if dest_conn:
            dest_conn.close()
        if source_conn:
            source_conn.close()

    # Validate destination integrity
    verify_sqlite_integrity(backup_path)
    logger.info(f"Successfully created and verified pre-migration backup at: {backup_path}")
    return backup_path


def restore_database_from_backup(
    backup_path: Path,
    target_db_path: Path,
) -> None:
    """Safely restore a database from a verified backup snapshot.

    Requires target writers to be quiesced. Cleans up stale -wal and -shm files
    at the destination to prevent dangerous WAL sidecar mixing.
    """
    if not backup_path.exists():
        raise SQLiteBackupError(f"Backup file does not exist: {backup_path}")

    verify_sqlite_integrity(backup_path)

    target_db_path.parent.mkdir(parents=True, exist_ok=True)

    # 1. Clean up stale sidecar files at destination before restoration
    wal_file = target_db_path.parent / f"{target_db_path.name}-wal"
    shm_file = target_db_path.parent / f"{target_db_path.name}-shm"

    for sidecar in (wal_file, shm_file):
        if sidecar.exists():
            try:
                sidecar.unlink()
            except OSError as exc:
                logger.warning(f"Could not unlink stale sidecar {sidecar} during restore: {exc}")

    # 2. Use sqlite3 backup from verified source to target
    source_conn: Optional[sqlite3.Connection] = None
    dest_conn: Optional[sqlite3.Connection] = None

    try:
        source_conn = sqlite3.connect(backup_path)
        dest_conn = sqlite3.connect(target_db_path)
        source_conn.backup(dest_conn)
        dest_conn.commit()
    except Exception as exc:
        raise SQLiteBackupError(f"Failed to restore database from {backup_path} to {target_db_path}: {exc}") from exc
    finally:
        if dest_conn:
            dest_conn.close()
        if source_conn:
            source_conn.close()

    # 3. Post-restore integrity check
    verify_sqlite_integrity(target_db_path)
    logger.info(f"Successfully restored database from {backup_path} to {target_db_path}")
