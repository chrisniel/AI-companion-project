# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: In Progress
- Current Sprint: Router & Model Registry Integration Fix
- Branch: `feature/assistant-orchestration-and-memory`
- Target: Fix llama-server router discovery, port 8085 migration, model ID routing, provider detection, and live status synchronization; all tests passing + live RX 580 smoke test.
- Scope Guard: No new DB migrations. No voice/audio tracks. No LFS/git policy changes.
- Plan: `docs/02_Planning/plan-llama-router-and-model-registry-fix.md`

## [CURRENT EXECUTION STATE - VERIFIED & READY FOR COMMIT]

- Active Files:
  - `backend/app/core/config.py`
  - `backend/app/services/llm/manager.py`
  - `backend/app/services/llm/mock.py`
  - `backend/app/schemas/model_registry.py`
  - `backend/app/services/model_registry.py`
  - `backend/app/services/llm/llama_cpp.py`
  - `frontend/web/src/components/workspace/ModelsView.tsx`
  - `backend/tests/conftest.py`
  - `backend/tests/test_llm.py`
  - `backend/tests/test_model_registry.py`
  - `CHANGELOG.md`
- Current Status: All 56 automated tests passing. Frontend build passed cleanly. Live smoke test on port 8085 with Vulkan GPU offload passed 100%.
- Next Action: Present commit proposal to user; await user review and manual commit.

## Active Checklist — Router & Model Registry Fix

- [x] Task 1: Update `backend/app/core/config.py` (port 8085, LLAMA_MODELS_DIR, URL)
- [x] Task 2: Fix `manager.py` (rglob for GGUF discovery) & `mock.py` (cold boot truthfulness)
- [x] Task 3: Schema & Registry (`runtime_model_id` field and resolver helper)
- [x] Task 4: LlamaCppProvider core (launch args, runtime ID routing, status polling, completion payload)
- [x] Task 5: Frontend `ModelsView.tsx` (exact ID matching and activation)
- [x] Task 6: Automated test suite verification (`pytest tests/ -v` [56/56] and `npm run build`)
- [x] Task 7: Live smoke test with `llama-server.exe` on port 8085 (Vulkan RX 580)

## Completed — Track B5 (archived after manual verification)

- [x] Task Pre-B5.1: Reconcile `AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`.
- [x] Task Pre-B5.2: Create canonical `LLAMA_CPP_RUNTIME_ARCHITECTURE.md`.
- [x] Task Pre-B5.3: Create canonical `VOICE_AND_AUDIO_ARCHITECTURE.md`.
- [x] Task Pre-B5.4: Document Qwen3-VL portfolio and ModelRegistry.
- [x] Task B5.0–B5.6: Full B5 backend + frontend + 49 tests passing.
- [x] Task B5.7: Committed by user (`6cff4aaf`).

