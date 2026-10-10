import 'package:meta/meta.dart';

/// DTO representing runtime model status from GET /api/v1/models.
///
/// Phase 3 Truthful Telemetry Contract:
/// - Distinguishes router process liveness (`router_running`) from model residency (`model_resident`).
/// - Distinguishes requested profile configuration (`requested_profile`) from actually verified
///   applied launch parameters (`applied_profile`, `applied_context_size`, `applied_gpu_layers`, `mmproj_offload`).
/// - Expressive MODEL_SLEEPING semantics via dual fields:
///     `model_loaded = true` (Logical model residency: worker process exists, model registered in router)
///     `model_awake = false` (VRAM/Compute readiness: allocations unmapped while sleeping)
///     `model_resident = false` (VRAM residency: GPU memory released while sleeping)
@immutable
class ModelStatusResponse {
  final String provider;
  final String? engineVersion;
  final bool routerRunning;
  final bool managedByCore;
  final String runtimeState;
  final String? activeModel;
  final bool modelResident;
  final bool modelLoaded;
  final bool modelAwake;
  final String requestedProfile;
  final String? appliedProfile;
  final int? appliedContextSize;
  final int? appliedGpuLayers;
  final bool requestedMmprojOffload;
  final bool? appliedMmprojOffload;
  final bool generationActive;
  final String? lastRuntimeError;
  final bool mmprojOffload;
  final bool isLoaded;
  final String activeProfile;
  final int contextSize;
  final int gpuLayers;
  final int idleTimeoutSeconds;
  final int? secondsUntilIdle;
  final int? secondsUntilUnload;
  final List<String> availableModels;
  final List<String>? availableRegistry;

  const ModelStatusResponse({
    required this.provider,
    this.engineVersion = 'b10936',
    this.routerRunning = false,
    this.managedByCore = false,
    this.runtimeState = 'UNLOADED',
    this.activeModel,
    this.modelResident = false,
    this.modelLoaded = false,
    this.modelAwake = false,
    this.requestedProfile = 'balanced',
    this.appliedProfile,
    this.appliedContextSize,
    this.appliedGpuLayers,
    this.requestedMmprojOffload = true,
    this.appliedMmprojOffload,
    this.generationActive = false,
    this.lastRuntimeError,
    this.mmprojOffload = true,
    this.isLoaded = false,
    this.activeProfile = 'balanced',
    this.contextSize = 4096,
    this.gpuLayers = 28,
    this.idleTimeoutSeconds = 900,
    this.secondsUntilIdle,
    this.secondsUntilUnload,
    this.availableModels = const [],
    this.availableRegistry,
  });

