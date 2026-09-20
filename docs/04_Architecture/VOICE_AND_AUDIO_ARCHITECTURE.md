# Voice and Audio Architecture Specification

**Project:** AI Companion Project  
**Architecture Area:** Voice Pipeline, Audio Device Management & Speech Processing  
**Document Role:** Canonical future-domain architecture specification  
**Document Status:** Approved Architecture / Planned Post-V1 Implementation (Tracks V0–V6)  
**Primary Host:** Windows 11 Local AI Runtime  
**Target Hardware:** AMD Ryzen 5 3600, 16 GB RAM, Aisurix RX 580 8 GB VRAM  
**Remote Companion Client:** Android Companion App  

> [!IMPORTANT]
> **Release Boundary Notice (Decision D1):**
> Voice & audio capabilities are strictly **POST-V1**. No voice interfaces, audio pipelines, speech models, or background audio capture services are currently implemented in the repository. This document defines the canonical architecture for future implementation phases without creating blockers for the V1 release.

---

## 1. Executive Summary & Core Rules

The AI Companion voice architecture enables fluid, multilingual spoken conversation across Windows PC and Android. It maintains five non-negotiable architectural principles:

1. **CPU-First Speech Execution:** Speech processing (VAD, STT, TTS, Wake Word, and Speaker ID) runs primarily on CPU/RAM. The 8 GB VRAM on the Aisurix RX 580 is reserved almost exclusively for the active generative LLM/VLM (`--models-max 1`). Speech models must never casually compete with the primary model for VRAM.
2. **Provider Independence:** Every voice component implements a clean Python interface (`AudioDeviceManager`, `VADProvider`, `STTProvider`, `TTSProvider`, `WakeWordProvider`). No engine or vendor library is hardcoded into Local AI Runtime application logic. Provider names (Kokoro, Piper, KittenTTS, Whisper-family, Silero) remain candidates rather than permanent defaults.
3. **Local-First & On-Device by Default:** Spoken conversations are synthesized and transcribed locally without cloud speech APIs unless the user explicitly configures an external provider. Speech processing runs locally on the PC host when the PC serves the interaction, or on-device in Android Offline Mode where hardware permits. The non-negotiable invariant is local/on-device processing by default, with no cloud speech transmission unless explicitly configured and authorized.
4. **Privacy & Zero Audio Retention Target (Future Architectural Policy):** As a future architectural policy and default target, audio PCM buffers are designed to be ephemeral, streamed in memory, and discarded immediately after processing, with no raw audio recordings persisted to disk by default. (Note: Specific transcript retention settings, debug capture retention, opt-in recording lifecycle, and cleanup duration remain open future implementation designs; the architectural invariant is privacy-first default with no unconsented raw audio retention).
5. **Multilingual Parity:** The pipeline explicitly measures and reports speech capability across English, Filipino / Tagalog, Japanese, and conversational code-switching.

---

## 2. Canonical Voice Processing Pipeline

```text
               ┌────────────────────────────────────────────────┐
               │          Audio Input Hardware Capture          │
               │   (PC Mic / Bluetooth Headset / Android Mic)   │
               └───────────────────────┬────────────────────────┘
                                       │ Raw PCM Audio Stream (16kHz, 16-bit Mono)
                                       ▼
               ┌────────────────────────────────────────────────┐
               │              AudioDeviceManager                │
               │    - Device Enumeration, Selection & Routing   │
               │    - Ring Buffer Management & Resampling       │
               └───────────┬────────────────────────┬───────────┘
                           │                        │
       [Wake Word Mode]    │                        │    [Continuous / Push-to-Talk]
                           ▼                        │
               ┌───────────────────────┐            │
               │   WakeWordProvider    │            │
               │  (openWakeWord / etc) │            │
               └───────────┬───────────┘            │
                           │ Wake phrase detected   │
                           ▼                        ▼
               ┌────────────────────────────────────────────────┐
               │                 VADProvider                    │
               │    - Silero VAD (ONNX / CPU execution)         │
               │    - Speech Start & Speech End Detection       │
               │    - Energy/Probability Framing                │
               └───────────────────────┬────────────────────────┘
                                       │ Voice Segment Audio Chunk
                                       ▼
               ┌────────────────────────────────────────────────┐
               │                 STTProvider                    │
               │    - Whisper-family (whisper.cpp / ONNX)       │
               │    - Multilingual Decoding (EN / FIL / JA)     │
               │    - Streaming / Chunked Transcription         │
               └───────────────────────┬────────────────────────┘
                                       │ Transcribed User Text
                                       ▼
               ┌────────────────────────────────────────────────┐
               │             AssistantOrchestrator              │
               │    - Trust Framing & Context Assembly          │
               │    - Memory Retrieval (SQLite FTS5)            │
               │    - Prompt Dispatch to LLMProvider            │
               └───────────────────────┬────────────────────────┘
                                       │ Response Text Tokens (Streamed)
                                       ▼
               ┌────────────────────────────────────────────────┐
               │                 TTSProvider                    │
               │    - Sentence / Clause Token Chunking          │
               │    - Kokoro-82M / Piper / sherpa-onnx (CPU)    │
               │    - Streaming Audio Synthesis                 │
               └───────────────────────┬────────────────────────┘
                                       │ Synthesized Audio PCM
                                       ▼
               ┌────────────────────────────────────────────────┐
               │              AudioDeviceManager                │
               │    - Output Device Routing (Speaker / Headset) │
               │    - Barge-In Interruption Handling            │
               └───────────────────────┬────────────────────────┘
                                       │ Acoustic Output
                                       ▼
               ┌────────────────────────────────────────────────┐
               │             Audio Output Hardware              │
               │   (PC Speakers / BT Headphones / Android Out)  │
               └────────────────────────────────────────────────┘
```

