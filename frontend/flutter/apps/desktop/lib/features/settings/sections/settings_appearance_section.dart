import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../../../controllers/desktop_settings_controller.dart';

/// Appearance & Theme configuration section plus deferred Batch 2 parity note.
class SettingsAppearanceSection extends StatelessWidget {
  const SettingsAppearanceSection({
    super.key,
    required this.controller,
  });

  final DesktopSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  Icon(Icons.palette_outlined, size: 20, color: ext?.accent),
                  const SizedBox(width: CompanionSpacing.sm),
                  Expanded(
                    child: Text(
                      'Appearance & Theme',
                      style: CompanionTypography.titleMedium
                          .copyWith(color: ext?.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.lg),

              Text(
                'Color Mode',
                style: CompanionTypography.bodyMedium.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: CompanionSpacing.sm),
              NeumorphicSegmentedControl<ThemeMode>(
                selected: controller.themeMode,
                onChanged: controller.setThemeMode,
                segments: const [
                  NeumorphicSegment(
                    value: ThemeMode.system,
                    label: 'System',
                    icon: Icons.brightness_auto_rounded,
                  ),
                  NeumorphicSegment(
                    value: ThemeMode.light,
                    label: 'Light',
                    icon: Icons.light_mode_rounded,
                  ),
                  NeumorphicSegment(
                    value: ThemeMode.dark,
                    label: 'Dark',
                    icon: Icons.dark_mode_rounded,
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.xl),

              Text(
                'Accent Color Preset',
                style: CompanionTypography.bodyMedium.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: CompanionSpacing.sm),
              Wrap(
                spacing: CompanionSpacing.md,
                runSpacing: CompanionSpacing.sm,
                children: AccentPreset.values.map((preset) {
                  final isSelected = controller.accentPreset == preset;
                  return InkWell(
                    onTap: () => controller.setAccentPreset(preset),
                    borderRadius: CompanionRadius.borderMd,
                    child: NeumorphicSurface(
                      surfaceType: isSelected
                          ? NeumorphicSurfaceType.raised
                          : NeumorphicSurfaceType.flat,
                      outerShadows: isSelected
                          ? (isDark
                              ? CompanionShadows.darkNavEmbossed
                              : CompanionShadows.lightNavEmbossed)
                          : const [],
                      borderColor: isSelected
                          ? (isDark
                              ? CompanionColors.darkBorderHighlight
                              : CompanionColors.lightBorderHighlight)
                          : (ext?.borderSubtle ?? Colors.transparent),
                      borderRadius: CompanionRadius.borderMd,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [preset.primary, preset.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: CompanionSpacing.sm),
                          Text(
                            preset.label,
                            style: CompanionTypography.bodySmall.copyWith(
                              color: isSelected
                                  ? ext?.textPrimary
                                  : ext?.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: CompanionSpacing.lg),
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_fix_high_outlined, size: 18, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extended Web Appearance Parity (Planned Follow-Up)',
                      style: CompanionTypography.bodySmall.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Custom accent hex, wallpaper/gradient backgrounds, frosted glass opacity/blur sliders, animation motion dynamics, and interface density will follow as an optional visual polish pass after M4.',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
