"""Full-duplex WebSocket VoiceSessionOrchestrator with mandatory barge-in and D9 parity."""

import asyncio
import base64
from contextlib import aclosing, suppress
from dataclasses import dataclass
import json
import logging
from typing import Any, Optional
import uuid

from fastapi import HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.profile_sessions import token_hash, validate_profile_session
from app.db.session import get_session_factory
from app.models.character_instance import CharacterInstance
from app.models.conversation import Conversation
from app.models.profile import Profile
from app.models.profile_session import ProfileSession
from app.models.profile_voice_settings import ProfileVoiceSettings
from app.services.assistant.orchestrator import (
    _get_lock,
    orchestrate_chat_stream,
    prepare_turn,
)
from app.services.llm.manager import get_llm_provider
from app.services.llm.runtime_state import LLMRuntimeState
from app.services.voice.audio_utils import (
    MAX_TURN_AUDIO_BYTES,
    VAD_FRAME_BYTES,
    AudioFormatError,
    decode_audio_to_pcm16,
)
from app.services.voice.manager import VoiceManager, get_voice_manager
from app.services.voice.tts import TtsProvider
from app.services.voice.vad import BargeInGate
from app.services.voice.ws_protocol import VoiceClientFrame, build_ws_frame

logger = logging.getLogger("app.services.voice.session_orchestrator")


@dataclass
class _AuthenticatedVoiceContext:
    profile_session: ProfileSession
    conversation_id: str
    barge_in_policy: str
    vad_sensitivity: str
    stt_language: str
    tts_speed: float
    default_voice_id: str
    character_voice_id: Optional[str]


async def get_or_create_profile_voice_settings(
    db: AsyncSession,
    profile_id: str,
) -> ProfileVoiceSettings:
    """Return profile voice settings, lazily creating defaults when absent."""
    row = await db.get(ProfileVoiceSettings, profile_id)
    if row is None:
        row = ProfileVoiceSettings(profile_id=profile_id)
        db.add(row)
        await db.commit()
        await db.refresh(row)
    return row


async def resolve_effective_voice_id(
    db: AsyncSession,
    *,
    profile_id: str,
    explicit_voice_id: Optional[str] = None,
    conversation_id: Optional[str] = None,
) -> str:
    """Resolve explicit -> conversation/active character voice -> Profile default -> af_nicole."""
    if explicit_voice_id and explicit_voice_id.strip():
        return explicit_voice_id.strip()

    char_inst_id: Optional[str] = None
    if conversation_id:
        conv = await db.scalar(
            select(Conversation).where(
                Conversation.id == conversation_id,
                Conversation.profile_id == profile_id,
                Conversation.is_deleted.is_(False),
            )
        )
        if conv is not None:
            char_inst_id = conv.character_instance_id
    if char_inst_id is None:
        prof = await db.get(Profile, profile_id)
        if prof is not None:
            char_inst_id = prof.active_character_instance_id

    if char_inst_id:
        inst = await db.scalar(
            select(CharacterInstance).where(
                CharacterInstance.id == char_inst_id,
                CharacterInstance.profile_id == profile_id,
                CharacterInstance.is_deleted.is_(False),
            )
        )
        if inst is not None and inst.voice_id and inst.voice_id.strip():
            return inst.voice_id.strip()

    voice_settings = await get_or_create_profile_voice_settings(db, profile_id)
    return voice_settings.default_voice_id or "af_nicole"


