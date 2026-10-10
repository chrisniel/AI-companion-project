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
                  return _DesktopNavTile(
                    destination: destination,
                    isSelected: isSelected,
                    isCollapsed: isCollapsed,
                    onTap: () => controller.setDestination(destination),
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

class _DesktopNavTile extends StatefulWidget {
  const _DesktopNavTile({
    required this.destination,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  final DesktopNavDestination destination;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  @override
  State<_DesktopNavTile> createState() => _DesktopNavTileState();
}

class _DesktopNavTileState extends State<_DesktopNavTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSelected = widget.isSelected;
    final isCollapsed = widget.isCollapsed;
    final destination = widget.destination;

    Widget tileSurface;
    Color contentColor;

    if (isSelected) {
      final outerShadows = isDark
          ? (_isHovered
              ? CompanionShadows.darkNavEmbossedHover
              : CompanionShadows.darkNavEmbossed)
          : (_isHovered
              ? CompanionShadows.lightNavEmbossedHover
              : CompanionShadows.lightNavEmbossed);
      final borderColor = isDark
          ? CompanionColors.darkBorderHighlight
          : CompanionColors.lightBorderHighlight;

      contentColor = ext?.accent ?? CompanionColors.lightAccent;

      tileSurface = NeumorphicSurface(
        surfaceType: NeumorphicSurfaceType.raised,
        borderRadius: CompanionRadius.borderMd,
        borderColor: borderColor,
        outerShadows: outerShadows,
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 10 : 14,
          vertical: 10,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: _buildTileContent(ext, isDark, isCollapsed, contentColor, FontWeight.w600),
      );
    } else if (_isPressed) {
      contentColor = ext?.textPrimary ?? CompanionColors.lightTextPrimary;

      tileSurface = NeumorphicSurface(
        surfaceType: NeumorphicSurfaceType.pressed,
        borderRadius: CompanionRadius.borderMd,
        borderColor: ext?.borderSubtle,
        innerShadows: isDark
            ? CompanionInnerShadows.darkNavPressed
            : CompanionInnerShadows.lightNavPressed,
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 10 : 14,
          vertical: 10,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: _buildTileContent(ext, isDark, isCollapsed, contentColor, FontWeight.w500),
      );
    } else if (_isHovered) {
      contentColor = ext?.textPrimary ?? CompanionColors.lightTextPrimary;

      tileSurface = NeumorphicSurface(
        surfaceType: NeumorphicSurfaceType.recessed,
        borderRadius: CompanionRadius.borderMd,
        borderColor: ext?.borderSubtle,
        innerShadows: isDark
            ? CompanionInnerShadows.darkNavInset
            : CompanionInnerShadows.lightNavInset,
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 10 : 14,
          vertical: 10,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: _buildTileContent(ext, isDark, isCollapsed, contentColor, FontWeight.w500),
      );
    } else {
      contentColor = ext?.textSecondary ?? CompanionColors.lightTextSecondary;

      tileSurface = Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 10 : 14,
          vertical: 10,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: const BoxDecoration(
          borderRadius: CompanionRadius.borderMd,
          color: Colors.transparent,
        ),
        child: _buildTileContent(ext, isDark, isCollapsed, contentColor, FontWeight.w400),
      );
    }

    Widget tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _isPressed = true),
        onPointerUp: (_) => setState(() => _isPressed = false),
        onPointerCancel: (_) => setState(() => _isPressed = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: tileSurface,
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

  Widget _buildTileContent(
    CompanionThemeExtension? ext,
    bool isDark,
    bool isCollapsed,
    Color contentColor,
    FontWeight fontWeight,
  ) {
    final destination = widget.destination;
    final isSelected = widget.isSelected;

    return Row(
      mainAxisAlignment:
          isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Icon(
          isSelected ? destination.activeIcon : destination.icon,
          size: 20,
          color: contentColor,
        ),
        if (!isCollapsed) ...[
          const SizedBox(width: CompanionSpacing.md),
          Expanded(
            child: Text(
              destination.label,
              style: CompanionTypography.bodyMedium.copyWith(
                color: isSelected ? ext?.textPrimary : contentColor,
                fontWeight: fontWeight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (destination.badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
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
    );
  }
}
