# Active Branch Task Tracker: M2 Secure Host Lifecycle & Model-Loading Reliability (`PC-HOST-005` + Bounded `PC-CLIENT-010`)

- **Branch:** `feature/m2-secure-host-lifecycle`
- **Target Integration Branch:** `develop`
- **Verified Base SHA:** `261d4b43930d3dcdad2dbd913d4dd4d60c8a4887`
- **Previous Phase 1 Review Checkpoint SHAs:** `8adfae0f964de81528883f73b8165e1cb9f62fae` (Initial), `350ba136b3786a761337e1df8b6720ce4161bc4d` (Revision 1), `d18e3f0f8d8aa8b68d0363f8f5f0a02440d2e90d` (Revision 2)
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
- [x] Complete Round 1 & Round 2 Phase 1 source investigation (`C1`–`C6`, `§9 Process Termination Safety`).
- [x] Complete Final Phase 1 Safety Reconciliation across the three concrete safety contradictions:
  - [x] **Safety Correction 1 (Provider Lock Ownership):** Eliminate unlocked `_stop_managed_router_unlocked()` fallback when `self._lock.acquire()` times out. All shared provider state mutations (`_server_process`, `_server_client`, `_managed_by_core`, `_runtime_state`) occur strictly under `self._lock`; lock acquisition timeout returns `ProviderShutdownResult(completed_cleanly=False, lock_acquired=False, reason="PROVIDER_LOCK_TIMEOUT")` and transitions to `INCOMPLETE_CLEANUP` (`incomplete_provider_lock_timeout`).
  - [x] **Safety Correction 2 (Real Database Quiescence Barrier):** Eliminate the `task.cancel()` + `1.0s` wait before `dispose_database_runtime()`. Require confirmed completion (`all(t.done())` in `_pending_persistence_tasks` and `_active_asgi_mutations == 0`) before engine disposal; if quiescence is not achieved by the deadline, keep the runtime and SQLite engine alive (`incomplete_db_quiescence_timeout`) and require retry or user-confirmed emergency termination disclosing potential incomplete writes.
  - [x] **Safety Correction 3 (Coordinated End-to-End Shutdown Deadline):** Coordinate backend phase caps ($\le 16.1\text{s}$ total) with a `25.0s` Flutter cooperative observation window and `/api/v1/system/status` phase polling so healthy cleanup is never killed prematurely, distinguishing `GRACEFUL_SUCCESS`, `INCOMPLETE_CLEANUP`, `UNRESPONSIVE_RUNTIME`, and `EMERGENCY_TERMINATED`.
- [x] Commit and push final reconciled Phase 1 plan and tracker to `origin/feature/m2-secure-host-lifecycle` and halt for final review.

---

## Phase 2: Autonomous Implementation and Verification (Blocked Pending Phase 1 Approval)
- [ ] **Task 1:** Implement `LlamaCppProvider` strict lock ownership (`_stop_managed_router_locked()`, `PROVIDER_LOCK_TIMEOUT` on lock timeout), lock-free `signal_shutdown_immediately()`, interruptible `load_model()`, Route A/B cancellation safety, lock-free snapshot `get_status()`, and canonical model ID normalization (`test_llama_cpp_provider.py`).
- [ ] **Task 2:** Implement `backend/app/runtime_server.py`, `RuntimeLifecycleCoordinator` (real DB quiescence barrier, `incomplete_db_quiescence_timeout` / `incomplete_provider_lock_timeout` escalation), `dispose_database_runtime()` active-work guard, `POST /api/v1/system/shutdown`, and `COMPANION_HOST_ADMIN_SECRET_FILE` override (`test_host_shutdown.py`).
- [ ] **Task 3:** Regenerate `contracts/openapi/openapi.json` and update `CompanionClient` (`shutdownSystem()` and operation-specific timeouts: `90s` load/select, `20s` unload, `5s` default including `GET /api/v1/models`).
- [ ] **Task 4:** Implement `isCompanionRuntimeCommandLine()`, handle-bound `terminateVerifiedRuntimeProcess()`, and `clearRuntimeLockfileThroughHandle()` in `WindowsRuntimeProcessSupervisor` + `HostAdminSecretStore` path override (`windows_runtime_process_supervisor_test.dart`).
- [ ] **Task 5:** Wire `hostAdminStore` into `DesktopRuntimeCoordinator`, update launch args to `-m app.runtime_server --app app.main:app`, and implement `shutdownLocalRuntime()` with `25.0s` cooperative observation window and 4-outcome handling (`desktop_runtime_coordinator_test.dart`).
- [ ] **Task 6:** Implement Tray & Settings `Exit Companion` confirmation, Incomplete Shutdown Recovery Dialog (`Wait / Retry Graceful Shutdown`, `Force Stop Local Runtime`, `Quit Desktop UI Only`, `Cancel`), 4-state model-loading reconciliation in `SettingsScreen`, and immediate + background `DesktopChatController` synchronization on `GET /api/v1/models`.
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
