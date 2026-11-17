"""Add profile_voice_settings and nullable character_instances.voice_id.

Revision ID: 018_voice_settings_and_character_voice
Revises: 017_d9_tool_policy_and_audit
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "018_voice_settings_and_character_voice"
down_revision: Union[str, None] = "017_d9_tool_policy_and_audit"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "profile_voice_settings",
        sa.Column("profile_id", sa.String(length=36), nullable=False),
        sa.Column("barge_in_policy", sa.String(length=24), server_default="smart_auto", nullable=False),
        sa.Column("vad_sensitivity", sa.String(length=16), server_default="medium", nullable=False),
        sa.Column("stt_language", sa.String(length=16), server_default="auto", nullable=False),
        sa.Column("tts_speed", sa.Float(), server_default="1.0", nullable=False),
        sa.Column("default_voice_id", sa.String(length=64), server_default="af_nicole", nullable=False),
        sa.Column("auto_read_replies", sa.Boolean(), server_default=sa.text("0"), nullable=False),
        sa.Column("proactive_speech_enabled", sa.Boolean(), server_default=sa.text("0"), nullable=False),
        sa.Column("cloud_stt_enabled", sa.Boolean(), server_default=sa.text("0"), nullable=False),
        sa.Column("cloud_tts_enabled", sa.Boolean(), server_default=sa.text("0"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "barge_in_policy IN ('smart_auto', 'strict_noisy', 'manual_only')",
            name="ck_profile_voice_barge_in_policy",
        ),
        sa.CheckConstraint(
            "vad_sensitivity IN ('low', 'medium', 'high')",
            name="ck_profile_voice_vad_sensitivity",
        ),
        sa.CheckConstraint(
            "tts_speed BETWEEN 0.5 AND 2.0",
            name="ck_profile_voice_tts_speed",
        ),
        sa.CheckConstraint("auto_read_replies IN (0, 1)", name="ck_profile_voice_auto_read_bool"),
        sa.CheckConstraint("proactive_speech_enabled IN (0, 1)", name="ck_profile_voice_proactive_bool"),
        sa.CheckConstraint("cloud_stt_enabled IN (0, 1)", name="ck_profile_voice_cloud_stt_bool"),
        sa.CheckConstraint("cloud_tts_enabled IN (0, 1)", name="ck_profile_voice_cloud_tts_bool"),
        sa.ForeignKeyConstraint(["profile_id"], ["profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("profile_id"),
    )

    op.execute(
        """
        INSERT OR IGNORE INTO profile_voice_settings (profile_id)
        SELECT id FROM profiles
        """
    )

    # Direct ADD COLUMN avoids SQLite table rebuild so character_instances triggers remain intact.
    op.add_column(
        "character_instances",
        sa.Column("voice_id", sa.String(length=64), nullable=True),
    )


def downgrade() -> None:
    # Direct DROP COLUMN preserves character_instances triggers cleanly without batch rebuild.
    op.drop_column("character_instances", "voice_id")
    op.drop_table("profile_voice_settings")
