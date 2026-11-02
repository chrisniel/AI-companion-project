"""Synthetic migration, SQLite constraints, and relational lifecycle tests for M3 Batch A."""

import sqlite3
import uuid
import importlib.util
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parent.parent
REVISION = "009_character_foundation"
PREVIOUS = "008_profile_sessions_and_tickets"

# Dynamically import migration module because filename starts with digits
_mig_path = BACKEND_DIR / "migrations" / "versions" / "009_character_foundation.py"
_mig_spec = importlib.util.spec_from_file_location("mig_009", _mig_path)
_mig_mod = importlib.util.module_from_spec(_mig_spec)
_mig_spec.loader.exec_module(_mig_mod)
derive_legacy_instance_id = _mig_mod.derive_legacy_instance_id
DEFAULT_PERSONA = _mig_mod.DEFAULT_PERSONA


def config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


@pytest.fixture
def fresh_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "fresh_009.db"
    command.upgrade(config(db_path), REVISION)
    return db_path


def test_fresh_upgrade_to_009_creates_character_tables_and_seeds_templates(fresh_db: Path):
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

        # 1. Verify character_templates table and seed rows
        tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
        assert "character_templates" in tables
        assert "character_instances" in tables

        # Verify columns on profiles and conversations
        prof_cols = {r[1] for r in conn.execute("PRAGMA table_info(profiles)").fetchall()}
        assert "active_character_instance_id" in prof_cols

        conv_cols = {r[1] for r in conn.execute("PRAGMA table_info(conversations)").fetchall()}
        assert "character_instance_id" in conv_cols
        assert "character_id" in conv_cols

        # 2. Verify seeded templates
        templates = conn.execute("""
            SELECT id, template_version, name, summary, is_neutral_fallback, default_preset_id,
                   warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity
            FROM character_templates ORDER BY id
        """).fetchall()
        assert len(templates) == 4
        tmpl_by_id = {t[0]: t for t in templates}

        # Check Neutral Assistant
        neutral = tmpl_by_id["neutral-assistant"]
        assert neutral[1] == 1  # template_version
        assert neutral[4] == 1  # is_neutral_fallback
        assert neutral[5] is None  # default_preset_id is None
        # All 8 traits are NULL (never hardcoded 50s!)
        assert neutral[6:] == (None, None, None, None, None, None, None, None)

        # Check Warm Companion
        warm = tmpl_by_id["warm-companion"]
        assert warm[1] == 1
        assert warm[4] == 0
        assert warm[5] == "warm_companion"
        assert warm[6:] == (85, 35, 15, 60, 75, 80, 25, 60)

        # Check Playful Companion
        playful = tmpl_by_id["playful-companion"]
        assert playful[4] == 0
        assert playful[5] == "playful"
        assert playful[6:] == (75, 80, 20, 55, 85, 65, 15, 55)

        # Check Formal Advisor
        formal = tmpl_by_id["formal-advisor"]
        assert formal[4] == 0
        assert formal[5] == "formal_advisor"
        assert formal[6:] == (45, 10, 45, 85, 30, 20, 90, 65)

        # 0 foreign key violations
        assert conn.execute("PRAGMA foreign_key_check").fetchall() == []


