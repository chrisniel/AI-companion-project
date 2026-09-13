"""Tests for conversation and message persistence, concurrency, and security."""

import pytest
from httpx import AsyncClient
from app.services.assistant.orchestrator import _get_lock


@pytest.mark.anyio
async def test_conversation_endpoints_require_auth(client: AsyncClient):
    """Ensure all conversation routes reject unauthenticated requests with 401."""
    resp = await client.get("/api/v1/conversations")
    assert resp.status_code == 401

    resp = await client.post("/api/v1/conversations", json={"title": "Test"})
    assert resp.status_code == 401

    resp = await client.get("/api/v1/conversations/test-id")
    assert resp.status_code == 401

    resp = await client.patch("/api/v1/conversations/test-id", json={"title": "New"})
    assert resp.status_code == 401

    resp = await client.delete("/api/v1/conversations/test-id")
    assert resp.status_code == 401

    resp = await client.get("/api/v1/conversations/test-id/messages")
    assert resp.status_code == 401

    resp = await client.post("/api/v1/conversations/test-id/messages", json={"user_text": "Hi"})
    assert resp.status_code == 401


@pytest.mark.anyio
async def test_conversation_crud_lifecycle(client: AsyncClient, auth_headers: dict):
    """Test full CRUD lifecycle of persistent conversations."""
    # 1. Create conversation
    create_resp = await client.post(
        "/api/v1/conversations",
        json={"title": "Project Planning", "character_id": "companion-1"},
        headers=auth_headers,
    )
    assert create_resp.status_code == 201
    conv = create_resp.json()
    conv_id = conv["id"]
    assert conv["title"] == "Project Planning"
    assert conv["character_id"] == "companion-1"
    assert "owner_id" in conv

    # 2. Get conversation
    get_resp = await client.get(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["id"] == conv_id

    # 3. List conversations
    list_resp = await client.get("/api/v1/conversations", headers=auth_headers)
    assert list_resp.status_code == 200
    data = list_resp.json()
    assert data["total"] >= 1
    assert any(c["id"] == conv_id for c in data["items"])

    # 4. Rename conversation
    patch_resp = await client.patch(
        f"/api/v1/conversations/{conv_id}",
        json={"title": "Renamed Planning"},
        headers=auth_headers,
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["title"] == "Renamed Planning"

    # 5. Soft-delete conversation
    del_resp = await client.delete(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert del_resp.status_code == 204

    # 6. Verify deleted conversation returns 404
    get_deleted = await client.get(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert get_deleted.status_code == 404


@pytest.mark.anyio
async def test_messages_streaming_and_persistence(client: AsyncClient, auth_headers: dict):
    """Test message sending, SSE token streaming, and message persistence."""
    # Create conversation
    c_resp = await client.post("/api/v1/conversations", json={"title": "Chat Test"}, headers=auth_headers)
    conv_id = c_resp.json()["id"]

    # Send message via SSE
    send_resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Hello assistant!", "client_message_id": "msg-client-001"},
        headers=auth_headers,
    )
    assert send_resp.status_code == 200
    assert "text/event-stream" in send_resp.headers["content-type"]
    body = send_resp.text
    assert "data:" in body
    assert "[DONE]" in body

    # Retrieve messages list
    msg_resp = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    assert msg_resp.status_code == 200
    msgs = msg_resp.json()["items"]
    assert len(msgs) == 2

    user_msg = msgs[0]
    asst_msg = msgs[1]

    assert user_msg["sender"] == "user"
    assert user_msg["content"] == "Hello assistant!"
    assert user_msg["sequence_no"] == 1
    assert user_msg["status"] == "completed"
    assert user_msg["client_message_id"] == "msg-client-001"

    assert asst_msg["sender"] == "assistant"
    assert asst_msg["sequence_no"] == 2
    assert asst_msg["status"] == "completed"
    assert len(asst_msg["content"]) > 0


@pytest.mark.anyio
async def test_idempotency_duplicate_message_rejected(client: AsyncClient, auth_headers: dict):
    """Ensure sending a message with duplicate client_message_id returns 409 DUPLICATE_MESSAGE."""
    c_resp = await client.post("/api/v1/conversations", json={"title": "Idempotency Test"}, headers=auth_headers)
    conv_id = c_resp.json()["id"]

    # First send succeeds
    r1 = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "First attempt", "client_message_id": "unique-uuid-123"},
        headers=auth_headers,
    )
    assert r1.status_code == 200

    # Second send with same client_message_id fails with 409
    r2 = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Duplicate attempt", "client_message_id": "unique-uuid-123"},
        headers=auth_headers,
    )
    assert r2.status_code == 409
    assert "DUPLICATE_MESSAGE" in r2.text


