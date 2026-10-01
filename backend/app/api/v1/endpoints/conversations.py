"""Conversation & Message REST endpoints adhering to Master Plan §16, §34 (Track B5)."""

import asyncio
from datetime import datetime, timezone
import logging
import re
from typing import Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_owner, get_db
from app.core.config import settings
from app.models.attachment import Attachment
from app.models.base import utc_now
from app.models.conversation import Conversation
from app.models.message import Message
from app.schemas.attachment import AttachmentRef
from app.schemas.conversation import (
    ConversationCreate,
    ConversationListOut,
    ConversationOut,
    ConversationUpdate,
    GenerateTitleRequest,
)
from app.schemas.llm import ChatMessage
from app.schemas.message import MessageListOut, MessageOut, MessageSend
from app.services.assistant.orchestrator import (
    _get_lock,
    orchestrate_chat_stream,
    prepare_turn,
)
from app.services.attachment_service import validate_attachment_ids_syntax
from app.services.llm.base import BaseLLMProvider
from app.services.llm.manager import get_llm_provider
from app.services.llm.runtime_state import LLMRuntimeState

logger = logging.getLogger("app.api.v1.endpoints.conversations")


def sanitize_conversation_title(raw_title: Optional[str]) -> Optional[str]:
    """Sanitize model-generated conversation title.

    Enforces stripping quotes, markdown markers, prefixes, whitespace,
    and caps at 255 characters with a targeted concise word budget.
    """
    if not raw_title:
        return None
    text = raw_title.strip()
    # Strip markdown headers (# Title -> Title)
    text = re.sub(r"^#+\s*", "", text)
    # Strip bullets (- Title -> Title, * Title -> Title)
    text = re.sub(r"^[-*•]\s*", "", text)
    # Strip surrounding quotes and backticks (ASCII and Unicode curly/angle quotes)
    quote_chars = "\"'`“”‘’«»„”"
    text = text.strip(quote_chars)
    # Collapse internal whitespace and newlines
    text = re.sub(r"\s+", " ", text).strip()
    text = text.strip(quote_chars)
    # Remove common model conversational prefixes
    text = re.sub(r"^(Title|Topic|Subject):\s*", "", text, flags=re.IGNORECASE)
    text = text.strip(quote_chars).strip()

    if not text or len(text) < 2:
        return None

    words = text.split()
    # Keep concise 3-8 word target, ceiling at 10 words
    if len(words) > 10:
        text = " ".join(words[:8])
    if len(text) > 255:
        text = text[:255].strip()
    return text


async def _get_conversation_message_count(db: AsyncSession, conversation_id: str) -> int:
    """Return authoritative active message count for a conversation."""
    stmt = (
        select(func.count(Message.id))
        .where(
            Message.conversation_id == conversation_id,
            Message.deleted_at.is_(None),
        )
    )
    res = await db.execute(stmt)
    return res.scalar_one_or_none() or 0

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
    return ConversationOut(
        id=conversation.id,
        title=conversation.title,
        character_id=conversation.character_id,
        owner_id=conversation.owner_id,
        created_at=conversation.created_at,
        updated_at=conversation.updated_at,
        message_count=0,
    )


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
    """List active conversations for the authenticated owner with authoritative message counts."""
    base_query = select(Conversation).where(
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )

    count_query = select(func.count()).select_from(base_query.subquery())
    total_res = await db.execute(count_query)
    total = total_res.scalar_one_or_none() or 0

    msg_count_sub = (
        select(func.count(Message.id))
        .where(
            Message.conversation_id == Conversation.id,
            Message.deleted_at.is_(None),
        )
        .scalar_subquery()
    )

    items_query = (
        select(Conversation, msg_count_sub.label("message_count"))
        .where(
            Conversation.owner_id == owner_id,
            Conversation.deleted_at.is_(None),
        )
        .order_by(Conversation.updated_at.desc())
        .offset(skip)
        .limit(limit)
    )
    items_res = await db.execute(items_query)
    items = [
        ConversationOut(
            id=conv.id,
            title=conv.title,
            character_id=conv.character_id,
            owner_id=conv.owner_id,
            created_at=conv.created_at,
            updated_at=conv.updated_at,
            message_count=count or 0,
        )
        for conv, count in items_res.all()
    ]

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
    """Get single conversation by ID with authoritative message count."""
    msg_count_sub = (
        select(func.count(Message.id))
        .where(
            Message.conversation_id == Conversation.id,
            Message.deleted_at.is_(None),
        )
        .scalar_subquery()
    )
    query = (
        select(Conversation, msg_count_sub.label("message_count"))
        .where(
            Conversation.id == conversation_id,
            Conversation.owner_id == owner_id,
            Conversation.deleted_at.is_(None),
        )
    )
    result = await db.execute(query)
    row = result.one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Conversation not found")
    conv, count = row
    return ConversationOut(
        id=conv.id,
        title=conv.title,
        character_id=conv.character_id,
        owner_id=conv.owner_id,
        created_at=conv.created_at,
        updated_at=conv.updated_at,
        message_count=count or 0,
    )


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
    count = await _get_conversation_message_count(db, conversation_id)
    return ConversationOut(
        id=conversation.id,
        title=conversation.title,
        character_id=conversation.character_id,
        owner_id=conversation.owner_id,
        created_at=conversation.created_at,
        updated_at=conversation.updated_at,
        message_count=count,
    )


