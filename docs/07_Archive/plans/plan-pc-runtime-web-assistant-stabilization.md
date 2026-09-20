# Implementation Plan: PC Runtime, Models UI, and Assistant Stabilization (Revised)

**Goal:** Establish the Windows PC backend and `llama.cpp` runtime as the coherent, authoritative source of truth, eliminate duplicate processes, fix VRAM/context allocation bugs, resolve Assistant React blank-screen crash and SSE streaming dropouts, reconcile Models/Assistant UI state, and provide rock-solid end-to-end PC stability before any Android/mobile integration.

- **Author:** Antigravity AI
- **Date:** 2026-09-14
- **Branch:** `feature/assistant-orchestration-and-memory`
- **Canonical Architecture:** [AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md](../reference/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md), [LLAMA_CPP_RUNTIME_ARCHITECTURE.md](../../04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md)
- **Status:** Proposed — Revised Per User Directives — Awaiting Approval

---

## 1. Repository & Local Runtime Evidence (Baseline Audit)

| Metric / Boundary | Observed Local Value | Evidence Path / Command |
|---|---|---|
| Current Branch | `feature/assistant-orchestration-and-memory` | `git branch --show-current` |
| Working Tree Status | Clean (0 uncommitted changes) | `git status` |
| Latest Relevant Commit | `8d219d6` | `git log -n 1 --oneline` |
| Local llama.cpp Binaries | b10936 Vulkan x64 present (`llama-server.exe`, `ggml-vulkan.dll`) | `runtime/llama.cpp/` (52 files) |
| Local GGUF Directory Layout | `models/vision/` contains all 5 Qwen3-VL subdirectories | `models/vision/{2b,4b,8b}-{instruct,thinking}` |
| Active `llama-server.exe` | 0 processes running (clean baseline) | `Get-CimInstance Win32_Process` |
| Ports 8080 & 8085 Status | Both ports idle, unassigned | `Get-NetTCPConnection` |
| Legacy Startup Scripts | `scripts/start-model.ps1` exists with stale `bin/`, port 8080, Qwen2.5 | `scripts/start-model.ps1` |

---

## 2. Confirmed / Rejected / Partially Confirmed Findings