async def _authenticate_ws_context(
    *,
    raw_token: str,
    conversation_id: str,
) -> tuple[Optional[_AuthenticatedVoiceContext], int, str]:
    """Validate ProfileSession and Conversation ownership using a short-lived DB session."""
    if not raw_token.startswith("psk_") or len(raw_token) > 256:
        return None, 4401, "Valid Profile session token is required"
    if not conversation_id or not conversation_id.strip():
        return None, 4404, "Conversation ID is required"

    factory = get_session_factory()
    async with factory() as db:
        session = await db.scalar(
            select(ProfileSession).where(ProfileSession.token_hash == token_hash(raw_token))
        )
        if session is None:
            return None, 4401, "Invalid Profile session"
        try:
            session = await validate_profile_session(db, session)
        except HTTPException:
            return None, 4401, "Inactive or revoked Profile session"

        conv = await db.scalar(
            select(Conversation).where(
                Conversation.id == conversation_id.strip(),
                Conversation.profile_id == session.profile_id,
                Conversation.deleted_at.is_(None),
            )
        )
        if conv is None:
            return None, 4404, "Conversation not found for authenticated Profile"

        vs = await get_or_create_profile_voice_settings(db, session.profile_id)
        effective_voice = await resolve_effective_voice_id(
            db,
            profile_id=session.profile_id,
            conversation_id=conv.id,
        )
        return (
            _AuthenticatedVoiceContext(
                profile_session=session,
                conversation_id=conv.id,
                barge_in_policy=vs.barge_in_policy,
                vad_sensitivity=vs.vad_sensitivity,
                stt_language=vs.stt_language,
                tts_speed=vs.tts_speed,
                default_voice_id=vs.default_voice_id,
                character_voice_id=effective_voice,
            ),
            0,
            "",
        )


def _extract_bearer_token(websocket: WebSocket) -> str:
    auth_header = websocket.headers.get("authorization", "")
    if auth_header.lower().startswith("bearer "):
        return auth_header[7:].strip()
    return ""