def test_negative_sqlite_constraints_on_character_templates_and_instances(fresh_db: Path):
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")

        # A. Template Constraints
        # 1. Non-neutral template cannot have NULL default_preset_id
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO character_templates (
                    id, template_version, name, summary, lore, system_prompt, avatar_asset,
                    default_preset_id, is_neutral_fallback,
                    warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity
                ) VALUES (
                    'bad-tmpl-1', 1, 'Bad', '', '', 'Prompt', 'avatar',
                    NULL, 0,
                    50, 50, 50, 50, 50, 50, 50, 50
                )
            """)

        # 2. Non-neutral template cannot have NULL personality dimension
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO character_templates (
                    id, template_version, name, summary, lore, system_prompt, avatar_asset,
                    default_preset_id, is_neutral_fallback,
                    warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity
                ) VALUES (
                    'bad-tmpl-2', 1, 'Bad', '', '', 'Prompt', 'avatar',
                    'custom', 0,
                    50, NULL, 50, 50, 50, 50, 50, 50
                )
            """)

        # 3. Non-neutral template cannot have trait out of bounds (> 100 or < 0)
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO character_templates (
                    id, template_version, name, summary, lore, system_prompt, avatar_asset,
                    default_preset_id, is_neutral_fallback,
                    warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity
                ) VALUES (
                    'bad-tmpl-3', 1, 'Bad', '', '', 'Prompt', 'avatar',
                    'custom', 0,
                    150, 50, 50, 50, 50, 50, 50, 50
                )
            """)

        # 4. Cannot insert a second neutral-assistant template (partial unique index & CHECK)
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO character_templates (
                    id, template_version, name, summary, lore, system_prompt, avatar_asset,
                    default_preset_id, is_neutral_fallback,
                    warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity
                ) VALUES (
                    'neutral-assistant-2', 1, 'Neutral 2', '', '', 'Prompt', 'avatar',
                    NULL, 1,
                    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
                )
            """)

        # 5. Neutral Assistant template is immutable (triggers protect update/delete)
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("UPDATE character_templates SET name = 'Hacked' WHERE id = 'neutral-assistant'")
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("DELETE FROM character_templates WHERE id = 'neutral-assistant'")

        # B. Instance Constraints
        prof_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]

        # 6. Standard instance cannot have NULL template_id
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO character_instances (
                    id, profile_id, is_legacy_placeholder, legacy_character_id, template_id,
                    source_template_version, name, summary, lore, system_prompt, avatar_asset,
                    preset_id, warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity
                ) VALUES (
                    'inst-bad-1', ?, 0, NULL, NULL,
                    1, 'Bad', '', '', 'Prompt', 'avatar',
                    'custom', 50, 50, 50, 50, 50, 50, 50, 50
                )
            """, (prof_id,))

        # 7. Standard instance cannot have NULL trait
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO character_instances (
                    id, profile_id, is_legacy_placeholder, legacy_character_id, template_id,
                    source_template_version, name, summary, lore, system_prompt, avatar_asset,
                    preset_id, warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity
                ) VALUES (
                    'inst-bad-2', ?, 0, NULL, 'warm-companion',
                    1, 'Bad', '', '', 'Prompt', 'avatar',
                    'custom', 50, NULL, 50, 50, 50, 50, 50, 50
                )
            """, (prof_id,))

        # 8. Standard instance cannot instantiate from neutral-assistant
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO character_instances (
                    id, profile_id, is_legacy_placeholder, legacy_character_id, template_id,
                    source_template_version, name, summary, lore, system_prompt, avatar_asset,
                    preset_id, warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity
                ) VALUES (
                    'inst-bad-3', ?, 0, NULL, 'neutral-assistant',
                    1, 'Bad', '', '', 'Prompt', 'avatar',
                    'custom', 50, 50, 50, 50, 50, 50, 50, 50
                )
            """, (prof_id,))

        # 9. Legacy placeholder cannot have non-null template_id or traits
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO character_instances (
                    id, profile_id, is_legacy_placeholder, legacy_character_id, template_id,
                    source_template_version, name, summary, lore, system_prompt, avatar_asset,
                    preset_id, warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                    status
                ) VALUES (
                    'legacy-bad-1', ?, 1, 'legacy-1', 'warm-companion',
                    1, 'Bad Legacy', '', '', '', 'avatar',
                    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                    'archived'
                )
            """, (prof_id,))

        # 10. Cannot mutate instance provenance after insert (trigger)
        conn.execute("""
            INSERT INTO character_instances (
                id, profile_id, is_legacy_placeholder, legacy_character_id, template_id,
                source_template_version, name, summary, lore, system_prompt, avatar_asset,
                preset_id, warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                status
            ) VALUES (
                'inst-good-1', ?, 0, NULL, 'warm-companion',
                1, 'Good', '', '', 'Prompt', 'avatar',
                'warm_companion', 85, 35, 15, 60, 75, 80, 25, 60,
                'active'
            )
        """, (prof_id,))

        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("UPDATE character_instances SET template_id = 'formal-advisor' WHERE id = 'inst-good-1'")
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("UPDATE character_instances SET source_template_version = 2 WHERE id = 'inst-good-1'")