| # | Finding Description | Status | Evidence from Codebase & Runtime Audit |
|---|---|---|---|
| **3** | Duplicate `llama-server.exe` processes spawning | **CONFIRMED** | `backend/app/services/llm/llama_cpp.py:L187-L255`: `load_model()` had no process liveness check (`self._server_process.poll() is None`) and no port check before calling `subprocess.Popen()`. If `_check_external_server()` timed out during startup, it spawned another instance. |
| **4** | Runtime Profile `--ctx-size` omitted from launch args | **CONFIRMED** | `llama_cpp.py:L228-L242`: `launch_args` lists `--n-gpu-layers` and `--threads`, but omits `--ctx-size`. `params["n_ctx"]` is calculated (2048/4096/8192) but discarded. |
| **5** | 2B model consuming ~7 GB VRAM | **PARTIALLY CONFIRMED** | **Confirmed:** Duplicate `llama-server.exe` processes were running simultaneously on the machine during testing, and `--ctx-size` was omitted (defaulting to 32K context). **Requires clean benchmark:** The exact contribution of weights vs mmproj vs KV cache vs compute buffers vs driver allocations cannot be asserted without an isolated, single-process benchmark on the RX 580. Hard VRAM thresholds are removed from plan. |
| **6 & 7** | Profile change does not reconfigure running router | **CONFIRMED** | `llama_cpp.py:L357-L364`: `set_profile(p)` only mutates internal Python string `self._active_profile = p`. Running `llama-server` retains its initial launch arguments. Reconfiguration mechanism treated as evidence-gated decision. |
| **8** | Native sleep vs Python idle monitor conflict | **CONFIRMED** | `llama_cpp.py:L233` passes `--sleep-idle-seconds 900` to router, while `_idle_monitor_loop` (lines 380-391) continuously triggers explicit `unload_model()` every 30s after 300s idle. |
| **9** | Router load/unload polling timeout returns `True` | **CONFIRMED** | `llama_cpp.py:L82 & L111`: Both polling loops fall through their `range(...)` iterations and end with `return True` when timing out! |
| **10 & 11** | Backend status overloads `is_loaded` & displays requested settings as applied | **CONFIRMED** | `schemas/llm.py`: `ModelStatusResponse` reports requested profile formulas rather than verified launch flags. `is_loaded` conflates router running with model residency. Fake live telemetry exists in UI. |
| **12 & 13** | VRAM Target Slider & Advanced Settings are mock UI-only with stale CUDA wording | **CONFIRMED** | `VramTargetSlider.tsx` and `AdvancedRuntimeSettings.tsx` update local React state only. `AdvancedRuntimeSettings.tsx:L84` references "CUDA cores rather than CPU RAM" on an AMD RX 580 Vulkan target. |
| **14** | Models Web UI resets to mock `'m-1'` on navigation/reload | **CONFIRMED** | `App.tsx:L34` owns `currentModelId = 'm-1'`. `ModelsView.tsx:L63` computes `activeModelId = controlledModelId || internalModelId`, so parent mock value overrides backend hydration. |
| **15** | AssistantView crashes with `ReferenceError: useCallback is not defined` | **CONFIRMED** | `AssistantView.tsx:L1`: `import React, { useState, useRef, useEffect } from 'react';` omits `useCallback`, but line 199 uses `useCallback(...)`. `npx tsc --noEmit` fails with TS2304. |
| **16** | No React ErrorBoundary in application shell | **CONFIRMED** | Grep confirms 0 error boundaries in `frontend/web/src/`. Any unhandled view crash renders a completely blank screen. |
| **17** | Assistant uses mock Llama-3.1 model name in live connected mode | **CONFIRMED** | `App.tsx:L116-L118` passes `mockLocalModels.find(...)?.name || 'Llama-3.1-8B-Instruct'` to `AssistantView`. |
| **18 & 19** | SSE mid-stream failure leaves blank assistant bubble | **CONFIRMED** | `orchestrator.py:L266-L271` re-raises exceptions without yielding an SSE error chunk. `conversationApi.ts` treats socket close as normal `onDone()`, leaving empty assistant bubble. |
| **20** | Active conversation reset on heartbeat / reconnect | **CONFIRMED** | `AssistantView.tsx:L254` depends on `[isOnline, loadConversationMessages]`, causing conversation list re-fetch and re-selection of `items[0]` on reconnects. |
| **21** | Silent `catch {}` blocks swallow critical errors | **CONFIRMED** | Multiple silent try-catches in `AssistantView.tsx` and `ModelsView.tsx` suppress actionable failures. |
| **22** | Database constraint mismatches on Message | **CONFIRMED** | `models/message.py:L22`: `client_message_id` is globally unique instead of conversation-scoped. `(conversation_id, sequence_no)` lacks a unique constraint. Preflight query also lacks conversation scoping. |

---

## 3. Root-Cause Map

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                  ROOT CAUSE MAP                                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
  1. Runtime Process Ownership:
     - No process-level lock or PID liveness guard before calling subprocess.Popen()
     - No port listening check before spawn; no cleanup of spawned process on failed startup
     - Health check probe timeout (0.3s) too aggressive during cold router initialization
     - Legacy scripts/start-model.ps1 points to deprecated bin/ on port 8080

  2. Profile & Resource Configuration:
     - Missing --ctx-size in router launch_args defaults to model's 32K training context
     - Profile reconfiguration semantics not defined (evidence-gated decision needed)
     - Python idle loop fights native --sleep-idle-seconds

  3. Router Contract & Verification:
     - Timeout in _router_load_model() / _router_unload_model() returns True instead of False
     - ModelStatusResponse conflates requested profile settings with verified active args

  4. Web UI State & React Hydration:
     - selectedModelId (browsing) and activeModelId (resident) not modeled separately
     - App.tsx forces mock 'm-1' down to ModelsView and 'Llama-3.1' to AssistantView
     - No ErrorBoundary wrapping workspace components; AssistantView missing useCallback import
     - Fake telemetry displayed as live readouts rather than "Unavailable / Estimated"

  5. Streaming SSE Contract & Disconnect Handling:
     - Non-deterministic SSE terminal semantics: no distinction between done, error, and unexpected EOF
     - conversationApi SSE parser ignores event types and treats socket EOF as normal completion
     - Lock release on AbortController signal needs robust cancellation handling

  6. Database Constraints & Idempotency:
     - Message table lacks UNIQUE(conversation_id, sequence_no)
     - client_message_id unique globally rather than per conversation
     - Backend preflight query omits conversation_id scoping
     - SQLite requires batch_alter_table for constraint modifications
