"""Health checks and host machine telemetry endpoints."""

import os
import platform
import socket
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, verify_token
from app.core.config import settings
from app.core.host_admin import require_host_admin
from app.core.runtime_lifecycle import runtime_lifecycle
from app.schemas.health import (
    HealthResponse,
    SystemShutdownRequest,
    SystemShutdownResponse,
    SystemStatusResponse,
)
from app.services.profile_purge_service import (
    ProfilePurgeService,
    PurgeMaintenanceResult,
)

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
