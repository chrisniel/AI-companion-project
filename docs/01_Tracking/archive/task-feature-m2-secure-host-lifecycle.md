# Archived Branch Task Tracker: M2 Secure Host Lifecycle & Model-Loading Reliability (`PC-HOST-005` + Bounded `PC-CLIENT-010`)

- **Branch:** `feature/m2-secure-host-lifecycle`
- **Target Integration Branch:** `develop`
- **Verified Base SHA:** `261d4b43930d3dcdad2dbd913d4dd4d60c8a4887`
- **Approved Phase 1 Plan SHA:** `7902782413e5b2b74841ff73628cb7526b4a7e74`
- **Milestone / Work Items:**
  - **Track A (Primary):** `M2 — PC Companion Foundation` / `PC-HOST-005` (`Host Administration Separation & Secure Lifecycle Authority`)
  - **Track B (Bounded Reliability Extension):** `PC-CLIENT-010` (`Model Management UI`), `PC-CLIENT-004` (`API Client Layer`), `PC-MODEL-006` (`Single-Resident Model Lifecycle Policy`)
- **Risk Classification:** `Level C — Sensitive Design`
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md`](../../02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md)
- **Current Lifecycle Phase:** `PHASE 3 — DOCUMENTATION, CLOSURE, AND DRAFT PR (COMPLETE; READY FOR PHASE 4 REVIEW & SQUASH-MERGE)`
- **Delivery Walkthrough:** [`docs/03_Walkthroughs/walkthrough-m2-secure-host-lifecycle.md`](../../03_Walkthroughs/walkthrough-m2-secure-host-lifecycle.md)

---

## Phase 1: Architecture Investigation, Planning Publication & Independent Review Revisions
- [x] Verify clean `develop` baseline (`261d4b43930d3dcdad2dbd913d4dd4d60c8a4887`) and create dedicated branch `feature/m2-secure-host-lifecycle`.
- [x] Apply narrow Phase 1 Planning Git Authorization clarifications to [`AGENTS.md`](../../../AGENTS.md) and [`docs/06_Guides/DELIVERY_WORKFLOW.md`](../../06_Guides/DELIVERY_WORKFLOW.md) (independently accepted in Phase 1 review).
- [x] Complete Round 1 & Round 2 Phase 1 source investigation (`C1`–`C6`, `§9 Process Termination Safety`).
- [x] Complete Final Phase 1 Safety Reconciliation across the three concrete safety contradictions:
  - [x] **Safety Correction 1 (Provider Lock Ownership):** Eliminate unlocked `_stop_managed_router_unlocked()` fallback when `self._lock.acquire()` times out. All shared provider state mutations (`_server_process`, `_server_client`, `_managed_by_core`, `_runtime_state`) occur strictly under `self._lock`; lock acquisition timeout returns `ProviderShutdownResult(completed_cleanly=False, lock_acquired=False, reason="PROVIDER_LOCK_TIMEOUT")` and transitions to `INCOMPLETE_CLEANUP` (`incomplete_provider_lock_timeout`).
  - [x] **Safety Correction 2 (Real Database Quiescence Barrier):** Eliminate the `task.cancel()` + `1.0s` wait before `dispose_database_runtime()`. Require confirmed completion (`all(t.done())` in `_pending_persistence_tasks` and `_active_asgi_mutations == 0`) before engine disposal; if quiescence is not achieved by the deadline, keep the runtime and SQLite engine alive (`incomplete_db_quiescence_timeout`) and require retry or user-confirmed emergency termination disclosing potential incomplete writes.
  - [x] **Safety Correction 3 (Coordinated End-to-End Shutdown Deadline):** Coordinate backend phase caps ($\le 16.1\text{s}$ total) with a `25.0s` Flutter cooperative observation window and `/api/v1/system/status` phase polling so healthy cleanup is never killed prematurely, distinguishing `GRACEFUL_SUCCESS`, `INCOMPLETE_CLEANUP`, `UNRESPONSIVE_RUNTIME`, and `EMERGENCY_TERMINATED`.
- [x] Commit and push final reconciled Phase 1 plan and tracker to `origin/feature/m2-secure-host-lifecycle` (commit `7902782413e5b2b74841ff73628cb7526b4a7e74`); Human Owner and Independent Reviewer approved.

---

## Phase 2: Autonomous Implementation and Verification (Complete & Verified Green)
- [x] **Task 1:** Implemented `LlamaCppProvider` strict lock ownership (`_stop_managed_router_locked()`, `PROVIDER_LOCK_TIMEOUT` on lock timeout), lock-free `signal_shutdown_immediately()`, interruptible `load_model()`, Route A/B cancellation safety, lock-free snapshot `get_status()`, and canonical model ID normalization (`test_llama_cpp_provider.py`: 11/11 tests passed).
- [x] **Task 2:** Implemented `backend/app/runtime_server.py`, `RuntimeLifecycleCoordinator` (real DB quiescence barrier, `incomplete_db_quiescence_timeout` / `incomplete_provider_lock_timeout` escalation), `dispose_database_runtime()` active-work guard, `POST /api/v1/system/shutdown`, and `COMPANION_HOST_ADMIN_SECRET_FILE` override (`test_host_shutdown.py`: 8/8 tests passed).
- [x] **Task 3:** Regenerated `contracts/openapi/openapi.json` and updated `CompanionClient` (`shutdownSystem()` and operation-specific timeouts: `90s` load/select, `20s` unload, `25s` shutdown, `5s` default including `GET /api/v1/models`).
- [x] **Task 4:** Implemented `isCompanionRuntimeCommandLine()`, handle-bound `terminateVerifiedRuntimeProcess()`, and `clearRuntimeLockfileThroughHandle()` in `WindowsRuntimeProcessSupervisor` + `HostAdminSecretStore` path override (`windows_runtime_process_supervisor_test.dart`: passed).
- [x] **Task 5:** Wired `hostAdminStore` into `DesktopRuntimeCoordinator`, updated launch args to `-m app.runtime_server --app app.main:app`, and implemented `shutdownLocalRuntime()` with `25.0s` cooperative observation window and 4-outcome handling (`desktop_runtime_coordinator_test.dart`: passed).
- [x] **Task 6:** Implemented Tray & Settings `Exit Companion` confirmation dialogs, Incomplete Shutdown Recovery Dialog (`Wait / Retry Graceful Shutdown`, `Force Stop Local Runtime`, `Quit Desktop UI Only`, `Cancel`), 4-state model-loading reconciliation in `SettingsScreen`, and immediate + background `DesktopChatController` synchronization on `GET /api/v1/models` (`desktop_shutdown_dialogs_test.dart` and `desktop_settings_test.dart`: passed).
- [x] **Task 7:** Ran full verification suites:
  - Backend Pytest: 660/660 passed in 78.42s
  - Flutter companion_core: 23/23 passed
  - Flutter companion_api: 81/81 passed
  - Flutter desktop: 297/297 passed
  - Dart analyze: 0 issues across all packages
  - OpenAPI Parity: 40 routes, 24/24 DTOs, 30/19 covered routes
  - React web tests: 16 test files passed, 248/248 passed
  - Windows supervision acceptance: 6/6 scenarios passed

---

## Phase 3: Documentation, Closure, and Draft PR (Complete)
- [x] Reconciled canonical architecture and master tracking documentation:
  - `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`
  - `docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`
  - `docs/04_Architecture/04_Infrastructure/runtime-and-models.md`
  - `docs/02_Planning/00_Master/DELIVERY_INDEX.md`
  - `docs/02_Planning/00_Master/WBS.md`
  - `docs/02_Planning/00_Master/MASTER_CHECKLIST.md`
  - `docs/02_Planning/00_Master/SPRINT_ROADMAP.md`
  - `CHANGELOG.md`
- [x] Authored delivery walkthrough in [`docs/03_Walkthroughs/walkthrough-m2-secure-host-lifecycle.md`](../../03_Walkthroughs/walkthrough-m2-secure-host-lifecycle.md).
- [x] Archived this branch tracker to `docs/01_Tracking/archive/task-feature-m2-secure-host-lifecycle.md`, staged all files, committed Conventional Commit, pushed to `origin/feature/m2-secure-host-lifecycle`, and prepared draft PR against `develop`.

---

## Phase 4: Combined Independent Review and Human Merge

### Independent Review Corrections (Implemented & Verified):
- [x] **A. Whole-Runtime Quiescence:** Replaced `BaseHTTPMiddleware` with pure ASGI `RuntimeAdmissionASGIMiddleware` holding mutation admission for full request/streaming response lifecycle. Registered assistant stream tasks with drain. Added persistence task result tracking (success/failure/cancelled), preventing clean shutdown if any persistence fails (`incomplete_persistence_failure`).
- [x] **B. Incomplete-Shutdown Retry:** Made `initiate_shutdown()` bounded and idempotent, allowing retries after `incomplete_*` states without creating duplicate concurrent shutdown tasks.
- [x] **C. Emergency Stop Authorization & Outcome Handling:** In `DesktopRuntimeCoordinator.shutdownLocalRuntime()`, isolated auth errors (401/403) from transport errors and prohibited silent OS termination fallback. In `DesktopShell` and `SettingsScreen`, inspected `forceEmergencyStopLocalRuntime()` return value; if termination fails, keeps UI open and displays error SnackBar.
- [x] **D. Child Process Provenance:** Implemented handle-bound child verification in PowerShell fallback checking parentage (`$childCim.ParentProcessId -eq $targetPid`), creation time (`$childCreated -ge $parentCreated`), executable name (`llama`), and command-line arguments. Fails closed on ambiguous ownership and never kills unrelated or externally managed `llama-server.exe`.
- [x] **E. Provider Cleanup Truthfulness:** In `_stop_managed_router_locked()`, verifies `self._server_process.poll()` is not None before clearing state; if process remains alive, retains reference/ownership, returns `False`, and reports `ROUTER_TERMINATION_FAILED`.
- [x] **F. Model-Load Cancellation:** Registered and tracked active loading tasks (`_active_load_task`) and router HTTP clients (`_active_router_clients`). Made router startup, HTTP load operations, and polling cancellation-aware (`_sleep_or_abort`). Ensured synchronized cleanup under lock on `CancelledError`.
- [x] **G. Shutdown Completion Detection:** Verified expected process identity and dead state before reporting `gracefulSuccess` or clearing lockfile descriptor.
- [x] **H. Provider Lifecycle Synchronization:** Restored exclusive lock synchronization for `load_model()` in `backend/app/services/llm/llama_cpp.py`; wrapped both critical section and `asyncio.CancelledError` recovery under `async with self._lock:`.
- [x] **I. Handle-Bound Child Verification & Partial Termination:** Bound child process verification to terminated handle in `WindowsRuntimeProcessSupervisor` (`$null = $childProc.Handle`, CIM start-time $\le 3\text{s}$ check, command-line inspection). Added `partialTermination` status when parent exits but child survives.
- [x] **J. Shutdown Call Coalescing & State Guards:** Coalesced concurrent shutdown invocations in `DesktopRuntimeCoordinator` onto `_activeShutdownFuture`. Prevented spurious `gracefulSuccess` on generation changes or disposed state while shutdown is active.
- [x] **K. Failed Persistence Retention Across Retries:** Preserved `_persistence_failures` across retried shutdowns in `RuntimeLifecycleCoordinator` so failed writes remain visible until resolved.
- [x] **L. Fail-Closed Emergency Fallback:** Distinguished `CompanionApiException` (401/403); returned `ShutdownOutcome.unresponsiveRuntime` at observation window expiry instead of auto-killing.
- [x] **M. Owned Router Tracking:** Tracked `_lastKnownManagedLlmPid` and `_lastKnownManagedByCore` across telemetry cycles and passed them to `forceEmergencyStopLocalRuntime()`.
- [x] **N. Database Read Safety During Shutdown:** Removed `db: AsyncSession` dependency from `/system/status` in `health.py`; eliminated SQLite queries during `is_shutting_down == True`.
- [x] **O. Extended Windows Acceptance Suite:** Added Scenarios G, H, and I verifying loopback shutdown, foreign child preservation, and partial termination reporting on live Windows processes.
- [x] **Verification Evidence:**
  - Backend Pytest: 669/669 passed, 1 warning in ~201s (0 failures)
  - Flutter companion_core: 23/23 passed
  - Flutter companion_api: 81/81 passed
  - Flutter desktop: 307/307 passed
  - Dart analyze: 0 issues across all packages
  - React web tests: 16 test files passed, 248/248 passed
  - OpenAPI Drift Check: clean (0 differences)
  - OpenAPI Parity: 40 routes, 24/24 DTOs, 30/19 covered routes
  - Windows supervision acceptance: 9/9 scenarios passed (Scenarios A through I)

### Merge Readiness:
- [ ] Independent Reviewer final evaluation of corrected delivery package.
- [ ] Human Owner squash-merge into `develop` and read-only post-merge verification.
