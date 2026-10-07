"""Automated retention policy and Recycle Bin purge services (Section 16.1)."""

import asyncio
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sqlite3
from typing import Optional
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.logging import logger
from app.db.session import (
    AsyncSessionLocal,
    dispose_database_runtime,
    get_engine,
    initialize_database_runtime,
)
from app.models.task import Task


def calculate_remaining_days(
    deleted_at: Optional[datetime],
    retention_days: Optional[int] = None,
) -> int:
    """Calculate remaining retention days before permanent purge."""
    days = retention_days if retention_days is not None else settings.DATA_RETENTION_DAYS
    if not deleted_at:
        return days

    now = datetime.now(timezone.utc)
    target_dt = deleted_at if deleted_at.tzinfo else deleted_at.replace(tzinfo=timezone.utc)
    elapsed_seconds = (now - target_dt).total_seconds()
    elapsed_days = elapsed_seconds / 86400.0
    remaining = int(days - elapsed_days)
    return max(0, remaining)


async def purge_expired_trash(
    db: AsyncSession,
    retention_days: Optional[int] = None,
    owner_id: Optional[str] = None,
) -> int:
    """Permanently delete soft-deleted records older than the retention threshold.
    
    Adheres strictly to owner-isolation if owner_id is provided.
    """
    days = retention_days if retention_days is not None else settings.DATA_RETENTION_DAYS
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    stmt = delete(Task).where(
        Task.is_deleted.is_(True),
        Task.deleted_at <= cutoff,
    )

    if owner_id:
        stmt = stmt.where(Task.owner_id == owner_id)

    result = await db.execute(stmt)
    await db.commit()
    purged_count = result.rowcount or 0

    if purged_count > 0:
        logger.info(
            f"Retention purge executed: {purged_count} soft-deleted tasks older than {days} days permanently removed."
        )

    return purged_count


def _require_prepared_database(database_path: Path) -> None:
    """Validate schema metadata read-only; retention never creates or migrates it."""
    error = (
        "Retention purge requires an existing compatible database at the current "
        "schema. Prepare storage through normal startup before running retention."
    )
    if not database_path.is_file():
        raise RuntimeError(error)

    config = Config()
    config.set_main_option(
        "script_location", str(Path(__file__).resolve().parents[2] / "migrations")
    )
    expected_heads = set(ScriptDirectory.from_config(config).get_heads())
    try:
        uri = database_path.resolve().as_uri() + "?mode=ro"
        with closing(sqlite3.connect(uri, uri=True)) as connection:
            revisions = {
                row[0] for row in connection.execute("SELECT version_num FROM alembic_version")
            }
            task_columns = {
                row[1] for row in connection.execute("PRAGMA table_info(tasks)")
            }
        if revisions != expected_heads or not set(Task.__table__.columns.keys()).issubset(task_columns):
            raise RuntimeError(error)
    except sqlite3.Error:
        raise RuntimeError(error) from None


async def run_retention_purge_job(retention_days: Optional[int] = None) -> int:
    """Own the standalone runtime; require prepared storage and dispose on exit.

    Application callers with an existing session use ``purge_expired_trash``;
    this runner must not take over or dispose another caller's database runtime.
    """
    try:
        get_engine()
    except RuntimeError:
        pass
    else:
        raise RuntimeError("Database runtime is already initialized; use the caller-owned purge session.")

    paths = settings.canonical_paths
    _require_prepared_database(paths.DATABASE_PATH)
    try:
        initialize_database_runtime(database_url=paths.DATABASE_URL)
        async with AsyncSessionLocal() as session:
            return await purge_expired_trash(session, retention_days=retention_days)
    finally:
        await dispose_database_runtime()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Purge expired soft-deleted records from Local AI Runtime.")
    parser.add_argument("--days", type=int, default=None, help="Retention period in days (default from config)")
    args = parser.parse_args()

    count = asyncio.run(run_retention_purge_job(retention_days=args.days))
    print(f"Purge complete. Permanently removed {count} expired tasks.")
