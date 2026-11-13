"""Add trigger_keywords and recall_count columns to memories (Milestone M3 Batch E).

Revision ID: 013_memory_knowledge_and_triggers
Revises: 012_character_mood_and_emotion
"""

import json
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "013_memory_knowledge_and_triggers"
down_revision: Union[str, None] = "012_character_mood_and_emotion"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

naming_convention = {
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
    "ix": "ix_%(table_name)s_%(column_0_name)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
}


def _capture_and_drop_memories_triggers(conn: sa.Connection) -> list[tuple[str, str]]:
    """Capture and drop all triggers on `memories` before SQLite batch table recreation."""
    triggers = conn.execute(
        sa.text("SELECT name, sql FROM sqlite_master WHERE type='trigger' AND tbl_name='memories'")
    ).fetchall()
    for name, _ in triggers:
        escaped = name.replace('"', '""')
        op.execute(f'DROP TRIGGER IF EXISTS "{escaped}"')
    return [(str(name), str(sql)) for name, sql in triggers if sql]


def _restore_memories_triggers_and_rebuild_fts(triggers: list[tuple[str, str]]) -> None:
    """Restore captured `memories` triggers and rebuild external-content FTS5 index."""
    for _, sql in triggers:
        op.execute(sql)
    op.execute("INSERT INTO memories_fts(memories_fts) VALUES('rebuild');")


def upgrade() -> None:
    conn = op.get_bind()
    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(f"Migration 013 refused: existing foreign key violations ({violations})")

    triggers = _capture_and_drop_memories_triggers(conn)

    with op.batch_alter_table("memories", naming_convention=naming_convention) as batch_op:
        batch_op.add_column(sa.Column("trigger_keywords", sa.Text(), nullable=True))
        batch_op.add_column(
            sa.Column("recall_count", sa.Integer(), nullable=False, server_default="0")
        )
        batch_op.create_check_constraint(
            "ck_memories_recall_count",
            "recall_count >= 0",
        )

    _restore_memories_triggers_and_rebuild_fts(triggers)

    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(f"Foreign key violations detected after migration 013: {violations}")


def downgrade() -> None:
    conn = op.get_bind()

    non_empty_keywords = conn.execute(
        sa.text("SELECT COUNT(*) FROM memories WHERE trigger_keywords IS NOT NULL")
    ).scalar_one()
    if non_empty_keywords:
        raise RuntimeError(
            "Migration 013 downgrade refused: trigger_keywords data exists and would be lost"
        )

    non_zero_recalls = conn.execute(
        sa.text("SELECT COUNT(*) FROM memories WHERE recall_count > 0")
    ).scalar_one()
    if non_zero_recalls:
        raise RuntimeError(
            "Migration 013 downgrade refused: positive recall_count metrics exist and would be lost"
        )

    triggers = _capture_and_drop_memories_triggers(conn)

    with op.batch_alter_table("memories", naming_convention=naming_convention) as batch_op:
        batch_op.drop_constraint("ck_memories_recall_count", type_="check")
        batch_op.drop_column("recall_count")
        batch_op.drop_column("trigger_keywords")

    _restore_memories_triggers_and_rebuild_fts(triggers)

    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(f"Foreign key violations detected after migration 013 downgrade: {violations}")
