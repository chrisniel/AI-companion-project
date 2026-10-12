import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('RuntimeProcessState', () {
    test('separates supervision mode from runtime status', () {
      const remoteUnauthenticated = RuntimeProcessState(
        supervisionMode: SupervisionMode.remoteHost,
        status: RuntimeStatus.reachableUnauthenticated,
        port: 8000,
        diagnosticMessage: 'Pairing token rejected by remote companion host.',
      );
      expect(remoteUnauthenticated.isLocalSupervised, isFalse);
      expect(remoteUnauthenticated.isOperational, isFalse);
      expect(remoteUnauthenticated.canSendMessages, isFalse);
      expect(remoteUnauthenticated.diagnosticMessage, contains('Pairing token rejected'));

      const localReady = RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.readyAndAuthenticated,
        pid: 1234,
        port: 8000,
      );
      expect(localReady.isLocalSupervised, isTrue);
      expect(localReady.isOperational, isTrue);
      expect(localReady.canSendMessages, isTrue);
      expect(localReady.pid, equals(1234));
    });

    test('predicates report correct states for dormant, launching, conflict, and timeout', () {
      const dormant = RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.dormant,
        port: 8000,
      );
      expect(dormant.isOperational, isFalse);
      expect(dormant.canSendMessages, isFalse);

      const conflict = RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.alienPortConflict,
        port: 8000,
        diagnosticMessage: 'Port 8000 occupied by alien process.',
      );
      expect(conflict.isOperational, isFalse);
      expect(conflict.canSendMessages, isFalse);

      const unresponsive = RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.processUnresponsive,
        pid: 9999,
        port: 8000,
      );
      expect(unresponsive.isOperational, isFalse);
      expect(unresponsive.pid, equals(9999));
    });

    test('copyWith works accurately for state updates', () {
      const initial = RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.dormant,
        port: 8000,
      );
      final updated = initial.copyWith(
        status: RuntimeStatus.readyAndAuthenticated,
        pid: 5678,
      );
      expect(updated.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(updated.pid, equals(5678));
      expect(updated.port, equals(8000));
      expect(updated.supervisionMode, equals(SupervisionMode.localLoopback));
    });
  });
}
