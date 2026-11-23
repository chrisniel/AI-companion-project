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


class CorruptCanonicalDatabaseError(StorageError):
    """Raised when an existing canonical database fails validation or integrity checks."""
    pass


# ---------------------------------------------------------------------------
# Data Models
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class CanonicalPaths:
    """Canonical persistent storage paths resolved from the five host storage roots."""
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
    APP_INSTALL_ROOT: Path
    CACHE_ROOT: Path
    LOG_ROOT: Path


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


def get_default_cache_root() -> Path:
    """Return the default disposable cache root for the current OS."""
    if sys.platform == "win32" or "LOCALAPPDATA" in os.environ:
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            return Path(local_app_data) / "AI Companion" / "Cache"
        return Path.home() / "AppData" / "Local" / "AI Companion" / "Cache"
    return Path.home() / ".cache" / "ai-companion"


def get_default_log_root() -> Path:
    """Return the default diagnostic log root for the current OS."""
    if sys.platform == "win32" or "LOCALAPPDATA" in os.environ:
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            return Path(local_app_data) / "AI Companion" / "Logs"
        return Path.home() / "AppData" / "Local" / "AI Companion" / "Logs"
    return Path.home() / ".local" / "state" / "ai-companion" / "logs"


def get_default_app_install_root() -> Path:
    """Return the application install/repo root purely without side effects."""
    # backend/app/core/storage.py -> repo/install root (3 parents up from app/core -> backend, 4 -> root)
    return Path(__file__).resolve().parent.parent.parent.parent


def _resolve_absolute_env_path(env_name: str, env_override: Optional[str]) -> Optional[Path]:
    raw = env_override if env_override is not None else os.environ.get(env_name)
    if raw and raw.strip():
        candidate = Path(raw.strip())
        if not candidate.is_absolute():
            raise StorageError(f"{env_name} must be an absolute path, got relative path: '{raw.strip()}'")
        return candidate.resolve()
    return None


def resolve_app_install_root(
    env_override: Optional[str] = None,
    default_root: Optional[Path] = None,
) -> Path:
    """Resolve APP_INSTALL_ROOT purely without filesystem side effects."""
    override = _resolve_absolute_env_path("COMPANION_APP_INSTALL_ROOT", env_override)
    if override is not None:
        return override
    return (default_root if default_root is not None else get_default_app_install_root()).resolve()


def resolve_cache_root(
    env_override: Optional[str] = None,
    default_root: Optional[Path] = None,
) -> Path:
    """Resolve CACHE_ROOT purely without filesystem side effects."""
    override = _resolve_absolute_env_path("COMPANION_CACHE_ROOT", env_override)
    if override is not None:
        return override
    return (default_root if default_root is not None else get_default_cache_root()).resolve()


