"""Read-only private Profile catalog and session-scoped metadata."""

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db, require_host_admin
from app.models.profile import Profile

router = APIRouter(prefix="/profiles", tags=["Profiles"])


class ProfileMetadata(BaseModel):
    id: str
    name: str
    is_default: bool
    status: str
    pin_protected: bool


def profile_metadata(profile: Profile) -> ProfileMetadata:
    return ProfileMetadata(id=profile.id, name=profile.name, is_default=profile.is_default,
                           status=profile.status, pin_protected=profile.pin_hash is not None)


@router.get("", response_model=list[ProfileMetadata], dependencies=[Depends(require_host_admin)])
async def profile_catalog(db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(Profile).where(Profile.is_deleted.is_(False), Profile.deleted_at.is_(None), Profile.status == "active"))).scalars().all()
    return [profile_metadata(row) for row in rows]


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
