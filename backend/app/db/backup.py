"""SQLite WAL-safe pre-migration backup and restore utility (PC-RESILIENCE-002).

Safety properties:
- Backups use sqlite3 ``Connection.backup`` (captures committed, uncheckpointed WAL pages).
- Every snapshot gets a collision-proof name and is published with no-overwrite semantics,
  so a prior verified recovery snapshot is never replaced.
- Snapshots are staged, integrity-verified, and only then published.
- Restoration never unlinks or replaces live ``-wal``/``-shm`` files and never swaps the live
  file underneath SQLite. It verifies writer quiescence, stages and verifies the backup,
  keeps a verified pre-restore snapshot of the live database, applies the staged copy through
  SQLite's own transactional backup API, re-verifies, and rolls back on failure.
"""

from datetime import datetime, timezone
import logging
import os
from pathlib import Path
import sqlite3
from typing import Optional
import uuid

logger = logging.getLogger(__name__)

_QUIESCENCE_PROBE_TIMEOUT_SECONDS = 0.25
_APPLY_TIMEOUT_SECONDS = 0.5


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


def _unique_suffix() -> str:
    return uuid.uuid4().hex[:12]


def _snapshot_name(label: str) -> str:
    """Collision-proof snapshot file name: label + UTC microsecond timestamp + random suffix."""
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
    return f"pre_{label}_{timestamp}_{_unique_suffix()}.db"


def _copy_via_backup_api(source: Path, destination: Path) -> None:
    """Copy a database with SQLite's online backup API (WAL-consistent)."""
    source_conn: Optional[sqlite3.Connection] = None
    dest_conn: Optional[sqlite3.Connection] = None
    try:
        source_conn = sqlite3.connect(source)
        dest_conn = sqlite3.connect(destination)
        source_conn.backup(dest_conn)
        dest_conn.commit()
    finally:
        if dest_conn:
            dest_conn.close()
        if source_conn:
            source_conn.close()


def _discard(path: Path) -> None:
    """Remove a file we created ourselves (staging artifacts only)."""
    try:
        if path.exists():
            path.unlink()
    except OSError:
        logger.warning("Could not remove temporary file %s", path)


def _publish_without_overwrite(staged: Path, final: Path) -> None:
    """Atomically expose a verified staged file under ``final`` without ever replacing a file."""
    try:
        os.link(staged, final)  # fails with FileExistsError if final exists
    except FileExistsError as exc:
        raise SQLiteBackupError(f"Backup snapshot already exists and was not overwritten: {final}") from exc
    except OSError:
        # Filesystem without hard links: fall back to exists-check + rename.
        if final.exists():
            raise SQLiteBackupError(f"Backup snapshot already exists and was not overwritten: {final}")
        os.rename(staged, final)
        return
    _discard(staged)


def create_pre_migration_backup(
    source_db_path: Path,
    backup_dir: Path,
    label: str = "migration",
) -> Path:
    """Create an atomic, WAL-consistent, verified, never-overwriting backup of the source database.

    The snapshot is written to a private staging file, integrity-verified, then published under
    a collision-proof name. An existing snapshot is never replaced; on any failure only this
    call's own staging file is removed.
    """
    if not source_db_path.exists():
        raise SQLiteBackupError(f"Source database does not exist: {source_db_path}")

    if source_db_path.stat().st_size == 0:
        raise SQLiteBackupError(f"Source database is an empty file: {source_db_path}")

    backup_dir.mkdir(parents=True, exist_ok=True)
    final_path = backup_dir / _snapshot_name(label)
    if final_path.exists():
        raise SQLiteBackupError(f"Backup snapshot already exists and was not overwritten: {final_path}")

    staged_path = final_path.with_name(f".{final_path.name}.partial")
    if staged_path.exists():
        raise SQLiteBackupError(f"Backup staging file already exists and was not reused: {staged_path}")

    try:
        _copy_via_backup_api(source_db_path, staged_path)
        verify_sqlite_integrity(staged_path)
        _publish_without_overwrite(staged_path, final_path)
    except SQLiteBackupError:
        _discard(staged_path)
        raise
    except Exception as exc:
        _discard(staged_path)
        raise SQLiteBackupError(f"Failed to create pre-migration backup for {source_db_path}: {exc}") from exc

    logger.info(f"Successfully created and verified pre-migration backup at: {final_path}")
    return final_path


