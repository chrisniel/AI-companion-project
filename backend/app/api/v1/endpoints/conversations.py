"""Conversation & Message REST endpoints adhering to Master Plan §16, §34 (Track B5)."""

from datetime import datetime, timezone
import logging
from typing import Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_owner, get_db
from app.core.config import settings
from app.models.conversation import Conversation
from app.models.message import Message
from app.schemas.conversation import (
    ConversationCreate,
    ConversationListOut,
    ConversationOut,
    ConversationUpdate,
)
from app.schemas.message import MessageListOut, MessageOut, MessageSend
from app.services.assistant.orchestrator import _get_lock, orchestrate_chat_stream
from app.services.llm.manager import get_llm_provider
from app.services.llm.runtime_state import LLMRuntimeState

logger = logging.getLogger("app.api.v1.endpoints.conversations")

router = APIRouter()


@router.post(
    "",
    response_model=ConversationOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create Conversation",
)
async def create_conversation(
    payload: Optional[ConversationCreate] = None,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> ConversationOut:
    """Create a new persistent conversation thread."""
    title = payload.title if payload and payload.title else "New Conversation"
    character_id = payload.character_id if payload and payload.character_id else "default"

    conversation = Conversation(
        id=str(uuid.uuid4()),
        title=title,
        character_id=character_id,
        owner_id=owner_id,
    )
    db.add(conversation)
    await db.commit()
    await db.refresh(conversation)
    return conversation


@router.get(
    "",
    response_model=ConversationListOut,
    summary="List Conversations",
)
async def list_conversations(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> ConversationListOut:
    """List active conversations for the authenticated owner, ordered by updated_at descending."""
    base_query = select(Conversation).where(
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )

    count_query = select(func.count()).select_from(base_query.subquery())
    total_res = await db.execute(count_query)
    total = total_res.scalar_one_or_none() or 0

    items_query = base_query.order_by(Conversation.updated_at.desc()).offset(skip).limit(limit)
    items_res = await db.execute(items_query)
    items = list(items_res.scalars().all())

    return ConversationListOut(items=items, total=total)


@router.get(
    "/{conversation_id}",
    response_model=ConversationOut,
    summary="Get Conversation",
)
async def get_conversation(
    conversation_id: str,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> ConversationOut:
    """Get single conversation by ID."""
    query = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )
    result = await db.execute(query)
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conversation


@router.patch(
    "/{conversation_id}",
    response_model=ConversationOut,
    summary="Rename Conversation",
)
async def rename_conversation(
    conversation_id: str,
    payload: ConversationUpdate,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> ConversationOut:
    """Rename a conversation title."""
    query = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )
    result = await db.execute(query)
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    conversation.title = payload.title
    await db.commit()
    await db.refresh(conversation)
    return conversation


@router.delete(
    "/{conversation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete Conversation",
)
async def delete_conversation(
    conversation_id: str,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Soft-delete a conversation."""
    query = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )
    result = await db.execute(query)
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    conversation.deleted_at = datetime.now(timezone.utc)
    await db.commit()


@router.get(
    "/{conversation_id}/messages",
    response_model=MessageListOut,
    summary="List Conversation Messages",
)
async def list_messages(
    conversation_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> MessageListOut:
    """List messages for a conversation ordered chronologically by sequence_no ASC."""
    conv_check = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )
    conv_res = await db.execute(conv_check)
    if not conv_res.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Conversation not found")

    query = select(Message).where(
        Message.conversation_id == conversation_id,
        Message.owner_id == owner_id,
        Message.deleted_at.is_(None),
    )

    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar_one_or_none() or 0

    items_query = query.order_by(Message.sequence_no.asc()).offset(skip).limit(limit)
    items = list((await db.execute(items_query)).scalars().all())

    return MessageListOut(items=items, total=total)


@router.post(
    "/{conversation_id}/messages",
    summary="Send Message & Stream Response",
    responses={
        200: {"content": {"text/event-stream": {}}, "description": "SSE Token Stream"},
        404: {"description": "Conversation not found"},
        409: {"description": "CONVERSATION_BUSY or DUPLICATE_MESSAGE"},
        503: {"description": "LLM_UNAVAILABLE"},
    },
)
async def send_message_stream(
    conversation_id: str,
    payload: MessageSend,
    owner_id: str = Depends(get_current_owner),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """Send user message and receive streaming assistant tokens via SSE."""
    # Pre-flight 1: Validate conversation
    conv_check = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )
    conv = (await db.execute(conv_check)).scalar_one_or_none()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    # Pre-flight 2: Idempotency check
    if payload.client_message_id:
        dup_query = select(Message).where(
            Message.client_message_id == payload.client_message_id,
            Message.owner_id == owner_id,
        )
        if (await db.execute(dup_query)).scalar_one_or_none():
            raise HTTPException(status_code=409, detail="DUPLICATE_MESSAGE")

    # Pre-flight 3: Conversation concurrency lock
    lock = _get_lock(conversation_id)
    if lock.locked():
        raise HTTPException(status_code=409, detail="CONVERSATION_BUSY")

    # Pre-flight 4: Check LLM provider availability
    provider = get_llm_provider()
    status_resp = await provider.get_status()
    if status_resp.runtime_state not in (
        LLMRuntimeState.MODEL_READY,
        LLMRuntimeState.MODEL_SLEEPING,
    ):
        # In mock or auto, try loading
        loaded = await provider.load_model()
        if not loaded:
            raise HTTPException(status_code=503, detail="LLM_UNAVAILABLE")

    stream = orchestrate_chat_stream(
        db=db,
        conversation_id=conversation_id,
        user_text=payload.user_text,
        owner_id=owner_id,
        client_message_id=payload.client_message_id,
    )

    return StreamingResponse(
        stream,
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
