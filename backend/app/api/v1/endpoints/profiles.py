"""Profile administration, catalog enumeration, and session-scoped metadata."""

from datetime import datetime
from typing import Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db, require_host_admin
from app.core.profile_sessions import now_utc, validate_profile_session
from app.models.profile import Profile
from app.models.profile_session import ProfileSession
from app.schemas.scheduling import QuietHoursOut, QuietHoursUpdate
from app.services.profile_purge_service import ProfilePurgeService

router = APIRouter(prefix="/profiles", tags=["Profiles"])


class ProfileMetadata(BaseModel):
    id: str
    name: str
    is_default: bool
    status: str
    pin_protected: bool
    is_deleted: bool = False
    deleted_at: Optional[datetime] = None
    purge_after: Optional[datetime] = None
    memory_extraction_enabled: bool = True


class ProfileCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=64)


class ProfileUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: Optional[str] = Field(default=None, min_length=1, max_length=64)
    memory_extraction_enabled: Optional[bool] = None


def profile_metadata(profile: Profile) -> ProfileMetadata:
    return ProfileMetadata(
        id=profile.id,
        name=profile.name,
        is_default=profile.is_default,
        status=profile.status,
        pin_protected=profile.pin_hash is not None,
        is_deleted=profile.is_deleted,
        deleted_at=profile.deleted_at,
        purge_after=profile.purge_after,
        memory_extraction_enabled=getattr(profile, "memory_extraction_enabled", True),
    )


async def _validate_and_normalize_name(
    raw_name: str,
    db: AsyncSession,
    exclude_profile_id: str | None = None,
) -> str:
    normalized = raw_name.strip()
    if len(normalized) < 1 or len(normalized) > 32:
        raise HTTPException(
            status_code=422,
            detail="Profile name must be between 1 and 32 characters",
        )
    if any(ord(ch) < 32 or ord(ch) == 127 for ch in normalized):
        raise HTTPException(
            status_code=422,
            detail="Profile name cannot contain control characters",
        )
    stmt = select(Profile.id).where(
        func.lower(Profile.name) == normalized.lower(),
        Profile.status.in_(("active", "deleted")),
    )
    if exclude_profile_id is not None:
        stmt = stmt.where(Profile.id != exclude_profile_id)
    existing = (await db.execute(stmt)).first()
    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail="A Profile with this name already exists",
        )
    return normalized


@router.get("", response_model=list[ProfileMetadata], dependencies=[Depends(require_host_admin)])
async def profile_catalog(db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(
        select(Profile)
        .where(Profile.is_deleted.is_(False), Profile.deleted_at.is_(None), Profile.status == "active")
        .order_by(Profile.is_default.desc(), Profile.created_at.asc(), Profile.id.asc())
    )).scalars().all()
    return [profile_metadata(row) for row in rows]


@router.get("/deleted", response_model=list[ProfileMetadata], dependencies=[Depends(require_host_admin)])
async def profile_deleted_catalog(db: AsyncSession = Depends(get_db)):
    service = ProfilePurgeService(db)
    rows = await service.list_deleted_profiles()
    return [profile_metadata(row) for row in rows]


@router.post("", response_model=ProfileMetadata, status_code=201, dependencies=[Depends(require_host_admin)])
async def profile_create(payload: ProfileCreateRequest, db: AsyncSession = Depends(get_db)):
    name = await _validate_and_normalize_name(payload.name, db)
    default_exists = (await db.execute(select(Profile.id).where(Profile.is_default.is_(True)))).scalar_one_or_none() is not None
    profile = Profile(
        id=str(uuid.uuid4()),
        name=name,
        pin_hash=None,
        is_default=not default_exists,
        status="active",
    )
    db.add(profile)
    await db.commit()
    await db.refresh(profile)
    return profile_metadata(profile)