def test_populated_008_upgrade_lossless_legacy_character_ids_shared_long_and_collision_cases(tmp_path: Path):
    db_path = tmp_path / "populated_008.db"
    cfg = config(db_path)

    # 1. Upgrade to 008
    command.upgrade(cfg, PREVIOUS)

    # 2. Populate 008 database with:
    #    - Profiles with identical prefix (tests against prefix truncation collisions)
    #    - Conversations with "default" and "neutral-assistant"
    #    - Conversations sharing legacy character_id across profiles ("companion-1")
    #    - Conversations with maximum-length 64-char legacy ID and delimiter-heavy ID
    prof_a = "00000000-1111-2222-aaaa-000000000001"
    prof_b = "00000000-1111-2222-bbbb-000000000002"
    long_legacy_id = "x" * 64
    delim_legacy_id = "a|1:b"

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        for p, name in [(prof_a, "Profile A"), (prof_b, "Profile B")]:
            conn.execute(
                "INSERT INTO profiles (id, name, is_default, status) VALUES (?, ?, 0, 'active')",
                (p, name),
            )

        # Conversations
        conn.execute("INSERT INTO conversations (id, profile_id, title, character_id, owner_id, created_at, updated_at) VALUES ('conv-def', ?, 'Default Chat', 'default', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", (prof_a,))
        conn.execute("INSERT INTO conversations (id, profile_id, title, character_id, owner_id, created_at, updated_at) VALUES ('conv-neut', ?, 'Neutral Chat', 'neutral-assistant', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", (prof_a,))
        conn.execute("INSERT INTO conversations (id, profile_id, title, character_id, owner_id, created_at, updated_at) VALUES ('conv-a-comp', ?, 'Comp A', 'companion-1', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", (prof_a,))
        conn.execute("INSERT INTO conversations (id, profile_id, title, character_id, owner_id, created_at, updated_at) VALUES ('conv-b-comp', ?, 'Comp B', 'companion-1', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", (prof_b,))
        conn.execute("INSERT INTO conversations (id, profile_id, title, character_id, owner_id, created_at, updated_at) VALUES ('conv-long', ?, 'Long Chat', ?, 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", (prof_a, long_legacy_id))
        conn.execute("INSERT INTO conversations (id, profile_id, title, character_id, owner_id, created_at, updated_at) VALUES ('conv-delim', ?, 'Delim Chat', ?, 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", (prof_a, delim_legacy_id))

        # Memory with FTS index
        conn.execute("INSERT INTO memories (id, profile_id, category, content, owner_id, created_at, updated_at) VALUES ('mem-1', ?, 'note', 'quantum physics notes', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", (prof_a,))
        conn.commit()

    # 3. Upgrade to 009
    command.upgrade(cfg, REVISION)

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

        # Check conversation bindings
        convs = {
            r[0]: (r[1], r[2], r[3])
            for r in conn.execute("SELECT id, profile_id, character_id, character_instance_id FROM conversations").fetchall()
        }

        # Original character_id is preserved verbatim!
        assert convs["conv-def"][1] == "default"
        assert convs["conv-def"][2] is None  # character_instance_id is None for Neutral

        assert convs["conv-neut"][1] == "neutral-assistant"
        assert convs["conv-neut"][2] is None

        assert convs["conv-a-comp"][1] == "companion-1"
        inst_a = convs["conv-a-comp"][2]
        assert inst_a == derive_legacy_instance_id(prof_a, "companion-1")

        assert convs["conv-b-comp"][1] == "companion-1"
        inst_b = convs["conv-b-comp"][2]
        assert inst_b == derive_legacy_instance_id(prof_b, "companion-1")

        # Crucial collision-resistance check: instances for same character_id on different profiles are distinct!
        assert inst_a != inst_b
        assert len(inst_a) <= 64
        assert len(inst_b) <= 64

        assert convs["conv-long"][1] == long_legacy_id
        assert convs["conv-long"][2] == derive_legacy_instance_id(prof_a, long_legacy_id)

        assert convs["conv-delim"][1] == delim_legacy_id
        assert convs["conv-delim"][2] == derive_legacy_instance_id(prof_a, delim_legacy_id)

        # Verify the created legacy placeholders in character_instances
        placeholders = conn.execute("""
            SELECT id, profile_id, is_legacy_placeholder, legacy_character_id,
                   template_id, preset_id, warmth, status
            FROM character_instances WHERE is_legacy_placeholder = 1
        """).fetchall()
        assert len(placeholders) == 4
        for row in placeholders:
            assert row[2] == 1  # is_legacy_placeholder
            assert row[4] is None  # template_id is NULL (no invented template)
            assert row[5] is None  # preset_id is NULL
            assert row[6] is None  # warmth is NULL (no invented Warm Companion)
            assert row[7] == "archived"  # status is archived

        # Verify FTS5 is intact and working
        res = conn.execute("SELECT content FROM memories WHERE rowid IN (SELECT rowid FROM memories_fts WHERE memories_fts MATCH 'quantum')").fetchall()
        assert len(res) == 1
        assert "quantum physics" in res[0][0]

        # 0 foreign key violations
        assert conn.execute("PRAGMA foreign_key_check").fetchall() == []


