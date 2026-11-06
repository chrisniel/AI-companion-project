import 'package:meta/meta.dart';

/// DTO for creating a new memory record via POST /api/v1/memories.
@immutable
class MemoryCreate {
  final String content;
  final String category;
  final double importance;
  final String scope;
  final String? characterInstanceId;
  final String? validFrom;
  final String? expiresAt;
  final bool isCore;

  const MemoryCreate({
    required this.content,
    this.category = 'fact',
    this.importance = 1.0,
    this.scope = 'profile',
    this.characterInstanceId,
    this.validFrom,
    this.expiresAt,
    this.isCore = false,
  });

  factory MemoryCreate.fromJson(Map<String, dynamic> json) {
    return MemoryCreate(
      content: json['content'] as String,
      category: json['category'] as String? ?? 'fact',
      importance: (json['importance'] as num?)?.toDouble() ?? 1.0,
      scope: json['scope'] as String? ?? 'profile',
      characterInstanceId: json['character_instance_id'] as String?,
      validFrom: json['valid_from'] as String?,
      expiresAt: json['expires_at'] as String?,
      isCore: json['is_core'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'category': category,
        'importance': importance,
        'scope': scope,
        if (characterInstanceId != null) 'character_instance_id': characterInstanceId,
        if (validFrom != null) 'valid_from': validFrom,
        if (expiresAt != null) 'expires_at': expiresAt,
        'is_core': isCore,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryCreate &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          category == other.category &&
          importance == other.importance &&
          scope == other.scope &&
          characterInstanceId == other.characterInstanceId &&
          validFrom == other.validFrom &&
          expiresAt == other.expiresAt &&
          isCore == other.isCore;

  @override
  int get hashCode => Object.hash(
        content,
        category,
        importance,
        scope,
        characterInstanceId,
        validFrom,
        expiresAt,
        isCore,
      );

  @override
  String toString() =>
      'MemoryCreate(content: $content, category: $category, scope: $scope, characterInstanceId: $characterInstanceId, isCore: $isCore)';
}

/// DTO for updating an existing memory record via PATCH /api/v1/memories/{memory_id}.
@immutable
class MemoryUpdate {
  final String? content;
  final String? category;
  final double? importance;
  final bool? isCore;
  final String? expiresAt;

  const MemoryUpdate({
    this.content,
    this.category,
    this.importance,
    this.isCore,
    this.expiresAt,
  });

  factory MemoryUpdate.fromJson(Map<String, dynamic> json) {
    return MemoryUpdate(
      content: json['content'] as String?,
      category: json['category'] as String?,
      importance: (json['importance'] as num?)?.toDouble(),
      isCore: json['is_core'] as bool?,
      expiresAt: json['expires_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (content != null) 'content': content,
        if (category != null) 'category': category,
        if (importance != null) 'importance': importance,
        if (isCore != null) 'is_core': isCore,
        'expires_at': expiresAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryUpdate &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          category == other.category &&
          importance == other.importance &&
          isCore == other.isCore &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(
        content,
        category,
        importance,
        isCore,
        expiresAt,
      );

  @override
  String toString() =>
      'MemoryUpdate(content: $content, category: $category, isCore: $isCore, expiresAt: $expiresAt)';
}

/// Authoritative memory record returned by the backend.
@immutable
class MemoryOut {
  final String id;
  final String content;
  final String category;
  final double importance;
  final String sourceType;
  final bool userVerified;
  final String createdAt;
  final String ownerId;
  final String? profileId;
  final String scope;
  final String? characterInstanceId;
  final String? validFrom;
  final String? expiresAt;
  final String? lastVerifiedAt;
  final bool isCore;

  const MemoryOut({
    required this.id,
    required this.content,
    required this.category,
    required this.importance,
    required this.sourceType,
    required this.userVerified,
    required this.createdAt,
    required this.ownerId,
    this.profileId,
    this.scope = 'profile',
    this.characterInstanceId,
    this.validFrom,
    this.expiresAt,
    this.lastVerifiedAt,
    this.isCore = false,
  });

  factory MemoryOut.fromJson(Map<String, dynamic> json) {
    return MemoryOut(
      id: json['id'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      importance: (json['importance'] as num).toDouble(),
      sourceType: json['source_type'] as String,
      userVerified: json['user_verified'] as bool,
      createdAt: json['created_at'] as String,
      ownerId: json['owner_id'] as String,
      profileId: json['profile_id'] as String?,
      scope: json['scope'] as String? ?? 'profile',
      characterInstanceId: json['character_instance_id'] as String?,
      validFrom: json['valid_from'] as String?,
      expiresAt: json['expires_at'] as String?,
      lastVerifiedAt: json['last_verified_at'] as String?,
      isCore: json['is_core'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'category': category,
        'importance': importance,
        'source_type': sourceType,
        'user_verified': userVerified,
        'created_at': createdAt,
        'owner_id': ownerId,
        'profile_id': profileId,
        'scope': scope,
        'character_instance_id': characterInstanceId,
        'valid_from': validFrom,
        'expires_at': expiresAt,
        'last_verified_at': lastVerifiedAt,
        'is_core': isCore,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryOut &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          content == other.content &&
          category == other.category &&
          importance == other.importance &&
          sourceType == other.sourceType &&
          userVerified == other.userVerified &&
          createdAt == other.createdAt &&
          ownerId == other.ownerId &&
          profileId == other.profileId &&
          scope == other.scope &&
          characterInstanceId == other.characterInstanceId &&
          validFrom == other.validFrom &&
          expiresAt == other.expiresAt &&
          lastVerifiedAt == other.lastVerifiedAt &&
          isCore == other.isCore;

  @override
  int get hashCode => Object.hashAll([
        id,
        content,
        category,
        importance,
        sourceType,
        userVerified,
        createdAt,
        ownerId,
        profileId,
        scope,
        characterInstanceId,
        validFrom,
        expiresAt,
        lastVerifiedAt,
        isCore,
      ]);

  @override
  String toString() =>
      'MemoryOut(id: $id, content: $content, scope: $scope, characterInstanceId: $characterInstanceId, isCore: $isCore)';
}

/// Paginated list response for memories via GET /api/v1/memories.
@immutable
class MemoryListOut {
  final List<MemoryOut> items;
  final int total;
  final int page;
  final int pageSize;

  const MemoryListOut({
    required this.items,
    required this.total,
    this.page = 1,
    this.pageSize = 50,
  });

  factory MemoryListOut.fromJson(Map<String, dynamic> json) {
    return MemoryListOut(
      items: (json['items'] as List<dynamic>)
          .map((item) => MemoryOut.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'page': page,
        'page_size': pageSize,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryListOut &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(items, total, page, pageSize);

  @override
  String toString() => 'MemoryListOut(total: $total, page: $page, count: ${items.length})';
}
