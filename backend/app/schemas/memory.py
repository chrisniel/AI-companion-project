"""Pydantic schemas for Memory creation, listing, and updates."""

from datetime import datetime
import json
from typing import Any, List, Literal, Optional
from pydantic import Field, field_validator, model_validator
from app.schemas.common import BaseSchema


def _normalize_keywords(value: Any) -> Optional[List[str]]:
    """Normalize keyword list or JSON string into deduplicated lowercase terms."""
    if value is None:
        return None
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return None
        try:
            parsed = json.loads(raw)
            items = parsed if isinstance(parsed, list) else raw.split(",")
        except Exception:
            items = raw.split(",")
    elif isinstance(value, (list, tuple, set)):
        items = list(value)
    else:
        return None

    seen: set[str] = set()
    cleaned: List[str] = []
    for item in items:
        kw = str(item).strip().lower()
        if kw and kw not in seen:
            seen.add(kw)
            cleaned.append(kw)
    return cleaned or None


class MemoryCreate(BaseSchema):
    """Payload to insert a new memory record."""

    content: str = Field(..., min_length=1, max_length=1000)
    category: Literal["fact", "preference", "context"] = Field(default="fact")
    importance: float = Field(default=1.0, ge=0.0, le=2.0)
    scope: Literal["profile", "character"] = Field(default="profile")
    character_instance_id: Optional[str] = Field(default=None)
    valid_from: Optional[datetime] = Field(default=None)
    expires_at: Optional[datetime] = Field(default=None)
    is_core: bool = Field(default=False)
    trigger_keywords: Optional[List[str]] = Field(default=None)
    source_type: Literal["manual", "user_explicit"] = Field(default="manual")

    @field_validator("trigger_keywords", mode="before")
    @classmethod
    def validate_trigger_keywords(cls, value: Any) -> Optional[List[str]]:
        return _normalize_keywords(value)

    @model_validator(mode="after")
    def validate_scoping(self) -> "MemoryCreate":
        if self.scope == "character" and not self.character_instance_id:
            raise ValueError("character_instance_id is required when scope is 'character'")
        if self.scope == "profile" and self.character_instance_id:
            raise ValueError("character_instance_id must be null when scope is 'profile'")
        if self.expires_at and self.valid_from and self.expires_at < self.valid_from:
            raise ValueError("expires_at cannot be earlier than valid_from")
        return self


class MemoryUpdate(BaseSchema):
    """Payload to update an existing memory record."""

    content: Optional[str] = Field(default=None, min_length=1, max_length=1000)
    category: Optional[Literal["fact", "preference", "context"]] = None
    importance: Optional[float] = Field(default=None, ge=0.0, le=2.0)
    is_core: Optional[bool] = None
    expires_at: Optional[datetime] = None
    user_verified: Optional[bool] = None
    source_type: Optional[str] = None
    trigger_keywords: Optional[List[str]] = None

    @field_validator("trigger_keywords", mode="before")
    @classmethod
    def validate_trigger_keywords(cls, value: Any) -> Optional[List[str]]:
        return _normalize_keywords(value)


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
    profile_id: Optional[str] = None
    scope: str = "profile"
    character_instance_id: Optional[str] = None
    valid_from: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    last_verified_at: Optional[datetime] = None
    is_core: bool = False
    trigger_keywords: Optional[List[str]] = None
    recall_count: int = 0

    @field_validator("trigger_keywords", mode="before")
    @classmethod
    def parse_trigger_keywords(cls, value: Any) -> Optional[List[str]]:
        return _normalize_keywords(value)


class MemoryListOut(BaseSchema):
    """List of memories with pagination info and per-tier counts."""

    items: List[MemoryOut]
    total: int
    page: int = 1
    page_size: int = 50
    knowledge_count: int = 0
    long_term_count: int = 0
    short_term_count: int = 0
