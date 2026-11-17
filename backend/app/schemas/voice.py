"""Pydantic v2 schemas for M4 Batch B Voice runtime, settings, dictation, and synthesis."""

from datetime import datetime
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


BargeInPolicyId = Literal["smart_auto", "strict_noisy", "manual_only"]
VadSensitivityId = Literal["low", "medium", "high"]
AudioPayloadFormat = Literal["wav", "pcm16"]


class VoiceDescriptorOut(BaseModel):
    """Metadata describing one locally discoverable TTS voice."""

    model_config = ConfigDict(extra="forbid")

    voice_id: str
    name: str
    provider: str
    language: str
    sample_rate: int


class VoiceCatalogOut(BaseModel):
    """List of available local TTS voices."""

    model_config = ConfigDict(extra="forbid")

    voices: list[VoiceDescriptorOut]


class VoiceStatusOut(BaseModel):
    """Truthful runtime readiness status across STT, VAD, and TTS subsystems."""

    model_config = ConfigDict(extra="forbid")

    stt_available: bool
    stt_provider: str
    stt_model: Optional[str] = None
    stt_unavailable_reason: Optional[str] = None
    vad_available: bool
    vad_provider: str
    tts_available: bool
    tts_provider: str
    tts_unavailable_reason: Optional[str] = None
    cpu_first: bool = True
    active_voice_sessions: int = 0


class VoiceSettingsOut(BaseModel):
    """Per-Profile voice behavior, barge-in, and privacy preferences."""

    model_config = ConfigDict(from_attributes=True, extra="forbid")

    profile_id: str
    barge_in_policy: BargeInPolicyId
    vad_sensitivity: VadSensitivityId
    stt_language: str
    tts_speed: float = Field(..., ge=0.5, le=2.0)
    default_voice_id: str
    auto_read_replies: bool
    proactive_speech_enabled: bool
    cloud_stt_enabled: bool
    cloud_tts_enabled: bool
    updated_at: datetime


class VoiceSettingsUpdate(BaseModel):
    """Partial update payload for PATCH /api/v1/voice/settings."""

    model_config = ConfigDict(extra="forbid")

    barge_in_policy: Optional[BargeInPolicyId] = None
    vad_sensitivity: Optional[VadSensitivityId] = None
    stt_language: Optional[str] = Field(default=None, min_length=1, max_length=16)
    tts_speed: Optional[float] = Field(default=None, ge=0.5, le=2.0)
    default_voice_id: Optional[str] = Field(default=None, min_length=1, max_length=64)
    auto_read_replies: Optional[bool] = None
    proactive_speech_enabled: Optional[bool] = None
    cloud_stt_enabled: Optional[bool] = None
    cloud_tts_enabled: Optional[bool] = None

    @field_validator("stt_language", "default_voice_id")
    @classmethod
    def strip_non_empty(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Value must not be empty")
        return cleaned


class VoiceTranscribeRequest(BaseModel):
    """Bounded ephemeral audio transcription request (never written to disk)."""

    model_config = ConfigDict(extra="forbid")

    audio_base64: str = Field(..., min_length=4, max_length=2_000_000)
    format: AudioPayloadFormat = "wav"
    sample_rate: int = Field(default=16000, ge=8000, le=48000)
    language: Optional[str] = Field(default=None, max_length=16)


class VoiceTranscribeOut(BaseModel):
    """Ephemeral STT transcription response."""

    model_config = ConfigDict(extra="forbid")

    text: str
    language: str
    duration_ms: int
    provider: str


class VoiceSynthesizeRequest(BaseModel):
    """Bounded speech synthesis request for Read Aloud and Auto-Read replies."""

    model_config = ConfigDict(extra="forbid")

    text: str = Field(..., min_length=1, max_length=2000)
    voice_id: Optional[str] = Field(default=None, min_length=1, max_length=64)
    speed: Optional[float] = Field(default=None, ge=0.5, le=2.0)

    @field_validator("text")
    @classmethod
    def require_non_blank_text(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Text to synthesize must not be blank")
        return cleaned


class VoiceSynthesizeOut(BaseModel):
    """In-memory synthesized WAV audio payload."""

    model_config = ConfigDict(extra="forbid")

    audio_base64: str
    mime_type: str = "audio/wav"
    sample_rate: int
    duration_ms: int
    voice_id: str
    provider: str
