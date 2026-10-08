import 'package:ai_companion_desktop/diagnostics/windows_storage_diagnostic_reader.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowsStorageDiagnosticReader', () {
    test('constructs default paths from localAppDataOverride', () {
      final reader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Users\TestUser\AppData\Local',
      );

      expect(
        reader.getBootstrapLocatorPath(),
        equals(r'C:\Users\TestUser\AppData\Local\AI Companion\bootstrap.json'),
      );
      expect(
        reader.getDefaultDataRoot(),
        equals(r'C:\Users\TestUser\AppData\Local\AI Companion\Data'),
      );
    });

    test('reports absent when locator file does not exist', () async {
      final reader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Test\AppData\Local',
        fileExistsChecker: (path) => false,
        directoryExistsChecker: (path) => false,
      );

      final diagnostic = reader.readBootstrapDiagnostic();
      expect(diagnostic.locatorStatus, equals(LocatorStatus.absent));
      expect(diagnostic.resolvedPath, isNull);
      expect(diagnostic.source, equals(StorageRootSource.localDiagnostic));

      final roots = await reader.readDiagnosticRoots();
      expect(roots.length, greaterThanOrEqualTo(2));
      expect(roots.first.locatorStatus, equals(LocatorStatus.absent));
    });

    test('reports corrupt when locator file contains invalid JSON', () async {
      final reader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Test\AppData\Local',
        fileExistsChecker: (path) => true,
        fileReader: (path) => 'not-valid-json',
      );

      final diagnostic = reader.readBootstrapDiagnostic();
      expect(diagnostic.locatorStatus, equals(LocatorStatus.corrupt));
      expect(diagnostic.details, contains('Malformed JSON syntax'));
    });

    test('reports validAvailable when locator points to existing directory', () async {
      final reader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Test\AppData\Local',
        fileExistsChecker: (path) => true,
        fileReader: (path) =>
            '{"schema_version": 1, "data_root": "D:\\\\CustomData"}',
        directoryExistsChecker: (path) => path == r'D:\CustomData',
      );

      final diagnostic = reader.readBootstrapDiagnostic();
      expect(diagnostic.locatorStatus, equals(LocatorStatus.validAvailable));
      expect(diagnostic.resolvedPath, equals(r'D:\CustomData'));
    });

    test('reports validUnavailable when locator points to missing directory', () async {
      final reader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Test\AppData\Local',
        fileExistsChecker: (path) => true,
        fileReader: (path) =>
            '{"schema_version": 1, "data_root": "D:\\\\MissingDir"}',
        directoryExistsChecker: (path) => false,
      );

      final diagnostic = reader.readBootstrapDiagnostic();
      expect(diagnostic.locatorStatus, equals(LocatorStatus.validUnavailable));
      expect(diagnostic.resolvedPath, equals(r'D:\MissingDir'));
    });
  });
}
