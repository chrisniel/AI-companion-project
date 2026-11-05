# Walkthrough: M2 Secure Host Lifecycle & Bounded Model-Loading Reliability (PC-HOST-005)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Purpose:** Document the architectural mechanisms, implementation components, data models, client controls, process supervision boundaries, and verification evidence for AI Companion's Secure Host Lifecycle, Provider Cleanup, and Bounded Model-Loading Reliability (`PC-HOST-005`, with bounded `PC-CLIENT-010` / `PC-CLIENT-004` / `PC-MODEL-006` reliability).
- **Audience:** Core developers, client application engineers (Flutter Desktop & React Web), host infrastructure maintainers, and independent reviewers.
- **Status:** Implemented & Verified (Level C delivery: approved implementation plan commit `7902782413e5b2b74841ff73628cb7526b4a7e74`; all implementation and automated verification tasks completed green; Phase 4 final review safety corrections applied and verified on branch `feature/m2-secure-host-lifecycle`).
- **Last Updated:** 2026-11-05

---

## 1. What Was Delivered

### Track A — Secure Host Lifecycle & Host Administration (`PC-HOST-005`)

1. **Dedicated Programmatic Runtime Server (`backend/app/runtime_server.py`):**
   - Implemented `run_runtime_server()` entrypoint that instantiates `uvicorn.Config` and `uvicorn.Server` programmatically, binding the running server instance to `RuntimeLifecycleCoordinator.set_server()`.
   - Replaced unmanaged CLI uvicorn spawning with explicit server lifecycle management capable of triggering cooperative asynchronous `server.should_exit = True`.

2. **Loopback-Only Authenticated Host Administration Endpoint (`POST /api/v1/system/shutdown`):**
   - Protected strictly by `require_host_admin` dependency in `backend/app/core/host_admin.py`.
   - Validates incoming requests against `X-Host-Admin-Secret` header or loopback-only peer authentication.
   - Restricts invocation to loopback addresses (`127.0.0.1`, `::1`); remote requests receive `403 FORBIDDEN (LOOPBACK_ONLY_FEATURE)`.
   - Emits structured synchronous `202 ACCEPTED` response with `correlation_id`, `drain_timeout_seconds`, and `status = "shutting_down"` before launching the asynchronous shutdown sequence in the background.

3. **Admission Control & Real Database Quiescence Barrier:**
   - Implemented pure ASGI admission control in `RuntimeAdmissionASGIMiddleware` (`backend/app/core/runtime_lifecycle.py`): once shutdown is initiated, all new non-health incoming requests receive `503 SERVICE_UNAVAILABLE (RUNTIME_SHUTTING_DOWN)`.
   - Read-only database activity accounting during shutdown: tracks in-flight ASGI read requests (`_active_asgi_reads`) in `has_active_database_work`. Database engine disposal (`engine.dispose()`) is strictly blocked until all admitted read operations complete.
   - Admission gating for read operations: `RuntimeAdmissionASGIMiddleware` rejects new database-dependent reads during teardown with 503 `RUNTIME_SHUTTING_DOWN`, while preserving loopback polling routes (`/health`, `/system/status`, `/models`).
   - Telemetry database dependency decoupling: `verify_telemetry` dynamically resolves DB sessions only when verifying database-backed profile session tokens (`psk_`), eliminating unnecessary database transactions and engine contention during shutdown polling.
   - Request and stream draining: tracks active mutation requests, active assistant stream tasks, and persistence tasks (`_pending_persistence_tasks` in `backend/app/db/session.py`). Shutdown strictly awaits in-flight persistence tasks and drains active streams before invoking `engine.dispose()`.
   - Failed persistence evidence retention: if any persistence task fails, the failure record is preserved in `_persistence_failures` across retries, preventing premature or deceptive clean shutdown claims (`incomplete_persistence_failure`).
   - SQLite isolation during shutdown: removed database dependency from `GET /api/v1/system/status`. When `runtime_lifecycle.is_shutting_down == True`, SQLite is never queried or touched, completely eliminating connection contention or pool-disposal race conditions during polling.

