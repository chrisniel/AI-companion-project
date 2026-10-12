# Milestone M2 Batch H1: Windows Runtime Launch, Attach & Supervision — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish reliable, non-elevated single-instance startup, safe local attach, cross-process concurrency synchronization, detached background persistence ("Quit UI != Stop Runtime"), bounded readiness polling, and unambiguous authentication separation for the Local AI Runtime on Windows.

**Architecture:** A native Windows supervisor in the Flutter desktop client coordinates local runtime lifecycle using kernel-enforced file locking (`RandomAccessFile.lock`), double-checked locking after lock acquisition, detached process creation (`ProcessStartMode.detached`) with internal rotating file logging, loopback port/health probing (`GET /api/v1/health`), DPAPI-backed identity verification (`POST /api/v1/auth/verify`), and two-factor process identity validation without process termination. Host-level termination (Stop/Restart) is strictly deferred until dedicated local host-administration controls are approved.

**Tech Stack:** Dart 3.13 / Flutter 3.47.1, Win32 Process APIs (`dart:io` Process/RandomAccessFile), Windows DPAPI (`Crypt32.dll`), HTTP/REST client.

**Spec:** [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../../04_Architecture/04_Infrastructure/windows-host-and-notifications.md), [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md), [`docs/04_Architecture/decisions/ADR-0003-d2-windows-host-model.md`](../../04_Architecture/decisions/ADR-0003-d2-windows-host-model.md), [`docs/04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md`](../../04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md), and [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](../../04_Architecture/02_Data_and_Security/authentication-and-secrets.md).

---

## Global Constraints

- **Non-Elevated Execution:** The runtime executes exclusively under standard user account privileges without requesting UAC elevation prompts (`SYSTEM_BASELINE.md` §3).
- **Loopback Binding Default:** Local runtime management applies strictly to loopback targets (`127.0.0.1` / `localhost`). Remote host URLs strictly disable local process management (`windows-host-and-notifications.md` §6).
- **Separation of Supervision Mode and Connection State:** `SupervisionMode` (localLoopback vs remoteHost) is modeled orthogonally from `RuntimeStatus` (dormant, launching, readyAndAuthenticated, reachableUnauthenticated, unreachable, etc.). Remote connections never conflate remote management with authentication state.
- **Invariant "Quit UI != Stop Runtime":** Closing or exiting the Flutter UI client leaves the detached background runtime process running (`windows-host-and-notifications.md` §2.1).
- **Process Safety & Anti-Kill Invariant:** Never kill an unknown process or trust a PID solely because it appears in a lockfile. If an unverified process occupies the port or lockfile, fail closed with typed diagnostics without process termination.
- **Authentication Separation:** Public `GET /api/v1/health` (HTTP 200) proves reachability only; the client is marked authenticated only after `POST /api/v1/auth/verify` succeeds with DPAPI credentials.
- **Host Administration Boundary:** Ordinary client API tokens must not authorize host termination. Host shutdown/restart is deferred from H1 to dedicated host administration design.
- **Storage Root Alignment:** Lockfile and logs reside strictly in canonical user directories (`%LOCALAPPDATA%\AI Companion\runtime.lock` and `%LOCALAPPDATA%\AI Companion\Logs\runtime.log`) without mutating repository paths (`storage-and-assets.md` §2.1).
- **Explicit Out-of-Scope Boundaries:** Strictly excludes Task Scheduler autostart (`PC-HOST-002`), Action Center toasts (`PC-HOST-003`), multi-profile DB migration (`PC-IDENTITY-001`), D6 model import (`PC-MODEL-002`), model weights/execution changes, and unrelated UI polish.

---

## Review Focus

1. **File Lock Safety & Truncation Prevention:** `runtime.lock` must be opened with `FileMode.append` (never `FileMode.write`, which truncates prior to lock acquisition). The exclusive lock (`RandomAccessFile.lock(FileLock.exclusive)`) must be acquired before any descriptor read/write, descriptor updates must be written through the locked handle (`setPosition(0)`, `truncate(0)`, `writeString(...)`, `flush()`), and locks must be released in `try ... finally` blocks.
2. **Double-Checked Locking & Recheck Under Guard:** Recheck port responsiveness and descriptor/process status immediately after acquiring the lock guard. If another process completed startup while the lock was pending, attach cleanly without duplicate process spawning.
3. **Surviving Unresponsive Process Guard:** If a recorded PID is running but port 8000 is not responding, do not blindly spawn a duplicate process or kill the existing process; transition safely to `processUnresponsive` and fail closed.
4. **Detached Process Logging Independence:** `ProcessStartMode.detached` exposes no stdout/stderr streams. Durable logging is achieved by configuring the runtime process environment (`COMPANION_LOG_FILE`) to log directly to `%LOCALAPPDATA%\AI Companion\Logs\runtime.log` using internal rotating file logging, without shell wrappers (`cmd.exe`), command-line secret exposure, or unmanaged child processes.
5. **Separation of Service Identity vs. OS Process Identity:** Authenticated service identity is verified over HTTP (`GET /health` + `POST /auth/verify`). OS process identity is checked via image provenance query without killing unverified PIDs.
6. **Cross-Process Concurrency Testing & Isolated Acceptance:** Verification requires genuine multi-process locking tests (via helper process) and disposable acceptance testing in `$env:TEMP` on non-default ports without touching user data, models, or live port 8000.

---

## Architectural Decisions & Alternatives Considered

| Decision Area | Chosen Architecture | Rejected Alternative & Rationale |
| :--- | :--- | :--- |
| **Lockfile Open Mode** | **`FileMode.append` with handle locking** and in-handle write (`setPosition(0)` / `truncate(0)` / `writeString`). | **Rejected: `FileMode.write`.** `FileMode.write` truncates file length to zero on Windows *before* the lock can be acquired, corrupting active descriptors during concurrent launches. |
| **Double-Checked Locking** | **Recheck port and process state under lock** before initiating process spawn. | **Rejected: Single check before lock.** A concurrent process could finish starting up while this process waits for the lock; without recheck, a duplicate instance would be spawned. |
| **Detached Logging** | **Direct runtime file logging via environment variable (`COMPANION_LOG_FILE`)** to `%LOCALAPPDATA%\AI Companion\Logs\runtime.log`. | **Rejected: Shell redirection (`cmd.exe /c ... > log`).** Introducing a shell wrapper introduces injection risks, obscures the true Python PID behind a `cmd.exe` parent PID, and leaks shell windows. |
| **Host Termination** | **Deferred to follow-on host admin design.** H1 focuses on launch, attach, and supervision. Tray "Stop Runtime" remains disabled / informational ("Managed by Host"). | **Rejected: `POST /api/v1/system/shutdown` with bearer auth.** Ordinary pairing credentials must not authorize host termination. Exposing shutdown over API violates host-admin trust boundary (`authentication-and-secrets.md`). |
| **PID Validation** | **Two-factor PID validation:** verify port responsiveness AND executable image name before trusting process identity. | **Rejected: Blind PID killing (`taskkill /PID <pid>`).** Windows aggressively recycles PIDs. Trusting a raw PID from disk could kill an innocent OS or user process. |
| **Remote URLs** | **Orthogonal state modeling:** `SupervisionMode` (`localLoopback` vs `remoteHost`) separate from `RuntimeStatus`. | **Rejected: Conflating remote mode with auth state.** Remote hosts can be authenticated, unauthenticated, or unreachable; coupling these into a single flat enum obscures failure modes. |

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
  - Enum `SupervisionMode { localLoopback, remoteHost }`.
  - Enum `RuntimeStatus { dormant, launching, readyAndAuthenticated, reachableUnauthenticated, unreachable, alienPortConflict, startupTimeout, processUnresponsive, executableNotFound }`.
  - Class `RuntimeProcessState`:
    - `final SupervisionMode supervisionMode;`
    - `final RuntimeStatus status;`
    - `final int? pid;`
    - `final int port;`
    - `final String? diagnosticMessage;`
    - Getters: `bool get isOperational => status == RuntimeStatus.readyAndAuthenticated;`, `bool get canSendMessages => isOperational;`, `bool get isLocalSupervised => supervisionMode == SupervisionMode.localLoopback;`.
  - Class `RuntimeLockfileData`:
    - `final int schemaVersion;` (must equal 1)
    - `final String instanceId;` (UUIDv4)
    - `final int pid;`
    - `final int port;`
    - `final DateTime startedAt;` (UTC)
    - `final String executablePath;`
    - `String toRawJson()` and `static RuntimeLockfileData fromRawJson(String source)` (fail-closed validation).

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

    test('fails closed on corrupt, partial, or invalid schema version descriptor', () {
      expect(() => RuntimeLockfileData.fromRawJson('{}'), throwsA(isA<FormatException>()));
      expect(() => RuntimeLockfileData.fromRawJson('{"schema_version": 2}'), throwsA(isA<FormatException>()));
      expect(() => RuntimeLockfileData.fromRawJson('not-json'), throwsA(isA<FormatException>()));
    });
  });

  group('RuntimeProcessState', () {
    test('separates supervision mode from runtime status', () {
      final remoteUnauthenticated = RuntimeProcessState(
        supervisionMode: SupervisionMode.remoteHost,
        status: RuntimeStatus.reachableUnauthenticated,
        port: 8000,
      );
      expect(remoteUnauthenticated.isLocalSupervised, isFalse);
      expect(remoteUnauthenticated.isOperational, isFalse);
      expect(remoteUnauthenticated.canSendMessages, isFalse);

      final localReady = RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.readyAndAuthenticated,
        pid: 1234,
        port: 8000,
      );
      expect(localReady.isLocalSupervised, isTrue);
      expect(localReady.isOperational, isTrue);
      expect(localReady.canSendMessages, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart`
Expected: FAIL with compilation error (classes not found).

- [ ] **Step 3: Implement `RuntimeProcessState` and `RuntimeLockfileData` in `companion_core`**

Implement `SupervisionMode`, `RuntimeStatus`, and `RuntimeProcessState` in `runtime_process_state.dart`. Implement `RuntimeLockfileData` with strict schema validation (`schemaVersion == 1`), ISO-8601 UTC timestamp parsing, and fail-closed error handling in `runtime_lockfile.dart`. Export both from `companion_core.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test frontend/flutter/packages/companion_core/test/runtime_lockfile_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify git status and commit**

Stage: `frontend/flutter/packages/companion_core/`
Commit: `feat(core): implement runtime process state model and lockfile descriptor`

---

### Task 2: Native Windows Runtime Process Supervisor with Kernel Locking & Detached Logging (`apps/desktop/lib/platform/`)

**Files:**
- Create: `frontend/flutter/apps/desktop/lib/platform/windows_runtime_process_supervisor.dart`
- Create: `frontend/flutter/apps/desktop/lib/platform/process_launcher_adapter.dart`
- Test: `frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart`
- Test Helper: `frontend/flutter/apps/desktop/test/helpers/lock_holder_helper.dart`

**Interfaces:**
- Consumes: `RuntimeLockfileData`, `ProcessLauncherAdapter`.
- Produces:
  - `WindowsRuntimeProcessSupervisor`:
    - `Future<bool> isPortListening(String host, int port, {Duration timeout = const Duration(milliseconds: 500)})`
    - `Future<RandomAccessFile?> acquireStartupLock(File lockFile, {Duration timeout = const Duration(seconds: 5)})`
    - `Future<void> releaseStartupLock(RandomAccessFile lockHandle)`
    - `Future<void> writeDescriptorThroughHandle(RandomAccessFile lockHandle, RuntimeLockfileData data)`
    - `Future<RuntimeLockfileData?> readDescriptorThroughHandle(RandomAccessFile lockHandle)`
    - `Future<RuntimeLockfileData?> readDescriptorDirect(File lockFile)`
    - `Future<bool> isProcessActiveAndMatching(int pid, {required String expectedExecutable})`
    - `Future<int> spawnDetachedRuntime({required String executable, required List<String> args, required String workingDirectory, required String logFilePath, Map<String, String>? environment})`

- [ ] **Step 1: Write failing tests for WindowsRuntimeProcessSupervisor**

```dart
// frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart
import 'dart:io';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('WindowsRuntimeProcessSupervisor', () {
    test('opens lockfile with append mode and writes descriptor through locked handle without truncating on open', () async {
      final tempDir = await Directory.systemTemp.createTemp('lock_test_');
      final lockFile = File('${tempDir.path}\\runtime.lock');
      final supervisor = WindowsRuntimeProcessSupervisor();

      // First acquisition
      final handle1 = await supervisor.acquireStartupLock(lockFile);
      expect(handle1, isNotNull);

      final data = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'test-inst-1',
        pid: 1001,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\test\python.exe',
      );
      await supervisor.writeDescriptorThroughHandle(handle1!, data);
      final readBack = await supervisor.readDescriptorThroughHandle(handle1);
      expect(readBack?.instanceId, equals('test-inst-1'));

      await supervisor.releaseStartupLock(handle1);

      // Reopening in append mode must NOT truncate existing descriptor
      final handle2 = await supervisor.acquireStartupLock(lockFile);
      expect(handle2, isNotNull);
      final readAgain = await supervisor.readDescriptorThroughHandle(handle2!);
      expect(readAgain?.instanceId, equals('test-inst-1'));
      await supervisor.releaseStartupLock(handle2);

      await tempDir.delete(recursive: true);
    });

    test('detects cross-process lock contention via helper process', () async {
      final tempDir = await Directory.systemTemp.createTemp('cross_proc_test_');
      final lockFile = File('${tempDir.path}\\runtime.lock');
      final supervisor = WindowsRuntimeProcessSupervisor();

      // Launch external Dart helper process that holds lock for 2 seconds
      final helper = await Process.start(
        Platform.resolvedExecutable,
        ['run', 'test/helpers/lock_holder_helper.dart', lockFile.path, '2000'],
      );

      // Give helper 200ms to acquire lock
      await Future.delayed(const Duration(milliseconds: 200));

      // Immediate attempt with 100ms timeout must detect lock contention and return null
      final handle = await supervisor.acquireStartupLock(lockFile, timeout: const Duration(milliseconds: 100));
      expect(handle, isNull);

      await helper.exitCode;
      await tempDir.delete(recursive: true);
    });

    test('refuses to kill or touch foreign or unverified PID', () async {
      final supervisor = WindowsRuntimeProcessSupervisor();
      // Probe PID with non-matching executable
      final isMatch = await supervisor.isProcessActiveAndMatching(
        1, // System idle or init
        expectedExecutable: 'python.exe',
      );
      expect(isMatch, isFalse);
    });

    test('fails closed when runtime executable is absent', () async {
      final supervisor = WindowsRuntimeProcessSupervisor();
      expect(
        () => supervisor.spawnDetachedRuntime(
          executable: r'C:\nonexistent\python.exe',
          args: [],
          workingDirectory: r'C:\',
          logFilePath: r'C:\temp\run.log',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart`
Expected: FAIL with compilation error (classes not found).

- [ ] **Step 3: Implement `WindowsRuntimeProcessSupervisor` and `ProcessLauncherAdapter`**

In `WindowsRuntimeProcessSupervisor`:
- `acquireStartupLock`: opens `lockFile` with `FileMode.append` (NEVER `FileMode.write`). Loops with exponential backoff up to `timeout` calling `handle.lock(FileLock.exclusive)`. Catches `FileSystemException` during contention. Returns `handle` or `null`.
- `releaseStartupLock`: calls `await handle.unlock()` and `await handle.close()`.
- `writeDescriptorThroughHandle`: writes strictly through handle: `await handle.setPosition(0)`, `await handle.truncate(0)`, `await handle.writeString(data.toRawJson())`, `await handle.flush()`.
- `readDescriptorThroughHandle`: reads string from `handle.setPosition(0)` and parses `RuntimeLockfileData`.
- `isPortListening`: bounded 500ms `Socket.connect`.
- `isProcessActiveAndMatching`: queries Windows process table via `tasklist /FI "PID eq <pid>" /FO CSV /NH`. Validates image name matches expected executable. Returns `false` on missing or mismatched PID. Never kills any process.
- `spawnDetachedRuntime`: checks executable exists on disk. Creates log parent directory. Spawns child with `ProcessStartMode.detached` and passes `environment: {'COMPANION_LOG_FILE': logFilePath, 'PYTHONUNBUFFERED': '1', ...?environment}`. Returns direct process PID without shell wrappers.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test frontend/flutter/apps/desktop/test/windows_runtime_process_supervisor_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify git status and commit**

Stage: `frontend/flutter/apps/desktop/lib/platform/` and test files.
Commit: `feat(desktop): implement Windows native process supervisor with safe kernel locking and detached logging`

---

### Task 3: Desktop Runtime Coordinator with Double-Checked Locking, Double Verification & Readiness Polling (`apps/desktop/lib/coordinator/`)

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
import 'dart:io';
import 'package:ai_companion_desktop/coordinator/desktop_runtime_coordinator.dart';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('DesktopRuntimeCoordinator', () {
    test('transitions to remoteHost and skips local process spawning when baseUrl is non-loopback', () async {
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://companion-remote.lan:8000',
        supervisor: WindowsRuntimeProcessSupervisor(),
        // mock client with successful reachability and auth
      );
      final state = await coordinator.ensureRuntimeReady();
      expect(state.supervisionMode, equals(SupervisionMode.remoteHost));
      expect(state.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(coordinator.isLocalLoopback, isFalse);
    });

    test('attaches to existing running instance without spawning second process', () async {
      // Mock supervisor where port 8000 connects, health returns 200, auth verify returns 200
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        // mock client & mock launcher
      );
      final state = await coordinator.ensureRuntimeReady();
      expect(state.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(coordinator.activeRuntimeInfo?.pid, isNotNull);
      // verify launcher.spawnDetachedRuntime was never called
    });

    test('transitions to reachableUnauthenticated when health 200 but auth verify returns 401', () async {
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        // mock client where health 200, auth 401
      );
      final state = await coordinator.ensureRuntimeReady();
      expect(state.status, equals(RuntimeStatus.reachableUnauthenticated));
      expect(state.canSendMessages, isFalse);
    });

    test('transitions to alienPortConflict and refuses to kill process when port responds with non-companion payload', () async {
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        // mock port listening but /health returns 404 or connection reset
      );
      final state = await coordinator.ensureRuntimeReady();
      expect(state.status, equals(RuntimeStatus.alienPortConflict));
      expect(state.isOperational, isFalse);
    });

    test('transitions to startupTimeout when spawned process does not become healthy within 30s', () async {
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        // mock process spawns but health polling continuously times out
      );
      final state = await coordinator.ensureRuntimeReady(timeout: const Duration(milliseconds: 500));
      expect(state.status, equals(RuntimeStatus.startupTimeout));
    });

    test('detects alive but unresponsive process under lock and refuses duplicate spawn', () async {
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        // mock lockfile has PID 5555 which is alive in OS table, but port 8000 is not responding
      );
      final state = await coordinator.ensureRuntimeReady();
      expect(state.status, equals(RuntimeStatus.processUnresponsive));
      // verify no duplicate spawn occurred
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart`
Expected: FAIL with compilation error (class not found).

- [ ] **Step 3: Implement `DesktopRuntimeCoordinator` in `apps/desktop/lib/coordinator/`**

Implement `DesktopRuntimeCoordinator`:
1. Check `isLocalLoopback`: if false, supervision mode is `SupervisionMode.remoteHost`. Verify remote reachability and auth over HTTP without touching local files or processes.
2. If loopback:
   - Check if port 8000 is already listening. If listening: check `GET /api/v1/health` and `POST /api/v1/auth/verify`. If healthy and authenticated, attach immediately without lock or spawn.
   - If port is not listening:
     - Acquire startup lock (`supervisor.acquireStartupLock`). If null/timed out, mark `startupTimeout` (lock contention).
     - Under `try { ... }`:
       - **Double-Checked Recheck under Guard:**
         - Recheck `isPortListening`. If listening now (peer finished launch), probe health and auth -> attach -> return.
         - Read descriptor through locked handle. If descriptor exists with PID:
           - Check `isProcessActiveAndMatching(desc.pid)`.
           - If PID is alive: do not spawn duplicate! Poll for readiness or transition to `processUnresponsive`.
           - If PID is dead/mismatched: descriptor is stale; proceed to spawn.
         - If port free and no active process:
           - Verify executable path exists. If not, transition to `executableNotFound`.
           - Spawn detached process with `COMPANION_LOG_FILE` environment.
           - Write new descriptor through locked handle with generated `instanceId` (UUID).
     - In `finally`: `await supervisor.releaseStartupLock(handle)`.
   - Poll `GET /api/v1/health` with exponential backoff (500ms initial, capped at 2s) up to 30s.
   - Upon health 200, verify DPAPI token via `POST /api/v1/auth/verify`. Transition to `readyAndAuthenticated` or `reachableUnauthenticated`.
   - If polling exceeds timeout, transition to `startupTimeout`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_runtime_coordinator_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify git status and commit**

Stage: `frontend/flutter/apps/desktop/lib/coordinator/` and test file.
Commit: `feat(desktop): implement desktop runtime coordinator with double-checked locking and auth separation`

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
    - `key: 'status'`: displays dynamic label (`Runtime: Active (PID 1234)`, `Runtime: Remote Host`, `Runtime: Alien Conflict`, `Runtime: Unresponsive`).
    - `key: 'exit_full'`: disabled with clear label `"Exit Companion (Full Shutdown - Planned PC-HOST-005)"` — explicitly conveying that full runtime shutdown requires secure local lifecycle authority.
    - `key: 'hide_to_tray'`: label `"Hide Window to Tray"` — hides visual shell to tray while runtime continues.
    - `key: 'quit_ui_dev'`: label `"Close UI Only (Dev Test)"` — developer-only UI termination for testing unexpected UI exit and crash survival without killing the background runtime.
  - Settings screen:
    - Recessed diagnostic card for Runtime Supervision: displays supervision mode (Local Loopback vs Remote Host), connection state badge, PID, port, and lockfile path.

- [ ] **Step 1: Write failing tests for System Tray lifecycle and Settings supervision display**

```dart
// frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_supervision_test.dart
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  test('closing window to tray hides UI while leaving runtime process running', () async {
    final coordinator = DesktopLifecycleCoordinator(/* mock window & tray adapters */);
    await coordinator.handleCloseToTrayRequested();
    // Verify window hidden to tray without any process termination
  });

  test('quit UI only terminates UI without stopping runtime process', () async {
    final coordinator = DesktopLifecycleCoordinator(/* mock window & tray adapters */);
    await coordinator.handleDevQuitUiRequested();
    // Verify window and tray adapters disposed cleanly without any process kill calls
  });

  test('tray menu keeps full exit action disabled with PC-HOST-005 planned label', () {
    final coordinator = DesktopLifecycleCoordinator(/* mock window & tray adapters */);
    final items = coordinator.buildTrayMenuItems(
      RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.readyAndAuthenticated,
        pid: 1234,
        port: 8000,
      ),
    );
    final exitFullItem = items.firstWhere((i) => i.key == 'exit_full');
    expect(exitFullItem.disabled, isTrue);
    expect(exitFullItem.label, contains('PC-HOST-005'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test frontend/flutter/apps/desktop/test/desktop_lifecycle_runtime_supervision_test.dart`
Expected: FAIL.

- [ ] **Step 3: Update `DesktopLifecycleCoordinator`, `DesktopSettingsController`, and `SettingsScreen`**

In `DesktopLifecycleCoordinator`:
- Add `updateRuntimeStatus(RuntimeProcessState state)` updating tray label dynamically.
- Implement truthful tray menu: `open`, `status`, `hide_to_tray`, `quit_ui_dev` (dev test only), and `exit_full` (disabled, planned for `PC-HOST-005`).
- Ensure neither window hide nor `quit_ui_dev` stops or signals the detached runtime.
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
- Test: Run verification harness covering dormant spawn, attach to existing, UI exit survival, stale lock recovery, alien port conflict, and lock contention.
- Run full automated test matrix.

**Interfaces:**
- Consumes: Windows PowerShell, compiled Flutter desktop debug executable, backend venv python executable.
- Produces: Reproducible automated Windows acceptance harness validating all 6 empirical lifecycle scenarios using disposable test roots, ports, and tokens.

- [ ] **Step 1: Implement `scripts/verify_windows_runtime_supervision.ps1`**

Script isolates test execution completely:
- Root directory: `$tempRoot = Join-Path $env:TEMP ("ai_companion_test_" + [Guid]::NewGuid().ToString("N"))`
- Port: Disposable test port (e.g. `8765`), avoiding production port 8000.
- Token: Disposable test pairing token (`companion_sec_test_verify_token_12345`).
- Never touches `%LOCALAPPDATA%\AI Companion` production data, models, or SQLite database.

Automates 6 empirical scenarios:
1. Scenario A: Dormant launch -> spawns runtime on test port -> verifies test port listening -> verifies `runtime.lock` created.
2. Scenario B: Concurrent launch -> second instance attaches to existing running instance without spawning duplicate PID.
3. Scenario C: "Quit UI != Stop Runtime" -> terminates Flutter client -> verifies backend runtime process PID remains alive on test port.
4. Scenario D: Stale lock recovery -> creates dummy stale lockfile with dead PID -> runs supervisor -> verifies stale lock removed and runtime spawns cleanly.
5. Scenario E: Alien port conflict -> binds dummy TCP listener on test port -> runs supervisor -> verifies supervisor fails closed with `alienPortConflict` without killing dummy listener.
6. Scenario F: Cross-process lock contention -> external process holds lock on test lockfile -> supervisor detects contention and handles it without descriptor corruption.
- Finally: terminates test backend process on test port, cleans up `$tempRoot`.

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
2. **Lifecycle & Crash Survival Verification:** Close the desktop window (`×`) -> verify window hides to tray while backend continues running -> trigger dev UI exit (or terminate Flutter UI) -> verify Flutter UI exits while backend process remains running at `127.0.0.1:8000` (verified via `netstat -ano | findstr 8000`) -> relaunch Flutter UI -> verify client cleanly re-attaches to the running backend without spawning a second process.
3. **Alien Port Conflict Handling:** Run a dummy TCP listener on port 8000 -> launch Flutter client -> verify client surfaces `PORT_CONFLICT_ALIEN_PROCESS` diagnostic badge without crashing, hanging, or terminating the foreign listener.
4. **Stale Lock Recovery:** Create a synthetic `runtime.lock` with dead PID 99999999 -> launch Flutter client -> verify supervisor detects dead PID, cleanly removes stale lockfile, and spawns runtime without error.
5. **Remote Host URL Bypass:** Set `HostUrl` to a remote address (e.g. `http://192.168.1.100:8000`) -> launch desktop client -> verify client operates in `remoteHost` supervision mode without attempting local process spawning or lockfile creation.
6. **Full Exit Menu Disclosure:** Inspect system tray context menu -> verify "Exit Companion (Full Shutdown - Planned PC-HOST-005)" is present and disabled, clearly indicating that confirmed host shutdown belongs to follow-on PC-HOST-005.
