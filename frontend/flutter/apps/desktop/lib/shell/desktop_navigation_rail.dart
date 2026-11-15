import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../controllers/desktop_settings_controller.dart';
import '../dialogs/desktop_shutdown_dialogs.dart';
import '../features/profiles/desktop_profile_controller.dart';
import '../features/profiles/profile_selector_header.dart';
import '../features/settings/settings_section.dart';
import '../lifecycle/desktop_lifecycle_coordinator.dart';

enum _RailPowerAction {
  hideToTray,
  lifecycleSettings,
  exitCompanion,
}

class DesktopNavigationRail extends StatelessWidget {
  const DesktopNavigationRail({
    super.key,
    required this.controller,
    this.coordinator,
    this.profileController,
    this.onHideToTrayRequested,
    this.onExitRequested,
    this.onOpenLifecycleSettings,
  });

  final DesktopSettingsController controller;
  final DesktopLifecycleCoordinator? coordinator;
  final DesktopProfileController? profileController;
  final VoidCallback? onHideToTrayRequested;
  final VoidCallback? onExitRequested;
  final VoidCallback? onOpenLifecycleSettings;

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

            // Profile Selector Header
            if (profileController != null) ...[
              ProfileSelectorHeader(
                controller: profileController!,
                isCollapsed: isCollapsed,
                onOpenSettings: () => controller.requestDestination(DesktopNavDestination.settings),
              ),
              const Divider(height: 1),
            ],

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
                    onTap: () => controller.requestDestination(destination),
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
    final isTrayAvailable = coordinator?.isTrayAvailable ?? false;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CompanionSpacing.sm,
          vertical: CompanionSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Runtime: Standalone (Unconnected)',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ext?.warning ?? CompanionColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: CompanionSpacing.xs),
            _buildPowerMenuButton(context, ext, isDark, isTrayAvailable),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(CompanionSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02),
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
            const SizedBox(width: CompanionSpacing.xs),
            _buildPowerMenuButton(context, ext, isDark, isTrayAvailable),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerMenuButton(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
    bool isTrayAvailable,
  ) {
    final menuBg = ext?.surfaceElevated ??
        (isDark
            ? CompanionColors.darkSurfaceElevated
            : CompanionColors.lightSurfaceElevated);
    final dangerColor = ext?.danger ?? CompanionColors.danger;

    return PopupMenuButton<_RailPowerAction>(
      key: const Key('rail_power_menu_button'),
      tooltip: 'Window & Companion Actions',
      position: PopupMenuPosition.over,
      offset: const Offset(0, -8),
      color: menuBg,
      shape: RoundedRectangleBorder(
        borderRadius: CompanionRadius.borderMd,
        side: BorderSide(
          color: ext?.borderSubtle ?? (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      onSelected: (action) => _handlePowerAction(context, action, isTrayAvailable),
      itemBuilder: (popupContext) => <PopupMenuEntry<_RailPowerAction>>[
        PopupMenuItem<_RailPowerAction>(
          value: _RailPowerAction.hideToTray,
          enabled: isTrayAvailable,
          child: Row(
            children: [
              Icon(
                Icons.vertical_align_bottom_rounded,
                size: 18,
                color: isTrayAvailable ? ext?.textPrimary : ext?.textMuted,
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Minimize to System Tray',
                      style: CompanionTypography.bodySmall.copyWith(
                        color: isTrayAvailable ? ext?.textPrimary : ext?.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isTrayAvailable
                          ? 'Keep alarms & runtime active'
                          : 'System tray unavailable',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<_RailPowerAction>(
          value: _RailPowerAction.lifecycleSettings,
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: ext?.textPrimary,
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Close & Startup Settings...',
                  style: CompanionTypography.bodySmall.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<_RailPowerAction>(
          value: _RailPowerAction.exitCompanion,
          child: Row(
            children: [
              Icon(
                Icons.power_settings_new_rounded,
                size: 18,
                color: dangerColor,
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Exit Companion',
                  style: CompanionTypography.bodySmall.copyWith(
                    color: dangerColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: CompanionRadius.borderSm,
          border: Border.all(
            color: ext?.borderSubtle ??
                (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Icon(
          Icons.power_settings_new_rounded,
          size: 17,
          color: ext?.textPrimary ??
              (isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Future<void> _handlePowerAction(
    BuildContext context,
    _RailPowerAction action,
    bool isTrayAvailable,
  ) async {
    switch (action) {
      case _RailPowerAction.hideToTray:
        if (!isTrayAvailable) return;
        if (onHideToTrayRequested != null) {
          onHideToTrayRequested!();
        } else {
          await coordinator?.hideToTray();
        }
        return;
      case _RailPowerAction.lifecycleSettings:
        if (onOpenLifecycleSettings != null) {
          onOpenLifecycleSettings!();
        } else {
          await controller.requestOpenSettingsSection(
            SettingsSectionId.general,
          );
        }
        return;
      case _RailPowerAction.exitCompanion:
        if (onExitRequested != null) {
          onExitRequested!();
          return;
        }
        final confirmed =
            await DesktopShutdownDialogs.showExitConfirmationDialog(context);
        if (confirmed) {
          coordinator?.handleExitRequested();
        }
        return;
    }
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
