"""Pydantic schemas and limits for image attachments."""

from datetime import datetime
from typing import Optional
from pydantic import Field

from app.schemas.common import BaseSchema

# Canonical attachment constraints (Phase 8B locked decisions)
ALLOWED_MIME_TYPES: frozenset[str] = frozenset({"image/png", "image/jpeg"})
MAX_SIZE_BYTES: int = 10 * 1024 * 1024       # 10 MiB raw file ceiling (10,485,760 bytes)
MAX_PIXEL_DIMENSION: int = 8192               # Maximum width or height in pixels
MAX_MEGAPIXELS: float = 32.0                  # 32.0 Megapixels (32,000,000 pixels)
MAX_ATTACHMENTS_PER_MESSAGE: int = 4         # Ceiling per conversation turn


class AttachmentOut(BaseSchema):
    """Public detail schema for an attachment record.

    CRITICAL INVARIANT: storage_path MUST NEVER appear in public API schemas.
    """

    id: str
    conversation_id: str
    message_id: Optional[str] = None
    filename_display: str
    mime_type: str
    size_bytes: int
    image_width: Optional[int] = None
    image_height: Optional[int] = None
    created_at: datetime


class AttachmentRef(BaseSchema):
    """Lightweight reference embedded in message payloads."""

    id: str
    filename_display: str
    mime_type: str
    size_bytes: int
