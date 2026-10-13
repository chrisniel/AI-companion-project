"""Hashed Profile Sessions and fresh lifecycle checks at every authority boundary."""

import asyncio
from contextlib import suppress
from datetime import datetime, timedelta, timezone
import hashlib
import secrets

from fastapi import Depends, HTTPException, Security
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import inspect, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm.attributes import set_committed_value

from app.core.security import bearer_security
from app.db.session import get_db
from app.models.profile import Profile
from app.models.profile_session import ProfileSession


def token_hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


async def validate_profile_session(db: AsyncSession, session: ProfileSession) -> ProfileSession:
    if not isinstance(session, ProfileSession):
        raise HTTPException(401, "Profile Session required")
    state = inspect(session)
    session_id = state.identity[0] if state.identity else session.__dict__.get("id")
    original_profile_id = state.info.get("authenticated_profile_id", session.__dict__.get("profile_id"))
    if not session_id or not original_profile_id:
        raise HTTPException(401, "Profile Session required")
    # Select columns rather than a cached ORM entity: revocation/expiry must be fresh.
    with db.no_autoflush:
        record = (await db.execute(select(ProfileSession.profile_id, ProfileSession.expires_at,
                                         ProfileSession.revoked_at, Profile.status, Profile.is_deleted, Profile.deleted_at)
                                  .join(Profile, Profile.id == ProfileSession.profile_id)
                                  .where(ProfileSession.id == session_id))).first()
    if record is None:
        raise HTTPException(401, "Inactive Profile Session")
    profile_id, expiry, revoked, state, deleted, deleted_at = record
    expiry = expiry.replace(tzinfo=timezone.utc) if expiry.tzinfo is None else expiry
    if profile_id != original_profile_id or revoked is not None or expiry <= now_utc() or state != "active" or deleted or deleted_at is not None:
        raise HTTPException(401, "Inactive Profile Session")
    inspect(session).info["authenticated_profile_id"] = profile_id
    # Restore only identity fields freshly verified above; the context can belong
    # to a request session while cleanup validates using an isolated DB session.
    set_committed_value(session, "id", session_id)
    set_committed_value(session, "profile_id", profile_id)
    return session


async def get_current_profile_session(
    auth_header: HTTPAuthorizationCredentials | None = Security(bearer_security),
    db: AsyncSession = Depends(get_db),
) -> ProfileSession:
    token = auth_header.credentials if auth_header else ""
    if not token.startswith("psk_") or len(token) > 256:
        raise HTTPException(401, "Profile Session required")
    session = (await db.execute(select(ProfileSession).where(ProfileSession.token_hash == token_hash(token)))).scalar_one_or_none()
    if session is None:
        raise HTTPException(401, "Invalid Profile Session")
    return await validate_profile_session(db, session)


def new_profile_session(profile_id: str, client_type: str) -> tuple[str, ProfileSession]:
    token = "psk_" + secrets.token_urlsafe(48)
    now = now_utc()
    session = ProfileSession(profile_id=profile_id, token_hash=token_hash(token), client_type=client_type,
                             created_at=now, last_active_at=now, expires_at=now + timedelta(hours=12))
    return token, session


async def guarded_tokens(stream, db: AsyncSession, session: ProfileSession):
    """Check authorization even while a provider is idle, closing outstanding work."""
    pending = None
    try:
        while True:
            await validate_profile_session(db, session)
            pending = asyncio.create_task(anext(stream))
            while True:
                done, _ = await asyncio.wait({pending}, timeout=0.25)
                await validate_profile_session(db, session)
                if done:
                    break
            try:
                value = pending.result()
            except StopAsyncIteration:
                break
            pending = None
            yield value
    finally:
        if pending is not None and not pending.done():
            pending.cancel()
            with suppress(asyncio.CancelledError, StopAsyncIteration):
                await pending
        await stream.aclose()
