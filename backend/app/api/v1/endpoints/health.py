"""Health checks and host machine telemetry endpoints."""

import asyncio
import inspect
import json
import os
import platform
import shutil
import socket
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, verify_token
from app.core.config import settings
from app.core.host_admin import require_host_admin
from app.core.runtime_lifecycle import runtime_lifecycle
from app.core.storage import (
    BootstrapCorruptError,
    RelocationConflictError,
    StorageError,
    get_bootstrap_path,
    relocate_library_root,
)
from app.schemas.health import (
    AutostartStatusOut,
    AutostartUpdateRequest,
    HealthResponse,
    LibraryRootUpdateRequest,
    ResourcePolicyStatusOut,
    ResourcePolicyUpdateRequest,
    StorageRootOut,
    StorageRootsResponse,
    SystemShutdownRequest,
    SystemShutdownResponse,
    SystemStatusResponse,
)
from app.services.autostart import AutostartConfigurationError, WindowsAutostartService
from app.services.profile_purge_service import (
    ProfilePurgeService,
    PurgeMaintenanceResult,
)
from app.services.resource_governor import resource_governor

public_health_router = APIRouter(tags=["Health"])
system_router = APIRouter(tags=["System Status"])
router = public_health_router  # Backwards compatibility


@public_health_router.get("/health", response_model=HealthResponse, summary="Public Health Check")
async def health_check() -> HealthResponse | JSONResponse:
    """
    Public liveness and readiness probe.
    Android uses this to detect if the Windows host PC is online on the local network.
    Returns 503 when the runtime is shutting down.
    """
    if runtime_lifecycle.is_shutting_down:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "shutting_down"},
        )
    return HealthResponse(status="healthy")


@system_router.get(
    "/system/status",
    response_model=SystemStatusResponse,
    summary="Host System Status (Protected)",
)
async def system_status() -> SystemStatusResponse:
    """
    Detailed Windows host machine telemetry and database diagnostics.
    Requires valid pairing token or host admin secret.
    Does not query database during runtime shutdown to prevent races with database disposal.
    """
    db_connected = False
    if not runtime_lifecycle.is_shutting_down:
        try:
            from app.db.session import _session_factory
            if _session_factory is not None:
                async with _session_factory() as session:
                    await session.execute(text("SELECT 1"))
                    db_connected = True
        except Exception:
            db_connected = False

    return SystemStatusResponse(
        status="online" if db_connected else "degraded",
        platform=f"{platform.system()} {platform.release()}",
        python_version=platform.python_version(),
        hostname=socket.gethostname(),
        cpu_count=os.cpu_count(),
        version=settings.VERSION,
        database_connected=db_connected,
        timestamp=datetime.now(timezone.utc),
        shutting_down=runtime_lifecycle.is_shutting_down,
        shutdown_phase=runtime_lifecycle.shutdown_phase,
        shutdown_quiescence_status=runtime_lifecycle.shutdown_quiescence_status,
        managed_llm_pid=runtime_lifecycle.managed_llm_pid,
        managed_by_core=runtime_lifecycle.managed_by_core,
    )


@system_router.post(
    "/system/shutdown",
    response_model=SystemShutdownResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Request Cooperative System Shutdown",
)
async def system_shutdown(
    request: Optional[SystemShutdownRequest] = None,
    _: str = Depends(require_host_admin),
) -> SystemShutdownResponse:
    """
    Cooperative local runtime termination endpoint (Host Admin only).
    """
    reason = request.reason if request else "user_exit_companion"
    drain_timeout = request.drain_timeout_seconds if request else 6.0
    already_shutting_down, msg = await runtime_lifecycle.initiate_shutdown(
        reason=reason,
        drain_timeout_seconds=drain_timeout,
    )
    return SystemShutdownResponse(
        status="shutting_down",
        pid=os.getpid(),
        managed_llm_pid=runtime_lifecycle.managed_llm_pid,
        managed_by_core=runtime_lifecycle.managed_by_core,
        already_shutting_down=already_shutting_down,
        shutdown_phase=runtime_lifecycle.shutdown_phase,
        message=f"Cooperative shutdown {'resumed' if msg == 'shutdown_retried' else ('already in progress' if already_shutting_down else 'initiated')}.",
    )


