import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../../../lifecycle/desktop_lifecycle_coordinator.dart';

/// General window bounds, system tray status, and startup lifecycle section.
class SettingsGeneralSection extends StatelessWidget {
  const SettingsGeneralSection({
    super.key,
    this.coordinator,
  });

  final DesktopLifecycleCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isTrayAvailable = coordinator?.isTrayAvailable ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.desktop_windows_outlined, size: 20, color: ext?.accent),
                  const SizedBox(width: CompanionSpacing.sm),
                  Expanded(
                    child: Text(
                      'Window & Tray Lifecycle',
                      style: CompanionTypography.titleMedium
                          .copyWith(color: ext?.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.md),
              Text(
                'Window Constraints: 1280x800 (1024x640 min)',
                style: CompanionTypography.bodySmall
                    .copyWith(color: ext?.textSecondary),
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                isTrayAvailable
                    ? 'System Tray: Active (Close-to-Tray Active)'
                    : 'System Tray: Unavailable (Close Exits App)',
                style: CompanionTypography.bodySmall.copyWith(
                  color: isTrayAvailable
                      ? (ext?.success ?? CompanionColors.success)
                      : ext?.textSecondary,
                ),
              ),
              const SizedBox(height: CompanionSpacing.lg),
              NeumorphicSurface(
                surfaceType: NeumorphicSurfaceType.recessed,
                borderRadius: CompanionRadius.borderMd,
                padding: const EdgeInsets.all(CompanionSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 18,
                      color: ext?.accent,
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    Expanded(
                      child: Text(
                        'Quick Tray & Exit Actions: Use the power button in the bottom-left navigation rail or the Windows System Tray menu to minimize to tray or shut down AI Companion from any screen.',
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CompanionSpacing.lg),
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch_outlined, size: 18, color: ext?.accent),
                  const SizedBox(width: CompanionSpacing.sm),
                  Expanded(
                    child: Text(
                      'Windows Startup & Autostart',
                      style: CompanionTypography.bodyMedium.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ext?.surfaceRecessed,
                      borderRadius: CompanionRadius.borderSm,
                      border: Border.all(
                        color: ext?.borderSubtle ?? Colors.transparent,
                      ),
                    ),
                    child: Text(
                      'PLANNED (PC-HOST-002)',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                'Standard-user Windows Task Scheduler registration ("Launch at Login, Start Minimized to Tray") is scheduled under PC-HOST-002 and is not yet active.',
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
