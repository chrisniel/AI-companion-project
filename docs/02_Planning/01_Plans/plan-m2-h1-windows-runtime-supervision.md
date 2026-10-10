# Milestone M2 Batch H1: Windows Runtime Launch & Supervision — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish reliable, non-elevated single-instance launch, authenticated identification, detached background lifecycle ("Quit UI != Stop Runtime"), bounded readiness polling, and safe runtime termination for the Local AI Runtime on Windows.

**Architecture:** A native Windows supervisor in the Flutter desktop client coordinates runtime lifecycle via Win32 process spawning (`ProcessStartMode.detached`), lockfile/mutex concurrency guarding (`runtime.lock`), loopback health polling (`GET /api/v1/health`), DPAPI-authenticated identity verification (`POST /api/v1/auth/verify`), and graceful shutdown orchestration (`POST /api/v1/system/shutdown` and process termination) wired to the System Tray and Settings UI.

**Tech Stack:** Dart 3.13 / Flutter 3.47.1, Win32 Process APIs (`dart:io` Process, `dart:ffi`), Python 3.11 / FastAPI, Windows DPAPI (`Crypt32.dll`), HTTP/REST client.

**Spec:** [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../../04_Architecture/04_Infrastructure/windows-host-and-notifications.md), [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md), [`docs/04_Architecture/decisions/ADR-0003-d2-windows-host-model.md`](../../04_Architecture/decisions/ADR-0003-d2-windows-host-model.md), and [`docs/04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md`](../../04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md).

---

## Global Constraints

- **Non-Elevated Execution:** The runtime executes exclusively under standard user account privileges without requesting UAC elevation prompts (`SYSTEM_BASELINE.md` §3).
- **Loopback Binding Default:** The runtime binds to `127.0.0.1:8000` by default; alien processes occupying the port trigger fail-closed diagnostics without crash loops (`windows-host-and-notifications.md` §6).
- **Invariant "Quit UI != Stop Runtime":** Closing or exiting the Flutter UI client leaves the detached background runtime process running (`windows-host-and-notifications.md` §2.1).
- **Fail-Closed Authenticated Identification:** Public `GET /api/v1/health` (HTTP 200) proves reachability only; the runtime is marked authenticated only after `POST /api/v1/auth/verify` succeeds with the DPAPI-stored token (`DesktopChatController` fail-closed baseline).
- **Standard Storage Root Alignment:** Lockfile and runtime logs reside strictly under canonical user data directories (`%LOCALAPPDATA%\AI Companion\runtime.lock` and `%LOCALAPPDATA%\AI Companion\Logs\runtime.log`) without mutating repository paths (`storage-and-assets.md` §2.1).
- **Explicit Out-of-Scope Boundaries:** Strictly excludes Windows Task Scheduler autostart (`PC-HOST-002`), Action Center native toasts (`PC-HOST-003`), multi-profile DB migration (`PC-IDENTITY-001`), D6 model import (`PC-MODEL-002`), model weights/execution changes, and unrelated UI restyling.

---

## Review Focus

1. **Port 8000 Occupied by an Alien Process:** `GET /api/v1/health` fails, times out, or returns an unrecognized non-companion payload -> supervisor transitions to `RuntimeProcessState.alienPortConflict`, records error diagnostics, and refuses to spawn child processes.
2. **Stale Lockfile from Prior OS Crash or Hard Reboot:** `runtime.lock` exists with a recorded PID, but the PID is dead -> supervisor detects dead PID via OS process probe, records recovery telemetry, safely removes the stale lockfile, and proceeds with launch.
3. **Rapid Concurrent Launch Triggers:** Double-clicking or rapid UI interactions trigger multiple start requests -> supervisor serializes acquisition via mutex/lockfile check; only the first attempt spawns a process, while subsequent callers attach to the active instance.
4. **Runtime Startup Hangs or Exceeds Readiness Timeout:** Spawned runtime process fails to respond to `GET /api/v1/health` within 30 seconds -> supervisor marks `RuntimeProcessState.startupTimeout`, records diagnostic log snippet, cleanly terminates the hung child process, and releases the lockfile.
5. **Graceful Termination Timeout:** "Stop Runtime" requested; authenticated shutdown endpoint called but backend process hangs -> supervisor waits bounded interval (10s), falls back to forceful PID termination (`taskkill /F /PID`), releases the lockfile, and transitions to `RuntimeProcessState.stopped`.

---

## Task Decomposition

### Task 1: Backend Authenticated Shutdown Endpoint & OpenAPI Contract Update

