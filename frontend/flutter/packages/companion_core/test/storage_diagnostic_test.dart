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

  group('isAbsolutePath and isWindowsAbsolutePath', () {
    test('identifies absolute paths across formats', () {
      expect(isAbsolutePath(r'C:\Users\Admin\Data'), isTrue);
      expect(isAbsolutePath('D:/AI-companion-project'), isTrue);
      expect(isAbsolutePath('/home/user/companion'), isTrue);
      expect(isAbsolutePath(r'\\server\share\data'), isTrue);

      expect(isAbsolutePath('relative/path'), isFalse);
      expect(isAbsolutePath(r'.\relative\path'), isFalse);
      expect(isAbsolutePath('../relative'), isFalse);
      expect(isAbsolutePath(''), isFalse);
    });

    test('validates Windows-specific absolute paths correctly', () {
      expect(isWindowsAbsolutePath(r'C:\Users\Admin\Data'), isTrue);
      expect(isWindowsAbsolutePath('D:/AI-companion-project'), isTrue);
      expect(isWindowsAbsolutePath(r'\\server\share\data'), isTrue);

      // POSIX root is not a valid Windows absolute path
      expect(isWindowsAbsolutePath('/home/user/companion'), isFalse);
      expect(isWindowsAbsolutePath('/data'), isFalse);
      expect(isWindowsAbsolutePath('relative/path'), isFalse);
    });
  });

  group('evaluateBootstrapLocatorContent', () {
    test('returns absent when fileExists is false', () {
      final res1 = evaluateBootstrapLocatorContent(fileExists: false, rawJson: null);
      expect(res1.locatorStatus, equals(LocatorStatus.absent));
      expect(res1.resolvedPath, isNull);
      expect(res1.details, contains('not found on disk'));

      final res2 = evaluateBootstrapLocatorContent(fileExists: false, rawJson: '{"schema_version": 1}');
      expect(res2.locatorStatus, equals(LocatorStatus.absent));
    });

    test('returns corrupt (fail closed) when file exists but read fails (rawJson == null)', () {
      final res = evaluateBootstrapLocatorContent(fileExists: true, rawJson: null);
      expect(res.locatorStatus, equals(LocatorStatus.corrupt));
      expect(res.resolvedPath, isNull);
      expect(res.details, contains('could not be read'));
    });

    test('returns corrupt when JSON is invalid, empty, or wrong type', () {
      final resEmpty = evaluateBootstrapLocatorContent(fileExists: true, rawJson: '');
      expect(resEmpty.locatorStatus, equals(LocatorStatus.corrupt));

      final resSyntax = evaluateBootstrapLocatorContent(fileExists: true, rawJson: '{not-json');
      expect(resSyntax.locatorStatus, equals(LocatorStatus.corrupt));

      final resList = evaluateBootstrapLocatorContent(fileExists: true, rawJson: '[1, 2, 3]');
      expect(resList.locatorStatus, equals(LocatorStatus.corrupt));
    });

    test('returns corrupt when schema_version is missing or invalid', () {
      final resNoVer = evaluateBootstrapLocatorContent(
        fileExists: true,
        rawJson: '{"data_root": "C:\\\\Data"}',
      );
      expect(resNoVer.locatorStatus, equals(LocatorStatus.corrupt));

      final resWrongVer = evaluateBootstrapLocatorContent(
        fileExists: true,
        rawJson: '{"schema_version": 2, "data_root": "C:\\\\Data"}',
      );
      expect(resWrongVer.locatorStatus, equals(LocatorStatus.corrupt));
    });

    test('returns corrupt when data_root is missing, empty, or relative', () {
      final resNoRoot = evaluateBootstrapLocatorContent(
        fileExists: true,
        rawJson: '{"schema_version": 1}',
      );
      expect(resNoRoot.locatorStatus, equals(LocatorStatus.corrupt));

      final resEmptyRoot = evaluateBootstrapLocatorContent(
        fileExists: true,
        rawJson: '{"schema_version": 1, "data_root": "   "}',
      );
      expect(resEmptyRoot.locatorStatus, equals(LocatorStatus.corrupt));

      final resRelative = evaluateBootstrapLocatorContent(
        fileExists: true,
        rawJson: '{"schema_version": 1, "data_root": "relative/path"}',
      );
      expect(resRelative.locatorStatus, equals(LocatorStatus.corrupt));
    });

    test('rejects POSIX path on Windows when isWindows is true', () {
      final res = evaluateBootstrapLocatorContent(
        fileExists: true,
        rawJson: '{"schema_version": 1, "data_root": "/home/user/companion"}',
        isWindows: true,
      );
      expect(res.locatorStatus, equals(LocatorStatus.corrupt));
      expect(res.details, contains('valid absolute Windows path'));
    });

    test('accepts POSIX path in platform-neutral mode (isWindows is false)', () {
      final res = evaluateBootstrapLocatorContent(
        fileExists: true,
        rawJson: '{"schema_version": 1, "data_root": "/home/user/companion"}',
        isWindows: false,
        pathExistsChecker: (p) => true,
      );
      expect(res.locatorStatus, equals(LocatorStatus.validAvailable));
    });

    test('returns validAvailable when path is absolute and directory exists', () {
      final res = evaluateBootstrapLocatorContent(
        fileExists: true,
        rawJson: '{"schema_version": 1, "data_root": "D:\\\\CompanionData"}',
        isWindows: true,
        pathExistsChecker: (p) => p == r'D:\CompanionData',
      );
      expect(res.locatorStatus, equals(LocatorStatus.validAvailable));
      expect(res.resolvedPath, equals(r'D:\CompanionData'));
      expect(res.source, equals(StorageRootSource.localDiagnostic));
    });

    test('returns validUnavailable when path is absolute but directory does not exist', () {
      final res = evaluateBootstrapLocatorContent(
        fileExists: true,
        rawJson: '{"schema_version": 1, "data_root": "D:\\\\NonExistentData"}',
        isWindows: true,
        pathExistsChecker: (p) => false,
      );
      expect(res.locatorStatus, equals(LocatorStatus.validUnavailable));
      expect(res.resolvedPath, equals(r'D:\NonExistentData'));
      expect(res.source, equals(StorageRootSource.localDiagnostic));
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