4. **Strict Provider Lock Ownership & Exclusive Lifecycle Synchronization (`backend/app/services/llm/llama_cpp.py`):**
   - Restored complete exclusive provider lifecycle synchronization: model loading (`load_model()`), unloading, router process startup/shutdown, profile switching, and Route A/B memory management execute entirely within `async with self._lock:`.
   - Synchronized cancellation handling: `except asyncio.CancelledError` inside `load_model()` executes its router cleanup and state reset under the already-held `self._lock`, preventing concurrent lifecycle mutations during aborted loads.
   - Router ownership preservation across all cleanup paths: on any failed or unverified router termination (including hardware profile switching, startup timeout, or explicit unload), `_stop_managed_router_locked()` preserves `_server_process`, `_server_pid`, and `_managed_by_core`, setting `_last_error = "ROUTER_TERMINATION_FAILED"` and `_runtime_state = SERVER_ERROR` rather than deceptively clearing state.
   - Verified process exit: checks `self._server_process.poll() is not None` after termination wait before clearing ownership references.
   - During `shutdown()`, sets `_cancel_requested = True` to unblock any pending model load or generation.
   - Enforces strict provider lock ownership (`self._lock`): only cleans up shared provider resources if the lock is successfully acquired. If lock acquisition times out, reports a truthful lock timeout failure without executing concurrent unlocked cleanup routines.
   - Inference drain: checks `self.has_active_generation`. If drain times out while inference is active, cleanly retains model weights and router state rather than corrupting in-flight streams.
   - External router preservation: `_stop_managed_router_locked()` only terminates router processes spawned and owned by the runtime (`self._managed_router_process`). Externally launched or pre-existing routers are preserved untouched.
   - Route B `del self._llm` guard: explicitly releases native `llama_cpp.Llama` memory before setting state to `SERVER_STOPPED`.

5. **Handle-Bound Windows OS Process Supervision (`WindowsRuntimeProcessSupervisor`):**
   - Process supervision uses PowerShell CIM `Win32_Process` parentage/provenance verification and kernel file locking (`RandomAccessFile.lock(FileLock.blockingExclusive)`).
   - Confirmed exit verification: checks the boolean return of `$proc.WaitForExit(5000)` and `$proc.HasExited` on the retained process handle. Never reports `terminated` unless the process has actually exited; preserves `timeout` status if the process survives.
   - Unknown managed-child identity discovery & provenance verification: when emergency termination is invoked without an authoritative child PID (`managedLlmPid == 0`), queries candidate child processes spawned under the runtime tree (including across intermediate Python worker subprocesses created by venv launchers).
   - Strict candidate provenance checking: verifies candidate process handle creation time against CIM table ($\le 3\text{s}$ tolerance), verified runtime parentage, creation time $\ge$ parent start time, executable name (`llama-server.exe` / `llama-server`), and launch arguments (`--port` and `--models-dir` / `--model`).
   - Foreign process preservation: non-llama or foreign child processes (such as child shell or worker instances) are strictly preserved and never killed. Sets `unverifiedChildDetected = true` and reports `partialTermination`.
   - Process entrypoint provenance verification: inspects executable path, creation timestamp, and command-line arguments before issuing any process termination fallback, eliminating PID reuse / recycling hazards.
   - Handle-bound child process verification: opens and retains a real process handle (`$null = $childProc.Handle`) immediately upon identifying the child candidate.
   - Discards method return pipeline pollution (`$null = $proc.WaitForExit(...)`) preventing JSON output corruption in Dart.
   - Partial termination reporting: if the parent runtime process is terminated but its owned child process fails to terminate, reports structured status `partialTermination`.
   - Cleans up stale runtime lockfiles through locked handle truncation and deletion upon confirmed process termination.

