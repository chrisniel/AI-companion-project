"""Schemas for health checks and host system telemetry."""

from datetime import datetime
from typing import List, Optional
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


class StorageRootOut(BaseSchema):
    """Live telemetry descriptor for one of the five canonical host storage roots."""

    key: str = Field(..., description="Canonical root identifier: app_install, data, library, cache, or log.")
    label: str = Field(..., description="Human-readable label for Settings UI.")
    path: str = Field(..., description="Resolved absolute filesystem path.")
    exists: bool = Field(..., description="Whether the directory currently exists on disk.")
    free_bytes: Optional[int] = Field(default=None, description="Free space in bytes on the backing volume.")
    total_bytes: Optional[int] = Field(default=None, description="Total volume capacity in bytes.")
    source: str = Field(..., description="Precedence source: 'env', 'bootstrap', or 'default'.")


class StorageRootsResponse(BaseSchema):
    """Host-Admin storage root telemetry across all five canonical roots (PC-HOST-004)."""

    bootstrap_path: str = Field(..., description="Path to bootstrap.json locator file.")
    library_root: str = Field(..., description="Active canonical LIBRARY_ROOT path.")
    import_inbox_dir: str = Field(..., description="Active D6 manual model import inbox folder.")
    library_relocatable: bool = Field(default=True, description="Whether LIBRARY_ROOT can currently be relocated.")
    relocation_blocked_reason: Optional[str] = Field(
        default=None,
        description="Explanation when library relocation is temporarily unavailable.",
    )
    roots: List[StorageRootOut] = Field(..., description="All five canonical storage roots.")


class LibraryRootUpdateRequest(BaseSchema):
    """Request payload to relocate LIBRARY_ROOT atomically in bootstrap.json."""

    new_library_root: str = Field(..., min_length=1, description="New absolute path for LIBRARY_ROOT.")
    migrate_existing_assets: bool = Field(
        default=True,
        description="Copy existing models, registry, voices, and inbox files into the new LIBRARY_ROOT.",
    )


class AutostartStatusOut(BaseSchema):
    """Windows Task Scheduler login autostart status (PC-HOST-002)."""

    supported: bool = Field(..., description="True when running on supported Windows host platform.")
    enabled: bool = Field(..., description="Whether login autostart is currently enabled/registered.")
    task_registered: bool = Field(..., description="Live Windows Task Scheduler registration verification flag.")
    task_name: str = Field(..., description="Canonical Windows Task Scheduler task name.")
    minimized_to_tray: bool = Field(default=True, description="Whether autostart launches silently to system tray.")
    command: Optional[str] = Field(default=None, description="Registered executable command and arguments.")
    working_directory: Optional[str] = Field(default=None, description="Registered task working directory.")
    status_detail: str = Field(..., description="Human-readable registration or platform status detail.")


class AutostartUpdateRequest(BaseSchema):
    """Request to enable or disable standard-user Windows login autostart."""

    enabled: bool = Field(..., description="Enable or disable Task Scheduler login autostart.")
    minimized_to_tray: bool = Field(
        default=True,
        description="Launch minimized to system tray without initial window flash.",
    )