def test_triggers_enforce_same_profile_ownership_legacy_mapping_and_conversation_immutability(fresh_db: Path):
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")

        prof_a = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        prof_b = str(uuid.uuid4())
        conn.execute("INSERT INTO profiles (id, name, is_default, status) VALUES (?, 'Profile B', 0, 'active')", (prof_b,))

        # Create active instance for Profile A
        conn.execute("""
            INSERT INTO character_instances (
                id, profile_id, is_legacy_placeholder, legacy_character_id, template_id,
                source_template_version, name, summary, lore, system_prompt, avatar_asset,
                preset_id, warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                status, is_deleted
            ) VALUES (
                'inst-a-1', ?, 0, NULL, 'warm-companion',
                1, 'Instance A', '', '', 'Prompt', 'avatar',
                'warm_companion', 85, 35, 15, 60, 75, 80, 25, 60,
                'active', 0
            )
        """, (prof_a,))

        # 1. Profile B cannot set active_character_instance_id to Profile A's instance
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("UPDATE profiles SET active_character_instance_id = 'inst-a-1' WHERE id = ?", (prof_b,))

        # 2. Profile A CAN set active_character_instance_id to own active instance
        conn.execute("UPDATE profiles SET active_character_instance_id = 'inst-a-1' WHERE id = ?", (prof_a,))
        assert conn.execute("SELECT active_character_instance_id FROM profiles WHERE id = ?", (prof_a,)).fetchone()[0] == 'inst-a-1'

        # 3. Archiving/deleting inst-a-1 automatically clears active_character_instance_id on Profile A!
        conn.execute("UPDATE character_instances SET status = 'archived' WHERE id = 'inst-a-1'")
        assert conn.execute("SELECT active_character_instance_id FROM profiles WHERE id = ?", (prof_a,)).fetchone()[0] is None

        # Reactivate inst-a-1
        conn.execute("UPDATE character_instances SET status = 'active' WHERE id = 'inst-a-1'")
        conn.execute("UPDATE profiles SET active_character_instance_id = 'inst-a-1' WHERE id = ?", (prof_a,))

        # Soft-deleting inst-a-1 automatically clears active_character_instance_id on Profile A!
        conn.execute("UPDATE character_instances SET is_deleted = 1 WHERE id = 'inst-a-1'")
        assert conn.execute("SELECT active_character_instance_id FROM profiles WHERE id = ?", (prof_a,)).fetchone()[0] is None

        # Reset is_deleted = 0
        conn.execute("UPDATE character_instances SET is_deleted = 0 WHERE id = 'inst-a-1'")

        # 4. Profile B cannot create a conversation with Profile A's character instance
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO conversations (id, profile_id, title, character_id, character_instance_id, owner_id, created_at, updated_at)
                VALUES ('conv-b-bad', ?, 'Chat', 'inst-a-1', 'inst-a-1', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """, (prof_b,))

        # 5. Profile A cannot insert a conversation where character_id does not match character_instance_id
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("""
                INSERT INTO conversations (id, profile_id, title, character_id, character_instance_id, owner_id, created_at, updated_at)
                VALUES ('conv-a-bad-match', ?, 'Chat', 'mismatched-id', 'inst-a-1', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """, (prof_a,))

        # 6. Profile A CAN insert conversation with matching character_id and character_instance_id
        conn.execute("""
            INSERT INTO conversations (id, profile_id, title, character_id, character_instance_id, owner_id, created_at, updated_at)
            VALUES ('conv-a-good', ?, 'Chat', 'inst-a-1', 'inst-a-1', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        """, (prof_a,))

        # 7. Immutable update: cannot reattribute conversation character identity or profile ownership
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("UPDATE conversations SET character_id = 'other-char' WHERE id = 'conv-a-good'")
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("UPDATE conversations SET character_instance_id = NULL WHERE id = 'conv-a-good'")
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("UPDATE conversations SET profile_id = ? WHERE id = 'conv-a-good'", (prof_b,))


def test_profile_deletion_and_character_foreign_key_lifecycle(fresh_db: Path):
    """Mandatory Acceptance Condition B: SQLite deletion and foreign-key lifecycle verification."""
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")

        prof = str(uuid.uuid4())
        conn.execute("INSERT INTO profiles (id, name, is_default, status) VALUES (?, 'Test Profile', 0, 'active')", (prof,))

        # Create character instance
        conn.execute("""
            INSERT INTO character_instances (
                id, profile_id, is_legacy_placeholder, legacy_character_id, template_id,
                source_template_version, name, summary, lore, system_prompt, avatar_asset,
                preset_id, warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                status
            ) VALUES (
                'inst-lifecycle-1', ?, 0, NULL, 'warm-companion',
                1, 'Lifecycle Char', '', '', 'Prompt', 'avatar',
                'warm_companion', 85, 35, 15, 60, 75, 80, 25, 60,
                'active'
            )
        """, (prof,))

        conn.execute("""
            INSERT INTO conversations (id, profile_id, title, character_id, character_instance_id, owner_id, created_at, updated_at)
            VALUES ('conv-lifecycle-1', ?, 'Lifecycle Chat', 'inst-lifecycle-1', 'inst-lifecycle-1', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        """, (prof,))

        # Requirement 1: Ordinary direct Character deletion is BLOCKED by ON DELETE RESTRICT
        # when conversations reference it (preserving conversation history).
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("DELETE FROM character_instances WHERE id = 'inst-lifecycle-1'")

        # Requirement 2 & 3: Archiving and soft-deleting CharacterInstance succeeds and leaves conversation intact
        conn.execute("UPDATE character_instances SET status = 'archived', is_deleted = 1 WHERE id = 'inst-lifecycle-1'")
        conv_row = conn.execute("SELECT character_instance_id FROM conversations WHERE id = 'conv-lifecycle-1'").fetchone()
        assert conv_row[0] == 'inst-lifecycle-1'

        # Requirement 4 & 5: Dependency order for Profile hard purge:
        # Deleting conversations first, then character_instances, then profile succeeds cleanly.
        conn.execute("DELETE FROM conversations WHERE profile_id = ?", (prof,))
        conn.execute("DELETE FROM character_instances WHERE profile_id = ?", (prof,))
        conn.execute("DELETE FROM profiles WHERE id = ?", (prof,))

        assert conn.execute("SELECT COUNT(*) FROM profiles WHERE id = ?", (prof,)).fetchone()[0] == 0
        assert conn.execute("SELECT COUNT(*) FROM character_instances WHERE id = 'inst-lifecycle-1'").fetchone()[0] == 0
        assert conn.execute("PRAGMA foreign_key_check").fetchall() == []


def test_downgrade_009_to_008_fails_closed_when_user_instances_exist_and_succeeds_when_clean(tmp_path: Path):
    db_path = tmp_path / "downgrade_test.db"
    cfg = config(db_path)

    # 1. Start with 008, add legacy conversation, upgrade to 009
    command.upgrade(cfg, PREVIOUS)
    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        prof = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        conn.execute("INSERT INTO conversations (id, profile_id, title, character_id, owner_id, created_at, updated_at) VALUES ('c-leg', ?, 'Legacy', 'old-char', 'local_user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)", (prof,))
        conn.commit()

    command.upgrade(cfg, REVISION)

    # 2. Add a user-created CharacterInstance
    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        prof = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        conn.execute("""
            INSERT INTO character_instances (
                id, profile_id, is_legacy_placeholder, legacy_character_id, template_id,
                source_template_version, name, summary, lore, system_prompt, avatar_asset,
                preset_id, warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                status
            ) VALUES (
                'user-inst-1', ?, 0, NULL, 'warm-companion',
                1, 'User Char', '', '', 'Prompt', 'avatar',
                'warm_companion', 85, 35, 15, 60, 75, 80, 25, 60,
                'active'
            )
        """, (prof,))
        conn.commit()

    # Downgrade MUST FAIL CLOSED because user-created CharacterInstance exists
    with pytest.raises(Exception) as exc_info:
        command.downgrade(cfg, PREVIOUS)
    assert "Downgrade refused" in str(exc_info.value)
    assert "user-created CharacterInstance(s) would be lost" in str(exc_info.value)

    # 3. Clean up the user-created instance, but set active_character_instance_id
    with sqlite3.connect(db_path) as conn:
        conn.execute("DELETE FROM character_instances WHERE id = 'user-inst-1'")
        # Create a clean instance and set active
        conn.execute("""
            INSERT INTO character_instances (
                id, profile_id, is_legacy_placeholder, legacy_character_id, template_id,
                source_template_version, name, summary, lore, system_prompt, avatar_asset,
                preset_id, warmth, teasing, guardedness, directness, expressiveness, affection, formality, verbosity,
                status
            ) VALUES (
                'user-inst-2', ?, 0, NULL, 'warm-companion',
                1, 'User Char 2', '', '', 'Prompt', 'avatar',
                'warm_companion', 85, 35, 15, 60, 75, 80, 25, 60,
                'active'
            )
        """, (prof,))
        conn.execute("UPDATE profiles SET active_character_instance_id = 'user-inst-2' WHERE id = ?", (prof,))
        conn.commit()

    with pytest.raises(Exception) as exc_info:
        command.downgrade(cfg, PREVIOUS)
    assert "Downgrade refused" in str(exc_info.value)

    # 4. Now clean all user instances and active selections; only auto-backfilled legacy placeholders remain
    with sqlite3.connect(db_path) as conn:
        conn.execute("UPDATE profiles SET active_character_instance_id = NULL WHERE id = ?", (prof,))
        conn.execute("DELETE FROM character_instances WHERE id = 'user-inst-2'")
        conn.commit()

    # Downgrade now SUCCEEDS cleanly
    command.downgrade(cfg, PREVIOUS)

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == PREVIOUS
        tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
        assert "character_templates" not in tables
        assert "character_instances" not in tables

        # Original legacy conversation remains 100% intact!
        conv = conn.execute("SELECT id, character_id FROM conversations WHERE id = 'c-leg'").fetchone()
        assert conv[0] == "c-leg"
        assert conv[1] == "old-char"

        # character_instance_id column was cleanly dropped
        cols = {r[1] for r in conn.execute("PRAGMA table_info(conversations)").fetchall()}
        assert "character_instance_id" not in cols

        # active_character_instance_id was cleanly dropped
        prof_cols = {r[1] for r in conn.execute("PRAGMA table_info(profiles)").fetchall()}
        assert "active_character_instance_id" not in prof_cols

    # Re-upgrade to 009 to verify round-trip
    command.upgrade(cfg, REVISION)
    with sqlite3.connect(db_path) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION
