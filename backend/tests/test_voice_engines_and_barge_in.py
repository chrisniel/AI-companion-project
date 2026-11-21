"""Unit tests for voice audio framing, VAD, and anti-false-trigger BargeInGate."""

import math
import struct

import pytest

from app.services.voice.audio_utils import (
    MAX_TRANSCRIBE_WAV_BYTES,
    VAD_FRAME_SAMPLES,
    AudioFormatError,
    compute_pcm16_rms,
    decode_audio_to_pcm16,
    pcm16_to_wav_bytes,
    split_pcm16_frames,
)
from app.services.voice.vad import (
    AdaptiveEnergyVadProvider,
    BargeInGate,
    SileroOnnxVadProvider,
)


def _tone_pcm16(amplitude: int, num_samples: int = VAD_FRAME_SAMPLES, freq_hz: float = 320.0) -> bytes:
    samples = [
        int(amplitude * math.sin(2.0 * math.pi * freq_hz * i / 16000.0))
        for i in range(num_samples)
    ]
    return struct.pack(f"<{num_samples}h", *samples)


def _silence_pcm16(num_samples: int = VAD_FRAME_SAMPLES) -> bytes:
    return b"\x00\x00" * num_samples


def test_pcm16_wav_round_trip_and_limits():
    pcm = _tone_pcm16(6000, num_samples=1600)
    wav = pcm16_to_wav_bytes(pcm, sample_rate=16000)
    assert wav[:4] == b"RIFF"
    decoded_pcm, sr = decode_audio_to_pcm16(wav, expected_format="wav", max_bytes=MAX_TRANSCRIBE_WAV_BYTES)
    assert sr == 16000
    assert decoded_pcm == pcm

    assert compute_pcm16_rms(_silence_pcm16()) == 0.0
    assert compute_pcm16_rms(pcm) > 0.1

    frames = split_pcm16_frames(pcm + _silence_pcm16(100))
    assert len(frames) == 3  # 1600 // 512 == 3 full frames (1536 samples)
    assert all(len(f) == VAD_FRAME_SAMPLES * 2 for f in frames)

    with pytest.raises(AudioFormatError):
        decode_audio_to_pcm16(b"not-a-wav", expected_format="wav")

    oversize = b"\x00" * (MAX_TRANSCRIBE_WAV_BYTES + 2)
    with pytest.raises(AudioFormatError):
        decode_audio_to_pcm16(oversize, expected_format="pcm16", max_bytes=MAX_TRANSCRIBE_WAV_BYTES)


def test_adaptive_energy_vad_distinguishes_silence_from_speech():
    vad = AdaptiveEnergyVadProvider(sensitivity="medium")
    for _ in range(4):
        res_silent = vad.evaluate_frame(_silence_pcm16())
        assert res_silent.is_speech is False
        assert res_silent.probability < 0.3

    speech_frame = _tone_pcm16(9000, freq_hz=260.0)
    probs = [vad.evaluate_frame(speech_frame).probability for _ in range(3)]
    assert probs[-1] > 0.6


def test_barge_in_gate_ignores_short_noise_and_respects_policies():
    vad = AdaptiveEnergyVadProvider(sensitivity="medium")
    speech_frame = _tone_pcm16(10000, freq_hz=280.0)
    silence_frame = _silence_pcm16()

    # 1. smart_auto (280ms hold => ~9 frames @ 32ms): short 3-frame burst (~96ms) must NOT trigger
    gate = BargeInGate(vad=vad, policy="smart_auto", sensitivity="medium")
    gate.set_speaking(True)
    for _ in range(3):
        assert gate.process_pcm16_frame(speech_frame) is False
    # Brief silence resets consecutive counter after brief tolerance
    for _ in range(3):
        assert gate.process_pcm16_frame(silence_frame) is False

    # Sustained speech >= 280ms (~9 frames * 32ms = 288ms) fires cleanly
    triggered = False
    for _ in range(10):
        if gate.process_pcm16_frame(speech_frame):
            triggered = True
            break
    assert triggered is True

    # 2. strict_noisy (400ms hold => ~13 frames): 10 frames (~320ms) must NOT trigger
    vad_strict = AdaptiveEnergyVadProvider(sensitivity="low")
    strict_gate = BargeInGate(vad=vad_strict, policy="strict_noisy", sensitivity="low")
    strict_gate.set_speaking(True)
    assert all(not strict_gate.process_pcm16_frame(speech_frame) for _ in range(10))
    assert any(strict_gate.process_pcm16_frame(speech_frame) for _ in range(6))

    # 3. manual_only never triggers from incoming mic frames while speaking
    manual_gate = BargeInGate(vad=vad, policy="manual_only", sensitivity="high")
    manual_gate.set_speaking(True)
    assert all(not manual_gate.process_pcm16_frame(speech_frame) for _ in range(25))


