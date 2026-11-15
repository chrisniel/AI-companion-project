"""Common response models and standardized error envelope definitions."""

from datetime import datetime, timezone
from typing import Any, Generic, Optional, TypeVar
from pydantic import BaseModel, ConfigDict, Field, model_validator

T = TypeVar("T")


class BaseSchema(BaseModel):
    """Base schema enforcing strict validation (OWASP API3: Mass Assignment guard)."""

    model_config = ConfigDict(
        extra="forbid",
        from_attributes=True,
    )

    @model_validator(mode="after")
    def _attach_utc_to_naive_datetimes(self) -> "BaseSchema":
        """Normalize SQLite-stripped naive datetimes back to explicit UTC for JSON serialization."""
        for field_name in type(self).model_fields:
            val = getattr(self, field_name, None)
            if isinstance(val, datetime) and val.tzinfo is None:
                setattr(self, field_name, val.replace(tzinfo=timezone.utc))
        return self


class ErrorDetail(BaseModel):
    """Standardized error structure returned on client and server failures."""

    code: str = Field(..., description="Machine-readable error classification code.")
    message: str = Field(..., description="Human-readable safe explanation.")
    details: Optional[Any] = Field(default=None, description="Field-level errors or diagnostic details.")
    request_id: Optional[str] = Field(default=None, description="Unique trace ID for host diagnostics.")


class ErrorEnvelope(BaseModel):
    """Top-level error response envelope."""

    error: ErrorDetail


class SuccessEnvelope(BaseModel, Generic[T]):
    """Top-level envelope for successful single-entity responses."""

    data: T
