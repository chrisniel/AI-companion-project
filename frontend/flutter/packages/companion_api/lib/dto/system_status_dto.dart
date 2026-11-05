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
  final bool shuttingDown;
  final String? shutdownPhase;
  final String? shutdownQuiescenceStatus;
  final int? managedLlmPid;
  final bool managedByCore;

  const SystemStatusResponse({
    this.status = 'online',
    required this.platform,
    required this.pythonVersion,
    required this.hostname,
    this.cpuCount,
    required this.version,
    required this.databaseConnected,
    required this.timestamp,
    this.shuttingDown = false,
    this.shutdownPhase,
    this.shutdownQuiescenceStatus,
    this.managedLlmPid,
    this.managedByCore = false,
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

    final shuttingDownVal = json['shutting_down'] as bool? ?? false;
    final shutdownPhaseVal = json['shutdown_phase'] as String?;
    final shutdownQuiescenceStatusVal = json['shutdown_quiescence_status'] as String?;
    final managedLlmPidVal = json['managed_llm_pid'] as int?;
    final managedByCoreVal = json['managed_by_core'] as bool? ?? false;

    return SystemStatusResponse(
      status: statusVal,
      platform: platformVal,
      pythonVersion: pythonVersionVal,
      hostname: hostnameVal,
      cpuCount: cpuCountVal as int?,
      version: versionVal,
      databaseConnected: dbConnectedVal,
      timestamp: timestampVal,
      shuttingDown: shuttingDownVal,
      shutdownPhase: shutdownPhaseVal,
      shutdownQuiescenceStatus: shutdownQuiescenceStatusVal,
      managedLlmPid: managedLlmPidVal,
      managedByCore: managedByCoreVal,
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
        if (shuttingDown) 'shutting_down': shuttingDown,
        if (shutdownPhase != null) 'shutdown_phase': shutdownPhase,
        if (shutdownQuiescenceStatus != null)
          'shutdown_quiescence_status': shutdownQuiescenceStatus,
        if (managedLlmPid != null) 'managed_llm_pid': managedLlmPid,
        if (managedByCore) 'managed_by_core': managedByCore,
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
          timestamp == other.timestamp &&
          shuttingDown == other.shuttingDown &&
          shutdownPhase == other.shutdownPhase &&
          shutdownQuiescenceStatus == other.shutdownQuiescenceStatus &&
          managedLlmPid == other.managedLlmPid &&
          managedByCore == other.managedByCore;

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
        shuttingDown,
        shutdownPhase,
        shutdownQuiescenceStatus,
        managedLlmPid,
        managedByCore,
      );

  @override
  String toString() =>
      'SystemStatusResponse(status: $status, platform: $platform, hostname: $hostname, dbConnected: $databaseConnected, shuttingDown: $shuttingDown, shutdownPhase: $shutdownPhase)';
}

/// Parameters for cooperative system shutdown via POST /api/v1/system/shutdown.
@immutable
class SystemShutdownRequest {
  final String reason;
  final double drainTimeoutSeconds;

  const SystemShutdownRequest({
    this.reason = 'user_exit_companion',
    this.drainTimeoutSeconds = 6.0,
  });

  Map<String, dynamic> toJson() => {
        'reason': reason,
        'drain_timeout_seconds': drainTimeoutSeconds,
      };
}

/// DTO representing accepted cooperative shutdown response from POST /api/v1/system/shutdown.
@immutable
class SystemShutdownResponse {
  final String status;
  final int pid;
  final int? managedLlmPid;
  final bool managedByCore;
  final bool alreadyShuttingDown;
  final String? shutdownPhase;
  final String message;

  const SystemShutdownResponse({
    this.status = 'shutting_down',
    required this.pid,
    this.managedLlmPid,
    this.managedByCore = false,
    this.alreadyShuttingDown = false,
    this.shutdownPhase,
    this.message = 'Cooperative shutdown initiated.',
  });

  factory SystemShutdownResponse.fromJson(Map<String, dynamic> json) {
    return SystemShutdownResponse(
      status: json['status'] as String? ?? 'shutting_down',
      pid: json['pid'] as int,
      managedLlmPid: json['managed_llm_pid'] as int?,
      managedByCore: json['managed_by_core'] as bool? ?? false,
      alreadyShuttingDown: json['already_shutting_down'] as bool? ?? false,
      shutdownPhase: json['shutdown_phase'] as String?,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'pid': pid,
        if (managedLlmPid != null) 'managed_llm_pid': managedLlmPid,
        'managed_by_core': managedByCore,
        'already_shutting_down': alreadyShuttingDown,
        if (shutdownPhase != null) 'shutdown_phase': shutdownPhase,
        'message': message,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemShutdownResponse &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          pid == other.pid &&
          managedLlmPid == other.managedLlmPid &&
          managedByCore == other.managedByCore &&
          alreadyShuttingDown == other.alreadyShuttingDown &&
          shutdownPhase == other.shutdownPhase &&
          message == other.message;

  @override
  int get hashCode => Object.hash(
        status,
        pid,
        managedLlmPid,
        managedByCore,
        alreadyShuttingDown,
        shutdownPhase,
        message,
      );

  @override
  String toString() =>
      'SystemShutdownResponse(status: $status, pid: $pid, alreadyShuttingDown: $alreadyShuttingDown, shutdownPhase: $shutdownPhase)';
}

/// Backward compatibility alias.
typedef SystemShutdownDto = SystemShutdownResponse;
