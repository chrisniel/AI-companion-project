import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/desktop_settings_controller.dart';
import '../coordinator/desktop_runtime_coordinator.dart';
import '../features/chat/desktop_chat_controller.dart';
import '../lifecycle/desktop_lifecycle_coordinator.dart';
import '../platform/desktop_client_settings.dart';
import '../screens/chat_screen.dart';
import '../screens/memory_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/studio_screen.dart';
import '../screens/voice_screen.dart';
import 'desktop_navigation_rail.dart';

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class HideToTrayIntent extends Intent {
  const HideToTrayIntent();
}

class DesktopShell extends StatelessWidget {
  const DesktopShell({
    super.key,
    required this.controller,
    this.coordinator,
    this.chatController,
    this.runtimeCoordinator,
    this.clientSettings,
    this.credentialStore,
  });

  final DesktopSettingsController controller;
  final DesktopLifecycleCoordinator? coordinator;
  final DesktopChatController? chatController;
  final DesktopRuntimeCoordinator? runtimeCoordinator;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ext = Theme.of(context).extension<CompanionThemeExtension>();
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final shortcuts = <ShortcutActivator, Intent>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma):
              const OpenSettingsIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const HideToTrayIntent(),
        };

        final actions = <Type, Action<Intent>>{
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) {
              controller.setDestination(DesktopNavDestination.settings);
              return null;
            },
          ),
          HideToTrayIntent: CallbackAction<HideToTrayIntent>(
            onInvoke: (_) {
              if (coordinator?.isTrayAvailable == true) {
                coordinator?.hideToTray();
              }
              return null;
            },
          ),
        };

        return Shortcuts(
          shortcuts: shortcuts,
          child: Actions(
            actions: actions,
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: ext?.appBg ??
                    (isDark ? CompanionColors.darkAppBg : CompanionColors.lightAppBg),
                body: Stack(
                  children: [
                    // SoftGlass ambient background glow
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.6, -0.6),
                            radius: 1.2,
                            colors: [
                              (ext?.accentGlow ?? ext?.accent ?? CompanionColors.lightAccent)
                                  .withValues(alpha: isDark ? 0.08 : 0.04),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Main Layout: Rail + Active Screen
                    SafeArea(
                      child: Row(
                        children: [
                          DesktopNavigationRail(
                            controller: controller,
                            coordinator: coordinator,
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _buildActiveScreen(controller.currentDestination),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveScreen(DesktopNavDestination destination) {
    switch (destination) {
      case DesktopNavDestination.chat:
        return ChatScreen(
          key: const ValueKey('chat_screen'),
          controller: chatController,
        );
      case DesktopNavDestination.voice:
        return const VoiceScreen(key: ValueKey('voice_screen'));
      case DesktopNavDestination.schedule:
        return const ScheduleScreen(key: ValueKey('schedule_screen'));
      case DesktopNavDestination.memory:
        return const MemoryScreen(key: ValueKey('memory_screen'));
      case DesktopNavDestination.studio:
        return const StudioScreen(key: ValueKey('studio_screen'));
      case DesktopNavDestination.settings:
        return SettingsScreen(
          key: const ValueKey('settings_screen'),
          controller: controller,
          coordinator: coordinator,
          chatController: chatController,
          runtimeCoordinator: runtimeCoordinator,
          clientSettings: clientSettings,
          credentialStore: credentialStore,
        );
    }
  }
}
