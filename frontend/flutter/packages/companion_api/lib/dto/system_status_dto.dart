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

/// DTO representing one of the five canonical host storage roots (GET /api/v1/system/storage).
@immutable
class StorageRootOut {
  final String key;
  final String label;
  final String path;
  final bool exists;
  final int? freeBytes;
  final int? totalBytes;
  final String source;

  const StorageRootOut({
    required this.key,
    required this.label,
    required this.path,
    required this.exists,
    this.freeBytes,
    this.totalBytes,
    required this.source,
  });

  factory StorageRootOut.fromJson(Map<String, dynamic> json) {
    return StorageRootOut(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      path: json['path'] as String? ?? '',
      exists: json['exists'] as bool? ?? false,
      freeBytes: json['free_bytes'] as int?,
      totalBytes: json['total_bytes'] as int?,
      source: json['source'] as String? ?? 'default',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'path': path,
        'exists': exists,
        if (freeBytes != null) 'free_bytes': freeBytes,
        if (totalBytes != null) 'total_bytes': totalBytes,
        'source': source,
      };
}

/// DTO representing host-admin storage telemetry across all five roots (GET /api/v1/system/storage).
@immutable
class StorageRootsResponse {
  final String bootstrapPath;
  final String libraryRoot;
  final String importInboxDir;
  final bool libraryRelocatable;
  final String? relocationBlockedReason;
  final List<StorageRootOut> roots;

  const StorageRootsResponse({
    required this.bootstrapPath,
    required this.libraryRoot,
    required this.importInboxDir,
    this.libraryRelocatable = true,
    this.relocationBlockedReason,
    this.roots = const [],
  });