6. **Coordinated Shutdown Orchestration (`DesktopRuntimeCoordinator`):**
   - Coalesces concurrent shutdown requests onto a single authoritative `Future<ShutdownOutcome>? _activeShutdownFuture`.
   - Tracks owned router process state (`_lastKnownManagedLlmPid` and `_lastKnownManagedByCore`) across telemetry and shutdown cycles, passing them to emergency termination routines.
   - Coordinates the 25-second cooperative shutdown window:
     1. Primary loopback authenticated `POST /api/v1/system/shutdown` invocation.
     2. Polls runtime exit state up to cooperative deadline.
     3. Never returns `gracefulSuccess` on generation changes or disposed state while shutdown is active.
     4. Distinguishes typed authentication errors (`CompanionApiException` 401/403) from transport errors.
     5. At observation window expiry, returns `ShutdownOutcome.unresponsiveRuntime` (fails closed without auto-killing), prompting the user via the Incomplete Shutdown Recovery Dialog.
   - In `forceEmergencyStopLocalRuntime()`, if the supervisor reports `partialTermination` or the owned child remains active, reports `ShutdownOutcome.incompleteCleanup`.
   - Handles distinct exit outcomes:
     - `CLEAN_SHUTDOWN`: Cooperative shutdown succeeded cleanly.
     - `INCOMPLETE_CLEANUP_FALLBACK_TERMINATED`: Loopback shutdown reported incomplete cleanup; handle-bound process supervisor terminated remaining processes.
     - `SHUTDOWN_TIMEOUT_FORCE_TERMINATED`: Loopback shutdown timed out; process supervisor forced termination.
     - `UNRESPONSIVE_RUNTIME`: Observation window expired; user prompted for emergency stop.
     - `RECOVERY_FAILED_PID_UNKNOWN`: Termination failed due to unknown PID or permissions; triggers user recovery dialog.

7. **Desktop UI Controls & Recovery Dialogs:**
   - Tray menu and Settings screen "Exit Companion" actions trigger `showExitConfirmationDialog()`, requiring explicit user confirmation before terminating background processes.
   - If runtime cleanup encounters errors or incomplete state, displays `showIncompleteShutdownRecoveryDialog()` offering user diagnostic options.
   - Remote host safety: If connected to a remote runtime (`isRemoteHost == true`), the "Exit Companion" action terminates only the local desktop UI, never shutting down the remote host.

---

### Track B — Bounded Model-Loading Reliability (`PC-CLIENT-010` / `PC-CLIENT-004` / `PC-MODEL-006`)

1. **Bounded Client Operation Timeouts (`frontend/flutter/packages/companion_api`):**
   - Configured bounded timeouts on `CompanionClient`:
     - Model selection / loading: 90 seconds (`defaultModelLoadTimeout`).
     - Model unloading: 20 seconds.
     - System shutdown: 25 seconds.
   - Prevents UI freezes and unbounded HTTP connection hangs when model weights are large or storage I/O is slow.

2. **Lock-Free Status Snapshot During Loading (`LlamaCppProvider`):**
   - In `get_status()`, reads transitional loading state without acquiring `self._lock` if a model load is actively in progress.
   - Eliminates client polling deadlocks: clients can query `GET /api/v1/models` and `GET /api/v1/system/status` smoothly while `load_model()` holds the lock.

3. **Canonical Model ID Normalization:**
   - Unified model identifiers across backend endpoints (`/api/v1/models`, `/api/v1/models/select`) and client controllers.
   - Resolves both bare model names and library-relative paths (`models/llm/model.gguf`) consistently.

