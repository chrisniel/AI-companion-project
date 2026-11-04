import 'dart:async';
import 'dart:io';
import 'package:ai_companion_desktop/coordinator/desktop_runtime_coordinator.dart';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter_test/flutter_test.dart';

class TestMockCompanionClient extends CompanionClient {
  bool healthSucceeds;
  bool isNonCompanionPayload;
  int authStatusCode;
  bool shutdownSucceeds;
  int healthCallCount = 0;
  int authCallCount = 0;
  int shutdownCallCount = 0;

  TestMockCompanionClient({
    super.baseUrl = 'http://127.0.0.1:8000',
    this.healthSucceeds = true,
    this.isNonCompanionPayload = false,
    this.authStatusCode = 200,
    this.shutdownSucceeds = true,
  }) : super(credentialStore: InMemoryCredentialStore('test_token'));

  @override
  Future<HealthResponse> getHealth({Duration timeout = const Duration(seconds: 3)}) async {
    healthCallCount++;
    if (isNonCompanionPayload) {
      throw const CompanionApiException(
        statusCode: 404,
        message: 'Cannot GET /api/v1/health',
      );
    }
    if (!healthSucceeds) {
      throw const CompanionApiException(
        statusCode: 503,
        message: 'Service Unavailable',
      );
    }
    return const HealthResponse(status: 'healthy');
  }

  @override
  Future<AuthVerifyResponse> verifyAuth({Duration timeout = const Duration(seconds: 5)}) async {
    authCallCount++;
    if (authStatusCode == 401) {
      throw const CompanionApiException(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Invalid pairing token',
      );
    }
    return const AuthVerifyResponse(
      authenticated: true,
      tokenType: 'Bearer',
      message: 'Token verified successfully',
    );
  }

  SystemStatusResponse systemStatusResponse = SystemStatusResponse(
    status: 'online',
    platform: 'windows',
    pythonVersion: '3.11.9',
    hostname: 'test-host',
    version: '0.1.0',
    databaseConnected: true,
    timestamp: DateTime.now().toUtc().toIso8601String(),
    shuttingDown: false,
  );

  @override
  Future<SystemShutdownResponse> shutdownSystem({
    String reason = 'user_exit_companion',
    double drainTimeoutSeconds = 6.0,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    shutdownCallCount++;
    if (!shutdownSucceeds) {
      throw const CompanionApiException(
        statusCode: 503,
        message: 'Shutdown failed',
      );
    }
    return const SystemShutdownResponse(
      status: 'shutting_down',
      pid: 2468,
      message: 'Shutdown accepted',
    );
  }

  @override
  Future<SystemStatusResponse> getSystemStatus({Duration timeout = const Duration(seconds: 5)}) async {
    return systemStatusResponse;
  }
}

class FakeSupervisor extends WindowsRuntimeProcessSupervisor {
  bool portListening = false;
  bool processActive = false;
  int spawnCallCount = 0;
  List<String>? lastSpawnedArgs;
  bool clearedLockfile = false;
  RuntimeLockfileData? lastTerminatedDescriptor;
  TerminationResult fakeTerminationResult = const TerminationResult(
    status: TerminationResultStatus.terminated,
  );
  RuntimeLockfileData? storedDescriptor;
  RandomAccessFile? fakeLockHandle;
  bool lockFails = false;

  @override
  Future<bool> clearRuntimeLockfileThroughHandle(
    File lockFile, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    clearedLockfile = true;
    return true;
  }