**Files:**
- Modify: `backend/app/api/v1/endpoints/health.py:40-60`
- Modify: `contracts/openapi/openapi.json`
- Modify: `frontend/flutter/packages/companion_api/lib/client/companion_client.dart:180-210`
- Modify: `frontend/flutter/packages/companion_api/lib/dto/system_status_dto.dart:40-60`
- Test: `backend/tests/test_system_shutdown.py`
- Test: `frontend/flutter/packages/companion_api/test/companion_client_shutdown_test.dart`

**Interfaces:**
- Consumes: `verify_token` dependency in `backend/app/api/deps.py`, FastAPI `BackgroundTasks`.
- Produces:
  - Route: `POST /api/v1/system/shutdown` (Protected by bearer token auth).
  - Schema: `ShutdownResponse(status: str, message: str, pid: int)`.
  - Dart method: `Future<ShutdownResponse> CompanionClient.shutdownRuntime()`.

- [ ] **Step 1: Write failing backend test for authenticated shutdown endpoint**

```python
# backend/tests/test_system_shutdown.py
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_shutdown_endpoint_requires_auth(client: AsyncClient):
    response = await client.post("/api/v1/system/shutdown")
    assert response.status_code == 401

@pytest.mark.asyncio
async def test_shutdown_endpoint_succeeds_with_auth(authenticated_client: AsyncClient):
    response = await authenticated_client.post("/api/v1/system/shutdown")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "shutting_down"
    assert "pid" in data
```

- [ ] **Step 2: Run test to verify it fails**

