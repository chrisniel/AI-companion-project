"""Pydantic schemas for Conversation management."""

from datetime import datetime
from typing import List, Optional
from pydantic import Field
from app.schemas.common import BaseSchema


class ConversationCreate(BaseSchema):
    """Payload to start a new persistent conversation."""
    title: Optional[str] = Field(default="New Conversation", max_length=255)
    character_id: Optional[str] = Field(default="default", max_length=64)


class ConversationUpdate(BaseSchema):
    """Payload to rename/update a conversation."""
    title: str = Field(..., min_length=1, max_length=255)


class ConversationOut(BaseSchema):
    """Conversation summary output."""
    id: str
    title: str
    character_id: str
    owner_id: str
    created_at: datetime
    updated_at: datetime


class ConversationListOut(BaseSchema):
    """Paginated or listed conversation response."""
    items: List[ConversationOut]
    total: int
