"""Tests for LLM runtime endpoints, streaming completions, model status, and authentication."""

import pytest
from httpx import AsyncClient

from app.services.llm.manager import llm_manager
from app.services.llm.mock import MockLLMProvider


@pytest.fixture(autouse=True)
def ensure_mock_provider():
    """Ensure tests run against fast, deterministic MockLLMProvider."""
    mock = MockLLMProvider()
    llm_manager.set_provider(mock)
    yield
    llm_manager.reset()


@pytest.mark.asyncio
async def test_llm_endpoints_require_auth(client: AsyncClient):
    """Security: Both /models and /chat/completions must fail-closed with 401."""
    resp1 = await client.get("/api/v1/models")
    assert resp1.status_code == 401

    resp2 = await client.post("/api/v1/chat/completions", json={"messages": [{"role": "user", "content": "Hi"}]})
    assert resp2.status_code == 401


@pytest.mark.asyncio
async def test_get_model_status_succeeds(client: AsyncClient, auth_headers: dict):
    """Model status endpoint returns hardware profile and active model metadata."""
    response = await client.get("/api/v1/models", headers=auth_headers)
    assert response.status_code == 200

    data = response.json()
    assert "provider" in data
    assert "is_loaded" in data
    assert "active_profile" in data
    assert "context_size" in data
    assert "idle_timeout_seconds" in data
    assert isinstance(data["available_models"], list)


@pytest.mark.asyncio
async def test_chat_completions_sync(client: AsyncClient, auth_headers: dict):
    """Synchronous chat completion returns standard OpenAI-compatible response."""
    payload = {
        "messages": [
            {"role": "system", "content": "You are a helpful companion."},
            {"role": "user", "content": "Hello, how are you today?"},
        ],
        "stream": False,
        "temperature": 0.7,
        "max_tokens": 512,
    }
    response = await client.post("/api/v1/chat/completions", json=payload, headers=auth_headers)
    assert response.status_code == 200

    data = response.json()
    assert data["object"] == "chat.completion"
    assert len(data["choices"]) == 1
    assert data["choices"][0]["message"]["role"] == "assistant"
    assert "Local AI Core is operational" in data["choices"][0]["message"]["content"]
    assert data["usage"]["total_tokens"] > 0


@pytest.mark.asyncio
async def test_chat_completions_streaming(client: AsyncClient, auth_headers: dict):
    """Streaming chat completion yields Server-Sent Events (SSE) data chunks."""
    payload = {
        "messages": [
            {"role": "user", "content": "Give me a brief overview."},
        ],
        "stream": True,
    }
    response = await client.post("/api/v1/chat/completions", json=payload, headers=auth_headers)
    assert response.status_code == 200
    assert "text/event-stream" in response.headers.get("content-type", "")

    body = response.text
    lines = [line.strip() for line in body.split("\n") if line.strip()]

    # Must have multiple data chunks
    data_lines = [line for line in lines if line.startswith("data:")]
    assert len(data_lines) >= 3

    # Must end with [DONE]
    assert data_lines[-1] == "data: [DONE]"


@pytest.mark.asyncio
async def test_chat_completions_validation_error(client: AsyncClient, auth_headers: dict):
    """Empty messages list must fail with HTTP 422 Unprocessable Entity."""
    payload = {
        "messages": [],
        "stream": False,
    }
    response = await client.post("/api/v1/chat/completions", json=payload, headers=auth_headers)
    assert response.status_code == 422
