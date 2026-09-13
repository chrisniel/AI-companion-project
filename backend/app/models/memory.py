from typing import Optional
from sqlalchemy import Boolean, Float, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base
from app.models.base import UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin


class Memory(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin):
    """User fact, preference, or context memory indexed in FTS5."""
    __tablename__ = "memories"

    category: Mapped[str] = mapped_column(String(32), nullable=False, default="fact")
    content: Mapped[str] = mapped_column(Text, nullable=False)
    importance: Mapped[float] = mapped_column(Float, nullable=False, default=1.0)
    source_type: Mapped[str] = mapped_column(String(32), nullable=False, default="manual")
    source_message_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    user_verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
