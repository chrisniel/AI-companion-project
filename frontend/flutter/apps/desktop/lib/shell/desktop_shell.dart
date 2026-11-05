import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/desktop_settings_controller.dart';
import '../coordinator/desktop_runtime_coordinator.dart';
import '../dialogs/desktop_shutdown_dialogs.dart';
import '../features/chat/desktop_chat_controller.dart';
import '../features/profiles/desktop_profile_controller.dart';
import '../features/studio/desktop_studio_controller.dart';
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

class DesktopShell extends StatefulWidget {
  const DesktopShell({
    super.key,
    required this.controller,
    this.coordinator,
    this.chatController,
    this.profileController,
    this.studioController,
    this.runtimeCoordinator,
    this.clientSettings,
    this.credentialStore,
  });

  final DesktopSettingsController controller;
  final DesktopLifecycleCoordinator? coordinator;
  final DesktopChatController? chatController;
  final DesktopProfileController? profileController;
  final DesktopStudioController? studioController;
  final DesktopRuntimeCoordinator? runtimeCoordinator;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  final Set<DesktopNavDestination> _visitedDestinations = <DesktopNavDestination>{};
  late final DesktopStudioController? _studioController;
  bool _ownsStudioController = false;

  @override
  void initState() {
    super.initState();
    _visitedDestinations.add(widget.controller.currentDestination);
    if (widget.studioController != null) {
      _studioController = widget.studioController;
    } else if (widget.chatController != null) {
      _studioController = DesktopStudioController(chat: widget.chatController!);
      _ownsStudioController = true;
    } else {
      _studioController = null;
    }
    widget.controller.navigationGuard = _handleNavigationGuard;
    widget.coordinator?.onExitMenuTriggered = () async {
      if (mounted) {
        await _handleExitCompanion();
      }
    };
  }

  Future<void> _handleExitCompanion() async {
    final confirmed = await DesktopShutdownDialogs.showExitConfirmationDialog(context);
    if (!confirmed || !mounted) return;

    final rc = widget.runtimeCoordinator;
    if (rc == null) {
      widget.coordinator?.handleExitRequested();
      return;
    }

    final outcome = await rc.shutdownLocalRuntime();
    if (!mounted) return;

    if (outcome == ShutdownOutcome.gracefulSuccess ||
        outcome == ShutdownOutcome.emergencyTerminated) {
      widget.coordinator?.handleExitRequested();
      return;
    }

    if (outcome == ShutdownOutcome.incompleteCleanup) {
      final action = await DesktopShutdownDialogs.showIncompleteShutdownDialog(
        context,
        diagnostic: rc.currentState.diagnosticMessage,
      );
      if (!mounted) return;

      switch (action) {
        case IncompleteShutdownAction.retryGraceful:
          await _handleExitCompanion();
          break;
        case IncompleteShutdownAction.forceStop:
          final forceOutcome = await rc.forceEmergencyStopLocalRuntime();
          if (mounted) {
            if (forceOutcome == ShutdownOutcome.emergencyTerminated ||
                forceOutcome == ShutdownOutcome.gracefulSuccess) {
              widget.coordinator?.handleExitRequested();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Emergency stop failed: ${rc.currentState.diagnosticMessage ?? "Unable to terminate runtime process"}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;
        case IncompleteShutdownAction.quitUiOnly:
          widget.coordinator?.handleExitRequested();
          break;
        case IncompleteShutdownAction.cancel:
        case null:
          break;
      }
      return;
    }

    if (outcome == ShutdownOutcome.unresponsiveRuntime) {
      final action = await DesktopShutdownDialogs.showUnresponsiveShutdownDialog(
        context,
        diagnostic: rc.currentState.diagnosticMessage,
      );
      if (!mounted) return;

      switch (action) {
        case UnresponsiveShutdownAction.forceStop:
          final forceOutcome = await rc.forceEmergencyStopLocalRuntime();
          if (mounted) {
            if (forceOutcome == ShutdownOutcome.emergencyTerminated ||
                forceOutcome == ShutdownOutcome.gracefulSuccess) {
              widget.coordinator?.handleExitRequested();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Emergency stop failed: ${rc.currentState.diagnosticMessage ?? "Unable to terminate runtime process"}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;
        case UnresponsiveShutdownAction.quitUiOnly:
          widget.coordinator?.handleExitRequested();
          break;
        case UnresponsiveShutdownAction.cancel:
        case null:
          break;
      }
    }
  }

  @override
  void dispose() {
    if (_ownsStudioController) {
      _studioController?.dispose();
    }
    super.dispose();
  }

  Future<bool> _handleNavigationGuard(DesktopNavDestination from, DesktopNavDestination to) async {
    final studio = _studioController;
    if (from == DesktopNavDestination.studio && studio != null && studio.draft?.isDirty == true) {
      final draft = studio.draft!;
      final decision = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Studio Customizations'),
          content: Text('You have unsaved changes to "${draft.name}". What would you like to do before leaving Studio?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('stay'),
              child: const Text('Stay in Studio'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: const Text('Discard & Leave'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('save'),
              child: const Text('Save & Leave'),
            ),
          ],
        ),
      );

      if (decision == 'save') {
        final success = await studio.saveDraft();
        if (success && studio.draft?.isDirty == false) {
          return true;
        }
        return false;
      } else if (decision == 'discard') {
        return true;
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        _visitedDestinations.add(widget.controller.currentDestination);
        final currentDest = widget.controller.currentDestination;
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
              widget.controller.requestDestination(DesktopNavDestination.settings);
              return null;
            },
          ),
          HideToTrayIntent: CallbackAction<HideToTrayIntent>(
            onInvoke: (_) {
              if (widget.coordinator?.isTrayAvailable == true) {
                widget.coordinator?.hideToTray();
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
                            controller: widget.controller,
                            coordinator: widget.coordinator,
                          ),
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                for (final destination in _visitedDestinations)
                                  Offstage(
                                    offstage: currentDest != destination,
                                    child: TickerMode(
                                      enabled: currentDest == destination,
                                      child: _buildActiveScreen(destination),
                                    ),
                                  ),
                              ],
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
          controller: widget.chatController,
          onNavigateToSettings: () => widget.controller.requestDestination(DesktopNavDestination.settings),
        );
      case DesktopNavDestination.voice:
        return const VoiceScreen(key: ValueKey('voice_screen'));
      case DesktopNavDestination.schedule:
        return const ScheduleScreen(key: ValueKey('schedule_screen'));
      case DesktopNavDestination.memory:
        return const MemoryScreen(key: ValueKey('memory_screen'));
      case DesktopNavDestination.studio:
        final studio = _studioController;
        if (studio != null) {
          return StudioScreen(
            key: const ValueKey('studio_screen'),
            controller: studio,
            onNavigateToSettings: () => widget.controller.requestDestination(DesktopNavDestination.settings),
          );
        }
        return const Center(child: Text('Studio unavailable'));
      case DesktopNavDestination.settings:
        return SettingsScreen(
          key: const ValueKey('settings_screen'),
          controller: widget.controller,
          coordinator: widget.coordinator,
          chatController: widget.chatController,
          profileController: widget.profileController,
          runtimeCoordinator: widget.runtimeCoordinator,
          clientSettings: widget.clientSettings,
          credentialStore: widget.credentialStore,
        );
    }
  }
}
