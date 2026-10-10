# Milestone M2 Batch H1: Windows Runtime Launch, Attach & Supervision — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish reliable, non-elevated single-instance startup, safe local attach, cross-process concurrency synchronization, detached background persistence ("Quit UI != Stop Runtime"), bounded readiness polling, and unambiguous authentication separation for the Local AI Runtime on Windows.

**Architecture:** A native Windows supervisor in the Flutter desktop client coordinates local runtime lifecycle using kernel-enforced file locking (`RandomAccessFile.lock`), detached process creation (`ProcessStartMode.detached`) with redirected logs, loopback port/health probing (`GET /api/v1/health`), DPAPI-backed identity verification (`POST /api/v1/auth/verify`), and safe PID provenance validation. Host-level termination (Stop/Restart) is strictly deferred until dedicated local host-administration controls are approved.

**Tech Stack:** Dart 3.13 / Flutter 3.47.1, Win32 Process APIs (`dart:io` Process/RandomAccessFile), Windows DPAPI (`Crypt32.dll`), HTTP/REST client.

**Spec:** [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../../04_Architecture/04_Infrastructure/windows-host-and-notifications.md), [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md), [`docs/04_Architecture/decisions/ADR-0003-d2-windows-host-model.md`](../../04_Architecture/decisions/ADR-0003-d2-windows-host-model.md), [`docs/04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md`](../../04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md), and [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](../../04_Architecture/02_Data_and_Security/authentication-and-secrets.md).

---

## Global Constraints

- **Non-Elevated Execution:** The runtime executes exclusively under standard user account privileges without requesting UAC elevation prompts (`SYSTEM_BASELINE.md` §3).
- **Loopback Binding Default:** Local runtime management applies strictly to loopback targets (`127.0.0.1` / `localhost`). Remote host URLs strictly disable local process management (`windows-host-and-notifications.md` §6).
- **Invariant "Quit UI != Stop Runtime":** Closing or exiting the Flutter UI client leaves the detached background runtime process running (`windows-host-and-notifications.md` §2.1).
- **Process Safety & Anti-Kill Invariant:** Never kill an unknown process or trust a PID solely because it appears in a lockfile. If an unverified process occupies the port or lockfile, fail closed with typed diagnostics without process termination.
- **Authentication Separation:** Public `GET /api/v1/health` (HTTP 200) proves reachability only; the client is marked authenticated only after `POST /api/v1/auth/verify` succeeds with DPAPI credentials.
- **Host Administration Boundary:** Ordinary client API tokens must not authorize host termination. Host shutdown/restart is deferred from H1 to dedicated host administration design.
- **Storage Root Alignment:** Lockfile and logs reside strictly in canonical user directories (`%LOCALAPPDATA%\AI Companion\runtime.lock` and `%LOCALAPPDATA%\AI Companion\Logs\runtime.log`) without mutating repository paths (`storage-and-assets.md` §2.1).
- **Explicit Out-of-Scope Boundaries:** Strictly excludes Task Scheduler autostart (`PC-HOST-002`), Action Center toasts (`PC-HOST-003`), multi-profile DB migration (`PC-IDENTITY-001`), D6 model import (`PC-MODEL-002`), model weights/execution changes, and unrelated UI polish.

---

## Review Focus

1. **Port 8000 Occupied by an Alien Process:** `GET /api/v1/health` fails, times out, or returns an unrecognized non-companion payload -> supervisor transitions to `alienPortConflict`, records error diagnostics, and refuses to spawn child processes or kill the alien process.
2. **Stale Lockfile with Dead or Recycled PID:** `runtime.lock` exists with a recorded PID, but the PID is either dead or points to a non-companion executable -> supervisor detects invalid provenance via OS query, safely removes the stale lockfile without killing the foreign process, and proceeds with launch.
3. **Rapid Concurrent Launch Triggers:** Multiple simultaneous client launches or double-clicks -> kernel-level atomic lock (`RandomAccessFile.lock(FileLock.exclusive)`) serializes startup; exactly one launch spawns a process, while subsequent callers attach to the healthy instance.
4. **Runtime Startup Hangs or Exceeds Readiness Timeout:** Spawned runtime process fails to respond to `GET /api/v1/health` within 30 seconds -> supervisor marks `startupTimeout`, records diagnostic log snippet, and notifies the user without corrupting system state.
5. **Remote Host URL Configuration:** Client is configured to connect to a LAN or Tailscale companion URL -> supervisor disables local process management (`remoteManaged`), bypassing local lockfile and process spawning.

---

## Architectural Decisions & Alternatives Considered

| Decision Area | Chosen Architecture | Rejected Alternative & Rationale |
| :--- | :--- | :--- |
| **Host Termination** | **Deferred to follow-on host admin design.** H1 focuses on launch, attach, and supervision. Tray "Stop Runtime" remains disabled / informational ("Managed by Host"). | **Rejected: `POST /api/v1/system/shutdown` with bearer auth.** Ordinary pairing credentials must not authorize host termination. Exposing shutdown over API violates host-admin trust boundary (`authentication-and-secrets.md`). |
| **Concurrency Guard** | **OS-level kernel file locking** via `RandomAccessFile.lock(FileLock.exclusive)` on `runtime.lock`. | **Rejected: Simple file existence checks (`File.existsSync`).** Subject to TOCTOU race conditions during concurrent launches. Kernel lock guarantees mutual exclusion across processes. |
| **PID Validation** | **Two-factor PID validation:** verify port responsiveness AND executable image name before trusting process identity. | **Rejected: Blind PID killing (`taskkill /PID <pid>`).** Windows aggressively recycles PIDs. Trusting a raw PID from disk could kill an innocent OS or user process. |
| **Process Detachment** | **`ProcessStartMode.detached` with redirected standard I/O** to `%LOCALAPPDATA%\AI Companion\Logs\runtime.log`. | **Rejected: Inherited I/O pipes.** Orphaned console pipe handles deadlock Windows console subsystems when the parent Flutter process exits. |
| **Remote URLs** | **Local supervision mode gating:** Loopback enables local supervisor; non-loopback enters `remoteManaged` mode. | **Rejected: Unconditional local spawn.** Spawning local background processes when the user intends to connect to a remote companion wastes resources and causes confusion. |

---

## Task Decomposition

### Task 1: Runtime Process State Model & Lockfile Descriptor (`companion_core`)

**Files:**
- Create: `frontend/flutter/packages/companion_core/lib/platform/runtime_process_state.dart`
- Create: `frontend/flutter/packages/companion_core/lib/platform/runtime_lockfile.dart`
- Modify: `frontend/flutter/packages/companion_core/lib/companion_core.dart`
- Test: `frontend/flutter/packages/companion_core/test/runtime_process_state_test.dart`
- Test: `frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart`

**Interfaces:**
- Consumes: Pure Dart core utilities.
- Produces:
  - Enum `RuntimeProcessState { dormant, launching, readyAndAuthenticated, reachableUnauthenticated, alienPortConflict, startupTimeout, remoteManaged }` with helper predicates (`isOperational`, `isLocalManaged`, `canSendMessages`).
  - Class `RuntimeLockfileData(schemaVersion: int, instanceId: String, pid: int, port: int, startedAt: DateTime, executablePath: String)` with `toRawJson()` and `fromRawJson()`.

- [ ] **Step 1: Write failing tests for RuntimeProcessState and RuntimeLockfileData**

```dart
// frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart
import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('RuntimeLockfileData', () {
    test('serializes and deserializes valid descriptor accurately', () {
      final now = DateTime.utc(2026, 10, 10, 12, 0, 0);
      final lockfile = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: '550e8400-e29b-41d4-a716-446655440000',
        pid: 12345,
        port: 8000,
        startedAt: now,
        executablePath: r'D:\AI Companion\backend\.venv\Scripts\python.exe',
      );
      final jsonStr = lockfile.toRawJson();
      final restored = RuntimeLockfileData.fromRawJson(jsonStr);
      expect(restored.schemaVersion, equals(1));
      expect(restored.instanceId, equals('550e8400-e29b-41d4-a716-446655440000'));
      expect(restored.pid, equals(12345));
      expect(restored.port, equals(8000));
      expect(restored.startedAt, equals(now));
      expect(restored.executablePath, equals(r'D:\AI Companion\backend\.venv\Scripts\python.exe'));
    });

    test('fails closed on corrupt, partial, or missing descriptor fields', () {
      expect(() => RuntimeLockfileData.fromRawJson('{}'), throwsA(isA<FormatException>()));
      expect(() => RuntimeLockfileData.fromRawJson('{"schema_version": 2}'), throwsA(isA<FormatException>()));
      expect(() => RuntimeLockfileData.fromRawJson('not-json'), throwsA(isA<FormatException>()));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart`
