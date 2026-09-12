"""Pytest fixtures for in-memory SQLite database and async HTTP client."""

import asyncio
from typing import AsyncGenerator
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.api.deps import get_db
from app.core.config import settings
from app.db.base import Base
from app.main import app

TEST_TOKEN = "companion_sec_test_token_abcdef1234567890"

# Use in-memory SQLite for high-speed isolated tests
TEST_DB_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"


@pytest.fixture(scope="session")
def test_token() -> str:
    """Fixture providing valid testing pairing token."""
    settings.COMPANION_API_KEY = TEST_TOKEN
    return TEST_TOKEN


@pytest.fixture(scope="session")
def auth_headers(test_token: str) -> dict:
    """Fixture providing Authorization: Bearer header."""
    return {"Authorization": f"Bearer {test_token}"}


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

    async with async_session() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest.fixture
async def client(test_session: AsyncSession, test_token: str) -> AsyncGenerator[AsyncClient, None]:
    """Async test client with get_db overridden to use the in-memory test_session."""
    app.dependency_overrides[get_db] = lambda: test_session

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac

    app.dependency_overrides.clear()
