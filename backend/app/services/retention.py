"""Automated retention policy and Recycle Bin purge services (Section 16.1)."""

import asyncio
from datetime import datetime, timedelta, timezone
from typing import Optional
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.logging import logger
from app.db.session import AsyncSessionLocal
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


async def run_retention_purge_job(retention_days: Optional[int] = None) -> int:
    """Standalone runner for background retention sweeps or Windows scheduled task."""
    async with AsyncSessionLocal() as session:
        return await purge_expired_trash(session, retention_days=retention_days)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Purge expired soft-deleted records from Local AI Core.")
    parser.add_argument("--days", type=int, default=None, help="Retention period in days (default from config)")
    args = parser.parse_args()

    count = asyncio.run(run_retention_purge_job(retention_days=args.days))
    print(f"Purge complete. Permanently removed {count} expired tasks.")
