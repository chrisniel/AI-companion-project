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

    test('returns null paths and unavailable status when LOCALAPPDATA is unset', () async {
      final reader = WindowsStorageDiagnosticReader(
        localAppDataOverride: '', // empty/unset override
      );

      expect(reader.getBootstrapLocatorPath(), isNull);
      expect(reader.getDefaultDataRoot(), isNull);

      final diagnostic = reader.readBootstrapDiagnostic();
      expect(diagnostic.locatorStatus, equals(LocatorStatus.validUnavailable));
      expect(diagnostic.resolvedPath, isNull);
      expect(diagnostic.details, contains('LOCALAPPDATA environment variable is unavailable'));
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
      expect(roots.length, greaterThanOrEqualTo(3));
      // First is absent bootstrap
      expect(roots[0].locatorStatus, equals(LocatorStatus.absent));
      // Second is default data candidate (evaluated because bootstrap was absent)
      expect(roots[1].rootType, equals(StorageRootType.data));
    });

    test('reports corrupt on existing file read failure and does not fall back to default data root', () async {
      final reader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Test\AppData\Local',
        fileExistsChecker: (path) => true,
        fileReader: (path) => null, // Read failure
        directoryExistsChecker: (path) => true,
      );

      final diagnostic = reader.readBootstrapDiagnostic();
      expect(diagnostic.locatorStatus, equals(LocatorStatus.corrupt));
      expect(diagnostic.details, contains('could not be read'));

      final roots = await reader.readDiagnosticRoots();
      // Must NOT contain a second default DATA root when bootstrap is corrupt (fails closed)
      final dataRoots = roots.where((r) => r.rootType == StorageRootType.data).toList();
      expect(dataRoots.length, equals(1));
      expect(dataRoots.first.locatorStatus, equals(LocatorStatus.corrupt));
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

    test('rejects POSIX data_root as corrupt under Windows semantics', () async {
      final reader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Test\AppData\Local',
        fileExistsChecker: (path) => true,
        fileReader: (path) =>
            '{"schema_version": 1, "data_root": "/home/user/companion"}',
      );

      final diagnostic = reader.readBootstrapDiagnostic();
      expect(diagnostic.locatorStatus, equals(LocatorStatus.corrupt));
      expect(diagnostic.details, contains('valid absolute Windows path'));
    });

    test('reports validAvailable when locator points to existing Windows directory', () async {
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

    test('reports M1 storage roots awareness for APP_INSTALL, DATA, and LIBRARY', () async {
      final reader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Test\AppData\Local',
        appInstallDirOverride: r'C:\Program Files\AI Companion',
        fileExistsChecker: (path) => false,
        directoryExistsChecker: (path) => true,
      );

      final roots = await reader.readDiagnosticRoots();
      final types = roots.map((r) => r.rootType).toSet();
      expect(types, contains(StorageRootType.data));
      expect(types, contains(StorageRootType.appInstall));
      expect(types, contains(StorageRootType.library));

      final libraryRoot = roots.firstWhere((r) => r.rootType == StorageRootType.library);
      expect(libraryRoot.resolvedPath, isNull);
      expect(libraryRoot.details, contains('Not reported by backend'));

      final installRoot = roots.firstWhere((r) => r.rootType == StorageRootType.appInstall);
      expect(installRoot.resolvedPath, equals(r'C:\Program Files\AI Companion'));
      expect(installRoot.locatorStatus, equals(LocatorStatus.validAvailable));
    });
  });
}
