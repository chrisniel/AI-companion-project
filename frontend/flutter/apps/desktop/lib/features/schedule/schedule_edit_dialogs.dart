import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_schedule_controller.dart';
import 'quiet_hours_card.dart' show show12HourTimePicker;

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

enum _TaskReminderMode {
  none,
  atDue,
  min15,
  hour1,
  custom,
}

DateTime _defaultFutureLocal({int minutes = 30}) {
  final raw = DateTime.now().add(Duration(minutes: minutes));
  return DateTime(raw.year, raw.month, raw.day, raw.hour, raw.minute);
}

DateTime _todayAt(int hour, int minute) {
  final now = DateTime.now();
  var candidate = DateTime(now.year, now.month, now.day, hour, minute);
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

DateTime _tomorrowAt(int hour, int minute) {
  final now = DateTime.now().add(const Duration(days: 1));
  return DateTime(now.year, now.month, now.day, hour, minute);
}

TimeOfDay _timeOfDayFromWireOrDefault(String? hhmm, TimeOfDay fallback) {
  if (hhmm == null || hhmm.trim().isEmpty) return fallback;
  final parts = hhmm.trim().split(':');
  if (parts.length != 2) return fallback;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return fallback;
  }
  return TimeOfDay(hour: h, minute: m);
}

