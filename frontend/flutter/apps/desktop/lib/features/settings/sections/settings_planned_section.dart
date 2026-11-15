import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../settings_section.dart';

/// Shared truthful placeholder card for upcoming M4+ settings categories.
class SettingsPlannedSection extends StatelessWidget {
  const SettingsPlannedSection({
    super.key,
    required this.section,
  });

  final SettingsSectionMeta section;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final accent = ext?.accent ?? CompanionColors.lightAccent;

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: CompanionSpacing.sm,
            runSpacing: CompanionSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: CompanionRadius.borderMd,
                    ),
                    child: Icon(section.icon, size: 19, color: accent),
                  ),
                  const SizedBox(width: CompanionSpacing.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.label,
                          style: CompanionTypography.titleMedium
                              .copyWith(color: ext?.textPrimary),
                        ),
                        Text(
                          section.description,
                          style: CompanionTypography.caption
                              .copyWith(color: ext?.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: CompanionRadius.borderFull,
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  section.milestoneHint != null
                      ? 'PLANNED • ${section.milestoneHint}'
                      : 'PLANNED',
                  style: CompanionTypography.caption.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.lg),
          NeumorphicSurface(
            surfaceType: NeumorphicSurfaceType.recessed,
            borderRadius: CompanionRadius.borderMd,
            padding: const EdgeInsets.all(CompanionSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: accent),
                const SizedBox(width: CompanionSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Architecture Status',
                        style: CompanionTypography.bodySmall.copyWith(
                          color: ext?.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        section.plannedSummary ??
                            'This configuration domain is scheduled for an upcoming milestone.',
                        style: CompanionTypography.bodySmall.copyWith(
                          color: ext?.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CompanionSpacing.md),
          Text(
            'Epistemic Truthfulness: Controls for this category are intentionally withheld until its local runtime service and Desktop hardware bindings are delivered.',
            style: CompanionTypography.caption.copyWith(color: ext?.textMuted),
          ),
        ],
      ),
    );
  }
}
