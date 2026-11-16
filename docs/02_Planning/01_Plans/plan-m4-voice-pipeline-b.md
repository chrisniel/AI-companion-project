# Implementation Plan: M4 Batch B — Local Speech Pipeline, Duplex Voice WebSocket & Companion API Parity

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Awaiting Approval
- **Delivery Level:** Level C — Sensitive Design
- **Scope Mode:** New Feature — M4 Batch B backend speech pipeline (`whisper.cpp` STT subprocess adapter, `Silero` ONNX / adaptive pure-Python VAD with anti-false-trigger `BargeInGate`, `Kokoro-82M` ONNX / Windows SAPI TTS adapters), Alembic Migration `018` (`profile_voice_settings` & nullable `character_instances.voice_id`), authenticated full-duplex `WS /api/v1/voice/ws` session orchestrator with D9 tool parity and mandatory barge-in, `/api/v1/voice/*` REST endpoints, OpenAPI 3.1 regeneration, and `companion_api` Dart SDK WebSocket + REST + DTO parity. (Windows C++ WASAPI/hotkey native channel and Option A Flutter Desktop Voice/Chat/Settings/Studio UI belong to follow-on **M4 Batch C**.)
- **Target Files:**
  - `backend/app/core/config.py`
  - `backend/app/main.py`
  - `backend/app/models/` (`profile_voice_settings.py`, `character_instance.py`, `__init__.py`)
  - `backend/migrations/versions/018_voice_settings_and_character_voice.py`
  - `backend/app/schemas/` (`voice.py`, `character.py`)
  - `backend/app/services/voice/` (`__init__.py`, `audio_utils.py`, `vad.py`, `stt.py`, `tts.py`, `ws_protocol.py`, `session_orchestrator.py`, `manager.py`)
  - `backend/app/services/character_service.py`
  - `backend/app/services/profile_purge_service.py`
  - `backend/app/api/v1/endpoints/voice.py` & `backend/app/api/v1/router.py`
  - `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, & `scripts/tests/test_check_dart_openapi_parity.py`
  - `frontend/flutter/packages/companion_api/lib/` (`dto/voice_dto.dart`, `dto/character_dto.dart`, `transport/ws_transport.dart`, `transport/ws_transport_io.dart`, `client/companion_client.dart`, `client/voice_session_client.dart`, `companion_api.dart`)
  - `backend/tests/` (`test_migration_018.py`, `test_voice_engines_and_barge_in.py`, `test_voice_api_and_ws.py`, updates to `test_prepare_database_schema_backup.py` / `test_schema_lifecycle.py` / `test_character_*` if head/column assertions apply)
  - `frontend/flutter/packages/companion_api/test/voice_dto_and_ws_test.dart`
  - Phase 3 docs: canonical specs (`voice-and-audio.md`, `characters-personality-and-emotion.md`, `privacy-retention-and-audit.md`), `DELIVERY_INDEX.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `DECISION_DEBT.md` (`DEBT-V1-04` resolution), `CHANGELOG.md`, walkthrough, and archived branch tracker.
- **Branch:** `feature/m4-voice-pipeline-b`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m4-voice-pipeline-b.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m4-voice-pipeline-b.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:** Deliver **Milestone M4 Batch B** (`PC-VOICE-002..005`, `PC-API-001`, `PC-API-003`, `PC-CLIENT-004`, `DEBT-V1-04`) establishing the backend local speech runtime, privacy-enforcing full-duplex WebSocket voice orchestrator with mandatory anti-false-trigger barge-in, persistent per-Profile & per-Character voice settings, and the typed `companion_api` Dart REST/WebSocket SDK needed by **M4 Batch C** (native Windows WASAPI/Hotkey channel and Option A Desktop UI):
  1. **Local Speech Provider Adapters (`whisper.cpp`, `Silero` / Adaptive VAD, `Kokoro-82M` / Windows SAPI):** Resolve `DEBT-V1-04` cleanly by driving pre-staged `runtime/whisper.cpp/whisper-server.exe` as a supervised, windowless, localhost-only (`127.0.0.1`) CPU-first subprocess daemon; supporting `models/vad/silero-vad-v6.2.1/silero_vad.onnx` and `models/tts/kokoro-82m-v1.0/model_quantized.onnx` when ONNX runtime is present alongside deterministic zero-dependency pure-Python VAD & native Windows `System.Speech` SAPI fallbacks.
  2. **Duplex WebSocket Orchestrator & Mandatory Anti-False-Trigger Barge-In (`WS /api/v1/voice/ws`):** Enforce fail-closed `ProfileSession` authentication, monotonic `(voice_session_id, turn_id, seq)` identity stamping so stale chunks never play after interruption, configurable `BargeInGate` speech-hold hysteresis (`smart_auto` `280ms`, `strict_noisy` `400ms`, `manual_only`), strict RAM-only ephemeral audio lifecycle (zero raw audio persisted or retained past turn end), and reuse of `AssistantOrchestrator` so voice turns inherit character persona, traits, mood, 3-tier memory, and **D9 tool policy parity** identically to text turns.
  3. **Voice Settings & Catalog REST API + `companion_api` Dart SDK:** Persist per-Profile voice settings (`profile_voice_settings`) and optional per-Character `voice_id` overrides (`character_instances.voice_id`), expose 6 typed REST endpoints under `/api/v1/voice/*` supporting both Desktop Live Voice and single-shot Chat Dictation / "Read aloud" / Auto-Read TTS, regenerate `contracts/openapi/openapi.json`, and deliver real `web_socket_channel`-backed `WebSocketChannelCompanionClient` + `VoiceSessionClient` + `voice_dto.dart`.
