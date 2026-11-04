# Active Branch Task Tracker: M2 Secure Host Lifecycle & Model-Loading Reliability (`PC-HOST-005` + Bounded `PC-CLIENT-010`)

- **Branch:** `feature/m2-secure-host-lifecycle`
- **Target Integration Branch:** `develop`
- **Verified Base SHA:** `261d4b43930d3dcdad2dbd913d4dd4d60c8a4887`
- **Previous Phase 1 Review Checkpoint SHAs:** `8adfae0f964de81528883f73b8165e1cb9f62fae` (Initial), `350ba136b3786a761337e1df8b6720ce4161bc4d` (Revision 1)
- **Milestone / Work Items:**
  - **Track A (Primary):** `M2 — PC Companion Foundation` / `PC-HOST-005` (`Host Administration Separation & Secure Lifecycle Authority`)
  - **Track B (Bounded Reliability Extension):** `PC-CLIENT-010` (`Model Management UI`), `PC-CLIENT-004` (`API Client Layer`), `PC-MODEL-006` (`Single-Resident Model Lifecycle Policy`)
- **Risk Classification:** `Level C — Sensitive Design`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md`](../../02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md)
- **Current Lifecycle Phase:** `PHASE 1 — PLAN AND AUTHORIZATION (AWAITING HUMAN / INDEPENDENT PLAN REVIEW)`

---

## Phase 1: Architecture Investigation, Planning Publication & Independent Review Revisions
- [x] Verify clean `develop` baseline (`261d4b43930d3dcdad2dbd913d4dd4d60c8a4887`) and create dedicated branch `feature/m2-secure-host-lifecycle`.
- [x] Apply narrow Phase 1 Planning Git Authorization clarifications to [`AGENTS.md`](../../../AGENTS.md) and [`docs/06_Guides/DELIVERY_WORKFLOW.md`](../../06_Guides/DELIVERY_WORKFLOW.md) (independently accepted in Phase 1 review).
- [x] Complete Round 1 & Round 2 Phase 1 source investigation and resolve all Independent Review findings (`C1`–`C6` and `§9 Process Termination Safety`):
  - [x] **Final `C1` (Reliable Uvicorn Ownership):** Replace `gc.get_objects()` / stack introspection with dedicated programmatic entrypoint `backend/app/runtime_server.py` (`pythonw.exe -m app.runtime_server --app app.main:app --host <host> --port <port> --no-use-colors`) that explicitly registers `uvicorn.Server` on `RuntimeLifecycleCoordinator`, and update supervisor launch + provenance checks (`isCompanionRuntimeCommandLine`).
  - [x] **Final `C2` (Shutdown During Active Model Loading):** Introduce lock-free `signal_shutdown_immediately()` (`_closing = True`, `_shutdown_event.set()`, cancel `_active_load_task` & close active router `httpx` clients) executing *before* `self._lock` acquisition, plus interruptible `_sleep_or_abort()` waits and partial router cleanup inside `load_model()`.
  - [x] **Final `C3` (Database Quiescence & Cancellation Persistence):** Track full ASGI request/stream lifetimes (`_active_asgi_mutations`), active streaming turns (`_active_stream_tasks`), and explicit `asyncio.Task[bool]` handles in `_pending_persistence_tasks` (`spawn_terminal_persistence_task` for `_persist_terminal_assistant_status`), awaiting their commit completion before `dispose_database_runtime()` and distinguishing `CLEAN_QUIESCENCE`, `PERSISTENCE_INCOMPLETE`, and `DRAIN_TIMED_OUT`.
  - [x] **Final `C4` (Exact Existing API Contracts):** Align all plan references with actual `GET /api/v1/models` (model status) and `POST /api/v1/models/select` / `/load` payload field `model_name` (`modelName` in Dart).
  - [x] **Final `C5` (Model-Load Timeout Truthfulness):** Define 4 explicit reconciliation states (`CONFIRMED_READY`, `CONFIRMED_FAILED`, `STILL_LOADING` with `Refresh Model Status` without duplicate load POST, and `STATUS_UNKNOWN_TIMED_OUT`) plus `DesktopChatController` background `GET /api/v1/models` polling while `SERVER_STARTING` / `MODEL_LOADING`.
  - [x] **Final `C6` (Host Admin & Auth Accuracy):** Accurately document `HostAdminSecretStore.readToken()` disk-read + ACL validation per `_adminRequest`, and test `Authorization: Bearer psk_...`, `Authorization: Bearer companion_sec_...` / `X-API-Key`, and malformed headers separately.
  - [x] **Process Termination Safety (`§9`):** Specify handle-bound `GetProcessById` $\rightarrow$ 4-factor verification $\rightarrow$ `$proc.Kill()` and independent child `llama-server.exe` handle verification as Phase 2 verification propositions (`P1`–`P4`).
- [x] Commit and push final Phase 1 planning revisions to `origin/feature/m2-secure-host-lifecycle` and halt for final Human Owner and Independent Reviewer approval.

---

## Phase 2: Autonomous Implementation and Verification (Blocked Pending Phase 1 Approval)
- [ ] **Task 1:** Implement `LlamaCppProvider` lock-free `signal_shutdown_immediately()`, interruptible `load_model()`, lifecycle separation (`unload_model`, `stop_managed_router`, `shutdown`), Route A/B cancellation safety, lock-free snapshot `get_status()`, and canonical model ID normalization (`test_llama_cpp_provider.py`).
- [ ] **Task 2:** Implement `backend/app/runtime_server.py`, `RuntimeLifecycleCoordinator` (explicit `uvicorn.Server` registration, full-ASGI mutation drain, tracked `_pending_persistence_tasks`), `POST /api/v1/system/shutdown`, and `COMPANION_HOST_ADMIN_SECRET_FILE` override (`test_host_shutdown.py`).
- [ ] **Task 3:** Regenerate `contracts/openapi/openapi.json` and update `CompanionClient` (`shutdownSystem()` and operation-specific timeouts: `90s` load/select, `20s` unload, `5s` default including `GET /api/v1/models`).
- [ ] **Task 4:** Implement `isCompanionRuntimeCommandLine()`, handle-bound `terminateVerifiedRuntimeProcess()`, and `clearRuntimeLockfileThroughHandle()` in `WindowsRuntimeProcessSupervisor` + `HostAdminSecretStore` path override (`windows_runtime_process_supervisor_test.dart`).
- [ ] **Task 5:** Wire `hostAdminStore` into `DesktopRuntimeCoordinator`, update launch args to `-m app.runtime_server --app app.main:app`, and implement `shutdownLocalRuntime()` (`desktop_runtime_coordinator_test.dart`).
- [ ] **Task 6:** Implement Tray & Settings `Exit Companion` confirmation/failure recovery dialogs, 4-state truthful model-loading reconciliation in `SettingsScreen`, and immediate + background `DesktopChatController` synchronization on `GET /api/v1/models`.
- [ ] **Task 7:** Run full backend `pytest`, Flutter unit/widget/acceptance suites (`windows_runtime_supervision_acceptance_test.dart`), `dart analyze`, React web tests, and `scripts/check_openapi_contract.py --check`.

---

## Phase 3: Documentation, Closure, and Draft PR (Blocked Pending Phase 2 Completion)
- [ ] Reconcile canonical documentation (`windows-host-and-notifications.md`, `authentication-and-secrets.md`, `runtime-and-models.md`, `SYSTEM_BASELINE.md`, `DELIVERY_INDEX.md`, `WBS.md`, `CHANGELOG.md`).
- [ ] Author technical walkthrough (`docs/03_Walkthroughs/walkthrough-m2-secure-host-lifecycle.md`).
- [ ] Archive this branch tracker to `docs/01_Tracking/archive/task-feature-m2-secure-host-lifecycle.md`, push verified commits, and open draft PR against `develop`.

---

## Phase 4: Combined Independent Review and Human Merge (Blocked Pending Phase 3)
- [ ] Independent review evaluation and any bounded same-branch corrections.
- [ ] Human Owner squash merge into `develop` and read-only post-merge verification.
