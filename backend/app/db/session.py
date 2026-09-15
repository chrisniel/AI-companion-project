"""Asynchronous SQLite database session management via SQLAlchemy 2.0 and aiosqlite (Batch 8P.3E).

Engine and sessionmaker lifecycles are explicitly initialized after storage preflight
and persistent path finalization. No connections or directories are eagerly created
at module import time.
"""

from collections.abc import AsyncGenerator
from pathlib import Path
from typing import Optional
from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

_engine: Optional[AsyncEngine] = None
_session_factory: Optional[async_sessionmaker[AsyncSession]] = None


def initialize_database_runtime(
    database_url: Optional[str] = None,
    debug: Optional[bool] = None,
) -> AsyncEngine:
    """Initialize the asynchronous SQLite engine and sessionmaker runtime.

    Configures connection pragmas:
    - WAL journal mode
    - busy_timeout = 5000
    - foreign_keys = ON
    - synchronous = NORMAL
    """
    global _engine, _session_factory
    target_url = database_url if database_url is not None else settings.DATABASE_URL
    is_debug = debug if debug is not None else settings.DEBUG

    if _engine is not None:
        return _engine

    _engine = create_async_engine(
        target_url,
        echo=is_debug,
        future=True,
        connect_args={"check_same_thread": False},
    )

    @event.listens_for(_engine.sync_engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        """Enable WAL mode, foreign keys, busy timeouts, and synchronous normal on SQLite connections."""
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode = WAL;")
        cursor.execute("PRAGMA busy_timeout = 5000;")
        cursor.execute("PRAGMA foreign_keys = ON;")
        cursor.execute("PRAGMA synchronous = NORMAL;")
        cursor.close()

    _session_factory = async_sessionmaker(
        bind=_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )
    return _engine


async def dispose_database_runtime() -> None:
    """Dispose the active database engine and reset session factory."""
    global _engine, _session_factory
    if _engine is not None:
        await _engine.dispose()
        _engine = None
        _session_factory = None


def get_engine() -> AsyncEngine:
    """Retrieve the initialized async engine or raise RuntimeError."""
    if _engine is None:
        raise RuntimeError("Database runtime has not been initialized. Call initialize_database_runtime() first.")
    return _engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    """Retrieve the initialized session factory or raise RuntimeError."""
    if _session_factory is None:
        raise RuntimeError("Database runtime has not been initialized. Call initialize_database_runtime() first.")
    return _session_factory


class _EngineProxy:
    """Proxy deferring attribute access to the initialized engine."""
    def __getattr__(self, name: str):
        eng = get_engine()
        return getattr(eng, name)


class _AsyncSessionLocalProxy:
    """Proxy deferring async session creation to the initialized session factory."""
    def __call__(self, *args, **kwargs):
        factory = get_session_factory()
        return factory(*args, **kwargs)


# Backward-compatibility handles
engine: AsyncEngine = _EngineProxy()  # type: ignore[assignment]
AsyncSessionLocal: async_sessionmaker[AsyncSession] = _AsyncSessionLocalProxy()  # type: ignore[assignment]


class Base(DeclarativeBase):
    """Base declarative class for all SQLAlchemy ORM models."""
    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency yielding an async database session."""
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
