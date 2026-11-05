"""Profile administration, catalog enumeration, and session-scoped metadata."""

import uuid
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db, require_host_admin
from app.core.profile_sessions import now_utc
from app.models.profile import Profile

router = APIRouter(prefix="/profiles", tags=["Profiles"])


class ProfileMetadata(BaseModel):
    id: str
    name: str
    is_default: bool
    status: str
    pin_protected: bool


class ProfileCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=64)


class ProfileUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=64)


def profile_metadata(profile: Profile) -> ProfileMetadata:
    return ProfileMetadata(
        id=profile.id,
        name=profile.name,
        is_default=profile.is_default,
        status=profile.status,
        pin_protected=profile.pin_hash is not None,
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
        Profile.is_deleted.is_(False),
        Profile.deleted_at.is_(None),
        Profile.status == "active",
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


@router.patch("/{profile_id}", response_model=ProfileMetadata, dependencies=[Depends(require_host_admin)])
async def profile_rename(profile_id: str, payload: ProfileUpdateRequest, db: AsyncSession = Depends(get_db)):
    profile = (await db.execute(select(Profile).where(
        Profile.id == profile_id,
        Profile.is_deleted.is_(False),
        Profile.deleted_at.is_(None),
        Profile.status == "active",
    ))).scalar_one_or_none()
    if profile is None:
        raise HTTPException(404, "Profile unavailable")
    name = await _validate_and_normalize_name(payload.name, db, exclude_profile_id=profile_id)
    profile.name = name
    profile.updated_at = now_utc()
    await db.commit()
    return profile_metadata(profile)


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
