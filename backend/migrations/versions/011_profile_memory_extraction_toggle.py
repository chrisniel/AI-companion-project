"""Add memory_extraction_enabled toggle to profiles table.

Revision ID: 011_profile_memory_extraction_toggle
Revises: 010_memory_scoping_and_lifecycle
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "011_profile_memory_extraction_toggle"
down_revision: Union[str, None] = "010_memory_scoping_and_lifecycle"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TRIGGER_SQL = """
CREATE TRIGGER trg_character_instances_deactivate_clear_profile
AFTER UPDATE ON character_instances
WHEN NEW.status != 'active' OR NEW.is_deleted = 1
BEGIN
    UPDATE profiles SET active_character_instance_id = NULL
    WHERE id = NEW.profile_id AND active_character_instance_id = NEW.id;
END;
"""


def upgrade() -> None:
    # 1. Temporarily drop trigger referencing profiles during batch recreation
    op.execute("DROP TRIGGER IF EXISTS trg_character_instances_deactivate_clear_profile;")

    # 2. Add column to profiles
    with op.batch_alter_table("profiles") as batch_op:
        batch_op.add_column(
            sa.Column(
                "memory_extraction_enabled",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("1"),
            )
        )

    # 3. Restore trigger
    op.execute(TRIGGER_SQL)


def downgrade() -> None:
    # 1. Temporarily drop trigger referencing profiles during batch recreation
    op.execute("DROP TRIGGER IF EXISTS trg_character_instances_deactivate_clear_profile;")

    # 2. Remove column from profiles
    with op.batch_alter_table("profiles") as batch_op:
        batch_op.drop_column("memory_extraction_enabled")

    # 3. Restore trigger
    op.execute(TRIGGER_SQL)
