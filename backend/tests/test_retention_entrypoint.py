"""Standalone retention uses its own runtime and only prepared synthetic storage."""

import os
from contextlib import closing
from pathlib import Path
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.core.storage import get_canonical_paths, prepare_database_schema
from app.db import session as db_session
from app.models.task import Task
from app.services.retention import purge_expired_trash, run_retention_purge_job


BACKEND = Path(__file__).resolve().parents[1]
CLI_BOOTSTRAP = r'''
import os
from pathlib import Path
import platform
import runpy
import socket
import sys
root = Path(os.environ["COMPANION_DATA_ROOT"]).parent.resolve()
selected_env = Path(os.environ["COMPANION_ENV_FILE"]).resolve()
selected_db = root / "data" / "database" / "companion.db"
# Cache CPython 3.11's read-only Windows version query before denying all
# subprocesses/file writes outside the disposable application boundary.
platform.uname()
def inside(path):
    return path == root or root in path.parents
def guard(event, args):
    if event == "open" and isinstance(args[0], (str, bytes, os.PathLike)):
        path = Path(os.fsdecode(args[0])).resolve()
        if path.name == ".env" or path.name.startswith(".env."):
            if path != selected_env:
                raise AssertionError("Foreign authentication configuration access")
        mode, flags = args[1], args[2]
        writing = isinstance(mode, str) and any(c in mode for c in "wax+")
        writing = writing or (isinstance(flags, int) and flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC))
        if writing and not inside(path):
            raise AssertionError("Write outside disposable retention root")
    if event == "sqlite3.connect":
        target = os.fsdecode(args[0])
        if target not in (str(selected_db), str(selected_db).replace("\\", "/")) and not target.startswith(selected_db.as_uri() + "?"):
            raise AssertionError("Foreign database access")
    if event == "socket.connect":
        # Windows asyncio creates a local socketpair to wake its event loop.
        # CPython 3.11 names this socketpair; newer CPython uses the fallback name.
        frame = sys._getframe()
        while frame:
            if frame.f_code.co_name in ("socketpair", "_fallback_socketpair") and frame.f_code.co_filename == socket.__file__:
                if args[1][0] in ("127.0.0.1", "::1"):
                    return
            frame = frame.f_back
        raise AssertionError("Unexpected network access")
    if event in ("subprocess.Popen", "os.system"):
        raise AssertionError("Unexpected external side effect")
sys.addaudithook(guard)
# This exemption must never allow an application-level network connection.
with socket.socket() as probe:
    try:
        probe.connect(("127.0.0.1", 9))
    except AssertionError as error:
        assert str(error) == "Unexpected network access"
    else:
        raise AssertionError("CLI guard permitted application network access")
try:
    runpy.run_module("app.services.retention", run_name="__main__")
finally:
    from app.db import session
    try:
        session.get_engine()
    except RuntimeError:
        pass
    else:
        raise AssertionError("CLI left its owned database runtime initialized")
'''


@pytest.fixture
def retention_storage(tmp_path, monkeypatch):
    root = tmp_path / "retention"
    root.mkdir()
    env_file = root / ".env"
    env_file.write_text("", encoding="utf-8")
    environment = {
        "COMPANION_ENV_FILE": str(env_file),
        "COMPANION_API_KEY": "companion_sec_retention_synthetic_1234567890",
        "COMPANION_DATA_ROOT": str(root / "data"),
        "LOCALAPPDATA": str(root / "localappdata"),
        "PYTHONDONTWRITEBYTECODE": "1",
        "DEBUG": "false",
    }
    for name, value in environment.items():
        monkeypatch.setenv(name, value)
    return get_canonical_paths(root / "data").DATABASE_PATH, environment


def _prepare(database_path):
    # Test fixture provisioning is separate from the destructive CLI invocation.
    prepare_database_schema(database_path)
    now = datetime.now(timezone.utc)
    with closing(sqlite3.connect(database_path)) as connection, connection:
        for task_id, owner, deleted, age in (
            ("expired-a", "owner-a", 1, 40),
            ("expired-b", "owner-b", 1, 40),
            ("recent-a", "owner-a", 1, 5),
            ("active-a", "owner-a", 0, 40),
            ("active-b", "owner-b", 0, 40),
        ):
            connection.execute(
                "INSERT INTO tasks (id, owner_id, title, status, priority, is_deleted, deleted_at) VALUES (?, ?, ?, 'pending', 'medium', ?, ?)",
                (task_id, owner, task_id, deleted, (now - timedelta(days=age)).isoformat()),
            )
        connection.execute("CREATE TABLE retention_unrelated (value TEXT NOT NULL)")
        connection.execute("INSERT INTO retention_unrelated VALUES ('synthetic sentinel')")


def _cli(environment):
    child_environment = os.environ.copy()
    child_environment.update(environment)
    return subprocess.run(
        [sys.executable, "-B", "-c", CLI_BOOTSTRAP, "--days", "30"],
        cwd=BACKEND,
        env=child_environment,
        capture_output=True,
        text=True,
        timeout=30,
    )


