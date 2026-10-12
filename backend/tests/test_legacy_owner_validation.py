"""Strict legacy owner validation for Migration 007 (PC-IDENTITY-001 gate fix).

Only the explicitly approved aliases {'local_user', 'default_user'} migrate. Unexpected,
empty, whitespace-only, case-variant or NULL owners make the migration refuse without
mutating any source data. Disposable SQLite databases only.
"""

import hashlib
import sqlite3
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config

from app.db.backup import MigrationAmbiguityError

BACKEND_DIR = Path(__file__).resolve().parent.parent

OWNER_TABLES = ["conversations", "messages", "memories", "tasks", "attachments"]


def _cfg(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


def _seed_v006(db_path: Path, bad_table: str, bad_owner) -> None:
    """Seed a v006 DB with approved rows everywhere and one row with the given owner."""
    command.upgrade(_cfg(db_path), "006_add_attachments")
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys=OFF")
    conn.execute(
        "INSERT INTO conversations (id, created_at, updated_at, owner_id, title, character_id, is_deleted) "
        "VALUES ('c-ok', '2026-09-01', '2026-09-01', 'local_user', 'ok', 'default', 0)"
    )
    conn.execute(
        "INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, sequence_no, is_deleted) "
        "VALUES ('m-ok', '2026-09-01', '2026-09-01', 'default_user', 'c-ok', 'user', 'hi', 1, 0)"
    )
    conn.execute(
        "INSERT INTO memories (id, created_at, updated_at, owner_id, category, content, importance, is_deleted) "
        "VALUES ('mem-ok', '2026-09-01', '2026-09-01', 'local_user', 'fact', 'remember quantum', 1.0, 0)"
    )
    conn.execute(
        "INSERT INTO tasks (id, created_at, updated_at, owner_id, title, status, priority, is_deleted) "
        "VALUES ('t-ok', '2026-09-01', '2026-09-01', 'local_user', 'ok', 'pending', 1, 0)"
    )
    conn.execute(
        "INSERT INTO attachments (id, created_at, updated_at, owner_id, conversation_id, filename_display, "
        "storage_filename, storage_path, mime_type, size_bytes, is_deleted) "
        "VALUES ('a-ok', '2026-09-01', '2026-09-01', 'local_user', 'c-ok', 'a.png', 's.png', 'attachments/s.png', 'image/png', 1, 0)"
    )
    if bad_owner is not None:
        row_id = f"bad-{bad_table}"
        if bad_table == "conversations":
            conn.execute(
                "INSERT INTO conversations (id, created_at, updated_at, owner_id, title, character_id, is_deleted) "
                "VALUES (?, '2026-09-01', '2026-09-01', ?, 'bad', 'default', 0)", (row_id, bad_owner))
        elif bad_table == "messages":
            conn.execute(
                "INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, sequence_no, is_deleted) "
                "VALUES (?, '2026-09-01', '2026-09-01', ?, 'c-ok', 'user', 'bad', 2, 0)", (row_id, bad_owner))
        elif bad_table == "memories":
            conn.execute(
                "INSERT INTO memories (id, created_at, updated_at, owner_id, category, content, importance, is_deleted) "
                "VALUES (?, '2026-09-01', '2026-09-01', ?, 'fact', 'bad', 1.0, 0)", (row_id, bad_owner))
        elif bad_table == "tasks":
            conn.execute(
                "INSERT INTO tasks (id, created_at, updated_at, owner_id, title, status, priority, is_deleted) "
                "VALUES (?, '2026-09-01', '2026-09-01', ?, 'bad', 'pending', 1, 0)", (row_id, bad_owner))
        else:
            conn.execute(
                "INSERT INTO attachments (id, created_at, updated_at, owner_id, conversation_id, filename_display, "
                "storage_filename, storage_path, mime_type, size_bytes, is_deleted) "
                "VALUES (?, '2026-09-01', '2026-09-01', ?, 'c-ok', 'b.png', 'b.png', 'attachments/b.png', 'image/png', 1, 0)",
                (row_id, bad_owner))
    conn.commit()
    conn.close()


def _fingerprint(db_path: Path) -> dict:
    conn = sqlite3.connect(db_path)
    try:
        out = {}
        for table in OWNER_TABLES:
            rows = conn.execute(f"SELECT * FROM {table} ORDER BY id").fetchall()
            out[table] = hashlib.sha256(repr(rows).encode()).hexdigest()
        out["version"] = conn.execute("SELECT version_num FROM alembic_version").fetchone()[0]
        out["tables"] = sorted(r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'"))
        return out
    finally:
        conn.close()


@pytest.mark.parametrize("table", OWNER_TABLES)
@pytest.mark.parametrize("bad_owner", ["rogue_tenant", "", "   ", "Local_User", "local_user "])
def test_unapproved_owner_values_refuse_migration_and_preserve_source(tmp_path, table, bad_owner):
    db = tmp_path / "legacy.db"
    _seed_v006(db, table, bad_owner)
    before = _fingerprint(db)

    with pytest.raises(MigrationAmbiguityError):
        command.upgrade(_cfg(db), "007_profiles_and_owner_id_migration")

    assert _fingerprint(db) == before
    assert "profiles" not in before["tables"]


def test_null_owner_values_are_rejected_by_the_validator(tmp_path):
    """NOT NULL columns normally prevent NULL owners; the validator must still reject them."""
    from app.db.legacy_owner_validation import find_unapproved_owners

    db = tmp_path / "legacy_null.db"
    conn = sqlite3.connect(db)
    conn.execute("CREATE TABLE tasks (id TEXT PRIMARY KEY, owner_id TEXT)")  # nullable on purpose
    conn.execute("INSERT INTO tasks VALUES ('t1', NULL)")
    conn.execute("INSERT INTO tasks VALUES ('t2', 'local_user')")
    conn.commit()
    try:
        found = find_unapproved_owners(conn, ["tasks", "table_that_does_not_exist"])
    finally:
        conn.close()
    assert found == {"tasks": [None]}


def test_approved_aliases_only_migrate_successfully(tmp_path):
    db = tmp_path / "ok.db"
    _seed_v006(db, "tasks", None)
    command.upgrade(_cfg(db), "head")
    conn = sqlite3.connect(db)
    owners = {r[0] for r in conn.execute("SELECT DISTINCT owner_id FROM tasks")}
    assert owners == {"local_user"}
    assert conn.execute("PRAGMA foreign_key_check").fetchall() == []
    assert conn.execute("SELECT count(*) FROM memories_fts WHERE memories_fts MATCH 'quantum'").fetchone()[0] == 1
    conn.close()
