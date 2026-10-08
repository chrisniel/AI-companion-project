import 'dart:convert';
import 'package:meta/meta.dart';

/// The canonical five storage roots defined in storage-and-assets.md.
enum StorageRootType {
  appInstall,
  data,
  library,
  cache,
  log,
}

/// Evaluation status of a storage locator (e.g. bootstrap.json).
/// Distinguishes syntactic validity from filesystem availability.
enum LocatorStatus {
  /// The locator file does not exist on disk.
  absent,

  /// The locator file exists but contains invalid JSON or schema errors.
  corrupt,

  /// The locator path is syntactically valid, but target directory does not exist.
  validUnavailable,

  /// The locator path is syntactically valid and accessible on disk.
  validAvailable,
}

/// Provenance of the reported storage root information.
enum StorageRootSource {
  /// Reported by the backend runtime telemetry (authoritative).
  backendTelemetry,

  /// Inspected locally by client platform adapter (diagnostic candidate).
  localDiagnostic,
}

/// Read-only diagnostic representation of a storage root.
@immutable
class StorageDiagnosticInfo {
  final StorageRootType rootType;
  final String? resolvedPath;
  final LocatorStatus locatorStatus;
  final StorageRootSource source;
  final String? details;

  const StorageDiagnosticInfo({
    required this.rootType,
    required this.locatorStatus,
    required this.source,
    this.resolvedPath,
    this.details,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageDiagnosticInfo &&
          runtimeType == other.runtimeType &&
          rootType == other.rootType &&
          resolvedPath == other.resolvedPath &&
          locatorStatus == other.locatorStatus &&
          source == other.source &&
          details == other.details;

  @override
  int get hashCode => Object.hash(
        rootType,
        resolvedPath,
        locatorStatus,
        source,
        details,
      );

  @override
  String toString() =>
      'StorageDiagnosticInfo(rootType: $rootType, resolvedPath: $resolvedPath, status: $locatorStatus, source: $source)';
}

/// Checks whether a given path string is absolute across Windows, POSIX, and UNC formats.
bool isAbsolutePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('/') || trimmed.startsWith(r'\\')) return true;
  if (trimmed.length >= 3 && RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(trimmed)) {
    return true;
  }
  return false;
}

/// Pure-Dart evaluator for bootstrap locator content.
/// Distinguishes absent, corrupt, validAvailable, and validUnavailable without platform side-effects.
StorageDiagnosticInfo evaluateBootstrapLocatorContent({
  required bool fileExists,
  String? rawJson,
  bool Function(String path)? pathExistsChecker,
  StorageRootType rootType = StorageRootType.data,
  StorageRootSource source = StorageRootSource.localDiagnostic,
}) {
  if (!fileExists || rawJson == null) {
    return StorageDiagnosticInfo(
      rootType: rootType,
      locatorStatus: LocatorStatus.absent,
      source: source,
      details: 'Bootstrap locator file not found on disk.',
    );
  }

  if (rawJson.trim().isEmpty) {
    return StorageDiagnosticInfo(
      rootType: rootType,
      locatorStatus: LocatorStatus.corrupt,
      source: source,
      details: 'Bootstrap locator file is empty.',
    );
  }

  try {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      return StorageDiagnosticInfo(
        rootType: rootType,
        locatorStatus: LocatorStatus.corrupt,
        source: source,
        details: 'Locator JSON must be an object.',
      );
    }

    final schemaVersion = decoded['schema_version'];
    if (schemaVersion is! int || schemaVersion != 1) {
      return StorageDiagnosticInfo(
        rootType: rootType,
        locatorStatus: LocatorStatus.corrupt,
        source: source,
        details: 'Invalid or missing schema_version (expected integer 1).',
      );
    }

    final dataRoot = decoded['data_root'];
    if (dataRoot is! String || dataRoot.trim().isEmpty) {
      return StorageDiagnosticInfo(
        rootType: rootType,
        locatorStatus: LocatorStatus.corrupt,
        source: source,
        details: 'Invalid or missing data_root path.',
      );
    }

    final trimmedPath = dataRoot.trim();
    if (!isAbsolutePath(trimmedPath)) {
      return StorageDiagnosticInfo(
        rootType: rootType,
        locatorStatus: LocatorStatus.corrupt,
        source: source,
        details: 'Configured data_root must be an absolute path: "$trimmedPath"',
      );
    }

    final exists = pathExistsChecker != null ? pathExistsChecker(trimmedPath) : true;
    if (exists) {
      return StorageDiagnosticInfo(
        rootType: rootType,
        resolvedPath: trimmedPath,
        locatorStatus: LocatorStatus.validAvailable,
        source: source,
        details: 'Configured data root directory exists on disk.',
      );
    } else {
      return StorageDiagnosticInfo(
        rootType: rootType,
        resolvedPath: trimmedPath,
        locatorStatus: LocatorStatus.validUnavailable,
        source: source,
        details: 'Configured data root path is valid but does not exist on disk.',
      );
    }
  } catch (e) {
    return StorageDiagnosticInfo(
      rootType: rootType,
      locatorStatus: LocatorStatus.corrupt,
      source: source,
      details: 'Malformed JSON syntax: $e',
    );
  }
}

/// Platform-neutral contract for reading diagnostic storage root information.
abstract interface class StorageDiagnosticReader {
  Future<List<StorageDiagnosticInfo>> readDiagnosticRoots();
}
