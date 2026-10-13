"""Explicit synthetic ownership for legacy test scenarios; no model hooks/defaults."""

from datetime import timedelta
import hashlib
import uuid

from sqlalchemy import select

from app.models.base import utc_now
from app.models.profile import Profile
from app.models.profile_session import ProfileSession


async def session_for_owner(db, owner="local_user"):
    """Persist a real test authority while preserving each scenario's owner partition."""
    if owner in ("local_user", "default_user"):
        profile_id = await db.scalar(select(Profile.id).where(Profile.is_default.is_(True)))
    else:
        profile_id = str(uuid.uuid5(uuid.NAMESPACE_URL, "synthetic-test-profile:" + owner))
        if await db.get(Profile, profile_id) is None:
            db.add(Profile(id=profile_id, name=owner[:32]))
            await db.flush()
    identifier = str(uuid.uuid5(uuid.NAMESPACE_URL, "synthetic-test-session:" + profile_id))
    session = await db.get(ProfileSession, identifier)
    if session is None:
        session = ProfileSession(
            id=identifier, profile_id=profile_id,
            token_hash=hashlib.sha256(identifier.encode()).hexdigest(), client_type="desktop",
            expires_at=utc_now() + timedelta(hours=1), last_active_at=utc_now(),
        )
        db.add(session)
        await db.flush()
    return session