- **Relevant Canonical Requirements:**
  - [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) — §3 Invariants #3 (`Multi-Profile`), #5 (`D9`), #6 (`Single Resident Model`), #8 (`D5`), #9 (`ADR-0019`), #10 (`Native Voice Architecture`), and §5 Golden Group G9.
  - [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../../04_Architecture/01_Domains/voice-and-audio.md) — §2.1–§2.8: hardware vs runtime ownership, CPU/RAM-first speech isolation, ephemeral RAM-only raw audio invariant, mandatory barge-in with `(voice_session_id, turn_id)` identity checks, Profile switch cleanup, voice-is-not-authentication, off-by-default proactive speech & cloud toggles, and D9 policy parity.
  - [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../../04_Architecture/01_Domains/assistant-and-conversations.md) — turn preparation, `conversation_lock`, and SSE/orchestrator reuse.
  - [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](../../04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md) — Profile cascade purge ordering and zero unauthorized raw audio persistence.
  - [`docs/04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md`](../../04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md) — WebSocket voice transport contract.
  - [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md) — `DEBT-V1-04` (Local STT & TTS Process Architecture), `DEBT-V1-011` (VAD/turn-taking tuning).
- **Concrete Deliverables:**
  1. Alembic Migration `018_voice_settings_and_character_voice.py` adding `profile_voice_settings` and nullable `character_instances.voice_id` (plus `ProfilePurgeService` cascade cleanup and `CharacterInstance*` DTO/service parity).
  2. `backend/app/services/voice/` package implementing `audio_utils.py`, `vad.py` (`VadProvider`, `SileroOnnxVadProvider`, `AdaptiveEnergyVadProvider`, `BargeInGate`), `stt.py` (`SttProvider`, `WhisperCppSttProvider`, `MockSttProvider`), `tts.py` (`TtsProvider`, `KokoroOnnxTtsProvider`, `WindowsSapiTtsProvider`, `MockTtsProvider`), `ws_protocol.py`, `session_orchestrator.py`, and lazy `manager.py` wired cleanly into `backend/app/main.py` lifespan shutdown.
  3. Authenticated `backend/app/api/v1/endpoints/voice.py` mounted on `api_v1_router` (`6` REST routes under `/api/v1/voice/*` + `WS /api/v1/voice/ws`).
  4. Regenerated `contracts/openapi/openapi.json`, updated `scripts/check_dart_openapi_parity.py` & tests, `voice_dto.dart`, updated `character_dto.dart` (`voiceId`), real `WebSocketChannelCompanionClient` (`ws_transport_io.dart`), `VoiceSessionClient`, and `CompanionClient` REST methods.
  5. Full automated unit, WebSocket/barge-in integration, migration, purge-isolation, and Dart SDK verification suites passing cleanly.
- **Explicit Out-of-Scope:**
  - **M4 Batch C Desktop Audio Channel & UI:** Native Windows C++ WASAPI capture/playback, Win32 `RegisterHotKey` customizable shortcuts (`windows_audio_channel.h/.cpp`), removal of standalone `Voice` rail tab (`Option A`), `ChatScreen` Live Voice Stage / Dictation / Auto-Read UI, `Settings -> Voice & Audio` section promotion, `Character Studio` voice picker UI, and `DesktopShell` / Tray mic controls remain cleanly deferred to **M4 Batch C**.
  - **Post-V1 / Excluded Features:** Always-on wake word (`openWakeWord`, `PC Later`), voice biometric authentication (explicitly prohibited), cloud STT/TTS upstream calls (cloud toggles are persisted `False` default policy flags only until M5 Cloud milestone), and React Web UI voice implementation (`frontend/web/` untouched).
  - **Python Lockfile Policy (Conditional Approval Item):** By default (`Option 1`), `backend/pyproject.toml`, `backend/requirements.txt`, and `backend/requirements.lock` remain untouched while `KokoroOnnxTtsProvider` & `SileroOnnxVadProvider` detect `onnxruntime`/`numpy` dynamically; see Section 6 if Human Owner prefers `Option 2` pinning `onnxruntime` + `numpy` into `requirements.lock` during Slice 1.

---

