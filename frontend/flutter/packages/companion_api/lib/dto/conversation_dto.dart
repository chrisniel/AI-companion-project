import 'package:meta/meta.dart';

/// Payload for creating a new conversation via POST /api/v1/conversations.
@immutable
class ConversationCreate {
  final String? title;
  final String? characterId;

  const ConversationCreate({
    this.title = 'New Conversation',
    this.characterId,
  });

  factory ConversationCreate.fromJson(Map<String, dynamic> json) {
    return ConversationCreate(
      title: json['title'] as String? ?? 'New Conversation',
      characterId: json['character_id'] as String?,
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
  final String? characterInstanceId;
  final String ownerId;
  final String createdAt;
  final String updatedAt;
  final int messageCount;

  const ConversationOut({
    required this.id,
    required this.title,
    required this.characterId,
    this.characterInstanceId,
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

    final charInstIdVal = json['character_instance_id'] as String?;

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
      characterInstanceId: charInstIdVal,
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
        if (characterInstanceId != null) 'character_instance_id': characterInstanceId,
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
          characterInstanceId == other.characterInstanceId &&
          ownerId == other.ownerId &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          messageCount == other.messageCount;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        characterId,
        characterInstanceId,
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

/// Active rolling episode summary preserving continuity across compacted conversation turns.
class ConversationSummaryOut {
  final String id;
  final String conversationId;
  final String summaryText;
  final int fromSequenceNo;
  final int toSequenceNo;
  final int compactedMessageCount;
  final int tokenEstimate;
  final String source;
  final bool isActive;
  final String updatedAt;

  const ConversationSummaryOut({
    required this.id,
    required this.conversationId,
    required this.summaryText,
    required this.fromSequenceNo,
    required this.toSequenceNo,
    required this.compactedMessageCount,
    required this.tokenEstimate,
    required this.source,
    required this.isActive,
    required this.updatedAt,
  });

  factory ConversationSummaryOut.fromJson(Map<String, dynamic> json) {
    return ConversationSummaryOut(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      summaryText: json['summary_text'] as String,
      fromSequenceNo: json['from_sequence_no'] as int,
      toSequenceNo: json['to_sequence_no'] as int,
      compactedMessageCount: json['compacted_message_count'] as int,
      tokenEstimate: json['token_estimate'] as int,
      source: json['source'] as String,
      isActive: json['is_active'] as bool,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'summary_text': summaryText,
        'from_sequence_no': fromSequenceNo,
        'to_sequence_no': toSequenceNo,
        'compacted_message_count': compactedMessageCount,
        'token_estimate': tokenEstimate,
        'source': source,
        'is_active': isActive,
        'updated_at': updatedAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationSummaryOut &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          conversationId == other.conversationId &&
          summaryText == other.summaryText &&
          fromSequenceNo == other.fromSequenceNo &&
          toSequenceNo == other.toSequenceNo &&
          compactedMessageCount == other.compactedMessageCount &&
          tokenEstimate == other.tokenEstimate &&
          source == other.source &&
          isActive == other.isActive &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        conversationId,
        summaryText,
        fromSequenceNo,
        toSequenceNo,
        compactedMessageCount,
        tokenEstimate,
        source,
        isActive,
        updatedAt,
      );

  @override
  String toString() =>
      'ConversationSummaryOut(id: $id, turns: $fromSequenceNo..$toSequenceNo, source: $source)';
}

/// Request payload for manual conversation context compaction.
class ConversationCompactRequest {
  final int? keepRecentMessages;
  final bool force;

  const ConversationCompactRequest({
    this.keepRecentMessages,
    this.force = true,
  });

  factory ConversationCompactRequest.fromJson(Map<String, dynamic> json) {
    return ConversationCompactRequest(
      keepRecentMessages: json['keep_recent_messages'] as int?,
      force: (json['force'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (keepRecentMessages != null)
          'keep_recent_messages': keepRecentMessages,
        'force': force,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationCompactRequest &&
          runtimeType == other.runtimeType &&
          keepRecentMessages == other.keepRecentMessages &&
          force == other.force;

  @override
  int get hashCode => Object.hash(keepRecentMessages, force);
}

/// Response envelope returned by manual context compaction.
class ConversationCompactResponse {
  final String conversationId;
  final bool compacted;
  final String reason;
  final ConversationSummaryOut? summary;

  const ConversationCompactResponse({
    required this.conversationId,
    required this.compacted,
    required this.reason,
    this.summary,
  });

  factory ConversationCompactResponse.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'];
    return ConversationCompactResponse(
      conversationId: json['conversation_id'] as String,
      compacted: json['compacted'] as bool,
      reason: json['reason'] as String,
      summary: rawSummary is Map<String, dynamic>
          ? ConversationSummaryOut.fromJson(rawSummary)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'conversation_id': conversationId,
        'compacted': compacted,
        'reason': reason,
        'summary': summary?.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationCompactResponse &&
          runtimeType == other.runtimeType &&
          conversationId == other.conversationId &&
          compacted == other.compacted &&
          reason == other.reason &&
          summary == other.summary;

  @override
  int get hashCode => Object.hash(conversationId, compacted, reason, summary);
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