---

## 3. Core Provider Interfaces

All planned voice components are architected to reside in `backend/app/providers/voice/` (directory not yet created in repository; planned for future Track V0) and adhere to typed abstract interfaces:

### 3.1 AudioDeviceManager Interface
```python
class AudioDeviceManager(ABC):
    @abstractmethod
    async def list_input_devices(self) -> list[AudioDeviceInfo]:
        """Enumerate available input microphones and capture endpoints."""
        ...

    @abstractmethod
    async def list_output_devices(self) -> list[AudioDeviceInfo]:
        """Enumerate available speakers, headphones, and Bluetooth sinks."""
        ...

    @abstractmethod
    async def set_active_input_device(self, device_id: str) -> None:
        """Route input capture to the selected device."""
        ...

    @abstractmethod
    async def set_active_output_device(self, device_id: str) -> None:
        """Route playback to the selected device."""
        ...

    @abstractmethod
    async def start_capture(self) -> AsyncIterator[bytes]:
        """Stream raw 16kHz 16-bit mono PCM chunks from active input."""
        ...

    @abstractmethod
    async def play_audio_chunk(self, pcm_chunk: bytes) -> None:
        """Queue and play audio chunk through active output sink."""
        ...

    @abstractmethod
    async def stop_playback_immediately(self) -> None:
        """Instantly flush output buffers for barge-in interruption."""
        ...
```

### 3.2 VADProvider Interface
```python
class VADProvider(ABC):
    @abstractmethod
    async def process_frame(self, pcm_frame: bytes) -> VADFrameResult:
        """Analyze audio frame (typically 30-50ms) and return speech probability."""
        ...

    @abstractmethod
    def reset(self) -> None:
        """Reset internal temporal/hidden states between conversation turns."""
        ...
```

### 3.3 STTProvider Interface
```python
class STTProvider(ABC):
    @abstractmethod
    async def transcribe(
        self,
        audio_pcm: bytes,
        language_hint: str | None = None,
    ) -> TranscriptionResult:
        """Transcribe audio chunk into text with confidence score and language code."""
        ...

    @abstractmethod
    def get_supported_languages(self) -> dict[str, CapabilityStatus]:
        """Return support status (Supported/Limited/Unsupported) for EN, FIL, JA, and mixed."""
        ...
```

### 3.4 TTSProvider Interface
```python
class TTSProvider(ABC):
    @abstractmethod
    async def synthesize_stream(
        self,
        text_stream: AsyncIterator[str],
        voice_profile: VoiceProfile,
    ) -> AsyncIterator[bytes]:
        """Stream synthesized PCM audio chunks as text clauses arrive."""
        ...

    @abstractmethod
    def get_supported_languages(self) -> dict[str, CapabilityStatus]:
        """Return support status for synthesis languages."""
        ...
```

### 3.5 WakeWordProvider Interface
```python
class WakeWordProvider(ABC):
    @abstractmethod
    async def process_frame(self, pcm_frame: bytes) -> WakeWordDetectionResult:
        """Detect configured wake phrases (e.g. 'Hey Companion') in real-time."""
        ...

    @abstractmethod
    def set_wake_phrase(self, phrase_id: str) -> None:
        """Configure active wake model and activation sensitivity."""
        ...
```

---

## 4. Semantic Voice State Machine & Barge-In

The conversation lifecycle follows an unambiguous, event-driven state machine:

