"""Standard error responses and custom exception classes."""

from typing import Any, Optional
from fastapi import Request
from fastapi.responses import JSONResponse


class CompanionAppError(Exception):
    """Base exception for all domain and application errors."""

    def __init__(
        self,
        message: str,
        code: str = "INTERNAL_SERVER_ERROR",
        status_code: int = 500,
        details: Optional[Any] = None,
    ):
        super().__init__(message)
        self.message = message
        self.code = code
        self.status_code = status_code
        self.details = details


class CompanionSecurityError(CompanionAppError):
    """Authentication or token verification failure."""

    def __init__(self, message: str = "Invalid or missing pairing credentials.", details: Optional[Any] = None):
        super().__init__(
            message=message,
            code="AUTHENTICATION_REQUIRED",
            status_code=401,
            details=details,
        )


class CompanionPermissionError(CompanionAppError):
    """Access denied for the requested resource."""

    def __init__(self, message: str = "You do not have permission to perform this action.", details: Optional[Any] = None):
        super().__init__(
            message=message,
            code="PERMISSION_DENIED",
            status_code=403,
            details=details,
        )


class CompanionNotFoundError(CompanionAppError):
    """Requested entity was not found."""

    def __init__(self, message: str = "Resource not found.", details: Optional[Any] = None):
        super().__init__(
            message=message,
            code="RESOURCE_NOT_FOUND",
            status_code=404,
            details=details,
        )


class CompanionConflictError(CompanionAppError):
    """Business rule or state conflict."""

    def __init__(self, message: str = "Resource state conflict.", details: Optional[Any] = None):
        super().__init__(
            message=message,
            code="STATE_CONFLICT",
            status_code=409,
            details=details,
        )


class CompanionPayloadTooLargeError(CompanionAppError):
    """Request payload or stream exceeds maximum size."""

    def __init__(self, message: str = "Request payload exceeds maximum allowed size.", details: Optional[Any] = None):
        super().__init__(
            message=message,
            code="PAYLOAD_TOO_LARGE",
            status_code=413,
            details=details,
        )


def format_error_response(
    code: str,
    message: str,
    details: Optional[Any] = None,
    request_id: Optional[str] = None,
    status_code: int = 400,
) -> JSONResponse:
    """Format a consistent JSON error envelope adhering to OWASP & Error Handling standards."""
    return JSONResponse(
        status_code=status_code,
        content={
            "error": {
                "code": code,
                "message": message,
                "details": details,
                "request_id": request_id,
            }
        },
    )
