"""Schemas for health checks and host system telemetry."""

from datetime import datetime
from typing import Optional
from pydantic import Field

from app.schemas.common import BaseSchema


class HealthResponse(BaseSchema):
    """Liveness and dependency connectivity status."""

    status: str = Field(default="healthy", description="Overall system health status.")
    version: str = Field(..., description="Application version.")
    database_connected: bool = Field(..., description="SQLite database read/write connectivity flag.")
    timestamp: datetime = Field(..., description="UTC server timestamp.")


class SystemStatusResponse(BaseSchema):
    """Host machine hardware profile and runtime status."""

    status: str = Field(default="online")
    platform: str = Field(..., description="Operating system identifier (e.g. Windows 11).")
    python_version: str = Field(..., description="Python interpreter version.")
    hostname: str = Field(..., description="Local machine hostname.")
    cpu_count: Optional[int] = Field(default=None, description="Logical CPU core count.")
    timestamp: datetime = Field(..., description="UTC server timestamp.")