```text
    ┌──────────────┐
    │     IDLE     │◄────────────────────────────────────────┐
    └──────┬───────┘                                         │
           │ wake word detected / push-to-talk started       │
           ▼                                                 │
    ┌──────────────┐                                         │
    │  LISTENING   │                                         │
    └──────┬───────┘                                         │
           │ VAD speech end detected / max chunk reached     │
           ▼                                                 │
    ┌──────────────┐                                         │
    │ TRANSCRIBING │                                         │
    └──────┬───────┘                                         │
           │ STT completed with valid text                   │
           ▼                                                 │
    ┌──────────────┐                                         │
    │   THINKING   │                                         │
    └──────┬───────┘                                         │
           ├──────────────────────────┐                      │
           │ tool proposed            │ first token ready    │
           ▼                          ▼                      │
    ┌──────────────┐           ┌──────────────┐              │
    │EXECUTING_TOOL│           │   SPEAKING   │              │
    └──────┬───────┘           └──────┬───────┘              │
           │ tool result returned     │                      │
           └──────────────────────────┤                      │
                                      ├──────────────────────┤
                                      │ playback complete    │
                                      ▼                      │
                               ┌──────────────┐              │
                               │ INTERRUPTED  │──────────────┘
                               └──────────────┘ (Barge-In: VAD detects user
                                                 speech during SPEAKING)
```

### Barge-In Protocol
1. While in state `SPEAKING`, the input microphone remains active and monitored by `VADProvider`.
2. If user speech is detected with consecutive probability exceeding the barge-in threshold (e.g., probability > 0.85 for > 200 ms):
   - State transitions immediately to `INTERRUPTED`.
   - `AudioDeviceManager.stop_playback_immediately()` drains output buffers.
   - Ongoing TTS synthesis is cancelled via `asyncio.Task.cancel()`.
   - State transitions directly to `LISTENING`, preserving the new incoming speech chunk.

---

## 5. Candidate Implementations & CPU-First Policy

| Subsystem | Primary Candidate | Fallback / Alternative | Placement | Target Metric (Proposed) |
|---|---|---|---|---|
| **VAD** | Silero VAD (ONNX Runtime) | WebRTC VAD | CPU / RAM | < 5 ms per 30ms frame, < 20 MB RAM (TARGET) |
| **STT** | `whisper.cpp` (quantized Q5_1 / Q8_0) | Faster-Whisper | CPU / RAM | RTF < 0.4x on Ryzen 5 3600 (threads=4) (TARGET) |
| **TTS (PC)** | Kokoro-82M (ONNX Runtime) | Piper TTS / sherpa-onnx | CPU / RAM | RTF < 0.3x, natural cadence (TARGET) |
| **TTS (Mobile)** | KittenTTS (lightweight offline candidate) | Kokoro / Android System TTS | Mobile CPU | Under evaluation; benchmarking deferred (TARGET) |
| **Wake Word** | openWakeWord (tflite/ONNX) | sherpa-onnx KWS | CPU / RAM | < 1% CPU utilization idle (TARGET) |
| **Audio I/O** | `sounddevice` / PortAudio | Windows Core Audio API | System | < 20 ms buffer latency (TARGET) |

### TTS Engine Direction & Invariants
- **No Locked Default:** The project does **not** permanently lock KittenTTS, Kokoro, Piper, Android System TTS, or any single engine as the universal default across all platforms. Each remains an evaluation candidate for its respective tier.
- **Mobile TTS Evaluation:**
  - **KittenTTS:** Promising lightweight on-device candidate, but currently has language limitations and must **not** be presented as a universal multilingual solution.
  - **Kokoro:** High quality, but observed slower during mobile evaluation on reference phone hardware.
  - **Android System TTS:** Universal reliable fallback when neural synthesis is unavailable or too slow.
  - Further mobile TTS benchmarking is deferred until the dedicated Android Offline Runtime / Voice implementation planning phase.
- **PC TTS Evaluation:** Kokoro and Piper remain strong local CPU neural candidates.

### Why CPU-First for Speech?
- **VRAM Contention:** The AMD RX 580 has 8 GB VRAM. A 4B GGUF model at Q4_K_M requires ~3.5–4.5 GB VRAM with context and KV cache. Loading Whisper or Kokoro on the same GPU via Vulkan risks out-of-memory (OOM) crashes, driver resets, and latency spikes during model swapping.
- **CPU Headroom:** The AMD Ryzen 5 3600 (6 cores, 12 threads) has ample headroom while the GPU handles generative tokens. Dedicating 3–4 threads to speech processing ensures zero interference with LLM VRAM.

---

## 6. Language Capability Reporting Matrix (Target Proposals)

The voice system must never report uniform language capabilities if underlying speech engines differ. Each provider reports capability per language:

