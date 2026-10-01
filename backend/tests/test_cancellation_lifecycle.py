"""Tests for assistant stream cancellation, transaction safety, and connection pool integrity."""

import asyncio
from unittest.mock import AsyncMock
import uuid
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.attachment import Attachment
from app.models.conversation import Conversation
from app.models.message import Message
from app.schemas.llm import LLMRuntimeState, ModelStatusResponse
from app.services.assistant.orchestrator import (
    _get_lock,
    orchestrate_chat_stream,
    prepare_turn,
)
from app.services.llm.manager import get_llm_provider


@pytest.mark.asyncio
async def test_stream_cancellation_persists_cancelled_status_safely(test_session: AsyncSession):
    """Verify stream cancellation reconciles assistant placeholder to 'cancelled' without pool corruption."""
    owner_id = "test-owner-cancel-1"
    conv_id = f"conv-{uuid.uuid4()}"
    conv = Conversation(id=conv_id, owner_id=owner_id, title="Test Cancellation")
    test_session.add(conv)
    await test_session.commit()

    prepared = await prepare_turn(
        db=test_session,
        conversation_id=conv_id,
        owner_id=owner_id,
        user_text="Stream test message that will be cancelled",
    )
    asst_id = prepared.assistant_message.id
    user_id = prepared.user_message.id

    lock = _get_lock(conv_id)
    await lock.acquire()

    provider = get_llm_provider()
    provider.get_status = AsyncMock(
        return_value=ModelStatusResponse(
            provider="mock",
            runtime_state=LLMRuntimeState.MODEL_READY,
            active_model="test-model",
            context_size=4096,
        )
    )

    async def mock_cancelling_stream(messages):
        yield "First token received "
        raise asyncio.CancelledError()

    provider.generate_stream = mock_cancelling_stream

    stream_gen = orchestrate_chat_stream(
        db=test_session,
        conversation_id=conv_id,
        user_text="Stream test message that will be cancelled",
        owner_id=owner_id,
        prepared_turn=prepared,
        conversation_lock=lock,
    )

    with pytest.raises(asyncio.CancelledError):
        async for _ in stream_gen:
            pass

    # Verify conversation lock was released
    assert not lock.locked()

    # Verify assistant placeholder reached terminal 'cancelled' state in database
    factory = async_sessionmaker(bind=test_session.bind, class_=AsyncSession, expire_on_commit=False)
    async with factory() as verify_session:
        stmt = select(Message).where(Message.id == asst_id)
        res = await verify_session.execute(stmt)
        asst_msg = res.scalar_one_or_none()
        assert asst_msg is not None
        assert asst_msg.status == "cancelled"
        assert asst_msg.content == "First token received "

        # Verify user message remains durable and intact
        user_stmt = select(Message).where(Message.id == user_id)
        user_res = await verify_session.execute(user_stmt)
        user_msg = user_res.scalar_one_or_none()
        assert user_msg is not None
        assert user_msg.status == "completed"
        assert user_msg.content == "Stream test message that will be cancelled"


