"""Lazy VoiceManager singleton and active voice session registry."""

from typing import Any, Optional

from app.core.config import settings
from app.services.voice.stt import MockSttProvider, SttProvider, WhisperCppSttProvider
from app.services.voice.tts import (
    KokoroOnnxTtsProvider,
    MockTtsProvider,
    TtsProvider,
    VoiceDescriptor,
    WindowsSapiTtsProvider,
)
from app.services.voice.vad import AdaptiveEnergyVadProvider, SileroOnnxVadProvider, VadProvider


class VoiceManager:
    """Coordinates lazy STT, VAD, TTS providers and tracks active WebSocket sessions."""

    def __init__(
        self,
        *,
        stt: Optional[SttProvider] = None,
        vad: Optional[VadProvider] = None,
        tts: Optional[TtsProvider] = None,
    ) -> None:
        self._stt = stt
        self._vad = vad
        self._tts = tts
        self._active_sessions: dict[str, Any] = {}

    def get_stt(self) -> SttProvider:
        if self._stt is None:
            mode = (settings.VOICE_PROVIDER or "auto").strip().lower()
            if mode == "mock":
                self._stt = MockSttProvider()
            else:
                self._stt = WhisperCppSttProvider(
                    threads=settings.VOICE_WHISPER_THREADS,
                    port=settings.VOICE_WHISPER_PORT,
                )
        return self._stt

    def get_vad(self, *, sensitivity: str = "medium") -> VadProvider:
        if self._vad is None:
            mode = (settings.VOICE_PROVIDER or "auto").strip().lower()
            if mode != "mock":
                silero_path = settings.MODELS_DIR / "vad" / "silero-vad-v6.2.1" / "silero_vad.onnx"
                silero = SileroOnnxVadProvider(model_path=silero_path, sensitivity=sensitivity)
                if silero.is_available():
                    self._vad = silero
                    return self._vad
            self._vad = AdaptiveEnergyVadProvider(sensitivity=sensitivity)
        if hasattr(self._vad, "sensitivity"):
            setattr(self._vad, "sensitivity", sensitivity)
        return self._vad

    def create_turn_vad(self, *, sensitivity: str = "medium") -> VadProvider:
        """Create an isolated per-session VAD instance so sessions never share RNN state."""
        mode = (settings.VOICE_PROVIDER or "auto").strip().lower()
        base = self.get_vad(sensitivity=sensitivity)
        if mode != "mock" and isinstance(base, SileroOnnxVadProvider) and base.is_available():
            return SileroOnnxVadProvider(
                model_path=base.model_path,
                sensitivity=sensitivity,
                session=base._session,
            )
        if isinstance(base, AdaptiveEnergyVadProvider):
            return AdaptiveEnergyVadProvider(sensitivity=sensitivity)
        return base

    def get_tts(self) -> TtsProvider:
        if self._tts is None:
            mode = (settings.VOICE_PROVIDER or "auto").strip().lower()
            if mode == "mock":
                self._tts = MockTtsProvider()
            else:
                kokoro = KokoroOnnxTtsProvider()
                if kokoro.is_available():
                    self._tts = kokoro
                else:
                    sapi = WindowsSapiTtsProvider()
                    self._tts = sapi if sapi.is_available() else kokoro
        return self._tts

    def list_voices(self) -> list[VoiceDescriptor]:
        tts = self.get_tts()
        return tts.list_voices() if tts.is_available() else []

    def register_session(self, voice_session_id: str, session_obj: Any) -> None:
        self._active_sessions[voice_session_id] = session_obj

    def unregister_session(self, voice_session_id: str) -> None:
        self._active_sessions.pop(voice_session_id, None)

    @property
    def active_session_count(self) -> int:
        return len(self._active_sessions)

    async def terminate_sessions_for_profile(self, profile_id: str) -> int:
        targets = [
            s for s in list(self._active_sessions.values())
            if getattr(s, "profile_id", None) == profile_id
        ]
        for sess in targets:
            close_fn = getattr(sess, "force_close", None)
            if close_fn is not None:
                await close_fn(code=4401, reason="profile_revoked")
        return len(targets)

    async def terminate_sessions_for_profile_session(self, profile_session_id: str) -> int:
        targets = [
            s for s in list(self._active_sessions.values())
            if getattr(s, "profile_session_id", None) == profile_session_id
        ]
        for sess in targets:
            close_fn = getattr(sess, "force_close", None)
            if close_fn is not None:
                await close_fn(code=4401, reason="session_revoked")
        return len(targets)

    async def shutdown(self) -> None:
        for sess in list(self._active_sessions.values()):
            close_fn = getattr(sess, "force_close", None)
            if close_fn is not None:
                try:
                    await close_fn(code=1001, reason="runtime_shutdown")
                except Exception:
                    pass
        self._active_sessions.clear()
        if self._stt is not None:
            await self._stt.shutdown()
        if self._tts is not None:
            await self._tts.shutdown()


_voice_manager: Optional[VoiceManager] = None


def get_voice_manager() -> VoiceManager:
    global _voice_manager
    if _voice_manager is None:
        _voice_manager = VoiceManager()
    return _voice_manager


def set_voice_manager(manager: Optional[VoiceManager]) -> None:
    global _voice_manager
    _voice_manager = manager


async def reset_voice_manager() -> None:
    global _voice_manager
    if _voice_manager is not None:
        await _voice_manager.shutdown()
    _voice_manager = None
