import 'dart:math' as math;

import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_schedule_controller.dart';

class NotificationBacklogDrawer extends StatelessWidget {
  const NotificationBacklogDrawer({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onOpenChat,
    this.activeProfileName,
  });

  final DesktopScheduleController controller;
  final VoidCallback onClose;
  final VoidCallback onOpenChat;
  final String? activeProfileName;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final viewportWidth = MediaQuery.of(context).size.width;
    final drawerWidth = math.min(420.0, viewportWidth * 0.92);

    return SizedBox(
      width: drawerWidth,
      child: Material(
        color: Colors.transparent,
        child: SoftGlassPanel(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(CompanionRadius.lg),
            bottomLeft: Radius.circular(CompanionRadius.lg),
          ),
          padding: const EdgeInsets.all(CompanionSpacing.lg),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final items = controller.notifications;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_rounded,
                        size: 20,
                        color: ext?.accent,
                      ),
                      const SizedBox(width: CompanionSpacing.sm),
                      Expanded(
                        child: Text(
                          'Notification Center',
                          style: CompanionTypography.titleMedium.copyWith(
                            color: ext?.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        key: const Key('backlog_drawer_close_button'),
                        tooltip: 'Close Notification Center',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.xs),
                  Wrap(
                    spacing: CompanionSpacing.sm,
                    runSpacing: CompanionSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (ext?.accent ?? CompanionColors.lightAccent)
                              .withValues(alpha: 0.12),
                          borderRadius: CompanionRadius.borderSm,
                        ),
                        child: Text(
                          'Profile Scope: ${activeProfileName ?? controller.profileId ?? 'Active Profile'}',
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      FilterChip(
                        key: const Key('backlog_unread_only_chip'),
                        label: const Text('Unread Only'),
                        selected: controller.unreadOnlyFilter,
                        onSelected: controller.setUnreadOnlyFilter,
                      ),
                      if (items.isNotEmpty)
                        TextButton.icon(
                          key: const Key('backlog_clear_all_button'),
                          onPressed: controller.isMutating
                              ? null
                              : controller.clearAllNotifications,
                          icon: const Icon(Icons.clear_all_rounded, size: 16),
                          label: const Text('Clear All'),
                        ),
                    ],
                  ),
                  if (controller.missedCount > 0) ...[
                    const SizedBox(height: CompanionSpacing.md),
                    Container(
                      key: const Key('backlog_missed_catchup_banner'),
                      padding: const EdgeInsets.all(CompanionSpacing.md),
                      decoration: BoxDecoration(
                        color: (ext?.warning ?? CompanionColors.warning)
                            .withValues(alpha: 0.14),
                        borderRadius: CompanionRadius.borderMd,
                        border: Border.all(
                          color: (ext?.warning ?? CompanionColors.warning)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 18,
                            color: ext?.warning ?? CompanionColors.warning,
                          ),
                          const SizedBox(width: CompanionSpacing.sm),
                          Expanded(
                            child: Text(
                              'Missed Reminders (Sleep Catch-up): ${controller.missedCount} alert(s) surfaced since last active session.',
                              style: CompanionTypography.bodySmall.copyWith(
                                color: ext?.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: CompanionSpacing.md),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              'No notifications in this backlog view.',
                              style: CompanionTypography.bodyMedium.copyWith(
                                color: ext?.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: CompanionSpacing.sm),
                            itemBuilder: (context, idx) =>
                                _buildEventCard(context, items[idx], ext),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    NotificationEventOut event,
    CompanionThemeExtension? ext,
  ) {
    final isUrgent = event.urgency == 'high' || event.sourceType == 'alarm';
    final isRoutine = event.sourceType == 'routine';
    final isTaskReminder = event.sourceType == 'task_reminder';
    final isResolved = event.status == 'acknowledged' ||
        event.status == 'dismissed';

    final statusColor = switch (event.status) {
      'unread' => isUrgent
          ? (ext?.danger ?? CompanionColors.danger)
          : (ext?.accent ?? CompanionColors.lightAccent),
      'missed_catchup' => ext?.warning ?? CompanionColors.warning,
      'suppressed_quiet_hours' => ext?.textMuted ?? CompanionColors.lightTextMuted,
      'acknowledged' => ext?.success ?? CompanionColors.success,
      _ => ext?.textSecondary ?? CompanionColors.lightTextSecondary,
    };

    return NeumorphicSurface(
      surfaceType: NeumorphicSurfaceType.flat,
      borderColor: ext?.borderSubtle,
      borderRadius: CompanionRadius.borderMd,
      padding: const EdgeInsets.all(CompanionSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUrgent
                    ? Icons.alarm_on_rounded
                    : isRoutine
                        ? Icons.auto_awesome_outlined
                        : Icons.notifications_none_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: CompanionSpacing.xs),
              Expanded(
                child: Text(
                  event.title,
                  style: CompanionTypography.bodyMedium.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: CompanionRadius.borderSm,
                ),
                child: Text(
                  event.status.toUpperCase(),
                  style: CompanionTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (event.body != null && event.body!.trim().isNotEmpty) ...[
            const SizedBox(height: CompanionSpacing.xs),
            Text(
              event.body!,
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            '${event.sourceType} · ${event.deliveryPolicy}',
            style: CompanionTypography.caption.copyWith(color: ext?.textMuted),
          ),
          if (!isResolved) ...[
            const SizedBox(height: CompanionSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (isTaskReminder)
                  FilledButton.tonal(
                    onPressed: controller.isMutating
                        ? null
                        : () => controller.acknowledgeNotification(
                              event.id,
                              completeTask: true,
                            ),
                    child: const Text('Mark Done'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: controller.isMutating
                        ? null
                        : () => controller.acknowledgeNotification(
                              event.id,
                              completeTask: false,
                            ),
                    child: const Text('Acknowledge'),
                  ),
                if (!isRoutine)
                  OutlinedButton(
                    onPressed: controller.isMutating
                        ? null
                        : () => controller.snoozeNotification(event.id),
                    child: const Text('Snooze 10m'),
                  ),
                if (isRoutine)
                  OutlinedButton(
                    onPressed: controller.isMutating
                        ? null
                        : () async {
                            await controller.markNotificationRead(event.id);
                            onClose();
                            onOpenChat();
                          },
                    child: const Text('Open Chat'),
                  ),
                if (event.status == 'unread')
                  TextButton(
                    onPressed: controller.isMutating
                        ? null
                        : () => controller.markNotificationRead(event.id),
                    child: const Text('Mark Read'),
                  ),
                TextButton(
                  onPressed: controller.isMutating
                      ? null
                      : () => controller.dismissNotification(event.id),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