def resolve_log_root(
    env_override: Optional[str] = None,
    default_root: Optional[Path] = None,
) -> Path:
    """Resolve LOG_ROOT purely without filesystem side effects."""
    override = _resolve_absolute_env_path("COMPANION_LOG_ROOT", env_override)
    if override is not None:
        return override
    return (default_root if default_root is not None else get_default_log_root()).resolve()


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
    Only a missing first-install locator permits default selection. An invalid
    existing locator fails closed to prevent switching persistent databases.
    """
    # 1. Environment override
    override = env_override if env_override is not None else os.environ.get("COMPANION_DATA_ROOT")
    if override and override.strip():
        val = override.strip()
        p = Path(val)
        if not p.is_absolute():
            raise StorageError(f"COMPANION_DATA_ROOT must be an absolute path, got relative path: '{val}'")
        return p.resolve()

    # 2. Bootstrap locator file
    b_path = bootstrap_path if bootstrap_path is not None else get_bootstrap_path()
    if os.path.lexists(b_path):
        try:
            if not b_path.is_file():
                raise BootstrapCorruptError("Existing bootstrap locator is not a readable file.")
            content = b_path.read_text(encoding="utf-8")
            data = json.loads(content)
            if (not isinstance(data, dict) or type(data.get("schema_version")) is not int
                    or data["schema_version"] != 1 or not isinstance(data.get("data_root"), str)
                    or not data["data_root"].strip()):
                raise BootstrapCorruptError("Existing bootstrap locator has invalid schema or data_root.")
            target_p = Path(data["data_root"].strip())
            if not target_p.is_absolute():
                raise BootstrapCorruptError("Bootstrap data_root must be an absolute path.")
            return target_p.resolve()
        except (OSError, ValueError, TypeError):
            raise BootstrapCorruptError("Existing bootstrap locator is unreadable or malformed; root selection refused.") from None

    # 3. Default root
    def_root = default_root if default_root is not None else get_default_data_root()
    return def_root.resolve()


def resolve_library_root(
    data_root: Path,
    env_override: Optional[str] = None,
    bootstrap_path: Optional[Path] = None,
    data_root_env_override: Optional[str] = None,
) -> Path:
    """Resolve LIBRARY_ROOT with strict fail-closed precedence.

    Precedence:
    1. COMPANION_LIBRARY_ROOT environment override (must be absolute)
    2. bootstrap.json 'library_root' attribute (consulted only when bootstrap_path
       is explicitly given OR COMPANION_DATA_ROOT is NOT redirecting away from global bootstrap)
    3. Default <data_root>/library
    """
    override = _resolve_absolute_env_path("COMPANION_LIBRARY_ROOT", env_override)
    if override is not None:
        return override

    dr_env = data_root_env_override if data_root_env_override is not None else os.environ.get("COMPANION_DATA_ROOT")
    should_consult_bootstrap = bootstrap_path is not None or not (dr_env and dr_env.strip())
    if should_consult_bootstrap:
        b_path = bootstrap_path if bootstrap_path is not None else get_bootstrap_path()
        if os.path.lexists(b_path):
            try:
                if not b_path.is_file():
                    raise BootstrapCorruptError("Existing bootstrap locator is not a readable file.")
                data = json.loads(b_path.read_text(encoding="utf-8"))
                if (
                    not isinstance(data, dict)
                    or type(data.get("schema_version")) is not int
                    or data["schema_version"] != 1
                ):
                    raise BootstrapCorruptError("Existing bootstrap locator has invalid schema.")
                # Only apply global bootstrap library_root if this locator owns the requested data_root.
                if bootstrap_path is None:
                    raw_dr = data.get("data_root")
                    if not isinstance(raw_dr, str) or not raw_dr.strip():
                        raise BootstrapCorruptError("Existing bootstrap locator has invalid data_root.")
                    dr_path = Path(raw_dr.strip())
                    if not dr_path.is_absolute():
                        raise BootstrapCorruptError("Bootstrap data_root must be an absolute path.")
                    if dr_path.resolve() != data_root.resolve():
                        return (data_root.resolve() / "library").resolve()
                if "library_root" in data:
                    raw_lib = data.get("library_root")
                    if not isinstance(raw_lib, str) or not raw_lib.strip():
                        raise BootstrapCorruptError("Bootstrap library_root must be a non-empty absolute path string.")
                    lib_path = Path(raw_lib.strip())
                    if not lib_path.is_absolute():
                        raise BootstrapCorruptError("Bootstrap library_root must be an absolute path.")
                    return lib_path.resolve()
            except BootstrapCorruptError:
                raise
            except (OSError, ValueError, TypeError):
                raise BootstrapCorruptError(
                    "Existing bootstrap locator is unreadable or malformed; library root selection refused."
                ) from None

    return (data_root.resolve() / "library").resolve()


def write_bootstrap(
    data_root: Path,
    bootstrap_path: Optional[Path] = None,
    schema_version: int = 1,
    library_root: Optional[Path] = None,
) -> None:
    """Write an authoritative bootstrap locator file atomically.

    Payload contains ONLY non-secret bootstrap metadata:
    {
      "schema_version": 1,
      "data_root": "...",
      "library_root": "..." // optional, omitted when None
    }
    """
    if not data_root.is_absolute():
        raise StorageError(
            f"Bootstrap data_root must be an absolute path, got relative path: '{data_root}'. "
            "Relative custom roots are rejected to ensure path invariants."
        )
    if library_root is not None and not library_root.is_absolute():
        raise StorageError(
            f"Bootstrap library_root must be an absolute path, got relative path: '{library_root}'."
        )

    b_path = bootstrap_path if bootstrap_path is not None else get_bootstrap_path()
    b_path.parent.mkdir(parents=True, exist_ok=True)

    payload: dict = {
        "schema_version": schema_version,
        "data_root": str(data_root.resolve()),
    }
    if library_root is not None:
        payload["library_root"] = str(library_root.resolve())
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


class RelocationConflictError(StorageError):
    """Raised when LIBRARY_ROOT relocation is blocked by runtime state or env override."""
    pass


def _paths_overlap(a: Path, b: Path) -> bool:
    ra = a.resolve()
    rb = b.resolve()
    return ra == rb or ra.is_relative_to(rb) or rb.is_relative_to(ra)


def relocate_library_root(
    new_library_root: Path,
    migrate_existing_assets: bool = True,
    bootstrap_path: Optional[Path] = None,
) -> Path:
    """Validate and relocate LIBRARY_ROOT atomically in bootstrap.json with optional asset migration."""
    if os.environ.get("COMPANION_LIBRARY_ROOT", "").strip():
        raise RelocationConflictError(
            "Cannot relocate LIBRARY_ROOT while COMPANION_LIBRARY_ROOT environment override is active."
        )
    if os.environ.get("COMPANION_DATA_ROOT", "").strip() and bootstrap_path is None:
        raise RelocationConflictError(
            "Cannot relocate LIBRARY_ROOT while COMPANION_DATA_ROOT environment override redirects storage."
        )

    if not new_library_root.is_absolute():
        raise StorageError(f"new_library_root must be an absolute path, got '{new_library_root}'.")

    target = new_library_root.resolve()
    b_path = bootstrap_path if bootstrap_path is not None else get_bootstrap_path()
    current_data = resolve_data_root(bootstrap_path=b_path)
    current_paths = get_canonical_paths(
        current_data,
        library_root=resolve_library_root(current_data, bootstrap_path=b_path),
    )

    if _paths_overlap(target, current_paths.LIBRARY_DIR):
        raise StorageError("Target LIBRARY_ROOT cannot be identical to or nested inside/around the current LIBRARY_ROOT.")
    if _paths_overlap(target, current_paths.DATABASE_DIR):
        raise StorageError("Target LIBRARY_ROOT cannot overlap with DATABASE_DIR.")
    if _paths_overlap(target, current_paths.APP_INSTALL_ROOT):
        raise StorageError("Target LIBRARY_ROOT cannot overlap with APP_INSTALL_ROOT.")
    if _paths_overlap(target, current_paths.CACHE_ROOT):
        raise StorageError("Target LIBRARY_ROOT cannot overlap with CACHE_ROOT.")
    if _paths_overlap(target, current_paths.LOG_ROOT):
        raise StorageError("Target LIBRARY_ROOT cannot overlap with LOG_ROOT.")
    for reserved in (
        current_paths.BACKUP_DIR,
        current_paths.ATTACHMENT_DIR,
        current_paths.CHARACTER_DIR,
        current_paths.MEMORY_DIR,
        current_paths.COMPANION_DATA_ROOT / "config",
    ):
        if _paths_overlap(target, reserved):
            raise StorageError(f"Target LIBRARY_ROOT cannot overlap with reserved runtime directory '{reserved.name}'.")
    if target == current_paths.COMPANION_DATA_ROOT or current_paths.COMPANION_DATA_ROOT.is_relative_to(target):
        raise StorageError("Target LIBRARY_ROOT cannot be DATA_ROOT itself or an ancestor of DATA_ROOT.")

    # Preserve existing bootstrap data_root verbatim if valid, else use resolved current_data
    persisted_data_root = current_data
    if os.path.lexists(b_path):
        try:
            existing_data = json.loads(b_path.read_text(encoding="utf-8"))
            if isinstance(existing_data, dict) and isinstance(existing_data.get("data_root"), str):
                persisted_data_root = Path(existing_data["data_root"].strip()).resolve()
        except Exception as exc:
            raise BootstrapCorruptError(f"Cannot read bootstrap locator before relocation: {exc}") from exc

    # Create target library structure before migrating/updating locator
    for subdir in (
        target / "models" / "llm",
        target / "registry",
        target / "voices",
        target / "imports" / "inbox",
        target / "imports" / "staging",
    ):
        subdir.mkdir(parents=True, exist_ok=True)

    if migrate_existing_assets and current_paths.LIBRARY_DIR.exists():
        # Copy models, registry, voices, and inbox (never partial staging artifacts)
        for rel_parts in (("models",), ("registry",), ("voices",), ("imports", "inbox")):
            src_dir = current_paths.LIBRARY_DIR.joinpath(*rel_parts)
            dst_dir = target.joinpath(*rel_parts)
            if not src_dir.is_dir():
                continue
            for item in src_dir.rglob("*"):
                if item.is_symlink() or not item.is_file():
                    continue
                rel_item = item.relative_to(src_dir)
                dst_item = dst_dir / rel_item
                dst_item.parent.mkdir(parents=True, exist_ok=True)
                # Containment: reject symlinks anywhere on the target path inside target
                probe = dst_item
                while True:
                    if os.path.islink(probe):
                        raise StorageError(
                            f"Target path contains a symlink component: '{rel_item.as_posix()}'."
                        )
                    if probe == target or probe.parent == probe:
                        break
                    probe = probe.parent
                shutil.copy2(item, dst_item)
                if dst_item.stat().st_size != item.stat().st_size:
                    raise MigrationVerificationError(
                        f"Migrated asset size mismatch for '{rel_item.as_posix()}'."
                    )

    write_bootstrap(
        data_root=persisted_data_root,
        bootstrap_path=b_path,
        schema_version=1,
        library_root=target,
    )
    return target


# ---------------------------------------------------------------------------
# Canonical Paths (8P.3B)
# ---------------------------------------------------------------------------

def get_canonical_paths(
    data_root: Path,
    library_root: Optional[Path] = None,
    cache_root: Optional[Path] = None,
    log_root: Optional[Path] = None,
    app_install_root: Optional[Path] = None,
) -> CanonicalPaths:
    """Derive all canonical persistent paths from the resolved host storage roots.

    This function defines paths without eagerly creating directories on disk.
    """
    root = data_root.resolve()
    db_dir = root / "database"
    db_path = db_dir / "companion.db"
    db_url = f"sqlite+aiosqlite:///{db_path.as_posix()}"

    library_dir = library_root.resolve() if library_root is not None else resolve_library_root(root)
    model_lib_dir = library_dir / "models" / "llm"
    installed_registry = library_dir / "registry" / "models.json"
    voice_lib_dir = library_dir / "voices"

    attachment_dir = root / "attachments"
    import_inbox = library_dir / "imports" / "inbox"
    import_staging = library_dir / "imports" / "staging"
    character_dir = root / "characters"
    memory_dir = root / "memory"
    backup_dir = root / "backups"

    resolved_install = app_install_root.resolve() if app_install_root is not None else resolve_app_install_root()
    resolved_cache = cache_root.resolve() if cache_root is not None else resolve_cache_root()
    resolved_log = log_root.resolve() if log_root is not None else resolve_log_root()

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
        APP_INSTALL_ROOT=resolved_install,
        CACHE_ROOT=resolved_cache,
        LOG_ROOT=resolved_log,
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
    if canonical_db_path.exists():
        if not canonical_db_path.is_file():
            raise CorruptCanonicalDatabaseError(f"Canonical database path {canonical_db_path} is not a regular file.")
        if canonical_db_path.stat().st_size == 0:
            raise CorruptCanonicalDatabaseError(f"Canonical database at {canonical_db_path} is an invalid zero-byte file.")
        canonical_info = inspect_legacy_candidate(canonical_db_path)
        if not canonical_info.is_valid or not canonical_info.integrity_ok:
            raise CorruptCanonicalDatabaseError(
                f"Canonical database at {canonical_db_path} failed integrity checks: {canonical_info.error}"
            )
        return MigrationDecision(
            action="CANONICAL_EXISTS",
            source=None,
            note="Canonical database already exists in persistent storage and passed integrity checks.",
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

    # Multiple valid candidates found: check if byte-identical without active WAL state
    distinct_hashes = {c.sha256 for c in valid_candidates}
    if len(distinct_hashes) == 1:
        has_active_wal = False
        for c in valid_candidates:
            wal_file = c.path.parent / f"{c.path.name}-wal"
            if wal_file.exists() and wal_file.stat().st_size > 0:
                has_active_wal = True
                break
        if not has_active_wal:
            # Sort deterministically by string path
            chosen = sorted(valid_candidates, key=lambda x: str(x.path))[0]
            return MigrationDecision(
                action="MIGRATE_EQUIVALENT",
                source=chosen.path.resolve(),
                note=(
                    f"Multiple byte-identical legacy candidates detected without WAL state ({[str(c.path) for c in valid_candidates]}). "
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
    """Execute the migration decision with atomic SQLite logical backup, verification, and backup.

    Original legacy source file is NEVER moved or deleted; it remains untouched.
    SQLite's native backup API is used to capture committed WAL state safely.
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

    # Step 1: Logical SQLite backup to temp file (leave source untouched and capture WAL state)
    try:
        ro_src = sqlite3.connect(f"file:{source_path.resolve()}?mode=ro", uri=True)
        dest_conn = sqlite3.connect(temp_target)
        try:
            ro_src.backup(dest_conn)
        finally:
            dest_conn.close()
            ro_src.close()
    except Exception as exc:
        if temp_target.exists():
            temp_target.unlink(missing_ok=True)
        raise StorageError(f"Failed to create SQLite backup snapshot from {source_path} to {temp_target}: {exc}")

    # Step 2: Thorough verification of copied snapshot
    copied_info = inspect_legacy_candidate(temp_target)
    if not copied_info.is_valid or not copied_info.integrity_ok:
        temp_target.unlink(missing_ok=True)
        raise MigrationVerificationError(f"Copied database failed inspection: {copied_info.error}")

    if copied_info.size == 0:
        temp_target.unlink(missing_ok=True)
        raise MigrationVerificationError("Copied database snapshot is an invalid zero-byte file.")

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

    canonical_info = inspect_legacy_candidate(canonical_db_path)
    logger.info(
        f"Successfully migrated legacy database from {source_path} to {canonical_db_path} "
        f"(Logical backup verified, Alembic revision={canonical_info.alembic_version}, Backup={backup_file.name})"
    )

    return MigrationResult(
        migrated=True,
        source=source_path,
        canonical_path=canonical_db_path,
        backup_path=backup_file if backup_file.exists() else None,
        sha256=canonical_info.sha256,
    )