@pytest.mark.asyncio
async def test_stream_cancellation_with_attachments_preserves_bindings(test_session: AsyncSession):
    """Verify that committed user turn and attachment bindings remain durable when stream is cancelled."""
    owner_id = "test-owner-cancel-2"
    conv_id = f"conv-{uuid.uuid4()}"
    conv = Conversation(id=conv_id, owner_id=owner_id, title="Test Cancellation with Attachments")
    test_session.add(conv)
    await test_session.commit()

    # Create active attachment in this conversation
    att_id = f"att-{uuid.uuid4()}"
    att = Attachment(
        id=att_id,
        owner_id=owner_id,
        conversation_id=conv_id,
        message_id=None,
        storage_filename=f"{att_id}.png",
        storage_path=f"attachments/{conv_id}/{att_id}.png",
        filename_display="screenshot.png",
        mime_type="image/png",
        size_bytes=1024,
        is_deleted=False,
    )
    test_session.add(att)
    await test_session.commit()

    prepared = await prepare_turn(
        db=test_session,
        conversation_id=conv_id,
        owner_id=owner_id,
        user_text="Describe this image please",
        attachment_ids=[att_id],
    )
    asst_id = prepared.assistant_message.id
    user_id = prepared.user_message.id

    lock = _get_lock(conv_id)
    await lock.acquire()

    provider = get_llm_provider()
    provider.get_status = AsyncMock(
        return_value=ModelStatusResponse(
            provider="mock",
            runtime_state=LLMRuntimeState.MODEL_READY,
            active_model="test-vision-model",
            context_size=4096,
        )
    )

    async def mock_cancelling_stream(messages):
        if False:
            yield "never"
        raise asyncio.CancelledError()

    provider.generate_stream = mock_cancelling_stream

    stream_gen = orchestrate_chat_stream(
        db=test_session,
        conversation_id=conv_id,
        user_text="Describe this image please",
        owner_id=owner_id,
        prepared_turn=prepared,
        conversation_lock=lock,
    )

    with pytest.raises(asyncio.CancelledError):
        async for _ in stream_gen:
            pass

    # Verify attachment is still permanently claimed by the user message
    factory = async_sessionmaker(bind=test_session.bind, class_=AsyncSession, expire_on_commit=False)
    async with factory() as verify_session:
        stmt = select(Attachment).where(Attachment.id == att_id)
        res = await verify_session.execute(stmt)
        saved_att = res.scalar_one_or_none()
        assert saved_att is not None
        assert saved_att.message_id == user_id
        assert saved_att.is_deleted is False

        # Verify assistant message terminal state
        asst_stmt = select(Message).where(Message.id == asst_id)
        asst_res = await verify_session.execute(asst_stmt)
        asst_msg = asst_res.scalar_one_or_none()
        assert asst_msg is not None
        assert asst_msg.status == "cancelled"


@pytest.mark.asyncio
async def test_db_session_pool_healthy_after_cancellation(test_session: AsyncSession):
    """Verify connection pool remains healthy and usable by subsequent requests after stream cancellation."""
    owner_id = "test-owner-cancel-3"
    conv_id = f"conv-{uuid.uuid4()}"
    conv = Conversation(id=conv_id, owner_id=owner_id, title="Test Pool Health")
    test_session.add(conv)
    await test_session.commit()

    prepared = await prepare_turn(
        db=test_session,
        conversation_id=conv_id,
        owner_id=owner_id,
        user_text="Trigger cancellation",
    )

    lock = _get_lock(conv_id)
    await lock.acquire()

    provider = get_llm_provider()
    provider.get_status = AsyncMock(
        return_value=ModelStatusResponse(
            provider="mock",
            runtime_state=LLMRuntimeState.MODEL_READY,
            active_model="test-model",
            context_size=4096,
        )
    )

    async def mock_cancelling_stream(messages):
        if False:
            yield "never"
        raise asyncio.CancelledError()

    provider.generate_stream = mock_cancelling_stream

    stream_gen = orchestrate_chat_stream(
        db=test_session,
        conversation_id=conv_id,
        user_text="Trigger cancellation",
        owner_id=owner_id,
        prepared_turn=prepared,
        conversation_lock=lock,
    )

    with pytest.raises(asyncio.CancelledError):
        async for _ in stream_gen:
            pass

    # Now perform multiple subsequent write and read transactions on fresh sessions
    # This proves the pool was not corrupted by the cancellation
    factory = async_sessionmaker(bind=test_session.bind, class_=AsyncSession, expire_on_commit=False)
    for i in range(3):
        async with factory() as session:
            test_msg = Message(
                id=f"msg-post-cancel-{i}-{uuid.uuid4()}",
                conversation_id=conv_id,
                owner_id=owner_id,
                sender="user",
                content=f"Subsequent message {i}",
                status="completed",
                sequence_no=100 + i,
            )
            session.add(test_msg)
            await session.commit()

            # Read back
            check = await session.execute(select(Message).where(Message.id == test_msg.id))
            assert check.scalar_one_or_none() is not None


