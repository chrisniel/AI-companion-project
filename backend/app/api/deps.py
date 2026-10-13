"""Common FastAPI endpoint dependencies."""

from fastapi import Depends, Header, Security
from app.core.security import verify_token
from app.db.session import get_db
from app.core.profile_sessions import get_current_profile_session
from app.core.host_admin import require_host_admin
from app.core.security import bearer_security
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

__all__ = ["get_db", "verify_token", "get_current_profile_session", "require_host_admin"]


async def get_current_owner(session=Depends(get_current_profile_session)) -> str:
    """Compatibility alias returns validated Profile identity, never a legacy owner."""
    return session.profile_id


async def verify_telemetry(
    auth_header: HTTPAuthorizationCredentials | None = Security(bearer_security),
    x_api_key: str | None = Header(None, alias="X-API-Key"),
    db: AsyncSession = Depends(get_db),
):
    if auth_header and auth_header.credentials.startswith("psk_"):
        return await get_current_profile_session(auth_header, db)
    return await verify_token(auth_header, x_api_key)
