# Active Task: M4 Batch B — Local Speech Pipeline, Duplex Voice WebSocket & Companion API Parity

- **Branch:** `feature/m4-voice-pipeline-b`
- **Plan:** [`plan-m4-voice-pipeline-b.md`](../../02_Planning/01_Plans/plan-m4-voice-pipeline-b.md)
- **Delivery Level:** Level C — Sensitive Design
- **Current Phase:** Phase 1 — Plan & Independent Review (Awaiting Approval)

## Checklist

- [x] Verify clean `develop` baseline (`f29ee17`) and create branch `feature/m4-voice-pipeline-b`
- [x] Author Level C implementation plan (`plan-m4-voice-pipeline-b.md`) and pass Phase 1 Independent Review (`553717e8` APPROVED)
- [ ] Publish Phase 1 plan commit to `origin/feature/m4-voice-pipeline-b` and obtain Human Owner approval
- [ ] Phase 2 Slice 1: Alembic Migration `018`, `ProfileVoiceSettings`, `CharacterInstance.voice_id`, `ProfilePurgeService` cascade, `audio_utils`, `vad` & `BargeInGate` (TDD)
- [ ] Phase 2 Slice 2: `WhisperCppSttProvider`, `KokoroOnnxTtsProvider` / `WindowsSapiTtsProvider`, lazy `VoiceManager` & `lifespan` shutdown (TDD)
- [ ] Phase 2 Slice 3: Duplex `VoiceSessionOrchestrator`, `WS /api/v1/voice/ws`, REST `/api/v1/voice/*`, D9 parity & Profile isolation tests (TDD)
- [ ] Phase 2 Slice 4: OpenAPI 3.1 contract regeneration, `check_dart_openapi_parity.py` & `companion_api` Dart REST + WebSocket SDK (`VoiceSessionClient`)
- [ ] Phase 3: Canonical doc sync, walkthrough, `CHANGELOG.md`, archive tracker & Draft PR preparation
- [ ] Phase 4: Combined independent review & green CI
