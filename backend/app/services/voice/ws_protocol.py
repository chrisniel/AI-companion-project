"""Typed WebSocket protocol envelopes and helpers for full-duplex PC/Mobile voice sessions."""

from typing import Any, Literal, Optional
from pydantic import BaseModel, ConfigDict, Field


VoiceClientMessageType = Literal[
    "session.start",
    "audio.chunk",
    "audio.commit",
    "barge_in",
    "config.update",
    "ping",
    "session.stop",
]


class VoiceClientFrame(BaseModel):
    """Inbound control/audio envelope sent by clients over WS /api/v1/voice/ws."""

    model_config = ConfigDict(extra="ignore")

    type: VoiceClientMessageType
    session_token: Optional[str] = None
    conversation_id: Optional[str] = None
    pcm16_base64: Optional[str] = None
    sample_rate: int = Field(default=16000, ge=8000, le=48000)
    reason: Optional[str] = None
    barge_in_policy: Optional[str] = None
    vad_sensitivity: Optional[str] = None
    voice_id: Optional[str] = None
    tts_speed: Optional[float] = Field(default=None, ge=0.5, le=2.0)
    stt_language: Optional[str] = None


def build_ws_frame(
    event_type: str,
    *,
    voice_session_id: Optional[str] = None,
    turn_id: Optional[int] = None,
    **fields: Any,
) -> dict[str, Any]:
    payload: dict[str, Any] = {"type": event_type}
    if voice_session_id is not None:
        payload["voice_session_id"] = voice_session_id
    if turn_id is not None:
        payload["turn_id"] = turn_id
    payload.update(fields)
    return payload
