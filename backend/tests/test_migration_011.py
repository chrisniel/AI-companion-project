"""Migration tests for 011_profile_memory_extraction_toggle."""

from pathlib import Path
import sqlite3
import uuid

import pytest
from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parent.parent
REVISION = "011_profile_memory_extraction_toggle"
PREVIOUS = "010_memory_scoping_and_lifecycle"


def config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


@pytest.fixture
def fresh_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "fresh_011.db"
    command.upgrade(config(db_path), REVISION)
    return db_path


def test_upgrade_adds_memory_extraction_enabled_column(fresh_db: Path):
    """Verify memory_extraction_enabled is added to profiles table."""
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

        columns = {r[1]: r for r in conn.execute("PRAGMA table_info(profiles)").fetchall()}
        assert "memory_extraction_enabled" in columns
        col = columns["memory_extraction_enabled"]
        # (cid, name, type, notnull, dflt_value, pk)
        assert col[3] == 1  # notnull = True
        assert col[4] in ("1", 1, "true", "True")


def test_downgrade_removes_memory_extraction_enabled_column(fresh_db: Path):
    """Verify downgrade back to 010 safely removes the column."""
    cfg = config(fresh_db)
    command.downgrade(cfg, PREVIOUS)

    with sqlite3.connect(fresh_db) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == PREVIOUS
        columns = {r[1]: r for r in conn.execute("PRAGMA table_info(profiles)").fetchall()}
        assert "memory_extraction_enabled" not in columns


def test_upgrade_existing_profiles_preserves_data_with_default_true(tmp_path: Path):
    """Verify upgrading a 010 database preserves profiles and defaults memory_extraction_enabled to 1."""
    db_path = tmp_path / "upgrade_010_to_011.db"
    cfg = config(db_path)

    # 1. Upgrade to 010
    command.upgrade(cfg, PREVIOUS)

    profile_id = str(uuid.uuid4())
    with sqlite3.connect(db_path) as conn:
        conn.execute(
            """
            INSERT INTO profiles (id, name, is_default, status, is_deleted)
            VALUES (?, 'Custom Test Profile', 0, 'active', 0)
            """,
            (profile_id,),
        )
        conn.commit()

    # 2. Upgrade to 011
    command.upgrade(cfg, REVISION)

    with sqlite3.connect(db_path) as conn:
        row = conn.execute(
            "SELECT name, memory_extraction_enabled FROM profiles WHERE id = ?",
            (profile_id,),
        ).fetchone()
        assert row is not None
        assert row[0] == "Custom Test Profile"
        assert row[1] == 1
