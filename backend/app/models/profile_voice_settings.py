"""ProfileVoiceSettings SQLAlchemy ORM model (M4 Batch B — Voice Pipeline)."""

from sqlalchemy import Boolean, CheckConstraint, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.base import TimestampMixin


class ProfileVoiceSettings(Base, TimestampMixin):
    """Per-Profile voice synthesis, VAD sensitivity, barge-in, and policy preferences."""

    __tablename__ = "profile_voice_settings"
    __table_args__ = (
        CheckConstraint(
            "barge_in_policy IN ('smart_auto', 'strict_noisy', 'manual_only')",
            name="ck_profile_voice_barge_in_policy",
        ),
        CheckConstraint(
            "vad_sensitivity IN ('low', 'medium', 'high')",
            name="ck_profile_voice_vad_sensitivity",
        ),
        CheckConstraint(
            "tts_speed BETWEEN 0.5 AND 2.0",
            name="ck_profile_voice_tts_speed",
        ),
        CheckConstraint(
            "auto_read_replies IN (0, 1)",
            name="ck_profile_voice_auto_read_bool",
        ),
        CheckConstraint(
            "proactive_speech_enabled IN (0, 1)",
            name="ck_profile_voice_proactive_bool",
        ),
        CheckConstraint(
            "cloud_stt_enabled IN (0, 1)",
            name="ck_profile_voice_cloud_stt_bool",
        ),
        CheckConstraint(
            "cloud_tts_enabled IN (0, 1)",
            name="ck_profile_voice_cloud_tts_bool",
        ),
    )

    profile_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("profiles.id", ondelete="CASCADE"),
        primary_key=True,
    )
    barge_in_policy: Mapped[str] = mapped_column(
        String(24),
        nullable=False,
        default="smart_auto",
        server_default="smart_auto",
    )
    vad_sensitivity: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="medium",
        server_default="medium",
    )
    stt_language: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="auto",
        server_default="auto",
    )
    tts_speed: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=1.0,
        server_default="1.0",
    )
    default_voice_id: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        default="af_nicole",
        server_default="af_nicole",
    )
    auto_read_replies: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="0",
    )
    proactive_speech_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="0",
    )
    cloud_stt_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="0",
    )
    cloud_tts_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="0",
    )
