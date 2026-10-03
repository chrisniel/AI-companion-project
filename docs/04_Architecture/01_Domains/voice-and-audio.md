# Voice and Audio Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

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

### 2.1 Native Client & Runtime Voice Architecture 

In accordance with Decision D1:
- **Hardware & Processing Boundary:**
  - **Flutter Desktop Client:** Owns local audio hardware enumeration, physical microphone capture, speaker/headphone playback, and OS audio focus.
  - **Local AI Runtime:** Owns the speech pipeline engines (`STTProvider` and `TTSProvider`) and conversational turn coordination.
- **WebSocket Full-Duplex Transport (`ADR-0019`):** Audio frames and speech control events stream over a dedicated persistent WebSocket connection between the desktop client and runtime.
- **Approved PC V1 Local Speech Engines:**
  - **Speech-to-Text (STT):** Local STT engine (e.g., whisper.cpp candidate) (executing on CPU/RAM to preserve GPU VRAM).
  - **Text-to-Speech (TTS):** Local TTS engine (e.g., Kokoro-82M candidate) (executing on CPU/RAM for fast, high-quality local voice synthesis).
  - **Voice Activity Detection (VAD):** In-stream turn detection via Silero VAD or equivalent lightweight model.
- **Mandatory Voice Barge-In (PC V1):**
  - Companion voice playback must support real-time user interruption.
  - When user speech is detected during assistant TTS output, the client immediately mutes audio output, sends a `barge_in` cancellation frame over the WebSocket, and the runtime cancels downstream LLM/TTS generation.
- **Wake Word Phasing:** Always-on wake-word detection is formally decoupled from conversational voice and scheduled for **PC Later**. PC V1 voice interaction relies on explicit, consented user initiation (push-to-talk, click-to-speak, or active voice session mode).

### 2.2 Hardware Resource Isolation Principle

- **Durable Principle:** Speech processing **SHOULD** avoid unnecessary contention with the active generative model on constrained target hardware.
- **Reference Strategy (CPU/RAM-First):** To safeguard precious GPU VRAM for the primary text/multimodal LLM on reference hardware (8 GB RX 580 baseline), speech transcription and synthesis are designed reference-first to execute comfortably on CPU and system RAM.
- **Implementation Flexibility:** The architecture does not permanently lock speech to CPU forever. On higher-end hardware with abundant compute or dedicated NPUs, providers may utilize hardware acceleration if resource contention policies permit.

### 2.3 Voice Privacy Invariant

- **Durable Privacy Invariant:** *"Raw user audio is not persistently retained by default without explicit user consent."*
- Buffering is kept strictly in transient memory during active turns. User-approved transcripts are persisted as conversation messages; raw audio chunks are discarded after turn completion.

---

## 2. Frozen PC V1 Voice Semantics & Architecture

### 2.1 Capability Ownership

- **Flutter Client Owns:** Mic/device enumeration, capture, output-device selection, playback.
- **Local AI Runtime Owns:** STT, TTS, VAD, `VoiceSession` orchestration, conversation/provider lifecycle.
- **PC V1 Flow:** Push-to-talk fallback, manually started active Voice Conversation, VAD-assisted turn-taking. Constant-listening wake word is deferred.

### 2.2 Mandatory Barge-In

- **Barge-in Behavior:** Must instantly stop playback, cancel pending TTS/audio, cancel stale text generation as appropriate, discard stale chunks, and start the new turn.
- **Identity Check:** Audio uses voice-session + turn identity so stale output cannot accidentally resume after a barge-in.
- **Profile Isolation:** A Profile switch strictly kills the old Profile's voice session and clears all buffers.

### 2.3 Privacy & Data Retention

