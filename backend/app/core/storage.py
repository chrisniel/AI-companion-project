"""Storage, data-root resolution, and persistent migration safety (Batch 8P.3).

This module encapsulates:
- Canonical Windows / OS data-root discovery
- Bootstrap locator and atomic configuration
- Canonical persistent path derivations (single source of truth)
- Read-only legacy database preflight validation
- Ambiguity detection and atomic copy/verification migration
"""

import hashlib
import json
import logging
import os
import shutil
import sqlite3
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import List, Optional

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------------

class StorageError(Exception):
    """Base exception for persistent storage errors."""
    pass


class BootstrapCorruptError(StorageError):
    """Raised when bootstrap configuration cannot be parsed."""
    pass


class MigrationAmbiguityError(StorageError):
    """Raised when multiple differing legacy databases are found without user selection."""
    pass


class MigrationVerificationError(StorageError):
    """Raised when a copied database fails post-copy checksum or integrity checks."""
    pass


# ---------------------------------------------------------------------------
# Data Models
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class CanonicalPaths:
    """Canonical persistent storage paths derived from a single COMPANION_DATA_ROOT."""
    COMPANION_DATA_ROOT: Path
    DATABASE_DIR: Path
    DATABASE_PATH: Path
    DATABASE_URL: str
    LIBRARY_DIR: Path
    MODEL_LIBRARY_DIR: Path
    INSTALLED_REGISTRY_PATH: Path
    VOICE_LIBRARY_DIR: Path
    ATTACHMENT_DIR: Path
    IMPORT_INBOX_DIR: Path
    IMPORT_STAGING_DIR: Path
    CHARACTER_DIR: Path
    MEMORY_DIR: Path
    BACKUP_DIR: Path


@dataclass(frozen=True)
class CandidateInspectionResult:
    """Read-only inspection result for a legacy database candidate."""
    path: Path
    is_valid: bool
    size: int
    sha256: str
    alembic_version: Optional[str]
    integrity_ok: bool
    error: Optional[str] = None


@dataclass(frozen=True)
class MigrationDecision:
    """Outcome of preflight migration assessment."""
    action: str  # "CANONICAL_EXISTS" | "FRESH_INSTALL" | "MIGRATE" | "MIGRATE_EQUIVALENT"
    source: Optional[Path]
    note: Optional[str] = None


@dataclass(frozen=True)
class MigrationResult:
    """Outcome of executing the migration decision."""
    migrated: bool
    source: Optional[Path]
    canonical_path: Path
    backup_path: Optional[Path]
    sha256: Optional[str]


# ---------------------------------------------------------------------------
# Root & Bootstrap Resolution (8P.3A)
# ---------------------------------------------------------------------------

def get_default_data_root() -> Path:
    """Return the approved default canonical data root for the current OS.

    On Windows: %LOCALAPPDATA%\\AI Companion\\Data
    On Linux/macOS: ~/.local/share/AI Companion/Data
    """
    if sys.platform == "win32" or "LOCALAPPDATA" in os.environ:
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            return Path(local_app_data) / "AI Companion" / "Data"
        return Path.home() / "AppData" / "Local" / "AI Companion" / "Data"
    return Path.home() / ".local" / "share" / "AI Companion" / "Data"


def get_bootstrap_path() -> Path:
    """Return the canonical location for the bootstrap locator file.

    On Windows: %LOCALAPPDATA%\\AI Companion\\bootstrap.json
    On Linux/macOS: ~/.local/share/AI Companion/bootstrap.json
    """
    if sys.platform == "win32" or "LOCALAPPDATA" in os.environ:
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            return Path(local_app_data) / "AI Companion" / "bootstrap.json"
        return Path.home() / "AppData" / "Local" / "AI Companion" / "bootstrap.json"
    return Path.home() / ".local" / "share" / "AI Companion" / "bootstrap.json"


