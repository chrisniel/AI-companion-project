"""Common FastAPI endpoint dependencies."""

from typing import AsyncGenerator
from fastapi import Depends, Header, HTTPException, Request, Security
from app.core.security import verify_token
from app.db.session import get_db
from app.core.profile_sessions import get_current_profile_session
from app.core.host_admin import require_host_admin
from app.core.security import bearer_security
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

__all__ = ["get_db", "verify_token", "get_current_profile_session", "require_host_admin", "verify_telemetry"]


async def get_current_owner(session=Depends(get_current_profile_session)) -> str:
    """Compatibility alias returns validated Profile identity, never a legacy owner."""
    return session.profile_id


async def get_telemetry_db(request: Request) -> AsyncGenerator[AsyncSession | None, None]:
    """Yield DB session if database is available, respecting FastAPI dependency overrides."""
    import inspect
    if get_db in request.app.dependency_overrides:
        override = request.app.dependency_overrides[get_db]
        if inspect.isasyncgenfunction(override):
            async for s in override():
                yield s
                return
        elif inspect.isgeneratorfunction(override):
            for s in override():
                yield s
                return
        else:
            res = override()
            if inspect.isasyncgen(res):
                async for s in res:
                    yield s
                    return
            elif inspect.isgenerator(res):
                for s in res:
                    yield s
                    return
            else:
                yield res
                return

    try:
        from app.db.session import get_session_factory
        factory = get_session_factory()
    except RuntimeError:
        yield None
        return

    async with factory() as session:
        try:
            yield session
            if session.is_active and session.in_transaction():
                await session.commit()
        except Exception:
            if session.is_active and session.in_transaction():
                await session.rollback()
            raise


async def verify_telemetry(
    request: Request,
    auth_header: HTTPAuthorizationCredentials | None = Security(bearer_security),
    x_api_key: str | None = Header(None, alias="X-API-Key"),
    db: AsyncSession | None = Depends(get_telemetry_db),
):
    if auth_header and auth_header.credentials.startswith("psk_"):
        import inspect
        if get_current_profile_session in request.app.dependency_overrides:
            override = request.app.dependency_overrides[get_current_profile_session]
            res = override()
            if inspect.iscoroutine(res):
                return await res
            return res
        if db is None:
            raise HTTPException(
                status_code=503,
                detail={"error": {"code": "DATABASE_UNAVAILABLE", "message": "Database is unavailable during shutdown"}},
            )
        return await get_current_profile_session(auth_header, db)
    return await verify_token(auth_header, x_api_key)
