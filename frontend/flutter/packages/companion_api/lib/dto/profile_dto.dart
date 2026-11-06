import 'package:meta/meta.dart';

/// DTO representing Profile metadata from the Profile catalog and operations.
@immutable
class ProfileMetadata {
  final String id;
  final String name;
  final bool isDefault;
  final String status;
  final bool pinProtected;
  final bool isDeleted;
  final String? deletedAt;
  final String? purgeAfter;
  final bool memoryExtractionEnabled;

  const ProfileMetadata({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.status,
    required this.pinProtected,
    this.isDeleted = false,
    this.deletedAt,
    this.purgeAfter,
    this.memoryExtractionEnabled = true,
  });

  factory ProfileMetadata.fromJson(Map<String, dynamic> json) {
    return ProfileMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      isDefault: json['is_default'] as bool,
      status: json['status'] as String,
      pinProtected: json['pin_protected'] as bool,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] as String?,
      purgeAfter: json['purge_after'] as String?,
      memoryExtractionEnabled: json['memory_extraction_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_default': isDefault,
        'status': status,
        'pin_protected': pinProtected,
        'is_deleted': isDeleted,
        'deleted_at': deletedAt,
        'purge_after': purgeAfter,
        'memory_extraction_enabled': memoryExtractionEnabled,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileMetadata &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isDefault == other.isDefault &&
          status == other.status &&
          pinProtected == other.pinProtected &&
          isDeleted == other.isDeleted &&
          deletedAt == other.deletedAt &&
          purgeAfter == other.purgeAfter &&
          memoryExtractionEnabled == other.memoryExtractionEnabled;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        isDefault,
        status,
        pinProtected,
        isDeleted,
        deletedAt,
        purgeAfter,
        memoryExtractionEnabled,
      );

  @override
  String toString() =>
      'ProfileMetadata(id: $id, name: $name, isDefault: $isDefault, status: $status, pinProtected: $pinProtected, isDeleted: $isDeleted, deletedAt: $deletedAt, purgeAfter: $purgeAfter)';
}

/// DTO for creating a new Profile.
@immutable
class ProfileCreateRequest {
  final String name;

  const ProfileCreateRequest({required this.name});

  factory ProfileCreateRequest.fromJson(Map<String, dynamic> json) {
    return ProfileCreateRequest(name: json['name'] as String);
  }

  Map<String, dynamic> toJson() => {'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileCreateRequest &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ProfileCreateRequest(name: $name)';
}

/// DTO for updating an existing Profile's display name.
@immutable
class ProfileUpdateRequest {
  final String? name;
  final bool? memoryExtractionEnabled;

  const ProfileUpdateRequest({
    this.name,
    this.memoryExtractionEnabled,
  });

  factory ProfileUpdateRequest.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateRequest(
      name: json['name'] as String?,
      memoryExtractionEnabled: json['memory_extraction_enabled'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (memoryExtractionEnabled != null) 'memory_extraction_enabled': memoryExtractionEnabled,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileUpdateRequest &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          memoryExtractionEnabled == other.memoryExtractionEnabled;

  @override
  int get hashCode => Object.hash(name, memoryExtractionEnabled);

  @override
  String toString() =>
      'ProfileUpdateRequest(name: , memoryExtractionEnabled: )';
}

/// Result summary for manual and periodic Profile purge maintenance sweeps.
@immutable
class PurgeMaintenanceResult {
  final List<String> purgedProfileIds;
  final List<String> failedProfileIds;

  const PurgeMaintenanceResult({
    this.purgedProfileIds = const [],
    this.failedProfileIds = const [],
  });

  factory PurgeMaintenanceResult.fromJson(Map<String, dynamic> json) {
    return PurgeMaintenanceResult(
      purgedProfileIds: (json['purged_profile_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      failedProfileIds: (json['failed_profile_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'purged_profile_ids': purgedProfileIds,
        'failed_profile_ids': failedProfileIds,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurgeMaintenanceResult &&
          runtimeType == other.runtimeType &&
          _listEquals(purgedProfileIds, other.purgedProfileIds) &&
          _listEquals(failedProfileIds, other.failedProfileIds);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(purgedProfileIds),
        Object.hashAll(failedProfileIds),
      );

  @override
  String toString() =>
      'PurgeMaintenanceResult(purgedProfileIds: $purgedProfileIds, failedProfileIds: $failedProfileIds)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