  @override
  Future<TerminationResult> terminateVerifiedRuntimeProcess({
    required RuntimeLockfileData expectedDescriptor,
    int? managedLlmPid,
    bool managedByCore = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    lastTerminatedDescriptor = expectedDescriptor;
    return fakeTerminationResult;
  }

  @override
  Future<bool> isPortListening(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    return portListening;
  }

  @override
  Future<RandomAccessFile?> acquireStartupLock(
    File lockFile, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (lockFails) return null;
    return fakeLockHandle;
  }

  @override
  Future<void> releaseStartupLock(RandomAccessFile lockHandle) async {}

  @override
  Future<void> writeDescriptorThroughHandle(
    RandomAccessFile lockHandle,
    RuntimeLockfileData data,
  ) async {
    storedDescriptor = data;
  }

  @override
  Future<RuntimeLockfileData?> readDescriptorThroughHandle(
    RandomAccessFile lockHandle,
  ) async {
    return storedDescriptor;
  }

  @override
  Future<RuntimeLockfileData?> readDescriptorDirect(File lockFile) async {
    return storedDescriptor;
  }

  @override
  Future<bool> isProcessActiveAndMatching(
    int pid, {
    required String expectedExecutable,
  }) async {
    return processActive;
  }

  @override
  Future<int> spawnDetachedRuntime({
    required String executable,
    required List<String> args,
    required String workingDirectory,
    required String logFilePath,
    Map<String, String>? environment,
  }) async {
    spawnCallCount++;
    lastSpawnedArgs = args;
    portListening = true; // Simulates process coming online
    return 9999;
  }

  ProcessDiscoveryResult discoveryResult = const ProcessDiscoveryResult(
    status: ProcessDiscoveryStatus.noProcess,
  );

  @override
  Future<ProcessDiscoveryResult> discoverRuntimeProcesses({
    required int port,
    required String expectedExecutable,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return discoveryResult;
  }
}

void main() {
  group('DesktopRuntimeCoordinator', () {
    test('transitions to remoteHost and skips local process spawning when baseUrl is non-loopback', () async {
      final fakeSupervisor = FakeSupervisor();
      final mockClient = TestMockCompanionClient(baseUrl: 'http://companion-remote.lan:8000');
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://companion-remote.lan:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
      );

      final state = await coordinator.ensureRuntimeReady();
      expect(state.supervisionMode, equals(SupervisionMode.remoteHost));
      expect(state.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(coordinator.isLocalLoopback, isFalse);
      expect(fakeSupervisor.spawnCallCount, equals(0));
    });

    test('attaches to existing running instance without spawning second process', () async {
      final fakeSupervisor = FakeSupervisor()..portListening = true;
      fakeSupervisor.storedDescriptor = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'existing-id',
        pid: 1234,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\Python\python.exe',
      );
      final mockClient = TestMockCompanionClient();
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
      );

      final state = await coordinator.ensureRuntimeReady();
      expect(state.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(state.pid, equals(1234));
      expect(fakeSupervisor.spawnCallCount, equals(0));
    });

    test('transitions to reachableUnauthenticated when health 200 but auth verify returns 401', () async {
      final fakeSupervisor = FakeSupervisor()..portListening = true;
      final mockClient = TestMockCompanionClient(authStatusCode: 401);
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
      );

      final state = await coordinator.ensureRuntimeReady();
      expect(state.status, equals(RuntimeStatus.reachableUnauthenticated));
      expect(state.canSendMessages, isFalse);
      expect(fakeSupervisor.spawnCallCount, equals(0));
    });

    test('transitions to alienPortConflict and refuses to kill process when port responds with non-companion payload', () async {
      final fakeSupervisor = FakeSupervisor()..portListening = true;
      final mockClient = TestMockCompanionClient(isNonCompanionPayload: true);
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
      );

      final state = await coordinator.ensureRuntimeReady();
      expect(state.status, equals(RuntimeStatus.alienPortConflict));
      expect(state.isOperational, isFalse);
      expect(fakeSupervisor.spawnCallCount, equals(0));
    });

    test('transitions to startupTimeout when spawned process does not become healthy within timeout', () async {
      final fakeSupervisor = FakeSupervisor()
        ..portListening = false;
      final mockClient = TestMockCompanionClient(healthSucceeds: false);

      final tempDir = await Directory.systemTemp.createTemp('coord_test_');
      final fakeExe = File('${tempDir.path}\\python.exe')..writeAsStringSync('');
      final fakeLock = File('${tempDir.path}\\runtime.lock');
      final handle = await fakeLock.open(mode: FileMode.append);
      fakeSupervisor.fakeLockHandle = handle;

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
        customLockFile: fakeLock,
        customExecutablePath: fakeExe.path,
        customLogFilePath: '${tempDir.path}\\runtime.log',
        customWorkingDirectory: tempDir.path,
      );

      final state = await coordinator.ensureRuntimeReady(timeout: const Duration(milliseconds: 300));
      expect(state.status, equals(RuntimeStatus.startupTimeout));

      await handle.close();
      await tempDir.delete(recursive: true);
    });

