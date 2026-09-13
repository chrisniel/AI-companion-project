# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: In Progress
- Current Sprint: Track R2-lite — Runtime Rename & Model Registry
- Branch: `feature/assistant-orchestration-and-memory`
- Target: Dynamic model registry, provider/ → runtime/ rename, per-model subdirs; 53/53 automated tests passing.
- Scope Guard: No new DB migrations. No voice/audio tracks. No LFS/git policy changes. No provider/ rename inside backend/app/services/.
- Plan: `docs/02_Planning/plan-runtime-rename-and-model-registry.md`

## [CURRENT EXECUTION STATE - R2-lite VERIFIED & READY TO COMMIT]

- Active Files:
  - `backend/app/core/config.py`
  - `backend/app/services/model_registry.py`
  - `backend/app/schemas/model_registry.py`
  - `backend/app/api/v1/endpoints/llm.py`
  - `backend/app/services/llm/llama_cpp.py`
  - `backend/app/services/llm/mock.py`
  - `frontend/web/src/services/api/registryApi.ts`
  - `frontend/web/src/components/workspace/ModelsView.tsx`
  - `models/registry.template.json`
- Current Status: All 53 tests passing (49 baseline + 4 registry). Frontend build passed cleanly.
- Next Action: Present commit proposal to user; await user review and commit.

## Active Checklist — Track R2-lite

- [x] Task R2-lite.0: Pre-flight — confirm 49 tests passing
- [x] Task R2-lite.1: Rename provider/ → runtime/ filesystem + config.py + .gitignore
- [x] Task R2-lite.2: Reorganize models/vision/ into per-model subdirectories
- [x] Task R2-lite.3: Create models/registry.template.json (committed template)
- [x] Task R2-lite.4: Backend ModelRegistryEntry schema + model_registry service
- [x] Task R2-lite.5: Backend GET /api/v1/models/registry endpoint in llm.py
- [x] Task R2-lite.6: Frontend registryApi.ts + LocalModel type extensions
- [x] Task R2-lite.7: ModelsView.tsx — live registry load + hardcoded name fix + variant badges
- [x] Task R2-lite.8: test_model_registry.py — 4 new tests; verify 53 total passing
- [x] Task R2-lite.9: Update all arch docs provider/ → runtime/
- [ ] Task R2-lite.10: Manual verification (user-owned — see plan Phase 14 checklist)

## Completed — Track B5 (archived after manual verification)

- [x] Task Pre-B5.1: Reconcile `AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`.
- [x] Task Pre-B5.2: Create canonical `LLAMA_CPP_RUNTIME_ARCHITECTURE.md`.
- [x] Task Pre-B5.3: Create canonical `VOICE_AND_AUDIO_ARCHITECTURE.md`.
- [x] Task Pre-B5.4: Document Qwen3-VL portfolio and ModelRegistry.
- [x] Task B5.0–B5.6: Full B5 backend + frontend + 49 tests passing.
- [x] Task B5.7: Committed by user (`6cff4aaf`).

