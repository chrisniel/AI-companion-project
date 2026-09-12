"""Tests for token verification, header handling, and rejection behavior."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_auth_verify_missing_token_returns_401(client: AsyncClient):
    """AC-3 / OWASP API2: Missing token returns 401 with standard error envelope."""
    response = await client.post("/api/v1/auth/verify")
    assert response.status_code == 401

    payload = response.json()
    assert "error" in payload
    assert payload["error"]["code"] == "AUTHENTICATION_REQUIRED"
    assert "X-Request-ID" in response.headers


@pytest.mark.asyncio
async def test_auth_verify_invalid_token_returns_401(client: AsyncClient):
    """AC-3 / OWASP API2: Invalid token returns 401."""
    headers = {"Authorization": "Bearer invalid_secret_token_value_9999"}
    response = await client.post("/api/v1/auth/verify", headers=headers)
    assert response.status_code == 401

    payload = response.json()
    assert "error" in payload
    assert payload["error"]["code"] == "AUTHENTICATION_REQUIRED"


@pytest.mark.asyncio
async def test_auth_verify_valid_bearer_token_returns_200(client: AsyncClient, auth_headers: dict):
    """AC-3 / Auth Flow: Valid Bearer token succeeds."""
    response = await client.post("/api/v1/auth/verify", headers=auth_headers)
    assert response.status_code == 200

    payload = response.json()
    assert payload["authenticated"] is True
    assert payload["token_type"] == "Bearer"


@pytest.mark.asyncio
async def test_auth_verify_valid_x_api_key_header_returns_200(client: AsyncClient, api_key_headers: dict):
    """AC-3 / Auth Flow: Valid X-API-Key header succeeds."""
    response = await client.post("/api/v1/auth/verify", headers=api_key_headers)
    assert response.status_code == 200

    payload = response.json()
    assert payload["authenticated"] is True
