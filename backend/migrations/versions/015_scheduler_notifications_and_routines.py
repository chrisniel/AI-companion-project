"""Add quiet hours profile settings, reminders, alarms, routines, and notification_events.

Revision ID: 015_scheduler_notifications_and_routines
Revises: 014_conversation_summaries_and_compaction
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "015_scheduler_notifications_and_routines"
down_revision: Union[str, None] = "014_conversation_summaries_and_compaction"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

PROFILE_TRIGGERS_TO_CYCLE = (
    "trg_character_instances_deactivate_clear_profile",
    "trg_profiles_active_character_owner_insert",
    "trg_profiles_active_character_owner_update",
)


def _drop_profile_triggers_and_partial_index() -> None:
    for trg in PROFILE_TRIGGERS_TO_CYCLE:
        op.execute(f"DROP TRIGGER IF EXISTS {trg};")
    op.execute("DROP INDEX IF EXISTS uq_profiles_single_default;")


def _restore_profile_triggers_and_partial_index() -> None:
    op.create_index(
        "uq_profiles_single_default",
        "profiles",
        ["is_default"],
        unique=True,
        sqlite_where=sa.text("is_default = 1"),
    )

    op.execute("""
        CREATE TRIGGER trg_profiles_active_character_owner_insert
        BEFORE INSERT ON profiles
        FOR EACH ROW
        WHEN NEW.active_character_instance_id IS NOT NULL
        BEGIN
            SELECT CASE
                WHEN NOT EXISTS (
                    SELECT 1 FROM character_instances ci
                    WHERE ci.id = NEW.active_character_instance_id
                      AND ci.profile_id = NEW.id
                      AND ci.status = 'active'
                      AND ci.is_deleted = 0
                      AND ci.is_legacy_placeholder = 0
                )
                THEN RAISE(ABORT, 'active_character_instance_id must reference an active, non-deleted, non-legacy CharacterInstance owned by the same Profile')
            END;
        END;
    """)

    op.execute("""
        CREATE TRIGGER trg_profiles_active_character_owner_update
        BEFORE UPDATE OF active_character_instance_id ON profiles
        FOR EACH ROW
        WHEN NEW.active_character_instance_id IS NOT NULL
        BEGIN
            SELECT CASE
                WHEN NOT EXISTS (
                    SELECT 1 FROM character_instances ci
                    WHERE ci.id = NEW.active_character_instance_id
                      AND ci.profile_id = NEW.id
                      AND ci.status = 'active'
                      AND ci.is_deleted = 0
                      AND ci.is_legacy_placeholder = 0
                )
                THEN RAISE(ABORT, 'active_character_instance_id must reference an active, non-deleted, non-legacy CharacterInstance owned by the same Profile')
            END;
        END;
    """)

    op.execute("""
        CREATE TRIGGER trg_character_instances_deactivate_clear_profile
        AFTER UPDATE ON character_instances
        WHEN NEW.status != 'active' OR NEW.is_deleted = 1
        BEGIN
            UPDATE profiles SET active_character_instance_id = NULL
            WHERE id = NEW.profile_id AND active_character_instance_id = NEW.id;
        END;
    """)


def upgrade() -> None:
    conn = op.get_bind()
    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(
            f"Migration 015 refused: existing foreign key violations ({violations})"
        )

    # Cycle dependent triggers & partial unique index cleanly around profiles alteration.
    _drop_profile_triggers_and_partial_index()
    with op.batch_alter_table("profiles") as batch_op:
        batch_op.add_column(
            sa.Column(
                "quiet_hours_enabled",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("0"),
            )
        )
        batch_op.add_column(
            sa.Column(
                "quiet_hours_start",
                sa.String(length=5),
                nullable=False,
                server_default="22:00",
            )
        )
        batch_op.add_column(
            sa.Column(
                "quiet_hours_end",
                sa.String(length=5),
                nullable=False,
                server_default="07:00",
            )
        )
        batch_op.add_column(
            sa.Column(
                "quiet_hours_timezone",
                sa.String(length=64),
                nullable=False,
                server_default="UTC",
            )
        )
    _restore_profile_triggers_and_partial_index()

    op.create_table(
        "reminders",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("owner_id", sa.String(length=64), nullable=False, server_default="local_user"),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("task_id", sa.String(length=36), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("timezone", sa.String(length=64), nullable=False, server_default="UTC"),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="scheduled"),
        sa.Column("snoozed_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("bypass_quiet_hours", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("origin", sa.String(length=32), nullable=False, server_default="host"),
        sa.Column("fired_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("acknowledged_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_reminders"),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"], name="fk_reminders_profile_id_profiles", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["task_id"], ["tasks.id"], name="fk_reminders_task_id_tasks", ondelete="SET NULL"),
    )
    op.create_index("ix_reminders_id", "reminders", ["id"], unique=False)
    op.create_index("ix_reminders_owner_id", "reminders", ["owner_id"], unique=False)
    op.create_index("ix_reminders_profile_id", "reminders", ["profile_id"], unique=False)
    op.create_index("ix_reminders_is_deleted", "reminders", ["is_deleted"], unique=False)
    op.create_index("ix_reminders_deleted_at", "reminders", ["deleted_at"], unique=False)
    op.create_index("ix_reminders_task_id", "reminders", ["task_id"], unique=False)
    op.create_index("ix_reminders_scheduled_at", "reminders", ["scheduled_at"], unique=False)
    op.create_index("ix_reminders_status", "reminders", ["status"], unique=False)
    op.create_index("ix_reminders_snoozed_until", "reminders", ["snoozed_until"], unique=False)

    op.create_table(
        "alarms",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("owner_id", sa.String(length=64), nullable=False, server_default="local_user"),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("label", sa.String(length=255), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("time_of_day", sa.String(length=5), nullable=True),
        sa.Column("recurrence_days", sa.String(length=64), nullable=True),
        sa.Column("timezone", sa.String(length=64), nullable=False, server_default="UTC"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="armed"),
        sa.Column("snoozed_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("bypass_quiet_hours", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        sa.Column("origin", sa.String(length=32), nullable=False, server_default="host"),
        sa.Column("last_fired_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("acknowledged_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_alarms"),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"], name="fk_alarms_profile_id_profiles", ondelete="CASCADE"),
    )
    op.create_index("ix_alarms_id", "alarms", ["id"], unique=False)
    op.create_index("ix_alarms_owner_id", "alarms", ["owner_id"], unique=False)
    op.create_index("ix_alarms_profile_id", "alarms", ["profile_id"], unique=False)
    op.create_index("ix_alarms_is_deleted", "alarms", ["is_deleted"], unique=False)
    op.create_index("ix_alarms_deleted_at", "alarms", ["deleted_at"], unique=False)
    op.create_index("ix_alarms_scheduled_at", "alarms", ["scheduled_at"], unique=False)
    op.create_index("ix_alarms_enabled", "alarms", ["enabled"], unique=False)
    op.create_index("ix_alarms_status", "alarms", ["status"], unique=False)
    op.create_index("ix_alarms_snoozed_until", "alarms", ["snoozed_until"], unique=False)

    op.create_table(
        "routines",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("owner_id", sa.String(length=64), nullable=False, server_default="local_user"),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("prompt_template", sa.Text(), nullable=True),
        sa.Column("fallback_message", sa.Text(), nullable=False),
        sa.Column("time_of_day", sa.String(length=5), nullable=False),
        sa.Column("recurrence_days", sa.String(length=64), nullable=True),
        sa.Column("timezone", sa.String(length=64), nullable=False, server_default="UTC"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        sa.Column("bypass_quiet_hours", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("next_run_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_run_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_status", sa.String(length=32), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_routines"),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"], name="fk_routines_profile_id_profiles", ondelete="CASCADE"),
    )
    op.create_index("ix_routines_id", "routines", ["id"], unique=False)
    op.create_index("ix_routines_owner_id", "routines", ["owner_id"], unique=False)
    op.create_index("ix_routines_profile_id", "routines", ["profile_id"], unique=False)
    op.create_index("ix_routines_is_deleted", "routines", ["is_deleted"], unique=False)
    op.create_index("ix_routines_deleted_at", "routines", ["deleted_at"], unique=False)
    op.create_index("ix_routines_enabled", "routines", ["enabled"], unique=False)
    op.create_index("ix_routines_next_run_at", "routines", ["next_run_at"], unique=False)

    op.create_table(
        "notification_events",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("owner_id", sa.String(length=64), nullable=False, server_default="local_user"),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source_type", sa.String(length=32), nullable=False),
        sa.Column("source_id", sa.String(length=36), nullable=False),
        sa.Column("urgency", sa.String(length=32), nullable=False, server_default="standard"),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("body", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False, server_default="unread"),
        sa.Column("delivery_policy", sa.String(length=32), nullable=False, server_default="immediate"),
        sa.Column("is_missed_catchup", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("triggered_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_notification_events"),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"], name="fk_notification_events_profile_id_profiles", ondelete="CASCADE"),
    )
    op.create_index("ix_notification_events_id", "notification_events", ["id"], unique=False)
    op.create_index("ix_notification_events_owner_id", "notification_events", ["owner_id"], unique=False)
    op.create_index("ix_notification_events_profile_id", "notification_events", ["profile_id"], unique=False)
    op.create_index("ix_notification_events_is_deleted", "notification_events", ["is_deleted"], unique=False)
    op.create_index("ix_notification_events_deleted_at", "notification_events", ["deleted_at"], unique=False)
    op.create_index("ix_notification_events_source_type", "notification_events", ["source_type"], unique=False)
    op.create_index("ix_notification_events_source_id", "notification_events", ["source_id"], unique=False)
    op.create_index("ix_notification_events_status", "notification_events", ["status"], unique=False)
    op.create_index("ix_notification_events_triggered_at", "notification_events", ["triggered_at"], unique=False)
    op.create_index(
        "ix_notification_events_dedup",
        "notification_events",
        ["profile_id", "source_type", "source_id", "triggered_at"],
        unique=False,
    )

    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(
            f"Foreign key violations detected after migration 015: {violations}"
        )


def downgrade() -> None:
    conn = op.get_bind()
    for table_name in ("notification_events", "routines", "alarms", "reminders"):
        row_count = conn.execute(sa.text(f"SELECT COUNT(*) FROM {table_name}")).scalar_one()
        if row_count:
            raise RuntimeError(
                f"Migration 015 downgrade refused: {table_name} rows exist and would be lost"
            )

    custom_qh_count = conn.execute(
        sa.text(
            "SELECT COUNT(*) FROM profiles "
            "WHERE quiet_hours_enabled != 0 "
            "OR quiet_hours_start != '22:00' "
            "OR quiet_hours_end != '07:00' "
            "OR quiet_hours_timezone != 'UTC'"
        )
    ).scalar_one()
    if custom_qh_count:
        raise RuntimeError(
            "Migration 015 downgrade refused: non-default profile quiet hours configuration would be lost"
        )

    for idx_name in (
        "ix_notification_events_dedup",
        "ix_notification_events_triggered_at",
        "ix_notification_events_status",
        "ix_notification_events_source_id",
        "ix_notification_events_source_type",
        "ix_notification_events_deleted_at",
        "ix_notification_events_is_deleted",
        "ix_notification_events_profile_id",
        "ix_notification_events_owner_id",
        "ix_notification_events_id",
    ):
        op.drop_index(idx_name, table_name="notification_events")
    op.drop_table("notification_events")

    for idx_name in (
        "ix_routines_next_run_at",
        "ix_routines_enabled",
        "ix_routines_deleted_at",
        "ix_routines_is_deleted",
        "ix_routines_profile_id",
        "ix_routines_owner_id",
        "ix_routines_id",
    ):
        op.drop_index(idx_name, table_name="routines")
    op.drop_table("routines")

    for idx_name in (
        "ix_alarms_snoozed_until",
        "ix_alarms_status",
        "ix_alarms_enabled",
        "ix_alarms_scheduled_at",
        "ix_alarms_deleted_at",
        "ix_alarms_is_deleted",
        "ix_alarms_profile_id",
        "ix_alarms_owner_id",
        "ix_alarms_id",
    ):
        op.drop_index(idx_name, table_name="alarms")
    op.drop_table("alarms")

    for idx_name in (
        "ix_reminders_snoozed_until",
        "ix_reminders_status",
        "ix_reminders_scheduled_at",
        "ix_reminders_task_id",
        "ix_reminders_deleted_at",
        "ix_reminders_is_deleted",
        "ix_reminders_profile_id",
        "ix_reminders_owner_id",
        "ix_reminders_id",
    ):
        op.drop_index(idx_name, table_name="reminders")
    op.drop_table("reminders")

    _drop_profile_triggers_and_partial_index()
    with op.batch_alter_table("profiles") as batch_op:
        batch_op.drop_column("quiet_hours_timezone")
        batch_op.drop_column("quiet_hours_end")
        batch_op.drop_column("quiet_hours_start")
        batch_op.drop_column("quiet_hours_enabled")
    _restore_profile_triggers_and_partial_index()

    violations = conn.execute(sa.text("PRAGMA foreign_key_check")).fetchall()
    if violations:
        raise RuntimeError(
            f"Foreign key violations detected after migration 015 downgrade: {violations}"
        )
