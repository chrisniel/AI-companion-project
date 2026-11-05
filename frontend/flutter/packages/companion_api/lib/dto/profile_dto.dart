import 'package:meta/meta.dart';

/// DTO representing Profile metadata from the Profile catalog and operations.
@immutable
class ProfileMetadata {
  final String id;
  final String name;
  final bool isDefault;
  final String status;
  final bool pinProtected;

  const ProfileMetadata({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.status,
    required this.pinProtected,
  });

  factory ProfileMetadata.fromJson(Map<String, dynamic> json) {
    return ProfileMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      isDefault: json['is_default'] as bool,
      status: json['status'] as String,
      pinProtected: json['pin_protected'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_default': isDefault,
        'status': status,
        'pin_protected': pinProtected,
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
          pinProtected == other.pinProtected;

  @override
  int get hashCode => Object.hash(id, name, isDefault, status, pinProtected);

  @override
  String toString() =>
      'ProfileMetadata(id: $id, name: $name, isDefault: $isDefault, status: $status, pinProtected: $pinProtected)';
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
  final String name;

  const ProfileUpdateRequest({required this.name});

  factory ProfileUpdateRequest.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateRequest(name: json['name'] as String);
  }

  Map<String, dynamic> toJson() => {'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileUpdateRequest &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ProfileUpdateRequest(name: $name)';
}
