import 'package:meta/meta.dart';

/// Single entry in the model registry catalog (GET /api/v1/models/registry).
@immutable
class ModelRegistryEntry {
  final String id;
  final String displayName;
  final String primaryFile;
  final String runtimeModelId;
  final String validationStatus;
  final bool primaryFileExists;
  final List<String> capabilities;
  final List<String> availableCapabilities;
  final double? sizeGb;
  final double estimatedVramGb;
  final String architecture;
  final String quantization;
  final String parameters;
  final String variant;
  final int? modelMaxContext;
  final String registrySource;
  final List<String> recommendedProfiles;
  final double estimatedRamGb;
  final String? sha256Primary;

  const ModelRegistryEntry({
    required this.id,
    required this.displayName,
    required this.primaryFile,
    this.runtimeModelId = '',
    this.validationStatus = 'unregistered',
    this.primaryFileExists = false,
    this.capabilities = const [],
    this.availableCapabilities = const [],
    this.sizeGb,
    this.estimatedVramGb = 0.0,
    this.architecture = '',
    this.quantization = '',
    this.parameters = '',
    this.variant = 'unknown',
    this.modelMaxContext,
    this.registrySource = 'factory',
    this.recommendedProfiles = const ['balanced'],
    this.estimatedRamGb = 0.0,
    this.sha256Primary,
  });