String _toWireHhMm(TimeOfDay tod) {
  final h = tod.hour.toString().padLeft(2, '0');
  final m = tod.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class ScheduleEditDialogs {
  static Future<void> showTaskDialog(
    BuildContext context, {
    required DesktopScheduleController controller,
    TaskResponse? existing,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime? dueLocal = parseServerUtcDateTime(existing?.dueDate);
    DateTime? customReminderLocal =
        parseServerUtcDateTime(existing?.reminderAt);

    var reminderMode = _TaskReminderMode.none;
    if (existing?.reminderMinutesBefore == 0) {
      reminderMode = _TaskReminderMode.atDue;
    } else if (existing?.reminderMinutesBefore == 15) {
      reminderMode = _TaskReminderMode.min15;
    } else if (existing?.reminderMinutesBefore == 60) {
      reminderMode = _TaskReminderMode.hour1;
    } else if (existing?.reminderMinutesBefore != null && dueLocal != null) {
      // Preserve non-standard minute offset via custom local timestamp if edited,
      // or default to custom picker pre-populated from reminderAt.
      reminderMode = _TaskReminderMode.custom;
      customReminderLocal ??=
          dueLocal.subtract(Duration(minutes: existing!.reminderMinutesBefore!));
    } else if (customReminderLocal != null) {
      reminderMode = _TaskReminderMode.custom;
    }

    var priority = existing?.priority ?? 'medium';
    var category = existing?.category ?? 'general';
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'New Task' : 'Edit Task'),
          content: SizedBox(
            width: 480,
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
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                          items: _kTaskPriorities
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => priority = v);
                          },
                        ),
                      ),
                      const SizedBox(width: CompanionSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _kTaskCategories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => category = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  const _SectionLabel(label: 'Due Date & Time (optional)'),
                  const SizedBox(height: CompanionSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _QuickChip(
                        label: 'Today 6:00 PM',
                        onPressed: () => setModalState(() {
                          dueLocal = _todayAt(18, 0);
                          validationError = null;
                        }),
                      ),
                      _QuickChip(
                        label: 'Tomorrow 9:00 AM',
                        onPressed: () => setModalState(() {
                          dueLocal = _tomorrowAt(9, 0);
                          validationError = null;
                        }),
                      ),
                      _QuickChip(
                        label: 'Next Week',
                        onPressed: () {
                          final next =
                              DateTime.now().add(const Duration(days: 7));
                          setModalState(() {
                            dueLocal = DateTime(
                              next.year,
                              next.month,
                              next.day,
                              9,
                              0,
                            );
                            validationError = null;
                          });
                        },
                      ),
                      if (dueLocal != null)
                        _QuickChip(
                          label: 'Clear Due',
                          onPressed: () => setModalState(() {
                            dueLocal = null;
                            if (reminderMode != _TaskReminderMode.custom) {
                              reminderMode = _TaskReminderMode.none;
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  _DateTimePickerRow(
                    dateKey: const Key('task_dialog_due_date_button'),
                    timeKey: const Key('task_dialog_due_time_button'),
                    value: dueLocal,
                    placeholder: 'No due date set',
                    defaultInitial: _todayAt(18, 0),
                    onChanged: (next) => setModalState(() {
                      dueLocal = next;
                      validationError = null;
                    }),
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  const _SectionLabel(label: 'Remind Me'),
                  const SizedBox(height: CompanionSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: reminderMode == _TaskReminderMode.none,
                        onSelected: (_) => setModalState(() {
                          reminderMode = _TaskReminderMode.none;
                          validationError = null;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('At due time'),
                        selected: reminderMode == _TaskReminderMode.atDue,
                        onSelected: (_) => setModalState(() {
                          dueLocal ??= _todayAt(18, 0);
                          reminderMode = _TaskReminderMode.atDue;
                          validationError = null;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('15m before'),
                        selected: reminderMode == _TaskReminderMode.min15,
                        onSelected: (_) => setModalState(() {
                          dueLocal ??= _todayAt(18, 0);
                          reminderMode = _TaskReminderMode.min15;
                          validationError = null;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('1h before'),
                        selected: reminderMode == _TaskReminderMode.hour1,
                        onSelected: (_) => setModalState(() {
                          dueLocal ??= _todayAt(18, 0);
                          reminderMode = _TaskReminderMode.hour1;
                          validationError = null;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Custom time'),
                        selected: reminderMode == _TaskReminderMode.custom,
                        onSelected: (_) => setModalState(() {
                          customReminderLocal ??=
                              dueLocal ?? _defaultFutureLocal(minutes: 30);
                          reminderMode = _TaskReminderMode.custom;
                          validationError = null;
                        }),
                      ),
                    ],
                  ),
                  if (reminderMode == _TaskReminderMode.custom) ...[
                    const SizedBox(height: CompanionSpacing.xs),
                    _DateTimePickerRow(
                      dateKey: const Key('task_dialog_custom_rem_date_button'),
                      timeKey: const Key('task_dialog_custom_rem_time_button'),
                      value: customReminderLocal,
                      placeholder: 'Select custom reminder time',
                      defaultInitial:
                          dueLocal ?? _defaultFutureLocal(minutes: 30),
                      onChanged: (next) => setModalState(() {
                        customReminderLocal = next;
                        validationError = null;
                      }),
                    ),
                  ],
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

                int? minutesBefore;
                DateTime? reminderDt;
                switch (reminderMode) {
                  case _TaskReminderMode.none:
                    break;
                  case _TaskReminderMode.atDue:
                    minutesBefore = 0;
                  case _TaskReminderMode.min15:
                    minutesBefore = 15;
                  case _TaskReminderMode.hour1:
                    minutesBefore = 60;
                  case _TaskReminderMode.custom:
                    if (customReminderLocal == null) {
                      setModalState(
                        () => validationError =
                            'Pick a custom reminder date and time.',
                      );
                      return;
                    }
                    reminderDt = customReminderLocal;
                }

                if (minutesBefore != null && dueLocal == null) {
                  setModalState(
                    () => validationError =
                        'Set a Due Date first, or pick Custom reminder time.',
                  );
                  return;
                }

                final notes = notesCtrl.text.trim();
                final dueIso = dueLocal?.toUtc().toIso8601String();
                final remIso = reminderDt?.toUtc().toIso8601String();
                final ok = existing == null
                    ? await controller.createTask(
                        TaskCreate(
                          title: title,
                          notes: notes.isEmpty ? null : notes,
                          category: category,
                          priority: priority,
                          dueDate: dueIso,
                          reminderMinutesBefore: minutesBefore,
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
                          reminderMinutesBefore: minutesBefore,
                          reminderAt: remIso,
                        ),
                        clearNotes: notes.isEmpty && existing.notes != null,
                        clearDueDate:
                            dueIso == null && existing.dueDate != null,
                        clearReminderMinutesBefore: minutesBefore == null &&
                            existing.reminderMinutesBefore != null,
                        clearReminderAt: remIso == null &&
                            minutesBefore == null &&
                            existing.reminderAt != null,
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
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime scheduledLocal =
        parseServerUtcDateTime(existing?.scheduledAt) ??
            _defaultFutureLocal(minutes: 30);
    final deviceTz = controller.effectiveDefaultTimezone;
    var timezone = existing?.timezone ?? deviceTz;
    if (timezone == 'UTC' && existing == null) {
      timezone = deviceTz;
    }
    var showCustomTimezone =
        existing != null && existing.timezone != deviceTz;
    var bypassQuietHours = existing?.bypassQuietHours ?? false;
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'New Reminder' : 'Edit Reminder'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('reminder_dialog_title_field'),
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reminder Title',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  const _SectionLabel(label: 'When (Local Time)'),
                  const SizedBox(height: CompanionSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _QuickChip(
                        label: 'In 15m',
                        onPressed: () => setModalState(() {
                          scheduledLocal = _defaultFutureLocal(minutes: 15);
                        }),
                      ),
                      _QuickChip(
                        label: 'In 1h',
                        onPressed: () => setModalState(() {
                          scheduledLocal = _defaultFutureLocal(minutes: 60);
                        }),
                      ),
                      _QuickChip(
                        label: 'Tonight 8:00 PM',
                        onPressed: () => setModalState(() {
                          scheduledLocal = _todayAt(20, 0);
                        }),
                      ),
                      _QuickChip(
                        label: 'Tomorrow 9:00 AM',
                        onPressed: () => setModalState(() {
                          scheduledLocal = _tomorrowAt(9, 0);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  KeyedSubtree(
                    key: const Key('reminder_dialog_when_field'),
                    child: _DateTimePickerRow(
                      dateKey: const Key('reminder_dialog_date_button'),
                      timeKey: const Key('reminder_dialog_time_button'),
                      value: scheduledLocal,
                      placeholder: 'Select date and time',
                      defaultInitial: scheduledLocal,
                      onChanged: (next) => setModalState(() {
                        if (next != null) scheduledLocal = next;
                      }),
                    ),
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  _AdvancedTimezonePicker(
                    deviceTimezone: deviceTz,
                    selectedTimezone: timezone,
                    expanded: showCustomTimezone,
                    onToggleExpanded: () => setModalState(() {
                      showCustomTimezone = !showCustomTimezone;
                      if (!showCustomTimezone) {
                        timezone = deviceTz;
                      }
                    }),
                    onTimezoneChanged: (v) =>
                        setModalState(() => timezone = v),
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
              key: const Key('reminder_dialog_save_button'),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  setModalState(() => validationError = 'Title is required.');
                  return;
                }
                final notes = notesCtrl.text.trim();
                final utcIso = scheduledLocal.toUtc().toIso8601String();
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
    var recurringTime = _timeOfDayFromWireOrDefault(
      existing?.timeOfDay,
      const TimeOfDay(hour: 7, minute: 0),
    );
    DateTime oneShotLocal =
        parseServerUtcDateTime(existing?.scheduledAt) ??
            _tomorrowAt(7, 0);
    final selectedDays = <int>{
      ...(existing?.recurrenceDays.isNotEmpty == true
          ? existing!.recurrenceDays
          : const [0, 1, 2, 3, 4]),
    };
    final deviceTz = controller.effectiveDefaultTimezone;
    var timezone = existing?.timezone ?? deviceTz;
    var showCustomTimezone =
        existing != null && existing.timezone != deviceTz;
    var bypassQuietHours = existing?.bypassQuietHours ?? true;
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'New Alarm' : 'Edit Alarm'),
          content: SizedBox(
            width: 480,
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
                  const SizedBox(height: CompanionSpacing.md),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Recurring')),
                      ButtonSegment(value: false, label: Text('One-Shot')),
                    ],
                    selected: {isRecurring},
                    onSelectionChanged: (sel) {
                      setModalState(() {
                        isRecurring = sel.first;
                        validationError = null;
                      });
                    },
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  if (isRecurring) ...[
                    const _SectionLabel(label: 'Alarm Time'),
                    const SizedBox(height: CompanionSpacing.xs),
                    _TimePillPickerButton(
                      key: const Key('alarm_dialog_time_field'),
                      time: recurringTime,
                      onChanged: (picked) =>
                          setModalState(() => recurringTime = picked),
                    ),
                    const SizedBox(height: CompanionSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _QuickChip(
                          label: '6:30 AM',
                          onPressed: () => setModalState(
                            () => recurringTime =
                                const TimeOfDay(hour: 6, minute: 30),
                          ),
                        ),
                        _QuickChip(
                          label: '7:00 AM',
                          onPressed: () => setModalState(
                            () => recurringTime =
                                const TimeOfDay(hour: 7, minute: 0),
                          ),
                        ),
                        _QuickChip(
                          label: '8:00 AM',
                          onPressed: () => setModalState(
                            () => recurringTime =
                                const TimeOfDay(hour: 8, minute: 0),
                          ),
                        ),
                        _QuickChip(
                          label: '9:00 PM',
                          onPressed: () => setModalState(
                            () => recurringTime =
                                const TimeOfDay(hour: 21, minute: 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CompanionSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel(label: 'Repeat Days'),
                        Wrap(
                          spacing: 6,
                          children: [
                            _QuickChip(
                              label: 'Weekdays',
                              onPressed: () => setModalState(() {
                                selectedDays
                                  ..clear()
                                  ..addAll(const [0, 1, 2, 3, 4]);
                                validationError = null;
                              }),
                            ),
                            _QuickChip(
                              label: 'Every day',
                              onPressed: () => setModalState(() {
                                selectedDays
                                  ..clear()
                                  ..addAll(const [0, 1, 2, 3, 4, 5, 6]);
                                validationError = null;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: CompanionSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(_kWeekdayLabels.length, (idx) {
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
                    const _SectionLabel(label: 'One-Shot Date & Time'),
                    const SizedBox(height: CompanionSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _QuickChip(
                          label: 'In 15m',
                          onPressed: () => setModalState(() {
                            oneShotLocal = _defaultFutureLocal(minutes: 15);
                          }),
                        ),
                        _QuickChip(
                          label: 'In 1h',
                          onPressed: () => setModalState(() {
                            oneShotLocal = _defaultFutureLocal(minutes: 60);
                          }),
                        ),
                        _QuickChip(
                          label: 'Tonight 8:00 PM',
                          onPressed: () => setModalState(() {
                            oneShotLocal = _todayAt(20, 0);
                          }),
                        ),
                        _QuickChip(
                          label: 'Tomorrow 7:00 AM',
                          onPressed: () => setModalState(() {
                            oneShotLocal = _tomorrowAt(7, 0);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: CompanionSpacing.xs),
                    KeyedSubtree(
                      key: const Key('alarm_dialog_time_field'),
                      child: _DateTimePickerRow(
                        dateKey: const Key('alarm_dialog_oneshot_date_button'),
                        timeKey: const Key('alarm_dialog_oneshot_time_button'),
                        value: oneShotLocal,
                        placeholder: 'Select alarm date and time',
                        defaultInitial: oneShotLocal,
                        onChanged: (next) => setModalState(() {
                          if (next != null) oneShotLocal = next;
                        }),
                      ),
                    ),
                  ],
                  const SizedBox(height: CompanionSpacing.md),
                  _AdvancedTimezonePicker(
                    deviceTimezone: deviceTz,
                    selectedTimezone: timezone,
                    expanded: showCustomTimezone,
                    onToggleExpanded: () => setModalState(() {
                      showCustomTimezone = !showCustomTimezone;
                      if (!showCustomTimezone) {
                        timezone = deviceTz;
                      }
                    }),
                    onTimezoneChanged: (v) =>
                        setModalState(() => timezone = v),
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
                  setModalState(
                    () => validationError = 'Alarm label is required.',
                  );
                  return;
                }
                List<int>? sortedDays;
                String? hhmm;
                String? oneShotIso;
                if (isRecurring) {
                  if (selectedDays.isEmpty) {
                    setModalState(
                      () => validationError = 'Select at least one weekday.',
                    );
                    return;
                  }
                  hhmm = _toWireHhMm(recurringTime);
                  sortedDays = selectedDays.toList()..sort();
                } else {
                  oneShotIso = oneShotLocal.toUtc().toIso8601String();
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
                          clearTimeOfDay:
                              !isRecurring && existing.timeOfDay != null,
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
    var routineTime = _timeOfDayFromWireOrDefault(
      existing?.timeOfDay,
      const TimeOfDay(hour: 9, minute: 0),
    );
    final selectedDays = <int>{
      ...(existing?.recurrenceDays ?? const [0, 1, 2, 3, 4, 5, 6]),
    };
    final deviceTz = controller.effectiveDefaultTimezone;
    var timezone = existing?.timezone ?? deviceTz;
    var showCustomTimezone =
        existing != null && existing.timezone != deviceTz;
    var bypassQuietHours = existing?.bypassQuietHours ?? false;
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(existing == null ? 'New Routine' : 'Edit Routine'),
          content: SizedBox(
            width: 480,
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
                    decoration: const InputDecoration(
                      labelText: 'Deterministic Check-In Message',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  const _SectionLabel(label: 'Check-In Time'),
                  const SizedBox(height: CompanionSpacing.xs),
                  _TimePillPickerButton(
                    key: const Key('routine_dialog_time_field'),
                    time: routineTime,
                    onChanged: (picked) =>
                        setModalState(() => routineTime = picked),
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _QuickChip(
                        label: '8:30 AM',
                        onPressed: () => setModalState(
                          () => routineTime =
                              const TimeOfDay(hour: 8, minute: 30),
                        ),
                      ),
                      _QuickChip(
                        label: '12:30 PM',
                        onPressed: () => setModalState(
                          () => routineTime =
                              const TimeOfDay(hour: 12, minute: 30),
                        ),
                      ),
                      _QuickChip(
                        label: '6:00 PM',
                        onPressed: () => setModalState(
                          () => routineTime =
                              const TimeOfDay(hour: 18, minute: 0),
                        ),
                      ),
                      _QuickChip(
                        label: '9:00 PM',
                        onPressed: () => setModalState(
                          () => routineTime =
                              const TimeOfDay(hour: 21, minute: 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel(label: 'Days'),
                      Wrap(
                        spacing: 6,
                        children: [
                          _QuickChip(
                            label: 'Weekdays',
                            onPressed: () => setModalState(() {
                              selectedDays
                                ..clear()
                                ..addAll(const [0, 1, 2, 3, 4]);
                            }),
                          ),
                          _QuickChip(
                            label: 'Every day',
                            onPressed: () => setModalState(() {
                              selectedDays
                                ..clear()
                                ..addAll(const [0, 1, 2, 3, 4, 5, 6]);
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(_kWeekdayLabels.length, (idx) {
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
                  const SizedBox(height: CompanionSpacing.md),
                  _AdvancedTimezonePicker(
                    deviceTimezone: deviceTz,
                    selectedTimezone: timezone,
                    expanded: showCustomTimezone,
                    onToggleExpanded: () => setModalState(() {
                      showCustomTimezone = !showCustomTimezone;
                      if (!showCustomTimezone) {
                        timezone = deviceTz;
                      }
                    }),
                    onTimezoneChanged: (v) =>
                        setModalState(() => timezone = v),
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
                final days = selectedDays.toList()..sort();
                final hhmm = _toWireHhMm(routineTime);
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    return Text(
      label,
      style: CompanionTypography.bodySmall.copyWith(
        color: ext?.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

class _TimePillPickerButton extends StatelessWidget {
  const _TimePillPickerButton({
    super.key,
    required this.time,
    required this.onChanged,
  });

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await show12HourTimePicker(
          context,
          initialTime: time,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: CompanionSpacing.md,
          vertical: CompanionSpacing.md,
        ),
        alignment: Alignment.centerLeft,
      ),
      icon: Icon(Icons.access_time_rounded, size: 18, color: ext?.accent),
      label: Text(
        formatTimeOfDay12h(time.hour, time.minute),
        style: CompanionTypography.titleMedium.copyWith(
          color: ext?.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DateTimePickerRow extends StatelessWidget {
  const _DateTimePickerRow({
    required this.dateKey,
    required this.timeKey,
    required this.value,
    required this.placeholder,
    required this.defaultInitial,
    required this.onChanged,
  });

  final Key dateKey;
  final Key timeKey;
  final DateTime? value;
  final String placeholder;
  final DateTime defaultInitial;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effective = value ?? defaultInitial;
    final dateText =
        value == null ? placeholder : formatDate12h(value!);
    final timeText = value == null
        ? 'Pick time'
        : formatTimeOfDay12h(value!.hour, value!.minute);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: OutlinedButton.icon(
            key: dateKey,
            onPressed: () async {
              final now = DateTime.now();
              final first = DateTime(now.year - 1);
              final last = DateTime(now.year + 5);
              final initial = effective.isBefore(first)
                  ? first
                  : (effective.isAfter(last) ? last : effective);
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: first,
                lastDate: last,
              );
              if (pickedDate == null) return;
              onChanged(
                DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  effective.hour,
                  effective.minute,
                ),
              );
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(dateText, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: CompanionSpacing.sm),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            key: timeKey,
            onPressed: () async {
              final pickedTime = await show12HourTimePicker(
                context,
                initialTime: TimeOfDay.fromDateTime(effective),
              );
              if (pickedTime == null) return;
              onChanged(
                DateTime(
                  effective.year,
                  effective.month,
                  effective.day,
                  pickedTime.hour,
                  pickedTime.minute,
                ),
              );
            },
            icon: const Icon(Icons.schedule_rounded, size: 16),
            label: Text(timeText, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class _AdvancedTimezonePicker extends StatelessWidget {
  const _AdvancedTimezonePicker({
    required this.deviceTimezone,
    required this.selectedTimezone,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTimezoneChanged,
  });

  final String deviceTimezone;
  final String selectedTimezone;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onTimezoneChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final options = kSupportedScheduleTimezones.contains(selectedTimezone)
        ? kSupportedScheduleTimezones
        : <String>[selectedTimezone, ...kSupportedScheduleTimezones];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.public_rounded, size: 15, color: ext?.textMuted),
            const SizedBox(width: CompanionSpacing.xs),
            Expanded(
              child: Text(
                expanded
                    ? 'Custom timezone override'
                    : 'Using PC timezone: $deviceTimezone',
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: onToggleExpanded,
              child: Text(
                expanded ? 'Use PC timezone' : 'Custom timezone (advanced)',
              ),
            ),
          ],
        ),
        if (expanded) ...[
          const SizedBox(height: CompanionSpacing.xs),
          DropdownButtonFormField<String>(
            initialValue: selectedTimezone,
            decoration: const InputDecoration(
              labelText: 'Timezone',
              border: OutlineInputBorder(),
            ),
            items: options
                .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                .toList(),
            onChanged: (v) {
              if (v != null) onTimezoneChanged(v);
            },
          ),
        ],
      ],
    );
  }
}