class VoiceSessionOrchestrator:
    """Manages one authenticated full-duplex voice WebSocket session."""

    def __init__(
        self,
        websocket: WebSocket,
        *,
        voice_manager: Optional[VoiceManager] = None,
    ) -> None:
        self.websocket = websocket
        self.voice_manager = voice_manager or get_voice_manager()
        self.voice_session_id = str(uuid.uuid4())
        self.profile_id: Optional[str] = None
        self.profile_session_id: Optional[str] = None
        self._profile_session: Optional[ProfileSession] = None
        self._conversation_id: Optional[str] = None

        self._send_lock = asyncio.Lock()
        self._turn_seq_lock = asyncio.Lock()
        self._pcm_buffer = bytearray()
        self._vad_remainder = bytearray()
        self._vad = self.voice_manager.create_turn_vad(sensitivity="medium")
        self._barge_in_gate = BargeInGate(vad=self._vad, policy="smart_auto", sensitivity="medium")

        self._language: str = "auto"
        self._tts_speed: float = 1.0
        self._voice_id: str = "af_nicole"

        self._active_turn_id: int = 0
        self._cancel_event: Optional[asyncio.Event] = None
        self._active_turn_task: Optional[asyncio.Task[Any]] = None
        self._closed: bool = False

    def clear_audio_buffers(self) -> None:
        """Guarantee ephemeral PCM audio buffers never linger in RAM."""
        self._pcm_buffer.clear()
        self._vad_remainder.clear()
        self._barge_in_gate.reset_hold()
        self._vad.reset()

    @property
    def buffered_audio_bytes(self) -> int:
        return len(self._pcm_buffer)

    async def _send_json(self, payload: dict[str, Any]) -> None:
        if self._closed:
            return
        async with self._send_lock:
            if not self._closed:
                await self.websocket.send_json(payload)

    async def force_close(self, *, code: int = 1001, reason: str = "closed") -> None:
        if self._closed:
            return
        await self._cancel_active_turn(reason=reason, emit_cancelled=False)
        self.clear_audio_buffers()
        self._closed = True
        with suppress(Exception):
            await self.websocket.close(code=code, reason=reason)

    async def _cancel_active_turn(self, *, reason: str, emit_cancelled: bool = True) -> None:
        task = self._active_turn_task
        cancel_ev = self._cancel_event
        old_turn_id = self._active_turn_id
        self._barge_in_gate.set_speaking(False)

        if cancel_ev is not None and not cancel_ev.is_set():
            cancel_ev.set()

        if task is not None and not task.done():
            task.cancel()
            with suppress(asyncio.CancelledError, asyncio.TimeoutError, Exception):
                await asyncio.wait_for(task, timeout=5.0)
        self._active_turn_task = None
        self._cancel_event = None

        if emit_cancelled and old_turn_id > 0:
            await self._send_json(
                build_ws_frame(
                    "turn.cancelled",
                    voice_session_id=self.voice_session_id,
                    turn_id=old_turn_id,
                    reason=reason,
                )
            )

    async def _speak_text_segment(
        self,
        *,
        tts: TtsProvider,
        text: str,
        turn_id: int,
        cancel_event: asyncio.Event,
        seq_counter: list[int],
    ) -> None:
        if not text.strip() or cancel_event.is_set() or turn_id != self._active_turn_id:
            return
        if not tts.is_available():
            return
        tts_res = await tts.synthesize(text, voice_id=self._voice_id, speed=self._tts_speed)
        if cancel_event.is_set() or turn_id != self._active_turn_id:
            return
        self._barge_in_gate.set_speaking(True, assistant_output_rms=0.04)
        seq = seq_counter[0]
        seq_counter[0] += 1
        await self._send_json(
            build_ws_frame(
                "tts.audio.chunk",
                voice_session_id=self.voice_session_id,
                turn_id=turn_id,
                seq=seq,
                sample_rate=tts_res.sample_rate,
                duration_ms=tts_res.duration_ms,
                voice_id=tts_res.voice_id,
                wav_base64=base64.b64encode(tts_res.wav_bytes).decode("ascii"),
            )
        )

    async def _execute_turn(self, *, pcm_audio: bytes, turn_id: int, cancel_event: asyncio.Event) -> None:
        try:
            await self._execute_turn_inner(pcm_audio=pcm_audio, turn_id=turn_id, cancel_event=cancel_event)
        except asyncio.CancelledError:
            raise
        except HTTPException as exc:
            await self._send_json(
                build_ws_frame(
                    "error",
                    voice_session_id=self.voice_session_id,
                    turn_id=turn_id,
                    code="HTTP_ERROR",
                    message=str(exc.detail),
                )
            )
        except Exception as exc:
            logger.exception("Unhandled error inside voice turn %s: %s", turn_id, exc)
            await self._send_json(
                build_ws_frame(
                    "error",
                    voice_session_id=self.voice_session_id,
                    turn_id=turn_id,
                    code="VOICE_TURN_FAILED",
                    message="Voice turn failed unexpectedly.",
                )
            )
        finally:
            self._barge_in_gate.set_speaking(False)

    async def _execute_turn_inner(self, *, pcm_audio: bytes, turn_id: int, cancel_event: asyncio.Event) -> None:
        stt = self.voice_manager.get_stt()
        tts = self.voice_manager.get_tts()
        assert self._profile_session is not None and self._conversation_id is not None

        if not stt.is_available():
            await self._send_json(
                build_ws_frame(
                    "error",
                    voice_session_id=self.voice_session_id,
                    turn_id=turn_id,
                    code="STT_UNAVAILABLE",
                    message=stt.unavailable_reason or "Local STT engine is unavailable.",
                )
            )
            return

        stt_res = await stt.transcribe(pcm_audio, language=self._language)
        if cancel_event.is_set() or turn_id != self._active_turn_id:
            return

        user_text = stt_res.text.strip()
        if not user_text:
            await self._send_json(
                build_ws_frame(
                    "tts.end",
                    voice_session_id=self.voice_session_id,
                    turn_id=turn_id,
                    finish_reason="empty_transcript",
                )
            )
            return

        provider = get_llm_provider()
        status_resp = await provider.get_status()
        if status_resp.runtime_state not in (
            LLMRuntimeState.MODEL_READY,
            LLMRuntimeState.MODEL_SLEEPING,
        ):
            loaded = await provider.load_model()
            if not loaded:
                code = (
                    "MODEL_SELECTION_REQUIRED"
                    if getattr(provider, "_last_error", None) == "MODEL_SELECTION_REQUIRED"
                    or status_resp.runtime_state == LLMRuntimeState.MODEL_SELECTION_REQUIRED
                    else "LLM_UNAVAILABLE"
                )
                await self._send_json(
                    build_ws_frame(
                        "error",
                        voice_session_id=self.voice_session_id,
                        turn_id=turn_id,
                        code=code,
                        message="No local LLM model is loaded for voice conversation.",
                    )
                )
                return

        lock = _get_lock(self._conversation_id)
        await lock.acquire()
        lock_transferred = False
        try:
            factory = get_session_factory()
            async with factory() as turn_db:
                prepared = await prepare_turn(
                    db=turn_db,
                    conversation_id=self._conversation_id,
                    profile_session=self._profile_session,
                    user_text=user_text,
                    client_message_id=None,
                    attachment_ids=None,
                )
                await self._send_json(
                    build_ws_frame(
                        "stt.final",
                        voice_session_id=self.voice_session_id,
                        turn_id=turn_id,
                        text=user_text,
                        language=stt_res.language,
                        message_id=prepared.user_message.id,
                    )
                )

                lock_transferred = True
                sentence_buf = ""
                seq_counter = [0]
                finish_reason = "stop"

                stream = orchestrate_chat_stream(
                    db=turn_db,
                    conversation_id=self._conversation_id,
                    user_text=user_text,
                    profile_session=self._profile_session,
                    prepared_turn=prepared,
                    conversation_lock=lock,
                )

                async with aclosing(stream):
                    async for raw_sse in stream:
                        if cancel_event.is_set() or turn_id != self._active_turn_id:
                            return
                        if not raw_sse.startswith("data: "):
                            continue
                        data_str = raw_sse[6:].strip()
                        if data_str == "[DONE]":
                            break
                        try:
                            event = json.loads(data_str)
                        except ValueError:
                            continue
                        ev_type = event.get("type")
                        if ev_type == "token":
                            piece = str(event.get("content") or "")
                            if piece:
                                sentence_buf += piece
                                await self._send_json(
                                    build_ws_frame(
                                        "llm.delta",
                                        voice_session_id=self.voice_session_id,
                                        turn_id=turn_id,
                                        content=piece,
                                    )
                                )
                                while any(p in sentence_buf for p in (". ", "! ", "? ", "\n")):
                                    cut = -1
                                    for sep in (". ", "! ", "? ", "\n"):
                                        idx = sentence_buf.find(sep)
                                        if idx != -1 and (cut == -1 or idx + len(sep) < cut):
                                            cut = idx + len(sep)
                                    if cut <= 0:
                                        break
                                    seg = sentence_buf[:cut].strip()
                                    sentence_buf = sentence_buf[cut:]
                                    await self._speak_text_segment(
                                        tts=tts,
                                        text=seg,
                                        turn_id=turn_id,
                                        cancel_event=cancel_event,
                                        seq_counter=seq_counter,
                                    )
                        elif ev_type == "tool_intent":
                            await self._send_json(
                                build_ws_frame(
                                    "tool.intent",
                                    voice_session_id=self.voice_session_id,
                                    turn_id=turn_id,
                                    tool_name=event.get("tool_name"),
                                    risk_tier=event.get("risk_tier"),
                                    provenance=event.get("provenance"),
                                    target_summary=event.get("target_summary"),
                                )
                            )
                        elif ev_type == "tool_result":
                            await self._send_json(
                                build_ws_frame(
                                    "tool.result",
                                    voice_session_id=self.voice_session_id,
                                    turn_id=turn_id,
                                    tool_name=event.get("tool_name"),
                                    decision=event.get("decision"),
                                    outcome_status=event.get("outcome_status"),
                                    summary=event.get("summary"),
                                    sources=event.get("sources", []),
                                )
                            )
                        elif ev_type == "tool_confirmation_required":
                            await self._send_json(
                                build_ws_frame(
                                    "tool.confirmation_required",
                                    voice_session_id=self.voice_session_id,
                                    turn_id=turn_id,
                                    confirmation=event.get("confirmation"),
                                )
                            )
                        elif ev_type == "done":
                            finish_reason = str(event.get("finish_reason") or "stop")
                        elif ev_type == "error":
                            finish_reason = "error"
                            await self._send_json(
                                build_ws_frame(
                                    "error",
                                    voice_session_id=self.voice_session_id,
                                    turn_id=turn_id,
                                    code=event.get("code") or "MODEL_GENERATION_FAILED",
                                    message=event.get("message") or "Generation failed.",
                                )
                            )
                            return

                if sentence_buf.strip() and not cancel_event.is_set() and turn_id == self._active_turn_id:
                    await self._speak_text_segment(
                        tts=tts,
                        text=sentence_buf.strip(),
                        turn_id=turn_id,
                        cancel_event=cancel_event,
                        seq_counter=seq_counter,
                    )

                self._barge_in_gate.set_speaking(False)
                if not cancel_event.is_set() and turn_id == self._active_turn_id:
                    await self._send_json(
                        build_ws_frame(
                            "tts.end",
                            voice_session_id=self.voice_session_id,
                            turn_id=turn_id,
                            finish_reason=finish_reason,
                        )
                    )
        except asyncio.CancelledError:
            raise
        except HTTPException as exc:
            await self._send_json(
                build_ws_frame(
                    "error",
                    voice_session_id=self.voice_session_id,
                    turn_id=turn_id,
                    code="HTTP_ERROR",
                    message=str(exc.detail),
                )
            )
        finally:
            if not lock_transferred and lock.locked():
                lock.release()
            self._barge_in_gate.set_speaking(False)

    async def _handle_pcm_chunk(self, pcm_bytes: bytes) -> None:
        max_turn_bytes = max(VAD_FRAME_BYTES, int(settings.VOICE_MAX_TURN_AUDIO_BYTES or MAX_TURN_AUDIO_BYTES))
        if len(self._pcm_buffer) + len(pcm_bytes) > max_turn_bytes:
            self._pcm_buffer.clear()
            await self._send_json(
                build_ws_frame(
                    "error",
                    voice_session_id=self.voice_session_id,
                    turn_id=self._active_turn_id,
                    code="AUDIO_BUFFER_LIMIT",
                    message="Turn audio buffer exceeded maximum allowed size and was reset.",
                )
            )
            return

        self._pcm_buffer.extend(pcm_bytes)
        self._vad_remainder.extend(pcm_bytes)

        while len(self._vad_remainder) >= VAD_FRAME_BYTES:
            frame_bytes = bytes(self._vad_remainder[:VAD_FRAME_BYTES])
            del self._vad_remainder[:VAD_FRAME_BYTES]
            if self._barge_in_gate.is_speaking:
                triggered = self._barge_in_gate.process_pcm16_frame(frame_bytes)
                if triggered:
                    # Keep only the interrupting speech slice that just fired barge-in.
                    self._pcm_buffer = bytearray(frame_bytes)
                    await self._cancel_active_turn(reason="vad_barge_in", emit_cancelled=True)
                    await self._send_json(
                        build_ws_frame(
                            "vad.state",
                            voice_session_id=self.voice_session_id,
                            turn_id=self._active_turn_id,
                            state="barge_in_triggered",
                        )
                    )
                    break

    async def _start_committed_turn(self) -> None:
        if not self._pcm_buffer:
            return
        async with self._turn_seq_lock:
            if self._active_turn_task is not None and not self._active_turn_task.done():
                await self._cancel_active_turn(reason="superseded_by_commit", emit_cancelled=True)
            if self._closed:
                return
            pcm_snapshot = bytes(self._pcm_buffer)
            self._pcm_buffer.clear()
            self._vad_remainder.clear()

            self._active_turn_id += 1
            turn_id = self._active_turn_id
            cancel_ev = asyncio.Event()
            self._cancel_event = cancel_ev
            self._active_turn_task = asyncio.create_task(
                self._execute_turn(pcm_audio=pcm_snapshot, turn_id=turn_id, cancel_event=cancel_ev)
            )

    async def run(self) -> None:
        """Accept WS handshake, authenticate fail-closed, and drive duplex turn loop."""
        await self.websocket.accept()
        header_token = _extract_bearer_token(self.websocket)

        try:
            first_msg = await asyncio.wait_for(self.websocket.receive_json(), timeout=5.0)
            start_frame = VoiceClientFrame.model_validate(first_msg)
        except Exception:
            await self.websocket.close(code=4401, reason="session.start frame required")
            return

        if start_frame.type != "session.start":
            await self.websocket.close(code=4401, reason="First frame must be session.start")
            return

        raw_token = (start_frame.session_token or header_token or "").strip()
        conv_id = (start_frame.conversation_id or "").strip()
        auth_ctx, err_code, err_reason = await _authenticate_ws_context(
            raw_token=raw_token,
            conversation_id=conv_id,
        )
        if auth_ctx is None:
            await self.websocket.close(code=err_code, reason=err_reason)
            return

        self._profile_session = auth_ctx.profile_session
        self.profile_id = auth_ctx.profile_session.profile_id
        self.profile_session_id = auth_ctx.profile_session.id
        self._conversation_id = auth_ctx.conversation_id
        self._language = start_frame.stt_language or auth_ctx.stt_language
        self._tts_speed = start_frame.tts_speed if start_frame.tts_speed is not None else auth_ctx.tts_speed
        self._voice_id = start_frame.voice_id or auth_ctx.character_voice_id or auth_ctx.default_voice_id
        self._barge_in_gate.configure(
            policy=start_frame.barge_in_policy or auth_ctx.barge_in_policy,
            sensitivity=start_frame.vad_sensitivity or auth_ctx.vad_sensitivity,
        )

        self.voice_manager.register_session(self.voice_session_id, self)
        try:
            stt = self.voice_manager.get_stt()
            tts = self.voice_manager.get_tts()
            await self._send_json(
                build_ws_frame(
                    "session.ready",
                    voice_session_id=self.voice_session_id,
                    turn_id=self._active_turn_id,
                    conversation_id=self._conversation_id,
                    stt_available=stt.is_available(),
                    stt_provider=stt.name,
                    tts_available=tts.is_available(),
                    tts_provider=tts.name,
                    vad_provider=self._vad.name,
                    voice_id=self._voice_id,
                )
            )

            while not self._closed:
                message = await self.websocket.receive()
                msg_type = message.get("type")
                if msg_type == "websocket.disconnect":
                    break
                if message.get("bytes") is not None:
                    raw_bin: bytes = message["bytes"]
                    try:
                        pcm, _ = decode_audio_to_pcm16(
                            raw_bin,
                            expected_format="pcm16",
                            sample_rate=16000,
                            max_bytes=MAX_TURN_AUDIO_BYTES,
                        )
                        await self._handle_pcm_chunk(pcm)
                    except AudioFormatError as exc:
                        await self._send_json(
                            build_ws_frame(
                                "error",
                                voice_session_id=self.voice_session_id,
                                turn_id=self._active_turn_id,
                                code="INVALID_AUDIO",
                                message=str(exc),
                            )
                        )
                    continue

                raw_text = message.get("text")
                if not raw_text:
                    continue
                try:
                    frame = VoiceClientFrame.model_validate_json(raw_text)
                except Exception:
                    await self._send_json(
                        build_ws_frame(
                            "error",
                            voice_session_id=self.voice_session_id,
                            turn_id=self._active_turn_id,
                            code="INVALID_FRAME",
                            message="Malformed WebSocket voice frame.",
                        )
                    )
                    continue

                if frame.type == "ping":
                    await self._send_json(build_ws_frame("pong", voice_session_id=self.voice_session_id))
                elif frame.type == "config.update":
                    if frame.stt_language:
                        self._language = frame.stt_language.strip()
                    if frame.tts_speed is not None:
                        self._tts_speed = frame.tts_speed
                    if frame.voice_id and frame.voice_id.strip():
                        self._voice_id = frame.voice_id.strip()
                    self._barge_in_gate.configure(
                        policy=frame.barge_in_policy,
                        sensitivity=frame.vad_sensitivity,
                    )
                elif frame.type == "audio.chunk":
                    if not frame.pcm16_base64:
                        continue
                    try:
                        raw_bytes = base64.b64decode(frame.pcm16_base64, validate=True)
                        pcm, _ = decode_audio_to_pcm16(
                            raw_bytes,
                            expected_format="pcm16",
                            sample_rate=frame.sample_rate,
                            max_bytes=MAX_TURN_AUDIO_BYTES,
                        )
                        await self._handle_pcm_chunk(pcm)
                    except Exception as exc:
                        await self._send_json(
                            build_ws_frame(
                                "error",
                                voice_session_id=self.voice_session_id,
                                turn_id=self._active_turn_id,
                                code="INVALID_AUDIO",
                                message=str(exc),
                            )
                        )
                elif frame.type == "audio.commit":
                    await self._start_committed_turn()
                elif frame.type == "barge_in":
                    await self._cancel_active_turn(
                        reason=frame.reason or "manual_barge_in",
                        emit_cancelled=True,
                    )
                elif frame.type == "session.stop":
                    break
        except WebSocketDisconnect:
            pass
        finally:
            await self.force_close(code=1000, reason="session_ended")
            self.voice_manager.unregister_session(self.voice_session_id)