@pytest.mark.anyio
async def test_same_client_message_id_in_different_conversations_allowed(client: AsyncClient, auth_headers: dict):
    """Ensure the same client_message_id in two DIFFERENT conversations is allowed (Phase 6 scoped uniqueness)."""
    c1_resp = await client.post("/api/v1/conversations", json={"title": "Conv 1"}, headers=auth_headers)
    conv1_id = c1_resp.json()["id"]

    c2_resp = await client.post("/api/v1/conversations", json={"title": "Conv 2"}, headers=auth_headers)
    conv2_id = c2_resp.json()["id"]

    shared_client_id = "shared-client-msg-uuid"

    # Send in conversation 1 -> 200 OK
    r1 = await client.post(
        f"/api/v1/conversations/{conv1_id}/messages",
        json={"user_text": "Message in conv 1", "client_message_id": shared_client_id},
        headers=auth_headers,
    )
    assert r1.status_code == 200

    # Send SAME client_message_id in conversation 2 -> 200 OK
    r2 = await client.post(
        f"/api/v1/conversations/{conv2_id}/messages",
        json={"user_text": "Message in conv 2", "client_message_id": shared_client_id},
        headers=auth_headers,
    )
    assert r2.status_code == 200

    # Sending AGAIN in conversation 1 must still be rejected with 409
    r3 = await client.post(
        f"/api/v1/conversations/{conv1_id}/messages",
        json={"user_text": "Retry in conv 1", "client_message_id": shared_client_id},
        headers=auth_headers,
    )
    assert r3.status_code == 409
    assert "DUPLICATE_MESSAGE" in r3.text


@pytest.mark.anyio
async def test_deterministic_sequence_ordering(client: AsyncClient, auth_headers: dict):
    """Ensure messages maintain deterministic chronological sequence numbering."""
    c_resp = await client.post("/api/v1/conversations", json={"title": "Seq Test"}, headers=auth_headers)
    conv_id = c_resp.json()["id"]

    # Send 2 consecutive messages
    await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Turn 1", "client_message_id": "turn-1"},
        headers=auth_headers,
    )
    await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Turn 2", "client_message_id": "turn-2"},
        headers=auth_headers,
    )

    # Fetch messages and verify sequence numbers
    list_resp = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    assert list_resp.status_code == 200
    msgs = list_resp.json()["items"]
    assert len(msgs) == 4

    seqs = [m["sequence_no"] for m in msgs]
    assert seqs == [1, 2, 3, 4]
    assert [m["sender"] for m in msgs] == ["user", "assistant", "user", "assistant"]


@pytest.mark.anyio
async def test_conversation_concurrency_lock_busy(client: AsyncClient, auth_headers: dict):
    """Ensure sending message when conversation lock is held returns 409 CONVERSATION_BUSY."""
    c_resp = await client.post("/api/v1/conversations", json={"title": "Lock Test"}, headers=auth_headers)
    conv_id = c_resp.json()["id"]

    lock = _get_lock(conv_id)
    await lock.acquire()
    try:
        resp = await client.post(
            f"/api/v1/conversations/{conv_id}/messages",
            json={"user_text": "Concurrent message"},
            headers=auth_headers,
        )
        assert resp.status_code == 409
        assert "CONVERSATION_BUSY" in resp.text
    finally:
        lock.release()


@pytest.mark.anyio
async def test_soft_delete_and_is_deleted_schema_integrity(client: AsyncClient, auth_headers: dict, test_session):
    """
    Regression Test:
    Verify that conversations, messages, and memories have is_deleted column
    and SoftDeleteMixin operates without OperationalError: no such column: conversations.is_deleted.
    """
    from sqlalchemy import select
    from app.models.conversation import Conversation
    from app.models.message import Message

    # 1. Create conversation
    create_resp = await client.post("/api/v1/conversations", json={"title": "Schema Integrity Test"}, headers=auth_headers)
    assert create_resp.status_code == 201
    conv_id = create_resp.json()["id"]

    # 2. Query ORM directly to verify is_deleted column selection
    conv_stmt = select(Conversation).where(Conversation.id == conv_id)
    conv_res = await test_session.execute(conv_stmt)
    conv = conv_res.scalar_one()
    assert conv.is_deleted is False
    assert conv.deleted_at is None

    # 3. Soft delete conversation and verify is_deleted flag
    del_resp = await client.delete(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert del_resp.status_code == 204

    # Refresh session to check soft delete state
    test_session.expire_all()
    conv_after_res = await test_session.execute(conv_stmt)
    conv_after = conv_after_res.scalar_one()
    assert conv_after.is_deleted is True
    assert conv_after.deleted_at is not None

