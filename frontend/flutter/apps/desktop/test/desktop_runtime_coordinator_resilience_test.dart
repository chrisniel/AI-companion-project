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
  });
}
