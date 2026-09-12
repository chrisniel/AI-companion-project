"""Common FastAPI endpoint dependencies."""

from fastapi import Depends
from app.core.security import verify_token
from app.db.session import get_db

__all__ = ["get_db", "verify_token", "get_current_owner"]


async def get_current_owner(token: str = Depends(verify_token)) -> str:
    """Return the owner context for the authenticated session (defaults to local_user in V1)."""
    return "local_user"