@system_router.post(
    "/system/maintenance/purge-profiles",
    response_model=PurgeMaintenanceResult,
    summary="Trigger Profile Purge Maintenance",
)
async def system_purge_profiles(
    db: AsyncSession = Depends(get_db),
    _: str = Depends(require_host_admin),
) -> PurgeMaintenanceResult:
    """Trigger an immediate maintenance purge of expired and interrupted Profiles (Host Admin only)."""
    service = ProfilePurgeService(db)
    return await service.execute_maintenance_purge()


def _probe_disk_usage(path: Path) -> tuple[Optional[int], Optional[int]]:
    """Probe disk usage from the nearest existing ancestor without mutating the filesystem."""
    candidate = path
    while not candidate.exists() and candidate.parent != candidate:
        candidate = candidate.parent
    if not candidate.exists():
        return None, None
    try:
        usage = shutil.disk_usage(candidate)
        return int(usage.free), int(usage.total)
    except OSError:
        return None, None


def _build_storage_roots_response() -> StorageRootsResponse:
    from app.services.llm.manager import llm_manager

    b_path = get_bootstrap_path()
    paths = settings.canonical_paths
    bootstrap_keys: dict[str, object] = {}
    if b_path.is_file():
        try:
            loaded = json.loads(b_path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                bootstrap_keys = loaded
        except Exception:
            bootstrap_keys = {}

    data_source = (
        "env"
        if os.environ.get("COMPANION_DATA_ROOT", "").strip()
        else ("bootstrap" if "data_root" in bootstrap_keys else "default")
    )
    lib_source = (
        "env"
        if (os.environ.get("COMPANION_LIBRARY_ROOT", "").strip() or (settings.COMPANION_LIBRARY_ROOT or "").strip())
        else ("bootstrap" if "library_root" in bootstrap_keys else "default")
    )
    install_source = (
        "env"
        if (os.environ.get("COMPANION_APP_INSTALL_ROOT", "").strip() or (settings.COMPANION_APP_INSTALL_ROOT or "").strip())
        else "default"
    )
    cache_source = (
        "env"
        if (os.environ.get("COMPANION_CACHE_ROOT", "").strip() or (settings.COMPANION_CACHE_ROOT or "").strip())
        else "default"
    )
    log_source = (
        "env"
        if (os.environ.get("COMPANION_LOG_ROOT", "").strip() or (settings.COMPANION_LOG_ROOT or "").strip())
        else "default"
    )

    blocked_reason: Optional[str] = None
    if os.environ.get("COMPANION_LIBRARY_ROOT", "").strip() or (settings.COMPANION_LIBRARY_ROOT or "").strip():
        blocked_reason = "COMPANION_LIBRARY_ROOT environment override is active."
    elif os.environ.get("COMPANION_DATA_ROOT", "").strip():
        blocked_reason = "COMPANION_DATA_ROOT environment override redirects storage."
    else:
        provider = llm_manager._provider
        if provider is not None and (provider.is_loaded() or getattr(provider, "has_active_generation", False)):
            blocked_reason = "Unload active LLM model before relocating LIBRARY_ROOT."

    definitions = [
        ("app_install", "Application Install Root", paths.APP_INSTALL_ROOT, install_source),
        ("data", "Persistent Data Root (DB & Profiles)", paths.COMPANION_DATA_ROOT, data_source),
        ("library", "Asset & Model Library Root", paths.LIBRARY_DIR, lib_source),
        ("cache", "Disposable Cache Root", paths.CACHE_ROOT, cache_source),
        ("log", "Diagnostics & Logs Root", paths.LOG_ROOT, log_source),
    ]
    roots: list[StorageRootOut] = []
    for key, label, root_path, source in definitions:
        free_b, total_b = _probe_disk_usage(root_path)
        roots.append(
            StorageRootOut(
                key=key,
                label=label,
                path=str(root_path),
                exists=root_path.exists(),
                free_bytes=free_b,
                total_bytes=total_b,
                source=source,
            )
        )

    return StorageRootsResponse(
        bootstrap_path=str(b_path),
        library_root=str(paths.LIBRARY_DIR),
        import_inbox_dir=str(paths.IMPORT_INBOX_DIR),
        library_relocatable=blocked_reason is None,
        relocation_blocked_reason=blocked_reason,
        roots=roots,
    )


@system_router.get(
    "/system/storage",
    response_model=StorageRootsResponse,
    summary="Inspect Five Canonical Storage Roots (Host Admin)",
)
async def get_system_storage(
    _: str = Depends(require_host_admin),
) -> StorageRootsResponse:
    """Return resolved paths and disk telemetry for all five canonical storage roots."""
    return _build_storage_roots_response()


@system_router.put(
    "/system/storage/library-root",
    response_model=StorageRootsResponse,
    summary="Relocate LIBRARY_ROOT Atomically (Host Admin)",
)
async def relocate_system_library_root(
    request: LibraryRootUpdateRequest,
    _: str = Depends(require_host_admin),
) -> StorageRootsResponse:
    """Validate and relocate LIBRARY_ROOT in bootstrap.json while no LLM model is loaded."""
    from app.services.llm.manager import llm_manager

    if (settings.COMPANION_LIBRARY_ROOT or "").strip():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot relocate LIBRARY_ROOT while COMPANION_LIBRARY_ROOT is configured.",
        )

    provider = llm_manager._provider
    if provider is not None:
        if provider.is_loaded() or getattr(provider, "has_active_generation", False):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Unload active LLM model before relocating LIBRARY_ROOT.",
            )
        unload_fn = getattr(provider, "stop_managed_router_if_idle", None)
        if inspect.iscoroutinefunction(unload_fn):
            stopped = await unload_fn()
            if not stopped:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Failed to stop idle LLM router before relocating LIBRARY_ROOT.",
                )
        else:
            fallback_unload = getattr(provider, "unload_model", None) or getattr(provider, "unload", None)
            if inspect.iscoroutinefunction(fallback_unload):
                await fallback_unload()

    try:
        await asyncio.to_thread(
            relocate_library_root,
            new_library_root=Path(request.new_library_root.strip()),
            migrate_existing_assets=request.migrate_existing_assets,
        )
    except RelocationConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from None
    except (StorageError, BootstrapCorruptError, OSError, ValueError) as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None

    return _build_storage_roots_response()


