"""Authentication verification and token pairing validation endpoints."""

from fastapi import APIRouter, Depends
from app.api.deps import verify_token
from app.schemas.auth import AuthVerifyResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/verify",
    response_model=AuthVerifyResponse,
    summary="Verify Pairing Token",
    dependencies=[Depends(verify_token)],
)
async def verify_credentials() -> AuthVerifyResponse:
    """
    Test pairing credentials.
    Returns 200 with confirmation if the provided token matches the host secret.
    Returns 401 if missing, malformed, or mismatched.
    """
    return AuthVerifyResponse(
        authenticated=True,
        token_type="Bearer",
        message="Token successfully verified against Local AI Core.",
    )
