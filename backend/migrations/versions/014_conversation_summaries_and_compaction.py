"""Create conversation_summaries table for Milestone M3 Batch F compaction.

Revision ID: 014_conversation_summaries_and_compaction
Revises: 013_memory_knowledge_and_triggers
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "014_conversation_summaries_and_compaction"
down_revision: Union[str, None] = "013_memory_knowledge_and_triggers"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(
            f"Migration 014 refused: existing foreign key violations ({violations})"
        )

    op.create_table(
        "conversation_summaries",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "owner_id",
            sa.String(length=64),
            nullable=False,
            server_default="local_user",
        ),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column(
            "is_deleted",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("conversation_id", sa.String(length=36), nullable=False),
        sa.Column("summary_text", sa.Text(), nullable=False),
        sa.Column("from_sequence_no", sa.Integer(), nullable=False),
        sa.Column("to_sequence_no", sa.Integer(), nullable=False),
        sa.Column(
            "compacted_message_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "token_estimate",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "source",
            sa.String(length=24),
            nullable=False,
            server_default="auto",
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("1"),
        ),
        sa.PrimaryKeyConstraint("id", name="pk_conversation_summaries"),
        sa.ForeignKeyConstraint(
            ["profile_id"],
            ["profiles.id"],
            name="fk_conversation_summaries_profile_id_profiles",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["conversation_id"],
            ["conversations.id"],
            name="fk_conversation_summaries_conversation_id_conversations",
            ondelete="CASCADE",
        ),
        sa.CheckConstraint(
            "from_sequence_no >= 1",
            name="ck_conversation_summaries_from_seq",
        ),
        sa.CheckConstraint(
            "to_sequence_no >= from_sequence_no",
            name="ck_conversation_summaries_seq_range",
        ),
        sa.CheckConstraint(
            "compacted_message_count >= 0",
            name="ck_conversation_summaries_msg_count",
        ),
        sa.CheckConstraint(
            "token_estimate >= 0",
            name="ck_conversation_summaries_token_est",
        ),
        sa.CheckConstraint(
            "source IN ('auto', 'manual', 'extractive_fallback')",
            name="ck_conversation_summaries_source",
        ),
    )

    op.create_index(
        "ix_conversation_summaries_profile_id",
        "conversation_summaries",
        ["profile_id"],
        unique=False,
    )
    op.create_index(
        "ix_conversation_summaries_conversation_id",
        "conversation_summaries",
        ["conversation_id"],
        unique=False,
    )
    op.create_index(
        "ix_conversation_summaries_conv_active",
        "conversation_summaries",
        ["conversation_id", "is_active", "is_deleted"],
        unique=False,
    )
    op.create_index(
        "uq_conversation_summaries_one_active",
        "conversation_summaries",
        ["conversation_id"],
        unique=True,
        sqlite_where=sa.text("is_active = 1 AND is_deleted = 0"),
    )

    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(
            f"Foreign key violations detected after migration 014: {violations}"
        )


def downgrade() -> None:
    conn = op.get_bind()
    existing_rows = conn.execute(
        sa.text("SELECT COUNT(*) FROM conversation_summaries")
    ).scalar_one()
    if existing_rows:
        raise RuntimeError(
            "Migration 014 downgrade refused: conversation_summaries rows exist and would be lost"
        )

    op.drop_index(
        "uq_conversation_summaries_one_active",
        table_name="conversation_summaries",
    )
    op.drop_index(
        "ix_conversation_summaries_conv_active",
        table_name="conversation_summaries",
    )
    op.drop_index(
        "ix_conversation_summaries_conversation_id",
        table_name="conversation_summaries",
    )
    op.drop_index(
        "ix_conversation_summaries_profile_id",
        table_name="conversation_summaries",
    )
    op.drop_table("conversation_summaries")

    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(
            f"Foreign key violations detected after migration 014 downgrade: {violations}"
        )