4. **4-State Truthful Status Reconciliation & Background Sync (`DesktopChatController` & `SettingsScreen`):**
   - Reconciles transitional states into four unambiguous states:
     - `CONFIRMED_READY`: Model is fully loaded into memory and ready for inference.
     - `CONFIRMED_FAILED`: Model loading failed with an explicit error code.
     - `STILL_LOADING`: Model is loading in the background (after 5-second initial wait); displays background progress and enables "Refresh Model Status" button.
     - `STATUS_UNKNOWN_TIMED_OUT`: Status polling timed out; provides diagnostic recovery options.
   - `SettingsScreen._selectModel()` transitions immediately to `STILL_LOADING` upon receiving `MODEL_LOADING`, launching background persistence with `unawaited()` to prevent UI thread blocking.
   - Background polling loop safely guards against hanging timer events in test environments via `FLUTTER_TEST` check.

---

## 2. Files Changed

| Category | File Path | Action | Description |
| :--- | :--- | :---: | :--- |
| **Backend Core** | `backend/app/core/runtime_lifecycle.py` | ADD | `RuntimeLifecycleCoordinator` managing server registration, admission control, request draining, and quiescence. |
| **Backend Core** | `backend/app/runtime_server.py` | ADD | Programmatic Uvicorn server entrypoint (`run_runtime_server`). |
| **Backend Core** | `backend/app/core/host_admin.py` | MODIFY | Added `require_host_admin` dependency and secret validation. |
| **Backend DB** | `backend/app/db/session.py` | MODIFY | Implemented `_pending_persistence_tasks` tracker and quiescence awaiter in `close_db()`. |
| **Backend Endpoints** | `backend/app/api/v1/endpoints/health.py` | MODIFY | Implemented `POST /api/v1/system/shutdown` endpoint. |
| **Backend Schemas** | `backend/app/schemas/health.py` | MODIFY | Added `SystemShutdownResponse` and shutdown DTO schemas. |
| **Backend LLM** | `backend/app/services/llm/base.py` | MODIFY | Added cancellation tokens and lock timeout types to `BaseLLMProvider`. |
| **Backend LLM** | `backend/app/services/llm/llama_cpp.py` | MODIFY | Strict lock ownership, Route B `del self._llm`, lock-free `get_status()` snapshot, managed router termination. |
| **Backend Service** | `backend/app/services/assistant/orchestrator.py` | MODIFY | Integrated admission control and generation drain awareness. |
| **Backend Main** | `backend/app/main.py` | MODIFY | Wired `RuntimeLifecycleCoordinator` middleware and startup/shutdown hooks. |
| **Backend Tests** | `backend/tests/test_host_shutdown.py` | ADD | 16 tests verifying loopback shutdown, auth, admission control, quiescence, retry persistence retention, and DB-safe `/system/status` polling. |
| **Backend Tests** | `backend/tests/test_llama_cpp_provider.py` | ADD | 12 tests verifying serialized lock ownership, cancellation under lock, external router preservation, and drain behavior. |
| **Contracts** | `contracts/openapi/openapi.json` | MODIFY | Hardened OpenAPI contract with `POST /api/v1/system/shutdown` and response schemas. |
| **Contracts Script** | `scripts/check_dart_openapi_parity.py` | MODIFY | Validated 40 routes and 24 DTOs including shutdown schemas. |
| **Companion Core** | `frontend/flutter/packages/companion_core/lib/platform/runtime_process_state.dart` | MODIFY | Added exit outcome and process state enums. |
| **Companion Core** | `frontend/flutter/packages/companion_core/test/runtime_process_state_test.dart` | MODIFY | Unit tests for process state models. |
| **Companion API** | `frontend/flutter/packages/companion_api/lib/client/companion_client.dart` | MODIFY | Added `shutdownRuntime()`, 90s model load timeouts, 20s unload timeouts. |
| **Companion API** | `frontend/flutter/packages/companion_api/lib/dto/system_status_dto.dart` | MODIFY | Added `SystemShutdownResponseDto` and status deserializers. |
| **Companion API** | `frontend/flutter/packages/companion_api/test/companion_client_test.dart` | MODIFY | Unit tests for client shutdown and timeout configurations. |
| **Flutter Desktop** | `frontend/flutter/apps/desktop/lib/platform/windows_runtime_process_supervisor.dart` | MODIFY | Handle-bound CIM Win32_Process supervision, child provenance verification, and partial termination reporting. |
| **Flutter Desktop** | `frontend/flutter/apps/desktop/lib/coordinator/desktop_runtime_coordinator.dart` | MODIFY | Coordinated 25s shutdown window, shutdown future coalescing, child tracking, and fail-closed unresponsive runtime fallback. |
| **Flutter Desktop** | `frontend/flutter/apps/desktop/lib/dialogs/exit_confirmation_dialog.dart` | ADD | User confirmation dialog for Exit Companion action. |
| **Flutter Desktop** | `frontend/flutter/apps/desktop/lib/dialogs/incomplete_shutdown_recovery_dialog.dart` | ADD | Recovery dialog presenting options when cleanup is incomplete. |
| **Flutter Desktop** | `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart` | MODIFY | Integrated Exit Companion button, 4-state model loading reconciliation, and manual refresh. |
| **Flutter Desktop** | `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart` | MODIFY | Wired tray Exit menu to `showExitConfirmationDialog()`. |
| **Flutter Desktop** | `frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart` | MODIFY | Added 90s model select timeout and background status sync. |
| **Flutter Desktop Tests** | `frontend/flutter/apps/desktop/test/desktop_shutdown_dialogs_test.dart` | ADD | Widget tests for exit confirmation and recovery dialogs. |
| **Flutter Desktop Tests** | `frontend/flutter/apps/desktop/test/desktop_settings_test.dart` | MODIFY | Widget tests for 4-state model loading, STILL_LOADING, and manual refresh. |
| **Flutter Desktop Tests** | `frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart` | MODIFY | 16 unit tests for coordinated shutdown, future coalescing, child tracking, and fail-closed timeout fallbacks. |
| **Flutter Desktop Tests** | `frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart` | MODIFY | 25 unit tests for handle-bound termination, provenance, pipeline cleanliness, and partial termination. |
| **Flutter Desktop Tests** | `frontend/flutter/apps/desktop/test/windows_runtime_supervision_acceptance_test.dart` | MODIFY | 9 end-to-end Windows acceptance scenarios (A through I) testing live process handles, loopback shutdown, foreign child preservation, and partial termination. |
| **Documentation** | `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md` | MODIFY | Documented PC-HOST-005 architecture, shutdown endpoints, and supervisor. |
| **Documentation** | `docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md` | MODIFY | Documented host admin security model and loopback secret store. |
| **Documentation** | `docs/04_Architecture/04_Infrastructure/runtime-and-models.md` | MODIFY | Documented strict lock ownership, router cleanup, and model status sync. |
| **Documentation** | `docs/02_Planning/00_Master/DELIVERY_INDEX.md` | MODIFY | Updated PC-HOST-005 tracking to implemented and verified. |
| **Documentation** | `docs/02_Planning/00_Master/WBS.md` | MODIFY | Updated line 61 to implemented and verified on branch. |
| **Documentation** | `docs/02_Planning/00_Master/MASTER_CHECKLIST.md` | MODIFY | Updated readiness matrix and blocker audit for PC-HOST-005. |
| **Documentation** | `docs/02_Planning/00_Master/SPRINT_ROADMAP.md` | MODIFY | Updated Milestone M2 sprint status. |
| **Documentation** | `CHANGELOG.md` | MODIFY | Recorded PC-HOST-005 release notes in past tense under Unreleased. |