# ---------------------------------------------------------------------------
# Schema Lifecycle & Upgrade (Correction Requirement 2)
# ---------------------------------------------------------------------------

from app.db.backup import create_pre_migration_backup, SQLiteBackupError


def prepare_database_schema(
    canonical_db_path: Path,
    alembic_ini_path: Optional[Path] = None,
    backup_dir: Optional[Path] = None,
) -> str:
    """Ensure canonical database exists and is upgraded to current Alembic head.

    Executes Alembic migrations in an isolated worker thread so that asyncio.run()
    inside migrations/env.py does not collide with an active event loop.
    Application logging remains caller-owned during this programmatic upgrade.
    If the canonical database exists with older data and requires an upgrade,
    a verified WAL-consistent pre-migration backup is taken prior to running upgrade.
    Returns the current Alembic revision string.
    """
    import concurrent.futures
    from alembic.config import Config
    from alembic import command
    from alembic.script import ScriptDirectory

    canonical_db_path.parent.mkdir(parents=True, exist_ok=True)
    db_url = f"sqlite+aiosqlite:///{canonical_db_path.resolve().as_posix()}"

    ini_path = alembic_ini_path
    if ini_path is None:
        ini_path = Path(__file__).resolve().parent.parent.parent / "alembic.ini"

    if not ini_path.exists():
        raise StorageError(f"Alembic configuration file not found at {ini_path}")

    cfg = Config(str(ini_path))
    cfg.attributes["application_owns_logging"] = True
    migrations_dir = ini_path.parent / "migrations"
    cfg.set_main_option("script_location", str(migrations_dir.resolve()))
    cfg.set_main_option("sqlalchemy.url", db_url)

    # Check if database exists and requires an upgrade
    script = ScriptDirectory.from_config(cfg)
    head_rev = script.get_current_head()

    if canonical_db_path.exists():
        # Fail closed: never back up, upgrade or otherwise mutate an existing invalid database.
        if canonical_db_path.stat().st_size == 0:
            raise StorageError(
                f"Refusing to upgrade existing database at {canonical_db_path}: file is an invalid zero-byte database."
            )
        inspection = inspect_legacy_candidate(canonical_db_path)
        if not inspection.is_valid or not inspection.integrity_ok:
            raise StorageError(
                f"Refusing to upgrade existing database at {canonical_db_path}: failed validation ({inspection.error})."
            )
        if inspection.alembic_version != head_rev:
            target_backup_dir = backup_dir or (canonical_db_path.parent.parent / "backups")
            logger.info(
                f"Existing database at {canonical_db_path} (rev={inspection.alembic_version}) requires upgrade to head ({head_rev}). "
                f"Taking pre-migration backup to {target_backup_dir}..."
            )
            try:
                create_pre_migration_backup(canonical_db_path, backup_dir=target_backup_dir)
            except SQLiteBackupError as exc:
                raise StorageError(f"Pre-migration backup failed for {canonical_db_path}: {exc}") from exc

    def _run_upgrade():
        command.upgrade(cfg, "head")

    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
        future = executor.submit(_run_upgrade)
        try:
            future.result()
        except Exception as exc:
            raise StorageError(f"Failed to apply Alembic migrations to {canonical_db_path}: {exc}") from exc

    inspection = inspect_legacy_candidate(canonical_db_path)
    if not inspection.is_valid or not inspection.integrity_ok:
        raise StorageError(
            f"Canonical database at {canonical_db_path} failed integrity checks after migration: {inspection.error}"
        )
    if not inspection.alembic_version:
        raise StorageError(f"Canonical database at {canonical_db_path} missing alembic_version after upgrade.")

    logger.info(f"Canonical database at {canonical_db_path} successfully upgraded to Alembic head: {inspection.alembic_version}")
    return inspection.alembic_version