```

---

## 4. Proposed Phased Fix (Revised)

### Phase 0: Reproduce and Instrument
* **Goal**: Establish deterministic regression test suites for backend and frontend before applying fixes.
* **Files to create/modify**:
  * [backend/tests/test_llm_router.py](file:///d:/OtherProjects/AI-companion-project/backend/tests/test_llm_router.py) (NEW)
  * [backend/tests/test_assistant_stream.py](file:///d:/OtherProjects/AI-companion-project/backend/tests/test_assistant_stream.py) (NEW)
  * [frontend/web/package.json](file:///d:/OtherProjects/AI-companion-project/frontend/web/package.json)
  * [frontend/web/src/components/workspace/__tests__/AssistantView.test.tsx](file:///d:/OtherProjects/AI-companion-project/frontend/web/src/components/workspace/__tests__/AssistantView.test.tsx) (NEW)
* **Actions**:
  * Add Vitest and React Testing Library (`@testing-library/react`, `jsdom`, `vitest`) to `frontend/web/package.json` for frontend unit testing.
  * Author backend failing tests:
    * Attempting dual `load_model()` does not spawn a second PID.
    * Omitting `--ctx-size` in router launch args fails assertion.
    * Router load timeout returns `False` (not `True`).
    * Mid-stream exception yields explicit SSE error chunk.
  * Author frontend failing tests:
    * `AssistantView` mounts cleanly without hook `ReferenceError`.
    * `ErrorBoundary` catches render failure and displays fallback card.
    * SSE parser distinguishes `[DONE]`, `error`, and unexpected EOF.

### Phase 1: Single Runtime Ownership & Router Correctness
* **Goal**: Guaranteed singleton `llama-server.exe` router owned by FastAPI Core. Eliminate duplicate processes, implement startup cleanup, and isolate legacy scripts.
* **Files to modify**:
  * [backend/app/services/llm/llama_cpp.py](file:///d:/OtherProjects/AI-companion-project/backend/app/services/llm/llama_cpp.py)
  * [backend/app/core/config.py](file:///d:/OtherProjects/AI-companion-project/backend/app/core/config.py)
  * [scripts/start-model.ps1](file:///d:/OtherProjects/AI-companion-project/scripts/start-model.ps1)
* **Actions**:
  * **Pre-spawn check**:
    1. Check if `self._server_process` is already set and alive (`poll() is None`). If alive, do NOT spawn.
    2. Check if port 8085 is listening via TCP socket probe:
       * If port is active and responds to `/health` as a valid llama-server, adopt it as an external server (`self._server_is_active = True`, `self._managed_by_core = False`).
       * If port is active but alien/unresponsive, abort with error `PORT_CONFLICT: 8085 is occupied by another process`.
  * **Failed startup cleanup**: If FastAPI spawns `self._server_process` and the health check loop fails/times out, FastAPI Core MUST explicitly terminate and kill the spawned child process (`self._server_process.kill()`, `wait()`) to prevent orphaned processes holding port 8085.
  * **Increase health probe timeout**: Increase polling interval from 0.3s to 2.0s with up to 45s maximum wait during model initialization.
  * **Fix polling return values**: Fix `_router_load_model()` and `_router_unload_model()` to return `False` on timeout.
  * **Legacy script protection**: Update `scripts/start-model.ps1` to diagnostic-only probe targeting port 8086 or an explicit `--port` parameter with a clear check that prevents launching on production port 8085 while Core is active.

### Phase 2: Resource Profile Correctness & Evidence-Gated Reconfiguration
* **Goal**: Pass profile parameters to `llama-server`, reconcile native sleep, and implement clean profile reconfiguration.
* **Files to modify**:
  * [backend/app/services/llm/llama_cpp.py](file:///d:/OtherProjects/AI-companion-project/backend/app/services/llm/llama_cpp.py)
* **Actions**:
  * Append `"--ctx-size", str(params["n_ctx"])` to router `launch_args`.
  * **Evidence-gated profile switching**:
    * Because `llama-server` b10936 binds `--ctx-size`, `--n-gpu-layers`, and `--threads` at process start:
    * When `set_profile(new_profile)` is called while a router is running:
      * Record `requested_profile = new_profile`.
      * If router is Core-managed and idle, perform clean scoped termination of the existing router process.
      * The router will respawn with the newly requested profile's flags on next model activation/inference.
      * If generation is active, reject or defer until completion.
  * **Reconcile sleep vs auto-unload**:
    * Disable Python's `_idle_monitor_loop` auto-unload when native `--sleep-idle-seconds` is enabled.
    * Let `llama-server` handle native memory sleep without Python fighting it.

### Phase 3: Backend Runtime Truth & Telemetry Contract
* **Goal**: Provide an unambiguous status contract distinguishing requested settings from verified applied runtime facts, keeping unmeasured GPU telemetry strictly out of scope.
* **Files to modify**:
  * [backend/app/schemas/llm.py](file:///d:/OtherProjects/AI-companion-project/backend/app/schemas/llm.py)
  * [backend/app/services/llm/llama_cpp.py](file:///d:/OtherProjects/AI-companion-project/backend/app/services/llm/llama_cpp.py)
  * [backend/app/services/llm/mock.py](file:///d:/OtherProjects/AI-companion-project/backend/app/services/llm/mock.py)
  * [backend/tests/test_llm_router.py](file:///d:/OtherProjects/AI-companion-project/backend/tests/test_llm_router.py)
* **Contract Specification**:
  * `router_running: bool` (true if router process alive and responding on port 8085)
  * `managed_by_core: bool` (true only if spawned by Core)
  * `runtime_state: LLMRuntimeState` (`SERVER_STOPPED`, `MODEL_UNLOADED`, `MODEL_LOADING`, `MODEL_READY`, `MODEL_SLEEPING`, `SERVER_ERROR`, `MODEL_ERROR`)
  * `active_model: Optional[str]`
  * **Expressive Model Residency & Sleep Semantics**:
    * `model_resident: bool` (physical VRAM compute residency: True ONLY when `MODEL_READY`)
    * `model_loaded: bool` (logical model presence: True for both `MODEL_READY` and `MODEL_SLEEPING`)
    * `model_awake: bool` (compute readiness: True for `MODEL_READY`, False for `MODEL_SLEEPING` or unloaded)
  * **Configuration vs Runtime Truth**:
    * `requested_profile: str` (target user configuration: `eco`, `balanced`, `maximum`)
    * `applied_profile: Optional[str]` (actual profile applied to running router; null when router stopped)
    * `applied_context_size: Optional[int]` (actual `--ctx-size` flag passed to process; null when router stopped)
    * `applied_gpu_layers: Optional[int]` (actual `--n-gpu-layers` flag passed to process; null when router stopped)
    * `mmproj_offload: bool` (True if projector offloaded to GPU; False if `--no-mmproj-offload` on CPU)
  * `generation_active: bool`
  * `last_runtime_error: Optional[str]`
  * **Preserved Backward-Compatibility Fields**:
    * `is_loaded: bool` (mapped directly to `model_loaded`)
    * `active_profile: str` (mapped to `requested_profile`)
    * `context_size: int` (mapped to `applied_context_size` if applied, else requested default)
    * `gpu_layers: int` (mapped to `applied_gpu_layers` if applied, else requested default)
* **Documentation Terminology Standard (Vision & Multimodal)**:
  * **Cold Image Ingest Latency (TTFT)**: Time-to-First-Token on first ingestion and vision projection of a new image (e.g. 28.7s GPU vs 72.4s CPU on 1080x2400 screenshot).
  * **Warm Cache-Hit Latency**: Follow-up turns where visual context is already resident in KV cache (e.g. ~0.35s TTFT).
  * **Rule**: Cold image ingest and warm cache-hit follow-ups MUST be reported separately. Do NOT use the warm-run median as representative first-image latency.

### Phase 4: Models Web UI State Reconciliation & Control Truthfulness
* **Goal**: Separate `selectedModelId` (browsing) from `activeModelId` (backend truth), truthfully represent VRAM and technical settings.
* **Files to modify**:
  * [frontend/web/src/App.tsx](file:///d:/OtherProjects/AI-companion-project/frontend/web/src/App.tsx)
  * [frontend/web/src/components/workspace/ModelsView.tsx](file:///d:/OtherProjects/AI-companion-project/frontend/web/src/components/workspace/ModelsView.tsx)
  * [frontend/web/src/components/workspace/models/VramTargetSlider.tsx](file:///d:/OtherProjects/AI-companion-project/frontend/web/src/components/workspace/models/VramTargetSlider.tsx)
  * [frontend/web/src/components/workspace/models/AdvancedRuntimeSettings.tsx](file:///d:/OtherProjects/AI-companion-project/frontend/web/src/components/workspace/models/AdvancedRuntimeSettings.tsx)
* **Actions**:
  * **Separate Model State**:
    * `selectedModelId`: What the user has clicked/highlighted in the UI library grid.
    * `activeModelId`: Directly reflects `modelStatus.active_model` from backend truth.
    * When `modelStatus.active_model` changes or hydrates from backend, update `activeModelId`. Do not let initial mock `'m-1'` override backend truth.
  * **VRAM Target Slider**:
    * Do not present as an authoritative hardware cap slider.
    * Rebrand as "Target Context Headroom Guide" derived from selected performance profile, or clearly mark as "Profile Headroom Target".
  * **Advanced Settings**:
    * Replace "CUDA" with "Vulkan / GPU Offload".
    * Mark un-wired controls (Flash Attention, batch size, context shift) as "Informational / Profile Default", removing false operational claims.

### Phase 5: Assistant Web UI Crash Fix, Error Boundary, & Deterministic SSE Parser
* **Goal**: Resolve React crash, wrap workspaces with ErrorBoundary, implement deterministic SSE terminal semantics (`done` / `error` / unexpected EOF).
* **Files to create/modify**:
  * [frontend/web/src/components/workspace/AssistantView.tsx](file:///d:/OtherProjects/AI-companion-project/frontend/web/src/components/workspace/AssistantView.tsx)
  * [frontend/web/src/components/ui/ErrorBoundary.tsx](file:///d:/OtherProjects/AI-companion-project/frontend/web/src/components/ui/ErrorBoundary.tsx) (NEW)
  * [frontend/web/src/App.tsx](file:///d:/OtherProjects/AI-companion-project/frontend/web/src/App.tsx)
  * [frontend/web/src/services/api/conversationApi.ts](file:///d:/OtherProjects/AI-companion-project/frontend/web/src/services/api/conversationApi.ts)
  * [backend/app/services/assistant/orchestrator.py](file:///d:/OtherProjects/AI-companion-project/backend/app/services/assistant/orchestrator.py)
* **Actions**:
  * **Fix React Crash**: Import `useCallback` in `AssistantView.tsx:L1`.
  * **Add ErrorBoundary**: Create `ErrorBoundary.tsx` and wrap workspace views in `App.tsx` so unhandled component errors render a clean, recoverable card rather than blanking the screen.
  * **Backend SSE Error Yield**:
    * In `orchestrator.py`, if an exception occurs during the streaming loop:
      * Yield `event: error\ndata: {"error": {"message": str(exc), "code": "ORCHESTRATION_ERROR"}}\n\n` before exiting.
      * Update `asst_msg.status = "failed"` in database.
  * **Frontend Deterministic SSE Parser (`conversationApi.ts`)**:
    * Parse both `event:` and `data:` fields.
    * Track boolean `hasReceivedDone = false`.
    * If `payload === '[DONE]'` or `event === 'done'`: set `hasReceivedDone = true`, call `onDone()`, return.
    * If `event === 'error'` or `payload.error`: extract error message, call `onError(new Error(message))`, return.
    * When `reader.read()` completes (`done: true`):
      * If `!hasReceivedDone` and no tokens were received: trigger `onError(new Error("Connection closed unexpectedly by server before completion."))`.
  * **AssistantView Stream State**:
    * If `onError` fires and assistant message content is empty, render a visible dismissible error notice in the chat thread rather than leaving an empty blank bubble.
  * **Stabilize Conversation Hydration**:
    * Prevent heartbeat reconnects from resetting user's selected conversation back to `items[0]`.

### Phase 6: Database Invariants (Scoped Idempotency & Safe SQLite Migration)
* **Goal**: Fix Message table constraints to enforce integrity without breaking existing schemas, using safe SQLite batch migration mechanics.
* **Files to create/modify**:
  * [backend/app/api/v1/endpoints/conversations.py](file:///d:/OtherProjects/AI-companion-project/backend/app/api/v1/endpoints/conversations.py)
  * [backend/app/models/message.py](file:///d:/OtherProjects/AI-companion-project/backend/app/models/message.py)
  * [backend/migrations/versions/004_fix_message_constraints.py](file:///d:/OtherProjects/AI-companion-project/backend/migrations/versions/004_fix_message_constraints.py) (NEW)
* **Actions**:
  * **Scope Preflight Query**:
    * In `conversations.py:L230`: Scope idempotency query by `conversation_id`:
      ```python
      dup_query = select(Message).where(
          Message.conversation_id == conversation_id,
          Message.client_message_id == payload.client_message_id,
          Message.owner_id == owner_id,
      )
      ```
  * **Safe SQLite Alembic Migration**:
    * Use `op.batch_alter_table("messages", recreate="always")` to safely copy and rebuild the SQLite table:
      * Drop the table-wide unique index on `client_message_id`.
      * Create unique constraint `uq_messages_conv_seq` on `["conversation_id", "sequence_no"]`.
      * Create unique constraint `uq_messages_conv_client_id` on `["conversation_id", "client_message_id"]`.
  * **Update SQLAlchemy Model**:
    * In `backend/app/models/message.py`, update table args with `UniqueConstraint("conversation_id", "sequence_no")` and `UniqueConstraint("conversation_id", "client_message_id")`.

### Phase 7: Full PC Integration Verification & Clean Benchmark
* **Goal**: Execute complete manual & automated PC verification from a clean, single-process baseline.
* **Actions**:
  * Run backend pytest suite (`pytest backend/tests/ -v`).
  * Run frontend tests and build (`npm test && npx tsc --noEmit && npm run build`).
  * Run clean single-router benchmark on AMD RX 580:
    * Measure baseline idle VRAM (0 models loaded).
    * Measure 2B Instruct on Eco (2048 context) and Balanced (4096 context).
    * Measure 4B Instruct on Balanced (4096 context).
    * Record observed, measured values in walkthrough (no asserted hard pass/fail thresholds).
  * Update `CHANGELOG.md` and walkthrough documentation.

---

## 5. Exact Files Expected to Change

```text
[MODIFY] backend/app/core/config.py
         - Align LLAMA_ROUTER_PORT and timeout parameters
