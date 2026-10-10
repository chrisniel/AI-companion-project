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
  final List<RuntimeLockfileData> writtenDescriptors = [];
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
  Future<ProcessDiscoveryResult> discoverRuntimeProcesses({
    required int port,
    required String expectedExecutable,
  }) async {
    return const ProcessDiscoveryResult(
      status: ProcessDiscoveryStatus.noProcess,
    );
  }

  @override
  Future<int?> findActiveRuntimeProcess({required int port, required String expectedExecutable}) async => null;

  @override
  Future<void> writeDescriptorThroughHandle(RandomAccessFile lockHandle, RuntimeLockfileData data) async {
    writtenDescriptors.add(data);
  }

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
}

class DiscoveryControlledMockSupervisor extends WindowsRuntimeProcessSupervisor {
  bool isListening = false;
  int spawnCallCount = 0;
  List<String> spawnArgs = [];
  RuntimeLockfileData? writtenDescriptor;
  RandomAccessFile? mockHandle;
  RuntimeLockfileData? existingDescriptor;
  bool isProcessActive = false;
  ProcessDiscoveryResult discoveryResult = const ProcessDiscoveryResult(
    status: ProcessDiscoveryStatus.noProcess,
  );

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
  Future<RuntimeLockfileData?> readDescriptorThroughHandle(RandomAccessFile lockHandle) async => existingDescriptor;

  @override
  Future<bool> isProcessActiveAndMatching(int pid, {required String expectedExecutable}) async => isProcessActive;

  @override
  Future<void> writeDescriptorThroughHandle(RandomAccessFile lockHandle, RuntimeLockfileData data) async {
    writtenDescriptor = data;
  }

  @override
  Future<ProcessDiscoveryResult> discoverRuntimeProcesses({
    required int port,
    required String expectedExecutable,
  }) async {
    return discoveryResult;
  }

  @override
  Future<int?> findActiveRuntimeProcess({required int port, required String expectedExecutable}) async {
    final res = await discoverRuntimeProcesses(port: port, expectedExecutable: expectedExecutable);
    return res.status == ProcessDiscoveryStatus.verified ? res.verifiedProcess?.pid : null;
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
    spawnArgs.addAll(args);
    return 9999;
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

    test('In-flight local startup superseded by remote reconfiguration preserves runtime independence and records lockfile descriptor without process termination', () async {
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
      // 2. Lockfile descriptor was safely written for the spawned process (preserving runtime independence)
      expect(supervisor.writtenDescriptors.map((d) => d.pid), contains(4242));
      // 4. Uvicorn was NEVER bound to the remote host!
      expect(supervisor.spawnArgs, isNot(contains('192.168.1.100')));
      expect(supervisor.spawnArgs, contains('127.0.0.1'));
      // 5. Coordinator state reflects the new remote host configuration, not the stale generation
      expect(coordinator.currentState.port, equals(9000));
      expect(coordinator.currentState.supervisionMode, equals(SupervisionMode.remoteHost));

      coordinator.dispose();
      await realHandle.close();
      await tempDir.delete(recursive: true);
    });

    test('Exact port matching: avoids false matches on similar but different port numbers', () {
      expect(WindowsRuntimeProcessSupervisor.matchesExactPort('python -m uvicorn app.main:app --port 80000', 8000), isFalse);
      expect(WindowsRuntimeProcessSupervisor.matchesExactPort('python -m uvicorn app.main:app --port 18000', 8000), isFalse);
      expect(WindowsRuntimeProcessSupervisor.matchesExactPort('python -m uvicorn app.main:app --timeout 8000 --port 8001', 8000), isFalse);
      expect(WindowsRuntimeProcessSupervisor.matchesExactPort('python -m uvicorn app.main:app --port 8000', 8000), isTrue);
      expect(WindowsRuntimeProcessSupervisor.matchesExactPort('python -m uvicorn app.main:app --port=8000', 8000), isTrue);
      expect(WindowsRuntimeProcessSupervisor.matchesExactPort('python -m uvicorn app.main:app --port "8000"', 8000), isTrue);
      expect(WindowsRuntimeProcessSupervisor.matchesExactPort("python -m uvicorn app.main:app --port '8000'", 8000), isTrue);
    });

    test('Similar but different port numbers in OS table are ignored and coordinator proceeds to spawn', () async {
      final tempDir = await Directory.systemTemp.createTemp('similar_port_test_');
      final tempLockFile = File('${tempDir.path}\\runtime.lock');
      await tempLockFile.writeAsString('');
      final realHandle = await tempLockFile.open(mode: FileMode.append);

      final supervisor = DiscoveryControlledMockSupervisor();
      supervisor.mockHandle = realHandle;
      supervisor.discoveryResult = const ProcessDiscoveryResult(status: ProcessDiscoveryStatus.noProcess);

      final fastClient = DelayedAuthClient(authDelay: Duration.zero);

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        client: fastClient,
        customLockFile: tempLockFile,
        customExecutablePath: Platform.resolvedExecutable,
      );

      Future.delayed(const Duration(milliseconds: 50), () {
        supervisor.isListening = true;
      });

      final result = await coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 5));

