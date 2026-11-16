"""Pydantic schemas for Message persistence and streaming."""

from datetime import datetime
from typing import List, Optional
from pydantic import Field

from app.schemas.attachment import AttachmentRef
from app.schemas.common import BaseSchema
from app.schemas.tools import ToolConfirmationOut, ToolReceiptOut, WebSourceRefOut


class MessageSend(BaseSchema):
    """Payload sent by client to add a user message and trigger generation."""

    user_text: str = Field(..., min_length=1)
    client_message_id: Optional[str] = Field(default=None, max_length=64)
    attachment_ids: List[str] = Field(default_factory=list)


class MessageOut(BaseSchema):
    """Message detail response."""

    id: str
    conversation_id: str
    sender: str
    content: str
    status: str
    sequence_no: int
    client_message_id: Optional[str] = None
    model_name: Optional[str] = None
    prompt_tokens: Optional[int] = None
    completion_tokens: Optional[int] = None
    created_at: datetime
    attachments: List[AttachmentRef] = Field(default_factory=list)
    tool_receipts: List[ToolReceiptOut] = Field(default_factory=list)
    sources: List[WebSourceRefOut] = Field(default_factory=list)
    pending_confirmations: List[ToolConfirmationOut] = Field(default_factory=list)


class MessageListOut(BaseSchema):
    """Message collection for a conversation."""

    items: List[MessageOut]
    total: int