@router.post(
    "/{conversation_id}/generate-title",
    response_model=ConversationOut,
    summary="Generate Conversation Title",
)
async def generate_conversation_title(
    conversation_id: str,
    payload: Optional[GenerateTitleRequest] = None,
    owner_id: str = Depends(get_current_owner),
    provider: BaseLLMProvider = Depends(get_llm_provider),
    db: AsyncSession = Depends(get_db),
) -> ConversationOut:
    """Generate a concise title for a conversation using the active local model.

    Adheres strictly to Phase 8C rules:
    - Never overwrites custom/manually edited titles
    - Uses cheap bounded non-streaming inference (max_tokens=24, temp=0.1)
    - Enforces timeout, sanitization, and fallback
    - Never raises 500 error on model failure or unavailability
    """
    query = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )
    result = await db.execute(query)
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    message_count = await _get_conversation_message_count(db, conversation_id)

    # Manual edit protection: if the title is neither default "New Conversation" nor matches
    # current/fallback title provided by client, it was manually customized by the user.
    if payload and payload.current_title:
        is_untouched = (
            conversation.title == "New Conversation"
            or conversation.title == payload.current_title
            or (payload.fallback_title and conversation.title == payload.fallback_title)
        )
        if not is_untouched:
            return ConversationOut(
                id=conversation.id,
                title=conversation.title,
                character_id=conversation.character_id,
                owner_id=conversation.owner_id,
                created_at=conversation.created_at,
                updated_at=conversation.updated_at,
                message_count=message_count,
            )

    # Query the first user message
    user_msg_stmt = (
        select(Message)
        .where(
            Message.conversation_id == conversation_id,
            Message.sender == "user",
            Message.deleted_at.is_(None),
        )
        .order_by(Message.sequence_no.asc())
        .limit(1)
    )
    user_msg_res = await db.execute(user_msg_stmt)
    first_user_msg = user_msg_res.scalar_one_or_none()

    if not first_user_msg:
        # No user query to name from
        return ConversationOut(
            id=conversation.id,
            title=conversation.title,
            character_id=conversation.character_id,
            owner_id=conversation.owner_id,
            created_at=conversation.created_at,
            updated_at=conversation.updated_at,
            message_count=message_count,
        )

    sanitized_title: Optional[str] = None
    try:
        model_status = await provider.get_status()
        if model_status.model_loaded and model_status.model_awake:
            user_content = first_user_msg.content.strip()[:240]
            prompt_messages = [
                ChatMessage(
                    role="system",
                    content=(
                        "You are a conversation title generator. Create a short, concise 3 to 8 word title "
                        "for this conversation based on the user's initial query. "
                        "Respond ONLY with the title. Do not include quotes, markdown formatting, or preamble."
                    ),
                ),
                ChatMessage(
                    role="user",
                    content=f"User query: {user_content}\n\nTitle:",
                ),
            ]
            raw_title = await asyncio.wait_for(
                provider.generate(
                    messages=prompt_messages,
                    temperature=0.1,
                    max_tokens=24,
                ),
                timeout=5.0,
            )
            sanitized_title = sanitize_conversation_title(raw_title)
    except Exception as e:
        logger.debug("Automatic title generation skipped or failed: %s", e)

    allowed_titles = {"New Conversation"}
    if payload and payload.current_title:
        allowed_titles.add(payload.current_title)
    if payload and payload.fallback_title:
        allowed_titles.add(payload.fallback_title)

    if sanitized_title:
        # Atomic conditional update: only overwrite if title is still in allowed_titles
        update_stmt = (
            update(Conversation)
            .where(
                Conversation.id == conversation_id,
                Conversation.owner_id == owner_id,
                Conversation.deleted_at.is_(None),
                Conversation.title.in_(allowed_titles),
            )
            .values(title=sanitized_title)
        )
        await db.execute(update_stmt)
        await db.commit()
    elif payload and payload.fallback_title:
        update_stmt = (
            update(Conversation)
            .where(
                Conversation.id == conversation_id,
                Conversation.owner_id == owner_id,
                Conversation.deleted_at.is_(None),
                Conversation.title == "New Conversation",
            )
            .values(title=payload.fallback_title[:255])
        )
        await db.execute(update_stmt)
        await db.commit()

    # Re-fetch authoritative row from DB to return exact title (preserving any concurrent user rename)
    refresh_stmt = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )
    refreshed_res = await db.execute(refresh_stmt)
    current_conv = refreshed_res.scalar_one_or_none() or conversation

    return ConversationOut(
        id=current_conv.id,
        title=current_conv.title,
        character_id=current_conv.character_id,
        owner_id=current_conv.owner_id,
        created_at=current_conv.created_at,
        updated_at=current_conv.updated_at,
        message_count=message_count,
    )


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
    """Soft-delete a conversation and cascade soft-delete to all its active child attachments."""
    query = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.owner_id == owner_id,
        Conversation.deleted_at.is_(None),
    )
    result = await db.execute(query)
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    now = utc_now()

    # 1. Bulk soft-delete ALL active attachments belonging to this conversation
    # Note: No owner_id filter here; all child attachments of this conversation must soft-delete
    cascade_stmt = (
        update(Attachment)
        .where(
            Attachment.conversation_id == conversation_id,
            Attachment.is_deleted.is_(False),
        )
        .values(
            is_deleted=True,
            deleted_at=now,
        )
    )
    await db.execute(cascade_stmt)

    # 2. Soft-delete parent conversation
    conversation.is_deleted = True
    conversation.deleted_at = now
    try:
        await db.commit()
    except Exception:
        await db.rollback()
        raise


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

    output_items: list[MessageOut] = []
    for msg in items:
        active_refs = [
            AttachmentRef(
                id=att.id,
                filename_display=att.filename_display,
                mime_type=att.mime_type,
                size_bytes=att.size_bytes,
            )
            for att in msg.attachments
            if not att.is_deleted and att.message_id == msg.id
        ]
        output_items.append(
            MessageOut(
                id=msg.id,
                conversation_id=msg.conversation_id,
                sender=msg.sender,
                content=msg.content,
                status=msg.status,
                sequence_no=msg.sequence_no,
                client_message_id=msg.client_message_id,
                model_name=msg.model_name,
                prompt_tokens=msg.prompt_tokens,
                completion_tokens=msg.completion_tokens,
                created_at=msg.created_at,
                attachments=active_refs,
            )
        )

    return MessageListOut(items=output_items, total=total)


