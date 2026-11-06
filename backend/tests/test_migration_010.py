"""Migration, SQLite check constraints, and FTS5 trigger cycling tests for M3 Batch C1."""

import sqlite3
import uuid
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parent.parent
REVISION = "010_memory_scoping_and_lifecycle"
PREVIOUS = "009_character_foundation"


def config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


@pytest.fixture
def fresh_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "fresh_010.db"
    command.upgrade(config(db_path), REVISION)
    return db_path


def test_upgrade_adds_scoping_and_lifecycle_columns(fresh_db: Path):
    """Verify columns and indexes added to memories table."""
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

        columns = {r[1]: r for r in conn.execute("PRAGMA table_info(memories)").fetchall()}
        assert "scope" in columns
        assert "character_instance_id" in columns
        assert "valid_from" in columns
        assert "expires_at" in columns
        assert "last_verified_at" in columns
        assert "is_core" in columns

        # Check default values
        assert columns["scope"][4] in ("'profile'", "profile")
        assert columns["is_core"][4] in ("0", 0)

        # Check indexes exist
        indexes = {r[1] for r in conn.execute("PRAGMA index_list(memories)").fetchall()}
        assert "ix_memories_profile_scope" in indexes
        assert "ix_memories_character_instance_id" in indexes
        assert "ix_memories_expires_at" in indexes
        assert "ix_memories_is_core" in indexes


def test_migration_backfills_valid_from_and_preserves_fts(tmp_path: Path):
    """Verify upgrading an existing 009 database backfills valid_from from created_at and keeps FTS functional."""
    db_path = tmp_path / "upgrade_009_to_010.db"
    cfg = config(db_path)

    # 1. Upgrade to 009
    command.upgrade(cfg, PREVIOUS)

    # Insert a memory under 009 schema using the default profile created by 007
    memory_id = str(uuid.uuid4())
    created_time = "2026-05-01 10:00:00"

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        default_profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]

        # Insert memory
        conn.execute(
            """
            INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, category, content, importance, source_type, user_verified)
            VALUES (?, ?, ?, 'local_user', ?, 'fact', 'User loves black coffee', 1.0, 'manual', 1)
            """,
            (memory_id, created_time, created_time, default_profile_id),
        )
        conn.commit()

        # FTS query should work in 009
        fts_res = conn.execute("SELECT id FROM memories_fts WHERE memories_fts MATCH 'coffee'").fetchall()
        assert len(fts_res) == 1

    # 2. Upgrade to 010
    command.upgrade(cfg, REVISION)

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        row = conn.execute(
            "SELECT scope, valid_from, expires_at, is_core FROM memories WHERE id = ?",
            (memory_id,),
        ).fetchone()
        assert row is not None
        assert row[0] == "profile"
        assert row[1] == created_time  # Backfilled from created_at
        assert row[2] is None  # Permanent
        assert row[3] == 0  # Not core by default

        # FTS integrity check and match
        conn.execute("INSERT INTO memories_fts(memories_fts) VALUES('integrity-check')")
        fts_res = conn.execute("SELECT id FROM memories_fts WHERE memories_fts MATCH 'coffee'").fetchall()
        assert len(fts_res) == 1
        assert fts_res[0][0] == memory_id


def test_sqlite_check_constraints_enforced(fresh_db: Path):
    """Verify check constraints for scope, character_instance_id matching, and expiry."""
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        default_profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        char_inst_id = str(uuid.uuid4())
        now = "2026-05-01 12:00:00"

        # Setup character instance for default profile using seeded warm-companion template
        conn.execute(
            """
            INSERT INTO character_instances(
                id, profile_id, template_id, source_template_version, name, preset_id,
                warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity, status, is_legacy_placeholder
            ) VALUES (
                ?, ?, 'warm-companion', 1, 'My Companion', 'warm_companion',
                85, 35, 20, 70, 75, 80, 20, 60, 'active', 0
            )
            """,
            (char_inst_id, default_profile_id),
        )
        conn.commit()

        # Valid profile memory
        conn.execute(
            """
            INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, character_instance_id, category, content, valid_from)
            VALUES (?, ?, ?, 'local_user', ?, 'profile', NULL, 'fact', 'Valid profile memory', ?)
            """,
            (str(uuid.uuid4()), now, now, default_profile_id, now),
        )

        # Valid character memory
        conn.execute(
            """
            INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, character_instance_id, category, content, valid_from)
            VALUES (?, ?, ?, 'local_user', ?, 'character', ?, 'context', 'Valid character memory', ?)
            """,
            (str(uuid.uuid4()), now, now, default_profile_id, char_inst_id, now),
        )

        # Invalid scope value
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, character_instance_id, category, content, valid_from)
                VALUES (?, ?, ?, 'local_user', ?, 'invalid_scope', NULL, 'fact', 'Bad scope', ?)
                """,
                (str(uuid.uuid4()), now, now, default_profile_id, now),
            )

        # Invalid: profile scope with non-null character_instance_id
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, character_instance_id, category, content, valid_from)
                VALUES (?, ?, ?, 'local_user', ?, 'profile', ?, 'fact', 'Bad profile scope', ?)
                """,
                (str(uuid.uuid4()), now, now, default_profile_id, char_inst_id, now),
            )

        # Invalid: character scope with null character_instance_id
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, character_instance_id, category, content, valid_from)
                VALUES (?, ?, ?, 'local_user', ?, 'character', NULL, 'fact', 'Bad character scope', ?)
                """,
                (str(uuid.uuid4()), now, now, default_profile_id, now),
            )

        # Invalid: expires_at earlier than valid_from
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, character_instance_id, category, content, valid_from, expires_at)
                VALUES (?, ?, ?, 'local_user', ?, 'profile', NULL, 'fact', 'Expired before valid', '2026-05-02 00:00:00', '2026-05-01 00:00:00')
                """,
                (str(uuid.uuid4()), now, now, default_profile_id),
            )


def test_downgrade_and_reupgrade(tmp_path: Path):
    """Verify clean downgrade back to 009 and re-upgrade to 010."""
    db_path = tmp_path / "downgrade_010.db"
    cfg = config(db_path)

    command.upgrade(cfg, REVISION)
    with sqlite3.connect(db_path) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

    command.downgrade(cfg, PREVIOUS)
    with sqlite3.connect(db_path) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == PREVIOUS
        cols = {r[1] for r in conn.execute("PRAGMA table_info(memories)").fetchall()}
        assert "scope" not in cols

    command.upgrade(cfg, REVISION)
    with sqlite3.connect(db_path) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION
