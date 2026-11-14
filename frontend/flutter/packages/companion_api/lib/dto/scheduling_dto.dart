import 'package:meta/meta.dart';

bool _intListEquals(List<int>? a, List<int>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<int> _parseIntList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => (e as num).toInt()).toList();
}

/// Per-profile Quiet Hours configuration returned by the backend.
@immutable
class QuietHoursOut {
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final String quietHoursTimezone;

  const QuietHoursOut({
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    this.quietHoursTimezone = 'UTC',
  });

  factory QuietHoursOut.fromJson(Map<String, dynamic> json) {
    return QuietHoursOut(
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? false,
      quietHoursStart: json['quiet_hours_start'] as String? ?? '22:00',
      quietHoursEnd: json['quiet_hours_end'] as String? ?? '07:00',
      quietHoursTimezone: json['quiet_hours_timezone'] as String? ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() => {
        'quiet_hours_enabled': quietHoursEnabled,
        'quiet_hours_start': quietHoursStart,
        'quiet_hours_end': quietHoursEnd,
        'quiet_hours_timezone': quietHoursTimezone,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuietHoursOut &&
          runtimeType == other.runtimeType &&
          quietHoursEnabled == other.quietHoursEnabled &&
          quietHoursStart == other.quietHoursStart &&
          quietHoursEnd == other.quietHoursEnd &&
          quietHoursTimezone == other.quietHoursTimezone;

  @override
  int get hashCode => Object.hash(
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
        quietHoursTimezone,
      );
}

/// Partial update payload for PATCH /api/v1/profiles/me/quiet-hours.
@immutable
class QuietHoursUpdate {
  final bool? quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final String? quietHoursTimezone;

  const QuietHoursUpdate({
    this.quietHoursEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.quietHoursTimezone,
  });

  factory QuietHoursUpdate.fromJson(Map<String, dynamic> json) {
    return QuietHoursUpdate(
      quietHoursEnabled: json['quiet_hours_enabled'] as bool?,
      quietHoursStart: json['quiet_hours_start'] as String?,
      quietHoursEnd: json['quiet_hours_end'] as String?,
      quietHoursTimezone: json['quiet_hours_timezone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (quietHoursEnabled != null)
          'quiet_hours_enabled': quietHoursEnabled,
        if (quietHoursStart != null) 'quiet_hours_start': quietHoursStart,
        if (quietHoursEnd != null) 'quiet_hours_end': quietHoursEnd,
        if (quietHoursTimezone != null)
          'quiet_hours_timezone': quietHoursTimezone,
      };
}

/// Payload to snooze a reminder, alarm, or notification.
@immutable
class SnoozeRequest {
  final int minutes;
  final String? until;

  const SnoozeRequest({
    this.minutes = 10,
    this.until,
  });

  factory SnoozeRequest.fromJson(Map<String, dynamic> json) {
    return SnoozeRequest(
      minutes: (json['minutes'] as num?)?.toInt() ?? 10,
      until: json['until'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'minutes': minutes,
        if (until != null) 'until': until,
      };
}

/// Payload to acknowledge a reminder or notification.
@immutable
class AcknowledgeRequest {
  final bool completeTask;

  const AcknowledgeRequest({
    this.completeTask = true,
  });

  factory AcknowledgeRequest.fromJson(Map<String, dynamic> json) {
    return AcknowledgeRequest(
      completeTask: json['complete_task'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'complete_task': completeTask,
      };
}

/// Payload to create a Reminder via POST /api/v1/reminders.
@immutable
class ReminderCreate {
  final String? id;
  final String? taskId;
  final String title;
  final String? notes;
  final String scheduledAt;
  final String timezone;
  final bool bypassQuietHours;
  final String origin;

  const ReminderCreate({
    this.id,
    this.taskId,
    required this.title,
    this.notes,
    required this.scheduledAt,
    this.timezone = 'UTC',
    this.bypassQuietHours = false,
    this.origin = 'host',
  });

  factory ReminderCreate.fromJson(Map<String, dynamic> json) {
    return ReminderCreate(
      id: json['id'] as String?,
      taskId: json['task_id'] as String?,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      scheduledAt: json['scheduled_at'] as String,
      timezone: json['timezone'] as String? ?? 'UTC',
      bypassQuietHours: json['bypass_quiet_hours'] as bool? ?? false,
      origin: json['origin'] as String? ?? 'host',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (taskId != null) 'task_id': taskId,
        'title': title,
        if (notes != null) 'notes': notes,
        'scheduled_at': scheduledAt,
        'timezone': timezone,
        'bypass_quiet_hours': bypassQuietHours,
        'origin': origin,
      };
}

/// Partial update payload for PATCH /api/v1/reminders/{reminder_id}.
@immutable
class ReminderUpdate {
  final String? taskId;
  final bool clearTaskId;
  final String? title;
  final String? notes;
  final bool clearNotes;
  final String? scheduledAt;
  final String? timezone;
  final String? status;
  final String? snoozedUntil;
  final bool clearSnoozedUntil;
  final bool? bypassQuietHours;

  const ReminderUpdate({
    this.taskId,
    this.clearTaskId = false,
    this.title,
    this.notes,
    this.clearNotes = false,
    this.scheduledAt,
    this.timezone,
    this.status,
    this.snoozedUntil,
    this.clearSnoozedUntil = false,
    this.bypassQuietHours,
  });

  factory ReminderUpdate.fromJson(Map<String, dynamic> json) {
    return ReminderUpdate(
      taskId: json['task_id'] as String?,
      clearTaskId: json['clear_task_id'] as bool? ?? false,
      title: json['title'] as String?,
      notes: json['notes'] as String?,
      clearNotes: json['clear_notes'] as bool? ?? false,
      scheduledAt: json['scheduled_at'] as String?,
      timezone: json['timezone'] as String?,
      status: json['status'] as String?,
      snoozedUntil: json['snoozed_until'] as String?,
      clearSnoozedUntil: json['clear_snoozed_until'] as bool? ?? false,
      bypassQuietHours: json['bypass_quiet_hours'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (taskId != null) 'task_id': taskId,
        if (clearTaskId) 'clear_task_id': true,
        if (title != null) 'title': title,
        if (notes != null) 'notes': notes,
        if (clearNotes) 'clear_notes': true,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (timezone != null) 'timezone': timezone,
        if (status != null) 'status': status,
        if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
        if (clearSnoozedUntil) 'clear_snoozed_until': true,
        if (bypassQuietHours != null) 'bypass_quiet_hours': bypassQuietHours,
      };
}

/// Output representation of a stored Reminder.
@immutable
class ReminderOut {
  final String id;
  final String profileId;
  final String? taskId;
  final String title;
  final String? notes;
  final String scheduledAt;
  final String timezone;
  final String status;
  final String? snoozedUntil;
  final bool bypassQuietHours;
  final String origin;
  final String? firedAt;
  final String? acknowledgedAt;
  final String createdAt;
  final String updatedAt;

  const ReminderOut({
    required this.id,
    required this.profileId,
    this.taskId,
    required this.title,
    this.notes,
    required this.scheduledAt,
    required this.timezone,
    required this.status,
    this.snoozedUntil,
    required this.bypassQuietHours,
    required this.origin,
    this.firedAt,
    this.acknowledgedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReminderOut.fromJson(Map<String, dynamic> json) {
    return ReminderOut(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      taskId: json['task_id'] as String?,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      scheduledAt: json['scheduled_at'] as String,
      timezone: json['timezone'] as String,
      status: json['status'] as String,
      snoozedUntil: json['snoozed_until'] as String?,
      bypassQuietHours: json['bypass_quiet_hours'] as bool,
      origin: json['origin'] as String,
      firedAt: json['fired_at'] as String?,
      acknowledgedAt: json['acknowledged_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'task_id': taskId,
        'title': title,
        'notes': notes,
        'scheduled_at': scheduledAt,
        'timezone': timezone,
        'status': status,
        'snoozed_until': snoozedUntil,
        'bypass_quiet_hours': bypassQuietHours,
        'origin': origin,
        'fired_at': firedAt,
        'acknowledged_at': acknowledgedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

/// Paginated collection of Reminders.
@immutable
class ReminderListOut {
  final List<ReminderOut> items;
  final int total;

  const ReminderListOut({
    this.items = const [],
    required this.total,
  });

  factory ReminderListOut.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return ReminderListOut(
      items: rawItems
          .map((e) => ReminderOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
      };
}

/// Payload to create a one-shot or recurring weekday Alarm via POST /api/v1/alarms.
@immutable
class AlarmCreate {
  final String? id;
  final String label;
  final String? scheduledAt;
  final String? timeOfDay;
  final List<int>? recurrenceDays;
  final String timezone;
  final bool enabled;
  final bool bypassQuietHours;
  final String origin;

  const AlarmCreate({
    this.id,
    required this.label,
    this.scheduledAt,
    this.timeOfDay,
    this.recurrenceDays,
    this.timezone = 'UTC',
    this.enabled = true,
    this.bypassQuietHours = true,
    this.origin = 'host',
  });

  factory AlarmCreate.fromJson(Map<String, dynamic> json) {
    return AlarmCreate(
      id: json['id'] as String?,
      label: json['label'] as String,
      scheduledAt: json['scheduled_at'] as String?,
      timeOfDay: json['time_of_day'] as String?,
      recurrenceDays: json['recurrence_days'] == null
          ? null
          : _parseIntList(json['recurrence_days']),
      timezone: json['timezone'] as String? ?? 'UTC',
      enabled: json['enabled'] as bool? ?? true,
      bypassQuietHours: json['bypass_quiet_hours'] as bool? ?? true,
      origin: json['origin'] as String? ?? 'host',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'label': label,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (timeOfDay != null) 'time_of_day': timeOfDay,
        if (recurrenceDays != null) 'recurrence_days': recurrenceDays,
        'timezone': timezone,
        'enabled': enabled,
        'bypass_quiet_hours': bypassQuietHours,
        'origin': origin,
      };
}

/// Partial update payload for PATCH /api/v1/alarms/{alarm_id}.
@immutable
class AlarmUpdate {
  final String? label;
  final String? scheduledAt;
  final String? timeOfDay;
  final bool clearTimeOfDay;
  final List<int>? recurrenceDays;
  final bool clearRecurrenceDays;
  final String? timezone;
  final bool? enabled;
  final String? status;
  final String? snoozedUntil;
  final bool clearSnoozedUntil;
  final bool? bypassQuietHours;

  const AlarmUpdate({
    this.label,
    this.scheduledAt,
    this.timeOfDay,
    this.clearTimeOfDay = false,
    this.recurrenceDays,
    this.clearRecurrenceDays = false,
    this.timezone,
    this.enabled,
    this.status,
    this.snoozedUntil,
    this.clearSnoozedUntil = false,
    this.bypassQuietHours,
  });

  factory AlarmUpdate.fromJson(Map<String, dynamic> json) {
    return AlarmUpdate(
      label: json['label'] as String?,
      scheduledAt: json['scheduled_at'] as String?,
      timeOfDay: json['time_of_day'] as String?,
      clearTimeOfDay: json['clear_time_of_day'] as bool? ?? false,
      recurrenceDays: json['recurrence_days'] == null
          ? null
          : _parseIntList(json['recurrence_days']),
      clearRecurrenceDays: json['clear_recurrence_days'] as bool? ?? false,
      timezone: json['timezone'] as String?,
      enabled: json['enabled'] as bool?,
      status: json['status'] as String?,
      snoozedUntil: json['snoozed_until'] as String?,
      clearSnoozedUntil: json['clear_snoozed_until'] as bool? ?? false,
      bypassQuietHours: json['bypass_quiet_hours'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (label != null) 'label': label,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (timeOfDay != null) 'time_of_day': timeOfDay,
        if (clearTimeOfDay) 'clear_time_of_day': true,
        if (recurrenceDays != null) 'recurrence_days': recurrenceDays,
        if (clearRecurrenceDays) 'clear_recurrence_days': true,
        if (timezone != null) 'timezone': timezone,
        if (enabled != null) 'enabled': enabled,
        if (status != null) 'status': status,
        if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
        if (clearSnoozedUntil) 'clear_snoozed_until': true,
        if (bypassQuietHours != null) 'bypass_quiet_hours': bypassQuietHours,
      };
}

/// Output representation of a stored Alarm.
@immutable
class AlarmOut {
  final String id;
  final String profileId;
  final String label;
  final String scheduledAt;
  final String? timeOfDay;
  final List<int> recurrenceDays;
  final String timezone;
  final bool enabled;
  final String status;
  final String? snoozedUntil;
  final bool bypassQuietHours;
  final String origin;
  final String? lastFiredAt;
  final String? acknowledgedAt;
  final String createdAt;
  final String updatedAt;

  const AlarmOut({
    required this.id,
    required this.profileId,
    required this.label,
    required this.scheduledAt,
    this.timeOfDay,
    this.recurrenceDays = const [],
    required this.timezone,
    required this.enabled,
    required this.status,
    this.snoozedUntil,
    required this.bypassQuietHours,
    required this.origin,
    this.lastFiredAt,
    this.acknowledgedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AlarmOut.fromJson(Map<String, dynamic> json) {
    return AlarmOut(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      label: json['label'] as String,
      scheduledAt: json['scheduled_at'] as String,
      timeOfDay: json['time_of_day'] as String?,
      recurrenceDays: _parseIntList(json['recurrence_days']),
      timezone: json['timezone'] as String,
      enabled: json['enabled'] as bool,
      status: json['status'] as String,
      snoozedUntil: json['snoozed_until'] as String?,
      bypassQuietHours: json['bypass_quiet_hours'] as bool,
      origin: json['origin'] as String,
      lastFiredAt: json['last_fired_at'] as String?,
      acknowledgedAt: json['acknowledged_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'label': label,
        'scheduled_at': scheduledAt,
        'time_of_day': timeOfDay,
        'recurrence_days': recurrenceDays,
        'timezone': timezone,
        'enabled': enabled,
        'status': status,
        'snoozed_until': snoozedUntil,
        'bypass_quiet_hours': bypassQuietHours,
        'origin': origin,
        'last_fired_at': lastFiredAt,
        'acknowledged_at': acknowledgedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmOut &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          profileId == other.profileId &&
          label == other.label &&
          scheduledAt == other.scheduledAt &&
          timeOfDay == other.timeOfDay &&
          _intListEquals(recurrenceDays, other.recurrenceDays) &&
          timezone == other.timezone &&
          enabled == other.enabled &&
          status == other.status &&
          snoozedUntil == other.snoozedUntil &&
          bypassQuietHours == other.bypassQuietHours &&
          origin == other.origin &&
          lastFiredAt == other.lastFiredAt &&
          acknowledgedAt == other.acknowledgedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        profileId,
        label,
        scheduledAt,
        timeOfDay,
        Object.hashAll(recurrenceDays),
        timezone,
        enabled,
        status,
        snoozedUntil,
        bypassQuietHours,
        origin,
        lastFiredAt,
        acknowledgedAt,
        createdAt,
        updatedAt,
      );
}

/// Paginated collection of Alarms.
@immutable
class AlarmListOut {
  final List<AlarmOut> items;
  final int total;

  const AlarmListOut({
    this.items = const [],
    required this.total,
  });

  factory AlarmListOut.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return AlarmListOut(
      items: rawItems
          .map((e) => AlarmOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
      };
}

/// Payload to create a scheduled check-in Routine via POST /api/v1/routines.
@immutable
class RoutineCreate {
  final String title;
  final String? promptTemplate;
  final String fallbackMessage;
  final String timeOfDay;
  final List<int>? recurrenceDays;
  final String timezone;
  final bool enabled;
  final bool bypassQuietHours;

  const RoutineCreate({
    required this.title,
    this.promptTemplate,
    required this.fallbackMessage,
    required this.timeOfDay,
    this.recurrenceDays,
    this.timezone = 'UTC',
    this.enabled = true,
    this.bypassQuietHours = false,
  });

  factory RoutineCreate.fromJson(Map<String, dynamic> json) {
    return RoutineCreate(
      title: json['title'] as String,
      promptTemplate: json['prompt_template'] as String?,
      fallbackMessage: json['fallback_message'] as String,
      timeOfDay: json['time_of_day'] as String,
      recurrenceDays: json['recurrence_days'] == null
          ? null
          : _parseIntList(json['recurrence_days']),
      timezone: json['timezone'] as String? ?? 'UTC',
      enabled: json['enabled'] as bool? ?? true,
      bypassQuietHours: json['bypass_quiet_hours'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        if (promptTemplate != null) 'prompt_template': promptTemplate,
        'fallback_message': fallbackMessage,
        'time_of_day': timeOfDay,
        if (recurrenceDays != null) 'recurrence_days': recurrenceDays,
        'timezone': timezone,
        'enabled': enabled,
        'bypass_quiet_hours': bypassQuietHours,
      };
}

/// Partial update payload for PATCH /api/v1/routines/{routine_id}.
@immutable
class RoutineUpdate {
  final String? title;
  final String? promptTemplate;
  final bool clearPromptTemplate;
  final String? fallbackMessage;
  final String? timeOfDay;
  final List<int>? recurrenceDays;
  final bool clearRecurrenceDays;
  final String? timezone;
  final bool? enabled;
  final bool? bypassQuietHours;

  const RoutineUpdate({
    this.title,
    this.promptTemplate,
    this.clearPromptTemplate = false,
    this.fallbackMessage,
    this.timeOfDay,
    this.recurrenceDays,
    this.clearRecurrenceDays = false,
    this.timezone,
    this.enabled,
    this.bypassQuietHours,
  });

  factory RoutineUpdate.fromJson(Map<String, dynamic> json) {
    return RoutineUpdate(
      title: json['title'] as String?,
      promptTemplate: json['prompt_template'] as String?,
      clearPromptTemplate: json['clear_prompt_template'] as bool? ?? false,
      fallbackMessage: json['fallback_message'] as String?,
      timeOfDay: json['time_of_day'] as String?,
      recurrenceDays: json['recurrence_days'] == null
          ? null
          : _parseIntList(json['recurrence_days']),
      clearRecurrenceDays: json['clear_recurrence_days'] as bool? ?? false,
      timezone: json['timezone'] as String?,
      enabled: json['enabled'] as bool?,
      bypassQuietHours: json['bypass_quiet_hours'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (promptTemplate != null) 'prompt_template': promptTemplate,
        if (clearPromptTemplate) 'clear_prompt_template': true,
        if (fallbackMessage != null) 'fallback_message': fallbackMessage,
        if (timeOfDay != null) 'time_of_day': timeOfDay,
        if (recurrenceDays != null) 'recurrence_days': recurrenceDays,
        if (clearRecurrenceDays) 'clear_recurrence_days': true,
        if (timezone != null) 'timezone': timezone,
        if (enabled != null) 'enabled': enabled,
        if (bypassQuietHours != null) 'bypass_quiet_hours': bypassQuietHours,
      };
}

/// Output representation of a stored Routine.
@immutable
class RoutineOut {
  final String id;
  final String profileId;
  final String title;
  final String? promptTemplate;
  final String fallbackMessage;
  final String timeOfDay;
  final List<int> recurrenceDays;
  final String timezone;
  final bool enabled;
  final bool bypassQuietHours;
  final String? nextRunAt;
  final String? lastRunAt;
  final String? lastStatus;
  final String createdAt;
  final String updatedAt;

  const RoutineOut({
    required this.id,
    required this.profileId,
    required this.title,
    this.promptTemplate,
    required this.fallbackMessage,
    required this.timeOfDay,
    this.recurrenceDays = const [],
    required this.timezone,
    required this.enabled,
    required this.bypassQuietHours,
    this.nextRunAt,
    this.lastRunAt,
    this.lastStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoutineOut.fromJson(Map<String, dynamic> json) {
    return RoutineOut(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      title: json['title'] as String,
      promptTemplate: json['prompt_template'] as String?,
      fallbackMessage: json['fallback_message'] as String,
      timeOfDay: json['time_of_day'] as String,
      recurrenceDays: _parseIntList(json['recurrence_days']),
      timezone: json['timezone'] as String,
      enabled: json['enabled'] as bool,
      bypassQuietHours: json['bypass_quiet_hours'] as bool,
      nextRunAt: json['next_run_at'] as String?,
      lastRunAt: json['last_run_at'] as String?,
      lastStatus: json['last_status'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'title': title,
        'prompt_template': promptTemplate,
        'fallback_message': fallbackMessage,
        'time_of_day': timeOfDay,
        'recurrence_days': recurrenceDays,
        'timezone': timezone,
        'enabled': enabled,
        'bypass_quiet_hours': bypassQuietHours,
        'next_run_at': nextRunAt,
        'last_run_at': lastRunAt,
        'last_status': lastStatus,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

/// Paginated collection of Routines.
@immutable
class RoutineListOut {
  final List<RoutineOut> items;
  final int total;

  const RoutineListOut({
    this.items = const [],
    required this.total,
  });

  factory RoutineListOut.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return RoutineListOut(
      items: rawItems
          .map((e) => RoutineOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
      };
}

/// Output representation of a durable Notification Backlog event.
@immutable
class NotificationEventOut {
  final String id;
  final String profileId;
  final String sourceType;
  final String sourceId;
  final String urgency;
  final String title;
  final String? body;
  final String status;
  final String deliveryPolicy;
  final bool isMissedCatchup;
  final String triggeredAt;
  final String? readAt;
  final String? resolvedAt;
  final String createdAt;
  final String updatedAt;

  const NotificationEventOut({
    required this.id,
    required this.profileId,
    required this.sourceType,
    required this.sourceId,
    required this.urgency,
    required this.title,
    this.body,
    required this.status,
    required this.deliveryPolicy,
    required this.isMissedCatchup,
    required this.triggeredAt,
    this.readAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationEventOut.fromJson(Map<String, dynamic> json) {
    return NotificationEventOut(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      sourceType: json['source_type'] as String,
      sourceId: json['source_id'] as String,
      urgency: json['urgency'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      status: json['status'] as String,
      deliveryPolicy: json['delivery_policy'] as String,
      isMissedCatchup: json['is_missed_catchup'] as bool,
      triggeredAt: json['triggered_at'] as String,
      readAt: json['read_at'] as String?,
      resolvedAt: json['resolved_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'source_type': sourceType,
        'source_id': sourceId,
        'urgency': urgency,
        'title': title,
        'body': body,
        'status': status,
        'delivery_policy': deliveryPolicy,
        'is_missed_catchup': isMissedCatchup,
        'triggered_at': triggeredAt,
        'read_at': readAt,
        'resolved_at': resolvedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

/// Paginated collection of Notification Backlog events plus summary counts.
@immutable
class NotificationListOut {
  final List<NotificationEventOut> items;
  final int total;
  final int unreadCount;
  final int missedCount;

  const NotificationListOut({
    this.items = const [],
    required this.total,
    required this.unreadCount,
    required this.missedCount,
  });

  factory NotificationListOut.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return NotificationListOut(
      items: rawItems
          .map((e) =>
              NotificationEventOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num).toInt(),
      unreadCount: (json['unread_count'] as num).toInt(),
      missedCount: (json['missed_count'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'unread_count': unreadCount,
        'missed_count': missedCount,
      };
}

/// Result summary after clearing active notifications.
@immutable
class NotificationClearResponse {
  final int clearedCount;

  const NotificationClearResponse({
    required this.clearedCount,
  });

  factory NotificationClearResponse.fromJson(Map<String, dynamic> json) {
    return NotificationClearResponse(
      clearedCount: (json['cleared_count'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'cleared_count': clearedCount,
      };
}
