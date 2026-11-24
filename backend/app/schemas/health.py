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


class ResourcePolicyStatusOut(BaseSchema):
    """Host resource governance and Auto Gaming Mode status telemetry (PC-RESOURCE-001..004)."""

    requested_mode: str = Field(..., description="Configured resource mode: normal, low_impact, or auto.")
    effective_mode: str = Field(..., description="Currently active runtime mode: normal or low_impact.")
    low_impact_active: bool = Field(..., description="True when Low-Impact governance overrides are active.")
    low_impact_strategy: str = Field(..., description="Low-Impact strategy: cpu_eco, unload_when_idle, or lightweight_model.")
    low_impact_model_id: Optional[str] = Field(default=None, description="Optional installed lightweight model override identifier.")
    game_process_list: List[str] = Field(..., description="Validated .exe process basenames monitored in Auto Gaming Mode.")
    detected_active_games: List[str] = Field(..., description="Monitored .exe basenames currently running on the host.")
    cooldown_seconds: int = Field(..., description="Configured hysteresis cooldown duration in seconds after watched games close.")
    cooldown_remaining_seconds: int = Field(..., description="Seconds remaining before exiting Auto Gaming Low-Impact cooldown.")
    transition_state: str = Field(..., description="Policy application transition state: idle, applying, deferred_active_turn, or deferred_model_load.")
    degradation_reason: Optional[str] = Field(default=None, description="Explicit reason when lightweight_model fell back to cpu_eco.")
    deferred_background_work: bool = Field(..., description="True when non-explicit memory extraction and background routines are deferred.")
    host_gpu_name: Optional[str] = Field(default=None, description="Live detected host GPU adapter name, or null when unavailable.")
    host_vram_gb: Optional[float] = Field(default=None, description="Live detected dedicated GPU VRAM in GiB, or null when unavailable.")
    host_ram_gb: Optional[float] = Field(default=None, description="Live detected total physical RAM in GiB, or null when unavailable.")
    available_ram_gb: Optional[float] = Field(default=None, description="Live detected available physical RAM in GiB, or null when unavailable.")
    applied_profile: Optional[str] = Field(default=None, description="Currently applied LLM hardware profile.")
    requested_profile: str = Field(..., description="Saved Normal hardware profile preference.")
    telemetry_source: str = Field(..., description="Live hardware telemetry source identifier or 'unavailable'.")


class ResourcePolicyUpdateRequest(BaseSchema):
    """Host-Admin request to update resource governance and Gaming Mode policy."""

    resource_mode: Optional[str] = Field(default=None, description="Target mode: normal, low_impact, or auto.")
    low_impact_strategy: Optional[str] = Field(default=None, description="Strategy: cpu_eco, unload_when_idle, or lightweight_model.")
    low_impact_model_id: Optional[str] = Field(default=None, description="Lightweight GGUF model identifier.")
    clear_low_impact_model: bool = Field(default=False, description="Clear any saved lightweight model override.")
    game_process_list: Optional[List[str]] = Field(default=None, description="Replacement .exe watchlist (max 64 unique basenames).")
    cooldown_seconds: Optional[int] = Field(default=None, ge=5, le=300, description="Hysteresis cooldown duration (5..300s).")