      // Correctly proceeded to spawn because process on 80000 was NOT matched
      expect(supervisor.spawnCallCount, equals(1));
      expect(supervisor.writtenDescriptor?.pid, equals(9999));
      expect(result.status, equals(RuntimeStatus.readyAndAuthenticated));

      coordinator.dispose();
      await realHandle.close();
      await tempDir.delete(recursive: true);
    });

    test('Multiple candidate processes: fails closed on ambiguity without spawning duplicate or adopting', () async {
      final tempDir = await Directory.systemTemp.createTemp('multiple_candidates_test_');
      final tempLockFile = File('${tempDir.path}\\runtime.lock');
      await tempLockFile.writeAsString('');
      final realHandle = await tempLockFile.open(mode: FileMode.append);

      final supervisor = DiscoveryControlledMockSupervisor();
      supervisor.mockHandle = realHandle;
      supervisor.discoveryResult = ProcessDiscoveryResult(
        status: ProcessDiscoveryStatus.multipleCandidates,
        candidates: [
          DiscoveredProcessIdentity(pid: 1001, executablePath: 'python.exe', commandLine: 'python -m uvicorn app.main:app --port 8000', creationTime: DateTime.now().toUtc()),
          DiscoveredProcessIdentity(pid: 1002, executablePath: 'python.exe', commandLine: 'python -m uvicorn app.main:app --port 8000', creationTime: DateTime.now().toUtc()),
        ],
        diagnostic: 'Multiple candidate processes detected on port 8000',
      );

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        customLockFile: tempLockFile,
        customExecutablePath: Platform.resolvedExecutable,
      );

      final result = await coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 5));

      // Fails closed with alienPortConflict
      expect(result.status, equals(RuntimeStatus.alienPortConflict));
      expect(result.diagnosticMessage, contains('ambiguous or unverified'));
      // Never spawns duplicate
      expect(supervisor.spawnCallCount, equals(0));
      // Never writes/adopts descriptor
      expect(supervisor.writtenDescriptor, isNull);

      coordinator.dispose();
      await realHandle.close();
      await tempDir.delete(recursive: true);
    });

    test('Foreign Python/uvicorn processes: fails closed without spawning or adopting', () async {
      final tempDir = await Directory.systemTemp.createTemp('foreign_proc_test_');
      final tempLockFile = File('${tempDir.path}\\runtime.lock');
      await tempLockFile.writeAsString('');
      final realHandle = await tempLockFile.open(mode: FileMode.append);

      final supervisor = DiscoveryControlledMockSupervisor();
      supervisor.mockHandle = realHandle;
      supervisor.discoveryResult = const ProcessDiscoveryResult(
        status: ProcessDiscoveryStatus.unverifiedCandidate,
        diagnostic: 'Candidate PID 9901 is running a non-companion application module: foreign.server:app',
      );

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        customLockFile: tempLockFile,
        customExecutablePath: Platform.resolvedExecutable,
      );

      final result = await coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 5));

      expect(result.status, equals(RuntimeStatus.alienPortConflict));
      expect(result.diagnosticMessage, contains('ambiguous or unverified'));
      expect(supervisor.spawnCallCount, equals(0));
      expect(supervisor.writtenDescriptor, isNull);

      coordinator.dispose();
      await realHandle.close();
      await tempDir.delete(recursive: true);
    });

    test('Dead descriptor with a possible orphan runtime: verifies orphan and recovers without duplicate spawn', () async {
      final tempDir = await Directory.systemTemp.createTemp('dead_desc_orphan_test_');
      final tempLockFile = File('${tempDir.path}\\runtime.lock');
      await tempLockFile.writeAsString('');
      final realHandle = await tempLockFile.open(mode: FileMode.append);

      final orphanStartTime = DateTime.parse('2026-10-10T12:30:00.000Z');

      final supervisor = DiscoveryControlledMockSupervisor();
      supervisor.mockHandle = realHandle;
      // Stale descriptor with dead PID 999999
      supervisor.existingDescriptor = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'stale-inst-1',
        pid: 999999,
        port: 8000,
        startedAt: DateTime.parse('2026-10-10T10:00:00.000Z'),
        executablePath: Platform.resolvedExecutable,
      );
      supervisor.isProcessActive = false; // Dead in OS table!

      // Discovery finds verified genuine orphan process PID 7777 starting up
      supervisor.discoveryResult = ProcessDiscoveryResult(
        status: ProcessDiscoveryStatus.verified,
        verifiedProcess: DiscoveredProcessIdentity(
          pid: 7777,
          executablePath: Platform.resolvedExecutable,
          commandLine: 'python -m uvicorn app.main:app --port 8000',
          creationTime: orphanStartTime,
        ),
      );

      final fastClient = DelayedAuthClient(authDelay: Duration.zero);

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        client: fastClient,
        customLockFile: tempLockFile,
        customExecutablePath: Platform.resolvedExecutable,
      );

      Future.delayed(const Duration(milliseconds: 50), () {
        supervisor.isListening = true;
      });

      final result = await coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 5));

      // 1. Never spawned duplicate
      expect(supervisor.spawnCallCount, equals(0));
      // 2. Overwrote dead descriptor with genuine orphan metadata (NOT fabricated DateTime.now())
      expect(supervisor.writtenDescriptor, isNotNull);
      expect(supervisor.writtenDescriptor?.pid, equals(7777));
      expect(supervisor.writtenDescriptor?.startedAt, equals(orphanStartTime));
      // 3. Adopted verified orphan and transitioned to ready
      expect(result.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(result.pid, equals(7777));

      coordinator.dispose();
      await realHandle.close();
      await tempDir.delete(recursive: true);
    });

    test('Unavailable process inspection: fails closed without spawning duplicate', () async {
      final tempDir = await Directory.systemTemp.createTemp('inspection_unavailable_test_');
      final tempLockFile = File('${tempDir.path}\\runtime.lock');
      await tempLockFile.writeAsString('');
      final realHandle = await tempLockFile.open(mode: FileMode.append);

      final supervisor = DiscoveryControlledMockSupervisor();
      supervisor.mockHandle = realHandle;
      supervisor.discoveryResult = const ProcessDiscoveryResult(
        status: ProcessDiscoveryStatus.inspectionUnavailable,
        diagnostic: 'WMI query access denied',
      );

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        customLockFile: tempLockFile,
        customExecutablePath: Platform.resolvedExecutable,
      );

      final result = await coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 5));

      expect(result.status, equals(RuntimeStatus.startupTimeout));
      expect(result.diagnosticMessage, contains('inspection unavailable'));
      expect(supervisor.spawnCallCount, equals(0));

      coordinator.dispose();
      await realHandle.close();
      await tempDir.delete(recursive: true);
    });

    test('Verified recovery without duplicate spawning: adopts verified process with genuine OS creation time', () async {
      final tempDir = await Directory.systemTemp.createTemp('verified_recovery_test_');
      final tempLockFile = File('${tempDir.path}\\runtime.lock');
      await tempLockFile.writeAsString('');
      final realHandle = await tempLockFile.open(mode: FileMode.append);

      final genuineCreationTime = DateTime.parse('2026-10-10T14:15:20.000Z');

      final supervisor = DiscoveryControlledMockSupervisor();
      supervisor.mockHandle = realHandle;
      supervisor.discoveryResult = ProcessDiscoveryResult(
        status: ProcessDiscoveryStatus.verified,
        verifiedProcess: DiscoveredProcessIdentity(
          pid: 8888,
          executablePath: Platform.resolvedExecutable,
          commandLine: 'python -m uvicorn app.main:app --port 8000',
          creationTime: genuineCreationTime,
        ),
      );

      final fastClient = DelayedAuthClient(authDelay: Duration.zero);

      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        client: fastClient,
        customLockFile: tempLockFile,
        customExecutablePath: Platform.resolvedExecutable,
      );

      Future.delayed(const Duration(milliseconds: 50), () {
        supervisor.isListening = true;
      });

      final result = await coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 5));

      expect(supervisor.spawnCallCount, equals(0));
      expect(supervisor.writtenDescriptor, isNotNull);
      expect(supervisor.writtenDescriptor?.pid, equals(8888));
      expect(supervisor.writtenDescriptor?.startedAt, equals(genuineCreationTime));
      expect(result.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(result.pid, equals(8888));

      coordinator.dispose();
      await realHandle.close();
      await tempDir.delete(recursive: true);
    });
  });
}
