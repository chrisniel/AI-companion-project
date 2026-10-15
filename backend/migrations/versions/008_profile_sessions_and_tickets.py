"""Add Profile sessions/approval requests and require explicit personal-data ownership.

Revision ID: 008_profile_sessions_and_tickets
Revises: 007_profiles_and_owner_id_migration
"""

from alembic import op
import sqlalchemy as sa

revision = "008_profile_sessions_and_tickets"
down_revision = "007_profiles_and_owner_id_migration"
branch_labels = None
depends_on = None

PERSONAL_TABLES = ("conversations", "messages", "tasks", "attachments", "memories")


def upgrade() -> None:
    conn = op.get_bind()
    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError("Migration 008 refused: existing foreign key violations")

    # SQLite batch recreation drops table triggers. Preserve their existing definitions,
    # then rebuild the external-content FTS index to account for any rowid reassignment.
    triggers = conn.execute(sa.text(
        "SELECT name, sql FROM sqlite_master WHERE type='trigger' AND tbl_name='memories'"
    )).fetchall()
    for name, _ in triggers:
        op.execute('DROP TRIGGER "' + name.replace('"', '""') + '"')
    for table in PERSONAL_TABLES:
        with op.batch_alter_table(table) as batch:
            batch.alter_column("profile_id", existing_type=sa.String(36), existing_nullable=False, server_default=None)
    for _, sql in triggers:
        op.execute(sql)
    op.execute("INSERT INTO memories_fts(memories_fts) VALUES('rebuild')")

    op.create_table(
        "profile_sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("profile_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token_hash", sa.String(64), nullable=False),
        sa.Column("client_type", sa.String(32), nullable=False),
        sa.Column("client_identifier", sa.String(255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_active_at", sa.DateTime(timezone=True), nullable=False),
    )
    for column in ("id", "profile_id", "token_hash", "expires_at"):
        op.create_index(f"ix_profile_sessions_{column}", "profile_sessions", [column], unique=column == "token_hash")

    op.create_table(
        "session_tickets",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("ticket_hash", sa.String(64), nullable=True),
        sa.Column("profile_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=True),
        sa.Column("claim_secret_hash", sa.String(64), nullable=True),
        sa.Column("origin", sa.String(255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=True),
    )
    for column in ("id", "profile_id", "ticket_hash", "claim_secret_hash", "expires_at"):
        op.create_index(f"ix_session_tickets_{column}", "session_tickets", [column], unique=column == "ticket_hash")

    if conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall():
        raise RuntimeError("Foreign key violations detected after migration 008")


def downgrade() -> None:
    # A rollback retires sessions and grants, but must never revive ambient ownership.
    # Keep all five profile_id columns NOT NULL without SQL defaults.
    op.drop_table("session_tickets")
    op.drop_table("profile_sessions")