@system_router.get(
    "/system/autostart",
    response_model=AutostartStatusOut,
    summary="Inspect Windows Task Scheduler Login Autostart Status (Host Admin)",
)
async def get_system_autostart(
    _: str = Depends(require_host_admin),
) -> AutostartStatusOut:
    """Query standard-user Windows Task Scheduler login autostart status."""
    return WindowsAutostartService().get_status()


@system_router.put(
    "/system/autostart",
    response_model=AutostartStatusOut,
    summary="Enable or Disable Windows Login Autostart (Host Admin)",
)
async def update_system_autostart(
    request: AutostartUpdateRequest,
    _: str = Depends(require_host_admin),
) -> AutostartStatusOut:
    """Register or remove standard-user Windows Task Scheduler login autostart."""
    try:
        return WindowsAutostartService().set_enabled(
            request.enabled,
            minimized_to_tray=request.minimized_to_tray,
        )
    except AutostartConfigurationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None


@system_router.get(
    "/system/resources",
    response_model=ResourcePolicyStatusOut,
    summary="Inspect Host Resource Governance & Auto Gaming Status (Host Admin)",
)
async def get_system_resources(
    _: str = Depends(require_host_admin),
) -> ResourcePolicyStatusOut:
    """Return live host resource governance mode, gaming detection, and truthful OS capacity."""
    return await resource_governor.get_status()


@system_router.put(
    "/system/resources",
    response_model=ResourcePolicyStatusOut,
    summary="Update Host Resource Governance & Auto Gaming Policy (Host Admin)",
)
async def update_system_resources(
    request: ResourcePolicyUpdateRequest,
    _: str = Depends(require_host_admin),
) -> ResourcePolicyStatusOut:
    """Persist validated resource governance settings and apply immediately without blocking."""
    try:
        return await resource_governor.update_policy(request)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from None
