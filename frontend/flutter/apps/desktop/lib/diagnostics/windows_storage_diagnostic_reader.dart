import 'dart:io';
import 'package:companion_core/companion_core.dart';

/// Concrete Windows diagnostic reader that inspects storage roots in a strictly read-only, fail-closed manner.
class WindowsStorageDiagnosticReader implements StorageDiagnosticReader {
  WindowsStorageDiagnosticReader({
    String? localAppDataOverride,
    String? appInstallDirOverride,
    bool Function(String path)? fileExistsChecker,
    String? Function(String path)? fileReader,
    bool Function(String path)? directoryExistsChecker,
  })  : _localAppDataOverride = localAppDataOverride,
        _appInstallDirOverride = appInstallDirOverride,
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
  final String? _appInstallDirOverride;
  final bool Function(String path) _fileExistsChecker;
  final String? Function(String path) _fileReader;
  final bool Function(String path) _directoryExistsChecker;

  String? get _resolvedLocalAppData {
    final val = _localAppDataOverride ?? Platform.environment['LOCALAPPDATA'];
    if (val == null || val.trim().isEmpty) return null;
    return val.trim();
  }

  /// Returns the canonical bootstrap locator path: %LOCALAPPDATA%\AI Companion\bootstrap.json,
  /// or null if LOCALAPPDATA is unavailable.
  String? getBootstrapLocatorPath() {
    final base = _resolvedLocalAppData;
    if (base == null) return null;
    return '$base\\AI Companion\\bootstrap.json';
  }

  /// Returns default OS data root: %LOCALAPPDATA%\AI Companion\Data,
  /// or null if LOCALAPPDATA is unavailable.
  String? getDefaultDataRoot() {
    final base = _resolvedLocalAppData;
    if (base == null) return null;
    return '$base\\AI Companion\\Data';
  }

  /// Returns the local application install directory based on executable location.
  String? getAppInstallDirectory() {
    if (_appInstallDirOverride != null) return _appInstallDirOverride;
    try {
      final exec = Platform.resolvedExecutable;
      if (exec.isNotEmpty) {
        return File(exec).parent.path;
      }
    } catch (_) {}
    return null;
  }

  /// Evaluates the bootstrap locator file and returns its diagnostic status.
  StorageDiagnosticInfo readBootstrapDiagnostic() {
    final bootstrapPath = getBootstrapLocatorPath();
    if (bootstrapPath == null) {
      return const StorageDiagnosticInfo(
        rootType: StorageRootType.data,
        locatorStatus: LocatorStatus.validUnavailable,
        source: StorageRootSource.localDiagnostic,
        details: 'LOCALAPPDATA environment variable is unavailable on host.',
      );
    }

    final fileExists = _fileExistsChecker(bootstrapPath);
    final rawJson = fileExists ? _fileReader(bootstrapPath) : null;

    return evaluateBootstrapLocatorContent(
      fileExists: fileExists,
      rawJson: rawJson,
      pathExistsChecker: _directoryExistsChecker,
      isWindows: true,
      rootType: StorageRootType.data,
      source: StorageRootSource.localDiagnostic,
    );
  }

  @override
  Future<List<StorageDiagnosticInfo>> readDiagnosticRoots() async {
    final roots = <StorageDiagnosticInfo>[];

    // 1. DATA root (evaluated via bootstrap locator with fail-closed semantics)
    final bootstrapInfo = readBootstrapDiagnostic();
    roots.add(bootstrapInfo);

    // Only if bootstrap locator is verified absent (not corrupt/unreadable) do we assess default OS root
    if (bootstrapInfo.locatorStatus == LocatorStatus.absent) {
      final defaultData = getDefaultDataRoot();
      if (defaultData != null) {
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
    }

    // 2. APP_INSTALL root (derived from client executable location)
    final appInstallDir = getAppInstallDirectory();
    if (appInstallDir != null) {
      final installExists = _directoryExistsChecker(appInstallDir);
      roots.add(
        StorageDiagnosticInfo(
          rootType: StorageRootType.appInstall,
          resolvedPath: appInstallDir,
          locatorStatus:
              installExists ? LocatorStatus.validAvailable : LocatorStatus.validUnavailable,
          source: StorageRootSource.localDiagnostic,
          details: 'Local client application executable directory.',
        ),
      );
    } else {
      roots.add(
        const StorageDiagnosticInfo(
          rootType: StorageRootType.appInstall,
          resolvedPath: null,
          locatorStatus: LocatorStatus.validUnavailable,
          source: StorageRootSource.localDiagnostic,
          details: 'Application executable location could not be determined.',
        ),
      );
    }

    // 3. LIBRARY root (awareness only; no authoritative backend reporting API in M1)
    roots.add(
      const StorageDiagnosticInfo(
        rootType: StorageRootType.library,
        resolvedPath: null,
        locatorStatus: LocatorStatus.absent,
        source: StorageRootSource.localDiagnostic,
        details: 'Not reported by backend',
      ),
    );

    return roots;
  }
}
