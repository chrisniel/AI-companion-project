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

## 2. Durable Architecture

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


### 2.4 Capability Ownership

- **Flutter Client Owns:** Mic/device enumeration, capture, output-device selection, playback.
- **Local AI Runtime Owns:** STT, TTS, VAD, `VoiceSession` orchestration, conversation/provider lifecycle.
- **PC V1 Flow:** Push-to-talk fallback, manually started active Voice Conversation, VAD-assisted turn-taking. Constant-listening wake word is deferred.

### 2.5 Mandatory Barge-In

- **Barge-in Behavior:** Must instantly stop playback, cancel pending TTS/audio, cancel stale text generation as appropriate, discard stale chunks, and start the new turn.
- **Identity Check:** Audio uses voice-session + turn identity so stale output cannot accidentally resume after a barge-in.
- **Profile Isolation:** A Profile switch strictly kills the old Profile's voice session and clears all buffers.

### 2.6 Privacy & Data Retention

- **Voice is NOT Authentication:** Conversational voiceprint matching is never used as an authorization or authentication factor.
- **Ephemeral Audio:** Partial STT is ephemeral. The final transcript becomes an ordinary conversation message. Raw audio is not stored by default. Debug capture requires explicit visible opt-in and bounded retention.
- **Cloud Boundaries:** Cloud LLM, cloud STT, and cloud TTS are strictly separate permissions. Gaming/resource pressure never silently sends audio to the cloud.
- **Proactive Speech:** Private proactive speech from notifications or Routines is OFF by default unless the user explicitly opts in.

### 2.7 Actions & Policy

- **Policy Parity:** Voice tools use the exact same D9 policy as text.
- **Low-Confidence Extraction:** Low-confidence consequential action fields require explicit clarification.

### 2.8 Provider Candidates

- Exact provider implementation remains open. `whisper.cpp`, `Kokoro`, and `Silero` remain primary reference candidates.

### 2.9 Composable Mobile Voice Architecture (`D-PHONE-04`, `D-PHONE-14` through `D-PHONE-14G`)

- **Composable Voice Decomposition (`D-PHONE-14`):** Voice functionality decomposes into three independent, decoupled stages:
  1. Speech-to-Text (STT): Converting spoken input into text.
  2. Reasoning / Generation: Conversational turn evaluation and LLM response generation.
  3. Text-to-Speech (TTS): Synthesizing spoken output from generated text.
  Each stage may independently execute via **Local Mobile**, **PC Host**, or separately authorized **Cloud** provider.
- **Connected Mobile Voice (`D-PHONE-14A`):**
  - *Mobile Phone Owns:* Physical microphone capture, audio frame buffering, audio focus management, route transitions (Bluetooth, speaker, earpiece), immediate local muting, and UI controls.
  - *PC Runtime Owns:* Canonical connected STT, turn orchestration, LLM reasoning, TTS synthesis, VAD state, and `VoiceSession` lifecycle over an authenticated full-duplex WebSocket stream.
- **Local Mobile TTS (`D-PHONE-14B`):** Classified as **Conditional Mobile V1**. A qualified on-device lightweight TTS engine may operate independently of local STT or local LLM. It synthesizes assistant speech for local text turns, offline alarms, check-in prompts, and routine occurrences.
- **Local Mobile STT (`D-PHONE-14C`):** Classified as **Conditional Mobile V1**. Supported on devices passing qualification. Mobile V1 focuses strictly on explicit, user-initiated input: push-to-talk, tap-to-speak, or explicit active Voice session mode. Continuous always-on ambient listening is strictly excluded.
- **Full Offline Voice Composition (`D-PHONE-14D`):** Classified as **Conditional Mobile V1**. Full standalone voice (speech input -> local reasoning -> speech output) activates when local STT, local LLM, and local TTS all qualify on the device and current battery/thermal resources permit. If any component becomes unavailable (e.g., thermal throttle unloads the local LLM), voice degrades compositionally (e.g., falling back to local STT input with text display, or text input with local TTS).
- **Voice Route Selection (`D-PHONE-14E`):** Default `Auto` route selection evaluates PC Host reachability, local component qualification, device thermal/battery pressure, internet connectivity, and user cloud authorizations. The active operational route (e.g., `Host STT + Host LLM + Host TTS` vs `Local STT + Local LLM + Local TTS`) must remain truthful and inspectable in the UI. Cloud speech services require distinct, independent user authorizations.
- **Explicit Voice Session Lifecycle (`D-PHONE-14F`):** Background eavesdropping is prohibited. Voice input begins only through explicit user initiation. An explicitly started active voice session may continue when the device is locked under Android foreground service rules with persistent, visible OS notification and audio indicators.
- **Shared STT Candidate Qualification (`D-PHONE-14G`):** `whisper.cpp` is the first approved research candidate for mobile local STT qualification to align with the PC Voice architecture direction. It serves as an empirical research and qualification candidate, replaceable if benchmarks or qualification dictate, without altering overall composable voice architecture. Mobile qualification is distinct from PC; empirical evaluation benchmarks English, Tagalog, Taglish code-switching, date/time recognition, memory footprint, thermal load, and barge-in responsiveness.
- **Shared Voice Invariants:**
  - *Immediate Local Barge-In:* User interruption immediately halts local playback and cancels audio pipelines.
  - *Policy Parity with Text:* Voice-triggered actions enforce identical D9 security and authorization policies.
  - *Ephemeral Audio:* Raw audio buffers are transient and not retained by default, with prompt release after their active processing lifecycle according to the approved Voice privacy policy.
  - *Voice is Not Authentication:* Voice characteristics are never used for biometric authentication.
  - *Independent Cloud Permissions:* Separate toggles govern Cloud LLM, Cloud STT, and Cloud TTS.
  - *No Always-On Wake Word:* Always-on passive wake-word detection is excluded from Mobile V1.
  - *Opt-In Proactive Speech:* Proactive spoken announcements remain strictly opt-in.

