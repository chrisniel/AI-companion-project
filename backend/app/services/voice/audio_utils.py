"""Pure-stdlib PCM16/WAV framing helpers (Python 3.11 and 3.13 compatible, zero disk retention)."""

from array import array
import io
import math
import sys
import wave

VOICE_SAMPLE_RATE = 16000
VAD_FRAME_SAMPLES = 512
VAD_FRAME_BYTES = VAD_FRAME_SAMPLES * 2
VAD_FRAME_MS = 32
MAX_TRANSCRIBE_WAV_BYTES = 1_468_006
MAX_TURN_AUDIO_BYTES = 1_572_864


class AudioFormatError(ValueError):
    """Raised when incoming audio fails header, size, or PCM framing validation."""


def _unpack_int16(pcm_bytes: bytes) -> array:
    if len(pcm_bytes) % 2 != 0:
        raise AudioFormatError("PCM16 payload must have an even byte length.")
    samples = array("h")
    samples.frombytes(pcm_bytes)
    if sys.byteorder != "little":
        samples.byteswap()
    return samples


def _pack_int16(samples: array) -> bytes:
    out = array("h", samples)
    if sys.byteorder != "little":
        out.byteswap()
    return out.tobytes()


def compute_pcm16_rms(pcm_bytes: bytes) -> float:
    """Return normalized RMS amplitude in [0.0, 1.0] for little-endian signed 16-bit PCM."""
    if not pcm_bytes:
        return 0.0
    samples = _unpack_int16(pcm_bytes)
    if not samples:
        return 0.0
    sum_sq = sum(float(s) * float(s) for s in samples)
    return min(1.0, math.sqrt(sum_sq / len(samples)) / 32768.0)


def compute_zero_crossing_rate(pcm_bytes: bytes) -> float:
    """Return zero-crossing ratio in [0.0, 1.0] across consecutive PCM16 samples."""
    if len(pcm_bytes) < 4:
        return 0.0
    samples = _unpack_int16(pcm_bytes)
    if len(samples) < 2:
        return 0.0
    crossings = 0
    prev = samples[0]
    for cur in samples[1:]:
        if (prev < 0 <= cur) or (prev >= 0 > cur):
            crossings += 1
        prev = cur
    return crossings / float(len(samples) - 1)


def pcm16_to_wav_bytes(pcm_bytes: bytes, *, sample_rate: int = VOICE_SAMPLE_RATE, channels: int = 1) -> bytes:
    """Wrap raw signed 16-bit little-endian PCM bytes in an in-memory RIFF WAV container."""
    if len(pcm_bytes) % (2 * max(1, channels)) != 0:
        raise AudioFormatError("PCM16 payload length is incompatible with channel count.")
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_bytes)
    return buf.getvalue()


def _downmix_to_mono(samples: array, channels: int) -> array:
    if channels <= 1:
        return samples
    mono = array("h")
    total_frames = len(samples) // channels
    for idx in range(total_frames):
        offset = idx * channels
        avg = sum(samples[offset : offset + channels]) // channels
        mono.append(int(avg))
    return mono


def _resample_linear(samples: array, src_rate: int, dst_rate: int) -> array:
    if src_rate == dst_rate or len(samples) <= 1:
        return samples
    dst_len = max(1, int(round(len(samples) * dst_rate / float(src_rate))))
    resampled = array("h")
    max_idx = len(samples) - 1
    ratio = src_rate / float(dst_rate)
    for out_idx in range(dst_len):
        pos = out_idx * ratio
        i0 = min(max_idx, int(pos))
        i1 = min(max_idx, i0 + 1)
        frac = pos - i0
        val = int(round(samples[i0] * (1.0 - frac) + samples[i1] * frac))
        resampled.append(max(-32768, min(32767, val)))
    return resampled


def decode_audio_to_pcm16(
    raw_bytes: bytes,
    *,
    expected_format: str = "wav",
    sample_rate: int = VOICE_SAMPLE_RATE,
    max_bytes: int = MAX_TRANSCRIBE_WAV_BYTES,
    target_sample_rate: int = VOICE_SAMPLE_RATE,
) -> tuple[bytes, int]:
    """Decode WAV or raw PCM16 bytes in-memory to normalized 16kHz mono PCM16 bytes."""
    if not raw_bytes:
        raise AudioFormatError("Audio payload must not be empty.")
    if len(raw_bytes) > max_bytes:
        raise AudioFormatError(f"Audio payload exceeds maximum allowed size of {max_bytes} bytes.")

    if expected_format == "wav":
        try:
            with wave.open(io.BytesIO(raw_bytes), "rb") as wf:
                channels = wf.getnchannels()
                sampwidth = wf.getsampwidth()
                src_rate = wf.getframerate()
                frames = wf.readframes(wf.getnframes())
        except Exception as exc:
            raise AudioFormatError(f"Invalid WAV container: {exc}") from exc
        if sampwidth != 2:
            raise AudioFormatError("Only 16-bit signed PCM WAV audio is supported.")
        if channels not in (1, 2):
            raise AudioFormatError("Only mono or stereo WAV audio is supported.")
        if src_rate < 8000 or src_rate > 48000:
            raise AudioFormatError("WAV sample rate must be between 8000 and 48000 Hz.")
        samples = _unpack_int16(frames)
        mono = _downmix_to_mono(samples, channels)
        normalized = _resample_linear(mono, src_rate, target_sample_rate)
        return _pack_int16(normalized), target_sample_rate

    if expected_format == "pcm16":
        if sample_rate < 8000 or sample_rate > 48000:
            raise AudioFormatError("PCM sample rate must be between 8000 and 48000 Hz.")
        samples = _unpack_int16(raw_bytes)
        normalized = _resample_linear(samples, sample_rate, target_sample_rate)
        return _pack_int16(normalized), target_sample_rate

    raise AudioFormatError(f"Unsupported audio format: {expected_format}")


def split_pcm16_frames(pcm_bytes: bytes, frame_samples: int = VAD_FRAME_SAMPLES) -> list[bytes]:
    """Split normalized PCM16 mono bytes into fixed-size frame chunks (dropping trailing partial)."""
    frame_bytes = frame_samples * 2
    if len(pcm_bytes) < frame_bytes:
        return []
    full_count = len(pcm_bytes) // frame_bytes
    return [pcm_bytes[i * frame_bytes : (i + 1) * frame_bytes] for i in range(full_count)]