| Language Dimension | STT (Whisper Base/Small) | TTS (Kokoro-82M) | TTS (Piper) | Notes (Proposed Targets) |
|---|---|---|---|---|
| **English (EN)** | PROPOSED TARGET | PROPOSED TARGET | PROPOSED TARGET | Full fidelity, natural cadence |
| **Filipino / Tagalog (FIL)** | PROPOSED TARGET | UNKNOWN / UNVERIFIED | UNKNOWN / UNVERIFIED | Whisper transcribes accurately; TTS phonemes require benchmark tuning |
| **Japanese (JA)** | PROPOSED TARGET | PROPOSED TARGET | PROPOSED TARGET | Kanji/kana grapheme handling required |
| **Code-Switching (Taglish / EN-JA)** | PROPOSED TARGET | UNKNOWN / UNVERIFIED | UNKNOWN / UNVERIFIED | Whisper handles mixed-phrase transcription well; synthesis requires multi-speaker/cross-lingual acoustic models |

> [!NOTE]
> Values in this matrix represent **proposed engineering targets** for future benchmark validation. They are unverified in the current repository. Statuses such as `PROPOSED TARGET` and `UNKNOWN / UNVERIFIED` remain in effect until real hardware benchmarks establish actual measured capabilities.

Typed status definitions for future benchmark reporting:
- `Supported`: Fully verified in benchmarks with native accuracy.
- `Limited`: Operational with known pronunciation, accent, or formatting quirks.
- `Unsupported`: Engine does not produce coherent output.
- `Unknown / Unverified`: Untested in local hardware benchmark.

---

## 7. Remote Audio: Android Companion Integration

When the user is away from the PC, the Android Companion functions as a remote voice endpoint:

```text
Android Companion Microphone
       │ (16kHz PCM audio frame)
       ▼
Opus Audio Encoder (Android Client)
       │ Encrypted Streaming Transport via Tailscale
       │ (UDP / WebSocket — PROPOSED / TO BE VALIDATED)
       ▼
Opus Audio Decoder (FastAPI / Local AI Runtime Gateway)
       │
       ▼
AudioDeviceManager (Virtual Network Stream)
       │
       ▼ Core Pipeline: VAD → STT → LLM → TTS
       │
Opus Audio Encoder (FastAPI / Local AI Runtime Gateway)
       │ Encrypted Return Stream
       ▼
Android Companion Audio Sinks (Phone Speaker / Earbud)
```

- **Audio Codec:** Opus 16kHz mono (target bitrate 24–32 kbps; ultra-low bandwidth, resilient to jitter) is the initial codec candidate.
- **Streaming Transport:** Exact streaming transport (e.g., UDP vs WebSocket over Tailscale) is **PROPOSED / TO BE VALIDATED**; neither protocol is permanently locked.
- **Latency Budget (Target / Proposed):** Network transport < 50 ms (TARGET), STT < 400 ms (TARGET), LLM Time-to-First-Token < 800 ms (TARGET), TTS chunk < 300 ms (TARGET). Total voice roundtrip target: < 1.6 seconds (TARGET; unverified in repository).

---

## 8. Voice Implementation Roadmap (Tracks V0–V6)

| Track | Phase Name | Deliverables | Status |
|---|---|---|---|
| **Track V0** | Audio Foundation | `AudioDeviceManager`, device enumeration, WASAPI/PortAudio capture & playback, PCM ring buffers | Planned |
| **Track V1** | Listening Foundation | `VADProvider` (Silero VAD), `STTProvider` (`whisper.cpp`), multilingual transcription benchmark | Planned |
| **Track V2** | Speaking Foundation | `TTSProvider` (Kokoro / Piper), voice profiles, clause chunking, language capability reporting | Planned |
| **Track V3** | Conversational Voice | Real-time state machine, live token-to-speech streaming, barge-in playback cancellation | Planned |
| **Track V4** | Wake Word | `WakeWordProvider` (openWakeWord), low-power background detection, configurable sensitivity | Planned |
| **Track V5** | Android Remote Audio | Opus stream protocol, Android audio capture/playback, Tailscale network gateway | Planned |
| **Track V6** | Advanced Voice | Speaker identification, noise cancellation filters, emotion/prosody parameters | Planned |

---

## 9. Security, Privacy & Data Retention

1. **Zero Retention by Default:** Raw audio streams are never saved to SQLite, file logs, or cloud buckets. Audio memory buffers are overwritten immediately after transcription.
2. **Local-First Processing Guarantee:** Speech processing executes on local devices by default (on the PC host when PC serves the interaction, or on-device in Android Offline Mode where hardware permits). No audio frames are forwarded to external servers without explicit user configuration and authorization.
3. **Hardware Privacy Indicator:** When capture is active, the Local AI Runtime broadcasts `voice.listening` events so Web and Android clients display prominent recording indicators.
