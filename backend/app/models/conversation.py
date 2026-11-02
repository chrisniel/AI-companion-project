from typing import List, Optional, TYPE_CHECKING
from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.models.base import (
    UUIDPrimaryKeyMixin,
    TimestampMixin,
    OwnerMixin,
    ProfileMixin,
    SoftDeleteMixin,
)

if TYPE_CHECKING:
    from app.models.message import Message
    from app.models.attachment import Attachment


class Conversation(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, ProfileMixin, SoftDeleteMixin):
    """Persistent chat thread owned by a user."""
    __tablename__ = "conversations"

    title: Mapped[str] = mapped_column(String(255), nullable=False, default="New Conversation")
    character_id: Mapped[str] = mapped_column(String(64), nullable=False, default="default")
    character_instance_id: Mapped[Optional[str]] = mapped_column(
        String(64),
        ForeignKey("character_instances.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
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
