import 'package:meta/meta.dart';

/// Payload to create a new Task via POST /api/v1/tasks.
@immutable
class TaskCreate {
  final String title;
  final String? notes;
  final String category;
  final String priority;
  final String? dueDate;
  final int? reminderMinutesBefore;
  final String? reminderAt;

  const TaskCreate({
    required this.title,
    this.notes,
    this.category = 'general',
    this.priority = 'medium',
    this.dueDate,
    this.reminderMinutesBefore,
    this.reminderAt,
  });

  factory TaskCreate.fromJson(Map<String, dynamic> json) {
    return TaskCreate(
      title: json['title'] as String,
      notes: json['notes'] as String?,
      category: json['category'] as String? ?? 'general',
      priority: json['priority'] as String? ?? 'medium',
      dueDate: json['due_date'] as String?,
      reminderMinutesBefore: (json['reminder_minutes_before'] as num?)?.toInt(),
      reminderAt: json['reminder_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        if (notes != null) 'notes': notes,
        'category': category,
        'priority': priority,
        if (dueDate != null) 'due_date': dueDate,
        if (reminderMinutesBefore != null)
          'reminder_minutes_before': reminderMinutesBefore,
        if (reminderAt != null) 'reminder_at': reminderAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCreate &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          notes == other.notes &&
          category == other.category &&
          priority == other.priority &&
          dueDate == other.dueDate &&
          reminderMinutesBefore == other.reminderMinutesBefore &&
          reminderAt == other.reminderAt;

  @override
  int get hashCode => Object.hash(
        title,
        notes,
        category,
        priority,
        dueDate,
        reminderMinutesBefore,
        reminderAt,
      );
}

/// Partial update payload for PATCH /api/v1/tasks/{task_id}.
///
/// Non-nullable backend fields (`title`, `category`, `status`, `priority`) are
/// omitted from JSON when null. Nullable fields can be explicitly nulled via
/// `toJson(clearNotes: true, ...)`.
@immutable
class TaskUpdate {
  final String? title;
  final String? notes;
  final String? category;
  final String? status;
  final String? priority;
  final String? dueDate;
  final int? reminderMinutesBefore;
  final String? reminderAt;

  const TaskUpdate({
    this.title,
    this.notes,
    this.category,
    this.status,
    this.priority,
    this.dueDate,
    this.reminderMinutesBefore,
    this.reminderAt,
  });

  factory TaskUpdate.fromJson(Map<String, dynamic> json) {
    return TaskUpdate(
      title: json['title'] as String?,
      notes: json['notes'] as String?,
      category: json['category'] as String?,
      status: json['status'] as String?,
      priority: json['priority'] as String?,
      dueDate: json['due_date'] as String?,
      reminderMinutesBefore: (json['reminder_minutes_before'] as num?)?.toInt(),
      reminderAt: json['reminder_at'] as String?,
    );
  }

  Map<String, dynamic> toJson({
    bool clearNotes = false,
    bool clearDueDate = false,
    bool clearReminderMinutesBefore = false,
    bool clearReminderAt = false,
  }) =>
      {
        if (title != null) 'title': title,
        if (clearNotes) 'notes': null else if (notes != null) 'notes': notes,
        if (category != null) 'category': category,
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (clearDueDate)
          'due_date': null
        else if (dueDate != null)
          'due_date': dueDate,
        if (clearReminderMinutesBefore)
          'reminder_minutes_before': null
        else if (reminderMinutesBefore != null)
          'reminder_minutes_before': reminderMinutesBefore,
        if (clearReminderAt)
          'reminder_at': null
        else if (reminderAt != null)
          'reminder_at': reminderAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskUpdate &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          notes == other.notes &&
          category == other.category &&
          status == other.status &&
          priority == other.priority &&
          dueDate == other.dueDate &&
          reminderMinutesBefore == other.reminderMinutesBefore &&
          reminderAt == other.reminderAt;

  @override
  int get hashCode => Object.hash(
        title,
        notes,
        category,
        status,
        priority,
        dueDate,
        reminderMinutesBefore,
        reminderAt,
      );
}

/// Authoritative Task record returned by the backend.
@immutable
class TaskResponse {
  final String id;
  final String ownerId;
  final String title;
  final String? notes;
  final String category;
  final String status;
  final String priority;
  final String? dueDate;
  final int? reminderMinutesBefore;
  final String? reminderAt;
  final bool isDeleted;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  const TaskResponse({
    required this.id,
    required this.ownerId,
    required this.title,
    this.notes,
    this.category = 'general',
    required this.status,
    required this.priority,
    this.dueDate,
    this.reminderMinutesBefore,
    this.reminderAt,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskResponse.fromJson(Map<String, dynamic> json) {
    return TaskResponse(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      category: json['category'] as String? ?? 'general',
      status: json['status'] as String,
      priority: json['priority'] as String,
      dueDate: json['due_date'] as String?,
      reminderMinutesBefore: (json['reminder_minutes_before'] as num?)?.toInt(),
      reminderAt: json['reminder_at'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'notes': notes,
        'category': category,
        'status': status,
        'priority': priority,
        'due_date': dueDate,
        'reminder_minutes_before': reminderMinutesBefore,
        'reminder_at': reminderAt,
        'is_deleted': isDeleted,
        'deleted_at': deletedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskResponse &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ownerId == other.ownerId &&
          title == other.title &&
          notes == other.notes &&
          category == other.category &&
          status == other.status &&
          priority == other.priority &&
          dueDate == other.dueDate &&
          reminderMinutesBefore == other.reminderMinutesBefore &&
          reminderAt == other.reminderAt &&
          isDeleted == other.isDeleted &&
          deletedAt == other.deletedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        ownerId,
        title,
        notes,
        category,
        status,
        priority,
        dueDate,
        reminderMinutesBefore,
        reminderAt,
        isDeleted,
        deletedAt,
        createdAt,
        updatedAt,
      );
}

/// Paginated list of active Tasks.
@immutable
class TaskListResponse {
  final List<TaskResponse> items;
  final int total;

  const TaskListResponse({
    this.items = const [],
    required this.total,
  });

  factory TaskListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return TaskListResponse(
      items: rawItems
          .map((e) => TaskResponse.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
      };
}

/// Soft-deleted Task in Trash with remaining retention days.
///
/// All inherited TaskResponse fields are declared directly so static OpenAPI
/// parity checks inspect the full flattened schema cleanly.
@immutable
class TrashTaskResponse {
  final String id;
  final String ownerId;
  final String title;
  final String? notes;
  final String category;
  final String status;
  final String priority;
  final String? dueDate;
  final int? reminderMinutesBefore;
  final String? reminderAt;
  final bool isDeleted;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;
  final int expiresInDays;

  const TrashTaskResponse({
    required this.id,
    required this.ownerId,
    required this.title,
    this.notes,
    this.category = 'general',
    required this.status,
    required this.priority,
    this.dueDate,
    this.reminderMinutesBefore,
    this.reminderAt,
    this.isDeleted = true,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresInDays,
  });

  factory TrashTaskResponse.fromJson(Map<String, dynamic> json) {
    return TrashTaskResponse(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      category: json['category'] as String? ?? 'general',
      status: json['status'] as String,
      priority: json['priority'] as String,
      dueDate: json['due_date'] as String?,
      reminderMinutesBefore: (json['reminder_minutes_before'] as num?)?.toInt(),
      reminderAt: json['reminder_at'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? true,
      deletedAt: json['deleted_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      expiresInDays: (json['expires_in_days'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'notes': notes,
        'category': category,
        'status': status,
        'priority': priority,
        'due_date': dueDate,
        'reminder_minutes_before': reminderMinutesBefore,
        'reminder_at': reminderAt,
        'is_deleted': isDeleted,
        'deleted_at': deletedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'expires_in_days': expiresInDays,
      };
}

/// Paginated list of soft-deleted Tasks in Trash.
@immutable
class TrashListResponse {
  final List<TrashTaskResponse> items;
  final int total;

  const TrashListResponse({
    this.items = const [],
    required this.total,
  });

  factory TrashListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return TrashListResponse(
      items: rawItems
          .map((e) =>
              TrashTaskResponse.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
      };
}