    test('detects alive but unresponsive process under lock and refuses duplicate spawn', () async {
      final fakeSupervisor = FakeSupervisor()
        ..portListening = false
        ..processActive = true;
      fakeSupervisor.storedDescriptor = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'stuck-proc',
        pid: 7777,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\Python\python.exe',
      );

      final tempDir = await Directory.systemTemp.createTemp('stuck_test_');
      final fakeLock = File('${tempDir.path}\\runtime.lock');
      final handle = await fakeLock.open(mode: FileMode.append);
      fakeSupervisor.fakeLockHandle = handle;

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: TestMockCompanionClient(),
        customLockFile: fakeLock,
        customExecutablePath: r'C:\Python\python.exe',
      );

      final state = await coordinator.ensureRuntimeReady();
      expect(state.status, equals(RuntimeStatus.processUnresponsive));
      expect(state.pid, equals(7777));
      expect(fakeSupervisor.spawnCallCount, equals(0));

      await handle.close();
      await tempDir.delete(recursive: true);
    });

    test('spawns runtime with app.runtime_server and --app app.main:app', () async {
      final fakeSupervisor = FakeSupervisor()..portListening = false;
      final mockClient = TestMockCompanionClient();

      final tempDir = await Directory.systemTemp.createTemp('spawn_args_test_');
      final fakeExe = File('${tempDir.path}\\pythonw.exe')..writeAsStringSync('');
      final fakeLock = File('${tempDir.path}\\runtime.lock');
      final handle = await fakeLock.open(mode: FileMode.append);
      fakeSupervisor.fakeLockHandle = handle;

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
        customLockFile: fakeLock,
        customExecutablePath: fakeExe.path,
        customLogFilePath: '${tempDir.path}\\runtime.log',
        customWorkingDirectory: tempDir.path,
      );

      final state = await coordinator.ensureRuntimeReady();
      expect(state.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(fakeSupervisor.spawnCallCount, equals(1));
      expect(fakeSupervisor.lastSpawnedArgs, contains('-m'));
      expect(fakeSupervisor.lastSpawnedArgs, contains('app.runtime_server'));
      expect(fakeSupervisor.lastSpawnedArgs, contains('--app'));
      expect(fakeSupervisor.lastSpawnedArgs, contains('app.main:app'));

      await handle.close();
      await tempDir.delete(recursive: true);
    });

    test('shutdownLocalRuntime on remoteHost skips network shutdown and returns gracefulSuccess', () async {
      final fakeSupervisor = FakeSupervisor();
      final mockClient = TestMockCompanionClient(baseUrl: 'http://remote-companion:8000');
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://remote-companion:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
      );

      final outcome = await coordinator.shutdownLocalRuntime();
      expect(outcome, equals(ShutdownOutcome.gracefulSuccess));
      expect(mockClient.shutdownCallCount, equals(0));
      expect(coordinator.currentState.status, equals(RuntimeStatus.stopped));
    });

    test('shutdownLocalRuntime observes graceful exit within 25s window without calling OS fallback', () async {
      final fakeSupervisor = FakeSupervisor()
        ..portListening = true
        ..processActive = true;
      fakeSupervisor.storedDescriptor = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'graceful-inst',
        pid: 2468,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\Python\pythonw.exe',
      );
      final mockClient = TestMockCompanionClient();
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
      );

      await coordinator.ensureRuntimeReady();

      // Simulate process shutting down after 2 health/poll checks
      int pollCount = 0;
      mockClient.systemStatusResponse = SystemStatusResponse(
        status: 'online',
        platform: 'windows',
        pythonVersion: '3.11.9',
        hostname: 'test-host',
        version: '0.1.0',
        databaseConnected: true,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        shuttingDown: true,
        shutdownPhase: 'drain_active_turns',
      );

      // We simulate that after 2 status checks, port stops listening and process exits
      fakeSupervisor.portListening = true;
      fakeSupervisor.processActive = true;

      Timer.periodic(const Duration(milliseconds: 50), (timer) {
        pollCount++;
        if (pollCount >= 2) {
          fakeSupervisor.portListening = false;
          fakeSupervisor.processActive = false;
          timer.cancel();
        }
      });

      final outcome = await coordinator.shutdownLocalRuntime(timeout: const Duration(seconds: 5));
      expect(outcome, equals(ShutdownOutcome.gracefulSuccess));
      expect(mockClient.shutdownCallCount, equals(1));
      expect(fakeSupervisor.clearedLockfile, isTrue);
      expect(fakeSupervisor.lastTerminatedDescriptor, isNull);
      expect(coordinator.currentState.status, equals(RuntimeStatus.stopped));
    });

    test('shutdownLocalRuntime transitions to shutdownFailed (incompleteCleanup) without killing runtime on quiescence timeout', () async {
      final fakeSupervisor = FakeSupervisor()
        ..portListening = true
        ..processActive = true;
      fakeSupervisor.storedDescriptor = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'incomplete-inst',
        pid: 3579,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\Python\pythonw.exe',
      );
      final mockClient = TestMockCompanionClient();
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
      );

      await coordinator.ensureRuntimeReady();

      mockClient.systemStatusResponse = SystemStatusResponse(
        status: 'online',
        platform: 'windows',
        pythonVersion: '3.11.9',
        hostname: 'test-host',
        version: '0.1.0',
        databaseConnected: true,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        shuttingDown: true,
        shutdownPhase: 'drain_persistence',
        shutdownQuiescenceStatus: 'incomplete_db_quiescence_timeout',
      );

      final outcome = await coordinator.shutdownLocalRuntime(timeout: const Duration(milliseconds: 500));
      expect(outcome, equals(ShutdownOutcome.incompleteCleanup));
      expect(fakeSupervisor.lastTerminatedDescriptor, isNull); // ZERO auto-kills!
      expect(coordinator.currentState.status, equals(RuntimeStatus.shutdownFailed));
      expect(coordinator.currentState.shutdownFailureReason, equals(ShutdownFailureReason.incompleteCleanup));
    });

    test('shutdownLocalRuntime falls back to terminateVerifiedRuntimeProcess on unresponsive runtime and returns emergencyTerminated', () async {
      final fakeSupervisor = FakeSupervisor()
        ..portListening = true
        ..processActive = true;
      fakeSupervisor.storedDescriptor = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'unresponsive-inst',
        pid: 4680,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\Python\pythonw.exe',
      );
      final mockClient = TestMockCompanionClient(shutdownSucceeds: false);
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
      );

      await coordinator.ensureRuntimeReady();

      final outcome = await coordinator.shutdownLocalRuntime(timeout: const Duration(milliseconds: 500));
      expect(outcome, equals(ShutdownOutcome.emergencyTerminated));
      expect(fakeSupervisor.lastTerminatedDescriptor?.pid, equals(4680));
      expect(fakeSupervisor.clearedLockfile, isTrue);
      expect(coordinator.currentState.status, equals(RuntimeStatus.stopped));
    });

    test('forceEmergencyStopLocalRuntime executes handle-bound termination and returns emergencyTerminated', () async {
      final fakeSupervisor = FakeSupervisor()
        ..portListening = true
        ..processActive = true;
      fakeSupervisor.storedDescriptor = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'force-stop-inst',
        pid: 5791,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\Python\pythonw.exe',
      );
      final mockClient = TestMockCompanionClient();
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: mockClient,
      );

      await coordinator.ensureRuntimeReady();

      final outcome = await coordinator.forceEmergencyStopLocalRuntime();
      expect(outcome, equals(ShutdownOutcome.emergencyTerminated));
      expect(fakeSupervisor.lastTerminatedDescriptor?.pid, equals(5791));
      expect(fakeSupervisor.clearedLockfile, isTrue);
      expect(coordinator.currentState.status, equals(RuntimeStatus.stopped));
    });
  });
}