  factory ModelStatusResponse.fromJson(Map<String, dynamic> json) {
    final providerVal = json['provider'];
    if (providerVal is! String) {
      throw FormatException('ModelStatusResponse: provider must be a string, got $providerVal');
    }

    final availableModelsRaw = json['available_models'];
    final List<String> parsedModels;
    if (availableModelsRaw is List) {
      parsedModels = availableModelsRaw.map((e) => e.toString()).toList();
    } else {
      parsedModels = const [];
    }

    final availableRegistryRaw = json['available_registry'];
    final List<String>? parsedRegistry;
    if (availableRegistryRaw is List) {
      parsedRegistry = availableRegistryRaw.map((e) => e.toString()).toList();
    } else {
      parsedRegistry = null;
    }

    return ModelStatusResponse(
      provider: providerVal,
      engineVersion: json['engine_version'] as String? ?? 'b10936',
      routerRunning: json['router_running'] as bool? ?? false,
      managedByCore: json['managed_by_core'] as bool? ?? false,
      runtimeState: json['runtime_state'] as String? ?? 'UNLOADED',
      activeModel: json['active_model'] as String?,
      modelResident: json['model_resident'] as bool? ?? false,
      modelLoaded: json['model_loaded'] as bool? ?? false,
      modelAwake: json['model_awake'] as bool? ?? false,
      requestedProfile: json['requested_profile'] as String? ?? 'balanced',
      appliedProfile: json['applied_profile'] as String?,
      appliedContextSize: json['applied_context_size'] as int?,
      appliedGpuLayers: json['applied_gpu_layers'] as int?,
      requestedMmprojOffload: json['requested_mmproj_offload'] as bool? ?? true,
      appliedMmprojOffload: json['applied_mmproj_offload'] as bool?,
      generationActive: json['generation_active'] as bool? ?? false,
      lastRuntimeError: json['last_runtime_error'] as String?,
      mmprojOffload: json['mmproj_offload'] as bool? ?? true,
      isLoaded: json['is_loaded'] as bool? ?? false,
      activeProfile: json['active_profile'] as String? ?? 'balanced',
      contextSize: json['context_size'] as int? ?? 4096,
      gpuLayers: json['gpu_layers'] as int? ?? 28,
      idleTimeoutSeconds: json['idle_timeout_seconds'] as int? ?? 900,
      secondsUntilIdle: json['seconds_until_idle'] as int?,
      secondsUntilUnload: json['seconds_until_unload'] as int?,
      availableModels: parsedModels,
      availableRegistry: parsedRegistry,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'engine_version': engineVersion,
        'router_running': routerRunning,
        'managed_by_core': managedByCore,
        'runtime_state': runtimeState,
        if (activeModel != null) 'active_model': activeModel,
        'model_resident': modelResident,
        'model_loaded': modelLoaded,
        'model_awake': modelAwake,
        'requested_profile': requestedProfile,
        if (appliedProfile != null) 'applied_profile': appliedProfile,
        if (appliedContextSize != null) 'applied_context_size': appliedContextSize,
        if (appliedGpuLayers != null) 'applied_gpu_layers': appliedGpuLayers,
        'requested_mmproj_offload': requestedMmprojOffload,
        if (appliedMmprojOffload != null) 'applied_mmproj_offload': appliedMmprojOffload,
        'generation_active': generationActive,
        if (lastRuntimeError != null) 'last_runtime_error': lastRuntimeError,
        'mmproj_offload': mmprojOffload,
        'is_loaded': isLoaded,
        'active_profile': activeProfile,
        'context_size': contextSize,
        'gpu_layers': gpuLayers,
        'idle_timeout_seconds': idleTimeoutSeconds,
        if (secondsUntilIdle != null) 'seconds_until_idle': secondsUntilIdle,
        if (secondsUntilUnload != null) 'seconds_until_unload': secondsUntilUnload,
        'available_models': availableModels,
        if (availableRegistry != null) 'available_registry': availableRegistry,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelStatusResponse &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          engineVersion == other.engineVersion &&
          routerRunning == other.routerRunning &&
          managedByCore == other.managedByCore &&
          runtimeState == other.runtimeState &&
          activeModel == other.activeModel &&
          modelResident == other.modelResident &&
          modelLoaded == other.modelLoaded &&
          modelAwake == other.modelAwake &&
          requestedProfile == other.requestedProfile &&
          appliedProfile == other.appliedProfile &&
          appliedContextSize == other.appliedContextSize &&
          appliedGpuLayers == other.appliedGpuLayers &&
          requestedMmprojOffload == other.requestedMmprojOffload &&
          appliedMmprojOffload == other.appliedMmprojOffload &&
          generationActive == other.generationActive &&
          lastRuntimeError == other.lastRuntimeError &&
          mmprojOffload == other.mmprojOffload &&
          isLoaded == other.isLoaded &&
          activeProfile == other.activeProfile &&
          contextSize == other.contextSize &&
          gpuLayers == other.gpuLayers &&
          idleTimeoutSeconds == other.idleTimeoutSeconds;

  @override
  int get hashCode => Object.hashAll([
        provider,
        engineVersion,
        routerRunning,
        managedByCore,
        runtimeState,
        activeModel,
        modelResident,
        modelLoaded,
        modelAwake,
        requestedProfile,
        appliedProfile,
        appliedContextSize,
        appliedGpuLayers,
        requestedMmprojOffload,
        appliedMmprojOffload,
        generationActive,
        lastRuntimeError,
        mmprojOffload,
        isLoaded,
        activeProfile,
        contextSize,
        gpuLayers,
        idleTimeoutSeconds,
      ]);

  @override
  String toString() =>
      'ModelStatusResponse(provider: $provider, state: $runtimeState, activeModel: $activeModel)';
}
