import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../controllers/desktop_settings_controller.dart';
import '../lifecycle/desktop_lifecycle_coordinator.dart';

class DesktopNavigationRail extends StatelessWidget {
  const DesktopNavigationRail({
    super.key,
    required this.controller,
    this.coordinator,
  });

  final DesktopSettingsController controller;
  final DesktopLifecycleCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollapsed = controller.isRailCollapsed;

    return SoftGlassPanel(
      width: isCollapsed ? 72 : 240,
      borderRadius: BorderRadius.zero,
      borderWidth: 0,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: ext?.borderSubtle ?? (isDark ? Colors.white10 : Colors.black12),
              width: 1.0,
            ),
          ),
        ),
        child: Column(
          children: [
            // Rail Header: Brand + Collapse toggle
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 6 : CompanionSpacing.md,
                vertical: CompanionSpacing.md,
              ),
              child: Row(
                mainAxisAlignment:
                    isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                children: [
                  if (!isCollapsed) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: (ext?.accent ?? CompanionColors.lightAccent)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: ext?.accent ?? CompanionColors.lightAccent,
                      ),
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    Expanded(
                      child: Text(
                        'AI Companion',
                        style: CompanionTypography.titleSmall.copyWith(
                          color: ext?.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  IconButton(
                    icon: Icon(
                      isCollapsed
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      size: 20,
                      color: ext?.textSecondary,
                    ),
                    tooltip: isCollapsed ? 'Expand Navigation' : 'Collapse Navigation',
                    onPressed: controller.toggleRailCollapsed,
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Navigation Destinations
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: CompanionSpacing.sm,
                  vertical: CompanionSpacing.md,
                ),
                children: DesktopNavDestination.values.map((destination) {
                  final isSelected = controller.currentDestination == destination;
                  return _buildNavTile(
                    context: context,
                    destination: destination,
                    isSelected: isSelected,
                    isCollapsed: isCollapsed,
                    ext: ext,
                    isDark: isDark,
                  );
                }).toList(),
              ),
            ),

            const Divider(height: 1),

            // Rail Footer: Runtime Status Indicator
            _buildFooter(context, ext, isDark, isCollapsed),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required BuildContext context,
    required DesktopNavDestination destination,
    required bool isSelected,
    required bool isCollapsed,
    required CompanionThemeExtension? ext,
    required bool isDark,
  }) {
    final activeBg = isDark
        ? (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.18)
        : (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.10);
    final activeBorder = ext?.accent ?? CompanionColors.lightAccent;

    final tile = InkWell(
      onTap: () => controller.setDestination(destination),
      borderRadius: CompanionRadius.borderMd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 12 : 14,
          vertical: 10,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: CompanionRadius.borderMd,
          border: Border.all(
            color: isSelected ? activeBorder.withValues(alpha: 0.4) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              isSelected ? destination.activeIcon : destination.icon,
              size: 20,
              color: isSelected ? (ext?.accent ?? CompanionColors.lightAccent) : ext?.textSecondary,
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: CompanionSpacing.md),
              Expanded(
                child: Text(
                  destination.label,
                  style: CompanionTypography.bodyMedium.copyWith(
                    color: isSelected ? ext?.textPrimary : ext?.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (destination.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    borderRadius: CompanionRadius.borderSm,
                  ),
                  child: Text(
                    destination.badge!,
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(
        message: destination.badge != null
            ? '${destination.label} (${destination.badge})'
            : destination.label,
        waitDuration: const Duration(milliseconds: 300),
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildFooter(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
    bool isCollapsed,
  ) {
    if (isCollapsed) {
      return Tooltip(
        message: 'Runtime: Standalone (Unconnected)',
        child: Padding(
          padding: const EdgeInsets.all(CompanionSpacing.md),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: ext?.warning ?? CompanionColors.warning,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(CompanionSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: CompanionRadius.borderMd,
          border: Border.all(color: ext?.borderSubtle ?? Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: ext?.warning ?? CompanionColors.warning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: CompanionSpacing.sm),
            Expanded(
              child: Text(
                'Runtime: Standalone (Unconnected)',
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