@router.get("/me/quiet-hours", response_model=QuietHoursOut, summary="Get Active Profile Quiet Hours")
async def get_own_quiet_hours(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> QuietHoursOut:
    profile = (
        await db.execute(
            select(Profile).where(
                Profile.id == session.profile_id,
                Profile.is_deleted.is_(False),
                Profile.deleted_at.is_(None),
                Profile.status == "active",
            )
        )
    ).scalar_one_or_none()
    if profile is None:
        raise HTTPException(404, "Profile unavailable")
    return QuietHoursOut(
        quiet_hours_enabled=profile.quiet_hours_enabled,
        quiet_hours_start=profile.quiet_hours_start,
        quiet_hours_end=profile.quiet_hours_end,
        quiet_hours_timezone=profile.quiet_hours_timezone,
    )


@router.patch("/me/quiet-hours", response_model=QuietHoursOut, summary="Update Active Profile Quiet Hours")
async def update_own_quiet_hours(
    payload: QuietHoursUpdate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> QuietHoursOut:
    profile = (
        await db.execute(
            select(Profile).where(
                Profile.id == session.profile_id,
                Profile.is_deleted.is_(False),
                Profile.deleted_at.is_(None),
                Profile.status == "active",
            )
        )
    ).scalar_one_or_none()
    if profile is None:
        raise HTTPException(404, "Profile unavailable")

    new_enabled = payload.quiet_hours_enabled if payload.quiet_hours_enabled is not None else profile.quiet_hours_enabled
    new_start = payload.quiet_hours_start if payload.quiet_hours_start is not None else profile.quiet_hours_start
    new_end = payload.quiet_hours_end if payload.quiet_hours_end is not None else profile.quiet_hours_end
    new_tz = payload.quiet_hours_timezone if payload.quiet_hours_timezone is not None else profile.quiet_hours_timezone

    if new_enabled and new_start == new_end:
        raise HTTPException(
            status_code=422,
            detail="quiet_hours_start and quiet_hours_end cannot be identical when quiet hours are enabled",
        )

    profile.quiet_hours_enabled = new_enabled
    profile.quiet_hours_start = new_start
    profile.quiet_hours_end = new_end
    profile.quiet_hours_timezone = new_tz
    profile.updated_at = now_utc()
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(profile)
    return QuietHoursOut(
        quiet_hours_enabled=profile.quiet_hours_enabled,
        quiet_hours_start=profile.quiet_hours_start,
        quiet_hours_end=profile.quiet_hours_end,
        quiet_hours_timezone=profile.quiet_hours_timezone,
    )


@router.patch("/{profile_id}", response_model=ProfileMetadata, dependencies=[Depends(require_host_admin)])
async def profile_rename(
    profile_id: str,
    payload: ProfileUpdateRequest,
    db: AsyncSession = Depends(get_db),
):
    profile = (await db.execute(select(Profile).where(
        Profile.id == profile_id,
        Profile.is_deleted.is_(False),
        Profile.deleted_at.is_(None),
        Profile.status == "active",
    ))).scalar_one_or_none()
    if profile is None:
        raise HTTPException(404, "Profile unavailable")
    if payload.name is not None:
        name = await _validate_and_normalize_name(payload.name, db, exclude_profile_id=profile_id)
        profile.name = name
    if payload.memory_extraction_enabled is not None:
        profile.memory_extraction_enabled = payload.memory_extraction_enabled
    profile.updated_at = now_utc()
    await db.commit()
    return profile_metadata(profile)


@router.delete("/{profile_id}", response_model=ProfileMetadata, dependencies=[Depends(require_host_admin)])
async def profile_delete(profile_id: str, db: AsyncSession = Depends(get_db)):
    service = ProfilePurgeService(db)
    profile = await service.soft_delete_profile(profile_id)
    return profile_metadata(profile)


@router.post("/{profile_id}/restore", response_model=ProfileMetadata, dependencies=[Depends(require_host_admin)])
async def profile_restore(profile_id: str, db: AsyncSession = Depends(get_db)):
    service = ProfilePurgeService(db)
    profile = await service.restore_profile(profile_id)
    return profile_metadata(profile)


@router.post("/{profile_id}/purge", dependencies=[Depends(require_host_admin)])
async def profile_purge(profile_id: str, db: AsyncSession = Depends(get_db)):
    service = ProfilePurgeService(db)
    await service.purge_profile(profile_id, allow_unexpired=True)
    return {"status": "purged", "profile_id": profile_id}


@router.get("/{profile_id}", response_model=ProfileMetadata)
async def profile_lookup(profile_id: str, request: Request, db: AsyncSession = Depends(get_db)):
    if request.headers.get("x-host-admin-secret") is not None:
        await require_host_admin(request, request.headers["x-host-admin-secret"])
    else:
        from app.core.security import bearer_security
        credentials = await bearer_security(request)
        session = await get_current_profile_session(credentials, db)
        if session.profile_id != profile_id:
            raise HTTPException(404, "Profile unavailable")
    profile = (await db.execute(select(Profile).where(Profile.id == profile_id, Profile.is_deleted.is_(False), Profile.deleted_at.is_(None),
                                Profile.status == "active"))).scalar_one_or_none()
    if profile is None:
        raise HTTPException(404, "Profile unavailable")
    return profile_metadata(profile)
