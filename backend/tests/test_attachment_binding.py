"""Comprehensive test suite for Phase 8B.4: Transactional Message Binding & Pre-Stream Preparation."""

import asyncio
from pathlib import Path
from typing import AsyncGenerator
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import event, func, select, text, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings
from app.db.base import Base
from app.models.attachment import Attachment
from app.models.base import utc_now
from app.models.conversation import Conversation
from app.models.message import Message
from app.schemas.attachment import AttachmentRef
from app.services.assistant.orchestrator import _get_lock, prepare_turn
from app.services.attachment_service import (
    AttachmentAlreadyClaimedError,
    AttachmentForbiddenError,
    AttachmentNotAvailableError,
    AttachmentNotFoundError,
    claim_attachments_for_message,
)
from app.services.llm.manager import get_llm_provider
from app.services.llm.runtime_state import LLMRuntimeState


async def _create_test_conversation(
    session: AsyncSession,
    owner_id: str = "local_user",
    title: str = "Binding Test Conv",
) -> Conversation:
    """Helper to create an active test conversation."""
    conv = Conversation(
        id=f"conv-{uuid.uuid4().hex[:8]}",
        owner_id=owner_id,
        title=title,
        character_id="default",
    )
    session.add(conv)
    await session.commit()
    await session.refresh(conv)
    return conv


async def _create_test_attachment(
    session: AsyncSession,
    conversation_id: str,
    owner_id: str = "local_user",
    message_id: str | None = None,
    is_deleted: bool = False,
    filename_display: str = "test.png",
) -> Attachment:
    """Helper to create a test attachment in DB."""
    att_id = f"att-{uuid.uuid4().hex[:8]}"
    att = Attachment(
        id=att_id,
        conversation_id=conversation_id,
        owner_id=owner_id,
        message_id=message_id,
        filename_display=filename_display,
        storage_filename=f"{att_id}.png",
        storage_path=f"attachments/{owner_id}/{conversation_id}/{att_id}.png",
        mime_type="image/png",
        size_bytes=1024,
        image_width=100,
        image_height=100,
        is_deleted=is_deleted,
        deleted_at=utc_now() if is_deleted else None,
    )
    session.add(att)
    await session.commit()
    await session.refresh(att)
    return att


# ===========================================================================
# 1. Basic Binding & Streaming Tests
# ===========================================================================

@pytest.mark.anyio
async def test_send_message_text_only_empty_attachments(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify text-only turn with attachment_ids=[] succeeds with SSE 200."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Hello, text only!", "attachment_ids": []},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert "text/event-stream" in resp.headers["content-type"]
    assert "[DONE]" in resp.text

    # Verify messages in DB
    msg_res = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    assert msg_res.status_code == 200
    data = msg_res.json()["items"]
    assert len(data) == 2
    assert data[0]["sender"] == "user"
    assert data[0]["attachments"] == []
    assert data[1]["sender"] == "assistant"
    assert data[1]["attachments"] == []


