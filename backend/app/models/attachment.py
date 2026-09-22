"""Attachment SQLAlchemy ORM model definition."""

from typing import Optional, TYPE_CHECKING
from sqlalchemy import ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import OwnerMixin, SoftDeleteMixin, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.conversation import Conversation
    from app.models.message import Message


class Attachment(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin):
    """Uploaded image attachment associated with a conversation and optional message."""

    __tablename__ = "attachments"
    __table_args__ = (
        Index("ix_attachments_staged_created", "message_id", "created_at"),
    )

    message_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("messages.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    conversation_id: Mapped[str] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    filename_display: Mapped[str] = mapped_column(String(255), nullable=False)
    storage_filename: Mapped[str] = mapped_column(String(128), nullable=False)
    storage_path: Mapped[str] = mapped_column(String(512), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(64), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    image_width: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    image_height: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    message: Mapped[Optional["Message"]] = relationship("Message", back_populates="attachments")
    conversation: Mapped["Conversation"] = relationship("Conversation", back_populates="attachments")

    def __repr__(self) -> str:
        return (
            f"<Attachment id={self.id!r} filename={self.filename_display!r} "
            f"mime={self.mime_type!r} conversation_id={self.conversation_id!r} "
            f"message_id={self.message_id!r} is_deleted={self.is_deleted}>"
        )