---

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality after M4 Batch B (`feature/m4-voice-pipeline-b`):

### 3.1 Backend & Companion API Codebase State

- **Database Schema (`018_voice_settings_and_character_voice.py`, ORM Models):** Implemented `ProfileVoiceSettings` (`profile_voice_settings` table with `profile_id` PK/FK, `barge_in_policy`, `vad_sensitivity`, `stt_language`, `tts_speed`, `default_voice_id`, `auto_read_replies`, `proactive_speech_enabled`, `cloud_stt_enabled`, `cloud_tts_enabled`, `updated_at`) and nullable `CharacterInstance.voice_id` on `character_instances`. `ProfilePurgeService.purge_profile` deletes `ProfileVoiceSettings` prior to `Profile` deletion, and `ProfilePurgeService.soft_delete_profile` + `auth.revoke_session` immediately terminate active WebSocket voice sessions.
- **Audio Validation & Ephemeral Memory Safety (`backend/app/services/voice/audio_utils.py`):** In-memory PCM16/WAV decoding and RMS normalization (`MAX_TRANSCRIBE_WAV_BYTES = 1,468,006` (~1.4 MiB) keeping base64 REST JSON safely beneath the 2 MiB `PayloadLimitMiddleware` cap; `MAX_TURN_AUDIO_BYTES` per WS turn); raw audio is never persisted to disk.
- **Speech Engines & Lazy `VoiceManager` (`backend/app/services/voice/`):**
  - *VAD & Barge-In (`vad.py`):* `SileroOnnxVadProvider` (dynamic `onnxruntime`/`numpy` detection) with automatic pure-stdlib `AdaptiveEnergyVadProvider` fallback (`512`-sample frames @ 16 kHz); `BargeInGate` supports `smart_auto`, `strict_noisy`, and `manual_only` policies across configurable `low`/`medium`/`high` sensitivities.
  - *STT (`stt.py`):* `WhisperCppSttProvider` running windowless localhost-only `runtime/whisper.cpp/whisper-server.exe -ng` on CPU/RAM with explicit unavailable reporting when model weights are absent.
  - *TTS (`tts.py`):* `KokoroOnnxTtsProvider` (dynamic `onnxruntime`/`numpy` detection, embedded G2P-to-IPA converter, `tokenizer.json`, and `.bin` style vectors) with automatic `WindowsSapiTtsProvider` fallback on Windows (`af_nicole` / voice catalog).
  - *Lifecycle (`manager.py`, `main.py`):* Lazy `VoiceManager` (`get_voice_manager()`) shuts down cleanly via `reset_voice_manager()` inside FastAPI `lifespan`, preserving clean `test_import_isolation.py` collection without heavy module-level side effects and zero `backend/requirements.lock` changes (Option 1).
- **Duplex WebSocket & REST Control Plane (`session_orchestrator.py`, `ws_protocol.py`, `endpoints/voice.py`):**
  - *REST Endpoints (`/api/v1/voice/*`):* `GET /status`, `GET /voices`, `GET /settings`, `PATCH /settings`, `POST /transcribe`, and `POST /synthesize` (resolving explicit voice -> active/conversation `CharacterInstance.voice_id` -> `ProfileVoiceSettings.default_voice_id` -> `af_nicole`).
  - *WebSocket (`/api/v1/voice/ws`):* Full-duplex `VoiceSessionOrchestrator` with no request-scoped `Depends(get_db)` session, authenticating via `Authorization` header or initial `session.start` `session_token`, streaming `vad.state`, `stt.final`, `llm.delta`, `tool.intent`, `tool.result`, `tool.confirmation_required`, `tts.audio.chunk`, `tts.end`, `turn.cancelled`, `pong`, and `error` frames. Enforces identical D9 tool policies (`orchestrate_chat_stream`), shared `_get_lock(conversation_id)` concurrency safety, and bounded `await asyncio.wait_for(task, timeout=5.0)` cancellation on manual or VAD-triggered `barge_in`.
