import 'package:meta/meta.dart';

/// Lightweight attachment reference embedded in message payloads.
@immutable
class AttachmentRef {
  final String id;
  final String filenameDisplay;
  final String mimeType;
  final int sizeBytes;

  const AttachmentRef({
    required this.id,
    required this.filenameDisplay,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory AttachmentRef.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    if (idVal is! String) {
      throw FormatException('AttachmentRef: id must be a string, got $idVal');
    }

    final filenameVal = json['filename_display'];
    if (filenameVal is! String) {
      throw FormatException('AttachmentRef: filename_display must be a string, got $filenameVal');
    }

    final mimeVal = json['mime_type'];
    if (mimeVal is! String) {
      throw FormatException('AttachmentRef: mime_type must be a string, got $mimeVal');
    }

    final sizeVal = json['size_bytes'];
    if (sizeVal is! int) {
      throw FormatException('AttachmentRef: size_bytes must be an int, got $sizeVal');
    }

    return AttachmentRef(
      id: idVal,
      filenameDisplay: filenameVal,
      mimeType: mimeVal,
      sizeBytes: sizeVal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename_display': filenameDisplay,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentRef &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          filenameDisplay == other.filenameDisplay &&
          mimeType == other.mimeType &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hash(id, filenameDisplay, mimeType, sizeBytes);

  @override
  String toString() => 'AttachmentRef(id: $id, name: $filenameDisplay)';
}

/// Payload sent by client to add a user message and trigger generation.
///
/// NOTE (Binding Correction A): attachment_ids is an optional array, NOT nullable.
/// For text-only turns, omit attachment_ids or send []. NEVER serialize null.
@immutable
class MessageSend {
  final String userText;
  final String? clientMessageId;
  final List<String>? attachmentIds;

  const MessageSend({
    required this.userText,
    this.clientMessageId,
    this.attachmentIds,
  });

  factory MessageSend.fromJson(Map<String, dynamic> json) {
    final textVal = json['user_text'];
    if (textVal is! String || textVal.isEmpty) {
      throw FormatException('MessageSend: user_text must be a non-empty string, got $textVal');
    }

    final rawAttIds = json['attachment_ids'];
    final List<String>? parsedAttIds;
    if (rawAttIds is List) {
      parsedAttIds = rawAttIds.map((e) => e.toString()).toList();
    } else {
      parsedAttIds = null;
    }

    return MessageSend(
      userText: textVal,
      clientMessageId: json['client_message_id'] as String?,
      attachmentIds: parsedAttIds,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_text': userText,
    };
    if (clientMessageId != null) {
      map['client_message_id'] = clientMessageId;
    }
    // Only serialize attachment_ids if explicitly provided, never serialize null
    if (attachmentIds != null) {
      map['attachment_ids'] = attachmentIds;
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageSend &&
          runtimeType == other.runtimeType &&
          userText == other.userText &&
          clientMessageId == other.clientMessageId;

  @override
  int get hashCode => Object.hash(userText, clientMessageId);

  @override
  String toString() => 'MessageSend(text: $userText, clientId: $clientMessageId)';
}

/// Authoritative message record returned from backend.
@immutable
class MessageOut {
  final String id;
  final String conversationId;
  final String sender;
  final String content;
  final String status;
  final int sequenceNo;
  final String? clientMessageId;
  final String? modelName;
  final int? promptTokens;
  final int? completionTokens;
  final String createdAt;
  final List<AttachmentRef> attachments;

  const MessageOut({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.status,
    required this.sequenceNo,
    this.clientMessageId,
    this.modelName,
    this.promptTokens,
    this.completionTokens,
    required this.createdAt,
    this.attachments = const [],
  });

  factory MessageOut.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    if (idVal is! String) {
      throw FormatException('MessageOut: id must be a string, got $idVal');
    }

    final convIdVal = json['conversation_id'];
    if (convIdVal is! String) {
      throw FormatException('MessageOut: conversation_id must be a string, got $convIdVal');
    }

    final senderVal = json['sender'];
    if (senderVal is! String) {
      throw FormatException('MessageOut: sender must be a string, got $senderVal');
    }

    final contentVal = json['content'];
    if (contentVal is! String) {
      throw FormatException('MessageOut: content must be a string, got $contentVal');
    }

    final statusVal = json['status'];
    if (statusVal is! String) {
      throw FormatException('MessageOut: status must be a string, got $statusVal');
    }

    final seqVal = json['sequence_no'];
    if (seqVal is! int) {
      throw FormatException('MessageOut: sequence_no must be an int, got $seqVal');
    }

    final createdVal = json['created_at'];
    if (createdVal is! String) {
      throw FormatException('MessageOut: created_at must be a string, got $createdVal');
    }

    final rawAtts = json['attachments'];
    final List<AttachmentRef> parsedAtts;
    if (rawAtts is List) {
      parsedAtts = rawAtts
          .map((e) => AttachmentRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      parsedAtts = const [];
    }

    return MessageOut(
      id: idVal,
      conversationId: convIdVal,
      sender: senderVal,
      content: contentVal,
      status: statusVal,
      sequenceNo: seqVal,
      clientMessageId: json['client_message_id'] as String?,
      modelName: json['model_name'] as String?,
      promptTokens: json['prompt_tokens'] as int?,
      completionTokens: json['completion_tokens'] as int?,
      createdAt: createdVal,
      attachments: parsedAtts,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender': sender,
        'content': content,
        'status': status,
        'sequence_no': sequenceNo,
        if (clientMessageId != null) 'client_message_id': clientMessageId,
        if (modelName != null) 'model_name': modelName,
        if (promptTokens != null) 'prompt_tokens': promptTokens,
        if (completionTokens != null) 'completion_tokens': completionTokens,
        'created_at': createdAt,
        'attachments': attachments.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageOut &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          conversationId == other.conversationId &&
          sender == other.sender &&
          content == other.content &&
          status == other.status &&
          sequenceNo == other.sequenceNo;

  @override
  int get hashCode => Object.hash(id, conversationId, sender, content, status, sequenceNo);

  @override
  String toString() => 'MessageOut(id: $id, sender: $sender, seq: $sequenceNo, status: $status)';
}

/// Paginated message list response from GET /api/v1/conversations/{id}/messages.
@immutable
class MessageListOut {
  final List<MessageOut> items;
  final int total;

  const MessageListOut({
    required this.items,
    required this.total,
  });

  factory MessageListOut.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw FormatException('MessageListOut: items must be a List, got $rawItems');
    }

    final totalVal = json['total'];
    if (totalVal is! int) {
      throw FormatException('MessageListOut: total must be an int, got $totalVal');
    }

    final parsedItems = rawItems
        .map((e) => MessageOut.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return MessageListOut(
      items: parsedItems,
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
      other is MessageListOut &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          items.length == other.items.length;

  @override
  int get hashCode => Object.hash(items, total);

  @override
  String toString() => 'MessageListOut(total: $total, count: ${items.length})';
}
