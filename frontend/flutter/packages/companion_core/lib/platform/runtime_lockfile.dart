import 'dart:convert';
import 'package:meta/meta.dart';

/// Descriptor schema recorded in the atomic runtime lockfile (%LOCALAPPDATA%\AI Companion\runtime.lock).
@immutable
class RuntimeLockfileData {
  /// Schema version format identifier. Must equal 1 for PC V1.
  final int schemaVersion;

  /// Unique UUIDv4 assigned to this runtime supervisor execution instance.
  final String instanceId;

  /// Operating system process ID of the spawned background runtime.
  final int pid;

  /// HTTP port the runtime is listening on (default: 8000).
  final int port;

  /// UTC timestamp when this runtime instance was spawned.
  final DateTime startedAt;

  /// Full absolute path of the executable image used to launch this instance.
  final String executablePath;

  const RuntimeLockfileData({
    required this.schemaVersion,
    required this.instanceId,
    required this.pid,
    required this.port,
    required this.startedAt,
    required this.executablePath,
  });

  /// Serializes descriptor to a JSON string.
  String toRawJson() => json.encode(toJson());

  /// Deserializes descriptor from a JSON string with fail-closed validation.
  factory RuntimeLockfileData.fromRawJson(String str) {
    try {
      final decoded = json.decode(str);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Lockfile descriptor root must be a JSON object.');
      }
      return RuntimeLockfileData.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Failed to parse lockfile descriptor JSON: $e');
    }
  }

  /// Deserializes descriptor from a Map with strict schema validation.
  factory RuntimeLockfileData.fromJson(Map<String, dynamic> json) {
    final version = json['schema_version'];
    if (version == null || version is! int || version != 1) {
      throw const FormatException('Unsupported or missing schema_version (expected 1).');
    }

    final instanceId = json['instance_id'];
    if (instanceId == null || instanceId is! String || instanceId.trim().isEmpty) {
      throw const FormatException('Missing or invalid instance_id.');
    }

    final pid = json['pid'];
    if (pid == null || pid is! int || pid <= 0) {
      throw const FormatException('Missing or invalid pid (must be positive integer).');
    }

    final port = json['port'];
    if (port == null || port is! int || port <= 0 || port > 65535) {
      throw const FormatException('Missing or invalid port number.');
    }

    final startedAtRaw = json['started_at'];
    if (startedAtRaw == null || startedAtRaw is! String) {
      throw const FormatException('Missing started_at timestamp string.');
    }
    final startedAt = DateTime.tryParse(startedAtRaw)?.toUtc();
    if (startedAt == null) {
      throw const FormatException('Unparseable started_at ISO-8601 timestamp.');
    }

    final executablePath = json['executable_path'];
    if (executablePath == null || executablePath is! String || executablePath.trim().isEmpty) {
      throw const FormatException('Missing or invalid executable_path.');
    }

    return RuntimeLockfileData(
      schemaVersion: version,
      instanceId: instanceId,
      pid: pid,
      port: port,
      startedAt: startedAt,
      executablePath: executablePath,
    );
  }

  /// Serializes descriptor to a Map.
  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'instance_id': instanceId,
        'pid': pid,
        'port': port,
        'started_at': startedAt.toUtc().toIso8601String(),
        'executable_path': executablePath,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeLockfileData &&
          runtimeType == other.runtimeType &&
          schemaVersion == other.schemaVersion &&
          instanceId == other.instanceId &&
          pid == other.pid &&
          port == other.port &&
          startedAt == other.startedAt &&
          executablePath == other.executablePath;

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        instanceId,
        pid,
        port,
        startedAt,
        executablePath,
      );

  @override
  String toString() {
    return 'RuntimeLockfileData(v: $schemaVersion, id: $instanceId, pid: $pid, port: $port, startedAt: $startedAt, exe: $executablePath)';
  }
}
