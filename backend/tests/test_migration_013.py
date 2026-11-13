"""Migration and trigger-preservation tests for Milestone M3 Batch E (Migration 013)."""

import sqlite3
import uuid
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parent.parent
REVISION = "013_memory_knowledge_and_triggers"
PREVIOUS = "012_character_mood_and_emotion"


def config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


@pytest.fixture
def fresh_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "fresh_013.db"
    command.upgrade(config(db_path), REVISION)
    return db_path


def test_upgrade_adds_trigger_keywords_and_recall_count_columns(fresh_db: Path):
    """Verify trigger_keywords and recall_count columns exist with proper defaults and constraints."""
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

        columns = {r[1]: r for r in conn.execute("PRAGMA table_info(memories)").fetchall()}
        assert "trigger_keywords" in columns
        assert "recall_count" in columns
        assert columns["trigger_keywords"][3] == 0  # nullable
        assert columns["recall_count"][3] == 1  # NOT NULL
        assert str(columns["recall_count"][4]) in ("0", "'0'")

        default_profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        now = "2026-11-13 10:00:00"
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, category, content, valid_from, recall_count)
                VALUES (?, ?, ?, 'local_user', ?, 'profile', 'fact', 'Invalid negative recall count', ?, -1)
                """,
                (str(uuid.uuid4()), now, now, default_profile_id, now),
            )


def test_upgrade_from_012_preserves_fts5_triggers_and_existing_rows(tmp_path: Path):
    """Verify upgrading from 012 preserves memories, FTS5 triggers, and integrity check."""
    db_path = tmp_path / "upgrade_012_to_013.db"
    cfg = config(db_path)
    command.upgrade(cfg, PREVIOUS)

    memory_id = str(uuid.uuid4())
    now = "2026-11-13 10:00:00"
    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        default_profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        conn.execute(
            """
            INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, category, content, importance, source_type, user_verified, valid_from)
            VALUES (?, ?, ?, 'local_user', ?, 'profile', 'fact', 'User enjoys classic cyberpunk manga', 1.0, 'manual', 1, ?)
            """,
            (memory_id, now, now, default_profile_id, now),
        )
        conn.commit()

    command.upgrade(cfg, REVISION)

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        row = conn.execute(
            "SELECT trigger_keywords, recall_count FROM memories WHERE id = ?",
            (memory_id,),
        ).fetchone()
        assert row == (None, 0)

        # FTS5 triggers and existing entries remain functional
        conn.execute("INSERT INTO memories_fts(memories_fts) VALUES('integrity-check')")
        fts_hits = conn.execute(
            "SELECT id FROM memories_fts WHERE memories_fts MATCH 'cyberpunk'"
        ).fetchall()
        assert [hit[0] for hit in fts_hits] == [memory_id]

        # Insert new row after upgrade and verify trigger populates FTS5
        new_id = str(uuid.uuid4())
        conn.execute(
            """
            INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, category, content, valid_from, trigger_keywords, recall_count)
            VALUES (?, ?, ?, 'local_user', ?, 'profile', 'fact', 'Project-X lore notes', ?, '["project-x", "tokyo"]', 3)
            """,
            (new_id, now, now, default_profile_id, now),
        )
        conn.commit()
        fts_new = conn.execute(
            "SELECT id FROM memories_fts WHERE memories_fts MATCH 'lore'"
        ).fetchall()
        assert [hit[0] for hit in fts_new] == [new_id]


def test_downgrade_fails_closed_if_new_column_data_exists(tmp_path: Path):
    """Verify downgrade refuses rollback when non-null trigger_keywords or positive recall_count exist."""
    db_path = tmp_path / "downgrade_guard.db"
    cfg = config(db_path)
    command.upgrade(cfg, REVISION)

    now = "2026-11-13 10:00:00"
    kw_id = str(uuid.uuid4())
    with sqlite3.connect(db_path) as conn:
        default_profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        conn.execute(
            """
            INSERT INTO memories(id, created_at, updated_at, owner_id, profile_id, scope, category, content, valid_from, trigger_keywords, recall_count)
            VALUES (?, ?, ?, 'local_user', ?, 'profile', 'fact', 'Lore entry', ?, '["lore"]', 0)
            """,
            (kw_id, now, now, default_profile_id, now),
        )
        conn.commit()

    with pytest.raises(RuntimeError, match="trigger_keywords"):
        command.downgrade(cfg, PREVIOUS)

    with sqlite3.connect(db_path) as conn:
        conn.execute("UPDATE memories SET trigger_keywords = NULL, recall_count = 2 WHERE id = ?", (kw_id,))
        conn.commit()

    with pytest.raises(RuntimeError, match="recall_count"):
        command.downgrade(cfg, PREVIOUS)

    # Clearing both allows clean downgrade back to 012
    with sqlite3.connect(db_path) as conn:
        conn.execute("UPDATE memories SET trigger_keywords = NULL, recall_count = 0 WHERE id = ?", (kw_id,))
        conn.commit()

    command.downgrade(cfg, PREVIOUS)
    with sqlite3.connect(db_path) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == PREVIOUS
        cols = {r[1] for r in conn.execute("PRAGMA table_info(memories)").fetchall()}
        assert "trigger_keywords" not in cols
        assert "recall_count" not in cols
        conn.execute("INSERT INTO memories_fts(memories_fts) VALUES('integrity-check')")