## 2. Architecture & Technical Approach

- **Current Findings & Technical Baseline:**

  | Observation / Evidence | Verified Interpretation |
  | --- | --- |
  | `runtime/whisper.cpp/` already stages `whisper-server.exe` (supporting `--host 127.0.0.1 --port <N> -ng/--no-gpu -m <bin> -l <lang> --vad -vm <silero.onnx>`), `whisper.dll`, and `ggml-cpu-*.dll`; `models/tts/kokoro-82m-v1.0/` holds `model_quantized.onnx` (92 MB), `tokenizer.json` (IPA phoneme vocab), and `voices/af_nicole.bin` (522 KB); `models/vad/silero-vad-v6.2.1/silero_vad.onnx` (2.3 MB) is present; `models/stt/whisper/` currently contains no `.bin` weight file. | Driving `whisper-server.exe` over loopback HTTP (`httpx`, already locked) resolves STT without adding heavy C-extension audio deps; `WhisperCppSttProvider` must check for both `whisper-server.exe` and a `.bin` GGML file and report truthful `unavailable` status in `GET /api/v1/voice/status` when no `.bin` model is staged yet. |
  | `backend/requirements.lock` + `.github/workflows/ci.yml` strictly verify exact Python `3.11.9` Windows x64 wheel hashes (`scripts/python_dependency_lock.py verify`), `uvicorn[standard]` already bundles `websockets`, Python `3.13` local venv removed stdlib `audioop`, and `runtime/ci-cancellation/qualification311` hosts local CPython `3.11.9` + `pip 26.1.2`. | Using `array('h')` + `math` + `wave` avoids Python `3.13` `audioop` removal issues; keeping `requirements.lock` unchanged by default (`Option 1`) avoids CI/local wheel skew while clean optional imports allow `onnxruntime` + `numpy` execution whenever installed alongside Windows SAPI + adaptive energy fallbacks. |
  | `backend/app/core/storage.py` (`CanonicalPaths`) already defines `VOICE_LIBRARY_DIR`, while `backend/app/models/character_instance.py` and `migrations/versions/012_character_mood_and_emotion.py` attach 5 SQLite triggers + partial index `uq_character_instances_profile_legacy_id` to `character_instances`. | Voice model search checks `settings.VOICE_LIBRARY_DIR` first, falling back to `settings.MODELS_DIR/{stt,tts,vad}`; Migration `018` adds nullable `character_instances.voice_id` via `op.add_column` directly and drops it via `op.drop_column` in `downgrade()` (never table-rebuilding batch mode) so all 5 SQLite triggers stay intact, and seeds default `profile_voice_settings` rows for existing profiles. |
  | `backend/app/core/profile_sessions.py` provides `get_current_profile_session` and `guarded_tokens`, `backend/app/api/deps.py` binds `Depends(get_db)` to request lifetimes, `PayloadLimitMiddleware` (`backend/app/main.py:58-88`) enforces `MAX_REQUEST_BODY_BYTES = 2_097_152` on non-attachment POSTs, and `SecurityAndTracingMiddleware` skips WebSockets. | `WS /api/v1/voice/ws` must NOT declare `Depends(get_db)` or `Depends(get_current_profile_session)` in its route signature; instead it validates auth via isolated `get_session_factory()` session (header or `session.start` within 5.0s, closing `4401` on failure) and opens fresh per-turn `AsyncSession` scopes. `POST /api/v1/voice/transcribe` bounds `MAX_TRANSCRIBE_WAV_BYTES = 1_468_006` (~1.4 MiB decoded $\rightarrow$ ~1.95 MiB base64 JSON) to stay safely under `PayloadLimitMiddleware`. |
  | `frontend/flutter/packages/companion_api/pubspec.yaml` depends on `web_socket_channel: ^3.0.1`, `lib/transport/ws_transport.dart` defines `CompanionWebSocketClient`, `task_dto.dart` uses `toJson({bool clearNotes = false})` to avoid extra class fields failing `check_dart_openapi_parity.py`, `desktop_chat_test.dart` constructs `const CharacterInstanceOut(...)`, and `test_prepare_database_schema_backup.py:22` / `test_schema_lifecycle.py:16` pin `HEAD_REVISION`. | Implementing `WebSocketChannelCompanionClient` (`ws_transport_io.dart`) + `VoiceSessionClient` adds zero new pub dependencies; `CharacterInstanceOut` adds optional `this.voiceId`, `CharacterInstanceUpdate` uses `toJson({bool clearVoiceId = false})` to pass parity while supporting explicit null clears; `HEAD_REVISION` updates to `018_voice_settings_and_character_voice` and `test_check_dart_openapi_parity.py:84` updates `93` $\rightarrow$ `99`. |
  | `backend/tests/test_import_isolation.py` rejects import-time socket/file/subprocess side effects on FastAPI app import. | All `VoiceManager`, STT daemon, ONNX session, and Windows SAPI initialization must happen lazily on explicit startup/request/test invocation, never at module import time. |

