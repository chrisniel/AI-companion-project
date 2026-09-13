# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: In Review / Awaiting User Approval
- Current Sprint: PC Runtime, Models UI, and Assistant Stabilization
- Branch: `feature/assistant-orchestration-and-memory`
- Target: Enforce singleton llama.cpp router ownership, truthful context & profile application, fix AssistantView React crash, stabilize SSE stream error handling, reconcile Web UI state from backend truth, and fix database message constraints.
- Scope Guard: PC-first stabilization only. No Android/mobile runtime changes. No STT/TTS voice audio tracks. No Git LFS policy changes.
- Plan: `docs/02_Planning/plan-pc-runtime-web-assistant-stabilization.md`

## [CURRENT EXECUTION STATE - PHASE 7 COMPLETE & VERIFIED]

- Active Plan: `docs/02_Planning/plan-pc-runtime-web-assistant-stabilization.md`
- Current Status: Phase 7 Full PC Integration Verification & Benchmarking completed and verified across all 21 checkpoints. Verified clean cold-boot baseline (0 llama processes, ports 8000/8085/3000 free, branch, migration head 005). Verified database integrity, composite message constraints, soft-delete columns, and documented downgrade limitation. Validated cold Core boot and Web UI reconciliation without legacy models or false telemetry. Verified Qwen3-VL-2B-Instruct on Balanced profile: launch configuration exact (--ctx-size 4096, --n-gpu-layers 28, --threads 6, GPU mmproj enabled, port 8085) with strict 1 root router + 1 worker PID topology. Measured Balanced resource benchmark: load time 5.72s, baseline VRAM 1128.80 MB, loaded VRAM 3829.71 MB (+2700.91 MB delta), router RAM 41.90 MB, worker RAM 1447.76 MB, TTFT 0.962s, gen speed 32.22 tok/s. Validated Models UI persistence journey, Header quick model selector, and Assistant normal streaming with deterministic sequence numbers. Verified Assistant cancellation (mid-stream abort preserves text, releases locks, generation_active clears) and failure recovery. Validated native sleep and wake cycle: MODEL_SLEEPING entered after idle threshold with 2661.21 MB VRAM released and worker preserved; wake request succeeded in 4.11s (3.601s wake latency) restoring MODEL_READY without router duplication. Verified explicit unload (worker exits, router remains, VRAM freed). Verified profile switching Balanced -> Eco (old router terminates, requested_profile eco, applied_profile null while stopped, fresh router spawned with Eco flags: ctx 2048, ngl 0, threads 4, --no-mmproj-offload) and Eco benchmark (VRAM delta 91.43 MB, load 4.68s, TTFT 1.107s, speed 23.80 tok/s). Performed 4B Balanced smoke benchmark: load 15.47s, VRAM delta 3557.31 MB, TTFT 1.115s, speed 16.26 tok/s, followed by clean unload (3551.41 MB freed). Verified state and conversation persistence across Core and Web UI restarts. Completed clean shutdown: 0 llama-server processes, 0 port listeners, database intact at revision 005. All 88 backend pytest tests, 38 frontend vitest tests, 0 tsc errors, and clean build pass.
- Next Action: STOP and report Phase 7 verification results. Await user review before any future phase.

## Active Checklist — PC Stabilization

- [x] Phase 0: Reproduce and Instrument (add failing test matrix for router ownership, profile args, and SSE stream errors)
- [x] Phase 1: Single Runtime Ownership & Router Correctness (PID liveness guard, 2s health check, fix polling return on timeout)
- [x] Phase 2: Resource Profile Correctness & VRAM Management (pass `--ctx-size`, handle router restart on profile change, disable conflicting Python idle loop)
- [x] Phase 3: Backend Runtime Truth & Telemetry Schema (`router_running`, `model_resident`, `applied_context_size`, `applied_gpu_layers`)
- [x] Phase 4: Models Web UI State Reconciliation (hydrate `currentModelId` from backend truth, fix `liveModels` precedence, truthful VRAM & settings labels)
- [x] Phase 5: Assistant Web UI Crash Fix, Error Boundary, & SSE Reliability (import `useCallback`, add `ErrorBoundary.tsx`, emit SSE error frame, stabilize conversation init)
- [x] Phase 6: Database Invariants (migration 005 for `UNIQUE(conversation_id, sequence_no)` and scoped `client_message_id`)
- [x] Phase 7: Full PC Integration Verification & Benchmarking (clean cold boot, single PID, VRAM check, 56+ pytest pass, clean build)