- **OpenAPI 3.1 & `companion_api` Dart SDK:** Regenerated `contracts/openapi/openapi.json` (`80` REST paths), added `voice_dto.dart`, optional `voiceId` / `clearVoiceId` on `CharacterInstance*`, `WebSocketChannelCompanionClient` (enforcing D5 `wss://` on credentialed non-loopback hosts), `VoiceSessionClient` (suppressing stale `turn_id` output after `barge_in`), and `6` REST methods on `CompanionClient` (`87/87` schemas, `99/99` covered routes in `check_dart_openapi_parity.py --check`).

### 3.2 Desktop & Mobile Audio Hardware State

- **Flutter Desktop Native Audio I/O, Hotkeys & Option A Voice UI (M4 Batch C Implemented & Automated-Verified on `feature/m4-voice-desktop-c`):**
  - *Native C++ Runner Channel (`windows_audio_channel.h/.cpp`, `flutter_window.cpp`):* Zero-plugin WASAPI (`IMMDeviceEnumerator` + `IAudioClient` capture/render) MethodChannel (`ai_companion/windows_audio`) with STA-safe COM initialization (`ScopedUiComGuard`) and dedicated MTA worker threads marshaling audio/RMS frames via UI-thread message queue (`kWmAudioEvent`), dynamic RIFF subchunk scanning + linear PCM resampler, generation-fenced `FlushPlayback` (`<50ms`), in-memory two-note sine `playTestTone`, and Win32 `RegisterHotKey` (`WM_HOTKEY`) registration with conflict reporting.
  - *Dart Adapter & Controller (`desktop_audio_adapter.dart`, `desktop_client_settings.dart`, `desktop_voice_controller.dart`):* Manages device enumeration, device-local hardware/shortcut persistence without clobbering unrelated settings, ephemeral `pcm16` dictation capped at `1,468,006` bytes, duplex `WS /api/v1/voice/ws` lifecycle, generation-tagged barge-in cut, hard OS mute synced with `DesktopLifecycleCoordinator` tray menu, Auto-Read on clean turn completion, and full session teardown + cache purge on Profile switch (`handleProfileEpochChanged`).
  - *Option A Desktop UI (`chat_screen.dart`, `live_voice_stage_panel.dart`, `voice_shortcut_recorder.dart`, `settings_voice_section.dart`, `desktop_studio_controller.dart`, `studio_inspector_panel.dart`, `desktop_shell.dart`):* Removed standalone `Voice` nav rail tab (`5` primary rail tabs), integrated `Live Voice` + `Auto-Read` header toggles, `LiveVoiceStagePanel` (reactive orb, RMS meter, live transcripts, Mute, composer-unfocused `Spacebar` Interrupt, `Right Alt` PTT hint, End Voice), active Composer Dictate button, and per-message `Read Aloud / Stop` into `ChatScreen`; promoted `Settings -> Voice & Audio` (`SettingsVoiceSection`); added nullable `voiceId` + `clearVoiceId: true` and preview inside `Character Studio`; wired `shell_mic_privacy_indicator` glowing amber privacy pill into `DesktopShell` (`423/423` Desktop tests passing, Windows debug executable built; manual physical hardware audio QA pending).
- **Flutter Mobile Audio Pipeline:** `NOT IMPLEMENTED`. Mobile audio capture, playback, audio focus handlers, and on-device mobile STT/TTS engines remain future Mobile V1 work.

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
- **Mobile System Baseline:** [`docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md)
- **Mobile Capabilities & Runtime Spec:** [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Infrastructure/mobile-capabilities-and-runtime.md)
- **Mobile Offline & Sync Spec:** [`docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`](../04_Infrastructure/mobile-offline-and-sync.md)
- **Client Target ADR:** [`docs/04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md`](../decisions/ADR-0017-flutter-production-windows-client.md)
- **Client-Runtime Contract ADR:** [`docs/04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md`](../decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) , [`WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-VOICE-001`)
- **UI Design Presentation:** [`docs/05_Design/05_Voice_Mode_and_Audio_Controls.md`](../../05_Design/05_Voice_Mode_and_Audio_Controls.md)