def test_silero_provider_reports_missing_runtime_gracefully(tmp_path):
    missing_model = tmp_path / "does_not_exist.onnx"
    provider = SileroOnnxVadProvider(model_path=missing_model)
    assert provider.is_available() is False


def test_silero_provider_prepends_64_sample_context_and_resets():
    pytest.importorskip("numpy")
    captured_inputs = []

    class _FakeSileroSession:
        def run(self, _names, feed):
            captured_inputs.append(feed["input"].copy())
            return ([[0.88]], feed["state"])

    vad = SileroOnnxVadProvider(sensitivity="medium", session=_FakeSileroSession())
    assert vad.is_available() is True

    frame1 = _tone_pcm16(8000, freq_hz=260.0)
    res1 = vad.evaluate_frame(frame1)
    assert res1.probability == pytest.approx(0.88)
    assert res1.is_speech is True
    assert captured_inputs[0].shape == (1, 576)
    # First 64 context samples start at zero
    assert float(captured_inputs[0][0, :64].max()) == 0.0

    # Second frame receives tail 64 samples from frame1 as its context prefix
    frame2 = _silence_pcm16()
    vad.evaluate_frame(frame2)
    assert captured_inputs[1].shape == (1, 576)
    assert float(abs(captured_inputs[1][0, :64]).max()) > 0.0

    # reset() clears context back to zero
    vad.reset()
    vad.evaluate_frame(frame2)
    assert float(captured_inputs[2][0, :64].max()) == 0.0


def test_whisper_provider_command_and_truthful_unavailability(tmp_path):
    from app.services.voice.stt import WhisperCppSttProvider

    # Missing model -> truthful unavailable without spawning anything
    missing_bin = tmp_path / "whisper-server.exe"
    missing_bin.write_bytes(b"")
    stt_missing = WhisperCppSttProvider(binary_path=missing_bin, model_path=tmp_path / "missing.bin")
    assert stt_missing.is_available() is False
    assert "model" in (stt_missing.unavailable_reason or "").lower()

    # Present binary & model -> builds localhost CPU-first command cleanly
    model_file = tmp_path / "ggml-base.bin"
    model_file.write_bytes(b"GGML")
    onnx_vad = tmp_path / "silero_vad.onnx"
    onnx_vad.write_bytes(b"ONNX")
    stt = WhisperCppSttProvider(
        binary_path=missing_bin,
        model_path=model_file,
        vad_model_path=onnx_vad,
        threads=4,
    )
    assert stt.is_available() is True
    cmd = stt.build_command(port=18123, language="en")
    assert "--host" in cmd and "127.0.0.1" in cmd
    assert "-ng" in cmd
    assert str(model_file) in cmd
    assert "-l" in cmd and "en" in cmd
    # Never pass .onnx files into whisper-server's GGML -vm flag
    assert "--vad" not in cmd and str(onnx_vad) not in cmd

    ggml_vad = tmp_path / "ggml-silero.bin"
    ggml_vad.write_bytes(b"GGML")
    stt_ggml_vad = WhisperCppSttProvider(
        binary_path=missing_bin,
        model_path=model_file,
        vad_model_path=ggml_vad,
        threads=4,
    )
    assert "-vm" in stt_ggml_vad.build_command(port=18123)


async def test_whisper_provider_transcribe_and_shutdown_uses_mocked_http_and_process(tmp_path):
    from unittest.mock import AsyncMock, MagicMock
    from app.services.voice.stt import WhisperCppSttProvider

    exe = tmp_path / "whisper-server.exe"
    exe.write_bytes(b"")
    model = tmp_path / "ggml-tiny.bin"
    model.write_bytes(b"GGML")

    fake_proc = MagicMock()
    fake_proc.poll.return_value = None

    fake_client = MagicMock()
    health_resp = MagicMock(status_code=200)
    health_resp.json.return_value = {"status": "ok"}
    infer_resp = MagicMock(status_code=200)
    infer_resp.raise_for_status = MagicMock()
    infer_resp.json.return_value = {"text": " Hello world! ", "language": "en"}
    fake_client.get = AsyncMock(return_value=health_resp)
    fake_client.post = AsyncMock(return_value=infer_resp)
    fake_client.aclose = AsyncMock()

    stt = WhisperCppSttProvider(
        binary_path=exe,
        model_path=model,
        process_launcher=lambda cmd: fake_proc,
        http_client_factory=lambda: fake_client,
    )
    res = await stt.transcribe(_tone_pcm16(5000, num_samples=1600), language="auto")
    assert res.text == "Hello world!"
    assert res.provider == "whisper_cpp"
    await stt.shutdown()
    fake_proc.terminate.assert_called_once()
    fake_client.aclose.assert_awaited_once()


