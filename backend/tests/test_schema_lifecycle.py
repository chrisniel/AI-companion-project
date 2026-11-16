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

HEAD_REVISION = "017_d9_tool_policy_and_audit"


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
    assert head_rev == HEAD_REVISION

    # Verify tables exist
    conn = sqlite3.connect(canonical_db)
    tables = [r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
    conn.close()

    assert "profiles" in tables
    assert "character_templates" in tables
    assert "character_instances" in tables
    assert "conversations" in tables
    assert "conversation_summaries" in tables
    assert "messages" in tables
    assert "tasks" in tables
    assert "reminders" in tables
    assert "alarms" in tables
    assert "routines" in tables
    assert "notification_events" in tables
    assert "memories" in tables
    assert "attachments" in tables
    assert "alembic_version" in tables

    conn = sqlite3.connect(canonical_db)
    profile_cols = {r[1] for r in conn.execute("PRAGMA table_info(profiles);").fetchall()}
    triggers = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='trigger';").fetchall()}
    partial_idx = conn.execute(
        "SELECT sql FROM sqlite_master WHERE type='index' AND name='uq_profiles_single_default';"
    ).fetchone()
    conn.close()

    assert {"quiet_hours_enabled", "quiet_hours_start", "quiet_hours_end", "quiet_hours_timezone"} <= profile_cols
    assert "trg_profiles_active_character_owner_insert" in triggers
    assert "trg_profiles_active_character_owner_update" in triggers
    assert "trg_character_instances_deactivate_clear_profile" in triggers
    assert partial_idx is not None and "is_default = 1" in partial_idx[0]


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
    assert head_rev == HEAD_REVISION

    # Canonical copy has revision 009
    conn_canon = sqlite3.connect(canonical_db)
    canon_rev = conn_canon.execute("SELECT version_num FROM alembic_version;").fetchone()[0]
    conn_canon.close()
    assert canon_rev == HEAD_REVISION

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
    assert head_rev == HEAD_REVISION

    conn = sqlite3.connect(canonical_db)
    rev = conn.execute("SELECT version_num FROM alembic_version;").fetchone()[0]
    conn.close()
    assert rev == HEAD_REVISION


def test_migration_015_downgrade_fails_closed_when_data_exists(tmp_path):
    """Migration 015 downgrade must refuse if scheduling data or custom quiet hours would be lost."""
    from alembic import command
    from alembic.config import Config

    canonical_db = tmp_path / "canonical" / "database" / "companion.db"
    head_rev = prepare_database_schema(canonical_db)
    assert head_rev == HEAD_REVISION

    conn = sqlite3.connect(canonical_db)
    profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1;").fetchone()[0]
    conn.execute(
        "INSERT INTO reminders (id, created_at, updated_at, owner_id, profile_id, is_deleted, title, scheduled_at, timezone, status, bypass_quiet_hours, origin) "
        "VALUES ('rem-1', '2026-11-14', '2026-11-14', 'local_user', ?, 0, 'Test', '2026-11-15T10:00:00Z', 'UTC', 'scheduled', 0, 'host')",
        (profile_id,),
    )
    conn.commit()
    conn.close()

    ini_path = Path(__file__).resolve().parent.parent / "alembic.ini"
    cfg = Config(str(ini_path))
    cfg.set_main_option("script_location", str((ini_path.parent / "migrations").resolve()))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{canonical_db.resolve().as_posix()}")

    with pytest.raises(RuntimeError, match="Migration 015 downgrade refused"):
        command.downgrade(cfg, "014_conversation_summaries_and_compaction")

    # Removing the reminder but keeping custom quiet hours must still refuse downgrade
    conn = sqlite3.connect(canonical_db)
    conn.execute("DELETE FROM reminders;")
    conn.execute("UPDATE profiles SET quiet_hours_enabled = 1 WHERE id = ?;", (profile_id,))
    conn.commit()
    conn.close()

    with pytest.raises(RuntimeError, match="quiet hours"):
        command.downgrade(cfg, "014_conversation_summaries_and_compaction")

    # Reverting quiet hours to defaults allows clean downgrade while preserving triggers & partial index
    conn = sqlite3.connect(canonical_db)
    conn.execute("UPDATE profiles SET quiet_hours_enabled = 0 WHERE id = ?;", (profile_id,))
    conn.commit()
    conn.close()

    command.downgrade(cfg, "014_conversation_summaries_and_compaction")
    conn = sqlite3.connect(canonical_db)
    rev = conn.execute("SELECT version_num FROM alembic_version;").fetchone()[0]
    triggers = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='trigger';").fetchall()}
    conn.close()
    assert rev == "014_conversation_summaries_and_compaction"
    assert "trg_profiles_active_character_owner_insert" in triggers
    assert "trg_profiles_active_character_owner_update" in triggers
    assert "trg_character_instances_deactivate_clear_profile" in triggers
