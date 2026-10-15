"""Synthetic migration and ORM ownership regressions for M2 Batch B."""

import sqlite3
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.base import Base
from app.models import Attachment, Conversation, Memory, Message, Profile, Task

BACKEND_DIR = Path(__file__).resolve().parent.parent
REVISION = "008_profile_sessions_and_tickets"
PREVIOUS = "007_profiles_and_owner_id_migration"
PERSONAL_TABLES = ("conversations", "messages", "tasks", "memories", "attachments")
ROWS = {
    "conversations": {"id": "conv", "title": "chat", "character_id": "default"},
    "messages": {"id": "msg", "conversation_id": "conv", "sender": "user", "content": "hello", "sequence_no": 1},
    "tasks": {"id": "task", "title": "task", "status": "pending", "priority": "medium"},
    "memories": {"id": "mem", "category": "fact", "content": "quantum", "importance": 1.0},
    "attachments": {"id": "att", "conversation_id": "conv", "message_id": "msg", "filename_display": "test.png", "storage_filename": "test.png", "storage_path": "attachments/test.png", "mime_type": "image/png", "size_bytes": 1},
}


def config(db_path):
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


def insert(conn, table, values):
    values = {"created_at": "2026-10-13 10:00:00", "updated_at": "2026-10-13 10:00:00", "owner_id": "local_user", **values}
    columns = ", ".join(values)
    placeholders = ", ".join("?" for _ in values)
    conn.execute(f"INSERT INTO {table} ({columns}) VALUES ({placeholders})", tuple(values.values()))


def index_contract(conn, table):
    # SQLite autoindex ordinals may change when Alembic reconstructs UNIQUE constraints.
    return sorted((
        "<auto>" if row[1].startswith("sqlite_autoindex_") else row[1],
        row[2:],
        tuple(info[2] for info in conn.execute(f"PRAGMA index_info({row[1]})")),
    ) for row in conn.execute(f"PRAGMA index_list({table})"))


@pytest.fixture
def migrated(tmp_path):
    path = tmp_path / "synthetic.db"
    command.upgrade(config(path), "head")
    return path


def test_session_schema_and_model_contract(migrated):
    with sqlite3.connect(migrated) as conn:
        assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == REVISION
        for table, required in {
            "profile_sessions": {"id", "profile_id", "token_hash", "client_type", "client_identifier", "created_at", "expires_at", "revoked_at", "last_active_at"},
            "session_tickets": {"id", "ticket_hash", "profile_id", "claim_secret_hash", "origin", "created_at", "expires_at", "approved_at", "redeemed_at"},
        }.items():
            assert {r[1] for r in conn.execute(f"PRAGMA table_info({table})")} == required
            assert set(Base.metadata.tables[table].columns.keys()) == required
            fk = conn.execute(f"PRAGMA foreign_key_list({table})").fetchall()
            assert any(r[2] == "profiles" and r[3] == "profile_id" and r[6] == "CASCADE" for r in fk)
            indexed = {tuple(r[2] for r in conn.execute(f"PRAGMA index_info({idx[1]})")) for idx in conn.execute(f"PRAGMA index_list({table})")}
            assert ("expires_at",) in indexed
            assert (("token_hash",) if table == "profile_sessions" else ("ticket_hash",)) in indexed


@pytest.mark.parametrize("table", PERSONAL_TABLES)
def test_raw_sql_requires_explicit_profile(migrated, table):
    with sqlite3.connect(migrated) as conn:
        with pytest.raises(sqlite3.IntegrityError, match=f"NOT NULL constraint failed: {table}.profile_id"):
            insert(conn, table, ROWS[table])
        col = next(row for row in conn.execute(f"PRAGMA table_info({table})") if row[1] == "profile_id")
        assert col[3] == 1 and col[4] is None


@pytest.mark.parametrize("model", [Conversation, Message, Task, Memory, Attachment])
def test_orm_requires_explicit_profile(tmp_path, model):
    engine = create_engine(f"sqlite:///{(tmp_path / 'orm.db').as_posix()}")
    Base.metadata.create_all(engine)
    try:
        with Session(engine) as session:
            session.add(model(**ROWS[model.__tablename__]))
            with pytest.raises(IntegrityError, match=f"NOT NULL constraint failed: {model.__tablename__}.profile_id"):
                session.commit()
    finally:
        engine.dispose()


