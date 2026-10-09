import 'package:meta/meta.dart';

/// Payload for creating a new conversation via POST /api/v1/conversations.
@immutable
class ConversationCreate {
  final String? title;
  final String? characterId;

  const ConversationCreate({
    this.title = 'New Conversation',
    this.characterId = 'default',
  });

  factory ConversationCreate.fromJson(Map<String, dynamic> json) {
    return ConversationCreate(
      title: json['title'] as String? ?? 'New Conversation',
      characterId: json['character_id'] as String? ?? 'default',
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (characterId != null) 'character_id': characterId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationCreate &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          characterId == other.characterId;

  @override
  int get hashCode => Object.hash(title, characterId);

  @override
  String toString() => 'ConversationCreate(title: $title, characterId: $characterId)';
}

/// Authoritative conversation record returned from backend.
@immutable
class ConversationOut {
  final String id;
  final String title;
  final String characterId;
  final String ownerId;
  final String createdAt;
  final String updatedAt;
  final int messageCount;

  const ConversationOut({
    required this.id,
    required this.title,
    required this.characterId,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  factory ConversationOut.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    if (idVal is! String) {
      throw FormatException('ConversationOut: id must be a string, got $idVal');
    }

    final titleVal = json['title'];
    if (titleVal is! String) {
      throw FormatException('ConversationOut: title must be a string, got $titleVal');
    }

    final charIdVal = json['character_id'];
    if (charIdVal is! String) {
      throw FormatException('ConversationOut: character_id must be a string, got $charIdVal');
    }

    final ownerIdVal = json['owner_id'];
    if (ownerIdVal is! String) {
      throw FormatException('ConversationOut: owner_id must be a string, got $ownerIdVal');
    }

    final createdVal = json['created_at'];
    if (createdVal is! String) {
      throw FormatException('ConversationOut: created_at must be a string, got $createdVal');
    }

    final updatedVal = json['updated_at'];
    if (updatedVal is! String) {
      throw FormatException('ConversationOut: updated_at must be a string, got $updatedVal');
    }

    final msgCountVal = json['message_count'] as int? ?? 0;

    return ConversationOut(
      id: idVal,
      title: titleVal,
      characterId: charIdVal,
      ownerId: ownerIdVal,
      createdAt: createdVal,
      updatedAt: updatedVal,
      messageCount: msgCountVal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'character_id': characterId,
        'owner_id': ownerId,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'message_count': messageCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationOut &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          characterId == other.characterId &&
          ownerId == other.ownerId &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          messageCount == other.messageCount;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        characterId,
        ownerId,
        createdAt,
        updatedAt,
        messageCount,
      );

  @override
  String toString() => 'ConversationOut(id: $id, title: $title, count: $messageCount)';
}

/// Paginated conversation list response from GET /api/v1/conversations.
@immutable
class ConversationListOut {
  final List<ConversationOut> items;
  final int total;

  const ConversationListOut({
    required this.items,
    required this.total,
  });

  factory ConversationListOut.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw FormatException('ConversationListOut: items must be a List, got $rawItems');
    }

    final totalVal = json['total'];
    if (totalVal is! int) {
      throw FormatException('ConversationListOut: total must be an int, got $totalVal');
    }

    final itemsList = rawItems
        .map((e) => ConversationOut.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return ConversationListOut(
      items: itemsList,
      total: totalVal,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationListOut &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          items.length == other.items.length;

  @override
  int get hashCode => Object.hash(items, total);

  @override
  String toString() => 'ConversationListOut(total: $total, count: ${items.length})';
}