async def test_kokoro_tokenizer_style_slicing_and_mock_tts():
    from pathlib import Path
    from app.services.voice.tts import (
        KokoroOnnxTtsProvider,
        MockTtsProvider,
        load_kokoro_voice_style_vector,
        split_sentences_for_tts,
        text_to_kokoro_tokens,
    )

    chunks = split_sentences_for_tts("Hello there! How is the weather in Manila? Let's check.")
    assert chunks == ["Hello there!", "How is the weather in Manila?", "Let's check."]

    tok_path = Path(__file__).resolve().parents[2] / "models" / "tts" / "kokoro-82m-v1.0" / "tokenizer.json"
    voice_path = Path(__file__).resolve().parents[2] / "models" / "tts" / "kokoro-82m-v1.0" / "voices" / "af_nicole.bin"
    if tok_path.is_file() and voice_path.is_file():
        import json

        vocab = json.loads(tok_path.read_text(encoding="utf-8"))["model"]["vocab"]
        tokens = text_to_kokoro_tokens("Hello companion.", vocab)
        assert tokens[0] == 0 and tokens[-1] == 0
        assert len(tokens) > 4
        style = load_kokoro_voice_style_vector(voice_path, token_count=len(tokens))
        assert len(style) == 256
        assert any(abs(v) > 0.0 for v in style)

    # MockTtsProvider always produces valid RIFF WAV audio
    mock_tts = MockTtsProvider()
    assert mock_tts.is_available() is True
    out = await mock_tts.synthesize("Testing mock speech synthesis.", voice_id="af_nicole", speed=1.1)
    assert out.wav_bytes[:4] == b"RIFF"
    decoded, sr = decode_audio_to_pcm16(out.wav_bytes, expected_format="wav")
    assert sr == 16000
    assert len(decoded) > 0

    # Kokoro provider reports cleanly when session is absent vs running with a fake ONNX session
    class _FakeInput:
        def __init__(self, name: str):
            self.name = name

    class _FakeSession:
        def get_inputs(self):
            return [_FakeInput("input_ids"), _FakeInput("style"), _FakeInput("speed")]

        def run(self, _names, feed):
            assert "input_ids" in feed and "style" in feed and "speed" in feed
            return [[[0.0, 0.25, -0.25, 0.1] * 200]]

    kokoro = KokoroOnnxTtsProvider(
        vocab={"$": 0, " ": 16, "a": 43, "h": 50, "i": 51},
        voices={"af_nicole": [[0.1] * 256] * 510},
        session=_FakeSession(),
    )
    assert kokoro.is_available() is True
    kokoro_res = await kokoro.synthesize("Hi!", voice_id="af_nicole", speed=1.0)
    assert kokoro_res.wav_bytes[:4] == b"RIFF"
    assert kokoro_res.sample_rate == 24000
    assert kokoro_res.provider == "kokoro_onnx"


def test_voice_manager_create_turn_vad_isolates_silero_state(monkeypatch):
    pytest.importorskip("numpy")
    from app.core.config import settings
    from app.services.voice.manager import VoiceManager

    class _FakeSileroSession:
        def run(self, _names, feed):
            return ([[0.5]], feed["state"])

    monkeypatch.setattr(settings, "VOICE_PROVIDER", "auto")
    shared_silero = SileroOnnxVadProvider(sensitivity="medium", session=_FakeSileroSession())
    vm = VoiceManager(vad=shared_silero)

    first = vm.get_vad(sensitivity="medium")
    turn_a = vm.create_turn_vad(sensitivity="high")
    turn_b = vm.create_turn_vad(sensitivity="low")

    assert first is shared_silero
    assert isinstance(turn_a, SileroOnnxVadProvider)
    assert isinstance(turn_b, SileroOnnxVadProvider)
    assert turn_a is not shared_silero
    assert turn_b is not shared_silero
    assert turn_a is not turn_b
    assert turn_a._session is shared_silero._session
    assert turn_a._state is not turn_b._state
    assert turn_a._context is not turn_b._context


