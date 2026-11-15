"""Add per-reminder center_popup and task reminder_center_popup columns.

Revision ID: 016_reminder_center_popup
Revises: 015_scheduler_notifications_and_routines
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "016_reminder_center_popup"
down_revision: Union[str, None] = "015_scheduler_notifications_and_routines"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "reminders",
        sa.Column(
            "center_popup",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("1"),
        ),
    )
    op.add_column(
        "tasks",
        sa.Column(
            "reminder_center_popup",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("1"),
        ),
    )


def downgrade() -> None:
    op.drop_column("tasks", "reminder_center_popup")
    op.drop_column("reminders", "center_popup")
