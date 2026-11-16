# Archived Task: M4 Batch B — Local Speech Pipeline, Duplex Voice WebSocket & Companion API Parity

- **Branch:** `feature/m4-voice-pipeline-b`
- **Plan:** [`plan-m4-voice-pipeline-b.md`](../../02_Planning/01_Plans/plan-m4-voice-pipeline-b.md)
- **Delivery Level:** Level C — Sensitive Design
- **Current Phase:** Phase 3 — Documentation & Draft PR Ready (Awaiting Phase 4 Independent Review & CI)

## Checklist

- [x] Verify clean `develop` baseline (`f29ee17`) and create branch `feature/m4-voice-pipeline-b`
- [x] Author Level C implementation plan (`plan-m4-voice-pipeline-b.md`) and pass Phase 1 Independent Review (`553717e8` APPROVED)
- [x] Publish Phase 1 plan commit to `origin/feature/m4-voice-pipeline-b` and obtain Human Owner approval (Option 1 Approved)
- [x] Phase 2 Slice 1: Alembic Migration `018`, `ProfileVoiceSettings`, `CharacterInstance.voice_id`, `ProfilePurgeService` cascade, `audio_utils`, `vad` & `BargeInGate` (TDD)
- [x] Phase 2 Slice 2: `WhisperCppSttProvider`, `KokoroOnnxTtsProvider` / `WindowsSapiTtsProvider`, lazy `VoiceManager` & `lifespan` shutdown (TDD)
- [x] Phase 2 Slice 3: Duplex `VoiceSessionOrchestrator`, `WS /api/v1/voice/ws`, REST `/api/v1/voice/*`, D9 parity & Profile isolation tests (TDD)
- [x] Phase 2 Slice 4: OpenAPI 3.1 contract regeneration, `check_dart_openapi_parity.py` & `companion_api` Dart REST + WebSocket SDK (`VoiceSessionClient`)
- [x] Phase 3: Canonical doc sync, walkthrough, `CHANGELOG.md`, archive tracker & Draft PR preparation
- [ ] Phase 4: Combined independent review & green CI
