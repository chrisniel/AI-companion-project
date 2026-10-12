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
  });

  factory ModelRegistryEntry.fromJson(Map<String, dynamic> json) {
    final manifest = json['manifest'] as Map<String, dynamic>? ?? {};
    final libraryState = json['library_state'] as Map<String, dynamic>? ?? {};
    final hints = json['hints'] as Map<String, dynamic>? ?? {};

    final rawCaps = manifest['capabilities'] as List<dynamic>? ?? [];
    final rawAvailCaps = libraryState['available_capabilities'] as List<dynamic>? ?? [];

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
      };

  bool get isVerified => validationStatus == 'verified' && primaryFileExists;
  bool get hasVision => availableCapabilities.contains('vision');
  bool get hasChat => availableCapabilities.contains('chat') || capabilities.contains('chat');
  bool get hasReasoning => availableCapabilities.contains('reasoning') || capabilities.contains('reasoning');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelRegistryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          primaryFile == other.primaryFile &&
          validationStatus == other.validationStatus &&
          primaryFileExists == other.primaryFileExists;

  @override
  int get hashCode => Object.hash(id, primaryFile, validationStatus, primaryFileExists);

  @override
  String toString() => 'ModelRegistryEntry(id: $id, display: $displayName, status: $validationStatus)';
}