- **Voice is NOT Authentication:** Conversational voiceprint matching is never used as an authorization or authentication factor.
- **Ephemeral Audio:** Partial STT is ephemeral. The final transcript becomes an ordinary conversation message. Raw audio is not stored by default. Debug capture requires explicit visible opt-in and bounded retention.
- **Cloud Boundaries:** Cloud LLM, cloud STT, and cloud TTS are strictly separate permissions. Gaming/resource pressure never silently sends audio to the cloud.
- **Proactive Speech:** Private proactive speech from notifications or Routines is OFF by default unless the user explicitly opts in.

### 2.4 Actions & Policy

- **Policy Parity:** Voice tools use the exact same D9 policy as text.
- **Low-Confidence Extraction:** Low-confidence consequential action fields require explicit clarification.

### 2.5 Provider Candidates

- Exact provider implementation remains open. `whisper.cpp`, `Kokoro`, and `Silero` remain primary reference candidates.

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality:

### 3.1 Codebase State

- **Voice Subsystem Runtime:** `NOT IMPLEMENTED`.
- **Speech Engines:** There is currently zero operational STT, TTS, VAD, or wake-word runtime code integrated into the FastAPI backend or React frontend.
- **Router Status:** `app.api.v1.router` mounts health, auth, tasks, llm, conversations, attachments, and memories routers. No audio, voice, or speech endpoints are mounted.
- **Frontend State:** Voice UI controls in the frontend operate as non-functional visual placeholders or UI previews without backend WebSocket or audio streaming bindings.

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved under Decisions D1, D11, and the Master Decision Register:

1. **Conversational Speech Pipeline (PC V1):**
   - Consented conversational voice interaction integrated with the primary conversation view.
   - Provider abstraction layer decoupling the backend from specific inference binaries or models.
   - Streaming or chunked audio ingestion with VAD-assisted or explicit turn boundary detection.
2. **Candidate Provider Adapters:**
   - **STT Candidate:** `whisper.cpp` is the primary/reference PC STT candidate, not an eternal requirement.
   - **TTS Candidate:** `Kokoro` is the primary/reference local PC TTS candidate, not an eternal requirement. `ElevenLabs` remains an optional cloud TTS candidate.
   - **VAD Candidate:** `Silero VAD` (VAD remains provider-independent).
   *(Note: These named engines are evaluated candidates for specific adapters; none are locked as mandatory architectural release requirements.)*
3. **Wake Word Detection (PC Later):**
   - Background listening for low-power activation phrases (Candidate: `openWakeWord`). Deferred beyond PC V1 to preserve battery/resource budgets and privacy boundaries.

---

## 5. Implementation-Open Details (Decision Debt)

The normative architecture for Voice is frozen. The following implementation-level details are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Turn-Taking & VAD Tuning:** VAD threshold parameters, silence detection window length, and speaking cadence tuning (`DEBT-V1-011`).
- **Audio Device Hotplugging:** Host audio device enumeration, default sink switching, and Bluetooth headset disconnect recovery in Flutter (`DEBT-V1-012`).
- **Wake Word Detection (PC Later):** Background listening for low-power activation phrases (`openWakeWord`). Deferred beyond PC V1.

---

## 6. Security & Ownership Boundaries

- **Consent Boundaries:** The microphone must never open or record without clear user action or explicit, visible UI state.
- **Transcript Authority:** Generated text transcripts become user messages within conversations, inheriting standard profile data ownership and retention rules (`profile_id`).
- **Network Boundaries:** Local speech processing occurs entirely on-device under Local AI Runtime authority; audio data is never transmitted to external cloud endpoints without explicit opt-in configuration.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, Voice)
- **Client Target ADR:** [`docs/04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md`](../decisions/ADR-0017-flutter-production-windows-client.md)
- **Client-Runtime Contract ADR:** [`docs/04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md`](../decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) , [`WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-VOICE-001`)
- **UI Design Presentation:** [`docs/05_Design/05_Voice_Mode_and_Audio_Controls.md`](../../05_Design/05_Voice_Mode_and_Audio_Controls.md)
