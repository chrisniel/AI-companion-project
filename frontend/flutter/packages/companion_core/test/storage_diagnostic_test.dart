import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('StorageDiagnosticInfo', () {
    test('instantiates with valid properties and supports value equality', () {
      const info1 = StorageDiagnosticInfo(
        rootType: StorageRootType.data,
        resolvedPath: r'C:\Users\Admin\AppData\Local\AI Companion\Data',
        locatorStatus: LocatorStatus.validAvailable,
        source: StorageRootSource.localDiagnostic,
      );

      const info2 = StorageDiagnosticInfo(
        rootType: StorageRootType.data,
        resolvedPath: r'C:\Users\Admin\AppData\Local\AI Companion\Data',
        locatorStatus: LocatorStatus.validAvailable,
        source: StorageRootSource.localDiagnostic,
      );

      expect(info1, equals(info2));
      expect(info1.hashCode, equals(info2.hashCode));
      expect(info1.rootType, equals(StorageRootType.data));
      expect(info1.locatorStatus, equals(LocatorStatus.validAvailable));
      expect(info1.source, equals(StorageRootSource.localDiagnostic));
    });

    test('distinguishes different locator statuses', () {
      const absent = StorageDiagnosticInfo(
        rootType: StorageRootType.library,
        locatorStatus: LocatorStatus.absent,
        source: StorageRootSource.localDiagnostic,
      );

      const corrupt = StorageDiagnosticInfo(
        rootType: StorageRootType.library,
        locatorStatus: LocatorStatus.corrupt,
        source: StorageRootSource.localDiagnostic,
        details: 'Invalid JSON syntax',
      );

      const unavailable = StorageDiagnosticInfo(
        rootType: StorageRootType.library,
        resolvedPath: r'D:\Relocated\Library',
        locatorStatus: LocatorStatus.validUnavailable,
        source: StorageRootSource.localDiagnostic,
      );

      expect(absent.locatorStatus, equals(LocatorStatus.absent));
      expect(corrupt.locatorStatus, equals(LocatorStatus.corrupt));
      expect(unavailable.locatorStatus, equals(LocatorStatus.validUnavailable));
      expect(absent, isNot(equals(corrupt)));
    });
  });

  group('CompanionException', () {
    test('formats string representation cleanly with code', () {
      const ex = ConnectionException('Host refused connection', code: 'ECONNREFUSED');
      expect(ex.toString(), contains('ECONNREFUSED'));
      expect(ex.toString(), contains('Host refused connection'));
    });
  });
}
