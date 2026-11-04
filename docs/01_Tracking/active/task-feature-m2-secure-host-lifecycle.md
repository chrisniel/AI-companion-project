# Active Branch Task Tracker: M2 Secure Host Lifecycle & Model-Loading Reliability (`PC-HOST-005` + Bounded `PC-CLIENT-010`)

- **Branch:** `feature/m2-secure-host-lifecycle`
- **Target Integration Branch:** `develop`
- **Verified Base SHA:** `261d4b43930d3dcdad2dbd913d4dd4d60c8a4887`
- **Previous Phase 1 Review Checkpoint SHA:** `8adfae0f964de81528883f73b8165e1cb9f62fae`
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
- [x] Complete expanded Phase 1 source investigation covering all Independent Review findings (`C1`–`C6`), confirmed shutdown defects (`Issue A1` & `Issue A2`), and the Human Owner's confirmed Model-Loading Reliability defect (`Issue B1`):
  - [x] `Issue A1`: Separate `unload_model()`, `stop_managed_router()`, `shutdown()`, and supervisor emergency recovery; preserve externally started `llama-server.exe` (`_managed_by_core == False`).
  - [x] `Issue A2`: Unify Tray and Settings `Exit Companion` behind mandatory confirmation while preserving `Close Window (×)` and `Close UI Only (Dev Test)`.
  - [x] `Issue B1` (Track B): Trace 5-second hardcoded client timeout in `CompanionClient._requestWithoutRedirects`, lockless state clobbering and unnormalized model IDs in `LlamaCppProvider.get_status()`, missing post-timeout polling in `SettingsScreen`, and missing `DesktopChatController` model-status sync.
  - [x] `Correction C1`: Replace Windows-unsafe `os.kill(SIGINT)` with signal-free `uvicorn.Server.should_exit = True` lifecycle coordination (`RuntimeLifecycleCoordinator`).
  - [x] `Correction C2`: Replace WMI-then-`Stop-Process` with a single handle-bound verification and termination flow (`System.Diagnostics.Process.GetProcessById` holding `SafeProcessHandle` during 4-factor verification and `$proc.Kill()`), eliminating TOCTOU PID-reuse risk.
  - [x] `Correction C3`: Differentiate Route A (`httpx` stream task cancellation) vs. Route B (`_closing` chunk loop break + native C++ `del self._llm` guard when worker thread remains active).
  - [x] `Correction C4`: Wire `HostAdminSecretStore` into `DesktopRuntimeCoordinator` (`main.dart` and `updateConfiguration`) and `SettingsScreen._resolveClient()`.
  - [x] `Correction C5`: Align exact routes (`GET /api/v1/health`, `GET /api/v1/system/status`, `POST /api/v1/system/shutdown`), distinct file paths (`%LOCALAPPDATA%\AI Companion\runtime.lock` vs. `%LOCALAPPDATA%\AICompanion\secrets\desktop_admin.secret`), and dynamic port handling.
  - [x] `Correction C6`: Add whole-runtime mutation admission-control middleware (`503 RUNTIME_SHUTTING_DOWN`) and in-flight mutation drain before `dispose_database_runtime()`.
- [x] Revise [`docs/02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md`](../../02_Planning/01_Plans/plan-m2-secure-host-lifecycle.md) with all 20 required sections and complete boundary-by-boundary safety closure analysis.
- [x] Commit and push revised Phase 1 planning and tracking files to `origin/feature/m2-secure-host-lifecycle` and halt for Human Owner and Independent Reviewer approval.

---

## Phase 2: Autonomous Implementation and Verification (Blocked Pending Phase 1 Approval)
- [ ] **Task 1:** Implement `LlamaCppProvider` lifecycle separation (`unload_model`, `stop_managed_router`, `shutdown`), Route A/B cancellation safety, `get_status()` lock/state preservation, and canonical model ID normalization (`test_llama_cpp_provider.py`).
- [ ] **Task 2:** Implement `RuntimeLifecycleCoordinator` (`uvicorn.Server.should_exit = True`), whole-runtime mutation admission control & drain middleware, `POST /api/v1/system/shutdown`, and `COMPANION_HOST_ADMIN_SECRET_FILE` override (`test_host_shutdown.py`).
- [ ] **Task 3:** Regenerate `contracts/openapi/openapi.json` and update `CompanionClient` (`shutdownSystem()` and operation-specific timeouts: `90s` load/select, `20s` unload, `5s` default).
- [ ] **Task 4:** Implement handle-bound `terminateVerifiedRuntimeProcess()` and `clearRuntimeLockfileThroughHandle()` in `WindowsRuntimeProcessSupervisor` + `HostAdminSecretStore` path override.
- [ ] **Task 5:** Wire `hostAdminStore` into `DesktopRuntimeCoordinator` and implement `shutdownLocalRuntime()`.
- [ ] **Task 6:** Implement Tray & Settings `Exit Companion` confirmation/failure recovery dialogs, bounded model-loading polling reconciliation in `SettingsScreen`, and immediate `DesktopChatController.updateModelStatus()` synchronization.
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
