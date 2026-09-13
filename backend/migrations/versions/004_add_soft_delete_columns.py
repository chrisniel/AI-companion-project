"""Add soft delete columns and indexes to conversations, messages, and memories.

Revision ID: 004_add_soft_delete_columns
Revises: 003_conversations_messages_and_fts5_memory
Create Date: 2026-09-14 04:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "004_add_soft_delete_columns"
down_revision: Union[str, None] = "003_conversations_messages_and_fts5_memory"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "conversations",
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_index("ix_conversations_is_deleted", "conversations", ["is_deleted"], unique=False)
    op.create_index("ix_conversations_deleted_at", "conversations", ["deleted_at"], unique=False)

    op.add_column(
        "messages",
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_index("ix_messages_is_deleted", "messages", ["is_deleted"], unique=False)
    op.create_index("ix_messages_deleted_at", "messages", ["deleted_at"], unique=False)

    op.add_column(
        "memories",
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_index("ix_memories_is_deleted", "memories", ["is_deleted"], unique=False)
    op.create_index("ix_memories_deleted_at", "memories", ["deleted_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_memories_deleted_at", table_name="memories")
    op.drop_index("ix_memories_is_deleted", table_name="memories")
    op.drop_column("memories", "is_deleted")

    op.drop_index("ix_messages_deleted_at", table_name="messages")
    op.drop_index("ix_messages_is_deleted", table_name="messages")
    op.drop_column("messages", "is_deleted")

    op.drop_index("ix_conversations_deleted_at", table_name="conversations")
    op.drop_index("ix_conversations_is_deleted", table_name="conversations")
    op.drop_column("conversations", "is_deleted")
