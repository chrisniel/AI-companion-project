"""Schemas for health checks and host system telemetry."""

from datetime import datetime
from typing import Optional
from pydantic import Field

from app.schemas.common import BaseSchema


class HealthResponse(BaseSchema):
    """Liveness and readiness status indicator."""

    status: str = Field(default="healthy", description="Overall system liveness status.")


class SystemStatusResponse(BaseSchema):
    """Host machine hardware profile and runtime status (protected)."""

    status: str = Field(default="online")
    platform: str = Field(..., description="Operating system identifier (e.g. Windows 11).")
    python_version: str = Field(..., description="Python interpreter version.")
    hostname: str = Field(..., description="Local machine hostname.")
    cpu_count: Optional[int] = Field(default=None, description="Logical CPU core count.")
    version: str = Field(..., description="Application version.")
    database_connected: bool = Field(..., description="Database connectivity flag.")
    timestamp: datetime = Field(..., description="UTC server timestamp.")
    shutting_down: bool = Field(default=False, description="Whether system shutdown has been initiated.")
    shutdown_phase: Optional[str] = Field(default=None, description="Current phase of shutdown sequence.")
    shutdown_quiescence_status: Optional[str] = Field(default=None, description="Quiescence barrier completion status.")
    managed_llm_pid: Optional[int] = Field(default=None, description="PID of Core-managed LLM router if active.")
    managed_by_core: bool = Field(default=False, description="Whether active LLM router is Core-managed.")


class SystemShutdownRequest(BaseSchema):
    """Parameters for cooperative system shutdown."""

    reason: str = Field(default="user_exit_companion", description="Reason for shutdown request.")
    drain_timeout_seconds: float = Field(default=6.0, description="Maximum duration to wait for persistence quiescence.")


class SystemShutdownResponse(BaseSchema):
    """Acknowledgement of accepted cooperative shutdown request."""

    status: str = Field(default="shutting_down", description="Status transition indicator.")
    pid: int = Field(..., description="Process ID of the shutting-down runtime.")
    managed_llm_pid: Optional[int] = Field(default=None, description="PID of managed child LLM router if running.")
    managed_by_core: bool = Field(default=False, description="Whether the child LLM router was spawned by Core.")
    already_shutting_down: bool = Field(default=False, description="Whether shutdown was already in progress.")
    shutdown_phase: Optional[str] = Field(default=None, description="Current phase of shutdown lifecycle.")
    message: str = Field(default="Cooperative shutdown initiated.", description="Informational message.")
