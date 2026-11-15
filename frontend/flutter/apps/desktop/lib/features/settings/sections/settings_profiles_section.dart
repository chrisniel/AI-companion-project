import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../../profiles/desktop_profile_controller.dart';
import '../../profiles/profile_access_card.dart';

/// Settings category section for Profiles & Privacy access control.
class SettingsProfilesSection extends StatelessWidget {
  const SettingsProfilesSection({
    super.key,
    this.profileController,
  });

  final DesktopProfileController? profileController;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profileController != null)
          ProfileAccessCard(controller: profileController!)
        else
          SoftGlassPanel(
            padding: const EdgeInsets.all(CompanionSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.manage_accounts_rounded,
                        size: 20, color: ext?.accent),
                    const SizedBox(width: CompanionSpacing.sm),
                    Expanded(
                      child: Text(
                        'Profiles & Privacy',
                        style: CompanionTypography.titleMedium
                            .copyWith(color: ext?.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CompanionSpacing.sm),
                Text(
                  'Profile management unavailable in standalone view. Connect to the Local AI Runtime shell to inspect active profiles, restore archives, or configure privacy boundaries.',
                  style: CompanionTypography.bodySmall
                      .copyWith(color: ext?.textSecondary),
                ),
              ],
            ),
          ),
        const SizedBox(height: CompanionSpacing.lg),
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pin_rounded, size: 18, color: ext?.textSecondary),
                  const SizedBox(width: CompanionSpacing.sm),
                  Expanded(
                    child: Text(
                      'Device PIN & Satellite Enrollment',
                      style: CompanionTypography.titleSmall
                          .copyWith(color: ext?.textPrimary),
                    ),
                  ),
                  const SizedBox(width: CompanionSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (ext?.accent ?? Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.14),
                      borderRadius: CompanionRadius.borderSm,
                    ),
                    child: Text(
                      'PLANNED • PC-IDENTITY-003',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.accent ?? Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                'Local profile PIN locking and mobile/satellite device enrollment are scheduled for upcoming identity hardening work.',
                style: CompanionTypography.caption
                    .copyWith(color: ext?.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
