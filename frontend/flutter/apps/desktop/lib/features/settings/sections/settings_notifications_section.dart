import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../../schedule/desktop_schedule_controller.dart';
import '../../schedule/quiet_hours_card.dart';

/// Settings category section for Notifications & Quiet Hours scheduling.
class SettingsNotificationsSection extends StatelessWidget {
  const SettingsNotificationsSection({
    super.key,
    this.scheduleController,
  });

  final DesktopScheduleController? scheduleController;

  @override
  Widget build(BuildContext context) {
    if (scheduleController != null) {
      return QuietHoursSettingsCard(controller: scheduleController!);
    }

    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_paused_rounded,
                  size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Notifications & Quiet Hours',
                  style: CompanionTypography.titleMedium
                      .copyWith(color: ext?.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.sm),
          Text(
            'Schedule service unavailable in standalone view. Connect to the Local AI Runtime shell to configure quiet hours, notification windows, and reminder chimes.',
            style: CompanionTypography.bodySmall
                .copyWith(color: ext?.textSecondary),
          ),
        ],
      ),
    );
  }
}
