import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'desktop_profile_controller.dart';
import 'profile_dialogs.dart';

/// Navigation Rail header displaying the active Profile and quick-switch popup menu.
class ProfileSelectorHeader extends StatelessWidget {
  const ProfileSelectorHeader({
    super.key,
    required this.controller,
    required this.isCollapsed,
    this.onOpenSettings,
  });

  final DesktopProfileController controller;
  final bool isCollapsed;
  final VoidCallback? onOpenSettings;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'P';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final active = controller.activeProfile;
        final activeName = controller.activeProfileName ??
            (controller.activeProfileId == null ? 'Signed Out' : 'Profile');
        final isSignedOut = controller.activeProfileId == null;
        final isDefault = active?['is_default'] == true;

        final avatarWidget = CircleAvatar(
          radius: 14,
          backgroundColor: isSignedOut
              ? (isDark ? Colors.white12 : Colors.black12)
              : (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.2),
          child: isSignedOut
              ? Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: ext?.textSecondary ?? Colors.grey,
                )
              : Text(
                  _getInitials(activeName),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ext?.accent ?? CompanionColors.lightAccent,
                  ),
                ),
        );

        Widget trigger;

        if (isCollapsed) {
          trigger = Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Tooltip(
                message: isSignedOut ? 'Signed Out' : 'Profile: $activeName',
                child: avatarWidget,
              ),
            ),
          );
        } else {
          trigger = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: CompanionRadius.borderMd,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                border: Border.all(
                  color: ext?.borderSubtle ?? (isDark ? Colors.white10 : Colors.black12),
                ),
              ),
              child: Row(
                children: [
                  avatarWidget,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeName,
                          style: CompanionTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: ext?.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isDefault)
                          Text(
                            'Personal / Default',
                            style: CompanionTypography.caption.copyWith(
                              fontSize: 10,
                              color: ext?.accent ?? CompanionColors.lightAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else if (isSignedOut)
                          Text(
                            'Sign in required',
                            style: CompanionTypography.caption.copyWith(
                              fontSize: 10,
                              color: ext?.warning ?? CompanionColors.warning,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: ext?.textSecondary,
                  ),
                ],
              ),
            ),
          );
        }

        return PopupMenuButton<String>(
          tooltip: 'Switch or manage Profile',
          constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
          offset: isCollapsed ? const Offset(56, 0) : const Offset(0, 48),
          child: trigger,
          onSelected: (action) async {
            if (action == '__create__') {
              await showCreateProfileDialog(context, controller);
            } else if (action == '__rename__') {
              if (controller.activeProfileId != null) {
                await showRenameProfileDialog(
                  context,
                  controller,
                  profileId: controller.activeProfileId!,
                  currentName: controller.activeProfileName ?? '',
                  isDefault: isDefault,
                );
              }
            } else if (action == '__sign_out__') {
              await controller.lockActiveProfile();
            } else if (action == '__settings__') {
              onOpenSettings?.call();
            } else {
              // Action is a profileId
              await controller.switchToProfile(action);
            }
          },
          itemBuilder: (ctx) {
            final items = <PopupMenuEntry<String>>[];

            items.add(
              const PopupMenuItem<String>(
                enabled: false,
                height: 28,
                child: Text(
                  'PROFILES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            );

            for (final p in controller.profiles) {
              final id = p['id'] as String;
              final name = p['name'] as String;
              final isDef = p['is_default'] == true;
              final isPin = p['pin_protected'] == true;
              final isActive = id == controller.activeProfileId;

              items.add(
                PopupMenuItem<String>(
                  value: id,
                  enabled: !isPin && !controller.busy,
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.check_circle_rounded : Icons.person_outline_rounded,
                        size: 16,
                        color: isActive
                            ? (ext?.accent ?? CompanionColors.lightAccent)
                            : (isPin ? Colors.grey : ext?.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isDef ? '$name (Personal / Default)' : name,
                          style: TextStyle(
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isPin ? Colors.grey : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPin) ...[
                        const SizedBox(width: 4),
                        const Text(
                          '(Locked - PIN)',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            items.add(const PopupMenuDivider());

            items.add(
              const PopupMenuItem<String>(
                value: '__create__',
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Create New Profile...',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (controller.activeProfileId != null) {
              items.add(
                const PopupMenuItem<String>(
                  value: '__rename__',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rename Current Profile...',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              items.add(
                const PopupMenuItem<String>(
                  value: '__sign_out__',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sign out',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (onOpenSettings != null) {
              items.add(
                const PopupMenuItem<String>(
                  value: '__settings__',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Manage Profiles in Settings...',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return items;
          },
        );
      },
    );
  }
}
