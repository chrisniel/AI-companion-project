"""REST and duplex WebSocket endpoints for Local Voice Pipeline (/api/v1/voice/*)."""

import base64

from fastapi import APIRouter, Depends, HTTPException, WebSocket, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db
from app.core.profile_sessions import now_utc, validate_profile_session
from app.models.profile_session import ProfileSession
from app.schemas.voice import (
    VoiceCatalogOut,
    VoiceDescriptorOut,
    VoiceSettingsOut,
    VoiceSettingsUpdate,
    VoiceStatusOut,
    VoiceSynthesizeOut,
    VoiceSynthesizeRequest,
    VoiceTranscribeOut,
    VoiceTranscribeRequest,
)
from app.services.voice.audio_utils import MAX_TRANSCRIBE_WAV_BYTES, AudioFormatError, decode_audio_to_pcm16
from app.services.voice.manager import get_voice_manager
from app.services.voice.session_orchestrator import (
    VoiceSessionOrchestrator,
    get_or_create_profile_voice_settings,
    resolve_effective_voice_id,
)

router = APIRouter(prefix="/voice", tags=["Voice"])


@router.get(
    "/status",
    response_model=VoiceStatusOut,
    summary="Get Voice Pipeline Status",
)
async def get_voice_status(
    session: ProfileSession = Depends(get_current_profile_session),
) -> VoiceStatusOut:
    """Return truthful readiness telemetry for STT, VAD, and TTS subsystems."""
    vm = get_voice_manager()
    stt = vm.get_stt()
    vad = vm.get_vad()
    tts = vm.get_tts()
    return VoiceStatusOut(
        stt_available=stt.is_available(),
        stt_provider=stt.name,
        stt_model=stt.model_label,
        stt_unavailable_reason=stt.unavailable_reason,
        vad_available=vad.is_available(),
        vad_provider=vad.name,
        tts_available=tts.is_available(),
        tts_provider=tts.name,
        tts_unavailable_reason=tts.unavailable_reason,
        cpu_first=True,
        active_voice_sessions=vm.active_session_count,
    )


@router.get(
    "/voices",
    response_model=VoiceCatalogOut,
    summary="List Available TTS Voices",
)
async def list_voices(
    session: ProfileSession = Depends(get_current_profile_session),
) -> VoiceCatalogOut:
    """List locally discovered TTS voice identifiers for Studio and Settings."""
    vm = get_voice_manager()
    voices = [
        VoiceDescriptorOut(
            voice_id=v.voice_id,
            name=v.name,
            provider=v.provider,
            language=v.language,
            sample_rate=v.sample_rate,
        )
        for v in vm.list_voices()
    ]
    return VoiceCatalogOut(voices=voices)