@pytest.mark.anyio
async def test_send_message_with_single_valid_attachment(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify send with 1 staged valid attachment succeeds with SSE 200 and binds attachment."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att = await _create_test_attachment(test_session, conv_id)
    att_id = att.id

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Check this picture", "attachment_ids": [att_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert "text/event-stream" in resp.headers["content-type"]

    # Verify attachment is now bound in DB
    res = await test_session.execute(select(Attachment).where(Attachment.id == att_id))
    bound_att = res.scalar_one()
    assert bound_att.message_id is not None

    # Check GET /messages
    msg_res = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    items = msg_res.json()["items"]
    assert len(items) == 2
    user_msg = items[0]
    assert len(user_msg["attachments"]) == 1
    assert user_msg["attachments"][0]["id"] == att_id
    assert user_msg["attachments"][0]["filename_display"] == att.filename_display
    assert user_msg["attachments"][0]["mime_type"] == "image/png"
    assert user_msg["attachments"][0]["size_bytes"] == 1024


@pytest.mark.anyio
async def test_send_message_with_max_four_attachments(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify send with exactly 4 staged valid attachments succeeds with SSE 200 and binds all 4."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    atts = [await _create_test_attachment(test_session, conv_id, filename_display=f"img_{i}.png") for i in range(4)]
    att_ids = [a.id for a in atts]

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Four attachments turn", "attachment_ids": att_ids},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert "text/event-stream" in resp.headers["content-type"]

    for aid in att_ids:
        res = await test_session.execute(select(Attachment).where(Attachment.id == aid))
        bound = res.scalar_one()
        assert bound.message_id is not None

    msg_res = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    items = msg_res.json()["items"]
    user_msg = items[0]
    assert len(user_msg["attachments"]) == 4
    bound_ids = {ref["id"] for ref in user_msg["attachments"]}
    assert bound_ids == set(att_ids)


@pytest.mark.anyio
async def test_unclaimed_staged_attachments_absent_from_messages(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify staged attachments not referenced in send remain staged and absent from message history."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att_staged = await _create_test_attachment(test_session, conv_id, filename_display="unclaimed.png")
    att_claimed = await _create_test_attachment(test_session, conv_id, filename_display="claimed.png")
    staged_id = att_staged.id
    claimed_id = att_claimed.id

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Claim only one", "attachment_ids": [claimed_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 200

    res_staged = await test_session.execute(select(Attachment).where(Attachment.id == staged_id))
    assert res_staged.scalar_one().message_id is None

    res_claimed = await test_session.execute(select(Attachment).where(Attachment.id == claimed_id))
    assert res_claimed.scalar_one().message_id is not None

    msg_res = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    items = msg_res.json()["items"]
    user_refs = items[0]["attachments"]
    assert len(user_refs) == 1
    assert user_refs[0]["id"] == claimed_id


# ===========================================================================
# 2. List Validation Tests
# ===========================================================================

@pytest.mark.anyio
async def test_send_message_exceeds_four_attachments_rejected_422(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify sending > 4 attachment IDs returns HTTP 422 before SSE and creates no DB messages."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    five_ids = [f"att-{i}" for i in range(5)]

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Too many images", "attachment_ids": five_ids},
        headers=auth_headers,
    )
    assert resp.status_code == 422
    assert "text/event-stream" not in resp.headers["content-type"]
    assert "Maximum of 4 attachments" in resp.text

    # Verify no messages created
    res = await test_session.execute(select(func.count(Message.id)).where(Message.conversation_id == conv_id))
    assert res.scalar() == 0


@pytest.mark.anyio
async def test_send_message_duplicate_attachment_ids_rejected_422(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify duplicate attachment IDs in payload return HTTP 422 without silent deduplication."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att = await _create_test_attachment(test_session, conv_id)
    att_id = att.id

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Duplicate IDs", "attachment_ids": [att_id, att_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 422
    assert "Duplicate attachment IDs" in resp.text

    # Verify no messages created
    res = await test_session.execute(select(func.count(Message.id)).where(Message.conversation_id == conv_id))
    assert res.scalar() == 0


# ===========================================================================
# 3. Claim Failure Classification Pre-SSE Tests
# ===========================================================================

@pytest.mark.anyio
async def test_claim_nonexistent_attachment_returns_404(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify claiming nonexistent attachment returns HTTP 404 ATTACHMENT_NOT_FOUND pre-SSE."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Missing attachment", "attachment_ids": ["nonexistent-id"]},
        headers=auth_headers,
    )
    assert resp.status_code == 404
    assert "ATTACHMENT_NOT_FOUND" in resp.text
    assert "text/event-stream" not in resp.headers["content-type"]

    res = await test_session.execute(select(func.count(Message.id)).where(Message.conversation_id == conv_id))
    assert res.scalar() == 0


@pytest.mark.anyio
async def test_claim_wrong_conversation_attachment_returns_404(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify claiming attachment belonging to another conversation returns 404 (prevents object disclosure)."""
    conv1 = await _create_test_conversation(test_session, title="Conv 1")
    conv2 = await _create_test_conversation(test_session, title="Conv 2")
    conv1_id = conv1.id
    conv2_id = conv2.id
    att_in_conv2 = await _create_test_attachment(test_session, conv2_id)
    att_id = att_in_conv2.id

    resp = await client.post(
        f"/api/v1/conversations/{conv1_id}/messages",
        json={"user_text": "Cross conv claim", "attachment_ids": [att_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 404
    assert "ATTACHMENT_NOT_FOUND" in resp.text
    assert "text/event-stream" not in resp.headers["content-type"]


@pytest.mark.anyio
async def test_claim_foreign_owner_attachment_returns_403(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify claiming attachment with foreign owner under valid parent returns HTTP 403 ATTACHMENT_FORBIDDEN."""
    conv = await _create_test_conversation(test_session, owner_id="local_user")
    conv_id = conv.id
    att_foreign = await _create_test_attachment(test_session, conv_id, owner_id="foreign_user")
    att_id = att_foreign.id

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "BOLA claim", "attachment_ids": [att_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 403
    assert "ATTACHMENT_FORBIDDEN" in resp.text
    assert "text/event-stream" not in resp.headers["content-type"]


@pytest.mark.anyio
async def test_claim_soft_deleted_attachment_returns_422(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify claiming soft-deleted attachment returns HTTP 422 ATTACHMENT_NOT_AVAILABLE pre-SSE."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att_del = await _create_test_attachment(test_session, conv_id, is_deleted=True)
    att_id = att_del.id

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Deleted claim", "attachment_ids": [att_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 422
    assert "ATTACHMENT_NOT_AVAILABLE" in resp.text
    assert "text/event-stream" not in resp.headers["content-type"]


@pytest.mark.anyio
async def test_claim_already_claimed_attachment_returns_422(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify claiming already-bound attachment returns HTTP 422 ATTACHMENT_ALREADY_CLAIMED pre-SSE."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att_bound = await _create_test_attachment(test_session, conv_id, message_id="pre-existing-msg-id")
    att_id = att_bound.id

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Already claimed", "attachment_ids": [att_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 422
    assert "ATTACHMENT_ALREADY_CLAIMED" in resp.text
    assert "text/event-stream" not in resp.headers["content-type"]


# ===========================================================================
# 4. Atomic Rollback Tests
# ===========================================================================

@pytest.mark.anyio
async def test_claim_failure_rolls_back_earlier_claims_in_batch(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify when attachment 1 succeeds and attachment 2 fails, rollback restores attachment 1 to staged state."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att1_valid = await _create_test_attachment(test_session, conv_id, filename_display="valid1.png")
    att1_id = att1_valid.id
    att2_bound = await _create_test_attachment(test_session, conv_id, message_id="already-claimed-id")
    att2_id = att2_bound.id

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Batch claim with failure", "attachment_ids": [att1_id, att2_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 422
    assert "ATTACHMENT_ALREADY_CLAIMED" in resp.text

    # Verify att1 was rolled back and is STILL staged
    res = await test_session.execute(select(Attachment).where(Attachment.id == att1_id))
    refreshed_att1 = res.scalar_one()
    assert refreshed_att1.message_id is None

    # Verify no messages survive
    res = await test_session.execute(select(func.count(Message.id)).where(Message.conversation_id == conv_id))
    assert res.scalar() == 0


@pytest.mark.anyio
async def test_commit_failure_rolls_back_messages_and_claims(test_session: AsyncSession, monkeypatch):
    """Verify commit failure during pre-stream preparation rolls back messages and resets attachment claims."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att = await _create_test_attachment(test_session, conv_id)
    att_id = att.id

    async def failing_commit():
        raise RuntimeError("Simulated DB disk full or constraint failure")

    monkeypatch.setattr(test_session, "commit", failing_commit)

    with pytest.raises(RuntimeError, match="Simulated DB disk full"):
        await prepare_turn(
            db=test_session,
            conversation_id=conv_id,
            owner_id="local_user",
            user_text="Turn that fails commit",
            attachment_ids=[att_id],
        )

    # Restore commit
    monkeypatch.undo()

    # Verify zero messages created
    res = await test_session.execute(select(func.count(Message.id)).where(Message.conversation_id == conv_id))
    assert res.scalar() == 0

    # Verify attachment is still staged
    res = await test_session.execute(select(Attachment).where(Attachment.id == att_id))
    refreshed_att = res.scalar_one()
    assert refreshed_att.message_id is None


# ===========================================================================
# 5. Idempotency & Locking Tests
# ===========================================================================

@pytest.mark.anyio
async def test_send_message_idempotency_success_and_duplicate_409(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify duplicate client_message_id returns HTTP 409 DUPLICATE_MESSAGE before SSE."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    client_id = f"client-msg-{uuid.uuid4().hex[:8]}"

    # First send succeeds
    r1 = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Attempt 1", "client_message_id": client_id},
        headers=auth_headers,
    )
    assert r1.status_code == 200

    # Duplicate send fails with 409
    r2 = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Attempt 2", "client_message_id": client_id},
        headers=auth_headers,
    )
    assert r2.status_code == 409
    assert "DUPLICATE_MESSAGE" in r2.text


@pytest.mark.anyio
async def test_conversation_lock_returns_409_conversation_busy(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify sending message when conversation lock is held returns 409 CONVERSATION_BUSY pre-SSE."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    lock = _get_lock(conv_id)
    await lock.acquire()

    try:
        resp = await client.post(
            f"/api/v1/conversations/{conv_id}/messages",
            json={"user_text": "Competing send"},
            headers=auth_headers,
        )
        assert resp.status_code == 409
        assert "CONVERSATION_BUSY" in resp.text
    finally:
        lock.release()


@pytest.mark.anyio
async def test_lock_released_after_prestream_preparation_failure(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify that after a pre-stream preparation failure (e.g. 422), conversation lock is cleanly released."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    lock = _get_lock(conv_id)

    # Trigger 422 via duplicate attachment IDs
    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Bad turn", "attachment_ids": ["bad-id", "bad-id"]},
        headers=auth_headers,
    )
    assert resp.status_code == 422
    assert lock.locked() is False

    # Immediate subsequent valid send should succeed without 409
    r2 = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Valid retry", "attachment_ids": []},
        headers=auth_headers,
    )
    assert r2.status_code == 200
    assert lock.locked() is False


# ===========================================================================
# 6. Truthful File-Backed SQLite Concurrency Race Test
# ===========================================================================

@pytest.mark.anyio
async def test_atomic_claim_concurrency_race(tmp_path: Path):
    """Truthful concurrency test using a file-backed SQLite database and 2 independent sessions/connections.

    Verifies that when two distinct transactions contend for the exact same staged attachment:
    - Exactly one transaction successfully commits the claim.
    - The losing transaction receives AttachmentAlreadyClaimedError (422 equivalent).
    - Final DB state contains exactly one bound message_id.
    """
    db_file = tmp_path / "concurrency_test.db"
    db_url = f"sqlite+aiosqlite:///{db_file}"

    engine = create_async_engine(
        db_url,
        connect_args={"check_same_thread": False},
    )

    @event.listens_for(engine.sync_engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode = WAL;")
        cursor.execute("PRAGMA busy_timeout = 5000;")
        cursor.execute("PRAGMA foreign_keys = ON;")
        cursor.close()

    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_maker = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

    conv_id = "conv-race-001"
    att_id = "att-race-001"
    msg1_id = "msg-winner-1"
    msg2_id = "msg-contender-2"

    # Seed conversation, user messages, and single staged attachment
    async with session_maker() as init_session:
        conv = Conversation(id=conv_id, owner_id="local_user", title="Race Conv")
        init_session.add(conv)
        m1 = Message(id=msg1_id, conversation_id=conv_id, owner_id="local_user", sender="user", content="Turn 1", sequence_no=1)
        m2 = Message(id=msg2_id, conversation_id=conv_id, owner_id="local_user", sender="user", content="Turn 2", sequence_no=2)
        init_session.add(m1)
        init_session.add(m2)
        att = Attachment(
            id=att_id,
            conversation_id=conv_id,
            owner_id="local_user",
            message_id=None,  # Staged
            filename_display="race.png",
            storage_filename="race.png",
            storage_path="attachments/race.png",
            mime_type="image/png",
            size_bytes=512,
        )
        init_session.add(att)
        await init_session.commit()

    # Run coordinated contention between two distinct sessions
    contender_a_result = None
    contender_b_result = None
    start_event = asyncio.Event()

    async def contender_a():
        nonlocal contender_a_result
        async with session_maker() as session_a:
            await start_event.wait()
            try:
                await claim_attachments_for_message(
                    db=session_a,
                    attachment_ids=[att_id],
                    message_id=msg1_id,
                    owner_id="local_user",
                    conversation_id=conv_id,
                )
                await session_a.commit()
                contender_a_result = ("success", msg1_id)
            except Exception as exc:
                await session_a.rollback()
                contender_a_result = ("failed", exc)

    async def contender_b():
        nonlocal contender_b_result
        async with session_maker() as session_b:
            await start_event.wait()
            try:
                await claim_attachments_for_message(
                    db=session_b,
                    attachment_ids=[att_id],
                    message_id=msg2_id,
                    owner_id="local_user",
                    conversation_id=conv_id,
                )
                await session_b.commit()
                contender_b_result = ("success", msg2_id)
            except Exception as exc:
                await session_b.rollback()
                contender_b_result = ("failed", exc)

    t1 = asyncio.create_task(contender_a())
    t2 = asyncio.create_task(contender_b())

    start_event.set()
    await asyncio.gather(t1, t2)

    # Verify results: exactly one success and one failure
    results = [contender_a_result[0], contender_b_result[0]]
    assert results.count("success") == 1
    assert results.count("failed") == 1

    # Verify the failed one raised AttachmentAlreadyClaimedError (422)
    failed_exc = contender_a_result[1] if contender_a_result[0] == "failed" else contender_b_result[1]
    assert isinstance(failed_exc, AttachmentAlreadyClaimedError)
    assert failed_exc.status_code == 422

    # Verify final DB state
    async with session_maker() as verify_session:
        res = await verify_session.execute(select(Attachment).where(Attachment.id == att_id))
        final_att = res.scalar_one()
        assert final_att.message_id in (msg1_id, msg2_id)

    await engine.dispose()


# ===========================================================================
# 7. Sequence Collision Handling Tests
# ===========================================================================

@pytest.mark.anyio
async def test_deterministic_sequence_ordering_with_attachments(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify messages maintain deterministic sequence ordering [1, 2, 3, 4] with attachments bound."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att1 = await _create_test_attachment(test_session, conv_id)
    att2 = await _create_test_attachment(test_session, conv_id)
    att1_id = att1.id
    att2_id = att2.id

    await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Turn 1", "attachment_ids": [att1_id]},
        headers=auth_headers,
    )
    await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Turn 2", "attachment_ids": [att2_id]},
        headers=auth_headers,
    )

    msg_res = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    items = msg_res.json()["items"]
    assert len(items) == 4
    assert [m["sequence_no"] for m in items] == [1, 2, 3, 4]
    assert [m["sender"] for m in items] == ["user", "assistant", "user", "assistant"]


@pytest.mark.anyio
async def test_sequence_collision_bounded_retry(test_session: AsyncSession, monkeypatch):
    """Simulate sequence collision on first attempt; verify bounded retry creates turn with fresh entities."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att = await _create_test_attachment(test_session, conv_id)
    att_id = att.id

    original_flush = test_session.flush
    collision_triggered = False

    async def flaky_flush():
        nonlocal collision_triggered
        if not collision_triggered:
            collision_triggered = True
            raise IntegrityError("UNIQUE constraint failed: messages.conversation_id, messages.sequence_no", params=None, orig=Exception("mock sequence collision"))
        await original_flush()

    monkeypatch.setattr(test_session, "flush", flaky_flush)

    prepared = await prepare_turn(
        db=test_session,
        conversation_id=conv_id,
        owner_id="local_user",
        user_text="Turn with sequence retry",
        attachment_ids=[att_id],
    )

    assert collision_triggered is True
    assert prepared.user_sequence_no == 1
    assert prepared.assistant_sequence_no == 2

    # Verify attachment is bound
    res = await test_session.execute(select(Attachment).where(Attachment.id == att_id))
    bound_att = res.scalar_one()
    assert bound_att.message_id == prepared.user_message.id


# ===========================================================================
# 8. History Serialization Integrity Tests
# ===========================================================================

@pytest.mark.anyio
async def test_history_serialization_excludes_storage_paths(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify storage_path and storage_filename are absent from message history serialization."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att = await _create_test_attachment(test_session, conv_id)
    att_id = att.id
    storage_fn = att.storage_filename

    await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Check schema privacy", "attachment_ids": [att_id]},
        headers=auth_headers,
    )

    msg_res = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    raw_json = msg_res.text
    assert "storage_path" not in raw_json
    assert "storage_filename" not in raw_json
    assert storage_fn not in raw_json


@pytest.mark.anyio
async def test_history_serialization_excludes_soft_deleted_attachments(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify soft-deleted attachments on a message are excluded from MessageOut.attachments."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att = await _create_test_attachment(test_session, conv_id)
    att_id = att.id

    await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Attachment to be deleted", "attachment_ids": [att_id]},
        headers=auth_headers,
    )

    # Soft-delete the attachment
    res = await test_session.execute(select(Attachment).where(Attachment.id == att_id))
    live_att = res.scalar_one()
    live_att.is_deleted = True
    live_att.deleted_at = utc_now()
    await test_session.commit()

    # GET messages should return empty attachments list
    msg_res = await client.get(f"/api/v1/conversations/{conv_id}/messages", headers=auth_headers)
    items = msg_res.json()["items"]
    assert items[0]["attachments"] == []


# ===========================================================================
# 9. Conversation Soft-Delete Cascade Tests
# ===========================================================================

@pytest.mark.anyio
async def test_conversation_delete_soft_deletes_staged_and_bound_attachments(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify DELETE conversation cascades soft-delete to both staged and bound attachments."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att_bound = await _create_test_attachment(test_session, conv_id, filename_display="bound.png")
    att_staged = await _create_test_attachment(test_session, conv_id, filename_display="staged.png")
    bound_id = att_bound.id
    staged_id = att_staged.id

    # Bind first attachment
    await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Bind one", "attachment_ids": [bound_id]},
        headers=auth_headers,
    )

    # Soft-delete conversation
    del_resp = await client.delete(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert del_resp.status_code == 204

    # Verify both attachments are soft-deleted in DB with same deleted_at
    res_b = await test_session.execute(select(Attachment).where(Attachment.id == bound_id))
    b = res_b.scalar_one()
    res_s = await test_session.execute(select(Attachment).where(Attachment.id == staged_id))
    s = res_s.scalar_one()

    assert b.is_deleted is True
    assert b.deleted_at is not None
    assert s.is_deleted is True
    assert s.deleted_at is not None
    assert b.deleted_at == s.deleted_at


@pytest.mark.anyio
async def test_conversation_delete_cascade_affects_all_child_attachments_regardless_of_owner(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify parent conversation soft-delete cascades to child attachments regardless of owner metadata."""
    conv = await _create_test_conversation(test_session, owner_id="local_user")
    conv_id = conv.id
    att_foreign = await _create_test_attachment(test_session, conv_id, owner_id="foreign_owner")
    foreign_id = att_foreign.id

    del_resp = await client.delete(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert del_resp.status_code == 204

    res = await test_session.execute(select(Attachment).where(Attachment.id == foreign_id))
    f = res.scalar_one()
    assert f.is_deleted is True
    assert f.deleted_at is not None


@pytest.mark.anyio
async def test_conversation_delete_preserves_physical_files(client: AsyncClient, auth_headers: dict, test_session: AsyncSession):
    """Verify conversation soft-delete does NOT delete physical attachment files from disk (Phase 9 retention)."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att = await _create_test_attachment(test_session, conv_id)
    storage_filename = att.storage_filename

    # Create dummy physical file
    file_dir = settings.ATTACHMENT_DIR / "local_user" / conv_id
    file_dir.mkdir(parents=True, exist_ok=True)
    file_path = file_dir / storage_filename
    file_path.write_bytes(b"dummy image bytes")
    assert file_path.is_file()

    # Soft-delete conversation
    del_resp = await client.delete(f"/api/v1/conversations/{conv_id}", headers=auth_headers)
    assert del_resp.status_code == 204

    # Verify physical file still exists on disk
    assert file_path.is_file()


@pytest.mark.anyio
async def test_conversation_delete_rollback_preserves_state(client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch):
    """Verify simulated commit failure on conversation delete rolls back conversation and attachments."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att = await _create_test_attachment(test_session, conv_id)
    att_id = att.id

    async def failing_commit():
        raise RuntimeError("Simulated failure during delete commit")

    monkeypatch.setattr(test_session, "commit", failing_commit)

    with pytest.raises(RuntimeError, match="Simulated failure during delete commit"):
        await client.delete(f"/api/v1/conversations/{conv_id}", headers=auth_headers)

    monkeypatch.undo()

    # Verify conversation is STILL active
    res_c = await test_session.execute(select(Conversation).where(Conversation.id == conv_id))
    refreshed_conv = res_c.scalar_one()
    assert refreshed_conv.is_deleted is False
    assert refreshed_conv.deleted_at is None

    # Verify attachment is STILL active
    res_a = await test_session.execute(select(Attachment).where(Attachment.id == att_id))
    refreshed_att = res_a.scalar_one()
    assert refreshed_att.is_deleted is False
    assert refreshed_att.deleted_at is None


# ===========================================================================
# 10. Provider Readiness, Failure & Task Cancellation Tests
# ===========================================================================

@pytest.mark.anyio
async def test_send_message_provider_unavailable_503(client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch):
    """Verify provider unavailable returns HTTP 503 LLM_UNAVAILABLE before messages or claims are persisted."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att = await _create_test_attachment(test_session, conv_id)
    att_id = att.id

    provider = get_llm_provider()

    # Mock provider status as not ready and load_model returning False
    class MockStatus:
        runtime_state = LLMRuntimeState.MODEL_ERROR

    async def mock_get_status():
        return MockStatus()

    async def mock_load_model():
        return False

    monkeypatch.setattr(provider, "get_status", mock_get_status)
    monkeypatch.setattr(provider, "load_model", mock_load_model)

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Should fail 503", "attachment_ids": [att_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 503
    assert "LLM_UNAVAILABLE" in resp.text
    assert "text/event-stream" not in resp.headers["content-type"]

    # Verify lock released
    lock = _get_lock(conv_id)
    assert lock.locked() is False

    # Verify no messages created and attachment still staged
    res = await test_session.execute(select(func.count(Message.id)).where(Message.conversation_id == conv_id))
    assert res.scalar() == 0

    res_a = await test_session.execute(select(Attachment).where(Attachment.id == att_id))
    assert res_a.scalar_one().message_id is None


@pytest.mark.anyio
async def test_generation_failure_lock_released_and_retry_allowed(client: AsyncClient, auth_headers: dict, test_session: AsyncSession, monkeypatch):
    """Verify mid-stream generation failure leaves user message and claims committed, releases lock, and allows immediate retry."""
    conv = await _create_test_conversation(test_session)
    conv_id = conv.id
    att1 = await _create_test_attachment(test_session, conv_id, filename_display="img1.png")
    att1_id = att1.id

    provider = get_llm_provider()

    async def failing_stream(*args, **kwargs):
        yield "InitialPart"
        raise RuntimeError("Native worker segfault")

    monkeypatch.setattr(provider, "generate_stream", failing_stream)

    resp = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Fail generation", "attachment_ids": [att1_id]},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert "MODEL_GENERATION_FAILED" in resp.text

    # Lock is unlocked
    lock = _get_lock(conv_id)
    assert lock.locked() is False

    # User message committed and attachment bound
    res = await test_session.execute(select(Attachment).where(Attachment.id == att1_id))
    refreshed_att1 = res.scalar_one()
    assert refreshed_att1.message_id is not None

    # Immediate second message on same conversation succeeds
    monkeypatch.undo()
    att2 = await _create_test_attachment(test_session, conv_id, filename_display="img2.png")
    att2_id = att2.id

    resp2 = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"user_text": "Retry succeed", "attachment_ids": [att2_id]},
        headers=auth_headers,
    )
    assert resp2.status_code == 200
    assert "[DONE]" in resp2.text
    assert lock.locked() is False
