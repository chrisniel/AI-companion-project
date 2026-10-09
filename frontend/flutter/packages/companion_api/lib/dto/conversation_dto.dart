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

/// Payload for updating/renaming a conversation via PATCH /api/v1/conversations/{conversation_id}.
@immutable
class ConversationUpdate {
  final String title;

  const ConversationUpdate({
    required this.title,
  });

  factory ConversationUpdate.fromJson(Map<String, dynamic> json) {
    final titleVal = json['title'];
    if (titleVal is! String) {
      throw FormatException('ConversationUpdate: title must be a string, got $titleVal');
    }
    return ConversationUpdate(title: titleVal);
  }

  Map<String, dynamic> toJson() => {
        'title': title,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationUpdate &&
          runtimeType == other.runtimeType &&
          title == other.title;

  @override
  int get hashCode => title.hashCode;

  @override
  String toString() => 'ConversationUpdate(title: $title)';
}

/// Payload for requesting model-generated title via POST /api/v1/conversations/{conversation_id}/generate-title.
@immutable
class GenerateTitleRequest {
  final String? currentTitle;
  final String? fallbackTitle;

  const GenerateTitleRequest({
    this.currentTitle,
    this.fallbackTitle,
  });

  factory GenerateTitleRequest.fromJson(Map<String, dynamic> json) {
    return GenerateTitleRequest(
      currentTitle: json['current_title'] as String?,
      fallbackTitle: json['fallback_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (currentTitle != null) 'current_title': currentTitle,
        if (fallbackTitle != null) 'fallback_title': fallbackTitle,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenerateTitleRequest &&
          runtimeType == other.runtimeType &&
          currentTitle == other.currentTitle &&
          fallbackTitle == other.fallbackTitle;

  @override
  int get hashCode => Object.hash(currentTitle, fallbackTitle);

  @override
  String toString() =>
      'GenerateTitleRequest(currentTitle: $currentTitle, fallbackTitle: $fallbackTitle)';
}

/// Derives a clean, concise deterministic fallback title from the initial user query.
///
/// Matches Web Phase 8C deriveDeterministicTitle implementation:
/// Strips markdown characters, normalizes whitespace, truncates to 6 words / 42 chars with ellipsis.
String deriveDeterministicTitle(String userPrompt) {
  final cleaned = userPrompt
      .replaceAll(RegExp(r'[#*`_~\[\]()]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return 'New Conversation';
  final words = cleaned.split(' ');
  if (words.length <= 6 && cleaned.length <= 40) {
    return cleaned;
  }
  final truncated = words.take(6).join(' ');
  return truncated.length > 42 ? '${truncated.substring(0, 42).trim()}…' : '$truncated…';
}