def _assert_writers_quiesced(target_db_path: Path) -> None:
    """Verify nobody is writing to the live database by taking (then releasing) a write lock.

    The caller remains responsible for stopping the application first; this check refuses to
    proceed if a writer is still active.
    """
    probe: Optional[sqlite3.Connection] = None
    try:
        probe = sqlite3.connect(
            target_db_path,
            timeout=_QUIESCENCE_PROBE_TIMEOUT_SECONDS,
            isolation_level=None,
        )
        probe.execute("BEGIN EXCLUSIVE")
        probe.execute("ROLLBACK")
    except sqlite3.Error as exc:
        raise SQLiteBackupError(
            f"Refusing to restore: database writers are not quiesced for {target_db_path} ({exc}). "
            "Stop the application and retry."
        ) from exc
    finally:
        if probe:
            probe.close()


def _apply_snapshot_to_live(snapshot_path: Path, target_db_path: Path) -> None:
    """Apply a snapshot through SQLite's transactional backup API (no file swapping, no sidecar edits).

    The destination is only modified by a single atomic write transaction; failure leaves it unchanged.
    """
    source_conn: Optional[sqlite3.Connection] = None
    dest_conn: Optional[sqlite3.Connection] = None
    try:
        source_conn = sqlite3.connect(snapshot_path)
        dest_conn = sqlite3.connect(target_db_path, timeout=_APPLY_TIMEOUT_SECONDS)
        source_conn.backup(dest_conn)
        dest_conn.commit()
    finally:
        if dest_conn:
            dest_conn.close()
        if source_conn:
            source_conn.close()


def restore_database_from_backup(
    backup_path: Path,
    target_db_path: Path,
    safety_dir: Optional[Path] = None,
) -> Optional[Path]:
    """Restore a verified backup over ``target_db_path`` in a staged, failure-safe way.

    Sequence: verify backup -> stage + verify a private copy -> verify writer quiescence ->
    take a verified pre-restore snapshot of the live database (kept in ``safety_dir``, default
    the backup's directory) -> apply via SQLite's backup API -> verify -> on failure roll back
    to the pre-restore snapshot. Live ``-wal``/``-shm`` files are never unlinked or replaced.

    Returns the pre-restore safety snapshot path (None if the target did not exist).
    Raises SQLiteBackupError (fail closed, target untouched) if any pre-apply step fails.
    """
    if not backup_path.exists():
        raise SQLiteBackupError(f"Backup file does not exist: {backup_path}")

    verify_sqlite_integrity(backup_path)

    target_db_path.parent.mkdir(parents=True, exist_ok=True)
    staged_path = target_db_path.parent / f".{target_db_path.name}.restore-{_unique_suffix()}.staged"
    safety_snapshot: Optional[Path] = None

    try:
        # 1. Stage a private copy of the backup and verify it before touching the live DB.
        _copy_via_backup_api(backup_path, staged_path)
        verify_sqlite_integrity(staged_path)

        target_exists = target_db_path.exists() and target_db_path.stat().st_size > 0
        if target_exists:
            # 2. Require writer quiescence, then preserve the live state before replacing it.
            _assert_writers_quiesced(target_db_path)
            safety_snapshot = create_pre_migration_backup(
                target_db_path,
                safety_dir if safety_dir is not None else backup_path.parent,
                label="restore",
            )

        # 3. Apply through SQLite itself (atomic; unchanged on failure).
        try:
            _apply_snapshot_to_live(staged_path, target_db_path)
        except sqlite3.Error as exc:
            raise SQLiteBackupError(
                f"Failed to restore database from {backup_path} to {target_db_path}: {exc}"
            ) from exc

        # 4. Verify the result; roll back to the pre-restore snapshot if it is not healthy.
        try:
            verify_sqlite_integrity(target_db_path)
        except SQLiteBackupError as verify_exc:
            if safety_snapshot is None:
                raise SQLiteBackupError(
                    f"Restored database failed verification and no pre-restore snapshot exists: {verify_exc}"
                ) from verify_exc
            try:
                _apply_snapshot_to_live(safety_snapshot, target_db_path)
                verify_sqlite_integrity(target_db_path)
            except (sqlite3.Error, SQLiteBackupError) as rollback_exc:
                raise SQLiteBackupError(
                    f"Restore verification failed ({verify_exc}) and automatic rollback also failed "
                    f"({rollback_exc}). Recover manually from snapshot: {safety_snapshot}"
                ) from rollback_exc
            raise SQLiteBackupError(
                f"Restored database failed verification and was rolled back to the pre-restore "
                f"snapshot {safety_snapshot}: {verify_exc}"
            ) from verify_exc
    finally:
        _discard(staged_path)

    logger.info(f"Successfully restored database from {backup_path} to {target_db_path}")
    return safety_snapshot
