# Walkthrough: M4 Batch B — Local Speech Pipeline, Duplex Voice WebSocket & Companion API Parity

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Deliver Milestone M4 Batch B (Alembic Migration `018`, CPU-first STT/VAD/TTS providers & `BargeInGate` without lockfile churn, full-duplex `WS /api/v1/voice/ws` & 6 `/api/v1/voice/*` REST endpoints with D9 parity, OpenAPI 3.1 contract regeneration, and `companion_api` Dart REST + WebSocket `VoiceSessionClient` SDK) on branch `feature/m4-voice-pipeline-b`.
- Audience: Maintainers, independent reviewers, security reviewers, and QA engineers.
- Status: Implemented & Automated-Verified on `feature/m4-voice-pipeline-b` (Awaiting Phase 4 Independent Review & CI; Desktop UI/WASAPI I/O remains deferred to M4 Batch C).
- Last Updated: 2026-11-16

---

## 1. What Was Delivered

- Implemented **Option 1 (Zero Lockfile Churn)**: kept `backend/requirements.txt`, `backend/pyproject.toml`, and `backend/requirements.lock` completely untouched while supporting dynamic `onnxruntime`/`numpy` detection in `SileroOnnxVadProvider` and `KokoroOnnxTtsProvider` alongside pure-stdlib `AdaptiveEnergyVadProvider`, `WhisperCppSttProvider`, and `WindowsSapiTtsProvider` fallbacks.
- Added Alembic Migration `018_voice_settings_and_character_voice` (`profile_voice_settings` table seeded for existing profiles + nullable `character_instances.voice_id` via direct `op.add_column`/`op.drop_column` preserving all 5 SQLite triggers), updated `ProfilePurgeService` (FK-safe deletion of `ProfileVoiceSettings` before `Profile`, plus immediate termination of active voice WS sessions on soft-delete and `/api/v1/auth/session/revoke`), and exposed `voice_id` across character schemas/service.
- Implemented `backend/app/services/voice/`: in-memory `audio_utils.py` (`MAX_TRANSCRIBE_WAV_BYTES = 1,468,006`), `vad.py` (`SileroOnnxVadProvider`, `AdaptiveEnergyVadProvider`, `BargeInGate` policies `smart_auto`/`strict_noisy`/`manual_only`), `stt.py` (windowless localhost-only `WhisperCppSttProvider` running `whisper-server.exe -ng`), `tts.py` (`KokoroOnnxTtsProvider` with embedded English G2P-to-IPA converter + `WindowsSapiTtsProvider` fallback), lazy `VoiceManager` with `reset_voice_manager()` wired into FastAPI `lifespan`, and `VoiceSessionOrchestrator` on `WS /api/v1/voice/ws` + `6` REST endpoints under `/api/v1/voice/*`.
- Enforced zero request-scoped `Depends(get_db)` session lifetime on `WS /api/v1/voice/ws`, D9 tool policy parity through `orchestrate_chat_stream`, shared `_get_lock(conversation_id)` concurrency protection, bounded 5s turn cancellation on `barge_in`, and fail-safe `VOICE_TURN_FAILED` error recovery.
- Regenerated `contracts/openapi/openapi.json` (`80` REST paths), updated `scripts/check_dart_openapi_parity.py` (`87/87` DTO schemas, `99/99` covered routes), and extended `frontend/flutter/packages/companion_api` with `voice_dto.dart`, optional `voiceId` + `clearVoiceId: true` on `CharacterInstance*`, `WebSocketChannelCompanionClient` (enforcing D5 `wss://` on credentialed non-loopback hosts), `VoiceSessionClient` (suppressing stale `turn_id` output after barge-in), and `6` REST methods on `CompanionClient`.

## 2. Files Changed

- `backend/migrations/versions/018_voice_settings_and_character_voice.py` — Migration `018` (`profile_voice_settings`, `character_instances.voice_id`, backfill).
- `backend/app/models/profile_voice_settings.py`, `character_instance.py`, `__init__.py`, `backend/app/db/base.py` — Voice settings ORM model & character `voice_id` field.
- `backend/app/services/profile_purge_service.py`, `backend/app/api/v1/endpoints/auth.py` — Permanent purge cascade and active voice session termination on soft-delete/revoke.
- `backend/app/schemas/character.py`, `voice.py` & `backend/app/services/character_service.py` — Character `voice_id` validation/clearing and typed Voice schemas.
- `backend/app/core/config.py`, `backend/app/main.py`, `backend/app/api/v1/router.py`, `backend/app/api/v1/endpoints/voice.py` — Voice config flags, `lifespan` shutdown hook, and REST + WS router.
- `backend/app/services/voice/{__init__.py,audio_utils.py,vad.py,stt.py,tts.py,manager.py,ws_protocol.py,session_orchestrator.py}` — Complete speech engines, lazy manager, and duplex WS orchestrator.
- `backend/tests/test_migration_018.py`, `test_voice_engines_and_barge_in.py`, `test_voice_api_and_ws.py`, `test_prepare_database_schema_backup.py`, `test_schema_lifecycle.py` — Migration, engine, WS duplex, D9 parity, barge-in, and session revocation tests.
- `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py` — OpenAPI 3.1 contract and Dart parity coverage (`99` routes / `87` schemas).
- `frontend/flutter/packages/companion_api/**` — `voice_dto.dart`, `character_dto.dart`, `ws_transport_io.dart`, `voice_session_client.dart`, `companion_client.dart`, `companion_api.dart`, and `voice_dto_and_ws_test.dart`.
- Canonical documentation (`docs/04_Architecture/**`, `docs/02_Planning/00_Master/**`, `CHANGELOG.md`, archived branch tracker).