  factory StorageRootsResponse.fromJson(Map<String, dynamic> json) {
    final rawRoots = json['roots'] as List<dynamic>? ?? const [];
    return StorageRootsResponse(
      bootstrapPath: json['bootstrap_path'] as String? ?? '',
      libraryRoot: json['library_root'] as String? ?? '',
      importInboxDir: json['import_inbox_dir'] as String? ?? '',
      libraryRelocatable: json['library_relocatable'] as bool? ?? true,
      relocationBlockedReason: json['relocation_blocked_reason'] as String?,
      roots: rawRoots
          .map((e) => StorageRootOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bootstrap_path': bootstrapPath,
        'library_root': libraryRoot,
        'import_inbox_dir': importInboxDir,
        'library_relocatable': libraryRelocatable,
        if (relocationBlockedReason != null)
          'relocation_blocked_reason': relocationBlockedReason,
        'roots': roots.map((r) => r.toJson()).toList(),
      };
}

/// Request DTO for PUT /api/v1/system/storage/library-root.
@immutable
class LibraryRootUpdateRequest {
  final String newLibraryRoot;
  final bool migrateExistingAssets;

  const LibraryRootUpdateRequest({
    required this.newLibraryRoot,
    this.migrateExistingAssets = true,
  });

  Map<String, dynamic> toJson() => {
        'new_library_root': newLibraryRoot,
        'migrate_existing_assets': migrateExistingAssets,
      };
}

/// DTO representing Windows Task Scheduler autostart status (GET /api/v1/system/autostart).
@immutable
class AutostartStatusOut {
  final bool supported;
  final bool enabled;
  final bool taskRegistered;
  final String taskName;
  final bool minimizedToTray;
  final String? command;
  final String? workingDirectory;
  final String statusDetail;

  const AutostartStatusOut({
    required this.supported,
    required this.enabled,
    required this.taskRegistered,
    required this.taskName,
    this.minimizedToTray = true,
    this.command,
    this.workingDirectory,
    required this.statusDetail,
  });

  factory AutostartStatusOut.fromJson(Map<String, dynamic> json) {
    return AutostartStatusOut(
      supported: json['supported'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? false,
      taskRegistered: json['task_registered'] as bool? ?? false,
      taskName: json['task_name'] as String? ?? 'AICompanionAutostart',
      minimizedToTray: json['minimized_to_tray'] as bool? ?? true,
      command: json['command'] as String?,
      workingDirectory: json['working_directory'] as String?,
      statusDetail: json['status_detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'supported': supported,
        'enabled': enabled,
        'task_registered': taskRegistered,
        'task_name': taskName,
        'minimized_to_tray': minimizedToTray,
        if (command != null) 'command': command,
        if (workingDirectory != null) 'working_directory': workingDirectory,
        'status_detail': statusDetail,
      };
}

/// Request DTO for PUT /api/v1/system/autostart.
@immutable
class AutostartUpdateRequest {
  final bool enabled;
  final bool minimizedToTray;

  const AutostartUpdateRequest({
    required this.enabled,
    this.minimizedToTray = true,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'minimized_to_tray': minimizedToTray,
      };
}

/// Live host resource governance and Auto Gaming Mode status (GET/PUT /api/v1/system/resources).
@immutable
class ResourcePolicyStatusOut {
  final String requestedMode;
  final String effectiveMode;
  final bool lowImpactActive;
  final String lowImpactStrategy;
  final String? lowImpactModelId;
  final List<String> gameProcessList;
  final List<String> detectedActiveGames;
  final int cooldownSeconds;
  final int cooldownRemainingSeconds;
  final String transitionState;
  final String? degradationReason;
  final bool deferredBackgroundWork;
  final String? hostGpuName;
  final double? hostVramGb;
  final double? hostRamGb;
  final double? availableRamGb;
  final String? appliedProfile;
  final String requestedProfile;
  final String telemetrySource;

  const ResourcePolicyStatusOut({
    required this.requestedMode,
    required this.effectiveMode,
    required this.lowImpactActive,
    required this.lowImpactStrategy,
    this.lowImpactModelId,
    this.gameProcessList = const <String>[],
    this.detectedActiveGames = const <String>[],
    required this.cooldownSeconds,
    this.cooldownRemainingSeconds = 0,
    this.transitionState = 'idle',
    this.degradationReason,
    required this.deferredBackgroundWork,
    this.hostGpuName,
    this.hostVramGb,
    this.hostRamGb,
    this.availableRamGb,
    this.appliedProfile,
    required this.requestedProfile,
    required this.telemetrySource,
  });

  factory ResourcePolicyStatusOut.fromJson(Map<String, dynamic> json) {
    return ResourcePolicyStatusOut(
      requestedMode: json['requested_mode'] as String? ?? 'normal',
      effectiveMode: json['effective_mode'] as String? ?? 'normal',
      lowImpactActive: json['low_impact_active'] as bool? ?? false,
      lowImpactStrategy: json['low_impact_strategy'] as String? ?? 'cpu_eco',
      lowImpactModelId: json['low_impact_model_id'] as String?,
      gameProcessList: (json['game_process_list'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      detectedActiveGames:
          (json['detected_active_games'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(growable: false),
      cooldownSeconds: json['cooldown_seconds'] as int? ?? 45,
      cooldownRemainingSeconds:
          json['cooldown_remaining_seconds'] as int? ?? 0,
      transitionState: json['transition_state'] as String? ?? 'idle',
      degradationReason: json['degradation_reason'] as String?,
      deferredBackgroundWork:
          json['deferred_background_work'] as bool? ?? false,
      hostGpuName: json['host_gpu_name'] as String?,
      hostVramGb: (json['host_vram_gb'] as num?)?.toDouble(),
      hostRamGb: (json['host_ram_gb'] as num?)?.toDouble(),
      availableRamGb: (json['available_ram_gb'] as num?)?.toDouble(),
      appliedProfile: json['applied_profile'] as String?,
      requestedProfile: json['requested_profile'] as String? ?? 'balanced',
      telemetrySource: json['telemetry_source'] as String? ?? 'unavailable',
    );
  }

  Map<String, dynamic> toJson() => {
        'requested_mode': requestedMode,
        'effective_mode': effectiveMode,
        'low_impact_active': lowImpactActive,
        'low_impact_strategy': lowImpactStrategy,
        if (lowImpactModelId != null) 'low_impact_model_id': lowImpactModelId,
        'game_process_list': gameProcessList,
        'detected_active_games': detectedActiveGames,
        'cooldown_seconds': cooldownSeconds,
        'cooldown_remaining_seconds': cooldownRemainingSeconds,
        'transition_state': transitionState,
        if (degradationReason != null) 'degradation_reason': degradationReason,
        'deferred_background_work': deferredBackgroundWork,
        if (hostGpuName != null) 'host_gpu_name': hostGpuName,
        if (hostVramGb != null) 'host_vram_gb': hostVramGb,
        if (hostRamGb != null) 'host_ram_gb': hostRamGb,
        if (availableRamGb != null) 'available_ram_gb': availableRamGb,
        if (appliedProfile != null) 'applied_profile': appliedProfile,
        'requested_profile': requestedProfile,
        'telemetry_source': telemetrySource,
      };
}

/// Request DTO for PUT /api/v1/system/resources.
@immutable
class ResourcePolicyUpdateRequest {
  final String? resourceMode;
  final String? lowImpactStrategy;
  final String? lowImpactModelId;
  final bool clearLowImpactModel;
  final List<String>? gameProcessList;
  final int? cooldownSeconds;

  const ResourcePolicyUpdateRequest({
    this.resourceMode,
    this.lowImpactStrategy,
    this.lowImpactModelId,
    this.clearLowImpactModel = false,
    this.gameProcessList,
    this.cooldownSeconds,
  });

  Map<String, dynamic> toJson() => {
        if (resourceMode != null) 'resource_mode': resourceMode,
        if (lowImpactStrategy != null)
          'low_impact_strategy': lowImpactStrategy,
        if (lowImpactModelId != null) 'low_impact_model_id': lowImpactModelId,
        if (clearLowImpactModel) 'clear_low_impact_model': clearLowImpactModel,
        if (gameProcessList != null) 'game_process_list': gameProcessList,
        if (cooldownSeconds != null) 'cooldown_seconds': cooldownSeconds,
      };
}
