import 'dart:io';
import 'package:companion_core/companion_core.dart';

/// Concrete Windows diagnostic reader that inspects storage roots in a strictly read-only, fail-closed manner.
class WindowsStorageDiagnosticReader implements StorageDiagnosticReader {
  WindowsStorageDiagnosticReader({
    String? localAppDataOverride,
    bool Function(String path)? fileExistsChecker,
    String? Function(String path)? fileReader,
    bool Function(String path)? directoryExistsChecker,
  })  : _localAppDataOverride = localAppDataOverride,
        _fileExistsChecker = fileExistsChecker ?? ((p) => File(p).existsSync()),
        _fileReader = fileReader ??
            ((p) {
              try {
                return File(p).readAsStringSync();
              } catch (_) {
                return null;
              }
            }),
        _directoryExistsChecker =
            directoryExistsChecker ?? ((p) => Directory(p).existsSync());

  final String? _localAppDataOverride;
  final bool Function(String path) _fileExistsChecker;
  final String? Function(String path) _fileReader;
  final bool Function(String path) _directoryExistsChecker;

  /// Returns the canonical bootstrap locator path: %LOCALAPPDATA%\AI Companion\bootstrap.json
  String getBootstrapLocatorPath() {
    final localAppData = _localAppDataOverride ??
        Platform.environment['LOCALAPPDATA'] ??
        r'C:\Users\Default\AppData\Local';
    return '$localAppData\\AI Companion\\bootstrap.json';
  }

  /// Returns default OS data root: %LOCALAPPDATA%\AI Companion\Data
  String getDefaultDataRoot() {
    final localAppData = _localAppDataOverride ??
        Platform.environment['LOCALAPPDATA'] ??
        r'C:\Users\Default\AppData\Local';
    return '$localAppData\\AI Companion\\Data';
  }

  /// Evaluates the bootstrap locator file and returns its diagnostic status.
  StorageDiagnosticInfo readBootstrapDiagnostic() {
    final bootstrapPath = getBootstrapLocatorPath();
    final fileExists = _fileExistsChecker(bootstrapPath);
    final rawJson = fileExists ? _fileReader(bootstrapPath) : null;

    return evaluateBootstrapLocatorContent(
      fileExists: fileExists,
      rawJson: rawJson,
      pathExistsChecker: _directoryExistsChecker,
      rootType: StorageRootType.data,
      source: StorageRootSource.localDiagnostic,
    );
  }

  @override
  Future<List<StorageDiagnosticInfo>> readDiagnosticRoots() async {
    final roots = <StorageDiagnosticInfo>[];
    final bootstrapInfo = readBootstrapDiagnostic();
    roots.add(bootstrapInfo);

    // If bootstrap locator is absent, evaluate default OS data root
    if (bootstrapInfo.locatorStatus == LocatorStatus.absent) {
      final defaultData = getDefaultDataRoot();
      final exists = _directoryExistsChecker(defaultData);
      roots.add(
        StorageDiagnosticInfo(
          rootType: StorageRootType.data,
          resolvedPath: defaultData,
          locatorStatus:
              exists ? LocatorStatus.validAvailable : LocatorStatus.validUnavailable,
          source: StorageRootSource.localDiagnostic,
          details: exists
              ? 'Default OS data root exists on disk.'
              : 'Default OS data root does not yet exist on disk.',
        ),
      );
    }

    final localAppData = _localAppDataOverride ??
        Platform.environment['LOCALAPPDATA'] ??
        r'C:\Users\Default\AppData\Local';
    final companionBase = '$localAppData\\AI Companion';

    final logsPath = '$companionBase\\Logs';
    roots.add(
      StorageDiagnosticInfo(
        rootType: StorageRootType.log,
        resolvedPath: logsPath,
        locatorStatus: _directoryExistsChecker(logsPath)
            ? LocatorStatus.validAvailable
            : LocatorStatus.validUnavailable,
        source: StorageRootSource.localDiagnostic,
        details: 'Diagnostic OS log root candidate.',
      ),
    );

    return roots;
  }
}