[MODIFY] backend/app/schemas/llm.py
         - Add router_running, model_resident, applied_context_size, applied_gpu_layers
[MODIFY] backend/app/services/llm/llama_cpp.py
         - PID check before spawn, cleanup on failed start, pass --ctx-size, fix polling return
[MODIFY] backend/app/api/v1/endpoints/conversations.py
         - Scope idempotency query by conversation_id
[MODIFY] backend/app/services/assistant/orchestrator.py
         - Yield explicit SSE error chunk on exception before stream termination
[MODIFY] backend/app/models/message.py
         - Update UniqueConstraints for conversation-scoped sequence_no and client_message_id
[NEW]    backend/migrations/versions/004_fix_message_constraints.py
         - Safe SQLite batch_alter_table migration
[MODIFY] scripts/start-model.ps1
         - Align with runtime/llama.cpp/, isolate from production port 8085
[NEW]    backend/tests/test_llm_router.py
         - Unit tests for singleton ownership, failed start cleanup, and polling return
[NEW]    backend/tests/test_assistant_stream.py
         - Unit tests for SSE error chunking and conversation-scoped idempotency
[MODIFY] frontend/web/package.json
         - Add Vitest, jsdom, and React Testing Library dependencies + "test" script
[NEW]    frontend/web/src/components/workspace/__tests__/AssistantView.test.tsx
         - Frontend regression test for hook imports, error boundaries, and stream parsing
