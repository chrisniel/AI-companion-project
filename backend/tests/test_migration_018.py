"""Migration, trigger preservation, and Profile purge tests for 018_voice_settings_and_character_voice."""

from datetime import datetime, timedelta, timezone
from pathlib import Path
import sqlite3
import uuid

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.profile_sessions import token_hash
from app.core.storage import prepare_database_schema
from app.models.character_instance import CharacterInstance
from app.models.character_template import CharacterTemplate
from app.models.profile import Profile
from app.models.profile_session import ProfileSession
from app.models.profile_voice_settings import ProfileVoiceSettings
from app.services.profile_purge_service import ProfilePurgeService

BACKEND_DIR = Path(__file__).resolve().parent.parent
REVISION = "018_voice_settings_and_character_voice"
PREVIOUS = "017_d9_tool_policy_and_audit"

EXPECTED_CHAR_TRIGGERS = {
    "trg_character_instances_immutable_provenance",
    "trg_character_instances_deactivate_clear_profile",
    "trg_profiles_active_character_owner_insert",
    "trg_profiles_active_character_owner_update",
    "trg_conversations_character_owner_insert",
}


def config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


@pytest.fixture
def fresh_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "fresh_018.db"
    command.upgrade(config(db_path), REVISION)
    return db_path


def test_upgrade_creates_voice_settings_and_character_voice_id(fresh_db: Path):
    """Verify 018 creates profile_voice_settings, character_instances.voice_id, and check constraints."""
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

        tables = {
            row[0]
            for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        }
        assert "profile_voice_settings" in tables

        char_cols = {r[1]: r for r in conn.execute("PRAGMA table_info(character_instances)").fetchall()}
        assert "voice_id" in char_cols
        assert char_cols["voice_id"][3] == 0  # nullable

        # Default profile must be backfilled with safe defaults (proactive/cloud OFF)
        profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        row = conn.execute(
            """
            SELECT barge_in_policy, vad_sensitivity, stt_language, tts_speed,
                   default_voice_id, auto_read_replies, proactive_speech_enabled,
                   cloud_stt_enabled, cloud_tts_enabled
            FROM profile_voice_settings WHERE profile_id = ?
            """,
            (profile_id,),
        ).fetchone()
        assert row is not None
        assert row == ("smart_auto", "medium", "auto", 1.0, "af_nicole", 0, 0, 0, 0)

        # Invalid barge_in_policy / tts_speed rejected by SQLite CHECK
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                "UPDATE profile_voice_settings SET barge_in_policy = 'invalid_mode' WHERE profile_id = ?",
                (profile_id,),
            )
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                "UPDATE profile_voice_settings SET tts_speed = 4.0 WHERE profile_id = ?",
                (profile_id,),
            )

        # Triggers on character_instances remain intact
        triggers = {
            row[0]
            for row in conn.execute("SELECT name FROM sqlite_master WHERE type='trigger'").fetchall()
        }
        assert EXPECTED_CHAR_TRIGGERS.issubset(triggers)


def test_downgrade_removes_voice_schema_and_preserves_character_triggers(fresh_db: Path):
    """Verify downgrade back to 017 drops voice tables/column while keeping all 5 character triggers."""
    command.downgrade(config(fresh_db), PREVIOUS)

    with sqlite3.connect(fresh_db) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == PREVIOUS
        tables = {
            row[0]
            for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        }
        assert "profile_voice_settings" not in tables

        char_cols = {r[1]: r for r in conn.execute("PRAGMA table_info(character_instances)").fetchall()}
        assert "voice_id" not in char_cols

        triggers = {
            row[0]
            for row in conn.execute("SELECT name FROM sqlite_master WHERE type='trigger'").fetchall()
        }
        assert EXPECTED_CHAR_TRIGGERS.issubset(triggers)


def test_upgrade_from_017_backfills_existing_profiles(tmp_path: Path):
    """Verify upgrading an existing 017 DB backfills profile_voice_settings for every profile."""
    db_path = tmp_path / "upgrade_017_to_018.db"
    cfg = config(db_path)
    command.upgrade(cfg, PREVIOUS)

    extra_profile_id = str(uuid.uuid4())
    now_str = datetime.now(timezone.utc).isoformat()
    with sqlite3.connect(db_path) as conn:
        conn.execute(
            """
            INSERT INTO profiles (id, name, is_default, status, is_deleted, created_at, updated_at)
            VALUES (?, 'Secondary', 0, 'active', 0, ?, ?)
            """,
            (extra_profile_id, now_str, now_str),
        )
        conn.commit()

    command.upgrade(cfg, REVISION)

    with sqlite3.connect(db_path) as conn:
        profile_count = conn.execute("SELECT COUNT(*) FROM profiles").fetchone()[0]
        voice_count = conn.execute("SELECT COUNT(*) FROM profile_voice_settings").fetchone()[0]
        assert profile_count >= 2
        assert voice_count == profile_count


async def test_profile_purge_removes_profile_voice_settings(tmp_path: Path):
    """Verify ProfilePurgeService.purge_profile removes profile_voice_settings with FK enforcement."""
    db_path = tmp_path / "purge_voice.db"
    prepare_database_schema(db_path)

    engine = create_async_engine(f"sqlite+aiosqlite:///{db_path.as_posix()}")
    factory = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

    secondary_id = str(uuid.uuid4())
    char_id = str(uuid.uuid4())
    sess_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    async with factory() as session:
        await session.execute(__import__("sqlalchemy").text("PRAGMA foreign_keys = ON"))
        template_id = await session.scalar(
            select(CharacterTemplate.id).where(CharacterTemplate.is_neutral_fallback.is_(False)).limit(1)
        )
        assert template_id is not None
        session.add(Profile(id=secondary_id, name="Temp", is_default=False, status="active"))
        await session.flush()
        session.add(
            ProfileSession(
                id=sess_id,
                profile_id=secondary_id,
                token_hash=token_hash("psk_voice_purge_test"),
                client_type="desktop",
                created_at=now,
                last_active_at=now,
                expires_at=now + timedelta(hours=12),
            )
        )
        session.add(ProfileVoiceSettings(profile_id=secondary_id, default_voice_id="af_nicole"))
        session.add(
            CharacterInstance(
                id=char_id,
                profile_id=secondary_id,
                is_legacy_placeholder=False,
                template_id=template_id,
                source_template_version=1,
                name="Aria",
                summary="Test",
                lore="",
                system_prompt="Be concise.",
                avatar_asset="default_avatar",
                preset_id="warm_companion",
                warmth=80,
                teasing=30,
                guardedness=20,
                directness=60,
                expressiveness=70,
                affection=75,
                formality=30,
                verbosity=50,
                voice_id="af_nicole",
            )
        )
        await session.commit()

        purge_svc = ProfilePurgeService(session)
        await purge_svc.soft_delete_profile(secondary_id)
        purged = await purge_svc.purge_profile(secondary_id, allow_unexpired=True)
        assert purged is True

        remaining_vs = await session.get(ProfileVoiceSettings, secondary_id)
        assert remaining_vs is None

    await engine.dispose()
