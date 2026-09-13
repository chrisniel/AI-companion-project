"""Scope message unique constraints to conversation.

Revision ID: 005_scope_message_constraints
Revises: 004_add_soft_delete_columns
Create Date: 2026-09-14 04:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "005_scope_message_constraints"
down_revision: Union[str, None] = "004_add_soft_delete_columns"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

naming_convention = {
    "uq": "uq_%(table_name)s_%(column_0_name)s",
}


def upgrade() -> None:
    # Rebuild messages table on SQLite to drop the global unique constraint on
    # client_message_id and add conversation-scoped composite unique constraints.
    with op.batch_alter_table("messages", naming_convention=naming_convention) as batch_op:
        batch_op.drop_constraint("uq_messages_client_message_id", type_="unique")
        batch_op.create_unique_constraint(
            "uq_messages_conversation_sequence",
            ["conversation_id", "sequence_no"],
        )
        batch_op.create_unique_constraint(
            "uq_messages_conversation_client_message_id",
            ["conversation_id", "client_message_id"],
        )


def downgrade() -> None:
    with op.batch_alter_table("messages", naming_convention=naming_convention) as batch_op:
        batch_op.drop_constraint("uq_messages_conversation_client_message_id", type_="unique")
        batch_op.drop_constraint("uq_messages_conversation_sequence", type_="unique")
        batch_op.create_unique_constraint("uq_messages_client_message_id", ["client_message_id"])
