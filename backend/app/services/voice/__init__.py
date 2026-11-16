"""Local speech, VAD, TTS, and full-duplex WebSocket voice pipeline package."""

from app.services.voice.audio_utils import (
    MAX_TRANSCRIBE_WAV_BYTES,
    MAX_TURN_AUDIO_BYTES,
    VAD_FRAME_BYTES,
    VAD_FRAME_MS,
    VAD_FRAME_SAMPLES,
    VOICE_SAMPLE_RATE,
    AudioFormatError,
    compute_pcm16_rms,
    decode_audio_to_pcm16,
    pcm16_to_wav_bytes,
    split_pcm16_frames,
)
from app.services.voice.manager import (
    VoiceManager,
    get_voice_manager,
    reset_voice_manager,
    set_voice_manager,
)
from app.services.voice.stt import MockSttProvider, SttProvider, SttResult, WhisperCppSttProvider
from app.services.voice.tts import (
    KokoroOnnxTtsProvider,
    MockTtsProvider,
    TtsProvider,
    TtsResult,
    VoiceDescriptor,
    WindowsSapiTtsProvider,
)
from app.services.voice.vad import (
    AdaptiveEnergyVadProvider,
    BargeInGate,
    SileroOnnxVadProvider,
    VadFrameResult,
    VadProvider,
)

__all__ = [
    "AudioFormatError",
    "AdaptiveEnergyVadProvider",
    "BargeInGate",
    "KokoroOnnxTtsProvider",
    "MAX_TRANSCRIBE_WAV_BYTES",
    "MAX_TURN_AUDIO_BYTES",
    "MockSttProvider",
    "MockTtsProvider",
    "SileroOnnxVadProvider",
    "SttProvider",
    "SttResult",
    "TtsProvider",
    "TtsResult",
    "VAD_FRAME_BYTES",
    "VAD_FRAME_MS",
    "VAD_FRAME_SAMPLES",
    "VOICE_SAMPLE_RATE",
    "VadFrameResult",
    "VadProvider",
    "VoiceDescriptor",
    "VoiceManager",
    "WhisperCppSttProvider",
    "WindowsSapiTtsProvider",
    "compute_pcm16_rms",
    "decode_audio_to_pcm16",
    "get_voice_manager",
    "pcm16_to_wav_bytes",
    "reset_voice_manager",
    "set_voice_manager",
    "split_pcm16_frames",
]
