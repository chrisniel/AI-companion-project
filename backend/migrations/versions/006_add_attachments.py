"""Add attachments table and indexes for multimodal images.

Revision ID: 006_add_attachments
Revises: 005_scope_message_constraints
Create Date: 2026-09-22 16:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "006_add_attachments"
down_revision: Union[str, None] = "005_scope_message_constraints"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "attachments",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("owner_id", sa.String(64), nullable=False),
        sa.Column(
            "message_id",
            sa.String(36),
            sa.ForeignKey("messages.id", ondelete="CASCADE"),
            nullable=True,
        ),
        sa.Column(
            "conversation_id",
            sa.String(36),
            sa.ForeignKey("conversations.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("filename_display", sa.String(255), nullable=False),
        sa.Column("storage_filename", sa.String(128), nullable=False),
        sa.Column("storage_path", sa.String(512), nullable=False),
        sa.Column("mime_type", sa.String(64), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("image_width", sa.Integer(), nullable=True),
        sa.Column("image_height", sa.Integer(), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    op.create_index("ix_attachments_id", "attachments", ["id"], unique=False)
    op.create_index("ix_attachments_owner_id", "attachments", ["owner_id"], unique=False)
    op.create_index("ix_attachments_message_id", "attachments", ["message_id"], unique=False)
    op.create_index("ix_attachments_conversation_id", "attachments", ["conversation_id"], unique=False)
    op.create_index("ix_attachments_is_deleted", "attachments", ["is_deleted"], unique=False)
    op.create_index("ix_attachments_deleted_at", "attachments", ["deleted_at"], unique=False)
    op.create_index("ix_attachments_staged_created", "attachments", ["message_id", "created_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_attachments_staged_created", table_name="attachments")
    op.drop_index("ix_attachments_deleted_at", table_name="attachments")
    op.drop_index("ix_attachments_is_deleted", table_name="attachments")
    op.drop_index("ix_attachments_conversation_id", table_name="attachments")
    op.drop_index("ix_attachments_message_id", table_name="attachments")
    op.drop_index("ix_attachments_owner_id", table_name="attachments")
    op.drop_index("ix_attachments_id", table_name="attachments")
    op.drop_table("attachments")