Run: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_system_shutdown.py -v`
Expected: FAIL with 404 Not Found.

- [ ] **Step 3: Implement `POST /api/v1/system/shutdown` in `backend/app/api/v1/endpoints/health.py`**

Define `ShutdownResponse(BaseModel)` and route `POST /system/shutdown` under `system_router` (protected by `verify_token`). Schedule graceful server termination via `asyncio.get_running_loop().call_later(0.5, ...)` or background task sending `signal.SIGINT` to the current process. Regenerate `contracts/openapi/openapi.json`. Add `ShutdownResponse` DTO and `CompanionClient.shutdownRuntime()` in `companion_api`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_system_shutdown.py -v`
Run: `dart test frontend/flutter/packages/companion_api/test/companion_client_shutdown_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit task deliverable**

```bash
git add backend/app/api/v1/endpoints/health.py backend/tests/test_system_shutdown.py contracts/openapi/openapi.json frontend/flutter/packages/companion_api/lib/ frontend/flutter/packages/companion_api/test/
git commit -m "feat(backend): add authenticated runtime shutdown endpoint"
```

---

### Task 2: Runtime Process State Model & Lockfile Data Types (`companion_core`)

**Files:**
- Create: `frontend/flutter/packages/companion_core/lib/platform/runtime_process_state.dart`
- Create: `frontend/flutter/packages/companion_core/lib/platform/runtime_lockfile.dart`
- Modify: `frontend/flutter/packages/companion_core/lib/companion_core.dart`
- Test: `frontend/flutter/packages/companion_core/test/runtime_process_state_test.dart`
- Test: `frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart`

**Interfaces:**
- Consumes: Pure Dart core utilities.
- Produces:
  - Enum `RuntimeProcessState { dormant, starting, readyAndAuthenticated, reachableUnauthenticated, alienPortConflict, startupTimeout, stopping, stopped }`.
  - Class `RuntimeLockfileData(pid: int, port: int, startedAt: DateTime, executablePath: String?)` with `toJson()`, `fromJson()`, `toRawJson()`, `fromRawJson()`.

- [ ] **Step 1: Write failing tests for RuntimeProcessState and RuntimeLockfileData**

```dart
// frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart
import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('RuntimeLockfileData', () {
    test('serializes and deserializes valid JSON accurately', () {
      final now = DateTime.utc(2026, 10, 10, 12, 0, 0);
      final lockfile = RuntimeLockfileData(
        pid: 12345,
        port: 8000,
        startedAt: now,
        executablePath: r'D:\AI Companion\python.exe',
      );
      final jsonStr = lockfile.toRawJson();
      final restored = RuntimeLockfileData.fromRawJson(jsonStr);
      expect(restored.pid, equals(12345));
      expect(restored.port, equals(8000));
      expect(restored.startedAt, equals(now));
      expect(restored.executablePath, equals(r'D:\AI Companion\python.exe'));
    });

    test('fails closed on corrupt or missing fields', () {
      expect(() => RuntimeLockfileData.fromRawJson('{}'), throwsA(isA<FormatException>()));
      expect(() => RuntimeLockfileData.fromRawJson('invalid json'), throwsA(isA<FormatException>()));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart`
Expected: FAIL with compilation error (classes not found).

- [ ] **Step 3: Implement `RuntimeProcessState` and `RuntimeLockfileData` in `companion_core`**

Implement `RuntimeProcessState` enum with helper getters (`isOperational`, `canSendMessages`, `canStop`). Implement `RuntimeLockfileData` with strict JSON validation, schema versioning (`schema_version: 1`), and round-trip parsing. Export both in `companion_core.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart`
Run: `dart test frontend/flutter/packages/companion_core/test/runtime_process_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit task deliverable**

```bash
git add frontend/flutter/packages/companion_core/
git commit -m "feat(core): add runtime process state machine and lockfile models"
```

---

### Task 3: Native Windows Runtime Process Supervisor (`apps/desktop/lib/platform/`)

**Files:**
- Create: `frontend/flutter/apps/desktop/lib/platform/windows_runtime_process_supervisor.dart`
- Create: `frontend/flutter/apps/desktop/lib/platform/process_launcher_adapter.dart`
- Test: `frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart`

**Interfaces:**
- Consumes: `RuntimeLockfileData`, `ProcessLauncherAdapter`.
- Produces:
  - `WindowsRuntimeProcessSupervisor`:
    - `Future<bool> isPortListening(String host, int port)`
    - `Future<RuntimeLockfileData?> readLockfile(File lockfile)`
    - `Future<void> writeLockfile(File lockfile, RuntimeLockfileData data)`
    - `Future<void> removeLockfile(File lockfile)`
    - `Future<bool> isPidAlive(int pid)`
    - `Future<int> spawnDetachedRuntime({required String executable, required List<String> args, required String workingDirectory, String? logPath})`
    - `Future<bool> killProcess(int pid, {bool force = false})`

- [ ] **Step 1: Write failing tests for WindowsRuntimeProcessSupervisor**

```dart
// frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart
import 'dart:io';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('WindowsRuntimeProcessSupervisor', () {
    test('detects dead PID and cleans up stale lockfile', () async {
      final tempDir = await Directory.systemTemp.createTemp('lockfile_test_');
      final lockfile = File('${tempDir.path}\\runtime.lock');
      final deadData = RuntimeLockfileData(
        pid: 99999999, // Unused PID
        port: 8000,
        startedAt: DateTime.now().toUtc(),
      );
      await lockfile.writeAsString(deadData.toRawJson());

      final supervisor = WindowsRuntimeProcessSupervisor();
      final isAlive = await supervisor.isPidAlive(deadData.pid);
      expect(isAlive, isFalse);

      await supervisor.removeLockfile(lockfile);
      expect(await lockfile.exists(), isFalse);
      await tempDir.delete(recursive: true);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart`
Expected: FAIL with compilation error (classes not found).

- [ ] **Step 3: Implement `WindowsRuntimeProcessSupervisor` and `ProcessLauncherAdapter`**

Implement `ProcessLauncherAdapter` interface wrapping `Process.start` to allow mock injection in tests. Implement `WindowsRuntimeProcessSupervisor` using `Socket.connect` with 500ms timeout for port check, `tasklist /FI "PID eq <pid>"` or `Process.killPid(pid, 0)` on Windows for PID liveness, atomic file operations for lockfile, and `Process.start(..., mode: ProcessStartMode.detached)` for detached spawn. Implement `killProcess(pid, {bool force})` using `taskkill /PID <pid>` (graceful) and `taskkill /F /PID <pid>` (forceful).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit task deliverable**

```bash
git add frontend/flutter/apps/desktop/lib/platform/ frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart
git commit -m "feat(desktop): implement Windows native process supervisor and lockfile manager"
```

---

### Task 4: Desktop Runtime Coordinator with Readiness Polling & Auth Verification

**Files:**
- Create: `frontend/flutter/apps/desktop/lib/coordinator/desktop_runtime_coordinator.dart`
- Test: `frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart`

**Interfaces:**
- Consumes: `WindowsRuntimeProcessSupervisor`, `CompanionClient`, `CredentialStore`.
- Produces:
  - `DesktopRuntimeCoordinator`:
    - `Stream<RuntimeProcessState> get stateStream`
    - `RuntimeProcessState get currentState`
    - `Future<RuntimeProcessState> ensureRuntimeReady({Duration timeout = const Duration(seconds: 30)})`
    - `Future<bool> stopRuntime({Duration timeout = const Duration(seconds: 10)})`
    - `RuntimeLockfileData? get activeRuntimeInfo`

- [ ] **Step 1: Write failing tests for DesktopRuntimeCoordinator**

```dart
// frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart
import 'package:ai_companion_desktop/coordinator/desktop_runtime_coordinator.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('DesktopRuntimeCoordinator', () {
    test('transitions to readyAndAuthenticated when health 200 and auth verify 200', () async {
      // Setup mock supervisor and client with valid credentials
      // Verify coordinator emits starting -> readyAndAuthenticated
    });

    test('transitions to reachableUnauthenticated when health 200 but token missing/invalid', () async {
      // Setup mock supervisor and client with 401 on auth verify
      // Verify coordinator emits reachableUnauthenticated and does NOT enable sending
    });

    test('transitions to alienPortConflict when port listening but health check fails', () async {
      // Setup mock supervisor where port is busy but /health returns 404 or connection refused
      // Verify coordinator halts and emits alienPortConflict
    });

    test('transitions to startupTimeout when spawned process does not become healthy within timeout', () async {
      // Setup mock supervisor where process spawns but health never returns 200
      // Verify coordinator emits startupTimeout, kills process, and cleans lockfile
    });

    test('stopRuntime calls authenticated shutdown endpoint then kills process and releases lock', () async {
      // Setup active runtime
      // Call stopRuntime() -> verify shutdownRuntime() called -> verify lockfile removed -> state stopped
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart`
Expected: FAIL with compilation error (class not found).

- [ ] **Step 3: Implement `DesktopRuntimeCoordinator` in `apps/desktop/lib/coordinator/`**

Implement full lifecycle state machine:
1. `ensureRuntimeReady`:
   - Inspect port and lockfile.
   - If port occupied: probe `GET /api/v1/health`. If healthy companion, probe `POST /api/v1/auth/verify`. If auth succeeds, return `readyAndAuthenticated`. If auth fails, return `reachableUnauthenticated`. If health fails, return `alienPortConflict`.
   - If port free: resolve Python runtime path (from config/settings/default venv), acquire lockfile, spawn detached process.
   - Poll `GET /api/v1/health` with backoff (500ms initial, capped at 2s interval) up to 30s timeout.
   - Upon health success, verify auth token. Transition to `readyAndAuthenticated` or `reachableUnauthenticated`.
   - If timeout expires, kill spawned PID, delete lockfile, and transition to `startupTimeout`.
2. `stopRuntime`:
   - Transition to `stopping`.
   - If authenticated, call `companionClient.shutdownRuntime()`.
   - Poll PID liveness up to 10s timeout.
   - If PID still alive after timeout, call supervisor `killProcess(pid, force: true)`.
   - Release lockfile and transition to `stopped`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit task deliverable**

```bash
git add frontend/flutter/apps/desktop/lib/coordinator/ frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart
git commit -m "feat(desktop): implement desktop runtime coordinator with readiness polling and auth verification"
```

---

### Task 5: Lifecycle & UI Wiring: System Tray "Stop Runtime" & Settings Supervision Card

**Files:**
- Modify: `frontend/flutter/apps/desktop/lib/lifecycle/desktop_lifecycle_coordinator.dart:95-120`
- Modify: `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`
- Modify: `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart`
- Test: `frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_stop_test.dart`
- Test: `frontend/flutter/apps/desktop/test/desktop_settings_runtime_supervision_test.dart`

**Interfaces:**
- Consumes: `DesktopRuntimeCoordinator`, `DesktopLifecycleCoordinator`, `DesktopSettingsController`.
- Produces:
  - System tray menu item `key: 'stop'` enabled when runtime is active (`disabled: false`); clicking it invokes `coordinator.stopRuntime()`.
  - System tray menu item `key: 'status'` displays dynamic label (`Runtime: Active (PID ...)`, `Runtime: Stopped`).
  - Closing window (`onWindowClose`) or tray *Exit Companion* (`key: 'exit'`) strictly terminates UI only, leaving detached runtime running ("Quit UI != Stop Runtime").
  - Settings screen: Recessed diagnostic card for Runtime Supervision with status badge, PID, Port, Lockfile path, and Start/Stop/Restart buttons.

- [ ] **Step 1: Write failing tests for System Tray stop action and Settings supervision card**

```dart
// frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_stop_test.dart
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:test/test.dart';

void main() {
  test('tray menu stop action invokes stopRuntime callback when active', () async {
    // Verify clicking 'stop' in tray triggers coordinator.stopRuntime()
  });

  test('tray menu exit action terminates UI shell only, preserving independent runtime', () async {
    // Verify clicking 'exit' disposes window/tray without calling stopRuntime()
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_stop_test.dart`
Expected: FAIL.

- [ ] **Step 3: Update `DesktopLifecycleCoordinator`, `DesktopSettingsController`, and `SettingsScreen`**

In `DesktopLifecycleCoordinator`:
- Add `onStopRuntimeRequested` callback and `updateRuntimeStatus(RuntimeProcessState state, int? pid)`.
- Enable tray `MenuItem(key: 'stop', label: 'Stop Runtime', disabled: !canStop)`.
- Handle `menuItem.key == 'stop'` in `onTrayMenuItemClick`.
In `DesktopSettingsController`:
- Expose runtime coordinator state, PID, port, and start/stop methods.
In `SettingsScreen`:
- Add "Runtime Process Supervision" section under Diagnostics with live status chip, process PID, lockfile status, and Neumorphic Start/Stop buttons.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_stop_test.dart`
Run: `flutter test frontend/flutter/apps/desktop/test/desktop_settings_runtime_supervision_test.dart`
Run: `flutter test frontend/flutter/apps/desktop/test/` (All desktop tests green)
Expected: PASS.

- [ ] **Step 5: Commit task deliverable**

```bash
git add frontend/flutter/apps/desktop/lib/lifecycle/ frontend/flutter/apps/desktop/lib/controllers/ frontend/flutter/apps/desktop/lib/screens/ frontend/flutter/apps/desktop/test/
git commit -m "feat(desktop): wire runtime stop to system tray and add settings supervision controls"
```

---

### Task 6: Contract Parity, Static Analysis & Documentation Verification

**Files:**
- Modify: `scripts/check_dart_openapi_parity.py` (register `/api/v1/system/shutdown`)
- Run: `python scripts/check_dart_openapi_parity.py`
- Run: `dart analyze .` in `frontend/flutter/`
- Run: `flutter test` across all flutter packages
- Run: `pytest` across backend tests
- Run: `git diff --check`

- [ ] **Step 1: Update `scripts/check_dart_openapi_parity.py`**

Register `("POST", "/api/v1/system/shutdown"): ("shutdownRuntime", "/api/v1/system/shutdown")` in `M2_COVERED_ROUTES` and verify route contract parity.

- [ ] **Step 2: Run verification scripts and test suites**

Run: `backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py`
Run: `dart analyze frontend/flutter/`
Run: `flutter test frontend/flutter/apps/desktop`
Run: `dart test frontend/flutter/packages/companion_core`
Run: `dart test frontend/flutter/packages/companion_api`
Run: `flutter test frontend/flutter/packages/companion_design`
Run: `backend/.venv/Scripts/python.exe -m pytest backend/tests`
Run: `git diff --check`
Expected: All suites PASS with 0 errors and 0 lint warnings.

- [ ] **Step 3: Commit verification and parity update**

```bash
git add scripts/check_dart_openapi_parity.py
git commit -m "chore(contracts): update Dart OpenAPI parity check for runtime shutdown route"
```

---

## Acceptance Criteria & Mechanical Verification Commands

### Automated Verification Gates

1. **Backend Tests:**
   ```powershell
   backend/.venv/Scripts/python.exe -m pytest backend/tests/test_system_shutdown.py backend/tests/test_model_selection_regression.py -v
   ```
2. **Flutter Desktop & Package Tests:**
   ```powershell
   flutter test frontend/flutter/apps/desktop
   dart test frontend/flutter/packages/companion_core
   dart test frontend/flutter/packages/companion_api
   flutter test frontend/flutter/packages/companion_design
   ```
3. **OpenAPI 3.1 Contract Parity:**
   ```powershell
   backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py
   ```
4. **Dart Static Analysis:**
   ```powershell
   dart analyze frontend/flutter/
   ```
5. **Cumulative Diff & Docs Integrity:**
   ```powershell
   git diff --check origin/develop...HEAD -- docs/ '*.md'
   ```

### Manual Windows Verification Steps

1. **Single-Instance Enforcement:** Start the desktop client -> verify backend process launches detached in background -> launch client a second time -> verify second client binds to the existing backend instance without spawning duplicate processes.
2. **"Quit UI != Stop Runtime" Verification:** Close the desktop window to tray -> verify backend continues running -> select *Exit Companion* from tray -> verify Flutter UI exits while backend process remains running at `127.0.0.1:8000` (verified via `netstat -ano | findstr 8000`).
3. **Explicit "Stop Runtime" Verification:** From System Tray or Settings screen, select *Stop Runtime* -> verify backend process terminates cleanly -> verify `%LOCALAPPDATA%\AI Companion\runtime.lock` is removed -> verify port 8000 is released.
4. **Alien Port Conflict Handling:** Run a dummy HTTP server on port 8000 -> launch Flutter client -> verify client surfaces `PORT_CONFLICT_ALIEN_PROCESS` diagnostic badge without crashing or hanging.
