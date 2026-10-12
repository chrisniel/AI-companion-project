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
  int healthCallCount = 0;
  int authCallCount = 0;

  TestMockCompanionClient({
    super.baseUrl = 'http://127.0.0.1:8000',
    this.healthSucceeds = true,
    this.isNonCompanionPayload = false,
    this.authStatusCode = 200,
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
}

class FakeSupervisor extends WindowsRuntimeProcessSupervisor {
  bool portListening = false;
  bool processActive = false;
  int spawnCallCount = 0;
  RuntimeLockfileData? storedDescriptor;
  RandomAccessFile? fakeLockHandle;
  bool lockFails = false;

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
    portListening = true; // Simulates process coming online
    return 9999;
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
  });
}
