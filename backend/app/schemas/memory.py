"""Pydantic schemas for Memory creation, listing, and updates."""

from datetime import datetime
from typing import List, Literal, Optional
from pydantic import Field
from app.schemas.common import BaseSchema


class MemoryCreate(BaseSchema):
    """Payload to insert a new memory record."""
    content: str = Field(..., min_length=1)
    category: Literal["fact", "preference", "context"] = Field(default="fact")
    importance: float = Field(default=1.0, ge=0.0, le=2.0)


class MemoryUpdate(BaseSchema):
    """Payload to update an existing memory record."""
    content: Optional[str] = Field(default=None, min_length=1)
    category: Optional[Literal["fact", "preference", "context"]] = None
    importance: Optional[float] = Field(default=None, ge=0.0, le=2.0)


class MemoryOut(BaseSchema):
    """Memory representation output."""
    id: str
    content: str
    category: str
    importance: float
    source_type: str
    user_verified: bool
    created_at: datetime
    owner_id: str


class MemoryListOut(BaseSchema):
    """List of memories with pagination info."""
    items: List[MemoryOut]
    total: int
    page: int = 1
    page_size: int = 50