def resolve_data_root(
    env_override: Optional[str] = None,
    bootstrap_path: Optional[Path] = None,
    default_root: Optional[Path] = None,
) -> Path:
    """Resolve the persistent data root with strict precedence.

    Precedence:
    1. COMPANION_DATA_ROOT environment variable (or explicit env_override)
    2. bootstrap.json 'data_root' attribute
    3. Approved OS default (%LOCALAPPDATA%\\AI Companion\\Data)

    This function is strictly pure and has no database or filesystem creation side effects.
    """
    # 1. Environment override
    override = env_override if env_override is not None else os.environ.get("COMPANION_DATA_ROOT")
    if override and override.strip():
        return Path(override.strip()).resolve()

    # 2. Bootstrap locator file
    b_path = bootstrap_path if bootstrap_path is not None else get_bootstrap_path()
    if b_path.exists() and b_path.is_file():
        try:
            content = b_path.read_text(encoding="utf-8")
            data = json.loads(content)
            if isinstance(data, dict) and "data_root" in data and isinstance(data["data_root"], str):
                target = data["data_root"].strip()
                if target:
                    return Path(target).resolve()
            logger.warning(f"Bootstrap file {b_path} is missing valid 'data_root'; falling back to default.")
        except Exception as exc:
            logger.warning(f"Failed to parse bootstrap file {b_path} ({exc}); falling back to default.")

    # 3. Default root
    def_root = default_root if default_root is not None else get_default_data_root()
    return def_root.resolve()


def write_bootstrap(
    data_root: Path,
    bootstrap_path: Optional[Path] = None,
    schema_version: int = 1,
) -> None:
    """Write an authoritative bootstrap locator file atomically.

    Payload contains ONLY non-secret bootstrap metadata:
    {
      "schema_version": 1,
      "data_root": "..."
    }
    """
    b_path = bootstrap_path if bootstrap_path is not None else get_bootstrap_path()
    b_path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "schema_version": schema_version,
        "data_root": str(data_root.resolve()),
    }
    serialized = json.dumps(payload, indent=2) + "\n"

    # Atomic write pattern via temp file on same directory
    temp_file = b_path.parent / f"{b_path.name}.tmp.{os.getpid()}"
    try:
        temp_file.write_text(serialized, encoding="utf-8")
        os.replace(temp_file, b_path)
    finally:
        if temp_file.exists():
            try:
                temp_file.unlink()
            except OSError:
                pass


# ---------------------------------------------------------------------------
# Canonical Paths (8P.3B)
# ---------------------------------------------------------------------------

def get_canonical_paths(data_root: Path) -> CanonicalPaths:
    """Derive all canonical persistent paths from a single resolved data root.

    This function defines paths without eagerly creating directories on disk.
    """
    root = data_root.resolve()
    db_dir = root / "database"
    db_path = db_dir / "companion.db"
    db_url = f"sqlite+aiosqlite:///{db_path.as_posix()}"

    library_dir = root / "library"
    model_lib_dir = library_dir / "models" / "llm"
    installed_registry = library_dir / "registry" / "models.json"
    voice_lib_dir = library_dir / "voices"

    attachment_dir = root / "attachments"
    import_inbox = root / "imports" / "inbox"
    import_staging = root / "imports" / "staging"
    character_dir = root / "characters"
    memory_dir = root / "memory"
    backup_dir = root / "backups"

    return CanonicalPaths(
        COMPANION_DATA_ROOT=root,
        DATABASE_DIR=db_dir,
        DATABASE_PATH=db_path,
        DATABASE_URL=db_url,
        LIBRARY_DIR=library_dir,
        MODEL_LIBRARY_DIR=model_lib_dir,
        INSTALLED_REGISTRY_PATH=installed_registry,
        VOICE_LIBRARY_DIR=voice_lib_dir,
        ATTACHMENT_DIR=attachment_dir,
        IMPORT_INBOX_DIR=import_inbox,
        IMPORT_STAGING_DIR=import_staging,
        CHARACTER_DIR=character_dir,
        MEMORY_DIR=memory_dir,
        BACKUP_DIR=backup_dir,
    )


# ---------------------------------------------------------------------------
# Legacy Database Preflight & Validation (8P.3C)
# ---------------------------------------------------------------------------

def _sha256_file(filepath: Path) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()


