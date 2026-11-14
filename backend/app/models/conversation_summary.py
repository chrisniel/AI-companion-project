"""ConversationSummary SQLAlchemy ORM model for rolling episode compaction."""

from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base
from app.models.base import (
    OwnerMixin,
    ProfileMixin,
    SoftDeleteMixin,
    TimestampMixin,
    UUIDPrimaryKeyMixin,
)

if TYPE_CHECKING:
    from app.models.conversation import Conversation


class ConversationSummary(
    Base,
    UUIDPrimaryKeyMixin,
    TimestampMixin,
    OwnerMixin,
    ProfileMixin,
    SoftDeleteMixin,
):
    """Rolling episode digest preserving continuity for older compacted turns.

    Raw `messages` rows are never deleted or overwritten by compaction, and
    compaction digests are kept separate from canonical `memories` records.
    """

    __tablename__ = "conversation_summaries"
    __table_args__ = (
        CheckConstraint("from_sequence_no >= 1", name="ck_conversation_summaries_from_seq"),
        CheckConstraint(
            "to_sequence_no >= from_sequence_no",
            name="ck_conversation_summaries_seq_range",
        ),
        CheckConstraint(
            "compacted_message_count >= 0",
            name="ck_conversation_summaries_msg_count",
        ),
        CheckConstraint(
            "token_estimate >= 0",
            name="ck_conversation_summaries_token_est",
        ),
        CheckConstraint(
            "source IN ('auto', 'manual', 'extractive_fallback')",
            name="ck_conversation_summaries_source",
        ),
        Index(
            "ix_conversation_summaries_conv_active",
            "conversation_id",
            "is_active",
            "is_deleted",
        ),
        Index(
            "uq_conversation_summaries_one_active",
            "conversation_id",
            unique=True,
            sqlite_where=text("is_active = 1 AND is_deleted = 0"),
        ),
    )

    conversation_id: Mapped[str] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    summary_text: Mapped[str] = mapped_column(Text, nullable=False)
    from_sequence_no: Mapped[int] = mapped_column(Integer, nullable=False)
    to_sequence_no: Mapped[int] = mapped_column(Integer, nullable=False)
    compacted_message_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
    token_estimate: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
    source: Mapped[str] = mapped_column(
        String(24),
        nullable=False,
        default="auto",
        server_default="auto",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("1"),
    )

    conversation: Mapped["Conversation"] = relationship("Conversation")

    def __repr__(self) -> str:
        return (
            f"<ConversationSummary id={self.id!r} conversation_id={self.conversation_id!r} "
            f"turns={self.from_sequence_no}..{self.to_sequence_no} "
            f"source={self.source!r} is_active={self.is_active}>"
        )
