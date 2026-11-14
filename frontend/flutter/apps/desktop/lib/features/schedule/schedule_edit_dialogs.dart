import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_schedule_controller.dart';

const List<String> _kTaskPriorities = ['low', 'medium', 'high', 'urgent'];
const List<String> _kTaskCategories = [
  'general',
  'work',
  'personal',
  'dev',
  'shopping',
  'health',
];
const List<String> _kWeekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String _formatLocalDateTimeForInput(String? isoUtc) {
  if (isoUtc == null || isoUtc.isEmpty) return '';
  final parsed = DateTime.tryParse(isoUtc);
  if (parsed == null) return isoUtc;
  final local = parsed.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

DateTime? _parseUserDateTime(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.contains(' ') && !trimmed.contains('T')
      ? trimmed.replaceFirst(' ', 'T')
      : trimmed;
  return DateTime.tryParse(normalized);
}

bool _isValidHhMm(String raw) {
  final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(raw.trim());
  return match != null;
}

String _normalizeHhMm(String raw) {
  final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(raw.trim())!;
  final hh = match.group(1)!.padLeft(2, '0');
  final mm = match.group(2)!;
  return '$hh:$mm';
}

class ScheduleEditDialogs {
  static Future<void> showTaskDialog(
    BuildContext context, {
    required DesktopScheduleController controller,
    TaskResponse? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final dueCtrl = TextEditingController(
      text: _formatLocalDateTimeForInput(existing?.dueDate),
    );
    final reminderCtrl = TextEditingController(
      text: _formatLocalDateTimeForInput(existing?.reminderAt),
    );
    var priority = existing?.priority ?? 'medium';
    var category = existing?.category ?? 'general';
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'New Task' : 'Edit Task'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('task_dialog_title_field'),
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  TextField(
                    controller: notesCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _kTaskPriorities.contains(priority)
                              ? priority
                              : 'medium',
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                          items: _kTaskPriorities
                              .map((p) => DropdownMenuItem(
                                  value: p, child: Text(p.toUpperCase())))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => priority = v);
                          },
                        ),
                      ),
                      const SizedBox(width: CompanionSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _kTaskCategories.contains(category)
                              ? category
                              : 'general',
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _kTaskCategories
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => category = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  TextField(
                    controller: dueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Due Date (YYYY-MM-DD HH:MM, local, optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  TextField(
                    controller: reminderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reminder At (YYYY-MM-DD HH:MM, local, optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: CompanionSpacing.sm),
                    Text(
                      validationError!,
                      style: const TextStyle(color: CompanionColors.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('task_dialog_save_button'),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  setModalState(() => validationError = 'Title is required.');
                  return;
                }
                DateTime? dueDt;
                if (dueCtrl.text.trim().isNotEmpty) {
                  dueDt = _parseUserDateTime(dueCtrl.text);
                  if (dueDt == null) {
                    setModalState(
                      () => validationError =
                          'Invalid Due Date format. Use YYYY-MM-DD HH:MM.',
                    );
                    return;
                  }
                }
                DateTime? reminderDt;
                if (reminderCtrl.text.trim().isNotEmpty) {
                  reminderDt = _parseUserDateTime(reminderCtrl.text);
                  if (reminderDt == null) {
                    setModalState(
                      () => validationError =
                          'Invalid Reminder At format. Use YYYY-MM-DD HH:MM.',
                    );
                    return;
                  }
                }

                final notes = notesCtrl.text.trim();
                final dueIso = dueDt?.toUtc().toIso8601String();
                final remIso = reminderDt?.toUtc().toIso8601String();
                final ok = existing == null
                    ? await controller.createTask(
                        TaskCreate(
                          title: title,
                          notes: notes.isEmpty ? null : notes,
                          category: category,
                          priority: priority,
                          dueDate: dueIso,
                          reminderAt: remIso,
                        ),
                      )
                    : await controller.updateTask(
                        existing.id,
                        TaskUpdate(
                          title: title,
                          notes: notes.isEmpty ? null : notes,
                          category: category,
                          priority: priority,
                          dueDate: dueIso,
                          reminderAt: remIso,
                        ),
                        clearNotes: notes.isEmpty && existing.notes != null,
                        clearDueDate: dueIso == null && existing.dueDate != null,
                        clearReminderAt:
                            remIso == null && existing.reminderAt != null,
                      );
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                } else {
                  setModalState(
                    () => validationError =
                        controller.errorMessage ?? 'Unable to save task.',
                  );
                }
              },
              child: Text(existing == null ? 'Create Task' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showReminderDialog(
    BuildContext context, {
    required DesktopScheduleController controller,
    ReminderOut? existing,
  }) async {
    final defaultWhen = existing != null
        ? _formatLocalDateTimeForInput(existing.scheduledAt)
        : _formatLocalDateTimeForInput(
            DateTime.now().add(const Duration(minutes: 30)).toUtc().toIso8601String(),
          );
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final scheduledCtrl = TextEditingController(text: defaultWhen);
    var timezone = existing?.timezone ?? controller.quietHours.quietHoursTimezone;
    if (!kSupportedScheduleTimezones.contains(timezone)) {
      timezone = 'UTC';
    }
    var bypassQuietHours = existing?.bypassQuietHours ?? false;
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'New Reminder' : 'Edit Reminder'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('reminder_dialog_title_field'),
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  TextField(
                    controller: notesCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  TextField(
                    key: const Key('reminder_dialog_when_field'),
                    controller: scheduledCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Scheduled For (YYYY-MM-DD HH:MM, local)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: timezone,
                    decoration: const InputDecoration(
                      labelText: 'Timezone',
                      border: OutlineInputBorder(),
                    ),
                    items: kSupportedScheduleTimezones
                        .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => timezone = v);
                    },
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bypass Quiet Hours'),
                    subtitle: const Text(
                      'When enabled, reminder fires even during Quiet Hours.',
                    ),
                    value: bypassQuietHours,
                    onChanged: (v) => setModalState(() => bypassQuietHours = v),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: CompanionSpacing.xs),
                    Text(
                      validationError!,
                      style: const TextStyle(color: CompanionColors.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('reminder_dialog_save_button'),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  setModalState(() => validationError = 'Title is required.');
                  return;
                }
                final parsedWhen = _parseUserDateTime(scheduledCtrl.text);
                if (parsedWhen == null) {
                  setModalState(
                    () => validationError =
                        'Valid Scheduled For date/time is required (YYYY-MM-DD HH:MM).',
                  );
                  return;
                }
                final notes = notesCtrl.text.trim();
                final utcIso = parsedWhen.toUtc().toIso8601String();
                final ok = existing == null
                    ? await controller.createReminder(
                        ReminderCreate(
                          title: title,
                          notes: notes.isEmpty ? null : notes,
                          scheduledAt: utcIso,
                          timezone: timezone,
                          bypassQuietHours: bypassQuietHours,
                        ),
                      )
                    : await controller.updateReminder(
                        existing.id,
                        ReminderUpdate(
                          title: title,
                          notes: notes.isEmpty ? null : notes,
                          clearNotes: notes.isEmpty && existing.notes != null,
                          scheduledAt: utcIso,
                          timezone: timezone,
                          bypassQuietHours: bypassQuietHours,
                        ),
                      );
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                } else {
                  setModalState(
                    () => validationError =
                        controller.errorMessage ?? 'Unable to save reminder.',
                  );
                }
              },
              child: Text(existing == null ? 'Create Reminder' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showAlarmDialog(
    BuildContext context, {
    required DesktopScheduleController controller,
    AlarmOut? existing,
  }) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    var isRecurring = existing != null
        ? existing.recurrenceDays.isNotEmpty
        : true;
    final timeCtrl = TextEditingController(text: existing?.timeOfDay ?? '07:00');
    final oneShotCtrl = TextEditingController(
      text: _formatLocalDateTimeForInput(
        existing?.scheduledAt ??
            DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String(),
      ),
    );
    final selectedDays = <int>{
      ...(existing != null && existing.recurrenceDays.isNotEmpty
          ? existing.recurrenceDays
          : const [0, 1, 2, 3, 4]),
    };
    var timezone = existing?.timezone ?? controller.quietHours.quietHoursTimezone;
    if (!kSupportedScheduleTimezones.contains(timezone)) {
      timezone = 'UTC';
    }
    var bypassQuietHours = existing?.bypassQuietHours ?? true;
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'New Alarm' : 'Edit Alarm'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('alarm_dialog_label_field'),
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Alarm Label',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Recurring')),
                      ButtonSegment(value: false, label: Text('One-Shot')),
                    ],
                    selected: {isRecurring},
                    onSelectionChanged: (sel) =>
                        setModalState(() => isRecurring = sel.first),
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  if (isRecurring) ...[
                    TextField(
                      key: const Key('alarm_dialog_time_field'),
                      controller: timeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Time of Day (HH:MM, 24h)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: CompanionSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(7, (idx) {
                        final active = selectedDays.contains(idx);
                        return FilterChip(
                          label: Text(_kWeekdayLabels[idx]),
                          selected: active,
                          onSelected: (v) {
                            setModalState(() {
                              if (v) {
                                selectedDays.add(idx);
                              } else {
                                selectedDays.remove(idx);
                              }
                            });
                          },
                        );
                      }),
                    ),
                  ] else ...[
                    TextField(
                      controller: oneShotCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Alarm Date/Time (YYYY-MM-DD HH:MM, local)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: CompanionSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: timezone,
                    decoration: const InputDecoration(
                      labelText: 'Timezone',
                      border: OutlineInputBorder(),
                    ),
                    items: kSupportedScheduleTimezones
                        .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => timezone = v);
                    },
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bypass Quiet Hours (Recommended)'),
                    subtitle: const Text(
                      'Alarms bypass quiet hours by default to ensure wakefulness.',
                    ),
                    value: bypassQuietHours,
                    onChanged: (v) => setModalState(() => bypassQuietHours = v),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: CompanionSpacing.xs),
                    Text(
                      validationError!,
                      style: const TextStyle(color: CompanionColors.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('alarm_dialog_save_button'),
              onPressed: () async {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) {
                  setModalState(() => validationError = 'Alarm label is required.');
                  return;
                }
                List<int>? sortedDays;
                String? hhmm;
                String? oneShotIso;
                if (isRecurring) {
                  if (!_isValidHhMm(timeCtrl.text)) {
                    setModalState(
                      () => validationError = 'Valid HH:MM (00:00–23:59) is required.',
                    );
                    return;
                  }
                  if (selectedDays.isEmpty) {
                    setModalState(
                      () => validationError = 'Select at least one weekday.',
                    );
                    return;
                  }
                  hhmm = _normalizeHhMm(timeCtrl.text);
                  sortedDays = selectedDays.toList()..sort();
                } else {
                  final parsed = _parseUserDateTime(oneShotCtrl.text);
                  if (parsed == null) {
                    setModalState(
                      () => validationError = 'Valid YYYY-MM-DD HH:MM is required.',
                    );
                    return;
                  }
                  oneShotIso = parsed.toUtc().toIso8601String();
                }

                final bool shouldRearm = existing != null &&
                    (existing.status == 'ringing' ||
                        existing.status == 'snoozed' ||
                        existing.status == 'missed');

                final ok = existing == null
                    ? await controller.createAlarm(
                        AlarmCreate(
                          label: label,
                          scheduledAt: oneShotIso,
                          timeOfDay: hhmm,
                          recurrenceDays: sortedDays,
                          timezone: timezone,
                          enabled: true,
                          bypassQuietHours: bypassQuietHours,
                        ),
                      )
                    : await controller.updateAlarm(
                        existing.id,
                        AlarmUpdate(
                          label: label,
                          scheduledAt: isRecurring ? null : oneShotIso,
                          timeOfDay: isRecurring ? hhmm : null,
                          clearTimeOfDay: !isRecurring && existing.timeOfDay != null,
                          recurrenceDays: isRecurring ? sortedDays : null,
                          clearRecurrenceDays:
                              !isRecurring && existing.recurrenceDays.isNotEmpty,
                          timezone: timezone,
                          enabled: true,
                          status: shouldRearm ? 'armed' : null,
                          clearSnoozedUntil: shouldRearm,
                          bypassQuietHours: bypassQuietHours,
                        ),
                      );
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                } else {
                  setModalState(
                    () => validationError =
                        controller.errorMessage ?? 'Unable to save alarm.',
                  );
                }
              },
              child: Text(existing == null ? 'Create Alarm' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showRoutineDialog(
    BuildContext context, {
    required DesktopScheduleController controller,
    RoutineOut? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final fallbackCtrl = TextEditingController(
      text: existing?.fallbackMessage ?? 'How are things progressing right now?',
    );
    final timeCtrl = TextEditingController(text: existing?.timeOfDay ?? '09:00');
    final selectedDays = <int>{
      ...(existing != null && existing.recurrenceDays.isNotEmpty
          ? existing.recurrenceDays
          : const [0, 1, 2, 3, 4]),
    };
    var timezone = existing?.timezone ?? controller.quietHours.quietHoursTimezone;
    if (!kSupportedScheduleTimezones.contains(timezone)) {
      timezone = 'UTC';
    }
    var bypassQuietHours = existing?.bypassQuietHours ?? false;
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'New Routine' : 'Edit Routine'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('routine_dialog_title_field'),
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Routine Title',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  TextField(
                    key: const Key('routine_dialog_message_field'),
                    controller: fallbackCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deterministic Check-in Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Time of Day (HH:MM, 24h)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(7, (idx) {
                      final active = selectedDays.contains(idx);
                      return FilterChip(
                        label: Text(_kWeekdayLabels[idx]),
                        selected: active,
                        onSelected: (v) {
                          setModalState(() {
                            if (v) {
                              selectedDays.add(idx);
                            } else {
                              selectedDays.remove(idx);
                            }
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: timezone,
                    decoration: const InputDecoration(
                      labelText: 'Timezone',
                      border: OutlineInputBorder(),
                    ),
                    items: kSupportedScheduleTimezones
                        .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => timezone = v);
                    },
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bypass Quiet Hours'),
                    value: bypassQuietHours,
                    onChanged: (v) => setModalState(() => bypassQuietHours = v),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: CompanionSpacing.xs),
                    Text(
                      validationError!,
                      style: const TextStyle(color: CompanionColors.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('routine_dialog_save_button'),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final fallback = fallbackCtrl.text.trim();
                if (title.isEmpty || fallback.isEmpty) {
                  setModalState(
                    () => validationError =
                        'Title and deterministic check-in message are required.',
                  );
                  return;
                }
                if (!_isValidHhMm(timeCtrl.text)) {
                  setModalState(
                    () => validationError = 'Valid HH:MM (00:00–23:59) is required.',
                  );
                  return;
                }
                final days = selectedDays.toList()..sort();
                final hhmm = _normalizeHhMm(timeCtrl.text);
                final ok = existing == null
                    ? await controller.createRoutine(
                        RoutineCreate(
                          title: title,
                          fallbackMessage: fallback,
                          timeOfDay: hhmm,
                          recurrenceDays: days.isEmpty ? null : days,
                          timezone: timezone,
                          enabled: true,
                          bypassQuietHours: bypassQuietHours,
                        ),
                      )
                    : await controller.updateRoutine(
                        existing.id,
                        RoutineUpdate(
                          title: title,
                          fallbackMessage: fallback,
                          timeOfDay: hhmm,
                          recurrenceDays: days.isEmpty ? null : days,
                          clearRecurrenceDays:
                              days.isEmpty && existing.recurrenceDays.isNotEmpty,
                          timezone: timezone,
                          bypassQuietHours: bypassQuietHours,
                        ),
                      );
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                } else {
                  setModalState(
                    () => validationError =
                        controller.errorMessage ?? 'Unable to save routine.',
                  );
                }
              },
              child: Text(existing == null ? 'Create Routine' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