---

## 3. Automated Verification Evidence Matrix

All verification was executed and confirmed 100% green across all tiers:

| Verification Suite | Target Directory / Script | Command Executed | Result / Output |
| :--- | :--- | :--- | :--- |
| **Backend Pytest** | `backend/tests/` | `backend\.venv\Scripts\python.exe -m pytest backend\tests` | **674 passed**, 1 warning (0 failures, 0 errors) in ~187s |
| **Flutter Core** | `frontend/flutter/packages/companion_core` | `flutter test` | **23 passed** (0 failures) |
| **Flutter API** | `frontend/flutter/packages/companion_api` | `flutter test` | **81 passed** (0 failures) |
| **Flutter Desktop App** | `frontend/flutter/apps/desktop` | `flutter test` | **310 passed** (0 failures) |
| **Dart Analyzer** | Entire Flutter workspace | `flutter analyze` | **0 issues found** across all packages |
| **OpenAPI Drift Check** | Backend routes vs schema | `python scripts/check_openapi_contract.py --check` | **Clean** (40 routes up to date) |
| **OpenAPI Parity Check** | Dart DTOs vs OpenAPI spec | `python scripts/check_dart_openapi_parity.py` | **40 routes, 24/24 DTOs, 30/19 covered routes** |
| **Web Client Vitest** | `frontend/web/` | `npx vitest run --fileParallelism=false` | **16 test files passed, 248 passed** |
| **Windows Supervision Acceptance** | `frontend/flutter/apps/desktop` | `flutter test test/windows_runtime_supervision_acceptance_test.dart` | **12/12 scenarios passed** (Scenarios A through L) |

