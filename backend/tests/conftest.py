"""Pytest fixtures for in-memory SQLite database and async HTTP client."""

import atexit
import asyncio
import os
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import AsyncGenerator

# Fixtures run after collection. Isolate configuration, authentication and storage
# before importing any application module, including app.api.deps and app.main.
TEST_TOKEN = "companion_sec_test_token_abcdef1234567890"
_collection_directory = TemporaryDirectory(prefix="companion-test-collection-")
_collection_root = Path(_collection_directory.name)
_collection_env_file = _collection_root / ".env"
_collection_env_file.write_text("", encoding="utf-8")
_collection_environment = {
    "COMPANION_ENV_FILE": str(_collection_env_file),
    "COMPANION_API_KEY": TEST_TOKEN,
    "COMPANION_DATA_ROOT": str(_collection_root / "data"),
    "LOCALAPPDATA": str(_collection_root / "localappdata"),
}
_previous_environment = {name: os.environ.get(name) for name in _collection_environment}
os.environ.update(_collection_environment)


def _cleanup_collection_environment():
    for name, previous_value in _previous_environment.items():
        if previous_value is None:
            os.environ.pop(name, None)
        else:
            os.environ[name] = previous_value
    _collection_directory.cleanup()


atexit.register(_cleanup_collection_environment)


def pytest_unconfigure(config):
    _cleanup_collection_environment()
    atexit.unregister(_cleanup_collection_environment)


import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.api.deps import get_db
from app.core.config import settings
from app.db.base import Base
from app.main import app

from app.services.llm.manager import llm_manager
from app.services.llm.mock import MockLLMProvider

# Use in-memory SQLite for high-speed isolated tests
TEST_DB_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"


@pytest.fixture(autouse=True)
def isolate_test_environment(tmp_path_factory, monkeypatch):
    """Ensure all tests run with isolated temporary storage roots.

    Guarantees no test touches the real %LOCALAPPDATA%\\AI Companion or real databases.
    """
    temp_local_app_data = tmp_path_factory.mktemp("mock_localappdata")
    temp_companion_data = tmp_path_factory.mktemp("mock_companion_data")
    monkeypatch.setenv("LOCALAPPDATA", str(temp_local_app_data))
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(temp_companion_data))
    yield temp_companion_data


@pytest.fixture(autouse=True)
def default_mock_llm_provider():
    """Ensure all tests run deterministically against MockLLMProvider unless explicitly overridden."""
    mock = MockLLMProvider(default_model="mock-default-model")
    llm_manager.set_provider(mock)
    yield mock
    llm_manager.reset()


@pytest.fixture(scope="session")
def test_token() -> str:
    """Fixture providing valid testing pairing token."""
    settings.COMPANION_API_KEY = TEST_TOKEN
    return TEST_TOKEN


@pytest.fixture(scope="session")
def pairing_headers(test_token: str) -> dict:
    """Legacy pairing grants diagnostic telemetry only."""
    return {"Authorization": f"Bearer {test_token}"}


@pytest.fixture
async def profile_id(test_session):
    return test_session.info["default_profile_id"]


@pytest.fixture
async def profile_session(test_session, profile_id):
    from app.core.profile_sessions import new_profile_session
    token, session = new_profile_session(profile_id, "desktop")
    test_session.add(session)
    await test_session.commit()
    session_token = token
    test_session.info["profile_session_token"] = session_token
    return session


@pytest.fixture
async def auth_headers(test_session, profile_session) -> dict:
    """Personal API tests use real persisted, expiring Profile Sessions."""
    return {"Authorization": f"Bearer {test_session.info['profile_session_token']}"}


@pytest.fixture
def host_admin_headers(monkeypatch):
    from app.core import host_admin
    credential = "test-host-admin-independent-credential"
    monkeypatch.setattr(host_admin, "read_host_admin_secret", lambda: credential)
    return {"X-Host-Admin-Secret": credential}


@pytest.fixture(scope="session")
def api_key_headers(test_token: str) -> dict:
    """Fixture providing X-API-Key header."""
    return {"X-API-Key": test_token}


@pytest.fixture
async def test_session() -> AsyncGenerator[AsyncSession, None]:
    """Create a fresh in-memory database and session for each test function."""
    engine = create_async_engine(
        TEST_DB_URL,
        connect_args={"check_same_thread": False},
    )
    async_session = async_sessionmaker(
        bind=engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        from sqlalchemy import text
        await conn.execute(text("""
            CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
                id UNINDEXED, content, category, content='memories', content_rowid='rowid'
            );
        """))
        await conn.execute(text("""
            CREATE TRIGGER IF NOT EXISTS memories_fts_insert AFTER INSERT ON memories
            WHEN NEW.deleted_at IS NULL
            BEGIN INSERT INTO memories_fts(rowid, id, content, category) VALUES(NEW.rowid, NEW.id, NEW.content, NEW.category); END;
        """))
        await conn.execute(text("""
            CREATE TRIGGER IF NOT EXISTS memories_fts_update AFTER UPDATE ON memories
            BEGIN
                INSERT INTO memories_fts(memories_fts, rowid, id, content, category) VALUES('delete', OLD.rowid, OLD.id, OLD.content, OLD.category);
                INSERT INTO memories_fts(rowid, id, content, category) SELECT NEW.rowid, NEW.id, NEW.content, NEW.category WHERE NEW.deleted_at IS NULL;
            END;
        """))
        await conn.execute(text("""
            CREATE TRIGGER IF NOT EXISTS memories_fts_delete AFTER DELETE ON memories
            BEGIN INSERT INTO memories_fts(memories_fts, rowid, id, content, category) VALUES('delete', OLD.rowid, OLD.id, OLD.content, OLD.category); END;
        """))

    async with async_session() as session:
        from sqlalchemy import select
        from app.models.profile import Profile
        session.info["default_profile_id"] = (await session.execute(
            select(Profile.id).where(Profile.is_default.is_(True)))).scalar_one()
        yield session

    async with engine.begin() as conn:
        from sqlalchemy import text
        await conn.execute(text("DROP TABLE IF EXISTS memories_fts;"))
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest.fixture
async def client(test_session: AsyncSession, test_token: str) -> AsyncGenerator[AsyncClient, None]:
    """Async test client with get_db overridden to use the in-memory test_session."""
    app.dependency_overrides[get_db] = lambda: test_session
    if hasattr(app.state, "bootstrap_attempts"):
        app.state.bootstrap_attempts.clear()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://127.0.0.1") as ac:
        yield ac

    app.dependency_overrides.clear()
