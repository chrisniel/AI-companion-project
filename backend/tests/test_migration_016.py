"""Migration tests for 016_reminder_center_popup."""

from pathlib import Path
import sqlite3
import uuid

import pytest
from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parent.parent
REVISION = "016_reminder_center_popup"
PREVIOUS = "015_scheduler_notifications_and_routines"


def config(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


@pytest.fixture
def fresh_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "fresh_016.db"
    command.upgrade(config(db_path), REVISION)
    return db_path


def test_upgrade_adds_center_popup_columns_with_default_true(fresh_db: Path):
    """Verify reminders.center_popup and tasks.reminder_center_popup exist and default to 1."""
    with sqlite3.connect(fresh_db) as conn:
        conn.execute("PRAGMA foreign_keys = ON;")
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION

        rem_cols = {r[1]: r for r in conn.execute("PRAGMA table_info(reminders)").fetchall()}
        assert "center_popup" in rem_cols
        assert rem_cols["center_popup"][3] == 1  # NOT NULL
        assert rem_cols["center_popup"][4] in ("1", 1, "true", "True")

        task_cols = {r[1]: r for r in conn.execute("PRAGMA table_info(tasks)").fetchall()}
        assert "reminder_center_popup" in task_cols
        assert task_cols["reminder_center_popup"][3] == 1  # NOT NULL
        assert task_cols["reminder_center_popup"][4] in ("1", 1, "true", "True")


def test_downgrade_removes_center_popup_columns(fresh_db: Path):
    """Verify downgrade back to 015 safely removes center_popup columns."""
    cfg = config(fresh_db)
    command.downgrade(cfg, PREVIOUS)

    with sqlite3.connect(fresh_db) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == PREVIOUS
        rem_cols = {r[1]: r for r in conn.execute("PRAGMA table_info(reminders)").fetchall()}
        task_cols = {r[1]: r for r in conn.execute("PRAGMA table_info(tasks)").fetchall()}
        assert "center_popup" not in rem_cols
        assert "reminder_center_popup" not in task_cols


def test_upgrade_existing_rows_preserve_data_with_default_true(tmp_path: Path):
    """Verify upgrading a 015 DB backfills center_popup / reminder_center_popup to 1."""
    db_path = tmp_path / "upgrade_015_to_016.db"
    cfg = config(db_path)

    command.upgrade(cfg, PREVIOUS)

    task_id = str(uuid.uuid4())
    rem_id = str(uuid.uuid4())
    with sqlite3.connect(db_path) as conn:
        profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        conn.execute(
            """
            INSERT INTO tasks (id, created_at, updated_at, owner_id, profile_id, title, status, priority, is_deleted)
            VALUES (?, '2026-11-15', '2026-11-15', 'local_user', ?, 'Legacy Task', 'pending', 'medium', 0)
            """,
            (task_id, profile_id),
        )
        conn.execute(
            """
            INSERT INTO reminders (id, created_at, updated_at, owner_id, profile_id, is_deleted, title, scheduled_at, timezone, status, bypass_quiet_hours, origin)
            VALUES (?, '2026-11-15', '2026-11-15', 'local_user', ?, 0, 'Legacy Reminder', '2026-11-15T12:00:00Z', 'UTC', 'scheduled', 0, 'host')
            """,
            (rem_id, profile_id),
        )
        conn.commit()

    command.upgrade(cfg, REVISION)

    with sqlite3.connect(db_path) as conn:
        t_row = conn.execute(
            "SELECT title, reminder_center_popup FROM tasks WHERE id = ?",
            (task_id,),
        ).fetchone()
        r_row = conn.execute(
            "SELECT title, center_popup FROM reminders WHERE id = ?",
            (rem_id,),
        ).fetchone()
        assert t_row == ("Legacy Task", 1)
        assert r_row == ("Legacy Reminder", 1)
