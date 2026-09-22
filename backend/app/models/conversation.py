from typing import List, TYPE_CHECKING
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.models.base import UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin

if TYPE_CHECKING:
    from app.models.message import Message
    from app.models.attachment import Attachment


class Conversation(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin):
    """Persistent chat thread owned by a user."""
    __tablename__ = "conversations"

    title: Mapped[str] = mapped_column(String(255), nullable=False, default="New Conversation")
    character_id: Mapped[str] = mapped_column(String(64), nullable=False, default="default")
    messages: Mapped[List["Message"]] = relationship(
        "Message",
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="Message.sequence_no",
    )
    attachments: Mapped[List["Attachment"]] = relationship(
        "Attachment",
        back_populates="conversation",
        cascade="all, delete-orphan",
    )
