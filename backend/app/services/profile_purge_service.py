"""Profile Purge Service (PC-IDENTITY-005).

Provides 30-day soft-deletion, admin restoration, safe physical-first permanent purge,
in-flight upload reconciliation, crash-orphaned file cleanup, and periodic maintenance sweeps.
"""

import asyncio
from datetime import datetime, timedelta, timezone
import logging
from pathlib import Path
from typing import Optional

from fastapi import HTTPException
from pydantic import BaseModel
from sqlalchemy import delete, func, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.attachments import (
    SecurityException,
    resolve_and_verify_profile_attachment_path,
)
from app.core.config import settings
from app.core.profile_sessions import now_utc
from app.models.attachment import Attachment
from app.models.character_instance import CharacterInstance
from app.models.conversation import Conversation
from app.models.memory import Memory
from app.models.message import Message
from app.models.profile import Profile
from app.models.profile_session import ProfileSession
from app.models.session_ticket import SessionTicket
from app.models.task import Task

logger = logging.getLogger(__name__)


def _as_utc(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


class PurgeMaintenanceResult(BaseModel):
    """Result summary for manual and periodic Profile purge maintenance sweeps."""
    purged_profile_ids: list[str] = []
    failed_profile_ids: list[str] = []


class ProfilePurgeService:
    """Service encapsulating the complete Profile deletion, recovery, and purge lifecycle."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def soft_delete_profile(self, profile_id: str) -> Profile:
        """Move an active secondary Profile to Recently Deleted with a 30-day recovery window."""
        profile = await self.db.get(Profile, profile_id)
        if not profile or profile.status == "purging":
            raise HTTPException(status_code=404, detail="Profile not found")

        if profile.is_default:
            raise HTTPException(status_code=400, detail="Cannot delete default profile")

        # Ensure host has at least one other active Profile
        active_count_stmt = select(func.count(Profile.id)).where(
            Profile.is_deleted.is_(False),
            Profile.status == "active",
        )
        active_count = await self.db.scalar(active_count_stmt)
        if active_count is not None and active_count <= 1:
            raise HTTPException(status_code=400, detail="Cannot delete the only active profile on host")

        if profile.is_deleted and profile.status == "deleted":
            return profile

        now = now_utc()
        profile.status = "deleted"
        profile.is_deleted = True
        profile.deleted_at = now
        profile.purge_after = now + timedelta(days=30)
        profile.updated_at = now

        # Immediately revoke all active profile sessions and tickets
        await self.db.execute(
            update(ProfileSession)
            .where(ProfileSession.profile_id == profile_id, ProfileSession.revoked_at.is_(None))
            .values(revoked_at=now)
        )
        await self.db.execute(
            delete(SessionTicket).where(SessionTicket.profile_id == profile_id)
        )

        await self.db.commit()
        await self.db.refresh(profile)
        return profile

    async def list_deleted_profiles(self) -> list[Profile]:
        """Catalog all Profiles currently in Recently Deleted."""
        stmt = (
            select(Profile)
            .where(
                Profile.is_deleted.is_(True),
                Profile.status.in_(("deleted", "purging")),
            )
            .order_by(Profile.deleted_at.desc(), Profile.id.asc())
        )
        return list((await self.db.execute(stmt)).scalars().all())

    async def restore_profile(self, profile_id: str) -> Profile:
        """Restore a Profile from Recently Deleted back to active state.

        Strict Boundary: Restores Profile-level container state only;
        does not un-delete child conversations, messages, memories, tasks, or attachments
        that were intentionally soft-deleted before Profile deletion.
        """
        profile = await self.db.get(Profile, profile_id)
        if not profile:
            raise HTTPException(status_code=404, detail="Profile not found")

        if profile.status == "purging":
            raise HTTPException(status_code=409, detail="Profile is being permanently purged and cannot be restored")

        if not profile.is_deleted or profile.status != "deleted":
            raise HTTPException(status_code=400, detail="Profile is not in Recently Deleted")

        now = now_utc()
        pa = _as_utc(profile.purge_after)
        if pa is not None and pa <= now:
            raise HTTPException(status_code=410, detail="Profile retention period has expired")

        # Name collision guard
        collision_stmt = select(Profile.id).where(
            func.lower(Profile.name) == profile.name.lower(),
            Profile.id != profile_id,
            Profile.is_deleted.is_(False),
            Profile.status == "active",
        )
        if (await self.db.execute(collision_stmt)).first() is not None:
            raise HTTPException(status_code=409, detail="An active profile with this name already exists")

        profile.status = "active"
        profile.is_deleted = False
        profile.deleted_at = None
        profile.purge_after = None
        profile.updated_at = now

        await self.db.commit()
        await self.db.refresh(profile)
        return profile

    async def purge_profile(self, profile_id: str, allow_unexpired: bool = False) -> bool:
        """Permanently purge a Profile and all owned filesystem & relational assets.

        Executes 5-Phase Purge:
        Phase A: Pre-validate all attachment paths before any state change.
        Phase B: Atomic transition to non-restorable status = 'purging' and session revocation.
        Phase C: Post-transition attachment reconciliation.
        Phase D: Physical file unlinking and comprehensive Profile directory cleanup.
        Phase E: Atomic relational database deletion in strict FK dependency order.
        """
        profile = await self.db.get(Profile, profile_id)
        if not profile:
            raise HTTPException(status_code=404, detail="Profile not found")

        if profile.is_default:
            raise HTTPException(status_code=400, detail="Cannot purge default profile")

        if not profile.is_deleted or profile.status == "active":
            raise HTTPException(status_code=409, detail="Profile must be soft-deleted before permanent purge")

        now = now_utc()
        pa = _as_utc(profile.purge_after)
        if not allow_unexpired and profile.status == "deleted":
            if pa is None or pa > now:
                raise HTTPException(status_code=409, detail="Profile retention has not expired")

        # Phase A: Pre-Validate All Attachment Paths Before State Transition
        att_rows = (await self.db.execute(
            select(Attachment.storage_path).where(Attachment.profile_id == profile_id)
        )).scalars().all()

        for sp in att_rows:
            # Raises SecurityException if tampered or escaping root
            resolve_and_verify_profile_attachment_path(sp, profile_id)

        # Phase B: Atomic Non-Restorable State Transition
        update_stmt = (
            update(Profile)
            .where(
                Profile.id == profile_id,
                Profile.is_default.is_(False),
                Profile.is_deleted.is_(True),
                Profile.status.in_(("deleted", "purging")),
            )
            .values(
                status="purging",
                purge_after=now if (pa is None or pa > now) else profile.purge_after,
                updated_at=now,
            )
        )
        res = await self.db.execute(update_stmt)
        if res.rowcount != 1:
            raise HTTPException(status_code=409, detail="Profile state conflict during purge initiation")

        await self.db.execute(
            update(ProfileSession)
            .where(ProfileSession.profile_id == profile_id, ProfileSession.revoked_at.is_(None))
            .values(revoked_at=now)
        )
        await self.db.execute(delete(SessionTicket).where(SessionTicket.profile_id == profile_id))
        await self.db.commit()

        # Phase C: Post-Transition Attachment Reconciliation
        reconciled_paths = (await self.db.execute(
            select(Attachment.storage_path).where(Attachment.profile_id == profile_id)
        )).scalars().all()

        # Phase D: Physical File Deletion & Dedicated Profile Directory Cleanup
        # 1. Unlink registered attachment files
        for sp in reconciled_paths:
            resolved_file = resolve_and_verify_profile_attachment_path(sp, profile_id)
            await asyncio.to_thread(resolved_file.unlink, missing_ok=True)

        # 2. Comprehensive sweep of dedicated Profile directory
        profile_root = (settings.ATTACHMENT_DIR / profile_id).resolve()
        attachment_root = settings.ATTACHMENT_DIR.resolve()

        if profile_root.exists() and profile_root.is_relative_to(attachment_root):
            # Inspect all files and subdirectories
            for candidate in list(profile_root.rglob("*")):
                if candidate.is_file() or candidate.is_symlink():
                    try:
                        resolved_cand = candidate.resolve()
                    except Exception:
                        resolved_cand = candidate
                    if not resolved_cand.is_relative_to(profile_root):
                        raise SecurityException(f"Symlink escapes profile root: {candidate}")
                    await asyncio.to_thread(candidate.unlink, missing_ok=True)

            # Clean empty directories bottom-up
            for sub_dir in sorted(list(profile_root.rglob("*")), key=lambda p: len(p.parts), reverse=True):
                if sub_dir.is_dir():
                    try:
                        sub_dir.rmdir()
                    except OSError:
                        pass
            try:
                profile_root.rmdir()
            except OSError:
                pass

        # Phase E: Atomic Relational Database Purge in Strict FK Order
        # 1. Break circular active character reference
        await self.db.execute(
            update(Profile)
            .where(Profile.id == profile_id)
            .values(active_character_instance_id=None)
        )
        # 2. Relational deletions
        await self.db.execute(delete(Attachment).where(Attachment.profile_id == profile_id))
        await self.db.execute(delete(Message).where(Message.profile_id == profile_id))
        await self.db.execute(delete(Conversation).where(Conversation.profile_id == profile_id))
        await self.db.execute(delete(CharacterInstance).where(CharacterInstance.profile_id == profile_id))
        await self.db.execute(delete(Memory).where(Memory.profile_id == profile_id))
        await self.db.execute(delete(Task).where(Task.profile_id == profile_id))
        await self.db.execute(delete(SessionTicket).where(SessionTicket.profile_id == profile_id))
        await self.db.execute(delete(ProfileSession).where(ProfileSession.profile_id == profile_id))
        await self.db.execute(
            delete(Profile).where(
                Profile.id == profile_id,
                Profile.is_default.is_(False),
                Profile.is_deleted.is_(True),
                Profile.status == "purging",
            )
        )
        await self.db.commit()
        return True

    async def execute_maintenance_purge(self) -> PurgeMaintenanceResult:
        """Perform a single maintenance sweep of expired and interrupted Profiles."""
        now = now_utc()
        stmt = select(Profile).where(
            Profile.is_deleted.is_(True),
            Profile.is_default.is_(False),
            Profile.status.in_(("deleted", "purging")),
        )
        all_deleted = list((await self.db.execute(stmt)).scalars().all())

        candidate_ids: list[str] = []
        for p in all_deleted:
            if p.status == "purging":
                candidate_ids.append(p.id)
            elif p.status == "deleted":
                pa = _as_utc(p.purge_after)
                if pa is not None and pa <= now:
                    candidate_ids.append(p.id)

        purged_ids: list[str] = []
        failed_ids: list[str] = []

        for pid in candidate_ids:
            try:
                await self.purge_profile(pid, allow_unexpired=True)
                purged_ids.append(pid)
            except Exception as exc:
                logger.error("Failed to purge profile '%s': %s", pid, exc, exc_info=True)
                failed_ids.append(pid)

        return PurgeMaintenanceResult(purged_profile_ids=purged_ids, failed_profile_ids=failed_ids)


async def run_periodic_profile_purge(
    db_or_session_factory,
    interval_seconds: float = 3600,
    *,
    loop_once_for_test: bool = False,
) -> PurgeMaintenanceResult:
    """Periodic maintenance background task.

    If loop_once_for_test is True, executes a single sweep on the supplied session and returns.
    Otherwise, runs indefinitely in a native asyncio.sleep loop inside the application lifespan.
    """
    if loop_once_for_test:
        if isinstance(db_or_session_factory, AsyncSession):
            service = ProfilePurgeService(db_or_session_factory)
            return await service.execute_maintenance_purge()
        async with db_or_session_factory() as session:
            service = ProfilePurgeService(session)
            return await service.execute_maintenance_purge()

    while True:
        try:
            await asyncio.sleep(interval_seconds)
            async with db_or_session_factory() as session:
                service = ProfilePurgeService(session)
                await service.execute_maintenance_purge()
        except asyncio.CancelledError:
            break
        except Exception as exc:
            logger.error("Error in periodic profile purge sweep: %s", exc, exc_info=True)