@router.get(
    "/settings",
    response_model=VoiceSettingsOut,
    summary="Get Profile Voice Settings",
)
async def get_voice_settings(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> VoiceSettingsOut:
    """Retrieve per-Profile voice, barge-in, and privacy preferences."""
    session = await validate_profile_session(db, session)
    row = await get_or_create_profile_voice_settings(db, session.profile_id)
    return VoiceSettingsOut.model_validate(row)


@router.patch(
    "/settings",
    response_model=VoiceSettingsOut,
    summary="Update Profile Voice Settings",
)
async def update_voice_settings(
    payload: VoiceSettingsUpdate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> VoiceSettingsOut:
    """Update per-Profile voice behavior and privacy settings."""
    session = await validate_profile_session(db, session)
    row = await get_or_create_profile_voice_settings(db, session.profile_id)
    fields = payload.model_fields_set

    if "barge_in_policy" in fields and payload.barge_in_policy is not None:
        row.barge_in_policy = payload.barge_in_policy
    if "vad_sensitivity" in fields and payload.vad_sensitivity is not None:
        row.vad_sensitivity = payload.vad_sensitivity
    if "stt_language" in fields and payload.stt_language is not None:
        row.stt_language = payload.stt_language
    if "tts_speed" in fields and payload.tts_speed is not None:
        row.tts_speed = payload.tts_speed
    if "default_voice_id" in fields and payload.default_voice_id is not None:
        row.default_voice_id = payload.default_voice_id
    if "auto_read_replies" in fields and payload.auto_read_replies is not None:
        row.auto_read_replies = payload.auto_read_replies
    if "proactive_speech_enabled" in fields and payload.proactive_speech_enabled is not None:
        row.proactive_speech_enabled = payload.proactive_speech_enabled
    if "cloud_stt_enabled" in fields and payload.cloud_stt_enabled is not None:
        row.cloud_stt_enabled = payload.cloud_stt_enabled
    if "cloud_tts_enabled" in fields and payload.cloud_tts_enabled is not None:
        row.cloud_tts_enabled = payload.cloud_tts_enabled

    row.updated_at = now_utc()
    await validate_profile_session(db, session)
    await db.commit()
    await db.refresh(row)
    return VoiceSettingsOut.model_validate(row)


@router.post(
    "/transcribe",
    response_model=VoiceTranscribeOut,
    summary="Transcribe Bounded Ephemeral Audio",
)
async def transcribe_audio(
    payload: VoiceTranscribeRequest,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> VoiceTranscribeOut:
    """Transcribe short dictation audio in RAM without writing raw audio to disk."""
    session = await validate_profile_session(db, session)
    vs = await get_or_create_profile_voice_settings(db, session.profile_id)

    try:
        raw = base64.b64decode(payload.audio_base64, validate=True)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Invalid base64 audio payload.",
        ) from None

    try:
        pcm, _ = decode_audio_to_pcm16(
            raw,
            expected_format=payload.format,
            sample_rate=payload.sample_rate,
            max_bytes=MAX_TRANSCRIBE_WAV_BYTES,
        )
    except AudioFormatError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=str(exc),
        ) from None

    vm = get_voice_manager()
    stt = vm.get_stt()
    if not stt.is_available():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=stt.unavailable_reason or "Local STT engine is unavailable.",
        )

    lang = payload.language or vs.stt_language or "auto"
    res = await stt.transcribe(pcm, language=lang)
    return VoiceTranscribeOut(
        text=res.text,
        language=res.language,
        duration_ms=res.duration_ms,
        provider=res.provider,
    )


@router.post(
    "/synthesize",
    response_model=VoiceSynthesizeOut,
    summary="Synthesize Text to In-Memory WAV",
)
async def synthesize_speech(
    payload: VoiceSynthesizeRequest,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> VoiceSynthesizeOut:
    """Synthesize speech in RAM resolving character override -> Profile default voice."""
    session = await validate_profile_session(db, session)
    vs = await get_or_create_profile_voice_settings(db, session.profile_id)
    voice_id = await resolve_effective_voice_id(
        db,
        profile_id=session.profile_id,
        explicit_voice_id=payload.voice_id,
    )
    speed = payload.speed if payload.speed is not None else vs.tts_speed

    vm = get_voice_manager()
    tts = vm.get_tts()
    if not tts.is_available():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=tts.unavailable_reason or "Local TTS engine is unavailable.",
        )

    res = await tts.synthesize(payload.text, voice_id=voice_id, speed=speed)
    return VoiceSynthesizeOut(
        audio_base64=base64.b64encode(res.wav_bytes).decode("ascii"),
        mime_type="audio/wav",
        sample_rate=res.sample_rate,
        duration_ms=res.duration_ms,
        voice_id=res.voice_id,
        provider=res.provider,
    )


@router.websocket("/ws")
async def voice_websocket(websocket: WebSocket) -> None:
    """Authenticated full-duplex WebSocket voice endpoint (no request-scoped DB session)."""
    orchestrator = VoiceSessionOrchestrator(websocket)
    await orchestrator.run()
