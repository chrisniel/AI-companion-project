import 'package:meta/meta.dart';

/// DTO representing host machine runtime status from GET /api/v1/system/status.
@immutable
class SystemStatusResponse {
  final String status;
  final String platform;
  final String pythonVersion;
  final String hostname;
  final int? cpuCount;
  final String version;
  final bool databaseConnected;
  final String timestamp;

  const SystemStatusResponse({
    this.status = 'online',
    required this.platform,
    required this.pythonVersion,
    required this.hostname,
    this.cpuCount,
    required this.version,
    required this.databaseConnected,
    required this.timestamp,
  });

  factory SystemStatusResponse.fromJson(Map<String, dynamic> json) {
    final statusVal = json['status'] as String? ?? 'online';
    final platformVal = json['platform'];
    if (platformVal is! String) {
      throw FormatException('SystemStatusResponse: platform must be a string, got $platformVal');
    }

    final pythonVersionVal = json['python_version'];
    if (pythonVersionVal is! String) {
      throw FormatException(
          'SystemStatusResponse: python_version must be a string, got $pythonVersionVal');
    }

    final hostnameVal = json['hostname'];
    if (hostnameVal is! String) {
      throw FormatException('SystemStatusResponse: hostname must be a string, got $hostnameVal');
    }

    final cpuCountVal = json['cpu_count'];
    if (cpuCountVal != null && cpuCountVal is! int) {
      throw FormatException('SystemStatusResponse: cpu_count must be an int?, got $cpuCountVal');
    }

    final versionVal = json['version'];
    if (versionVal is! String) {
      throw FormatException('SystemStatusResponse: version must be a string, got $versionVal');
    }

    final dbConnectedVal = json['database_connected'];
    if (dbConnectedVal is! bool) {
      throw FormatException(
          'SystemStatusResponse: database_connected must be a bool, got $dbConnectedVal');
    }

    final timestampVal = json['timestamp'];
    if (timestampVal is! String) {
      throw FormatException('SystemStatusResponse: timestamp must be a string, got $timestampVal');
    }

    return SystemStatusResponse(
      status: statusVal,
      platform: platformVal,
      pythonVersion: pythonVersionVal,
      hostname: hostnameVal,
      cpuCount: cpuCountVal as int?,
      version: versionVal,
      databaseConnected: dbConnectedVal,
      timestamp: timestampVal,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'platform': platform,
        'python_version': pythonVersion,
        'hostname': hostname,
        'cpu_count': cpuCount,
        'version': version,
        'database_connected': databaseConnected,
        'timestamp': timestamp,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemStatusResponse &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          platform == other.platform &&
          pythonVersion == other.pythonVersion &&
          hostname == other.hostname &&
          cpuCount == other.cpuCount &&
          version == other.version &&
          databaseConnected == other.databaseConnected &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        status,
        platform,
        pythonVersion,
        hostname,
        cpuCount,
        version,
        databaseConnected,
        timestamp,
      );

  @override
  String toString() =>
      'SystemStatusResponse(status: $status, platform: $platform, hostname: $hostname, dbConnected: $databaseConnected)';
}
