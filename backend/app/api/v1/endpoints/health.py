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

router = APIRouter(tags=["Health & System"])


@router.get("/health", response_model=HealthResponse, summary="Public Health Check")
async def health_check(db: AsyncSession = Depends(get_db)) -> HealthResponse:
    """
    Public liveness and readiness probe.
    Android uses this to detect if the Windows host PC is online on the local network.
    Does not require pairing credentials.
    """
    db_connected = False
    try:
        await db.execute(text("SELECT 1"))
        db_connected = True
    except Exception:
        db_connected = False

    return HealthResponse(
        status="healthy" if db_connected else "degraded",
        version=settings.VERSION,
        database_connected=db_connected,
        timestamp=datetime.now(timezone.utc),
    )


@router.get(
    "/system/status",
    response_model=SystemStatusResponse,
    summary="Host System Status (Protected)",
    dependencies=[Depends(verify_token)],
)
async def system_status() -> SystemStatusResponse:
    """
    Detailed Windows host machine telemetry.
    Requires valid pairing token.
    """
    return SystemStatusResponse(
        status="online",
        platform=f"{platform.system()} {platform.release()}",
        python_version=platform.python_version(),
        hostname=socket.gethostname(),
        cpu_count=os.cpu_count(),
        timestamp=datetime.now(timezone.utc),
    )