def inspect_legacy_candidate(db_path: Path) -> CandidateInspectionResult:
    """Inspect a legacy database candidate file safely in read-only mode."""
    if not db_path.exists() or not db_path.is_file():
        return CandidateInspectionResult(
            path=db_path,
            is_valid=False,
            size=0,
            sha256="",
            alembic_version=None,
            integrity_ok=False,
            error="File does not exist or is not a regular file",
        )

    size = db_path.stat().st_size
    if size == 0:
        return CandidateInspectionResult(
            path=db_path,
            is_valid=False,
            size=0,
            sha256="",
            alembic_version=None,
            integrity_ok=False,
            error="Zero-byte file",
        )

    # Validate 16-byte SQLite header
    try:
        with open(db_path, "rb") as f:
            header = f.read(16)
        if header != b"SQLite format 3\x00":
            return CandidateInspectionResult(
                path=db_path,
                is_valid=False,
                size=size,
                sha256="",
                alembic_version=None,
                integrity_ok=False,
                error="Invalid SQLite format header",
            )
    except Exception as exc:
        return CandidateInspectionResult(
            path=db_path,
            is_valid=False,
            size=size,
            sha256="",
            alembic_version=None,
            integrity_ok=False,
            error=f"Cannot read file header: {exc}",
        )

    # Read-only SQLite verification (no content printed or retrieved)
    conn = None
    try:
        uri_path = f"file:{db_path.resolve()}?mode=ro"
        conn = sqlite3.connect(uri_path, uri=True)
        cur = conn.cursor()

        cur.execute("PRAGMA integrity_check;")
        check_res = cur.fetchall()
        integrity_ok = bool(check_res and check_res[0][0] == "ok")
        if not integrity_ok:
            return CandidateInspectionResult(
                path=db_path,
                is_valid=False,
                size=size,
                sha256=_sha256_file(db_path),
                alembic_version=None,
                integrity_ok=False,
                error="SQLite PRAGMA integrity_check failed",
            )

        # Check alembic revision if present
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='alembic_version';")
        has_alembic = cur.fetchone() is not None
        alembic_ver = None
        if has_alembic:
            cur.execute("SELECT version_num FROM alembic_version LIMIT 1;")
            row = cur.fetchone()
            if row:
                alembic_ver = str(row[0])

        sha = _sha256_file(db_path)
        return CandidateInspectionResult(
            path=db_path,
            is_valid=True,
            size=size,
            sha256=sha,
            alembic_version=alembic_ver,
            integrity_ok=True,
            error=None,
        )
    except Exception as exc:
        return CandidateInspectionResult(
            path=db_path,
            is_valid=False,
            size=size,
            sha256="",
            alembic_version=None,
            integrity_ok=False,
            error=f"SQLite inspection error: {exc}",
        )
    finally:
        if conn:
            conn.close()


def assess_migration_preflight(
    canonical_db_path: Path,
    legacy_candidates: List[Path],
) -> MigrationDecision:
    """Assess whether migration is required, safe, ambiguous, or fresh install.

    Rules:
    1. Canonical DB exists and non-empty -> CANONICAL_EXISTS (never overwrite)
    2. Canonical absent + no valid legacy DBs -> FRESH_INSTALL
    3. Canonical absent + exactly 1 valid legacy DB -> MIGRATE
    4. Canonical absent + multiple byte-identical valid DBs -> MIGRATE_EQUIVALENT
    5. Canonical absent + multiple differing valid DBs -> STOP (MigrationAmbiguityError)
    """
    if canonical_db_path.exists() and canonical_db_path.is_file() and canonical_db_path.stat().st_size > 0:
        return MigrationDecision(
            action="CANONICAL_EXISTS",
            source=None,
            note="Canonical database already exists in persistent storage. Using existing database.",
        )

    # Inspect all legacy candidates
    valid_candidates: List[CandidateInspectionResult] = []
    for cand_path in legacy_candidates:
        res = inspect_legacy_candidate(cand_path)
        if res.is_valid:
            valid_candidates.append(res)

    if not valid_candidates:
        return MigrationDecision(
            action="FRESH_INSTALL",
            source=None,
            note="No valid legacy database candidates found. Fresh installation permitted.",
        )

    if len(valid_candidates) == 1:
        return MigrationDecision(
            action="MIGRATE",
            source=valid_candidates[0].path.resolve(),
            note=f"Exactly one valid legacy database candidate found: {valid_candidates[0].path}",
        )

    # Multiple valid candidates found: check if byte-identical
    distinct_hashes = {c.sha256 for c in valid_candidates}
    if len(distinct_hashes) == 1:
        # Sort deterministically by string path
        chosen = sorted(valid_candidates, key=lambda x: str(x.path))[0]
        return MigrationDecision(
            action="MIGRATE_EQUIVALENT",
            source=chosen.path.resolve(),
            note=(
                f"Multiple byte-identical legacy candidates detected ({[str(c.path) for c in valid_candidates]}). "
                f"Using representative: {chosen.path}"
            ),
        )

    # Differing candidates: strictly STOP and raise MigrationAmbiguityError
    candidates_info = [
        f"{c.path} (size={c.size}, alembic={c.alembic_version}, sha256={c.sha256[:12]}...)"
        for c in valid_candidates
    ]
    err_msg = (
        f"Migration ambiguity detected: Found {len(valid_candidates)} differing legacy database candidates:\n"
        + "\n".join(f"  - {info}" for info in candidates_info)
        + "\nAutomated migration cannot safely guess which database to use without risking data loss. "
        "Please specify which database to migrate or archive redundant candidates before proceeding."
    )
    logger.error(err_msg)
    raise MigrationAmbiguityError(err_msg)


