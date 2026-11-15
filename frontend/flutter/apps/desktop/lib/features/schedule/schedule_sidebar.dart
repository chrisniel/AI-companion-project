import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_schedule_controller.dart';

class ScheduleSidebar extends StatelessWidget {
  const ScheduleSidebar({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final DesktopScheduleController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final items = <_SectionNavItem>[
      _SectionNavItem(
        section: ScheduleSection.tasks,
        label: 'Tasks',
        icon: Icons.check_circle_outline_rounded,
        count: controller.tasks.length,
      ),
      _SectionNavItem(
        section: ScheduleSection.reminders,
        label: 'Reminders',
        icon: Icons.notifications_active_outlined,
        count: controller.reminders.length,
      ),
      _SectionNavItem(
        section: ScheduleSection.alarms,
        label: 'Alarms',
        icon: Icons.alarm_rounded,
        count: controller.alarms.length,
      ),
      _SectionNavItem(
        section: ScheduleSection.routines,
        label: 'Routines',
        icon: Icons.repeat_rounded,
        count: controller.routines.length,
      ),
      _SectionNavItem(
        section: ScheduleSection.notifications,
        label: 'Notifications',
        icon: Icons.inbox_rounded,
        count: controller.unreadCount,
        highlightBadge: controller.unreadCount > 0 || controller.missedCount > 0,
      ),
    ];

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CompanionSpacing.md),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items
                .map((item) => _buildCompactChip(context, item, ext))
                .toList(),
          ),
        ),
      );
    }

    return SizedBox(
      width: 224,
      child: SoftGlassPanel(
        padding: const EdgeInsets.all(CompanionSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'WORKSPACE',
              style: CompanionTypography.caption.copyWith(
                color: ext?.textMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: CompanionSpacing.sm),
            for (final item in items) ...[
              _buildSidebarTile(context, item, ext),
              const SizedBox(height: CompanionSpacing.xs),
            ],
            const Spacer(),
            Divider(color: ext?.borderSubtle),
            const SizedBox(height: CompanionSpacing.xs),
            Row(
              children: [
                Icon(
                  controller.quietHours.quietHoursEnabled
                      ? Icons.bedtime_rounded
                      : Icons.bedtime_off_outlined,
                  size: 15,
                  color: controller.quietHours.quietHoursEnabled
                      ? (ext?.accent ?? CompanionColors.lightAccent)
                      : ext?.textMuted,
                ),
                const SizedBox(width: CompanionSpacing.xs),
                Expanded(
                  child: Text(
                    controller.quietHours.quietHoursEnabled
                        ? 'Quiet ${controller.quietHours.quietHoursStart}-${controller.quietHours.quietHoursEnd}'
                        : 'Quiet Hours Off',
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarTile(
    BuildContext context,
    _SectionNavItem item,
    CompanionThemeExtension? ext,
  ) {
    final selected = controller.selectedSection == item.section;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ext?.accent ?? CompanionColors.lightAccent;

    return InkWell(
      key: Key('schedule_nav_${item.section.name}'),
      onTap: () => controller.selectSection(item.section),
      borderRadius: CompanionRadius.borderMd,
      child: NeumorphicSurface(
        surfaceType:
            selected ? NeumorphicSurfaceType.raised : NeumorphicSurfaceType.flat,
        outerShadows: selected
            ? (isDark
                ? CompanionShadows.darkNavEmbossed
                : CompanionShadows.lightNavEmbossed)
            : const [],
        borderColor: selected
            ? (isDark
                ? CompanionColors.darkBorderHighlight
                : CompanionColors.lightBorderHighlight)
            : Colors.transparent,
        borderRadius: CompanionRadius.borderMd,
        padding: const EdgeInsets.symmetric(
          horizontal: CompanionSpacing.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 18,
              color: selected ? accent : ext?.textSecondary,
            ),
            const SizedBox(width: CompanionSpacing.sm),
            Expanded(
              child: Text(
                item.label,
                style: CompanionTypography.bodyMedium.copyWith(
                  color: selected ? ext?.textPrimary : ext?.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: item.highlightBadge
                    ? (ext?.warning ?? CompanionColors.warning)
                        .withValues(alpha: 0.2)
                    : (selected
                        ? accent.withValues(alpha: 0.16)
                        : (ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2))),
                borderRadius: CompanionRadius.borderFull,
              ),
              child: Text(
                '${item.count}',
                style: CompanionTypography.caption.copyWith(
                  color: item.highlightBadge
                      ? (ext?.warning ?? CompanionColors.warning)
                      : (selected ? accent : ext?.textMuted),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactChip(
    BuildContext context,
    _SectionNavItem item,
    CompanionThemeExtension? ext,
  ) {
    final selected = controller.selectedSection == item.section;
    final accent = ext?.accent ?? CompanionColors.lightAccent;

    return Padding(
      padding: const EdgeInsets.only(right: CompanionSpacing.xs),
      child: ChoiceChip(
        key: Key('schedule_compact_nav_${item.section.name}'),
        selected: selected,
        onSelected: (_) => controller.selectSection(item.section),
        avatar: Icon(
          item.icon,
          size: 16,
          color: selected ? accent : ext?.textSecondary,
        ),
        label: Text('${item.label} (${item.count})'),
      ),
    );
  }
}

class _SectionNavItem {
  const _SectionNavItem({
    required this.section,
    required this.label,
    required this.icon,
    required this.count,
    this.highlightBadge = false,
  });

  final ScheduleSection section;
  final String label;
  final IconData icon;
  final int count;
  final bool highlightBadge;
}