[MODIFY] frontend/web/src/components/workspace/AssistantView.tsx
         - Import useCallback, render dismissible error notice on empty stream, stable conversation init
[NEW]    frontend/web/src/components/ui/ErrorBoundary.tsx
         - Graceful fallback container for workspace view crashes
[MODIFY] frontend/web/src/App.tsx
         - Wrap workspace views in ErrorBoundary, separate selectedModelId from activeModelId
[MODIFY] frontend/web/src/components/workspace/ModelsView.tsx
         - Separate selectedModelId from activeModelId, truthful status reflection
[MODIFY] frontend/web/src/components/workspace/models/VramTargetSlider.tsx
         - Rebrand as context headroom guide rather than fake hardware slider
[MODIFY] frontend/web/src/components/workspace/models/AdvancedRuntimeSettings.tsx
         - Purge CUDA references; align labels with Vulkan GPU offload
[MODIFY] frontend/web/src/services/api/conversationApi.ts
         - Deterministic SSE parser handling token, error, [DONE], and unexpected EOF
[MODIFY] docs/01_Tracking/task.md
         - Active task checklist tracking Phase 0-7
[MODIFY] CHANGELOG.md
         - Record stabilization fixes under [Unreleased]
```

---

## 6. Runtime Contract After Fix

```text
               Web UI Client
                     │
                     │ GET /api/v1/models/status
                     ▼
          FastAPI Local AI Core
                     │
         ModelStatusResponse:
         ├── is_loaded: boolean (true only if model resident in router)
         ├── router_running: boolean (true if process alive on 8085)
         ├── model_resident: boolean
         ├── active_model: "qwen3-vl-4b-instruct" | null
         ├── active_profile: "balanced"
         ├── requested_profile: "balanced"
         ├── applied_context_size: 4096 (actual launch flag)
         ├── applied_gpu_layers: 28 (actual launch flag)
         └── router_pid: 12345
                     │
                     │ HTTP /models (polling & control)
                     ▼
             llama-server :8085
             PID: 12345 (SINGLETON GUARDED)
             Args: --ctx-size 4096 -ngl 28 --port 8085 ...
                     │
                     ▼
             AMD RX 580 (Vulkan)
             Measured VRAM: (recorded from clean single-process benchmark)
