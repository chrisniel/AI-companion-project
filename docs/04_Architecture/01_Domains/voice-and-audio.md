# Voice and Audio Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.1).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** This document is authored as part of the staged documentation reconciliation. Primary canonical authority remains in [`docs/04_Architecture/VOICE_AND_AUDIO_ARCHITECTURE.md`](../VOICE_AND_AUDIO_ARCHITECTURE.md) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decisions D1 & D11) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the audio ingestion, speech processing, synthesis, privacy rules, and runtime lifecycle for voice-enabled companion interaction:
- Bidirectional conversational voice (audio capture, speech-to-text, text-to-speech, audio playback).
- Voice Activity Detection (VAD) and spoken turn boundary detection.
- Resource isolation principles across constrained host hardware.
- Privacy boundaries governing raw audio buffers and transcripts.
- Phased speech capabilities (conversational voice in PC V1 vs. wake word in PC Later).

It governs the boundary between audio hardware/drivers and conversational assistant orchestration.

---

## 2. Durable Architecture & Invariants

### 2.1 Provider-Independent Conversational Voice (PC V1)

In accordance with Decision D1 (PC V1 release boundary) and Decision D11 (decoupled voice configuration):
- **Core Capability:** The PC V1 milestone requires **provider-independent conversational voice capability without wake word**:
  1. Audio capture from host microphones.
  2. Explicit, user-consented session initiation and turn-taking.
  3. Speech-to-Text (STT) transcription.
  4. Spoken turn detection via Voice Activity Detection (VAD) or explicit user controls where required.
  5. Text-to-Speech (TTS) synthesis of companion responses.
  6. Audio output playback to host speakers or headphones.
- **Provider Independence:** The architecture is decoupled from proprietary or specific third-party engines. Speech subsystems interact through abstract interfaces (e.g., `STTProvider`, `TTSProvider`, `VADDetector`).
- **Wake Word Phasing:** Always-on wake-word detection is formally decoupled from conversational voice and scheduled for **PC Later**. PC V1 voice interaction relies on explicit, consented user initiation; push-to-talk and click-to-speak represent interaction candidates, while the exact initiation UX remains OPEN DESIGN.
- **Barge-In Status:** User interruption during companion speech (barge-in) is an approved target capability, but is **not** a hard blocking gate for PC V1 delivery unless explicitly promoted.

### 2.2 Hardware Resource Isolation Principle

- **Durable Principle:** Speech processing **SHOULD** avoid unnecessary contention with the active generative model on constrained target hardware.
- **Reference Strategy (CPU/RAM-First):** To safeguard precious GPU VRAM for the primary text/multimodal LLM on reference hardware (e.g., 8 GB RX 580 baseline), speech transcription and synthesis are designed reference-first to execute comfortably on CPU and system RAM.
- **Implementation Flexibility:** The architecture does **not** permanently lock speech to CPU forever. On higher-end hardware with abundant compute or dedicated NPUs, providers may utilize hardware acceleration if resource contention policies permit. (Decision D2 provides cross-cutting context for long-running host process lifecycle).

### 2.3 Voice Privacy Invariant

- **Durable Privacy Invariant:** *"Raw user audio is not persistently retained by default without explicit user consent."*
- **No Implementation Lock:** Architecture establishes the privacy guarantee without permanently locking a single specific buffering mechanism (e.g., it does not dictate that all PCM audio must strictly reside in RAM and be instantly wiped).
- Buffering duration, debug audio capture, transcript logging, opt-in audio recording, and temporary disk cleanup intervals remain implementation details and open design.

---

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality:

### 3.1 Codebase State

- **Voice Subsystem Runtime:** `NOT IMPLEMENTED`.
- **Speech Engines:** There is currently zero operational STT, TTS, VAD, or wake-word runtime code integrated into the FastAPI backend or React frontend.
- **Router Status:** `app.api.v1.router` mounts health, auth, tasks, llm, conversations, attachments, and memories routers. No audio, voice, or speech endpoints are mounted.
- **Frontend State:** Voice UI controls in the frontend operate as non-functional visual placeholders or UI previews without backend WebSocket or audio streaming bindings.

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved under Decisions D1, D11, and the Feature Promotion Map:

1. **Conversational Speech Pipeline (PC V1):**
   - Consented conversational voice interaction integrated with the primary conversation view.
   - Provider abstraction layer decoupling the backend from specific inference binaries or models.
   - Streaming or chunked audio ingestion with VAD-assisted or explicit turn boundary detection.
2. **Candidate Provider Adapters:**
   - **STT Candidate:** `Whisper` (via `whisper.cpp`, `faster-whisper`, or ONNX Runtime).
   - **TTS Candidate:** `Kokoro` (or lightweight alternatives such as `Piper`).
   - **VAD Candidate:** `Silero VAD` (via ONNX Runtime).
   *(Note: These named engines are evaluated candidates for specific adapters; none are locked as mandatory architectural release requirements.)*
3. **Wake Word Detection (PC Later):**
   - Background listening for low-power activation phrases (Candidate: `openWakeWord`). Deferred beyond PC V1 to preserve battery/resource budgets and privacy boundaries.

---

## 5. OPEN DESIGN

The following implementation choices remain intentionally open for architectural investigation:

- **Session Initiation & Turn Control UX:** Exact UI/UX mechanisms for initiating, holding, and closing voice turns (push-to-talk, click-to-speak, visual voice toggle, or hands-free conversational loop).
- **Audio Streaming Transport:** Choice between WebSocket binary frames, WebRTC data channels, or multipart HTTP chunk uploads between frontend and backend.
- **Buffer Management & Retention:** Specific memory ring-buffer vs. temporary disk spooling architecture and cleanup timeouts.
- **Debug Capture & Diagnostics:** Opt-in debug recording mechanics, retention quotas, and troubleshooting log schemas.
- **Barge-In Implementation:** Exact echo-cancellation, acoustic playback suppression, and model generation cancellation mechanisms.
- **Audio Routing & Hotplugging:** Host audio device enumeration, default sink switching, and Bluetooth headset disconnect handling on Windows.

---

## 6. Security & Ownership Boundaries

- **Consent Boundaries:** The microphone must never open or record without clear user action or explicit, visible UI state.
- **Transcript Authority:** Generated text transcripts become user messages within conversations, inheriting standard profile data ownership and retention rules.
- **Network Boundaries:** Local speech processing occurs entirely on-device under Local AI Runtime authority; audio data is never transmitted to external cloud endpoints without explicit opt-in configuration.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical Architecture Source:** [`docs/04_Architecture/VOICE_AND_AUDIO_ARCHITECTURE.md`](../VOICE_AND_AUDIO_ARCHITECTURE.md) (Retains primary authority until R11.4)
- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decisions D1 & D11; §3 Windows Host Context, Decision D2)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Conversational Voice (STT / TTS), Wake Word Detection)
- **Character Domain Specification:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](characters-personality-and-emotion.md) (Voice profile associations)