def _task_ids(database_path):
    with closing(sqlite3.connect(database_path)) as connection, connection:
        return {row[0] for row in connection.execute("SELECT id FROM tasks")}


def _runtime_is_disposed():
    with pytest.raises(RuntimeError, match="not been initialized"):
        db_session.get_engine()
    with pytest.raises(RuntimeError, match="not been initialized"):
        db_session.get_session_factory()


def test_actual_retention_cli_purges_only_expired_deleted_tasks(retention_storage):
    database_path, environment = retention_storage
    _prepare(database_path)
    result = _cli(environment)
    assert result.returncode == 0, result.stderr
    assert "Permanently removed 2 expired tasks" in result.stdout
    assert _task_ids(database_path) == {"recent-a", "active-a", "active-b"}
    with closing(sqlite3.connect(database_path)) as connection, connection:
        assert connection.execute("SELECT value FROM retention_unrelated").fetchall() == [("synthetic sentinel",)]
    assert Path(environment["COMPANION_ENV_FILE"]).read_text(encoding="utf-8") == ""


def test_actual_cli_disposes_after_database_delete_failure(retention_storage):
    database_path, environment = retention_storage
    _prepare(database_path)
    with closing(sqlite3.connect(database_path)) as connection, connection:
        connection.execute("CREATE TRIGGER retention_reject_delete BEFORE DELETE ON tasks BEGIN SELECT RAISE(ABORT, 'synthetic purge failure'); END")
    result = _cli(environment)
    assert result.returncode != 0
    assert "synthetic purge failure" in result.stderr
    assert "CLI left its owned" not in result.stderr
    assert "expired-a" in _task_ids(database_path)


@pytest.mark.parametrize("schema", ["absent", "empty", "old_revision", "missing_task_column"])
def test_cli_rejects_unprepared_schema_without_migration(retention_storage, schema):
    database_path, environment = retention_storage
    if schema == "empty":
        database_path.parent.mkdir(parents=True)
        sqlite3.connect(database_path).close()
    elif schema != "absent":
        _prepare(database_path)
        with closing(sqlite3.connect(database_path)) as connection, connection:
            if schema == "old_revision":
                connection.execute("UPDATE alembic_version SET version_num='001_initial_tasks_schema'")
            else:
                connection.execute("ALTER TABLE tasks RENAME COLUMN deleted_at TO incompatible_deleted_at")
    original = database_path.read_bytes() if database_path.exists() else None
    result = _cli(environment)
    assert result.returncode != 0
    assert "Retention purge requires" in result.stderr
    if original is None:
        assert not database_path.exists()
        assert not database_path.parent.exists()
    else:
        assert database_path.read_bytes() == original
    assert Path(environment["COMPANION_ENV_FILE"]).read_text(encoding="utf-8") == ""


@pytest.mark.asyncio
@pytest.mark.parametrize("fail_delete", [False, True])
async def test_owned_runner_disposes_runtime_after_success_or_database_failure(retention_storage, fail_delete):
    database_path, _ = retention_storage
    _prepare(database_path)
    if fail_delete:
        with closing(sqlite3.connect(database_path)) as connection, connection:
            connection.execute("CREATE TRIGGER retention_reject_delete BEFORE DELETE ON tasks BEGIN SELECT RAISE(ABORT, 'synthetic purge failure'); END")
    _runtime_is_disposed()
    if fail_delete:
        with pytest.raises(IntegrityError):
            await run_retention_purge_job(retention_days=30)
        assert "expired-a" in _task_ids(database_path)
    else:
        assert await run_retention_purge_job(retention_days=30) == 2
    _runtime_is_disposed()
    # Windows rename also proves connections no longer keep the database open.
    moved = database_path.with_suffix(".closed")
    database_path.rename(moved)
    moved.rename(database_path)


@pytest.mark.asyncio
async def test_owned_runner_rejects_existing_runtime_without_disposing_it(retention_storage):
    database_path, _ = retention_storage
    _prepare(database_path)
    engine = db_session.initialize_database_runtime()
    try:
        with pytest.raises(RuntimeError, match="already initialized"):
            await run_retention_purge_job(retention_days=30)
        assert db_session.get_engine() is engine
        assert "expired-a" in _task_ids(database_path)
    finally:
        await db_session.dispose_database_runtime()


@pytest.mark.asyncio
async def test_caller_owned_session_keeps_owner_scope_and_session_usable(test_session):
    now = datetime.now(timezone.utc)
    test_session.add_all([
        Task(id="owner-a-expired", owner_id="owner-a", title="synthetic a", is_deleted=True, deleted_at=now - timedelta(days=40)),
        Task(id="owner-b-expired", owner_id="owner-b", title="synthetic b", is_deleted=True, deleted_at=now - timedelta(days=40)),
    ])
    await test_session.commit()
    assert await purge_expired_trash(test_session, retention_days=30, owner_id="owner-a") == 1
    remaining = (await test_session.execute(select(Task.id))).scalars().all()
    assert remaining == ["owner-b-expired"]
    assert test_session.is_active
