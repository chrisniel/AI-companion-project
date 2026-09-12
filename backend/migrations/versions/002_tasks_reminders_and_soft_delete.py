"""Add reminders, categories, and soft delete to tasks table.

Revision ID: 002_tasks_reminders_and_soft_delete
Revises: 001_initial_tasks_schema
Create Date: 2026-09-12 22:15:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "002_tasks_reminders_and_soft_delete"
down_revision: Union[str, None] = "001_initial_tasks_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("tasks") as batch_op:
        batch_op.add_column(
            sa.Column("category", sa.String(length=32), nullable=False, server_default="general")
        )
        batch_op.add_column(
            sa.Column("reminder_minutes_before", sa.Integer(), nullable=True)
        )
        batch_op.add_column(
            sa.Column("reminder_at", sa.DateTime(timezone=True), nullable=True)
        )
        batch_op.add_column(
            sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.false())
        )
        batch_op.add_column(
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True)
        )

    op.create_index("ix_tasks_category", "tasks", ["category"], unique=False)
    op.create_index("ix_tasks_reminder_at", "tasks", ["reminder_at"], unique=False)
    op.create_index("ix_tasks_is_deleted", "tasks", ["is_deleted"], unique=False)
    op.create_index("ix_tasks_deleted_at", "tasks", ["deleted_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_tasks_deleted_at", table_name="tasks")
    op.drop_index("ix_tasks_is_deleted", table_name="tasks")
    op.drop_index("ix_tasks_reminder_at", table_name="tasks")
    op.drop_index("ix_tasks_category", table_name="tasks")

    with op.batch_alter_table("tasks") as batch_op:
        batch_op.drop_column("deleted_at")
        batch_op.drop_column("is_deleted")
        batch_op.drop_column("reminder_at")
        batch_op.drop_column("reminder_minutes_before")
        batch_op.drop_column("category")