@router.post(
    "/{conversation_id}/messages",
    summary="Send Message & Stream Response",
    responses={
        200: {"content": {"text/event-stream": {}}, "description": "SSE Token Stream"},
        400: {"description": "Bad Request"},
        403: {"description": "ATTACHMENT_FORBIDDEN"},
        404: {"description": "Conversation or Attachment not found"},
        409: {"description": "CONVERSATION_BUSY or DUPLICATE_MESSAGE"},
        422: {"description": "ATTACHMENT_NOT_AVAILABLE or ATTACHMENT_ALREADY_CLAIMED"},
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

    # Pre-flight 2: Attachment input validation (pure validation before DB lock)
    validate_attachment_ids_syntax(payload.attachment_ids)

    # Pre-flight 3: Idempotency check (scoped to conversation)
    if payload.client_message_id:
        dup_query = select(Message).where(
            Message.conversation_id == conversation_id,
            Message.client_message_id == payload.client_message_id,
            Message.owner_id == owner_id,
        )
        if (await db.execute(dup_query)).scalar_one_or_none():
            raise HTTPException(status_code=409, detail="DUPLICATE_MESSAGE")

    # Pre-flight 4: Conversation concurrency lock
    lock = _get_lock(conversation_id)
    if lock.locked():
        raise HTTPException(status_code=409, detail="CONVERSATION_BUSY")
    await lock.acquire()

    lock_transferred = False
    try:
        # Pre-flight 5: Check LLM provider availability
        provider = get_llm_provider()
        status_resp = await provider.get_status()
        if status_resp.runtime_state not in (
            LLMRuntimeState.MODEL_READY,
            LLMRuntimeState.MODEL_SLEEPING,
        ):
            loaded = await provider.load_model()
            if not loaded:
                raise HTTPException(status_code=503, detail="LLM_UNAVAILABLE")

        # Execute atomic pre-stream preparation transaction
        prepared_turn = await prepare_turn(
            db=db,
            conversation_id=conversation_id,
            owner_id=owner_id,
            user_text=payload.user_text,
            client_message_id=payload.client_message_id,
            attachment_ids=payload.attachment_ids,
        )

        stream = orchestrate_chat_stream(
            db=db,
            conversation_id=conversation_id,
            user_text=payload.user_text,
            owner_id=owner_id,
            prepared_turn=prepared_turn,
            conversation_lock=lock,
        )

        response = StreamingResponse(
            stream,
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )
        lock_transferred = True
        return response
    except Exception:
        if not lock_transferred and lock.locked():
            lock.release()
        raise