def test_upgrade_downgrade_preserve_data_foreign_keys_indexes_and_fts(tmp_path):
    path = tmp_path / "populated.db"
    cfg = config(path)
    command.upgrade(cfg, PREVIOUS)
    with sqlite3.connect(path) as conn:
        profile_id = conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchone()[0]
        for table in PERSONAL_TABLES:
            insert(conn, table, ROWS[table])
        conn.commit()
        before = {table: conn.execute(f"SELECT * FROM {table}").fetchall() for table in PERSONAL_TABLES}
        indexes = {table: index_contract(conn, table) for table in PERSONAL_TABLES}
        foreign_keys = {table: sorted(row[2:] for row in conn.execute(f"PRAGMA foreign_key_list({table})")) for table in PERSONAL_TABLES}

    for direction in ("upgrade", "downgrade", "upgrade"):
        getattr(command, direction)(cfg, REVISION if direction == "upgrade" else PREVIOUS)
        with sqlite3.connect(path) as conn:
            conn.execute("PRAGMA foreign_keys=ON")
            assert conn.execute("PRAGMA foreign_key_check").fetchall() == []
            for table in PERSONAL_TABLES:
                assert conn.execute(f"SELECT * FROM {table}").fetchall() == before[table]
                assert index_contract(conn, table) == indexes[table]
                assert sorted(row[2:] for row in conn.execute(f"PRAGMA foreign_key_list({table})")) == foreign_keys[table]
                with pytest.raises(sqlite3.IntegrityError, match=f"NOT NULL constraint failed: {table}.profile_id"):
                    insert(conn, table, {**ROWS[table], "id": "unowned", **({"sequence_no": 2} if table == "messages" else {})})
            assert conn.execute("SELECT id FROM memories_fts WHERE memories_fts MATCH 'quantum'").fetchall() == [("mem",)]
            conn.execute("UPDATE memories SET content = 'astrophysics' WHERE id = 'mem'")
            assert conn.execute("SELECT id FROM memories_fts WHERE memories_fts MATCH 'quantum'").fetchall() == []
            assert conn.execute("SELECT id FROM memories_fts WHERE memories_fts MATCH 'astrophysics'").fetchall() == [("mem",)]
            conn.rollback()
            insert(conn, "memories", {**ROWS["memories"], "id": "new", "profile_id": profile_id, "content": "nebula"})
            assert conn.execute("SELECT id FROM memories_fts WHERE memories_fts MATCH 'nebula'").fetchall() == [("new",)]
            conn.execute("DELETE FROM memories WHERE id = 'new'")
            assert conn.execute("SELECT id FROM memories_fts WHERE memories_fts MATCH 'nebula'").fetchall() == []
            conn.rollback()


def test_startup_snapshot_precedes_migration_and_failure_never_restores(tmp_path, monkeypatch):
    from app.core.storage import StorageError, prepare_database_schema
    from app.db.backup import verify_sqlite_integrity

    path = tmp_path / "startup.db"
    command.upgrade(config(path), PREVIOUS)
    backup_dir = tmp_path / "backups"

    def failing_upgrade(cfg, revision):
        snapshots = list(backup_dir.glob("*.db"))
        assert len(snapshots) == 1
        assert verify_sqlite_integrity(snapshots[0])
        with sqlite3.connect(snapshots[0]) as backup:
            assert backup.execute("SELECT version_num FROM alembic_version").fetchone()[0] == PREVIOUS
        with sqlite3.connect(path) as live:
            live.execute("CREATE TABLE failure_marker(id INTEGER)")
        raise RuntimeError("synthetic DDL failure")

    monkeypatch.setattr(command, "upgrade", failing_upgrade)
    with pytest.raises(StorageError, match="synthetic DDL failure"):
        prepare_database_schema(path, backup_dir=backup_dir)
    assert len(list(backup_dir.glob("*.db"))) == 1
    with sqlite3.connect(path) as live:
        assert live.execute("SELECT name FROM sqlite_master WHERE name='failure_marker'").fetchone()
