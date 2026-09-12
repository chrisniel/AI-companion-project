"""Tests for public health probe and protected system telemetry."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_public_health_check_returns_200_without_token(client: AsyncClient):
    """AC-3 / Health Probe: /health must return minimal status without leaking internal metrics."""
    response = await client.get("/api/v1/health")
    assert response.status_code == 200

    data = response.json()
    assert data == {"status": "healthy"}
    # Verify no diagnostic or version leakage to unauthenticated callers
    assert "version" not in data
    assert "database_connected" not in data
    assert "timestamp" not in data


@pytest.mark.asyncio
async def test_system_status_requires_authentication(client: AsyncClient):
    """AC-3 / Security: /system/status must reject unauthenticated requests."""
    response = await client.get("/api/v1/system/status")
    assert response.status_code == 401
    assert "error" in response.json()
    assert response.json()["error"]["code"] == "AUTHENTICATION_REQUIRED"


@pytest.mark.asyncio
async def test_system_status_succeeds_with_auth(client: AsyncClient, auth_headers: dict):
    """AC-3 / System Status: /system/status returns full telemetry and diagnostics when authenticated."""
    response = await client.get("/api/v1/system/status", headers=auth_headers)
    assert response.status_code == 200

    data = response.json()
    assert data["status"] in ("online", "degraded")
    assert "platform" in data
    assert "python_version" in data
    assert "hostname" in data
    assert "version" in data
    assert "database_connected" in data
    assert "timestamp" in data