---

## 4. Interactive Manual Physical Acceptance Checklist for Chris

The following manual test scenarios can be performed on the physical Windows workstation to verify end-to-end runtime behavior:

### Scenario 1: Desktop Settings "Exit Companion" (Graceful Shutdown)
- [ ] Launch AI Companion Desktop with local runtime running.
- [ ] Navigate to Settings (`gear` icon in navigation rail).
- [ ] Scroll to the bottom of the Settings screen.
- [ ] Locate the **Exit Companion** action button.
- [ ] Click **Exit Companion**.
- [ ] **Verify:** An `Exit Companion` confirmation dialog appears with warning text explaining that background runtime and companion services will terminate.
- [ ] Click **Cancel** in the dialog.
- [ ] **Verify:** The dialog closes and the application and runtime remain operational.
- [ ] Click **Exit Companion** again, then click **Exit Companion** in the dialog.
- [ ] **Verify:** Desktop window closes, and `AI Companion Runtime.exe` / python process terminates cleanly within a few seconds without leaving orphaned `llama.cpp` router processes.

### Scenario 2: System Tray "Exit Companion"
- [ ] Launch AI Companion Desktop and minimize to system tray.
- [ ] Right-click the AI Companion icon in the Windows Taskbar notification tray.
- [ ] Click **Exit Companion** from the context menu.
- [ ] **Verify:** The desktop application brings the confirmation dialog into focus.
- [ ] Confirm exit.
- [ ] **Verify:** Both the Flutter Desktop app and background runtime terminate cleanly.

### Scenario 3: Remote Host Protection
- [ ] In Settings, configure the Runtime Host URL to point to a remote host (or non-loopback IP).
- [ ] Trigger **Exit Companion**.
- [ ] **Verify:** The confirmation dialog informs the user that only the Desktop UI will close and the remote host will remain unaffected. Confirm exit and verify remote server is not sent a shutdown command.

### Scenario 4: Heavy Model Loading (> 5s) & STILL_LOADING Transition
- [ ] In Settings $\rightarrow$ Model Selection, select a heavy GGUF model that takes longer than 5 seconds to load from disk.
- [ ] Click **Select Model**.
- [ ] **Verify:** After 5 seconds of loading, the UI transitions gracefully to `STILL_LOADING` state showing a loading spinner and message: *"Model is still loading in the background. You can continue using the application."*
- [ ] **Verify:** A **Refresh Model Status** button is visible.
- [ ] Wait for loading to finish, or click **Refresh Model Status**.
- [ ] **Verify:** UI transitions to `CONFIRMED_READY` with green status badge.

### Scenario 5: Recovery Dialog on Incomplete Shutdown
- [ ] If runtime termination experiences an unexpected failure or timeout, verify the `showIncompleteShutdownRecoveryDialog` presents the user with actionable options: Force Terminate, Ignore and Exit UI, or View Logs.
