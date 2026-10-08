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

/// Platform-neutral contract for reading diagnostic storage root information.
abstract interface class StorageDiagnosticReader {
  Future<List<StorageDiagnosticInfo>> readDiagnosticRoots();
}
