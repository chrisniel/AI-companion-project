# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: In Review / Awaiting User Approval
- Current Sprint: PC Runtime, Models UI, and Assistant Stabilization
- Branch: `feature/assistant-orchestration-and-memory`
- Target: Enforce singleton llama.cpp router ownership, truthful context & profile application, fix AssistantView React crash, stabilize SSE stream error handling, reconcile Web UI state from backend truth, and fix database message constraints.
- Scope Guard: PC-first stabilization only. No Android/mobile runtime changes. No STT/TTS voice audio tracks. No Git LFS policy changes.
- Plan: `docs/02_Planning/plan-pc-runtime-web-assistant-stabilization.md`

## [CURRENT EXECUTION STATE - PHASE 5 ERROR CLASSIFICATION & REGRESSION RESOLVED]

- Active Plan: `docs/02_Planning/plan-pc-runtime-web-assistant-stabilization.md`
- Current Status: Phase 5 runtime error classification and regression resolved and verified. Root cause of original error was resolved (missing `is_deleted` column in SQLite migration 003). Assistant error classification logic was upgraded in `AssistantView.tsx` so user-facing messages are strictly based on authoritative runtime state (`isOnline`, `modelStatus.model_loaded`, `modelStatus.runtime_state`). Distinct user-facing error codes and concise diagnostic messages implemented: `CORE_OFFLINE`, `MODEL_NOT_LOADED`, `MODEL_SLEEPING`, `WAKE_FAILED`, `STREAM_CONNECTION_FAILED`, `STREAM_TERMINATED`, `MODEL_GENERATION_FAILED`, and `USER_CANCELLED`. Generic "Ensure Local AI Core is running and model is loaded" is eliminated when Core is online and model is loaded/awake. All 38 frontend vitest tests pass, `npx tsc --noEmit` passes with 0 errors, `npm run build` passes cleanly, and 79/79 backend pytest tests pass.
- Next Action: STOP and report Phase 5 runtime error classification and live streaming verification; await user manual testing and review before Phase 6.

## Active Checklist — PC Stabilization

- [x] Phase 0: Reproduce and Instrument (add failing test matrix for router ownership, profile args, and SSE stream errors)
- [x] Phase 1: Single Runtime Ownership & Router Correctness (PID liveness guard, 2s health check, fix polling return on timeout)
- [x] Phase 2: Resource Profile Correctness & VRAM Management (pass `--ctx-size`, handle router restart on profile change, disable conflicting Python idle loop)
- [x] Phase 3: Backend Runtime Truth & Telemetry Schema (`router_running`, `model_resident`, `applied_context_size`, `applied_gpu_layers`)
- [x] Phase 4: Models Web UI State Reconciliation (hydrate `currentModelId` from backend truth, fix `liveModels` precedence, truthful VRAM & settings labels)
- [x] Phase 5: Assistant Web UI Crash Fix, Error Boundary, & SSE Reliability (import `useCallback`, add `ErrorBoundary.tsx`, emit SSE error frame, stabilize conversation init)
- [ ] Phase 6: Database Invariants (migration 004 for `UNIQUE(conversation_id, sequence_no)` and scoped `client_message_id`)
- [ ] Phase 7: Full PC Integration Verification & Benchmarking (clean cold boot, single PID, VRAM check, 56+ pytest pass, clean build)
