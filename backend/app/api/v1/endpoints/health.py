"""Health checks and host machine telemetry endpoints."""

import os
import platform
import socket
from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, verify_token
from app.core.config import settings
from app.schemas.health import HealthResponse, SystemStatusResponse

public_health_router = APIRouter(tags=["Health"])
system_router = APIRouter(tags=["System Status"])
router = public_health_router  # Backwards compatibility


@public_health_router.get("/health", response_model=HealthResponse, summary="Public Health Check")
async def health_check() -> HealthResponse:
    """
    Public liveness and readiness probe.
    Android uses this to detect if the Windows host PC is online on the local network.
    Does not require pairing credentials or expose internal versions or database metrics.
    """
    return HealthResponse(status="healthy")


@system_router.get(
    "/system/status",
    response_model=SystemStatusResponse,
    summary="Host System Status (Protected)",
)
async def system_status(db: AsyncSession = Depends(get_db)) -> SystemStatusResponse:
    """
    Detailed Windows host machine telemetry and database diagnostics.
    Requires valid pairing token.
    """
    db_connected = False
    try:
        await db.execute(text("SELECT 1"))
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
    )