## 3. How the Logic Works

1. **Authentication & Setup:** Clients open `WS /api/v1/voice/ws` with an `Authorization: Bearer ...` upgrade header or initial `session.start` `session_token` frame; `_authenticate_ws_context` opens short-lived DB sessions only to validate `ProfileSession`, resolve `ProfileVoiceSettings` and effective `voice_id`, and releases the DB session immediately.
2. **Inbound Audio & VAD / Barge-In:** Client `audio.chunk` frames decode in RAM (`audio_utils.py`), feed `VadProvider.is_speech` in `512`-sample frames, and drive `BargeInGate` (`smart_auto`, `strict_noisy`, or `manual_only`). When barge-in triggers during an active turn (or client sends explicit `barge_in`), `_cancel_active_turn` cancels the running task within `5.0s` (`asyncio.wait_for`), releases conversation lock cleanly via `aclosing(stream)`, and emits `turn.cancelled`.
3. **Turn Execution & D9 Parity:** `audio.commit` (or VAD end-of-speech) runs `SttProvider.transcribe` on the RAM buffer, saves the user message via `prepare_turn`, acquires `_get_lock(conversation_id)`, streams `orchestrate_chat_stream` (`llm.delta`, `tool.intent`, `tool.result`, `tool.confirmation_required`), and chunks sentence boundaries into `tts.audio.chunk` frames followed by `tts.end`.
4. **Client SDK Filtering:** `VoiceSessionClient` tracks active/cancelled `turn_id` values and drops late `tts.audio.chunk`, `tts.end`, and `llm.delta` frames belonging to cancelled turns immediately after `barge_in`.

## 4. Verification Steps

### Automated Checks

- [x] `venv\Scripts\python.exe -B backend\tests\test_import_isolation.py -v` — `Ran 4 tests in 5.355s — OK (ISOLATED_COLLECTION_COUNT=878)`.
- [x] `venv\Scripts\python.exe -m pytest backend\tests -q` — `878 passed` (`0` failed, `0` skipped, `319.53s`), including `test_migration_018.py`, `test_voice_engines_and_barge_in.py`, `test_voice_api_and_ws.py`, and character regression tests (`32 passed`).
- [x] `venv\Scripts\python.exe scripts\check_openapi_contract.py --check` — `OpenAPI contract is up-to-date (80 routes, all required model routes present)`.
- [x] `venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check` — `Verified DTO Schemas: 87/87`, `M1 + M2 + M3 + M4 Native Covered Routes: 99/99`, `RESULT: ALL CONTRACT PARITY AND ROUTE COVERAGE CHECKS PASSED`.
- [x] `venv\Scripts\python.exe -m unittest scripts/tests/test_check_dart_openapi_parity.py -v` — `Ran 8 tests in 0.228s — OK`.
- [x] `git diff --exit-code -- backend/requirements.txt backend/requirements.lock backend/pyproject.toml` — Exited `0` (zero dependency/lockfile changes under Option 1).
- [x] `dart analyze && dart test` (`frontend/flutter/packages/companion_api`) — `No issues found!`, `112` tests passed.
- [x] `dart analyze . && flutter test --no-pub --concurrency=1 apps/desktop/test` (`frontend/flutter`) — `No issues found!`, `409` tests passed.

### Live Local Hardware / Neural Engine Smoke Verification

- [x] Live end-to-end neural smoke run verified with staged [`ggml-base.bin`](../../models/stt/whisper/ggml-base.bin), [`silero_vad.onnx`](../../models/vad/silero-vad-v6.2.1/silero_vad.onnx), [`model_quantized.onnx`](../../models/tts/kokoro-82m-v1.0/model_quantized.onnx) (`af_nicole.bin`), and [`whisper-server.exe`](../../runtime/whisper.cpp/whisper-server.exe): `KokoroOnnxTtsProvider` synthesized `24 kHz` WAV -> resampled to `16 kHz` PCM16 (`rms=0.0696`) -> `SileroOnnxVadProvider` detected `131/216` speech frames (`max_prob=1.0000`) -> `WhisperCppSttProvider` transcribed cleanly over loopback HTTP (`en` and `auto`) + `WindowsSapiTtsProvider` verified (`RIFF` WAV) + `reset_voice_manager()` terminated child process cleanly.

## 5. Safe Customization & Invariants

- Tunable config settings (`backend/app/core/config.py`): `VOICE_PROVIDER`, `VOICE_STT_MODEL_PATH`, `VOICE_WHISPER_THREADS`, `VOICE_WHISPER_PORT`, `VOICE_MAX_TURN_AUDIO_BYTES`, `VOICE_BARGE_IN_DEFAULT_HOLD_MS`.
- Security & privacy invariants: raw audio never touches disk; `WS /api/v1/voice/ws` never uses `Depends(get_db)` across idle sockets; non-loopback `VoiceSessionClient` requires `wss://` when carrying `Authorization` headers; Profile soft-delete and session revocation immediately close active WS voice sessions and discard RAM audio buffers; `VoiceSessionOrchestrator` reuses `orchestrate_chat_stream` and `_get_lock(conversation_id)` for full D9 policy parity.