```

---

## 7. Automated Test Matrix

1. **Backend Tests (`pytest backend/tests/ -v`)**:
   * Singleton router process ownership: second `load_model()` call reuses running PID.
   * Failed startup cleanup: killed child process if health check fails; no zombie on port 8085.
   * Port conflict guard: refuses spawn if 8085 is bound by an alien process.
   * `--ctx-size` launch arg validation: verifies active profile `n_ctx` is passed.
   * Polling return on timeout: returns `False` on load/unload timeout.
   * SSE stream error yielding: exception emits `event: error\ndata: {"error": ...}\n\n`.
   * Conversation-scoped idempotency: duplicate `client_message_id` within same conversation rejected; allowed across distinct conversations.
   * Unique sequence numbers: `(conversation_id, sequence_no)` uniqueness enforced.
2. **Frontend Tests (`npm test` via Vitest + RTL)**:
   * `AssistantView` mounts cleanly without hook `ReferenceError`.
   * `ErrorBoundary` catches view exceptions and renders fallback recovery UI.
   * `streamSendMessage` parser handles `token`, `error`, `[DONE]`, and unexpected EOF.
   * `ModelsView` hydrates `activeModelId` truthfully without mock `'m-1'` override.
3. **Frontend Static Check & Production Build**:
   * `npx tsc --noEmit` clean (0 errors).
   * `npm run build` passes with 0 errors.

---

## 8. Manual PC Verification Matrix

1. **Process & Port Check**:
   * `Get-CimInstance Win32_Process -Filter "Name='llama-server.exe'"` confirms exactly 0 before load, exactly 1 after load.
   * Port 8085 owned exclusively by the Core router PID; legacy script does not interfere.
2. **Clean Baseline VRAM Benchmark**:
   * Record measured VRAM for 2B Eco, 2B Balanced, and 4B Balanced on RX 580.
   * Verify bounded context eliminates the ~7GB dual-process / 32K context ballooning.
3. **Web UI Navigation & Reconnect**:
   * Navigate: Models $\rightarrow$ Assistant $\rightarrow$ Home $\rightarrow$ Models.
   * Reload browser (`F5`): `activeModelId` and conversation history reconcile truthfully.
4. **Assistant Streaming & Disconnect**:
   * Send prompt; verify smooth streaming tokens; verify Stop Generation aborts cleanly.
   * Simulate mid-stream network/generator error; verify visible error notice instead of blank bubble.

---

## 9. Proposed Conventional Commit Messages

* **Phase 1 & 2**: `fix(llm): enforce singleton router ownership, startup cleanup, bounded context, and truthful profiles`
* **Phase 3 & 4**: `feat(models-ui): separate selected and active model state, reconcile runtime truth, and sanitize settings`
* **Phase 5**: `fix(assistant): resolve usecallback crash, add error boundary, and implement deterministic sse terminal semantics`
* **Phase 6**: `fix(db): scope message idempotency by conversation and enforce sequence uniqueness via sqlite batch migration`
* **Phase 7**: `docs: benchmark clean single-process pc runtime on rx 580 and update walkthroughs`
