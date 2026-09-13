"""003 - conversations, messages, and FTS5 memory

Revision ID: 003_conversations_messages_and_fts5_memory
Revises: 002_tasks_reminders_and_soft_delete
Create Date: 2026-09-13 21:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "003_conversations_messages_and_fts5_memory"
down_revision: Union[str, None] = "002_tasks_reminders_and_soft_delete"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "conversations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("owner_id", sa.String(36), nullable=False, index=True),
        sa.Column("title", sa.String(255), nullable=False, server_default="New Conversation"),
        sa.Column("character_id", sa.String(64), nullable=False, server_default="default"),
    )

    op.create_table(
        "messages",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("owner_id", sa.String(36), nullable=False, index=True),
        sa.Column(
            "conversation_id",
            sa.String(36),
            sa.ForeignKey("conversations.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("sender", sa.String(32), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("status", sa.String(32), nullable=False, server_default="completed"),
        sa.Column("sequence_no", sa.Integer(), nullable=False),
        sa.Column("client_message_id", sa.String(64), nullable=True, unique=True),
        sa.Column("model_name", sa.String(128), nullable=True),
        sa.Column("prompt_tokens", sa.Integer(), nullable=True),
        sa.Column("completion_tokens", sa.Integer(), nullable=True),
    )
    op.create_index("ix_messages_conv_seq", "messages", ["conversation_id", "sequence_no"])

    op.create_table(
        "memories",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("owner_id", sa.String(36), nullable=False, index=True),
        sa.Column("category", sa.String(32), nullable=False, server_default="fact"),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("importance", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column("source_type", sa.String(32), nullable=False, server_default="manual"),
        sa.Column("source_message_id", sa.String(36), nullable=True),
        sa.Column("user_verified", sa.Boolean(), nullable=False, server_default="1"),
    )

    # SQLite FTS5 Virtual Table and sync triggers
    op.execute("""
        CREATE VIRTUAL TABLE memories_fts USING fts5(
            id UNINDEXED,
            content,
            category,
            content='memories',
            content_rowid='rowid'
        );
    """)

    op.execute("""
        CREATE TRIGGER memories_fts_insert AFTER INSERT ON memories
        WHEN NEW.deleted_at IS NULL
        BEGIN
            INSERT INTO memories_fts(rowid, id, content, category)
            VALUES(NEW.rowid, NEW.id, NEW.content, NEW.category);
        END;
    """)

    op.execute("""
        CREATE TRIGGER memories_fts_update AFTER UPDATE ON memories
        BEGIN
            INSERT INTO memories_fts(memories_fts, rowid, id, content, category)
            VALUES('delete', OLD.rowid, OLD.id, OLD.content, OLD.category);
            INSERT INTO memories_fts(rowid, id, content, category)
            SELECT NEW.rowid, NEW.id, NEW.content, NEW.category
            WHERE NEW.deleted_at IS NULL;
        END;
    """)

    op.execute("""
        CREATE TRIGGER memories_fts_delete AFTER DELETE ON memories
        BEGIN
            INSERT INTO memories_fts(memories_fts, rowid, id, content, category)
            VALUES('delete', OLD.rowid, OLD.id, OLD.content, OLD.category);
        END;
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS memories_fts_delete;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_update;")
    op.execute("DROP TRIGGER IF EXISTS memories_fts_insert;")
    op.execute("DROP TABLE IF EXISTS memories_fts;")
    op.drop_table("memories")
    op.drop_table("messages")
    op.drop_table("conversations")
