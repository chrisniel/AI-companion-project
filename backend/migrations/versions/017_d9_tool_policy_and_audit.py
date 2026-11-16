"""Add D9 tool policy, confirmations, audit tables, and messages.metadata_json.

Revision ID: 017_d9_tool_policy_and_audit
Revises: 016_reminder_center_popup
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "017_d9_tool_policy_and_audit"
down_revision: Union[str, None] = "016_reminder_center_popup"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "tool_runtime_config",
        sa.Column("id", sa.String(length=16), nullable=False),
        sa.Column("global_kill_switch", sa.Boolean(), server_default=sa.text("0"), nullable=False),
        sa.Column("kill_switch_updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("kill_switch_reason", sa.String(length=255), nullable=True),
        sa.Column("weather_provider", sa.String(length=32), server_default="open_meteo", nullable=False),
        sa.Column("web_search_provider", sa.String(length=32), server_default="public_search", nullable=False),
        sa.Column("searxng_base_url", sa.String(length=512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("id = 'default'", name="ck_tool_runtime_config_singleton_id"),
        sa.CheckConstraint("global_kill_switch IN (0, 1)", name="ck_tool_runtime_config_kill_bool"),
        sa.CheckConstraint(
            "weather_provider IN ('open_meteo', 'disabled')",
            name="ck_tool_runtime_config_weather_provider",
        ),
        sa.CheckConstraint(
            "web_search_provider IN ('public_search', 'searxng', 'tavily', 'brave', 'disabled')",
            name="ck_tool_runtime_config_web_search_provider",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "profile_tool_settings",
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("risk0_policy", sa.String(length=16), server_default="allow", nullable=False),
        sa.Column("risk1_explicit_policy", sa.String(length=16), server_default="allow", nullable=False),
        sa.Column("risk1_suggested_policy", sa.String(length=16), server_default="confirm", nullable=False),
        sa.Column("risk2_policy", sa.String(length=16), server_default="confirm", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("risk0_policy IN ('allow', 'confirm', 'deny')", name="ck_profile_tool_risk0"),
        sa.CheckConstraint("risk1_explicit_policy IN ('allow', 'confirm', 'deny')", name="ck_profile_tool_risk1_exp"),
        sa.CheckConstraint("risk1_suggested_policy IN ('confirm', 'deny')", name="ck_profile_tool_risk1_sug"),
        sa.CheckConstraint("risk2_policy IN ('confirm', 'deny')", name="ck_profile_tool_risk2"),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("profile_id"),
    )

    op.create_table(
        "tool_confirmations",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("conversation_id", sa.String(length=36), nullable=False),
        sa.Column("session_id", sa.String(length=64), nullable=False),
        sa.Column("tool_name", sa.String(length=64), nullable=False),
        sa.Column("risk_tier", sa.Integer(), nullable=False),
        sa.Column("provenance", sa.String(length=32), nullable=False),
        sa.Column("arguments_json", sa.Text(), nullable=False),
        sa.Column("target_summary", sa.String(length=255), server_default="", nullable=False),
        sa.Column("fingerprint", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=24), server_default="pending", nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("result_summary_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("risk_tier BETWEEN 0 AND 2", name="ck_tool_confirmations_risk_tier"),
        sa.CheckConstraint(
            "status IN ('pending', 'approved', 'rejected', 'expired', 'executed', 'failed', 'killed')",
            name="ck_tool_confirmations_status",
        ),
        sa.ForeignKeyConstraint(["conversation_id"], ["conversations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_tool_confirmations_id", "tool_confirmations", ["id"], unique=False)
    op.create_index("ix_tool_confirmations_profile_id", "tool_confirmations", ["profile_id"], unique=False)
    op.create_index("ix_tool_confirmations_conversation_id", "tool_confirmations", ["conversation_id"], unique=False)
    op.create_index("ix_tool_confirmations_session_id", "tool_confirmations", ["session_id"], unique=False)
    op.create_index("ix_tool_confirmations_tool_name", "tool_confirmations", ["tool_name"], unique=False)
    op.create_index("ix_tool_confirmations_status", "tool_confirmations", ["status"], unique=False)
    op.create_index("ix_tool_confirmations_expires_at", "tool_confirmations", ["expires_at"], unique=False)

    op.create_table(
        "tool_audit_logs",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("profile_id", sa.String(length=36), nullable=True),
        sa.Column("conversation_id", sa.String(length=36), nullable=True),
        sa.Column("tool_name", sa.String(length=64), nullable=False),
        sa.Column("risk_tier", sa.Integer(), nullable=False),
        sa.Column("provenance", sa.String(length=32), nullable=False),
        sa.Column("decision", sa.String(length=32), nullable=False),
        sa.Column("outcome_status", sa.String(length=32), nullable=False),
        sa.Column("duration_ms", sa.Integer(), nullable=True),
        sa.Column("source_domains_json", sa.Text(), nullable=True),
        sa.Column("error_code", sa.String(length=64), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("risk_tier BETWEEN 0 AND 2", name="ck_tool_audit_logs_risk_tier"),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_tool_audit_logs_id", "tool_audit_logs", ["id"], unique=False)
    op.create_index("ix_tool_audit_logs_profile_id", "tool_audit_logs", ["profile_id"], unique=False)
    op.create_index("ix_tool_audit_logs_conversation_id", "tool_audit_logs", ["conversation_id"], unique=False)
    op.create_index("ix_tool_audit_logs_tool_name", "tool_audit_logs", ["tool_name"], unique=False)
    op.create_index("ix_tool_audit_logs_created_at", "tool_audit_logs", ["created_at"], unique=False)

    op.add_column("messages", sa.Column("metadata_json", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("messages", "metadata_json")

    op.drop_index("ix_tool_audit_logs_created_at", table_name="tool_audit_logs")
    op.drop_index("ix_tool_audit_logs_tool_name", table_name="tool_audit_logs")
    op.drop_index("ix_tool_audit_logs_conversation_id", table_name="tool_audit_logs")
    op.drop_index("ix_tool_audit_logs_profile_id", table_name="tool_audit_logs")
    op.drop_index("ix_tool_audit_logs_id", table_name="tool_audit_logs")
    op.drop_table("tool_audit_logs")

    op.drop_index("ix_tool_confirmations_expires_at", table_name="tool_confirmations")
    op.drop_index("ix_tool_confirmations_status", table_name="tool_confirmations")
    op.drop_index("ix_tool_confirmations_tool_name", table_name="tool_confirmations")
    op.drop_index("ix_tool_confirmations_session_id", table_name="tool_confirmations")
    op.drop_index("ix_tool_confirmations_conversation_id", table_name="tool_confirmations")
    op.drop_index("ix_tool_confirmations_profile_id", table_name="tool_confirmations")
    op.drop_index("ix_tool_confirmations_id", table_name="tool_confirmations")
    op.drop_table("tool_confirmations")

    op.drop_table("profile_tool_settings")
    op.drop_table("tool_runtime_config")
