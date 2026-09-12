"""Schemas for pairing verification and authentication responses."""

from pydantic import Field
from app.schemas.common import BaseSchema


class AuthVerifyResponse(BaseSchema):
    """Result returned on token verification check."""

    authenticated: bool = Field(default=True, description="Indicates token passed constant-time verification.")
    token_type: str = Field(default="Bearer", description="Expected authorization scheme.")
    message: str = Field(default="Token is valid and authenticated.", description="Status confirmation message.")