Expected: FAIL with compilation error (classes not found).

- [ ] **Step 3: Implement `RuntimeProcessState` and `RuntimeLockfileData` in `companion_core`**

Implement `RuntimeProcessState` enum with clear state definitions and helpers. Implement `RuntimeLockfileData` with strict schema validation (`schemaVersion == 1`), ISO-8601 UTC timestamp parsing, and fail-closed error handling. Export both from `companion_core.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart`
Run: `dart test frontend/flutter/packages/companion_core/test/runtime_process_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify git status and commit**

Stage: `frontend/flutter/packages/companion_core/`
Commit: `feat(core): implement runtime process state model and lockfile descriptor`

---

### Task 2: Native Windows Runtime Process Supervisor with Kernel Locking (`apps/desktop/lib/platform/`)

**Files:**
- Create: `frontend/flutter/apps/desktop/lib/platform/windows_runtime_process_supervisor.dart`
- Create: `frontend/flutter/apps/desktop/lib/platform/process_launcher_adapter.dart`
- Test: `frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart`

**Interfaces:**
- Consumes: `RuntimeLockfileData`, `ProcessLauncherAdapter`.
- Produces:
  - `WindowsRuntimeProcessSupervisor`:
    - `Future<bool> isPortListening(String host, int port, {Duration timeout})`
    - `Future<RandomAccessFile?> tryAcquireStartupLock(File lockfile)`
    - `Future<void> releaseStartupLock(RandomAccessFile lockHandle)`
    - `Future<RuntimeLockfileData?> readLockfile(File lockfile)`
    - `Future<void> writeLockfile(File lockfile, RuntimeLockfileData data)`
    - `Future<void> removeLockfile(File lockfile)`
    - `Future<bool> isProcessActiveAndMatching(int pid, {required String expectedExecutable})`
    - `Future<int> spawnDetachedRuntime({required String executable, required List<String> args, required String workingDirectory, required String logFilePath})`

- [ ] **Step 1: Write failing tests for WindowsRuntimeProcessSupervisor**

```dart
// frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart
import 'dart:io';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('WindowsRuntimeProcessSupervisor', () {
    test('acquires exclusive file lock and blocks concurrent acquisition', () async {
      final tempDir = await Directory.systemTemp.createTemp('lock_test_');
      final lockFile = File('${tempDir.path}\\runtime.lock');
      final supervisor = WindowsRuntimeProcessSupervisor();

      final handle1 = await supervisor.tryAcquireStartupLock(lockFile);
      expect(handle1, isNotNull);

      // Second attempt on locked file fails closed
      final handle2 = await supervisor.tryAcquireStartupLock(lockFile);
      expect(handle2, isNull);

      await supervisor.releaseStartupLock(handle1!);
      await tempDir.delete(recursive: true);
    });

    test('refuses to kill or touch dead/unverified PID during stale lock recovery', () async {
      final tempDir = await Directory.systemTemp.createTemp('stale_test_');
      final lockFile = File('${tempDir.path}\\runtime.lock');
      final supervisor = WindowsRuntimeProcessSupervisor();

      // Write stale descriptor pointing to non-existent or foreign PID
      final data = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'test-instance',
        pid: 99999999,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\Windows\System32\notepad.exe', // foreign image
      );
      await supervisor.writeLockfile(lockFile, data);

      final isMatching = await supervisor.isProcessActiveAndMatching(
        data.pid,
        expectedExecutable: 'python.exe',
      );
      expect(isMatching, isFalse);

      // Safe recovery cleans lockfile without killing the foreign process
      await supervisor.removeLockfile(lockFile);
      expect(await lockFile.exists(), isFalse);
      await tempDir.delete(recursive: true);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart`
Expected: FAIL with compilation error (classes not found).

- [ ] **Step 3: Implement `WindowsRuntimeProcessSupervisor` and `ProcessLauncherAdapter`**

Implement `ProcessLauncherAdapter` wrapping `Process.start` to allow mock injection. In `WindowsRuntimeProcessSupervisor`:
- `tryAcquireStartupLock`: opens file with `FileMode.write` and calls `lock(FileLock.exclusive)`. Catches `FileSystemException` and returns `null` on contention.
- `isPortListening`: tests loopback port connection with a bounded 500ms timeout via `Socket.connect`.
- `isProcessActiveAndMatching`: queries Windows process table via `tasklist /FI "PID eq <pid>" /FO CSV /NH` or Win32 process probe; checks that image name matches expected executable. If PID is dead or image does not match, returns `false`. Never kills any process.
- `spawnDetachedRuntime`: ensures log directory exists (`%LOCALAPPDATA%\AI Companion\Logs`), opens log file for append, launches child process with `mode: ProcessStartMode.detached`, and redirects stdout/stderr.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify git status and commit**

Stage: `frontend/flutter/apps/desktop/lib/platform/` and test file.
Commit: `feat(desktop): implement Windows native process supervisor with kernel locking and safe PID provenance`

---

### Task 3: Desktop Runtime Coordinator with Readiness Polling & Auth Separation (`apps/desktop/lib/coordinator/`)

**Files:**
- Create: `frontend/flutter/apps/desktop/lib/coordinator/desktop_runtime_coordinator.dart`
- Test: `frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart`

**Interfaces:**
- Consumes: `WindowsRuntimeProcessSupervisor`, `CompanionClient`, `CredentialStore`.
- Produces:
  - `DesktopRuntimeCoordinator`:
    - `Stream<RuntimeProcessState> get stateStream`
    - `RuntimeProcessState get currentState`
    - `RuntimeLockfileData? get activeRuntimeInfo`
    - `bool get isLocalLoopback`
    - `Future<RuntimeProcessState> ensureRuntimeReady({Duration timeout = const Duration(seconds: 30)})`

- [ ] **Step 1: Write failing tests for DesktopRuntimeCoordinator**

```dart
// frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart
import 'package:ai_companion_desktop/coordinator/desktop_runtime_coordinator.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('DesktopRuntimeCoordinator', () {
    test('transitions to remoteManaged when baseUrl is non-loopback and bypasses process spawn', () async {
      // Setup coordinator with remote baseUrl (e.g. https://companion.lan:8000)
      // Call ensureRuntimeReady() -> verifies local lockfile and spawn are skipped -> state is remoteManaged
    });

    test('attaches to existing running instance without spawning second process', () async {
      // Setup supervisor with port 8000 listening and health 200
      // Call ensureRuntimeReady() -> verifies spawnDetachedRuntime was NOT called -> state readyAndAuthenticated
    });

    test('transitions to reachableUnauthenticated when health 200 but auth verify returns 401', () async {
      // Setup supervisor with port 8000 listening, health 200, but client.verifyAuth() throws 401
      // Call ensureRuntimeReady() -> verifies state is reachableUnauthenticated and sending remains disabled
    });

    test('transitions to alienPortConflict when port is listening but /health returns non-companion response', () async {
      // Setup supervisor where port 8000 connects but /health returns 404 or connection reset
      // Call ensureRuntimeReady() -> verifies state is alienPortConflict and no process is spawned or killed
    });

    test('transitions to startupTimeout when spawned process does not become healthy within 30s', () async {
      // Setup supervisor where process spawns but /health never responds 200 within timeout
      // Call ensureRuntimeReady() -> verifies state is startupTimeout
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart`
Expected: FAIL with compilation error (class not found).

- [ ] **Step 3: Implement `DesktopRuntimeCoordinator` in `apps/desktop/lib/coordinator/`**

Implement the coordinator:
1. `isLocalLoopback`: checks if `baseUrl` host is `127.0.0.1` or `localhost`. If false, set `remoteManaged` and verify network reachability/auth directly without touching local OS processes.
2. If loopback:
   - Check if port 8000 is listening.
   - If listening: probe `GET /api/v1/health`. If healthy companion, probe `POST /api/v1/auth/verify`. If auth 200 -> `readyAndAuthenticated`. If auth 401 -> `reachableUnauthenticated`. If health fails -> `alienPortConflict` (fail closed, no spawn, no kill).
   - If port is free: check for stale `runtime.lock`. If lockfile exists, verify PID. If dead or foreign image, clean up stale lockfile.
   - Acquire kernel lock (`tryAcquireStartupLock`). If locked by peer, wait up to 2s.
   - Spawn detached runtime process with redirected logs. Write new lockfile descriptor with instance UUID. Release startup lock.
   - Poll `GET /api/v1/health` with exponential backoff (500ms initial, capped at 2s interval) up to 30s.
   - Upon health success, verify DPAPI token via `companionClient.verifyAuth()`. Transition to `readyAndAuthenticated` or `reachableUnauthenticated`.
   - If timeout expires, transition to `startupTimeout`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify git status and commit**

Stage: `frontend/flutter/apps/desktop/lib/coordinator/` and test file.
Commit: `feat(desktop): implement desktop runtime coordinator with readiness polling and auth separation`

---

### Task 4: UI & Lifecycle Integration ("Quit UI != Stop Runtime" & Informational Status)

**Files:**
- Modify: `frontend/flutter/apps/desktop/lib/lifecycle/desktop_lifecycle_coordinator.dart:95-125`
- Modify: `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`
- Modify: `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart`
- Test: `frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_supervision_test.dart`
- Test: `frontend/flutter/apps/desktop/test/desktop_settings_runtime_supervision_test.dart`

**Interfaces:**
- Consumes: `DesktopRuntimeCoordinator`, `DesktopLifecycleCoordinator`, `DesktopSettingsController`.
- Produces:
  - System Tray context menu:
    - `key: 'status'`: displays dynamic label (`Runtime: Active (PID 1234)`, `Runtime: Standalone`, `Runtime: Alien Conflict`, `Runtime: Remote`).
    - `key: 'stop'`: disabled with clear label `"Stop Runtime (Managed by Host)"` — explicitly conveying that host termination requires local OS session administration.
    - `key: 'exit'`: remains *Exit Companion* (terminates UI only; leaves detached background runtime running: "Quit UI != Stop Runtime").
  - Settings screen:
    - Recessed diagnostic card for Runtime Supervision: displays supervision mode (Local Loopback vs Remote), connection state badge, PID, port, and lockfile path.

- [ ] **Step 1: Write failing tests for System Tray lifecycle and Settings supervision display**

```dart
// frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_supervision_test.dart
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:test/test.dart';

void main() {
  test('closing window to tray or clicking exit terminates UI only, leaving runtime process running', () async {
    // Verify that handleExitRequested() disposes window and tray adapters
    // without invoking any runtime termination or killing background process
  });

  test('tray menu keeps stop action disabled with host-managed label', () {
    // Verify MenuItem(key: 'stop') is disabled and indicates host management
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_supervision_test.dart`
Expected: FAIL.

- [ ] **Step 3: Update `DesktopLifecycleCoordinator`, `DesktopSettingsController`, and `SettingsScreen`**

In `DesktopLifecycleCoordinator`:
- Add `updateRuntimeStatus(RuntimeProcessState state, int? pid)` updating tray label dynamically.
- Keep `MenuItem(key: 'stop', label: 'Stop Runtime (Managed by Host)', disabled: true)`.
- Ensure `handleExitRequested()` disposes UI resources cleanly while leaving detached runtime untouched.
In `DesktopSettingsController`:
- Expose runtime coordinator state, PID, port, and lockfile path.
In `SettingsScreen`:
- Add "Runtime Process Supervision" section under Diagnostics displaying supervision mode, status chip, PID, and lockfile details.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_supervision_test.dart`
Run: `flutter test frontend/flutter/apps/desktop/test/desktop_settings_runtime_supervision_test.dart`
Run: `flutter test frontend/flutter/apps/desktop/test/` (All desktop tests green)
Expected: PASS.

- [ ] **Step 5: Verify git status and commit**

Stage: `frontend/flutter/apps/desktop/lib/lifecycle/`, `controllers/`, `screens/`, and test files.
Commit: `feat(desktop): wire runtime supervision to system tray and settings diagnostics`

---

### Task 5: External PowerShell Windows Acceptance Harness & Test Matrix Verification

**Files:**
- Create: `scripts/verify_windows_runtime_supervision.ps1`
- Test: Run verification harness covering dormant spawn, attach to existing, UI exit survival, stale lock recovery, and alien port conflict.
- Run full automated test matrix.

**Interfaces:**
- Consumes: Windows PowerShell, compiled Flutter desktop debug executable, backend venv python executable.
- Produces: Reproducible automated Windows acceptance harness validating all 5 empirical lifecycle scenarios.

- [ ] **Step 1: Implement `scripts/verify_windows_runtime_supervision.ps1`**

Script automates:
1. Scenario A: Dormant launch -> spawns runtime -> verifies port 8000 listening -> verifies `runtime.lock` created.
2. Scenario B: Concurrent launch -> second instance attaches to existing running instance without spawning duplicate PID.
3. Scenario C: "Quit UI != Stop Runtime" -> terminates Flutter client -> verifies backend runtime process PID remains alive and port 8000 remains responsive.
4. Scenario D: Stale lock recovery -> creates dummy stale lockfile with dead PID -> runs supervisor -> verifies stale lock removed and runtime spawns cleanly.
5. Scenario E: Alien port conflict -> binds dummy TCP listener on port 8000 -> runs supervisor -> verifies supervisor fails closed with `alienPortConflict` without killing dummy listener.

- [ ] **Step 2: Execute full test matrix and parity checks**

Run: `dart analyze frontend/flutter/`
Run: `flutter test frontend/flutter/apps/desktop`
Run: `dart test frontend/flutter/packages/companion_core`
Run: `dart test frontend/flutter/packages/companion_api`
Run: `flutter test frontend/flutter/packages/companion_design`
Run: `backend/.venv/Scripts/python.exe -m pytest backend/tests`
Run: `backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py`
Run: `git diff --check`
Expected: All suites PASS with 0 errors, 0 lints, and 0 contract parity discrepancies.

- [ ] **Step 3: Commit verification harness**

Stage: `scripts/verify_windows_runtime_supervision.ps1`
Commit: `test(windows): add empirical Windows runtime supervision verification harness`

---

## Acceptance Criteria & Mechanical Verification Commands

### Automated Verification Gates

1. **Flutter Desktop & Package Tests:**
   ```powershell
   flutter test frontend/flutter/apps/desktop
   dart test frontend/flutter/packages/companion_core
   dart test frontend/flutter/packages/companion_api
   flutter test frontend/flutter/packages/companion_design
   ```
2. **Backend Regression Tests:**
   ```powershell
   backend/.venv/Scripts/python.exe -m pytest backend/tests/test_model_selection_regression.py backend/tests/test_llm_router.py -v
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

1. **Single-Instance Enforcement:** Start the desktop client -> verify backend process launches detached in background -> launch client a second time -> verify second client binds to the existing backend instance without duplicate process spawn.
2. **"Quit UI != Stop Runtime" Verification:** Close the desktop window to tray -> verify backend continues running -> select *Exit Companion* from tray -> verify Flutter UI exits while backend process remains running at `127.0.0.1:8000` (verified via `netstat -ano | findstr 8000`).
3. **Alien Port Conflict Handling:** Run a dummy TCP listener on port 8000 -> launch Flutter client -> verify client surfaces `PORT_CONFLICT_ALIEN_PROCESS` diagnostic badge without crashing, hanging, or terminating the foreign listener.
4. **Stale Lock Recovery:** Create a synthetic `runtime.lock` with dead PID 99999999 -> launch Flutter client -> verify supervisor detects dead PID, cleanly removes stale lockfile, and spawns runtime without error.
5. **Remote Host URL Bypass:** Set `HostUrl` to a remote address (e.g. `http://192.168.1.100:8000`) -> launch desktop client -> verify client operates in `remoteManaged` mode without attempting local process spawning or lockfile creation.
