"""Tests for public health probe and protected system telemetry."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_public_health_check_returns_200_without_token(client: AsyncClient):
    """AC-3 / Health Probe: /health must respond to public pings without credentials."""
    response = await client.get("/api/v1/health")
    assert response.status_code == 200

    data = response.json()
    assert data["status"] == "healthy"
    assert data["database_connected"] is True
    assert "version" in data
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_system_status_requires_authentication(client: AsyncClient):
    """AC-3 / Security: /system/status must reject unauthenticated requests."""
    response = await client.get("/api/v1/system/status")
    assert response.status_code == 401
    assert "error" in response.json()
    assert response.json()["error"]["code"] == "AUTHENTICATION_REQUIRED"


@pytest.mark.asyncio
async def test_system_status_succeeds_with_auth(client: AsyncClient, auth_headers: dict):
    """AC-3 / System Status: /system/status returns telemetry when authenticated."""
    response = await client.get("/api/v1/system/status", headers=auth_headers)
    assert response.status_code == 200

    data = response.json()
    assert data["status"] == "online"
    assert "platform" in data
    assert "python_version" in data
    assert "hostname" in data