# ---------------------------------------------------------------------------
# Safe Copy & Migration Execution (8P.3D)
# ---------------------------------------------------------------------------

def execute_migration(
    decision: MigrationDecision,
    canonical_db_path: Path,
    backup_dir: Path,
) -> MigrationResult:
    """Execute the migration decision with atomic copy, verification, and backup.

    Original legacy source file is NEVER moved or deleted; it remains untouched.
    """
    if decision.action in ("CANONICAL_EXISTS", "FRESH_INSTALL"):
        # Safe cleanup of any stale migration temp files without touching canonical DB
        temp_file = canonical_db_path.parent / f"{canonical_db_path.name}.migrating"
        if temp_file.exists():
            try:
                temp_file.unlink()
            except OSError:
                pass
        return MigrationResult(
            migrated=False,
            source=None,
            canonical_path=canonical_db_path,
            backup_path=None,
            sha256=None,
        )

    if decision.action not in ("MIGRATE", "MIGRATE_EQUIVALENT") or not decision.source:
        raise StorageError(f"Unexpected migration action: {decision.action}")

    source_path = decision.source
    if not source_path.exists() or not source_path.is_file():
        raise StorageError(f"Migration source disappeared before execution: {source_path}")

    # Inspect source to get verified baseline
    source_info = inspect_legacy_candidate(source_path)
    if not source_info.is_valid:
        raise MigrationVerificationError(f"Migration source failed pre-migration inspection: {source_info.error}")

    # Ensure destination and backup directories exist
    canonical_db_path.parent.mkdir(parents=True, exist_ok=True)
    backup_dir.mkdir(parents=True, exist_ok=True)

    temp_target = canonical_db_path.parent / f"{canonical_db_path.name}.migrating"
    if temp_target.exists():
        temp_target.unlink()

    # Step 1: Copy to temp file (leave source untouched)
    try:
        shutil.copy2(source_path, temp_target)
    except Exception as exc:
        if temp_target.exists():
            temp_target.unlink(missing_ok=True)
        raise StorageError(f"Failed to copy legacy database from {source_path} to {temp_target}: {exc}")

    # Step 2: Thorough verification of copied file
    copied_info = inspect_legacy_candidate(temp_target)
    if not copied_info.is_valid:
        temp_target.unlink(missing_ok=True)
        raise MigrationVerificationError(f"Copied database failed inspection: {copied_info.error}")

    if copied_info.size != source_info.size:
        temp_target.unlink(missing_ok=True)
        raise MigrationVerificationError(
            f"Copied size mismatch: source has {source_info.size} bytes, copy has {copied_info.size} bytes"
        )

    if copied_info.sha256 != source_info.sha256:
        temp_target.unlink(missing_ok=True)
        raise MigrationVerificationError(
            f"Copied checksum mismatch: source SHA256 is {source_info.sha256}, copy is {copied_info.sha256}"
        )

    if copied_info.alembic_version != source_info.alembic_version:
        temp_target.unlink(missing_ok=True)
        raise MigrationVerificationError(
            f"Copied Alembic version mismatch: source has {source_info.alembic_version}, copy has {copied_info.alembic_version}"
        )

    # Step 3: Promote atomically to canonical path
    try:
        os.replace(temp_target, canonical_db_path)
    except Exception as exc:
        temp_target.unlink(missing_ok=True)
        raise StorageError(f"Failed to atomically promote migration temp file to {canonical_db_path}: {exc}")

    # Step 4: Preserve a backup in BACKUP_DIR
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    backup_file = backup_dir / f"{canonical_db_path.name}.backup-{timestamp}"
    try:
        shutil.copy2(canonical_db_path, backup_file)
    except Exception as exc:
        logger.warning(f"Failed to create persistent backup copy at {backup_file}: {exc}")

    logger.info(
        f"Successfully migrated legacy database from {source_path} to {canonical_db_path} "
        f"(SHA256={source_info.sha256}, Backup={backup_file.name})"
    )

    return MigrationResult(
        migrated=True,
        source=source_path,
        canonical_path=canonical_db_path,
        backup_path=backup_file if backup_file.exists() else None,
        sha256=source_info.sha256,
    )