def test_tts_espeak_g2p_taglish_and_preprocessing():
    from app.services.voice.tts import preprocess_text_for_tts, text_to_kokoro_ipa

    cleaned = preprocess_text_for_tts(
        "**Check** the [CPU guide](https://example.com) on GPU 🎉 `test` 100%"
    )
    assert "https://" not in cleaned
    assert "🎉" not in cleaned
    assert "**" not in cleaned
    assert "`" not in cleaned
    assert "C P U" in cleaned and "G P U" in cleaned

    english_ipa = text_to_kokoro_ipa("Welcome to the city today.")
    assert "kɪtj" not in english_ipa
    assert "s" in english_ipa  # soft c in "city" -> /s.../

    taglish_ipa = text_to_kokoro_ipa("Kamusta ka na? Magandang gabi sa Quezon City!")
    assert "kæmʌstæ" not in taglish_ipa
    assert "kɪtj" not in taglish_ipa
    assert "ŋ" in taglish_ipa  # Magandang -> ...ŋ

    # Slice 5B: Slash word normalization, emoji-only suppression, and punctuation prosody preservation
    assert preprocess_text_for_tts("Since it's in late winter/early spring.") == "Since it's in late winter or early spring."
    assert preprocess_text_for_tts("🌸") == ""
    prosody_ipa = text_to_kokoro_ipa("Oh my dear, would you like more suggestions?")
    assert "," in prosody_ipa and prosody_ipa.rstrip().endswith("?")

    # Slice 6D: Curly apostrophes, decimals, temperature ranges/units, percentages, and arrows
    norm = preprocess_text_for_tts(
        "I’ll check Caloocan: 26.7°C now, 24.8–31.3°C tomorrow (51% rain) or 30.2c → Thunderstorm!"
    )
    assert "I'll" in norm
    assert "’" not in norm
    assert "26 point 7 degrees Celsius" in norm
    assert "24 point 8 to 31 point 3 degrees Celsius" in norm
    assert "51 percent" in norm
    assert "30 point 2 degrees Celsius" in norm
    assert "→" not in norm
    contraction_ipa = text_to_kokoro_ipa("We’ll check tomorrow, don’t worry!")
    assert "ˌɛlˈɛl" not in contraction_ipa
    assert "dˈɑːn tˈiː" not in contraction_ipa


async def test_kokoro_synthesize_chunks_long_text_without_510_truncation():
    from app.services.voice.tts import KokoroOnnxTtsProvider

    class _FakeInput:
        def __init__(self, name: str):
            self.name = name

    calls: list[int] = []

    class _CountingSession:
        def get_inputs(self):
            return [_FakeInput("input_ids"), _FakeInput("style"), _FakeInput("speed")]

        def run(self, _names, feed):
            ids = feed["input_ids"]
            token_len = len(ids[0])
            assert token_len <= 512
            calls.append(token_len)
            return [[[0.1, -0.1, 0.2, -0.2] * 300]]  # 1200 samples per chunk

    vocab = {"$": 0, " ": 16}
    for idx, ch in enumerate("abcdefghijklmnopqrstuvwxyz.,!?ˈˌːɑɛiɔuŋɡɾɹəɪʊʌæʃʒθð ", start=20):
        vocab.setdefault(ch, idx)

    long_text = " ".join(
        f"Sentence number {i} explains how local voice streaming stays responsive."
        for i in range(1, 14)
    )
    assert len(long_text) > 700

    kokoro = KokoroOnnxTtsProvider(
        vocab=vocab,
        voices={"af_nicole": [[0.1] * 256] * 512},
        session=_CountingSession(),
    )
    # 183+ char sentence stays intact inside a single chunk instead of slicing before "spring."
    intact_chunks = kokoro._split_token_bounded_chunks(
        "Since it is December eighth in late winter/early spring, I recommend looking at lavender wedding suits today.",
        language="en-us",
    )
    assert len(intact_chunks) == 1

    # Emoji-only string skips ONNX synthesis and returns silent padding WAV
    calls.clear()
    emoji_res = await kokoro.synthesize("🌸", voice_id="af_nicole", speed=1.0)
    assert len(calls) == 0
    assert emoji_res.wav_bytes[:4] == b"RIFF"

    # Normal text includes 50ms leading + 120ms trailing silence padding at 24 kHz
    import io
    import wave

    hi_res = await kokoro.synthesize("Hi!", voice_id="af_nicole", speed=1.0)
    with wave.open(io.BytesIO(hi_res.wav_bytes), "rb") as wf:
        assert wf.getframerate() == 24000
        assert wf.getnframes() == 1200 + int(24000 * 0.05) + int(24000 * 0.12)

    calls.clear()
    res = await kokoro.synthesize(long_text, voice_id="af_nicole", speed=1.0)
    assert res.wav_bytes[:4] == b"RIFF"
    assert len(calls) >= 4
    # Combined WAV holds multiple 1200-sample chunks (> 1200 * 2 bytes PCM payload)
    assert len(res.wav_bytes) > 1200 * 2 * 3

