"""Tests for LLM runtime endpoints, streaming completions, model status, and authentication."""

import pytest
from httpx import AsyncClient


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
    assert "Local AI Runtime is operational" in data["choices"][0]["message"]["content"]
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


@pytest.mark.asyncio
async def test_unload_and_load_model_endpoints(client: AsyncClient, auth_headers: dict):
    """Admin controls: unload releases model; load restores model into memory."""
    # 1. Unload model
    resp_unload = await client.post("/api/v1/models/unload", headers=auth_headers)
    assert resp_unload.status_code == 200
    data_unload = resp_unload.json()
    assert data_unload["is_loaded"] is False

    # 2. Load model
    resp_load = await client.post(
        "/api/v1/models/load",
        json={"model_name": "Qwen2.5-7B-Instruct-Q4_K_M.gguf", "profile": "balanced"},
        headers=auth_headers,
    )
    assert resp_load.status_code == 200
    data_load = resp_load.json()
    assert data_load["is_loaded"] is True
    assert data_load["active_profile"] == "balanced"


@pytest.mark.asyncio
async def test_update_model_profile_endpoint(client: AsyncClient, auth_headers: dict):
    """Admin controls: patch profile updates GPU layer targets and context sizes."""
    # Switch to Eco
    resp_eco = await client.patch(
        "/api/v1/models/profile",
        json={"profile": "eco"},
        headers=auth_headers,
    )
    assert resp_eco.status_code == 200
    data_eco = resp_eco.json()
    assert data_eco["active_profile"] == "eco"
    assert data_eco["gpu_layers"] == 0
    assert data_eco["context_size"] == 2048

    # Switch to Maximum
    resp_max = await client.patch(
        "/api/v1/models/profile",
        json={"profile": "maximum"},
        headers=auth_headers,
    )
    assert resp_max.status_code == 200
    data_max = resp_max.json()
    assert data_max["active_profile"] == "maximum"
    assert data_max["gpu_layers"] == 33
    assert data_max["context_size"] == 8192

    # Invalid profile
    resp_invalid = await client.patch(
        "/api/v1/models/profile",
        json={"profile": "ultra_extreme_invalid"},
        headers=auth_headers,
    )
    assert resp_invalid.status_code == 422


@pytest.mark.asyncio
async def test_chat_completions_rejects_image_bytes_content_block_422(client: AsyncClient, auth_headers: dict):
    """Security: Public /chat/completions must reject internal ContentBlock / image_bytes payloads with 422."""
    payload = {
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "image_bytes", "mime_type": "image/png", "data": "aGVsbG8="}
                ]
            }
        ],
        "stream": False,
    }
    response = await client.post("/api/v1/chat/completions", json=payload, headers=auth_headers)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_chat_completions_rejects_raw_binary_payloads_422(client: AsyncClient, auth_headers: dict):
    """Security: Public /chat/completions must reject raw binary or non-string content with 422."""
    payload = {
        "messages": [
            {
                "role": "user",
                "content": {"data": "raw_binary_dict"}
            }
        ],
        "stream": False,
    }
    response = await client.post("/api/v1/chat/completions", json=payload, headers=auth_headers)
    assert response.status_code == 422


def test_internal_chat_message_still_accepts_content_blocks():
    """Internal ChatMessage still accepts List[ContentBlock] for orchestrator/provider layers."""
    from app.schemas.llm import ChatMessage
    from app.schemas.multimodal import ResolvedImageContent, TextContent

    msg = ChatMessage(
        role="user",
        content=[
            ResolvedImageContent(type="image_bytes", mime_type="image/png", data=b"\x89PNG\r\n\x1a\n"),
            TextContent(type="text", text="Look at this image"),
        ]
    )
    assert len(msg.content) == 2
    assert msg.content[0].type == "image_bytes"
    assert msg.content[1].type == "text"

