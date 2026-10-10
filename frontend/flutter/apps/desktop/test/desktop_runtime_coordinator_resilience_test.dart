import 'dart:async';
import 'dart:io';

import 'package:ai_companion_desktop/coordinator/desktop_runtime_coordinator.dart';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter_test/flutter_test.dart';

class MockResilienceProcessSupervisor extends WindowsRuntimeProcessSupervisor {
  bool isListening = true;

  @override
  Future<bool> isPortListening(String host, int port, {Duration timeout = const Duration(milliseconds: 500)}) async {
    return isListening;
  }

  @override
  Future<RuntimeLockfileData?> readDescriptorDirect(File lockFile) async {
    return null;
  }
}

class ControllableSpawningSupervisor extends WindowsRuntimeProcessSupervisor {
  final List<String> spawnArgs = [];
  final List<int> spawnedPids = [];
  final List<int> terminatedPids = [];
  final Completer<void> spawnDelayCompleter = Completer<void>();
  bool isListening = false;
  RandomAccessFile? mockHandle;

  @override
  Future<bool> isPortListening(String host, int port, {Duration timeout = const Duration(milliseconds: 500)}) async {
    return isListening;
  }

  @override
  Future<RandomAccessFile?> acquireStartupLock(File lockFile, {Duration timeout = const Duration(seconds: 5)}) async {
    return mockHandle;
  }

  @override
  Future<void> releaseStartupLock(RandomAccessFile lockHandle) async {}

  @override
  Future<RuntimeLockfileData?> readDescriptorThroughHandle(RandomAccessFile lockHandle) async => null;

  @override
  Future<void> writeDescriptorThroughHandle(RandomAccessFile lockHandle, RuntimeLockfileData data) async {}

  @override
  Future<int> spawnDetachedRuntime({
    required String executable,
    required List<String> args,
    required String workingDirectory,
    required String logFilePath,
    Map<String, String>? environment,
  }) async {
    spawnArgs.addAll(args);
    await spawnDelayCompleter.future;
    const pid = 4242;
    spawnedPids.add(pid);
    return pid;
  }

  @override
  Future<bool> terminateSpawnedProcess(int pid) async {
    terminatedPids.add(pid);
    return true;
  }
}

class DelayedAuthClient extends CompanionClient {
  DelayedAuthClient({this.authDelay = const Duration(seconds: 10), this.authException})
      : super(credentialStore: InMemoryCredentialStore('token'));

  final Duration authDelay;
  final Exception? authException;

  @override
  Future<HealthResponse> getHealth({Duration timeout = const Duration(seconds: 3)}) async {
    return const HealthResponse(status: 'healthy');
  }

  @override
  Future<AuthVerifyResponse> verifyAuth({Duration timeout = const Duration(seconds: 5)}) async {
    if (authException != null) {
      throw authException!;
    }
    await Future<void>.delayed(authDelay);
    return const AuthVerifyResponse(
      authenticated: true,
      tokenType: 'Bearer',
      message: 'Token verified',
    );
  }
}

class GenuineHangingAuthClient extends CompanionClient {
  final Completer<AuthVerifyResponse> authCompleter = Completer<AuthVerifyResponse>();
  bool verifyAuthCalled = false;

  GenuineHangingAuthClient({required CredentialStore credentialStore})
      : super(credentialStore: credentialStore);

  @override
  Future<HealthResponse> getHealth({Duration timeout = const Duration(seconds: 3)}) async {
    return const HealthResponse(status: 'healthy');
  }

  @override
  Future<AuthVerifyResponse> verifyAuth({Duration timeout = const Duration(seconds: 5)}) {
    verifyAuthCalled = true;
    return authCompleter.future; // NEVER completes
  }
}