  factory ModelRegistryEntry.fromJson(Map<String, dynamic> json) {
    final manifest = json['manifest'] as Map<String, dynamic>? ?? {};
    final libraryState = json['library_state'] as Map<String, dynamic>? ?? {};
    final hints = json['hints'] as Map<String, dynamic>? ?? {};

    final rawCaps = manifest['capabilities'] as List<dynamic>? ?? [];
    final rawAvailCaps = libraryState['available_capabilities'] as List<dynamic>? ?? [];
    final rawRecProfiles = hints['recommended_profiles'] as List<dynamic>? ?? const ['balanced'];

    return ModelRegistryEntry(
      id: manifest['id'] as String? ?? json['runtime_model_id'] as String? ?? '',
      displayName: manifest['display_name'] as String? ?? manifest['id'] as String? ?? 'Unknown Model',
      primaryFile: manifest['primary_file'] as String? ?? '',
      runtimeModelId: json['runtime_model_id'] as String? ?? '',
      validationStatus: libraryState['validation_status'] as String? ?? 'unregistered',
      primaryFileExists: libraryState['primary_file_exists'] as bool? ?? false,
      capabilities: rawCaps.map((e) => e.toString()).toList(),
      availableCapabilities: rawAvailCaps.map((e) => e.toString()).toList(),
      sizeGb: (libraryState['size_gb'] as num?)?.toDouble(),
      estimatedVramGb: (hints['estimated_vram_gb'] as num?)?.toDouble() ?? 0.0,
      architecture: manifest['architecture'] as String? ?? '',
      quantization: manifest['quantization'] as String? ?? '',
      parameters: manifest['parameters'] as String? ?? '',
      variant: manifest['variant'] as String? ?? 'unknown',
      modelMaxContext: manifest['model_max_context'] as int?,
      registrySource: json['registry_source'] as String? ?? 'factory',
      recommendedProfiles: rawRecProfiles.map((e) => e.toString()).toList(),
      estimatedRamGb: (hints['estimated_ram_gb'] as num?)?.toDouble() ?? 0.0,
      sha256Primary: manifest['sha256_primary'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'primary_file': primaryFile,
        'runtime_model_id': runtimeModelId,
        'validation_status': validationStatus,
        'primary_file_exists': primaryFileExists,
        'capabilities': capabilities,
        'available_capabilities': availableCapabilities,
        if (sizeGb != null) 'size_gb': sizeGb,
        'estimated_vram_gb': estimatedVramGb,
        'architecture': architecture,
        'quantization': quantization,
        'parameters': parameters,
        'variant': variant,
        if (modelMaxContext != null) 'model_max_context': modelMaxContext,
        'registry_source': registrySource,
        'recommended_profiles': recommendedProfiles,
        'estimated_ram_gb': estimatedRamGb,
        if (sha256Primary != null) 'sha256_primary': sha256Primary,
      };

  bool get isVerified => validationStatus == 'verified' && primaryFileExists;
  bool get hasVision => availableCapabilities.contains('vision');
  bool get hasChat => availableCapabilities.contains('chat') || capabilities.contains('chat');
  bool get hasReasoning => availableCapabilities.contains('reasoning') || capabilities.contains('reasoning');
  bool get isInstalled => registrySource == 'installed';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelRegistryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          primaryFile == other.primaryFile &&
          validationStatus == other.validationStatus &&
          primaryFileExists == other.primaryFileExists &&
          registrySource == other.registrySource;

  @override
  int get hashCode => Object.hash(id, primaryFile, validationStatus, primaryFileExists, registrySource);

  @override
  String toString() => 'ModelRegistryEntry(id: $id, display: $displayName, status: $validationStatus, source: $registrySource)';
}

/// Advisory hardware suitability preflight outcome for a GGUF artifact.
@immutable
class PreflightAssessmentOut {
  final String status;
  final double estimatedVramGb;
  final double hostDedicatedVramGb;
  final String recommendedProfile;
  final String message;

  const PreflightAssessmentOut({
    required this.status,
    required this.estimatedVramGb,
    required this.hostDedicatedVramGb,
    required this.recommendedProfile,
    required this.message,
  });

  factory PreflightAssessmentOut.fromJson(Map<String, dynamic> json) {
    return PreflightAssessmentOut(
      status: json['status'] as String? ?? 'recommended',
      estimatedVramGb: (json['estimated_vram_gb'] as num?)?.toDouble() ?? 0.0,
      hostDedicatedVramGb: (json['host_dedicated_vram_gb'] as num?)?.toDouble() ?? 8.0,
      recommendedProfile: json['recommended_profile'] as String? ?? 'balanced',
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'estimated_vram_gb': estimatedVramGb,
        'host_dedicated_vram_gb': hostDedicatedVramGb,
        'recommended_profile': recommendedProfile,
        'message': message,
      };
}

/// Scanned D6 candidate bundle inside IMPORT_INBOX_DIR.
@immutable
class ModelImportCandidateOut {
  final String relativePath;
  final String primaryFilename;
  final String suggestedModelId;
  final String displayName;
  final int fileSizeBytes;
  final double sizeGb;
  final bool artifactValid;
  final String? validationError;
  final String architecture;
  final String quantization;
  final String parameters;
  final String variant;
  final String family;
  final String license;
  final int? modelMaxContext;
  final bool hasChatTemplate;
  final bool hasVisionProjector;
  final String? companionMmprojRelativePath;
  final String? companionMmprojFilename;
  final List<String> detectedCapabilities;
  final PreflightAssessmentOut preflight;

  const ModelImportCandidateOut({
    required this.relativePath,
    required this.primaryFilename,
    required this.suggestedModelId,
    required this.displayName,
    required this.fileSizeBytes,
    required this.sizeGb,
    required this.artifactValid,
    this.validationError,
    this.architecture = '',
    this.quantization = '',
    this.parameters = '',
    this.variant = 'unknown',
    this.family = '',
    this.license = '',
    this.modelMaxContext,
    this.hasChatTemplate = false,
    this.hasVisionProjector = false,
    this.companionMmprojRelativePath,
    this.companionMmprojFilename,
    this.detectedCapabilities = const [],
    required this.preflight,
  });

  factory ModelImportCandidateOut.fromJson(Map<String, dynamic> json) {
    final rawCaps = json['detected_capabilities'] as List<dynamic>? ?? const [];
    return ModelImportCandidateOut(
      relativePath: json['relative_path'] as String? ?? '',
      primaryFilename: json['primary_filename'] as String? ?? '',
      suggestedModelId: json['suggested_model_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      sizeGb: (json['size_gb'] as num?)?.toDouble() ?? 0.0,
      artifactValid: json['artifact_valid'] as bool? ?? false,
      validationError: json['validation_error'] as String?,
      architecture: json['architecture'] as String? ?? '',
      quantization: json['quantization'] as String? ?? '',
      parameters: json['parameters'] as String? ?? '',
      variant: json['variant'] as String? ?? 'unknown',
      family: json['family'] as String? ?? '',
      license: json['license'] as String? ?? '',
      modelMaxContext: json['model_max_context'] as int?,
      hasChatTemplate: json['has_chat_template'] as bool? ?? false,
      hasVisionProjector: json['has_vision_projector'] as bool? ?? false,
      companionMmprojRelativePath: json['companion_mmproj_relative_path'] as String?,
      companionMmprojFilename: json['companion_mmproj_filename'] as String?,
      detectedCapabilities: rawCaps.map((e) => e.toString()).toList(),
      preflight: PreflightAssessmentOut.fromJson(
        Map<String, dynamic>.from(json['preflight'] as Map? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'relative_path': relativePath,
        'primary_filename': primaryFilename,
        'suggested_model_id': suggestedModelId,
        'display_name': displayName,
        'file_size_bytes': fileSizeBytes,
        'size_gb': sizeGb,
        'artifact_valid': artifactValid,
        if (validationError != null) 'validation_error': validationError,
        'architecture': architecture,
        'quantization': quantization,
        'parameters': parameters,
        'variant': variant,
        'family': family,
        'license': license,
        if (modelMaxContext != null) 'model_max_context': modelMaxContext,
        'has_chat_template': hasChatTemplate,
        'has_vision_projector': hasVisionProjector,
        if (companionMmprojRelativePath != null)
          'companion_mmproj_relative_path': companionMmprojRelativePath,
        if (companionMmprojFilename != null)
          'companion_mmproj_filename': companionMmprojFilename,
        'detected_capabilities': detectedCapabilities,
        'preflight': preflight.toJson(),
      };
}

/// Response from POST /api/v1/models/import/scan.
@immutable
class ModelImportScanOut {
  final String inboxDir;
  final List<ModelImportCandidateOut> candidates;
  final List<String> warnings;

  const ModelImportScanOut({
    required this.inboxDir,
    this.candidates = const [],
    this.warnings = const [],
  });

  factory ModelImportScanOut.fromJson(Map<String, dynamic> json) {
    final rawCands = json['candidates'] as List<dynamic>? ?? const [];
    final rawWarnings = json['warnings'] as List<dynamic>? ?? const [];
    return ModelImportScanOut(
      inboxDir: json['inbox_dir'] as String? ?? '',
      candidates: rawCands
          .map((e) => ModelImportCandidateOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      warnings: rawWarnings.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'inbox_dir': inboxDir,
        'candidates': candidates.map((c) => c.toJson()).toList(),
        'warnings': warnings,
      };
}

/// Request payload for POST /api/v1/models/import/install.
@immutable
class ModelImportInstallRequest {
  final String relativePath;
  final String? companionRelativePath;
  final String modelId;
  final String? displayName;
  final String? variant;
  final String? family;
  final String? license;
  final String transferMode;

  const ModelImportInstallRequest({
    required this.relativePath,
    this.companionRelativePath,
    required this.modelId,
    this.displayName,
    this.variant,
    this.family,
    this.license,
    this.transferMode = 'move',
  });

  Map<String, dynamic> toJson() => {
        'relative_path': relativePath,
        if (companionRelativePath != null)
          'companion_relative_path': companionRelativePath,
        'model_id': modelId,
        if (displayName != null) 'display_name': displayName,
        if (variant != null) 'variant': variant,
        if (family != null) 'family': family,
        if (license != null) 'license': license,
        'transfer_mode': transferMode,
      };
}

/// Response from POST /api/v1/models/import/install.
@immutable
class ModelImportInstallOut {
  final String installedId;
  final String displayName;
  final String primaryFile;
  final String validationStatus;
  final String sha256Primary;

  const ModelImportInstallOut({
    required this.installedId,
    required this.displayName,
    required this.primaryFile,
    required this.validationStatus,
    required this.sha256Primary,
  });

  factory ModelImportInstallOut.fromJson(Map<String, dynamic> json) {
    return ModelImportInstallOut(
      installedId: json['installed_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      primaryFile: json['primary_file'] as String? ?? '',
      validationStatus: json['validation_status'] as String? ?? '',
      sha256Primary: json['sha256_primary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'installed_id': installedId,
        'display_name': displayName,
        'primary_file': primaryFile,
        'validation_status': validationStatus,
        'sha256_primary': sha256Primary,
      };
}

/// Response from DELETE /api/v1/models/registry/{model_id}.
@immutable
class ModelDeleteOut {
  final String deletedId;
  final String message;

  const ModelDeleteOut({
    required this.deletedId,
    required this.message,
  });

  factory ModelDeleteOut.fromJson(Map<String, dynamic> json) {
    return ModelDeleteOut(
      deletedId: json['deleted_id'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'deleted_id': deletedId,
        'message': message,
      };
}
