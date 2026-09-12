"""Automated verification suite for Security Hardening V1.1 controls."""

import pytest
from httpx import AsyncClient

from app.core.config import Settings, settings
from app.core.logging import sanitize_message
from app.main import create_app


@pytest.mark.asyncio
async def test_payload_size_limit_rejects_oversized_body(client: AsyncClient, auth_headers: dict):
    """OWASP API4: Requests with body exceeding MAX_REQUEST_BODY_BYTES must be rejected with 413."""
    # Create an oversized payload exceeding 2 MB limit
    oversized_content = "x" * (settings.MAX_REQUEST_BODY_BYTES + 1024)
    headers = {
        **auth_headers,
        "Content-Length": str(len(oversized_content)),
        "Content-Type": "application/json",
    }

    response = await client.post(
        "/api/v1/tasks",
        content=oversized_content,
        headers=headers,
    )
    assert response.status_code == 413
    data = response.json()
    assert "error" in data
    assert data["error"]["code"] == "PAYLOAD_TOO_LARGE"
    assert "exceeds maximum allowed size" in data["error"]["message"]


@pytest.mark.asyncio
async def test_default_deny_blocks_unauthenticated_tasks_access(client: AsyncClient):
    """Security Hardening: Router boundary enforces default-deny authentication on /tasks."""
    response = await client.get("/api/v1/tasks")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTHENTICATION_REQUIRED"


@pytest.mark.asyncio
async def test_public_health_probe_remains_accessible_without_auth(client: AsyncClient):
    """Public health probe must remain reachable for LAN discovery while other routes are default-deny."""
    response = await client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


@pytest.mark.asyncio
async def test_cors_preflight_allows_configured_methods_and_headers(client: AsyncClient):
    """OWASP API7: CORS preflight must allow only explicit methods and headers, no wildcards."""
    headers = {
        "Origin": "http://localhost:5173",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "Authorization,Content-Type",
    }
    response = await client.options("/api/v1/tasks", headers=headers)
    assert response.status_code == 200
    allow_methods = response.headers.get("access-control-allow-methods", "")
    assert "POST" in allow_methods
    assert "GET" in allow_methods
    assert "PATCH" in allow_methods
    assert "DELETE" in allow_methods


@pytest.mark.asyncio
async def test_secret_sanitizer_redacts_tokens_from_log_messages():
    """Rule 12 & Sec 11.1: Log sanitizer must redact pairing tokens and Bearer strings."""
    test_secret = "companion_sec_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
    test_msg = f"Connecting to runtime with token {test_secret} for session"
    sanitized = sanitize_message(test_msg)

    assert test_secret not in sanitized
    assert "***REDACTED_TOKEN***" in sanitized


def test_docs_disabled_outside_development_environment(monkeypatch):
    """Sec 11.6: Swagger UI and OpenAPI schemas must be disabled when ENVIRONMENT is not development."""
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    prod_app = create_app()

    assert prod_app.docs_url is None
    assert prod_app.redoc_url is None
    assert prod_app.openapi_url is None


@pytest.mark.asyncio
async def test_streaming_payload_exceeding_limit_rejected_413(client: AsyncClient, auth_headers: dict):
    """OWASP API4: Streaming chunks exceeding MAX_REQUEST_BODY_BYTES must be aborted with 413 even without Content-Length."""
    chunk_size = 512 * 1024  # 512 KB
    total_chunks = (settings.MAX_REQUEST_BODY_BYTES // chunk_size) + 2

    async def streaming_generator():
        for _ in range(total_chunks):
            yield b"0" * chunk_size

    headers = {
        **auth_headers,
        "Content-Type": "application/octet-stream",
    }
    response = await client.post(
        "/api/v1/tasks",
        content=streaming_generator(),
        headers=headers,
    )
    assert response.status_code == 413
    assert response.json()["error"]["code"] == "PAYLOAD_TOO_LARGE"


def test_cors_configuration_rejects_wildcards_and_schemeless_origins():
    """Item 4 / CORS: Setting wildcard '*' or schemeless origins must raise a fatal configuration error."""
    from pydantic import ValidationError

    # Wildcard rejection
    with pytest.raises(ValidationError) as exc1:
        Settings(CORS_ORIGINS="*", COMPANION_API_KEY="companion_sec_testtoken123456789012")
    assert "strictly forbidden" in str(exc1.value)

    # Schemeless origin rejection
    with pytest.raises(ValidationError) as exc2:
        Settings(CORS_ORIGINS="localhost:3000", COMPANION_API_KEY="companion_sec_testtoken123456789012")
    assert "Explicit scheme" in str(exc2.value)


@pytest.mark.asyncio
async def test_request_id_sanitizer_discards_malicious_header(client: AsyncClient):
    """Item 5: Malicious or oversized X-Request-ID headers must be discarded and replaced with safe req_<hex>."""
    # Malicious injection header
    response = await client.get("/api/v1/health", headers={"X-Request-ID": "../../attack\r\nInjected: True"})
    req_id = response.headers.get("X-Request-ID", "")
    assert req_id.startswith("req_")
    assert "attack" not in req_id

    # Valid header is preserved
    response_valid = await client.get("/api/v1/health", headers={"X-Request-ID": "safe-trace_id-123"})
    assert response_valid.headers.get("X-Request-ID") == "safe-trace_id-123"


def test_router_architecture_is_fail_closed():
    """Item 2: Verify public_router contains only /health and protected_router enforces verify_token."""
    from app.api.v1.router import public_router, protected_router
    from app.api.deps import verify_token

    def extract_paths(router):
        paths = []
        for route in router.routes:
            if hasattr(route, "path"):
                paths.append(route.path)
            elif hasattr(route, "original_router"):
                for sub_route in route.original_router.routes:
                    if hasattr(sub_route, "path"):
                        paths.append(sub_route.path)
        return paths

    # Public router must only contain /health
    public_paths = extract_paths(public_router)
    assert public_paths == ["/health"]

    # Protected router must have verify_token dependency
    assert any(dep.dependency == verify_token for dep in protected_router.dependencies)

