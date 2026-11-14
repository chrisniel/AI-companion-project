"""Pydantic schemas for Conversation management."""

from datetime import datetime
from typing import List, Literal, Optional
from pydantic import Field
from app.schemas.common import BaseSchema


class ConversationCreate(BaseSchema):
    """Payload to start a new persistent conversation."""
    title: Optional[str] = Field(default="New Conversation", max_length=255)
    character_id: Optional[str] = Field(default=None, max_length=64)


class ConversationUpdate(BaseSchema):
    """Payload to rename/update a conversation."""
    title: str = Field(..., min_length=1, max_length=255)


class GenerateTitleRequest(BaseSchema):
    """Payload to request model-generated title with optional current and fallback titles."""
    current_title: Optional[str] = Field(default=None, max_length=255)
    fallback_title: Optional[str] = Field(default=None, max_length=255)


class ConversationOut(BaseSchema):
    """Conversation summary output."""
    id: str
    title: str
    character_id: str
    character_instance_id: Optional[str] = None
    owner_id: str
    created_at: datetime
    updated_at: datetime
    message_count: int = Field(default=0, description="Authoritative active message count")


class ConversationListOut(BaseSchema):
    """Paginated or listed conversation response."""
    items: List[ConversationOut]
    total: int


class ConversationSummaryOut(BaseSchema):
    """Serialized active rolling episode summary for a conversation."""

    id: str
    conversation_id: str
    summary_text: str
    from_sequence_no: int
    to_sequence_no: int
    compacted_message_count: int
    token_estimate: int
    source: Literal["auto", "manual", "extractive_fallback"]
    is_active: bool
    updated_at: datetime


class ConversationCompactRequest(BaseSchema):
    """Optional overrides when triggering manual conversation compaction."""

    keep_recent_messages: Optional[int] = Field(default=None, ge=0, le=50)
    force: bool = True


class ConversationCompactResponse(BaseSchema):
    """Result envelope for manual context compaction."""

    conversation_id: str
    compacted: bool
    reason: str
    summary: Optional[ConversationSummaryOut] = None