void main() {
  group('DesktopRuntimeCoordinator Resilience', () {
    test('Hanging authentication probe respects deadline and returns startupTimeout', () async {
      final supervisor = MockResilienceProcessSupervisor();
      // Client verifyAuth delays for 5 seconds or throws 408 timeout
      final client = DelayedAuthClient(
        authDelay: const Duration(seconds: 5),
        authException: const CompanionApiException(
          statusCode: 408,
          code: 'TIMEOUT',
          message: 'Authentication probe timed out',
        ),
      );

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        client: client,
      );

      final result = await coordinator.ensureRuntimeReady(
        timeout: const Duration(milliseconds: 200),
      );

      expect(result.status, equals(RuntimeStatus.startupTimeout));
      coordinator.dispose();
    });

    test('Rapid Host URL changes discard stale generation updates', () async {
      final supervisor = MockResilienceProcessSupervisor();
      final slowClient = DelayedAuthClient(authDelay: const Duration(milliseconds: 300));
      final fastClient = DelayedAuthClient(authDelay: Duration.zero);

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        client: slowClient,
      );

      final emittedStates = <RuntimeProcessState>[];
      final sub = coordinator.stateStream.listen(emittedStates.add);

      // Start launch on initial configuration (generation 0)
      final future1 = coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 2));

      // Rapidly switch configuration to remote host on different port (generation 1)
      coordinator.updateConfiguration(
        newBaseUrl: 'http://192.168.1.50:9000',
        newClient: fastClient,
      );
      final future2 = coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 2));

      await Future.wait([future1, future2]);

      // Final state must reflect the second configuration (port 9000, remoteHost)
      expect(coordinator.currentState.port, equals(9000));
      expect(coordinator.currentState.supervisionMode, equals(SupervisionMode.remoteHost));
      expect(coordinator.currentState.status, equals(RuntimeStatus.readyAndAuthenticated));

      await sub.cancel();
      coordinator.dispose();
    });

    test('Failed authentication (401) sets reachableUnauthenticated', () async {
      final supervisor = MockResilienceProcessSupervisor();
      final client = DelayedAuthClient(
        authException: const CompanionApiException(
          statusCode: 401,
          code: 'UNAUTHORIZED',
          message: 'Invalid pairing token',
        ),
      );

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        client: client,
      );

      final result = await coordinator.ensureRuntimeReady(
        timeout: const Duration(seconds: 2),
      );

      expect(result.status, equals(RuntimeStatus.reachableUnauthenticated));
      expect(result.diagnosticMessage, contains('unauthenticated'));
      coordinator.dispose();
    });

    test('Disposal during in-flight startup cleanly terminates without throwing', () async {
      final supervisor = MockResilienceProcessSupervisor();
      final client = DelayedAuthClient(authDelay: const Duration(seconds: 5));

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        client: client,
      );

      final inFlight = coordinator.ensureRuntimeReady(
        timeout: const Duration(seconds: 10),
      );

      // Dispose while in flight
      coordinator.dispose();

      // In-flight call should complete cleanly without throwing or crashing
      final finalState = await inFlight;
      expect(finalState, isNotNull);
    });

    test('Genuinely hanging auth probe (uncompleted Completer) enforces timeout deadline and returns startupTimeout', () async {
      final supervisor = MockResilienceProcessSupervisor();
      final store = InMemoryCredentialStore('token-123');
      final hangingClient = GenuineHangingAuthClient(credentialStore: store);

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        client: hangingClient,
      );

      final stopwatch = Stopwatch()..start();
      final result = await coordinator.ensureRuntimeReady(
        timeout: const Duration(milliseconds: 200),
      );
      stopwatch.stop();

      expect(hangingClient.verifyAuthCalled, isTrue);
      expect(result.status, equals(RuntimeStatus.startupTimeout));
      expect(result.diagnosticMessage, contains('timed out'));
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
      coordinator.dispose();
    });

    test('In-flight local startup superseded by remote reconfiguration terminates spawned process and never binds uvicorn to remote host', () async {
      final tempDir = await Directory.systemTemp.createTemp('race_test_');
      final tempLockFile = File('${tempDir.path}\\runtime.lock');
      await tempLockFile.writeAsString('');
      final realHandle = await tempLockFile.open(mode: FileMode.append);

      final supervisor = ControllableSpawningSupervisor();
      supervisor.mockHandle = realHandle;

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        customLockFile: tempLockFile,
        customExecutablePath: Platform.resolvedExecutable,
      );

      // Start ensureRuntimeReady (generation 0)
      final future1 = coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 5));

      // Wait a brief delay so coordinator enters spawnDetachedRuntime
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // While in flight, reconfigure to remote host
      coordinator.updateConfiguration(
        newBaseUrl: 'http://192.168.1.100:9000',
        newClient: DelayedAuthClient(authDelay: Duration.zero),
      );

      // Complete the delayed spawn
      supervisor.spawnDelayCompleter.complete();

      await future1;

      // 1. Process was spawned during generation 0
      expect(supervisor.spawnedPids, contains(4242));
      // 2. But generation changed, so supervisor.terminateSpawnedProcess MUST have been called!
      expect(supervisor.terminatedPids, contains(4242));
      // 3. Uvicorn was NEVER bound to the remote host!
      expect(supervisor.spawnArgs, isNot(contains('192.168.1.100')));
      expect(supervisor.spawnArgs, contains('127.0.0.1'));
      // 4. Coordinator state reflects the new remote host configuration, not the stale generation
      expect(coordinator.currentState.port, equals(9000));
      expect(coordinator.currentState.supervisionMode, equals(SupervisionMode.remoteHost));

      coordinator.dispose();
      await realHandle.close();
      await tempDir.delete(recursive: true);
    });
  });
}
