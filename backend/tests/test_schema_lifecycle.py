"""Tests for schema preparation and Alembic upgrade lifecycle (Correction Requirement 2)."""

import sqlite3
from pathlib import Path
import pytest

from app.core.storage import (
    assess_migration_preflight,
    execute_migration,
    prepare_database_schema,
)
from app.db.session import (
    initialize_database_runtime,
    dispose_database_runtime,
    get_engine,
)


def _create_legacy_v004_db(path: Path) -> None:
    """Helper to create an authentic SQLite DB at Alembic revision 004."""
    import concurrent.futures
    path.parent.mkdir(parents=True, exist_ok=True)
    db_url = f"sqlite+aiosqlite:///{path.resolve().as_posix()}"
    ini_path = Path(__file__).resolve().parent.parent / "alembic.ini"

    def _run_upgrade():
        from alembic.config import Config
        from alembic import command
        cfg = Config(str(ini_path))
        cfg.set_main_option("script_location", str((ini_path.parent / "migrations").resolve()))
        cfg.set_main_option("sqlalchemy.url", db_url)
        command.upgrade(cfg, "004_add_soft_delete_columns")

    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
        executor.submit(_run_upgrade).result()


def test_fresh_install_runs_alembic_upgrade_to_head(tmp_path):
    """Fresh install creates canonical database and brings it to current Alembic head."""
    canonical_dir = tmp_path / "canonical" / "database"
    canonical_db = canonical_dir / "companion.db"
    backup_dir = tmp_path / "canonical" / "backups"

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[],
    )
    assert decision.action == "FRESH_INSTALL"

    # Execute migration (no-op for fresh install)
    execute_migration(decision, canonical_db, backup_dir)

    # Prepare schema upgrades to head
    head_rev = prepare_database_schema(canonical_db)
    assert head_rev == "006_add_attachments"

    # Verify tables exist
    conn = sqlite3.connect(canonical_db)
    tables = [r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
    conn.close()

    assert "conversations" in tables
    assert "messages" in tables
    assert "tasks" in tables
    assert "memories" in tables
    assert "attachments" in tables
    assert "alembic_version" in tables


def test_migrated_older_db_upgraded_on_canonical_copy_while_source_remains_at_old_revision(tmp_path):
    """Migration of an older database upgrades canonical copy to head while preserving source at older rev."""
    legacy_dir = tmp_path / "legacy"
    legacy_db = legacy_dir / "companion.db"
    _create_legacy_v004_db(legacy_db)

    canonical_dir = tmp_path / "canonical" / "database"
    canonical_db = canonical_dir / "companion.db"
    backup_dir = tmp_path / "canonical" / "backups"

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[legacy_db],
    )
    assert decision.action == "MIGRATE"

    # Migrate snapshot
    execute_migration(decision, canonical_db, backup_dir)

    # Run schema preparation on canonical copy
    head_rev = prepare_database_schema(canonical_db)
    assert head_rev == "006_add_attachments"

    # Canonical copy has revision 006
    conn_canon = sqlite3.connect(canonical_db)
    canon_rev = conn_canon.execute("SELECT version_num FROM alembic_version;").fetchone()[0]
    conn_canon.close()
    assert canon_rev == "006_add_attachments"

    # Legacy source MUST remain at 004
    conn_source = sqlite3.connect(legacy_db)
    source_rev = conn_source.execute("SELECT version_num FROM alembic_version;").fetchone()[0]
    conn_source.close()
    assert source_rev == "004_add_soft_delete_columns", "Legacy source revision must remain completely untouched!"


def test_existing_canonical_db_safely_upgraded_if_behind(tmp_path):
    """Existing canonical database behind head is safely upgraded."""
    canonical_dir = tmp_path / "canonical" / "database"
    canonical_db = canonical_dir / "companion.db"
    _create_legacy_v004_db(canonical_db)

    decision = assess_migration_preflight(
        canonical_db_path=canonical_db,
        legacy_candidates=[],
    )
    assert decision.action == "CANONICAL_EXISTS"

    head_rev = prepare_database_schema(canonical_db)
    assert head_rev == "006_add_attachments"

    conn = sqlite3.connect(canonical_db)
    rev = conn.execute("SELECT version_num FROM alembic_version;").fetchone()[0]
    conn.close()
    assert rev == "006_add_attachments"
