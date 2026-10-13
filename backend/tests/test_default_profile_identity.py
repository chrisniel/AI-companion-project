"""Per-installation Default Profile identity (PC-IDENTITY-001 gate fix).

Every database generates, persists and preserves its own random Default Profile UUID.
No Profile ID is shared across installations. All databases are disposable temp files.
"""

import asyncio
import sqlite3
import uuid
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.storage import prepare_database_schema
from app.db.backup import create_pre_migration_backup
from app.db.base import Base
from app.models.attachment import Attachment
from app.models.conversation import Conversation
from app.models.memory import Memory
from app.models.message import Message
from app.models.task import Task

BACKEND_DIR = Path(__file__).resolve().parent.parent
LEGACY_SHARED_ID = "00000000-0000-4000-8000-000000000001"


def _cfg(db_path: Path) -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
    return cfg


def _default_profiles(db_path: Path) -> list:
    conn = sqlite3.connect(db_path)
    try:
        return [r[0] for r in conn.execute("SELECT id FROM profiles WHERE is_default = 1").fetchall()]
    finally:
        conn.close()


def _single_default(db_path: Path) -> str:
    ids = _default_profiles(db_path)
    assert len(ids) == 1, ids
    return ids[0]


def test_two_fresh_migrated_databases_have_different_default_profile_ids(tmp_path):
    a, b = tmp_path / "a.db", tmp_path / "b.db"
    command.upgrade(_cfg(a), "head")
    command.upgrade(_cfg(b), "head")

    id_a, id_b = _single_default(a), _single_default(b)
    assert id_a != id_b
    assert LEGACY_SHARED_ID not in (id_a, id_b)
    for pid in (id_a, id_b):
        assert uuid.UUID(pid).version == 4


def test_populated_v006_upgrade_assigns_one_unique_default_to_existing_rows(tmp_path):
    ids = []
    for name in ("one.db", "two.db"):
        db = tmp_path / name
        command.upgrade(_cfg(db), "006_add_attachments")
        conn = sqlite3.connect(db)
        conn.execute(
            "INSERT INTO conversations (id, created_at, updated_at, owner_id, title, character_id, is_deleted) "
            "VALUES ('c1', '2026-09-01', '2026-09-01', 'local_user', 'Legacy', 'default', 0)"
        )
        conn.commit()
        conn.close()
        command.upgrade(_cfg(db), "head")
        default_id = _single_default(db)
        conn = sqlite3.connect(db)
        owner_profile = conn.execute("SELECT profile_id FROM conversations WHERE id='c1'").fetchone()[0]
        conn.close()
        assert owner_profile == default_id
        ids.append(default_id)
    assert ids[0] != ids[1]


def test_default_profile_id_preserved_across_restart_and_backup(tmp_path):
    db = tmp_path / "database" / "companion.db"
    backups = tmp_path / "backups"

    prepare_database_schema(db, backup_dir=backups)
    original = _single_default(db)

    prepare_database_schema(db, backup_dir=backups)  # simulated restart
    assert _single_default(db) == original

    snapshot = create_pre_migration_backup(db, backups, label="manual")
    assert _single_default(snapshot) == original


def test_only_one_default_profile_is_allowed(tmp_path):
    db = tmp_path / "single.db"
    command.upgrade(_cfg(db), "head")
    conn = sqlite3.connect(db)
    try:
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                "INSERT INTO profiles (id, name, is_default, status, is_deleted) "
                "VALUES (?, 'Second Default', 1, 'active', 0)",
                (str(uuid.uuid4()),),
            )
    finally:
        conn.close()


def test_raw_insert_without_profile_id_uses_database_default(tmp_path):
    """Historical 007 compatibility is retained when explicitly migrating only to 007."""
    db = tmp_path / "raw.db"
    command.upgrade(_cfg(db), "007_profiles_and_owner_id_migration")
    default_id = _single_default(db)
    conn = sqlite3.connect(db)
    conn.execute(
        "INSERT INTO tasks (id, created_at, updated_at, owner_id, title, status, priority, is_deleted) "
        "VALUES ('t-raw', '2026-09-01', '2026-09-01', 'local_user', 'raw', 'pending', 1, 0)"
    )
    conn.commit()
    assert conn.execute("SELECT profile_id FROM tasks WHERE id='t-raw'").fetchone()[0] == default_id
    conn.close()


async def _create_all_engine(db_path: Path):
    engine = create_async_engine(f"sqlite+aiosqlite:///{db_path.as_posix()}")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    return engine


async def _insert_one_of_each(session: AsyncSession, tag: str, profile_id: str) -> dict:
    conv = Conversation(title=f"conv-{tag}", profile_id=profile_id)
    session.add(conv)
    await session.flush()
    msg = Message(conversation_id=conv.id, sender="user", content="hi", sequence_no=1, profile_id=profile_id)
    task = Task(title=f"task-{tag}", profile_id=profile_id)
    mem = Memory(content=f"memory {tag}", profile_id=profile_id)
    att = Attachment(
        conversation_id=conv.id,
        profile_id=profile_id,
        filename_display="a.png",
        storage_filename=f"a-{tag}.png",
        storage_path=f"attachments/a-{tag}.png",
        mime_type="image/png",
        size_bytes=10,
    )
    session.add_all([msg, task, mem, att])
    await session.commit()
    return {"conversation": conv, "message": msg, "task": task, "memory": mem, "attachment": att}


async def test_create_all_databases_get_distinct_defaults_and_records_use_explicit_profile(tmp_path):
    engines = [await _create_all_engine(tmp_path / n) for n in ("x.db", "y.db")]
    try:
        defaults = []
        for engine in engines:
            async with engine.connect() as conn:
                rows = (await conn.execute(text("SELECT id FROM profiles WHERE is_default = 1"))).fetchall()
            assert len(rows) == 1
            defaults.append(rows[0][0])
        assert defaults[0] != defaults[1]

        for engine, expected in zip(engines, defaults):
            async with async_sessionmaker(engine, expire_on_commit=False)() as session:
                created = await _insert_one_of_each(session, expected[:6], expected)
            for name, obj in created.items():
                assert obj.profile_id == expected, name
                assert obj.owner_id == "local_user", name
    finally:
        for engine in engines:
            await engine.dispose()


async def test_explicit_profile_ownership_persists_across_restart(tmp_path):
    db = tmp_path / "database" / "companion.db"
    await asyncio.to_thread(prepare_database_schema, db)
    default_id = _single_default(db)

    for run in ("first-run", "after-restart"):
        engine = create_async_engine(f"sqlite+aiosqlite:///{db.as_posix()}")
        try:
            async with async_sessionmaker(engine, expire_on_commit=False)() as session:
                created = await _insert_one_of_each(session, run, default_id)
            assert all(obj.profile_id == default_id for obj in created.values())
        finally:
            await engine.dispose()
        await asyncio.to_thread(prepare_database_schema, db)  # idempotent restart

    engine = create_async_engine(f"sqlite+aiosqlite:///{db.as_posix()}")
    try:
        async with async_sessionmaker(engine)() as session:
            for model in (Conversation, Message, Task, Memory, Attachment):
                rows = (await session.execute(select(model.profile_id))).scalars().all()
                assert rows and set(rows) == {default_id}, model.__name__
    finally:
        await engine.dispose()
