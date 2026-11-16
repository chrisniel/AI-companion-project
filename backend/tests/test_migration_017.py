"""Migration and ORM schema tests for 017_d9_tool_policy_and_audit."""

from pathlib import Path
import sqlite3
import uuid

import pytest
from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parent.parent
REVISION = "017_d9_tool_policy_and_audit"
PREVIOUS = "016_reminder_center_popup"


def config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


@pytest.fixture
def fresh_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "fresh_017.db"
    command.upgrade(config(db_path), REVISION)
    return db_path


def test_upgrade_creates_d9_tables_and_message_metadata_column(fresh_db: Path):
    """Verify D9 tables and messages.metadata_json exist on fresh 017 upgrade."""
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

        tables = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        assert {
            "tool_runtime_config",
            "profile_tool_settings",
            "tool_confirmations",
            "tool_audit_logs",
        }.issubset(tables)

        msg_cols = {r[1]: r for r in conn.execute("PRAGMA table_info(messages)").fetchall()}
        assert "metadata_json" in msg_cols
        assert msg_cols["metadata_json"][3] == 0  # nullable

        # Risk tier constraint rejects Risk 3 in audit/confirmation storage
        profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO tool_audit_logs (
                    id, profile_id, tool_name, risk_tier, provenance, decision, outcome_status, created_at
                ) VALUES (?, ?, 'arbitrary_shell', 3, 'EXPLICIT_USER', 'DENY', 'blocked', '2026-11-16T00:00:00Z')
                """,
                (str(uuid.uuid4()), profile_id),
            )


def test_downgrade_removes_d9_tables_and_message_metadata(fresh_db: Path):
    """Verify downgrade back to 016 cleanly drops D9 tables and metadata_json column."""
    cfg = config(fresh_db)
    command.downgrade(cfg, PREVIOUS)

    with sqlite3.connect(fresh_db) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == PREVIOUS
        tables = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        for name in (
            "tool_runtime_config",
            "profile_tool_settings",
            "tool_confirmations",
            "tool_audit_logs",
        ):
            assert name not in tables

        msg_cols = {r[1]: r for r in conn.execute("PRAGMA table_info(messages)").fetchall()}
        assert "metadata_json" not in msg_cols


def test_upgrade_from_016_preserves_existing_messages(tmp_path: Path):
    """Verify upgrading an existing 016 database keeps messages with NULL metadata_json."""
    db_path = tmp_path / "upgrade_016_to_017.db"
    cfg = config(db_path)
    command.upgrade(cfg, PREVIOUS)

    conv_id = str(uuid.uuid4())
    msg_id = str(uuid.uuid4())
    with sqlite3.connect(db_path) as conn:
        profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        conn.execute(
            """
            INSERT INTO conversations (id, created_at, updated_at, owner_id, profile_id, title, is_deleted)
            VALUES (?, '2026-11-16', '2026-11-16', 'local_user', ?, 'Legacy Conv', 0)
            """,
            (conv_id, profile_id),
        )
        conn.execute(
            """
            INSERT INTO messages (id, created_at, updated_at, owner_id, profile_id, conversation_id, sender, content, status, sequence_no, is_deleted)
            VALUES (?, '2026-11-16', '2026-11-16', 'local_user', ?, ?, 'assistant', 'Hello!', 'completed', 1, 0)
            """,
            (msg_id, profile_id, conv_id),
        )
        conn.commit()

    command.upgrade(cfg, REVISION)

    with sqlite3.connect(db_path) as conn:
        row = conn.execute(
            "SELECT content, metadata_json FROM messages WHERE id = ?", (msg_id,)
        ).fetchone()
        assert row == ("Hello!", None)