- **Architectural Approach:**
  1. **Schema & Profile Purge Safety (`018_voice_settings_and_character_voice.py`):**
     - `profile_voice_settings` table (`profile_id` PK + FK `profiles.id` `ON DELETE CASCADE`, `barge_in_policy` IN `('smart_auto', 'strict_noisy', 'manual_only')` default `'smart_auto'`, `vad_sensitivity` IN `('low', 'medium', 'high')` default `'medium'`, `stt_language` `String(16)` default `'auto'`, `tts_speed` `Float` CHECK `BETWEEN 0.5 AND 2.0` default `1.0`, `default_voice_id` `String(64)` default `'af_nicole'`, `auto_read_replies` `Boolean` default `0`, `proactive_speech_enabled` `Boolean` default `0`, `cloud_stt_enabled` `Boolean` default `0`, `cloud_tts_enabled` `Boolean` default `0`, `created_at`, `updated_at`). Backfill existing profiles in Migration `018` (`INSERT INTO profile_voice_settings (profile_id) SELECT id FROM profiles`) and also lazily initialize defaults in `GET /api/v1/voice/settings` if absent.
     - Nullable `character_instances.voice_id` (`String(64)`, default `None`), added via `op.add_column` in `upgrade()` and dropped via `op.drop_column("character_instances", "voice_id")` in `downgrade()` (never table-rebuilding batch mode, preserving all 5 triggers intact). Exposed as optional named `voiceId` on `CharacterInstanceCreate` / `CharacterInstanceUpdate` (`toJson({bool clearVoiceId = false})`) / `CharacterInstanceOut` (`const` optional `this.voiceId` preserving existing tests).
     - Extend `ProfilePurgeService.purge_profile` Phase E deletion list to remove `ProfileVoiceSettings` explicitly in FK-safe order before `Profile`.
  2. **Layered Speech Engines (`backend/app/services/voice/`):**
     - **Audio Framing (`audio_utils.py`):** Normalizes 16kHz mono signed 16-bit PCM chunks (`32000` bytes/sec, `512`-sample `32ms` frames for Silero/Energy VAD), builds/parses RIFF WAV headers cleanly without disk temp files, validates maximum utterance/request size (`MAX_TRANSCRIBE_WAV_BYTES = 1_468_006` decoded bytes, so ~1.95 MiB base64 JSON stays strictly below `PayloadLimitMiddleware`'s 2,097,152-byte ceiling).
     - **VAD & Anti-False-Trigger `BargeInGate` (`vad.py`):**
       - `SileroOnnxVadProvider`: runs `silero_vad.onnx` (state tensor + 512-sample @ 16kHz frame -> speech probability `0.0..1.0`) when `onnxruntime` + `numpy` + model exist cleanly.
       - `AdaptiveEnergyVadProvider`: zero-dependency pure-Python calibrated RMS + zero-crossing-rate + dynamic noise-floor estimator yielding deterministic `0.0..1.0` probability scores.
       - `BargeInGate`: configurable state machine evaluated during `speaking` state:
         - Sensitivity probability/RMS thresholds (`high` = sensitive, `medium` = balanced, `low` = conservative).
         - Policy hold windows: `smart_auto` requires sustained speech frames totaling `>= 280ms` (allowing <= 1 brief gap frame) + echo RMS margin above assistant output; `strict_noisy` requires `>= 400ms` sustained hold + higher probability/RMS floor; `manual_only` ignores speech VAD triggers so only explicit `barge_in` frame / Spacebar / PTT interrupts speech.
     - **STT (`stt.py`):**
       - `WhisperCppSttProvider`: resolves `runtime/whisper.cpp/whisper-server.exe` and newest `.bin` model under `VOICE_LIBRARY_DIR/stt` or `MODELS_DIR/stt/whisper`, launches cleanly on an ephemeral localhost port with `["--host", "127.0.0.1", "--port", str(port), "-ng", "--threads", str(threads), "-m", str(model_path)]` (+ `-l <lang>`) inside Windows `CREATE_NO_WINDOW` job/process group, sends in-memory WAV bytes over `POST /inference` via `httpx`, parses text/language, never writes audio files to disk, and shuts down deterministically in `lifespan` / `VoiceManager.shutdown()`.
       - `MockSttProvider`: used when `VOICE_PROVIDER == "mock"` (or explicit test DI), returning deterministic transcripts from injected fixtures/PCM metadata without touching binaries.
     - **TTS (`tts.py`):**
       - `KokoroOnnxTtsProvider`: activates automatically when `onnxruntime` + `numpy` + `model_quantized.onnx` + `voices/*.bin` are available cleanly; converts text into IPA tokens via embedded pure-Python English grapheme-to-IPA rules + `tokenizer.json` lookup (plus optional local `espeak-ng` if installed on `PATH`), slices `voices/<voice_id>.bin`, runs ONNX CPU inference per sentence chunk (`<= 510` tokens), and streams `24kHz` PCM16/WAV chunks (`voice_id`, `speed` clamped `0.5..2.0`).
       - `WindowsSapiTtsProvider`: native Windows `System.Speech.Synthesis.SpeechSynthesizer` in-memory stream (`SetOutputToWaveStream`) returning WAV bytes over stdout (`CREATE_NO_WINDOW`) when ONNX runtime isn't available cleanly on Windows host, zero temp files.
       - `MockTtsProvider`: generates valid short RIFF PCM16 WAV buffers deterministically for CI/unit/WS integration tests.
  3. **Duplex WebSocket Protocol & Turn Orchestrator (`ws_protocol.py`, `session_orchestrator.py`, `endpoints/voice.py`):**
     - **Auth & Scoped DB Session Lifecycle:** `WS /api/v1/voice/ws` accepts `websocket: WebSocket` directly **without** `Depends(get_db)` or `Depends(get_current_profile_session)` in the route signature (preventing long-lived SQLite transaction holds or pre-handshake 401 drops). It authenticates either from the HTTP `Authorization: Bearer psk_...` header or an initial `session.start` JSON frame received within `5.0s` (`session_token`, `conversation_id`, etc.) using an isolated short-lived session from `get_session_factory()`, verifies `ProfileSession` + `Conversation` ownership (`profile_id`), closes with WS code `4401` on invalid/revoked/deleted-profile auth, and allocates a fresh scoped `AsyncSession` per spoken turn for `prepare_turn` and `orchestrate_chat_stream`. Non-loopback transport enforces D5 HTTPS/WSS awareness consistent with `CompanionClient`.
     - **Frame Envelope (JSON control + base64 PCM16 audio chunks or raw binary PCM16):**
       - *Client -> Server:* `session.start`, `audio.chunk` (`pcm16_base64` or binary frame after `session.start`), `audio.commit`, `barge_in` (`reason`), `config.update` (`barge_in_policy`, `vad_sensitivity`, `voice_id`, `tts_speed`, `stt_language`), `ping`, `session.stop`.
       - *Server -> Client:* `session.ready` (`voice_session_id`, `stt_available`, `tts_provider`, `vad_provider`), `vad.state` (`state`, `probability`, `voice_session_id`, `turn_id`), `stt.partial` (`text`, `voice_session_id`, `turn_id` — ephemeral), `stt.final` (`text`, `message_id`, `voice_session_id`, `turn_id`), `llm.delta` (`content`, `voice_session_id`, `turn_id`), `tool.intent` / `tool.result` / `tool.confirmation_required`, `tts.audio.chunk` (`wav_base64`, `seq`, `sample_rate`, `voice_session_id`, `turn_id`), `tts.end` (`voice_session_id`, `turn_id`, `finish_reason`), `turn.cancelled` (`voice_session_id`, `turn_id`, `reason`), `pong`, `error` (`code`, `message`).
     - **Turn Execution & Barge-In Concurrency:**
       - Reader task continuously consumes client WS frames even while LLM + TTS are running!
       - Incoming `barge_in` frame OR `BargeInGate` trigger during `speaking` state immediately calls `_cancel_active_turn(reason)`: sets `turn_cancel_event`, cancels the generation/TTS task (`asyncio.Task.cancel()`), purges outbound TTS buffer, emits `turn.cancelled(voice_session_id, old_turn_id, reason)`, increments `turn_id += 1`, clears stale PCM buffers (retaining only the interrupting speech tail that triggered barge-in!), and enters `listening` immediately!
       - Any delayed chunk produced right at the cancellation boundary fails the `frame_turn_id == active_turn_id` & `not cancel_event.is_set()` check and is dropped before transmission.
       - Active `VoiceSessionRegistry` allows profile revocation / deletion / server shutdown to terminate open sessions deterministically (`4401` / `1001`) and zero out in-memory audio buffers.
  4. **Voice Catalog & Settings REST Routes (`endpoints/voice.py`, `/api/v1/voice/*`):**
     - `GET /api/v1/voice/status` -> `VoiceStatusOut`
     - `GET /api/v1/voice/voices` -> `VoiceCatalogOut` (`voices: list[VoiceDescriptorOut]`)
     - `GET /api/v1/voice/settings` -> `VoiceSettingsOut`
     - `PATCH /api/v1/voice/settings` -> `VoiceSettingsOut` (strict `VoiceSettingsUpdate` with `extra="forbid"`)
     - `POST /api/v1/voice/transcribe` -> `VoiceTranscribeOut` (`VoiceTranscribeRequest` bounded `<= 1_468_006` decoded bytes; returns transcript + language + duration_ms; zero retention)
     - `POST /api/v1/voice/synthesize` -> `VoiceSynthesizeOut` (`VoiceSynthesizeRequest` `text <= 2000`, resolves `voice_id` -> active character `voice_id` -> profile `default_voice_id` -> engine default; returns `audio_base64` WAV + `sample_rate` + `duration_ms` + `voice_id` + `provider`)
- **Contract & Schema Impact:**
  - Alembic Revision: `018_voice_settings_and_character_voice` (revises `017_d9_tool_policy_and_audit`).
  - OpenAPI routes: +`6` REST routes under `/api/v1/voice/*` (`75` -> `81` OpenAPI paths) plus updated `CharacterInstance*` schemas (`voice_id: Optional[str] = None`).
  - `WS /api/v1/voice/ws` documented cleanly as canonical WebSocket endpoint (excluded by FastAPI OpenAPI HTTP paths, covered by dedicated WS contract tests in both `pytest` and `companion_api/test/`).
  - `companion_api`: `voice_dto.dart` + `character_dto.dart` (`voiceId`, `CharacterInstanceUpdate.toJson({bool clearVoiceId = false})`) + `ws_transport_io.dart` (`WebSocketChannelCompanionClient`) + `voice_session_client.dart` + `CompanionClient` 6 REST methods (`check_dart_openapi_parity.py` upgraded from `93` -> `99` M1–M4 covered routes).

---

## 3. Proposed File Changes & In-Place Logic

### [MODIFY] `backend/app/core/config.py` & `backend/app/main.py`
- **Primary Responsibility:** Add env-overridable voice runtime settings (`VOICE_PROVIDER: str = "auto"`, `VOICE_STT_MODEL_PATH: Optional[str] = None`, `VOICE_WHISPER_THREADS: int = 4`, `VOICE_WHISPER_PORT: int = 0`, `VOICE_MAX_TURN_AUDIO_BYTES: int = 1_468_006`, `VOICE_BARGE_IN_DEFAULT_HOLD_MS: int = 280`) in `Settings`, and shut down active `VoiceSessionRegistry` + `VoiceManager` (`whisper-server.exe`) cleanly during `main.py` `lifespan` exit (matching `llm_manager.get_provider().shutdown()`).
- **Invariants to Preserve:** Zero import-time subprocess/socket/filesystem side effects (`test_import_isolation.py`); preserve `MAX_REQUEST_BODY_BYTES` middleware bounds.

### [ADD] `backend/app/models/profile_voice_settings.py`, `backend/migrations/versions/018_voice_settings_and_character_voice.py` & [MODIFY] `backend/app/models/{__init__.py,character_instance.py}`, `backend/app/services/profile_purge_service.py`
- **Primary Responsibility:** Persist per-Profile voice & barge-in preferences and optional per-Character `voice_id` override with backfill on existing profiles, clean cascade deletion, and zero disruption to existing `character_instances` triggers/constraints.
- **Invariants to Preserve:** Existing `ck_character_instances_legacy_or_standard` & `ck_character_instances_mood_invariants` constraints and all 5 SQLite triggers remain valid on upgrade & downgrade (`op.add_column` / `op.drop_column`, no batch table rebuild); `proactive_speech_enabled`, `cloud_stt_enabled`, `cloud_tts_enabled` default `False`.

### [MODIFY] `backend/app/schemas/character.py` & `backend/app/services/character_service.py` & [ADD] `backend/app/schemas/voice.py`
- **Primary Responsibility:** Add optional `voice_id` field (`max_length=64`, trimmed so whitespace normalizes to `None`) to `CharacterInstanceCreate`, `CharacterInstanceUpdate` (`if "voice_id" in set_fields:` allows explicit `null` clear), `CharacterInstanceOut` (`_to_instance_out`), and define typed Pydantic v2 `extra="forbid"` schemas for `/api/v1/voice/*`.

### [ADD] `backend/app/services/voice/{__init__.py,audio_utils.py,vad.py,stt.py,tts.py,ws_protocol.py,session_orchestrator.py,manager.py}` & [MODIFY] `backend/app/services/assistant/orchestrator.py` / `backend/app/api/v1/endpoints/conversations.py`
- **Primary Responsibility:** Implement modular CPU-first STT/VAD/TTS adapters (`whisper-server.exe` daemon + Kokoro/SAPI + Silero/Adaptive VAD), `BargeInGate` anti-false-trigger state machine, ephemeral RAM-only PCM buffers, shared per-conversation `get_conversation_lock(conversation_id)` between `conversations.py` and voice turns (awaiting cancelled turn unwind cleanly so barge-in replacement turns never hit false `CONVERSATION_BUSY` lock races), LLM readiness pre-flight check before `prepare_turn`, and full-duplex `VoiceSessionOrchestrator` allocating fresh per-turn `AsyncSession` scopes around `prepare_turn` / `orchestrate_chat_stream` + `guarded_tokens`.
- **Invariants to Preserve:** Raw audio never persisted to DB/disk; Profile switch/revocation immediately kills session & wipes RAM buffers; Voice carries identical D9 tool policy guarantees as text; no blocking synchronous waits inside asyncio event loop; no long-lived DB connections held open across idle WS lifetime.

### [ADD] `backend/app/api/v1/endpoints/voice.py` & [MODIFY] `backend/app/api/v1/router.py`
- **Primary Responsibility:** Expose `6` REST endpoints (`get_current_profile_session`) and `WS /api/v1/voice/ws` (`ProfileSession` handshake/init auth without `Depends(get_db)` in WS route signature + active `VoiceSessionRegistry`), mounted on `api_v1_router`.

### [MODIFY] `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py` & [MODIFY / ADD] `frontend/flutter/packages/companion_api/**`
- **Primary Responsibility:** Regenerate OpenAPI 3.1 contract, register `6` `/api/v1/voice/*` routes (`99/99` covered routes) and new Voice schemas in `check_dart_openapi_parity.py`, add `voice_dto.dart`, update `character_dto.dart` (`voiceId` optional field + `CharacterInstanceUpdate.toJson({bool clearVoiceId = false})`), implement `WebSocketChannelCompanionClient` (`ws_transport_io.dart`) & `VoiceSessionClient` (`voice_session_client.dart`) using existing `web_socket_channel: ^3.0.1`, add 6 REST methods (plus optional `clearVoiceId` arg on `updateCharacterInstance`) to `CompanionClient`, and export via `companion_api.dart`.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Slice 1 — Migration `018`, ORM Models, Purge Cascade, Schemas & `audio_utils` / `vad` / `BargeInGate` (RED -> GREEN -> REFACTOR):**
   - Write failing tests (`backend/tests/test_migration_018.py`, `test_voice_engines_and_barge_in.py`) verifying `018` upgrade/downgrade preserves `character_instances` triggers, backfills `profile_voice_settings`, `ProfilePurgeService.purge_profile` cleans `profile_voice_settings`, `audio_utils` PCM/WAV round-trip, and `BargeInGate` hysteresis rejects short noise bursts while firing reliably past `smart_auto` (`280ms`) / `strict_noisy` (`400ms`) holds and suppressing auto-barge-in in `manual_only`.
   - Implement Migration `018`, `ProfileVoiceSettings`, `CharacterInstance.voice_id`, `ProfilePurgeService`, `CharacterInstance*` schemas/service updates, `audio_utils.py`, and `vad.py`, and update hardcoded `HEAD_REVISION = "018_voice_settings_and_character_voice"` in `backend/tests/test_prepare_database_schema_backup.py:22` and `backend/tests/test_schema_lifecycle.py:16`.
2. **Slice 2 — `stt.py`, `tts.py`, Lazy `VoiceManager` & `lifespan` Shutdown (RED -> GREEN -> REFACTOR):**
   - Write failing tests covering `WhisperCppSttProvider` command args (`--host 127.0.0.1`, `-ng`), unavailable-model truthfulness, mocked HTTP `/inference`, clean subprocess shutdown; `KokoroOnnxTtsProvider` tokenization + style slicing (with fake ONNX session + real local `tokenizer.json` / `af_nicole.bin` read checks) + sentence splitting + SAPI/Mock TTS generation; and `VoiceManager` shutdown & import isolation (`test_import_isolation.py`).
   - Implement `stt.py`, `tts.py`, `manager.py`, `config.py`, and `main.py` shutdown hook.
3. **Slice 3 — Duplex `VoiceSessionOrchestrator`, `WS /api/v1/voice/ws`, REST `/api/v1/voice/*` & Security/Isolation Tests (RED -> GREEN -> REFACTOR):**
   - Write failing tests (`backend/tests/test_voice_api_and_ws.py`) covering fail-closed unauthenticated/revoked WS rejection (`4401`), cross-profile conversation hijack rejection, ephemeral `stt.partial` non-persistence vs `stt.final` DB turn creation, D9 Risk 2 tool confirmation emitted over WS, mid-speech `BargeInGate` & manual `barge_in` cancelling active LLM/TTS turn + discarding stale `turn_id` chunks + resetting buffers, mid-stream session revocation immediate halt, REST `/voice/status|voices|settings|transcribe|synthesize` validation (`422` on bad speed/oversized WAV, lazy settings auto-seed), and per-character `voice_id` TTS resolution.
   - Implement `ws_protocol.py`, `session_orchestrator.py`, `endpoints/voice.py`, and `router.py` wiring.
4. **Slice 4 — OpenAPI 3.1 Contract, `scripts/check_dart_openapi_parity.py` & `companion_api` Dart REST + WebSocket SDK (RED -> GREEN -> REFACTOR):**
   - Regenerate `contracts/openapi/openapi.json` via `scripts/check_openapi_contract.py --write`.
   - Add `voice_dto.dart`, update `character_dto.dart`, implement `WebSocketChannelCompanionClient` & `VoiceSessionClient` & `CompanionClient` methods, update `check_dart_openapi_parity.py` + `scripts/tests/test_check_dart_openapi_parity.py:84` (`93` -> `99`), and add `voice_dto_and_ws_test.dart` covering DTO serialization, REST calls, and full WS stream/barge-in/reconnect handling.
5. **Phase 3 Documentation & Draft PR Packaging:**
   - Sync canonical docs (`voice-and-audio.md`, `characters-personality-and-emotion.md`, `privacy-retention-and-audit.md`, `DELIVERY_INDEX.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `DECISION_DEBT.md`), append `CHANGELOG.md`, author `docs/03_Walkthroughs/walkthrough-m4-voice-pipeline-b.md`, archive active branch tracker, push to `feature/m4-voice-pipeline-b`, and open Draft PR targeting `develop`. *(Note: Batch B does not modify Flutter Desktop or React Web UI screens.)*

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Backend import isolation: `venv\Scripts\python.exe -B backend\tests\test_import_isolation.py -v`
- [ ] Backend full pytest suite: `venv\Scripts\python.exe -m pytest backend\tests -q` (must pass `861+` existing + all new Batch B migration/voice/WS/security tests with `0` failures)
- [ ] OpenAPI contract & Dart parity checks:
  - `venv\Scripts\python.exe scripts\check_openapi_contract.py --check`
  - `venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check`
  - `venv\Scripts\python.exe -m unittest scripts/tests/test_check_dart_openapi_parity.py -v`
- [ ] Dart SDK static analysis & tests (`frontend\flutter\packages\companion_api`): `dart analyze && dart test`
- [ ] Flutter workspace analyzer & desktop regression (`frontend\flutter`): `dart analyze . && flutter test --no-pub --concurrency=1 apps/desktop/test` (confirming `character_dto.dart` & `companion_api` changes compile and pass cleanly across Desktop without regressions)
- [ ] Clean diff & lockfile checks: `git diff --check` clean; Python/pub dependency lockfiles verified per approved option.

### Manual & Host-Level Checks (Where Applicable)
- Batch B introduces backend speech runtime & Dart SDK contracts with **zero Desktop/Web UI changes** (`DEBT-V1-04` runtime smoke optional when a local Whisper `.bin` model is placed in `models/stt/whisper/`). Full interactive UI & microphone/speaker hardware QA is scheduled in **M4 Batch C**.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Dependencies & Approval Choice (`requirements.lock`):**
  - *Option 1 (Recommended Default — Zero Lockfile Churn):* Keep `backend/pyproject.toml`, `backend/requirements.txt`, and `backend/requirements.lock` untouched. `WhisperCppSttProvider` (`runtime/whisper.cpp/whisper-server.exe` via `httpx`), `WindowsSapiTtsProvider`, `AdaptiveEnergyVadProvider`, and `BargeInGate` operate with zero new Python packages, while `KokoroOnnxTtsProvider` & `SileroOnnxVadProvider` detect `onnxruntime` + `numpy` dynamically when installed in the Python environment.
  - *Option 2 (Pin `onnxruntime` + `numpy` Now):* Add `onnxruntime` and `numpy` to `backend/pyproject.toml` / `backend/requirements.txt` and regenerate `backend/requirements.lock` using `runtime/ci-cancellation/qualification311` (`CPython 3.11.9` + `pip 26.1.2`) in Slice 1 so `Kokoro-82M` and `Silero VAD` ONNX models run inside the CI-locked environment out of the box.
- **Risks & Mitigations:**
  - *Kokoro G2P without system `espeak-ng`:* Embedded pure-Python English grapheme-to-IPA converter ensures Kokoro `tokenizer.json` produces valid phoneme token sequences without requiring external `espeak-ng` binaries; falls back cleanly to Windows SAPI or returns clear capability status when needed.
  - *Orphaned `whisper-server.exe` subprocesses:* Bind strictly to `127.0.0.1`, register `terminate()` / Windows Job/process cleanup in `VoiceManager.shutdown()` + `main.py` lifespan `finally`, and exercise cleanup in unit tests with `FakeProcess`.
  - *WebSocket stale chunk race on barge-in:* Every chunk checks `(voice_session_id, active_turn_id)` and `cancel_event.is_set()` prior to `websocket.send_*`, while `VoiceSessionClient` ignores incoming chunks matching any previously cancelled `turn_id`.
- **Required Permissions:** Task-bounded branch creation, planning/code/test/doc commits, push to `origin/feature/m4-voice-pipeline-b`, and Draft PR creation against `develop` in Phase 3 (Human Owner exclusively executes final squash merge into `develop`).
- **Genuine Stop Conditions:** Any unapproved change to Python/Flutter dependency lockfiles, discovery that `runtime/whisper.cpp` or ONNX binary execution breaks `test_import_isolation.py` or Windows CI constraints, or any Profile isolation / D9 security boundary conflict halts execution immediately for Human Owner decision.
