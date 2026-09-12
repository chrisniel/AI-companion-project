"""Security utilities and authentication verification dependencies."""

import hmac
from typing import Optional
from fastapi import Header, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import settings
from app.core.errors import CompanionSecurityError

bearer_security = HTTPBearer(auto_error=False)


def constant_time_compare(val1: str, val2: str) -> bool:
    """Compare two token strings in constant time to prevent timing attacks."""
    if not val1 or not val2:
        return False
    return hmac.compare_digest(val1.strip(), val2.strip())


async def verify_token(
    auth_header: Optional[HTTPAuthorizationCredentials] = Security(bearer_security),
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
) -> str:
    """
    Validate the incoming client token against the configured pairing key.
    Accepts either `Authorization: Bearer <token>` or `X-API-Key: <token>`.
    """
    expected_token = settings.COMPANION_API_KEY
    if not expected_token:
        # If no key configured, fallback to ensuring pairing token
        expected_token = settings.ensure_pairing_token()

    provided_token: Optional[str] = None
    if auth_header and auth_header.credentials:
        provided_token = auth_header.credentials
    elif x_api_key:
        provided_token = x_api_key

    if not provided_token:
        raise CompanionSecurityError(
            message="Authentication credentials required. Provide 'Authorization: Bearer <token>' or 'X-API-Key' header."
        )

    if not constant_time_compare(provided_token, expected_token):
        raise CompanionSecurityError(message="Invalid pairing token or API key.")

    return provided_token
