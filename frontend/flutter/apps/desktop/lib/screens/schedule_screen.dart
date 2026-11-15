import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../features/schedule/desktop_schedule_controller.dart';
import '../features/schedule/schedule_edit_dialogs.dart';
import '../features/schedule/schedule_sidebar.dart';

const List<String> _kWeekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String _formatLocalDateTime(String? isoUtc) {
  if (isoUtc == null || isoUtc.isEmpty) return 'Not set';
  final parsed = parseServerUtcDateTime(isoUtc);
  if (parsed == null) return isoUtc;
  return formatDateTime12h(parsed);
}

String _formatRecurrenceDays(List<int> days) {
  if (days.isEmpty) return 'One-shot';
  final sorted = days.toSet().toList()..sort();
  if (sorted.length == 7) return 'Daily';
  if (sorted.length == 5 &&
      sorted[0] == 0 &&
      sorted[1] == 1 &&
      sorted[2] == 2 &&
      sorted[3] == 3 &&
      sorted[4] == 4) {
    return 'Mon–Fri';
  }
  return sorted
      .where((d) => d >= 0 && d < _kWeekdayShort.length)
      .map((d) => _kWeekdayShort[d])
      .join(', ');
}

/// Primary Schedule & Routines workspace for PC V1 (Option 2A 5-section layout).
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({
    super.key,
    this.controller,
    this.onNavigateToSettings,
    this.onNavigateToChat,
  });

  final DesktopScheduleController? controller;
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onNavigateToChat;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final ctrl = controller;

    if (ctrl == null) {
      return _buildStandaloneUnavailable(context, ext);
    }

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, ctrl, ext),
              if (ctrl.errorMessage != null) ...[
                const SizedBox(height: CompanionSpacing.md),
                _buildErrorBanner(ctrl, ext),
              ],
              const SizedBox(height: CompanionSpacing.lg),
              Expanded(
                child: !ctrl.isConnected ||
                        ctrl.profileId == null ||
                        ctrl.profileId!.isEmpty
                    ? _buildDisconnectedState(context, ext)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 720;
                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ScheduleSidebar(controller: ctrl, compact: true),
                                Expanded(
                                  child: _buildActiveSectionPanel(
                                    context,
                                    ctrl,
                                    ext,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ScheduleSidebar(controller: ctrl, compact: false),
                              const SizedBox(width: CompanionSpacing.lg),
                              Expanded(
                                child: _buildActiveSectionPanel(
                                  context,
                                  ctrl,
                                  ext,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStandaloneUnavailable(
    BuildContext context,
    CompanionThemeExtension? ext,
  ) {
    return Padding(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: SoftGlassPanel(
        padding: const EdgeInsets.all(CompanionSpacing.xxl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_rounded, size: 44, color: ext?.accent),
                const SizedBox(height: CompanionSpacing.md),
                Text(
                  'Schedule & Routines',
                  style: CompanionTypography.titleLarge.copyWith(
                    color: ext?.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: CompanionSpacing.xs),
                Text(
                  'Schedule workspace unavailable',
                  style: CompanionTypography.titleMedium.copyWith(
                    color: ext?.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: CompanionSpacing.sm),
                Text(
                  'No active schedule controller is attached to this desktop shell.',
                  style: CompanionTypography.bodyMedium.copyWith(
                    color: ext?.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onNavigateToSettings != null) ...[
                  const SizedBox(height: CompanionSpacing.lg),
                  FilledButton.icon(
                    onPressed: onNavigateToSettings,
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('Open Settings'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedState(
    BuildContext context,
    CompanionThemeExtension? ext,
  ) {
    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 44, color: ext?.textMuted),
              const SizedBox(height: CompanionSpacing.md),
              Text(
                'Connect & Select Profile to Manage Schedule',
                style: CompanionTypography.titleMedium.copyWith(
                  color: ext?.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CompanionSpacing.sm),
              Text(
                'Tasks, reminders, alarms, deterministic check-in routines, and Notification Center sync activate automatically once paired with the local runtime and unlocked with a Profile.',
                style: CompanionTypography.bodyMedium.copyWith(
                  color: ext?.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (onNavigateToSettings != null) ...[
                const SizedBox(height: CompanionSpacing.lg),
                FilledButton.icon(
                  onPressed: onNavigateToSettings,
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('Open Connection & Profile Settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    final canCreate = ctrl.isConnected &&
        ctrl.profileId != null &&
        ctrl.profileId!.isNotEmpty &&
        ctrl.selectedSection != ScheduleSection.notifications;

    final createLabel = switch (ctrl.selectedSection) {
      ScheduleSection.tasks => 'New Task',
      ScheduleSection.reminders => 'New Reminder',
      ScheduleSection.alarms => 'New Alarm',
      ScheduleSection.routines => 'New Routine',
      ScheduleSection.notifications => 'Notifications',
    };

    return Wrap(
      spacing: CompanionSpacing.md,
      runSpacing: CompanionSpacing.sm,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schedule & Routines',
                style: CompanionTypography.titleLarge.copyWith(
                  color: ext?.textPrimary,
                ),
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                'Tasks, scheduled reminders, high-urgency alarms, deterministic check-in routines, and Windows Notification Center.',
                style: CompanionTypography.bodySmall.copyWith(
                  color: ext?.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: CompanionSpacing.sm,
          runSpacing: CompanionSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (ctrl.isLoading || ctrl.isMutating)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            OutlinedButton.icon(
              key: const Key('schedule_refresh_button'),
              onPressed: (!ctrl.isConnected ||
                      ctrl.profileId == null ||
                      ctrl.isLoading)
                  ? null
                  : ctrl.refreshAll,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
            if (canCreate)
              FilledButton.icon(
                key: const Key('schedule_create_button'),
                onPressed: ctrl.isMutating
                    ? null
                    : () => _openCreateDialog(context, ctrl),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(createLabel),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner(
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    final danger = ext?.danger ?? CompanionColors.danger;
    return Container(
      key: const Key('schedule_error_banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: CompanionSpacing.md,
        vertical: CompanionSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.12),
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(color: danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: danger),
          const SizedBox(width: CompanionSpacing.sm),
          Expanded(
            child: Text(
              ctrl.errorMessage ?? '',
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: ctrl.refreshAll,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(
    BuildContext context,
    DesktopScheduleController ctrl,
  ) {
    return switch (ctrl.selectedSection) {
      ScheduleSection.tasks =>
        ScheduleEditDialogs.showTaskDialog(context, controller: ctrl),
      ScheduleSection.reminders =>
        ScheduleEditDialogs.showReminderDialog(context, controller: ctrl),
      ScheduleSection.alarms =>
        ScheduleEditDialogs.showAlarmDialog(context, controller: ctrl),
      ScheduleSection.routines =>
        ScheduleEditDialogs.showRoutineDialog(context, controller: ctrl),
      ScheduleSection.notifications => Future<void>.value(),
    };
  }

  Widget _buildActiveSectionPanel(
    BuildContext context,
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.lg),
      child: switch (ctrl.selectedSection) {
        ScheduleSection.tasks => _buildTasksSection(context, ctrl, ext),
        ScheduleSection.reminders => _buildRemindersSection(context, ctrl, ext),
        ScheduleSection.alarms => _buildAlarmsSection(context, ctrl, ext),
        ScheduleSection.routines => _buildRoutinesSection(context, ctrl, ext),
        ScheduleSection.notifications =>
          _buildNotificationsSection(context, ctrl, ext),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Tasks & Trash
  // ---------------------------------------------------------------------------

  Widget _buildTasksSection(
    BuildContext context,
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: CompanionSpacing.sm,
          runSpacing: CompanionSpacing.xs,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              ctrl.showTrashTasks ? 'Task Trash (30-Day Retention)' : 'Active Tasks',
              style: CompanionTypography.titleMedium.copyWith(
                color: ext?.textPrimary,
              ),
            ),
            SegmentedButton<bool>(
              key: const Key('tasks_view_toggle'),
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Active (${ctrl.tasks.length})'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Trash (${ctrl.trashTasks.length})'),
                ),
              ],
              selected: {ctrl.showTrashTasks},
              onSelectionChanged: (s) => ctrl.setShowTrashTasks(s.first),
            ),
          ],
        ),
        const SizedBox(height: CompanionSpacing.md),
        Expanded(
          child: ctrl.showTrashTasks
              ? _buildTrashList(ctrl, ext)
              : _buildActiveTaskList(context, ctrl, ext),
        ),
      ],
    );
  }

  Widget _buildActiveTaskList(
    BuildContext context,
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    if (ctrl.tasks.isEmpty) {
      return _buildEmptyState(
        ext,
        icon: Icons.task_alt_rounded,
        title: 'No active tasks yet',
        subtitle: 'Create a task with an optional due date and reminder trigger.',
      );
    }

    return ListView.separated(
      itemCount: ctrl.tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: CompanionSpacing.sm),
      itemBuilder: (context, index) {
        final task = ctrl.tasks[index];
        final isCompleted = task.status == 'completed';
        final priorityColor = switch (task.priority) {
          'urgent' => ext?.danger ?? CompanionColors.danger,
          'high' => ext?.warning ?? CompanionColors.warning,
          'medium' => ext?.accent ?? CompanionColors.lightAccent,
          _ => ext?.textSecondary ?? CompanionColors.lightTextSecondary,
        };

        return NeumorphicSurface(
          key: Key('task_card_${task.id}'),
          surfaceType: NeumorphicSurfaceType.flat,
          borderColor: ext?.borderSubtle,
          borderRadius: CompanionRadius.borderMd,
          padding: const EdgeInsets.all(CompanionSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    key: Key('task_complete_checkbox_${task.id}'),
                    value: isCompleted,
                    onChanged: ctrl.isMutating
                        ? null
                        : (_) => ctrl.toggleTaskCompletion(task),
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      style: CompanionTypography.bodyLarge.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w600,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: CompanionSpacing.sm),
                  _StatusPill(label: task.priority.toUpperCase(), color: priorityColor),
                  const SizedBox(width: CompanionSpacing.xs),
                  _StatusPill(
                    label: task.category,
                    color: ext?.textSecondary ?? CompanionColors.lightTextSecondary,
                  ),
                ],
              ),
              if (task.notes != null && task.notes!.trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 40, top: 4),
                  child: Text(
                    task.notes!,
                    style: CompanionTypography.bodySmall.copyWith(
                      color: ext?.textSecondary,
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 8),
                child: Wrap(
                  spacing: CompanionSpacing.md,
                  runSpacing: CompanionSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (task.dueDate != null)
                      _MetaChip(
                        icon: Icons.event_outlined,
                        text: 'Due ${_formatLocalDateTime(task.dueDate)}',
                        ext: ext,
                      ),
                    if (task.reminderAt != null)
                      _MetaChip(
                        icon: Icons.notifications_active_outlined,
                        text: 'Reminder ${_formatLocalDateTime(task.reminderAt)}',
                        ext: ext,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: CompanionSpacing.xs),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: CompanionSpacing.xs,
                overflowSpacing: CompanionSpacing.xs,
                children: [
                  TextButton.icon(
                    key: Key('task_edit_button_${task.id}'),
                    onPressed: ctrl.isMutating
                        ? null
                        : () => ScheduleEditDialogs.showTaskDialog(
                              context,
                              controller: ctrl,
                              existing: task,
                            ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    key: Key('task_delete_button_${task.id}'),
                    onPressed: ctrl.isMutating
                        ? null
                        : () => ctrl.deleteTask(task.id),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: ext?.danger ?? CompanionColors.danger,
                    ),
                    label: Text(
                      'Move to Trash',
                      style: TextStyle(color: ext?.danger ?? CompanionColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrashList(
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    if (ctrl.trashTasks.isEmpty) {
      return _buildEmptyState(
        ext,
        icon: Icons.delete_sweep_outlined,
        title: 'Trash is empty',
        subtitle: 'Deleted tasks stay recoverable for 30 days.',
      );
    }

    return ListView.separated(
      itemCount: ctrl.trashTasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: CompanionSpacing.sm),
      itemBuilder: (context, index) {
        final item = ctrl.trashTasks[index];
        return NeumorphicSurface(
          key: Key('trash_task_card_${item.id}'),
          surfaceType: NeumorphicSurfaceType.flat,
          borderColor: ext?.borderSubtle,
          borderRadius: CompanionRadius.borderMd,
          padding: const EdgeInsets.all(CompanionSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: CompanionTypography.bodyLarge.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expires in ${item.expiresInDays} day(s) · Category: ${item.category}',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Wrap(
                spacing: CompanionSpacing.xs,
                children: [
                  OutlinedButton.icon(
                    key: Key('trash_restore_button_${item.id}'),
                    onPressed: ctrl.isMutating
                        ? null
                        : () => ctrl.restoreTask(item.id),
                    icon: const Icon(Icons.restore_from_trash_rounded, size: 16),
                    label: const Text('Restore'),
                  ),
                  TextButton.icon(
                    key: Key('trash_permanent_delete_button_${item.id}'),
                    onPressed: ctrl.isMutating
                        ? null
                        : () => ctrl.permanentDeleteTask(item.id),
                    icon: Icon(
                      Icons.delete_forever_outlined,
                      size: 16,
                      color: ext?.danger ?? CompanionColors.danger,
                    ),
                    label: Text(
                      'Delete Forever',
                      style: TextStyle(color: ext?.danger ?? CompanionColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Reminders
  // ---------------------------------------------------------------------------

  Widget _buildRemindersSection(
    BuildContext context,
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reminders',
          style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
        ),
        const SizedBox(height: CompanionSpacing.md),
        Expanded(
          child: ctrl.reminders.isEmpty
              ? _buildEmptyState(
                  ext,
                  icon: Icons.notifications_active_outlined,
                  title: 'No reminders scheduled',
                  subtitle: 'Create standalone reminders or attach reminders to tasks.',
                )
              : ListView.separated(
                  itemCount: ctrl.reminders.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: CompanionSpacing.sm),
                  itemBuilder: (context, index) {
                    final r = ctrl.reminders[index];
                    final statusColor = _statusColor(r.status, ext);
                    final canAck = r.status == 'fired' || r.status == 'snoozed';
                    final canSnooze =
                        r.status == 'fired' || r.status == 'scheduled' || r.status == 'snoozed';

                    return NeumorphicSurface(
                      key: Key('reminder_card_${r.id}'),
                      surfaceType: NeumorphicSurfaceType.flat,
                      borderColor: ext?.borderSubtle,
                      borderRadius: CompanionRadius.borderMd,
                      padding: const EdgeInsets.all(CompanionSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.title,
                                  style: CompanionTypography.bodyLarge.copyWith(
                                    color: ext?.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (r.taskId != null) ...[
                                _StatusPill(
                                  label: 'TASK LINKED',
                                  color: ext?.accent ?? CompanionColors.lightAccent,
                                ),
                                const SizedBox(width: CompanionSpacing.xs),
                              ],
                              if (r.bypassQuietHours) ...[
                                _StatusPill(
                                  label: 'BYPASS QUIET',
                                  color: ext?.warning ?? CompanionColors.warning,
                                ),
                                const SizedBox(width: CompanionSpacing.xs),
                              ],
                              _StatusPill(
                                label: r.status.toUpperCase(),
                                color: statusColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: CompanionSpacing.md,
                            runSpacing: CompanionSpacing.xs,
                            children: [
                              _MetaChip(
                                icon: Icons.schedule_rounded,
                                text:
                                    '${_formatLocalDateTime(r.scheduledAt)} (${r.timezone})',
                                ext: ext,
                              ),
                              if (r.snoozedUntil != null)
                                _MetaChip(
                                  icon: Icons.snooze_rounded,
                                  text:
                                      'Snoozed until ${_formatLocalDateTime(r.snoozedUntil)}',
                                  ext: ext,
                                ),
                            ],
                          ),
                          if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              r.notes!,
                              style: CompanionTypography.bodySmall.copyWith(
                                color: ext?.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: CompanionSpacing.sm),
                          OverflowBar(
                            alignment: MainAxisAlignment.end,
                            spacing: CompanionSpacing.xs,
                            overflowSpacing: CompanionSpacing.xs,
                            children: [
                              if (canAck)
                                FilledButton.tonal(
                                  key: Key('reminder_ack_button_${r.id}'),
                                  onPressed: ctrl.isMutating
                                      ? null
                                      : () => ctrl.acknowledgeReminder(
                                            r.id,
                                            completeTask: r.taskId != null,
                                          ),
                                  child: Text(
                                    r.taskId != null ? 'Mark Done' : 'Got it',
                                  ),
                                ),
                              if (canSnooze)
                                OutlinedButton(
                                  key: Key('reminder_snooze_button_${r.id}'),
                                  onPressed: ctrl.isMutating
                                      ? null
                                      : () => ctrl.snoozeReminder(r.id),
                                  child: const Text('Snooze 10m'),
                                ),
                              if (canAck)
                                TextButton(
                                  key: Key('reminder_dismiss_button_${r.id}'),
                                  onPressed: ctrl.isMutating
                                      ? null
                                      : () => ctrl.dismissReminder(r.id),
                                  child: const Text('Dismiss'),
                                ),
                              TextButton.icon(
                                onPressed: ctrl.isMutating
                                    ? null
                                    : () => ScheduleEditDialogs.showReminderDialog(
                                          context,
                                          controller: ctrl,
                                          existing: r,
                                        ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit'),
                              ),
                              TextButton.icon(
                                onPressed: ctrl.isMutating
                                    ? null
                                    : () => ctrl.deleteReminder(r.id),
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: ext?.danger ?? CompanionColors.danger,
                                ),
                                label: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: ext?.danger ?? CompanionColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Alarms
  // ---------------------------------------------------------------------------

  Widget _buildAlarmsSection(
    BuildContext context,
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Alarms (High Urgency)',
          style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
        ),
        const SizedBox(height: CompanionSpacing.md),
        Expanded(
          child: ctrl.alarms.isEmpty
              ? _buildEmptyState(
                  ext,
                  icon: Icons.alarm_rounded,
                  title: 'No alarms configured',
                  subtitle:
                      'Alarms bypass quiet hours by default and trigger prominent Windows Action Center alerts.',
                )
              : ListView.separated(
                  itemCount: ctrl.alarms.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: CompanionSpacing.sm),
                  itemBuilder: (context, index) {
                    final a = ctrl.alarms[index];
                    final statusColor = _statusColor(a.status, ext);
                    final isRinging =
                        a.status == 'ringing' || a.status == 'snoozed';
                    final scheduleSummary = a.recurrenceDays.isNotEmpty
                        ? '${formatHhMm12h(a.timeOfDay)} · ${_formatRecurrenceDays(a.recurrenceDays)} (${a.timezone})'
                        : 'One-shot · ${_formatLocalDateTime(a.scheduledAt)} (${a.timezone})';

                    return NeumorphicSurface(
                      key: Key('alarm_card_${a.id}'),
                      surfaceType: NeumorphicSurfaceType.flat,
                      borderColor: ext?.borderSubtle,
                      borderRadius: CompanionRadius.borderMd,
                      padding: const EdgeInsets.all(CompanionSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.label,
                                  style: CompanionTypography.bodyLarge.copyWith(
                                    color: ext?.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (a.bypassQuietHours) ...[
                                _StatusPill(
                                  label: 'BYPASS QUIET',
                                  color: ext?.warning ?? CompanionColors.warning,
                                ),
                                const SizedBox(width: CompanionSpacing.xs),
                              ],
                              _StatusPill(
                                label: a.status.toUpperCase(),
                                color: statusColor,
                              ),
                              const SizedBox(width: CompanionSpacing.sm),
                              Switch(
                                key: Key('alarm_enable_switch_${a.id}'),
                                value: a.enabled,
                                onChanged: ctrl.isMutating
                                    ? null
                                    : (v) => ctrl.toggleAlarmEnabled(a, v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _MetaChip(
                            icon: Icons.alarm_on_rounded,
                            text: scheduleSummary,
                            ext: ext,
                          ),
                          if (a.snoozedUntil != null) ...[
                            const SizedBox(height: 4),
                            _MetaChip(
                              icon: Icons.snooze_rounded,
                              text:
                                  'Snoozed until ${_formatLocalDateTime(a.snoozedUntil)}',
                              ext: ext,
                            ),
                          ],
                          const SizedBox(height: CompanionSpacing.sm),
                          OverflowBar(
                            alignment: MainAxisAlignment.end,
                            spacing: CompanionSpacing.xs,
                            overflowSpacing: CompanionSpacing.xs,
                            children: [
                              if (isRinging) ...[
                                FilledButton.tonal(
                                  key: Key('alarm_ack_button_${a.id}'),
                                  onPressed: ctrl.isMutating
                                      ? null
                                      : () => ctrl.acknowledgeAlarm(a.id),
                                  child: const Text('Stop'),
                                ),
                                OutlinedButton(
                                  key: Key('alarm_snooze_button_${a.id}'),
                                  onPressed: ctrl.isMutating
                                      ? null
                                      : () => ctrl.snoozeAlarm(a.id),
                                  child: const Text('Snooze 10m'),
                                ),
                                TextButton(
                                  onPressed: ctrl.isMutating
                                      ? null
                                      : () => ctrl.dismissAlarm(a.id),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                              TextButton.icon(
                                onPressed: ctrl.isMutating
                                    ? null
                                    : () => ScheduleEditDialogs.showAlarmDialog(
                                          context,
                                          controller: ctrl,
                                          existing: a,
                                        ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit'),
                              ),
                              TextButton.icon(
                                onPressed: ctrl.isMutating
                                    ? null
                                    : () => ctrl.deleteAlarm(a.id),
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: ext?.danger ?? CompanionColors.danger,
                                ),
                                label: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: ext?.danger ?? CompanionColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4: Routines
  // ---------------------------------------------------------------------------

  Widget _buildRoutinesSection(
    BuildContext context,
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Proactive Check-In Routines',
          style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Routines dispatch deterministic check-in messages on schedule without autonomous model/tool execution.',
          style: CompanionTypography.caption.copyWith(color: ext?.textMuted),
        ),
        const SizedBox(height: CompanionSpacing.md),
        Expanded(
          child: ctrl.routines.isEmpty
              ? _buildEmptyState(
                  ext,
                  icon: Icons.repeat_rounded,
                  title: 'No check-in routines yet',
                  subtitle:
                      'Create a recurring morning or evening check-in routine.',
                )
              : ListView.separated(
                  itemCount: ctrl.routines.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: CompanionSpacing.sm),
                  itemBuilder: (context, index) {
                    final r = ctrl.routines[index];
                    return NeumorphicSurface(
                      key: Key('routine_card_${r.id}'),
                      surfaceType: NeumorphicSurfaceType.flat,
                      borderColor: ext?.borderSubtle,
                      borderRadius: CompanionRadius.borderMd,
                      padding: const EdgeInsets.all(CompanionSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.title,
                                  style: CompanionTypography.bodyLarge.copyWith(
                                    color: ext?.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _StatusPill(
                                label: r.enabled ? 'ENABLED' : 'PAUSED',
                                color: r.enabled
                                    ? (ext?.success ?? CompanionColors.success)
                                    : (ext?.textMuted ??
                                        CompanionColors.lightTextMuted),
                              ),
                              const SizedBox(width: CompanionSpacing.sm),
                              Switch(
                                key: Key('routine_enable_switch_${r.id}'),
                                value: r.enabled,
                                onChanged: ctrl.isMutating
                                    ? null
                                    : (v) => ctrl.toggleRoutineEnabled(r, v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: CompanionSpacing.md,
                            runSpacing: CompanionSpacing.xs,
                            children: [
                              _MetaChip(
                                icon: Icons.repeat_rounded,
                                text:
                                    '${formatHhMm12h(r.timeOfDay)} · ${_formatRecurrenceDays(r.recurrenceDays)} (${r.timezone})',
                                ext: ext,
                              ),
                              if (r.nextRunAt != null)
                                _MetaChip(
                                  icon: Icons.upcoming_outlined,
                                  text:
                                      'Next: ${_formatLocalDateTime(r.nextRunAt)}',
                                  ext: ext,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(CompanionSpacing.sm),
                            decoration: BoxDecoration(
                              color: (ext?.accent ?? CompanionColors.lightAccent)
                                  .withValues(alpha: 0.08),
                              borderRadius: CompanionRadius.borderSm,
                            ),
                            child: Text(
                              r.fallbackMessage,
                              style: CompanionTypography.bodySmall.copyWith(
                                color: ext?.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: CompanionSpacing.sm),
                          OverflowBar(
                            alignment: MainAxisAlignment.end,
                            spacing: CompanionSpacing.xs,
                            overflowSpacing: CompanionSpacing.xs,
                            children: [
                              FilledButton.tonalIcon(
                                key: Key('routine_run_now_${r.id}'),
                                onPressed: ctrl.isMutating
                                    ? null
                                    : () => ctrl.runRoutineNow(r.id),
                                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                label: const Text('Run Now'),
                              ),
                              TextButton.icon(
                                onPressed: ctrl.isMutating
                                    ? null
                                    : () => ScheduleEditDialogs.showRoutineDialog(
                                          context,
                                          controller: ctrl,
                                          existing: r,
                                        ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit'),
                              ),
                              TextButton.icon(
                                onPressed: ctrl.isMutating
                                    ? null
                                    : () => ctrl.deleteRoutine(r.id),
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: ext?.danger ?? CompanionColors.danger,
                                ),
                                label: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: ext?.danger ?? CompanionColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section 5: Notifications History
  // ---------------------------------------------------------------------------

  Widget _buildNotificationsSection(
    BuildContext context,
    DesktopScheduleController ctrl,
    CompanionThemeExtension? ext,
  ) {
    final items = ctrl.notifications;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: CompanionSpacing.sm,
          runSpacing: CompanionSpacing.xs,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Notification History (${ctrl.unreadCount} unread)',
              style: CompanionTypography.titleMedium.copyWith(
                color: ext?.textPrimary,
              ),
            ),
            Wrap(
              spacing: CompanionSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  key: const Key('notifications_unread_only_chip'),
                  label: const Text('Unread Only'),
                  selected: ctrl.unreadOnlyFilter,
                  onSelected: ctrl.setUnreadOnlyFilter,
                ),
                if (ctrl.unreadCount > 0 ||
                    ctrl.missedCount > 0 ||
                    items.any(
                      (e) =>
                          e.status == 'unread' ||
                          e.status == 'suppressed_quiet_hours' ||
                          e.status == 'missed_catchup',
                    ))
                  TextButton.icon(
                    key: const Key('notifications_mark_all_read_button'),
                    onPressed:
                        ctrl.isMutating ? null : ctrl.markAllNotificationsRead,
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Mark All Read'),
                  ),
              ],
            ),
          ],
        ),
        if (ctrl.missedCount > 0) ...[
          const SizedBox(height: CompanionSpacing.sm),
          Container(
            padding: const EdgeInsets.all(CompanionSpacing.sm),
            decoration: BoxDecoration(
              color: (ext?.warning ?? CompanionColors.warning)
                  .withValues(alpha: 0.14),
              borderRadius: CompanionRadius.borderSm,
              border: Border.all(
                color: (ext?.warning ?? CompanionColors.warning)
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Missed Reminders (Sleep Catch-up): ${ctrl.missedCount} alert(s) surfaced while offline.',
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: CompanionSpacing.md),
        Expanded(
          child: items.isEmpty
              ? _buildEmptyState(
                  ext,
                  icon: Icons.notifications_none_rounded,
                  title: 'No notification events',
                  subtitle:
                      'Triggered reminders, alarms, check-in routines, and suppressed Quiet Hours alerts appear here.',
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: CompanionSpacing.sm),
                  itemBuilder: (context, index) {
                    final ev = items[index];
                    final statusColor = _statusColor(ev.status, ext);
                    final isResolved = ev.status == 'acknowledged' ||
                        ev.status == 'dismissed';
                    final isTaskReminder = ev.sourceType == 'task_reminder';
                    final isRoutine = ev.sourceType == 'routine';

                    return NeumorphicSurface(
                      key: Key('schedule_notification_card_${ev.id}'),
                      surfaceType: NeumorphicSurfaceType.flat,
                      borderColor: ext?.borderSubtle,
                      borderRadius: CompanionRadius.borderMd,
                      padding: const EdgeInsets.all(CompanionSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ev.title,
                                  style: CompanionTypography.bodyLarge.copyWith(
                                    color: ext?.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _StatusPill(
                                label: ev.status.toUpperCase(),
                                color: statusColor,
                              ),
                            ],
                          ),
                          if (ev.body != null && ev.body!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              ev.body!,
                              style: CompanionTypography.bodySmall.copyWith(
                                color: ext?.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${ev.sourceType} · ${ev.deliveryPolicy} · ${_formatLocalDateTime(ev.triggeredAt)}',
                            style: CompanionTypography.caption.copyWith(
                              color: ext?.textMuted,
                            ),
                          ),
                          if (!isResolved) ...[
                            const SizedBox(height: CompanionSpacing.sm),
                            OverflowBar(
                              alignment: MainAxisAlignment.end,
                              spacing: CompanionSpacing.xs,
                              overflowSpacing: CompanionSpacing.xs,
                              children: [
                                FilledButton.tonal(
                                  onPressed: ctrl.isMutating
                                      ? null
                                      : () => ctrl.acknowledgeNotification(
                                            ev.id,
                                            completeTask: isTaskReminder,
                                          ),
                                  child: Text(
                                    ev.sourceType == 'alarm'
                                        ? 'Stop'
                                        : (isTaskReminder
                                            ? 'Mark Done'
                                            : 'Got it'),
                                  ),
                                ),
                                if (!isRoutine)
                                  OutlinedButton(
                                    onPressed: ctrl.isMutating
                                        ? null
                                        : () => ctrl.snoozeNotification(ev.id),
                                    child: const Text('Snooze 10m'),
                                  ),
                                if (isRoutine && onNavigateToChat != null)
                                  OutlinedButton(
                                    onPressed: ctrl.isMutating
                                        ? null
                                        : () async {
                                            await ctrl.markNotificationRead(ev.id);
                                            onNavigateToChat?.call();
                                          },
                                    child: const Text('Open Chat'),
                                  ),
                                TextButton(
                                  onPressed: ctrl.isMutating
                                      ? null
                                      : () => ctrl.dismissNotification(ev.id),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    CompanionThemeExtension? ext, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: ext?.textMuted),
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              title,
              style: CompanionTypography.titleMedium.copyWith(
                color: ext?.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CompanionSpacing.xs),
            Text(
              subtitle,
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status, CompanionThemeExtension? ext) {
    return switch (status) {
      'unread' || 'fired' || 'ringing' =>
        ext?.danger ?? CompanionColors.danger,
      'missed_catchup' || 'snoozed' =>
        ext?.warning ?? CompanionColors.warning,
      'suppressed_quiet_hours' || 'disabled' =>
        ext?.textMuted ?? CompanionColors.lightTextMuted,
      'acknowledged' || 'completed' || 'armed' || 'scheduled' =>
        ext?.success ?? CompanionColors.success,
      _ => ext?.textSecondary ?? CompanionColors.lightTextSecondary,
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: CompanionRadius.borderSm,
      ),
      child: Text(
        label,
        style: CompanionTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
    required this.ext,
  });

  final IconData icon;
  final String text;
  final CompanionThemeExtension? ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ext?.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: CompanionTypography.caption.copyWith(
              color: ext?.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
