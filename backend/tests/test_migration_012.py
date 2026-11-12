"""Migration tests for 012_character_mood_and_emotion (PC-CHAR-003)."""

from pathlib import Path
import sqlite3
import uuid

import pytest
from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parent.parent
REVISION = "012_character_mood_and_emotion"
PREVIOUS = "011_profile_memory_extraction_toggle"


def config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


@pytest.fixture
def fresh_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "fresh_012.db"
    command.upgrade(config(db_path), REVISION)
    return db_path


def test_upgrade_adds_mood_columns_and_preserves_triggers(fresh_db: Path):
    """Verify current_mood, mood_intensity, and mood_updated_at are added and triggers survive."""
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

        columns = {r[1]: r for r in conn.execute("PRAGMA table_info(character_instances)").fetchall()}
        assert "current_mood" in columns
        assert "mood_intensity" in columns
        assert "mood_updated_at" in columns

        triggers = {
            r[0]
            for r in conn.execute("SELECT name FROM sqlite_master WHERE type = 'trigger'").fetchall()
        }
        expected_triggers = {
            "trg_character_templates_protect_neutral_update",
            "trg_character_templates_protect_neutral_delete",
            "trg_character_instances_immutable_provenance",
            "trg_character_instances_deactivate_clear_profile",
            "trg_profiles_active_character_owner_insert",
            "trg_profiles_active_character_owner_update",
            "trg_conversations_character_owner_insert",
            "trg_conversations_character_immutable_update",
        }
        assert expected_triggers.issubset(triggers)

        indexes = {
            r[0]
            for r in conn.execute(
                "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'character_instances'"
            ).fetchall()
        }
        assert "uq_character_instances_profile_legacy_id" in indexes
        assert conn.execute("PRAGMA foreign_key_check").fetchall() == []


def test_upgrade_backfills_existing_instances_and_enforces_constraints(tmp_path: Path):
    """Verify upgrading a 011 DB backfills standard instances to calm/50 and keeps legacy NULL."""
    db_path = tmp_path / "upgrade_011_to_012.db"
    cfg = config(db_path)
    command.upgrade(cfg, PREVIOUS)

    profile_id = str(uuid.uuid4())
    std_id = f"inst-{uuid.uuid4().hex[:12]}"
    leg_id = f"legacy-{uuid.uuid4().hex[:12]}"

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.execute(
            "INSERT INTO profiles (id, name, is_default, status, is_deleted) VALUES (?, 'Mood Test Profile', 0, 'active', 0)",
            (profile_id,),
        )
        conn.execute(
            """
            INSERT INTO character_instances (
                id, profile_id, is_legacy_placeholder, legacy_character_id,
                template_id, source_template_version, name, summary, lore, system_prompt,
                avatar_asset, preset_id,
                warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                status, is_deleted
            ) VALUES (
                ?, ?, 0, NULL,
                'warm-companion', 1, 'Aria', 'Warm friend', '', 'Be kind',
                'warm_companion_avatar', 'warm_companion',
                85, 35, 15, 60, 75, 80, 25, 60,
                'active', 0
            )
            """,
            (std_id, profile_id),
        )
        conn.execute(
            """
            INSERT INTO character_instances (
                id, profile_id, is_legacy_placeholder, legacy_character_id,
                template_id, source_template_version, name, summary, lore, system_prompt,
                avatar_asset, preset_id,
                warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                status, is_deleted
            ) VALUES (
                ?, ?, 1, 'old-bot',
                NULL, NULL, 'old-bot', 'Legacy placeholder', '', '',
                'default_avatar', NULL,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                'archived', 0
            )
            """,
            (leg_id, profile_id),
        )
        conn.commit()

    command.upgrade(cfg, REVISION)

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        std_row = conn.execute(
            "SELECT current_mood, mood_intensity, mood_updated_at FROM character_instances WHERE id = ?",
            (std_id,),
        ).fetchone()
        assert std_row is not None
        assert std_row[0] == "calm"
        assert std_row[1] == 50
        assert std_row[2] is not None

        leg_row = conn.execute(
            "SELECT current_mood, mood_intensity, mood_updated_at FROM character_instances WHERE id = ?",
            (leg_id,),
        ).fetchone()
        assert leg_row == (None, None, None)

        # Verify CHECK constraint rejects invalid mood or out-of-bounds intensity on standard instance
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                "UPDATE character_instances SET current_mood = 'invalid_mood' WHERE id = ?",
                (std_id,),
            )
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                "UPDATE character_instances SET mood_intensity = 120 WHERE id = ?",
                (std_id,),
            )
        # Verify CHECK constraint rejects non-null mood on legacy placeholder
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                "UPDATE character_instances SET current_mood = 'calm', mood_intensity = 50 WHERE id = ?",
                (leg_id,),
            )


def test_downgrade_removes_mood_columns_and_restores_triggers(fresh_db: Path):
    """Verify downgrade to 011 cleanly drops mood columns while preserving triggers and constraints."""
    cfg = config(fresh_db)
    command.downgrade(cfg, PREVIOUS)

    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == PREVIOUS
        columns = {r[1]: r for r in conn.execute("PRAGMA table_info(character_instances)").fetchall()}
        assert "current_mood" not in columns
        assert "mood_intensity" not in columns
        assert "mood_updated_at" not in columns

        triggers = {
            r[0]
            for r in conn.execute("SELECT name FROM sqlite_master WHERE type = 'trigger'").fetchall()
        }
        assert "trg_character_instances_immutable_provenance" in triggers
        assert "trg_character_instances_deactivate_clear_profile" in triggers
        assert conn.execute("PRAGMA foreign_key_check").fetchall() == []