@pytest.mark.asyncio
async def test_request_session_commit_cancelled_persists_via_isolated_session(test_session: AsyncSession):
    """Verify that if request-scoped session raises CancelledError, terminal status is still persisted."""
    owner_id = "test-owner-req-cancel"
    conv_id = f"conv-{uuid.uuid4()}"
    conv = Conversation(id=conv_id, owner_id=owner_id, title="Test Request Cancelled")
    test_session.add(conv)
    await test_session.commit()

    prepared = await prepare_turn(
        db=test_session,
        conversation_id=conv_id,
        owner_id=owner_id,
        user_text="User query for request cancel test",
    )
    asst_id = prepared.assistant_message.id
    user_id = prepared.user_message.id

    lock = _get_lock(conv_id)
    await lock.acquire()

    provider = get_llm_provider()
    provider.get_status = AsyncMock(
        return_value=ModelStatusResponse(
            provider="mock",
            runtime_state=LLMRuntimeState.MODEL_READY,
            active_model="test-model",
            context_size=4096,
        )
    )

    async def mock_cancelling_stream(messages):
        yield "Partial token before cancel "
        raise asyncio.CancelledError("Stream interrupted by client")

    provider.generate_stream = mock_cancelling_stream

    # Force request-scoped session commit and rollback to simulate CancelledError
    test_session.commit = AsyncMock(side_effect=asyncio.CancelledError("Request-scoped commit cancelled"))
    test_session.rollback = AsyncMock(side_effect=asyncio.CancelledError("Request-scoped rollback cancelled"))

    stream_gen = orchestrate_chat_stream(
        db=test_session,
        conversation_id=conv_id,
        user_text="User query for request cancel test",
        owner_id=owner_id,
        prepared_turn=prepared,
        conversation_lock=lock,
    )

    with pytest.raises(asyncio.CancelledError):
        async for _ in stream_gen:
            pass

    # Verify lock released
    assert not lock.locked()

    # Verify assistant placeholder reached terminal 'cancelled' via isolated session
    factory = async_sessionmaker(bind=test_session.bind, class_=AsyncSession, expire_on_commit=False)
    async with factory() as verify_session:
        stmt = select(Message).where(Message.id == asst_id)
        res = await verify_session.execute(stmt)
        asst_msg = res.scalar_one_or_none()
        assert asst_msg is not None
        assert asst_msg.status == "cancelled"
        assert asst_msg.content == "Partial token before cancel "

        # Verify user message remains durable
        user_stmt = select(Message).where(Message.id == user_id)
        user_res = await verify_session.execute(user_stmt)
        user_msg = user_res.scalar_one_or_none()
        assert user_msg is not None
        assert user_msg.status == "completed"


@pytest.mark.asyncio
async def test_stream_failure_path_isolated_persistence(test_session: AsyncSession):
    """Verify that failure path persists 'failed' status via isolated session and releases lock."""
    owner_id = "test-owner-stream-fail"
    conv_id = f"conv-{uuid.uuid4()}"
    conv = Conversation(id=conv_id, owner_id=owner_id, title="Test Stream Failure")
    test_session.add(conv)
    await test_session.commit()

    prepared = await prepare_turn(
        db=test_session,
        conversation_id=conv_id,
        owner_id=owner_id,
        user_text="User query for failure test",
    )
    asst_id = prepared.assistant_message.id
    user_id = prepared.user_message.id

    lock = _get_lock(conv_id)
    await lock.acquire()

    provider = get_llm_provider()
    provider.get_status = AsyncMock(
        return_value=ModelStatusResponse(
            provider="mock",
            runtime_state=LLMRuntimeState.MODEL_READY,
            active_model="test-model",
            context_size=4096,
        )
    )

    async def mock_failing_stream(messages):
        yield "Initial chunk "
        raise RuntimeError("GPU Driver Crashed")

    provider.generate_stream = mock_failing_stream

    stream_gen = orchestrate_chat_stream(
        db=test_session,
        conversation_id=conv_id,
        user_text="User query for failure test",
        owner_id=owner_id,
        prepared_turn=prepared,
        conversation_lock=lock,
    )

    events = []
    async for event in stream_gen:
        events.append(event)

    # Should have emitted an error event
    assert any("MODEL_GENERATION_FAILED" in e for e in events)
    assert not lock.locked()

    factory = async_sessionmaker(bind=test_session.bind, class_=AsyncSession, expire_on_commit=False)
    async with factory() as verify_session:
        stmt = select(Message).where(Message.id == asst_id)
        res = await verify_session.execute(stmt)
        asst_msg = res.scalar_one_or_none()
        assert asst_msg is not None
        assert asst_msg.status == "failed"
        assert asst_msg.content == "Initial chunk "
