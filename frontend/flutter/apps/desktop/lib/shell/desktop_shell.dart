import 'dart:async';
import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/desktop_settings_controller.dart';
import '../coordinator/desktop_runtime_coordinator.dart';
import '../dialogs/desktop_shutdown_dialogs.dart';
import '../features/chat/desktop_chat_controller.dart';
import '../features/profiles/desktop_profile_controller.dart';
import '../features/memory/desktop_memory_controller.dart';
import '../features/schedule/desktop_schedule_controller.dart';
import '../features/schedule/notification_backlog_drawer.dart';
import '../features/settings/settings_section.dart';
import '../features/studio/desktop_studio_controller.dart';
import '../features/tools/desktop_tool_policy_controller.dart';
import '../features/voice/desktop_voice_controller.dart';
import '../features/voice/voice_shortcut_recorder.dart';
import '../lifecycle/desktop_lifecycle_coordinator.dart';
import '../platform/desktop_audio_adapter.dart';
import '../platform/desktop_client_settings.dart';
import '../platform/windows_toast_adapter.dart';
import '../screens/chat_screen.dart';
import '../screens/memory_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/studio_screen.dart';
import 'desktop_navigation_rail.dart';

class DesktopShell extends StatefulWidget {
  const DesktopShell({
    super.key,
    required this.controller,
    this.coordinator,
    this.chatController,
    this.profileController,
    this.studioController,
    this.memoryController,
    this.runtimeCoordinator,
    this.clientSettings,
    this.credentialStore,
    this.scheduleController,
    this.toolPolicyController,
    this.voiceController,
    this.audioAdapter,
    this.toastAdapter,
    this.enableSchedulePolling,
  });

  final DesktopSettingsController controller;
  final DesktopLifecycleCoordinator? coordinator;
  final DesktopChatController? chatController;
  final DesktopProfileController? profileController;
  final DesktopStudioController? studioController;
  final DesktopMemoryController? memoryController;
  final DesktopRuntimeCoordinator? runtimeCoordinator;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;
  final DesktopScheduleController? scheduleController;
  final DesktopToolPolicyController? toolPolicyController;
  final DesktopVoiceController? voiceController;
  final DesktopAudioAdapter? audioAdapter;
  final DesktopToastAdapter? toastAdapter;
  final bool? enableSchedulePolling;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  final Set<DesktopNavDestination> _visitedDestinations = <DesktopNavDestination>{};
  late final DesktopStudioController? _studioController;
  bool _ownsStudioController = false;
  late final DesktopMemoryController? _memoryController;
  bool _ownsMemoryController = false;
  late final DesktopScheduleController? _scheduleController;
  bool _ownsScheduleController = false;
  late final DesktopToolPolicyController? _toolPolicyController;
  bool _ownsToolPolicyController = false;
  late final DesktopVoiceController? _voiceController;
  bool _ownsVoiceController = false;
  String? _lastKnownToolProfileId;
  int _lastKnownVoiceProfileEpoch = 0;
  bool _lastKnownVoiceConnected = false;
  String? _lastKnownVoiceProfileId;
  bool Function()? _chatHistoryDrawerCloser;
  VoidCallback? _chatHistoryDrawerToggler;
  bool _pendingToggleHistoryDrawer = false;
  DesktopToastAdapter? _toastAdapter;
  bool _ownsToastAdapter = false;
  bool _isBacklogDrawerOpen = false;
  DesktopNavDestination _lastDestination = DesktopNavDestination.chat;

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

    if (widget.memoryController != null) {
      _memoryController = widget.memoryController;
    } else if (widget.chatController != null) {
      final active = widget.profileController?.activeProfile;
      final profileId = active?['id'] as String?;
      final extractionEnabled = active?['memory_extraction_enabled'] as bool? ?? true;
      _memoryController = DesktopMemoryController(
        client: widget.chatController!.client,
        profileId: profileId,
        initialExtractionEnabled: extractionEnabled,
      );
      _ownsMemoryController = true;
    } else {
      _memoryController = null;
    }

    if (widget.scheduleController != null) {
      _scheduleController = widget.scheduleController;
      _ownsScheduleController = false;
      _scheduleController!.onNavigateRequested ??= _handleToastNavigation;
    } else if (widget.chatController != null) {
      final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
      _toastAdapter = widget.toastAdapter ??
          (!isFlutterTest && Platform.isWindows
              ? WindowsWinRtToastAdapter()
              : NoOpDesktopToastAdapter());
      _ownsToastAdapter = widget.toastAdapter == null;
      _scheduleController = DesktopScheduleController(
        clientProvider: () => widget.chatController!.client,
        toastAdapter: _toastAdapter,
        profileId: _resolveActiveProfileId(),
        isConnected: widget.chatController!.isConnected,
        onNavigateRequested: _handleToastNavigation,
      );
      _ownsScheduleController = true;
    } else {
      _scheduleController = null;
    }

    if (widget.toolPolicyController != null) {
      _toolPolicyController = widget.toolPolicyController;
      _ownsToolPolicyController = false;
    } else if (widget.chatController != null) {
      _toolPolicyController = DesktopToolPolicyController(
        clientProvider: () => widget.chatController!.client,
      );
      _ownsToolPolicyController = true;
    } else {
      _toolPolicyController = null;
    }

    if (widget.voiceController != null) {
      _voiceController = widget.voiceController;
      _ownsVoiceController = false;
    } else if (widget.chatController != null) {
      final chat = widget.chatController!;
      _voiceController = DesktopVoiceController(
        clientProvider: () => chat.client,
        audioAdapter: widget.audioAdapter,
        clientSettings: widget.clientSettings,
        ensureActiveConversationId: () async {
          if (chat.activeConversation?.id == null) {
            await chat.createNewConversation();
          }
          return chat.activeConversation?.id;
        },
        onConversationMessagesUpdated: (conversationId) async {
          if (chat.activeConversation?.id == conversationId) {
            await chat.loadMessages(conversationId);
          } else {
            await chat.loadConversations();
          }
        },
        onAudioMutedChanged: (muted) {
          try {
            unawaited(widget.coordinator?.updateAudioMutedStatus(muted));
          } on UnimplementedError {
            // Minimal Fake coordinators in widget tests may omit optional tray sync.
          }
        },
        onGlobalHotkeyTriggered: _handleGlobalVoiceHotkeyTriggered,
      );
      _ownsVoiceController = true;
    } else {
      _voiceController = null;
    }

    _lastKnownToolProfileId = _resolveActiveProfileId();
    _lastKnownVoiceProfileEpoch = widget.chatController?.profileEpoch ?? 0;
    _lastKnownVoiceConnected = widget.chatController?.isConnected ?? false;
    _lastKnownVoiceProfileId = _lastKnownToolProfileId;
    HardwareKeyboard.instance.addHandler(_handleShellHardwareKey);
    _toolPolicyController?.addListener(_handleToolPolicyChange);
    if (_toolPolicyController != null && widget.coordinator != null) {
      final toolCtrl = _toolPolicyController;
      try {
        widget.coordinator!.onKillSwitchTriggered = () async {
          if (!toolCtrl.globalKillSwitch) {
            await toolCtrl.toggleKillSwitch(
              enabled: true,
              reason: 'tray_emergency_stop',
            );
          }
        };
      } on UnimplementedError {
        // Minimal Fake coordinators in widget tests may omit optional callbacks.
      }
    }
    if (_voiceController != null && widget.coordinator != null) {
      final voiceCtrl = _voiceController;
      try {
        widget.coordinator!.onMuteToggleTriggered = () async {
          await voiceCtrl.setMuted(!voiceCtrl.isAudioMuted);
        };
      } on UnimplementedError {
        // Minimal Fake coordinators in widget tests may omit optional callbacks.
      }
    }

    _lastDestination = widget.controller.currentDestination;
    widget.controller.addListener(_handleDestinationChange);
    widget.profileController?.addListener(_handleProfileChange);
    widget.chatController?.addListener(_handleProfileChange);
    widget.controller.navigationGuard = _handleNavigationGuard;
    _initScheduleActivation();
    if (_ownsVoiceController && _shouldPollSchedule) {
      unawaited(_voiceController?.initialize());
    }
    if (_ownsToolPolicyController &&
        _shouldPollSchedule &&
        (widget.chatController?.isConnected ?? false)) {
      unawaited(_toolPolicyController?.refreshKillSwitch());
    }
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

  bool get _shouldPollSchedule =>
      widget.enableSchedulePolling ??
      !Platform.environment.containsKey('FLUTTER_TEST');

  String? _resolveActiveProfileId() {
    return widget.profileController?.activeProfileId ??
        widget.chatController?.authenticatedProfileId;
  }

  String? _resolveActiveProfileName() {
    return widget.profileController?.activeProfileName ??
        widget.chatController?.authenticatedProfileName;
  }

  void _initScheduleActivation() {
    final ctrl = _scheduleController;
    if (ctrl == null) return;
    final active = ctrl.isConnected &&
        ctrl.profileId != null &&
        ctrl.profileId!.isNotEmpty;
    if (!active) return;

    if (_ownsScheduleController) {
      unawaited(ctrl.refreshAll());
    }
    if (_shouldPollSchedule) {
      ctrl.startPolling();
    }
  }

  void _handleToastNavigation(ToastNavigationTarget target) {
    if (!mounted) return;
    unawaited(
      widget.coordinator?.restoreAndFocusWindow() ?? Future<void>.value(),
    );
    switch (target) {
      case ToastNavigationTarget.chat:
        widget.controller.requestDestination(DesktopNavDestination.chat);
        break;
      case ToastNavigationTarget.schedule:
        widget.controller.requestDestination(DesktopNavDestination.schedule);
        break;
      case ToastNavigationTarget.backlogDrawer:
        setState(() => _isBacklogDrawerOpen = true);
        break;
    }
  }

  void _syncScheduleScope() {
    final ctrl = _scheduleController;
    if (ctrl == null || !_ownsScheduleController) return;
    final connected = widget.chatController?.isConnected ?? false;
    final profileId = _resolveActiveProfileId();
    final scopeChanged =
        ctrl.profileId != profileId || ctrl.isConnected != connected;
    if (!scopeChanged) return;

    if (!connected || profileId == null || profileId.isEmpty) {
      ctrl.clearForDisconnect();
      if (_isBacklogDrawerOpen && mounted) {
        setState(() => _isBacklogDrawerOpen = false);
      }
      return;
    }

    ctrl.updateProfileScope(profileId: profileId, isConnected: connected);
    unawaited(ctrl.refreshAll());
    if (_shouldPollSchedule) {
      ctrl.startPolling();
    }
  }

  void _handleDestinationChange() {
    final dest = widget.controller.currentDestination;
    if (dest != _lastDestination) {
      _lastDestination = dest;
      if (_isBacklogDrawerOpen && mounted) {
        setState(() => _isBacklogDrawerOpen = false);
      }
      if (dest == DesktopNavDestination.memory) {
        _memoryController?.loadMemories();
      } else if (dest == DesktopNavDestination.schedule &&
          (_scheduleController?.isConnected == true) &&
          (_scheduleController?.profileId?.isNotEmpty == true) &&
          _ownsScheduleController) {
        unawaited(_scheduleController?.refreshAll());
      }
    }
  }

  Future<void> _handleGlobalVoiceHotkeyTriggered() async {
    final vc = _voiceController;
    if (!mounted || vc == null) return;
    try {
      await widget.coordinator?.restoreAndFocusWindow();
    } on UnimplementedError {
      // Test coordinator doubles may omit window management.
    }
    await widget.controller.requestDestination(DesktopNavDestination.chat);
    if (vc.isLiveVoiceActive) {
      await vc.stopLiveVoice();
    } else {
      await vc.startLiveVoice();
    }
  }

  void _handleToolPolicyChange() {
    final ctrl = _toolPolicyController;
    final coord = widget.coordinator;
    if (ctrl == null || coord == null) return;
    try {
      unawaited(coord.updateKillSwitchStatus(ctrl.globalKillSwitch));
    } on UnimplementedError {
      // Minimal Fake coordinators in widget tests may omit optional tray status sync.
    }
  }

  void _handleProfileChange() {
    final active = widget.profileController?.activeProfile;
    final profileId = active?['id'] as String?;
    final extractionEnabled = active?['memory_extraction_enabled'] as bool?;
    _memoryController?.updateProfileScope(
      profileId: profileId,
      memoryExtractionEnabled: extractionEnabled,
    );
    _syncScheduleScope();
    final effectiveProfileId = _resolveActiveProfileId();
    if (effectiveProfileId != _lastKnownToolProfileId) {
      _lastKnownToolProfileId = effectiveProfileId;
      _toolPolicyController?.resetForProfileChange();
      if (effectiveProfileId != null && effectiveProfileId.isNotEmpty) {
        unawaited(_toolPolicyController?.refreshAll());
      } else {
        unawaited(_toolPolicyController?.refreshKillSwitch());
      }
    }
    final connected = widget.chatController?.isConnected ?? false;
    final voiceEpoch = widget.chatController?.profileEpoch;
    if (voiceEpoch != null && voiceEpoch != _lastKnownVoiceProfileEpoch) {
      _lastKnownVoiceProfileEpoch = voiceEpoch;
      _lastKnownVoiceConnected = connected;
      _lastKnownVoiceProfileId = effectiveProfileId;
      unawaited(_voiceController?.handleProfileEpochChanged(voiceEpoch));
    } else if (connected &&
        (!_lastKnownVoiceConnected ||
            effectiveProfileId != _lastKnownVoiceProfileId ||
            (_voiceController?.initialized == true &&
                _voiceController?.voiceSettings == null &&
                _voiceController?.isLoading == false))) {
      _lastKnownVoiceConnected = connected;
      _lastKnownVoiceProfileId = effectiveProfileId;
      unawaited(_voiceController?.refreshBackendState());
    } else {
      _lastKnownVoiceConnected = connected;
      _lastKnownVoiceProfileId = effectiveProfileId;
    }
  }

  bool _isEditableTextFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _handleShellHardwareKey(KeyEvent event) {
    if (!mounted || VoiceShortcutKeyMapper.isCaptureModalOpen) return false;
    if (event is! KeyDownEvent) return false;

    final hw = HardwareKeyboard.instance;
    final isCtrlOnly = hw.isControlPressed &&
        !hw.isAltPressed &&
        !hw.isShiftPressed &&
        !hw.isMetaPressed;
    if (isCtrlOnly &&
        event is! KeyRepeatEvent &&
        event.logicalKey == LogicalKeyboardKey.comma) {
      widget.controller.requestDestination(DesktopNavDestination.settings);
      return true;
    }
    if (isCtrlOnly &&
        event is! KeyRepeatEvent &&
        event.logicalKey == LogicalKeyboardKey.keyH) {
      final notOnChat =
          widget.controller.currentDestination != DesktopNavDestination.chat;
      if (notOnChat) {
        widget.controller.requestDestination(DesktopNavDestination.chat);
        final toggler = _chatHistoryDrawerToggler;
        if (toggler != null) {
          // Ensure History Drawer is open when switching from another tab.
          if (_chatHistoryDrawerCloser == null ||
              !_visitedDestinations.contains(DesktopNavDestination.chat)) {
            toggler();
          } else {
            // Close first if left open, or simpler: call toggler only if not already open.
            final wasOpen = _chatHistoryDrawerCloser!.call();
            if (!wasOpen) {
              toggler();
            } else {
              // Keep open when jumping into Chat from Settings via Ctrl+H
              toggler();
            }
          }
        } else {
          _pendingToggleHistoryDrawer = true;
        }
      } else {
        _chatHistoryDrawerToggler?.call();
      }
      return true;
    }

    final vc = _voiceController;
    if (vc != null && event is! KeyRepeatEvent) {
      if (VoiceShortcutKeyMapper.matchesKeyEvent(
        event,
        vc.shortcuts.inAppToggle,
      )) {
        if (vc.isLiveVoiceActive) {
          unawaited(vc.stopLiveVoice());
        } else {
          unawaited(widget.controller.requestDestination(DesktopNavDestination.chat));
          unawaited(vc.startLiveVoice());
        }
        return true;
      }
      final isF8Backup = event.logicalKey == LogicalKeyboardKey.f8 &&
          !hw.isControlPressed &&
          !hw.isAltPressed &&
          !hw.isShiftPressed &&
          !hw.isMetaPressed &&
          vc.shortcuts.inAppToggle.virtualKey != 0x77 &&
          vc.shortcuts.pushToTalk.virtualKey != 0x77;
      if (VoiceShortcutKeyMapper.matchesKeyEvent(
            event,
            vc.shortcuts.muteToggle,
          ) ||
          isF8Backup) {
        unawaited(vc.setMuted(!vc.isAudioMuted));
        return true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        !hw.isControlPressed &&
        !hw.isAltPressed &&
        !hw.isShiftPressed &&
        !hw.isMetaPressed) {
      if (_isEditableTextFocused()) {
        return false;
      }
      if (_isBacklogDrawerOpen) {
        setState(() => _isBacklogDrawerOpen = false);
        return true;
      }
      if (widget.controller.currentDestination == DesktopNavDestination.chat &&
          (_chatHistoryDrawerCloser?.call() ?? false)) {
        return true;
      }
      if (widget.coordinator?.isTrayAvailable == true) {
        widget.coordinator?.hideToTray();
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleShellHardwareKey);
    widget.controller.removeListener(_handleDestinationChange);
    widget.profileController?.removeListener(_handleProfileChange);
    widget.chatController?.removeListener(_handleProfileChange);
    _toolPolicyController?.removeListener(_handleToolPolicyChange);
    if (_ownsStudioController) {
      _studioController?.dispose();
    }
    if (_ownsMemoryController) {
      _memoryController?.dispose();
    }
    if (_ownsScheduleController) {
      _scheduleController?.dispose();
    } else if (_scheduleController?.onNavigateRequested ==
        _handleToastNavigation) {
      _scheduleController?.onNavigateRequested = null;
    }
    if (_ownsToolPolicyController) {
      _toolPolicyController?.dispose();
    }
    if (_ownsVoiceController) {
      _voiceController?.dispose();
    }
    if (_ownsToastAdapter) {
      _toastAdapter?.dispose();
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

        return Focus(
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
                            profileController: widget.profileController,
                            onHideToTrayRequested: () => widget.coordinator?.hideToTray(),
                            onExitRequested: _handleExitCompanion,
                            onOpenLifecycleSettings: () => widget.controller
                                .requestOpenSettingsSection(
                              SettingsSectionId.general,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_scheduleController != null ||
                                    _toolPolicyController != null ||
                                    _voiceController != null)
                                  ListenableBuilder(
                                    listenable: Listenable.merge([
                                      if (_scheduleController != null)
                                        _scheduleController,
                                      if (_toolPolicyController != null)
                                        _toolPolicyController,
                                      if (_voiceController != null)
                                        _voiceController,
                                    ]),
                                    builder: (context, _) {
                                      return _buildTopUtilityStrip(
                                        context,
                                        _scheduleController,
                                        _toolPolicyController,
                                        _voiceController,
                                        ext,
                                      );
                                    },
                                  ),
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      for (final destination
                                          in _visitedDestinations)
                                        Offstage(
                                          offstage: currentDest != destination,
                                          child: TickerMode(
                                            enabled: currentDest == destination,
                                            child: _buildActiveScreen(
                                              destination,
                                            ),
                                          ),
                                        ),
                                      if (_scheduleController != null)
                                        Positioned.fill(
                                          child: ListenableBuilder(
                                            listenable: _scheduleController,
                                            builder: (context, _) {
                                              final centerAlert =
                                                  _scheduleController
                                                      .centerPopupAlert;
                                              return IgnorePointer(
                                                ignoring: centerAlert == null,
                                                child: centerAlert == null
                                                    ? const SizedBox.shrink()
                                                    : _buildCenterAlertModal(
                                                        context,
                                                        _scheduleController,
                                                        centerAlert,
                                                        ext,
                                                      ),
                                              );
                                            },
                                          ),
                                        ),
                                      if (_scheduleController != null)
                                        Positioned(
                                          top: CompanionSpacing.md,
                                          left: CompanionSpacing.xl,
                                          right: CompanionSpacing.xl,
                                          child: ListenableBuilder(
                                            listenable: _scheduleController,
                                            builder: (context, _) {
                                              final topAlert =
                                                  _scheduleController
                                                      .topBannerAlert;
                                              if (topAlert == null) {
                                                return const SizedBox.shrink();
                                              }
                                              return Align(
                                                alignment: Alignment.topRight,
                                                child: _buildActiveAlertBanner(
                                                  context,
                                                  _scheduleController,
                                                  topAlert,
                                                  ext,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      if (_isBacklogDrawerOpen &&
                                          _scheduleController != null) ...[
                                        Positioned.fill(
                                          child: GestureDetector(
                                            key: const Key(
                                              'backlog_drawer_dismiss_barrier',
                                            ),
                                            behavior:
                                                HitTestBehavior.translucent,
                                            onTap: () => setState(
                                              () => _isBacklogDrawerOpen = false,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          bottom: 0,
                                          right: 0,
                                          child: NotificationBacklogDrawer(
                                            controller: _scheduleController,
                                            activeProfileName:
                                                _resolveActiveProfileName(),
                                            onClose: () => setState(
                                              () => _isBacklogDrawerOpen = false,
                                            ),
                                            onOpenChat: () {
                                              setState(
                                                () =>
                                                    _isBacklogDrawerOpen = false,
                                              );
                                              widget.controller
                                                  .requestDestination(
                                                DesktopNavDestination.chat,
                                              );
                                            },
                                            onOpenHistory: () {
                                              setState(
                                                () =>
                                                    _isBacklogDrawerOpen = false,
                                              );
                                              _scheduleController.selectSection(
                                                ScheduleSection.notifications,
                                              );
                                              widget.controller
                                                  .requestDestination(
                                                DesktopNavDestination.schedule,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
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
          toolPolicyController: _toolPolicyController,
          voiceController: _voiceController,
          isActiveTab: widget.controller.currentDestination == DesktopNavDestination.chat,
          onRegisterCloseHistoryDrawer: (closer) => _chatHistoryDrawerCloser = closer,
          onRegisterToggleHistoryDrawer: (toggler) {
            _chatHistoryDrawerToggler = toggler;
            if (toggler != null && _pendingToggleHistoryDrawer) {
              _pendingToggleHistoryDrawer = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  toggler();
                }
              });
            }
          },
          onNavigateToSettings: () => widget.controller.requestDestination(DesktopNavDestination.settings),
        );
      case DesktopNavDestination.schedule:
        return ScheduleScreen(
          key: const ValueKey('schedule_screen'),
          controller: _scheduleController,
          onNavigateToSettings: () => widget.controller.requestDestination(
            DesktopNavDestination.settings,
          ),
          onNavigateToChat: () => widget.controller.requestDestination(
            DesktopNavDestination.chat,
          ),
        );
      case DesktopNavDestination.memory:
        return MemoryScreen(
          key: const ValueKey('memory_screen'),
          controller: _memoryController,
        );
      case DesktopNavDestination.studio:
        final studio = _studioController;
        if (studio != null) {
          return StudioScreen(
            key: const ValueKey('studio_screen'),
            controller: studio,
            voiceController: _voiceController,
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
          scheduleController: _scheduleController,
          toolPolicyController: _toolPolicyController,
          voiceController: _voiceController,
        );
    }
  }

  Widget _buildTopUtilityStrip(
    BuildContext context,
    DesktopScheduleController? ctrl,
    DesktopToolPolicyController? toolCtrl,
    DesktopVoiceController? voiceCtrl,
    CompanionThemeExtension? ext,
  ) {
    final profileLabel = _resolveActiveProfileName() ?? ctrl?.profileId;
    final totalAttention = ctrl == null ? 0 : (ctrl.unreadCount + ctrl.missedCount);
    final hasUnread = ctrl != null && ctrl.unreadCount > 0;
    final hasMissedOnly = !hasUnread && ctrl != null && ctrl.missedCount > 0;
    final bellColor = hasUnread
        ? (ext?.accent ?? CompanionColors.lightAccent)
        : hasMissedOnly
            ? (ext?.warning ?? CompanionColors.warning)
            : ext?.textSecondary;

    final badgeText = ctrl == null
        ? ''
        : hasUnread
            ? 'Alerts (${ctrl.unreadCount})'
            : hasMissedOnly
                ? 'Alerts (${ctrl.missedCount} missed)'
                : 'Alerts';

    final killed = toolCtrl?.globalKillSwitch ?? false;

    return Padding(
      key: const Key('shell_top_utility_strip'),
      padding: const EdgeInsets.fromLTRB(
        CompanionSpacing.xl,
        CompanionSpacing.sm,
        CompanionSpacing.xl,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: CompanionSpacing.sm,
              runSpacing: CompanionSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (profileLabel != null && profileLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (ext?.accent ?? CompanionColors.lightAccent)
                          .withValues(alpha: 0.12),
                      borderRadius: CompanionRadius.borderFull,
                    ),
                    child: Text(
                      'Profile Scope: $profileLabel',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.accent,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (ctrl != null && ctrl.quietHours.quietHoursEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (ext?.textMuted ?? CompanionColors.lightTextMuted)
                          .withValues(alpha: 0.12),
                      borderRadius: CompanionRadius.borderFull,
                    ),
                    child: Text(
                      'Quiet ${ctrl.quietHours.quietHoursStart}-${ctrl.quietHours.quietHoursEnd}',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textSecondary,
                      ),
                    ),
                  ),
                if (voiceCtrl != null && voiceCtrl.isMicCapturing)
                  Tooltip(
                    message: 'Microphone is active — click to mute',
                    child: InkWell(
                      key: const Key('shell_mic_privacy_indicator'),
                      borderRadius: CompanionRadius.borderFull,
                      onTap: () => unawaited(voiceCtrl.setMuted(true)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (ext?.warning ?? CompanionColors.warning)
                              .withValues(alpha: 0.16),
                          borderRadius: CompanionRadius.borderFull,
                          border: Border.all(
                            color: (ext?.warning ?? CompanionColors.warning)
                                .withValues(alpha: 0.65),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (ext?.warning ?? CompanionColors.warning)
                                  .withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_rounded,
                              size: 13,
                              color: ext?.warning ?? CompanionColors.warning,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Mic Active',
                              style: CompanionTypography.caption.copyWith(
                                color: ext?.warning ?? CompanionColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (voiceCtrl != null && voiceCtrl.isAudioMuted)
                  Tooltip(
                    message: 'Audio & mic muted — click to unmute',
                    child: InkWell(
                      key: const Key('shell_mic_muted_indicator'),
                      borderRadius: CompanionRadius.borderFull,
                      onTap: () => unawaited(voiceCtrl.setMuted(false)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (ext?.warning ?? CompanionColors.warning)
                              .withValues(alpha: 0.12),
                          borderRadius: CompanionRadius.borderFull,
                          border: Border.all(
                            color: (ext?.warning ?? CompanionColors.warning)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_off_rounded,
                              size: 13,
                              color: ext?.warning ?? CompanionColors.warning,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Audio Muted · Unmute',
                              style: CompanionTypography.caption.copyWith(
                                color: ext?.warning ?? CompanionColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (toolCtrl != null) ...[
            const SizedBox(width: CompanionSpacing.sm),
            OutlinedButton.icon(
              key: const Key('shell_kill_switch_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: killed
                    ? (ext?.danger ?? CompanionColors.danger)
                    : ext?.textPrimary,
                side: BorderSide(
                  color: killed
                      ? (ext?.danger ?? CompanionColors.danger)
                      : (ext?.textMuted ?? CompanionColors.lightTextMuted)
                          .withValues(alpha: 0.35),
                ),
              ),
              onPressed: toolCtrl.isSaving
                  ? null
                  : () async {
                      if (killed) {
                        await widget.controller.requestOpenSettingsSection(
                          SettingsSectionId.tools,
                        );
                      } else {
                        await toolCtrl.toggleKillSwitch(
                          enabled: true,
                          reason: 'shell_top_bar_emergency',
                        );
                      }
                    },
              icon: Icon(
                killed ? Icons.gpp_bad_rounded : Icons.shield_outlined,
                size: 16,
                color: killed
                    ? (ext?.danger ?? CompanionColors.danger)
                    : ext?.accent,
              ),
              label: Text(
                killed ? 'Tools KILLED' : 'Stop Tools',
                style: CompanionTypography.caption.copyWith(
                  color: killed
                      ? (ext?.danger ?? CompanionColors.danger)
                      : ext?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (ctrl != null) ...[
            const SizedBox(width: CompanionSpacing.sm),
            OutlinedButton.icon(
              key: const Key('shell_notification_bell_button'),
              onPressed: () =>
                  setState(() => _isBacklogDrawerOpen = !_isBacklogDrawerOpen),
              icon: Icon(
                totalAttention > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size: 16,
                color: bellColor,
              ),
              label: Text(
                badgeText,
                style: CompanionTypography.caption.copyWith(
                  color: hasUnread ? ext?.accent : ext?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveAlertBanner(
    BuildContext context,
    DesktopScheduleController ctrl,
    NotificationEventOut alert,
    CompanionThemeExtension? ext,
  ) {
    final isUrgent = ctrl.isUrgentAlert(alert);
    final isTaskReminder = ctrl.isTaskReminderAlert(alert);
    final isRoutine = alert.sourceType == 'routine';
    final accentColor = isUrgent
        ? (ext?.danger ?? CompanionColors.danger)
        : (ext?.accent ?? CompanionColors.lightAccent);
    final nonModalCount =
        ctrl.activeAlerts.where((e) => !ctrl.usesCenterPopup(e)).length;
    final kindLabel = switch (alert.sourceType) {
      'routine' => 'ROUTINE',
      'task_reminder' => 'TASK REMINDER',
      'alarm' => 'ALARM',
      _ => 'REMINDER',
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SoftGlassPanel(
        key: const Key('shell_active_alert_banner'),
        padding: const EdgeInsets.all(CompanionSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: CompanionRadius.borderSm,
                  ),
                  child: Icon(
                    isRoutine
                        ? Icons.auto_awesome_rounded
                        : Icons.notifications_active_rounded,
                    size: 18,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: CompanionSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            kindLabel,
                            style: CompanionTypography.caption.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          if (nonModalCount > 1) ...[
                            const SizedBox(width: CompanionSpacing.xs),
                            Text(
                              '(+${nonModalCount - 1} more)',
                              style: CompanionTypography.caption.copyWith(
                                color: ext?.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.title,
                        style: CompanionTypography.bodyMedium.copyWith(
                          color: ext?.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (alert.body != null &&
                          alert.body!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          alert.body!,
                          style: CompanionTypography.bodySmall.copyWith(
                            color: ext?.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CompanionSpacing.sm),
            Wrap(
              spacing: CompanionSpacing.xs,
              runSpacing: CompanionSpacing.xs,
              children: [
                FilledButton.tonal(
                  key: const Key('banner_acknowledge_button'),
                  onPressed: ctrl.isMutating
                      ? null
                      : () => ctrl.acknowledgeNotification(
                            alert.id,
                            completeTask: isTaskReminder,
                          ),
                  child: Text(ctrl.primaryActionLabel(alert)),
                ),
                if (!isRoutine)
                  OutlinedButton(
                    key: const Key('banner_snooze_button'),
                    onPressed: ctrl.isMutating
                        ? null
                        : () => ctrl.snoozeNotification(alert.id),
                    child: const Text('Snooze 10m'),
                  ),
                if (isRoutine)
                  OutlinedButton(
                    key: const Key('banner_open_chat_button'),
                    onPressed: ctrl.isMutating
                        ? null
                        : () async {
                            await ctrl.markNotificationRead(alert.id);
                            widget.controller.requestDestination(
                              DesktopNavDestination.chat,
                            );
                          },
                    child: const Text('Open Chat'),
                  ),
                TextButton(
                  key: const Key('banner_dismiss_button'),
                  onPressed: ctrl.isMutating
                      ? null
                      : () => ctrl.dismissNotification(alert.id),
                  child: const Text('Dismiss'),
                ),
                TextButton(
                  key: const Key('banner_view_all_button'),
                  onPressed: () =>
                      setState(() => _isBacklogDrawerOpen = true),
                  child: const Text('View All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAlertModal(
    BuildContext context,
    DesktopScheduleController ctrl,
    NotificationEventOut alert,
    CompanionThemeExtension? ext,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrgent = ctrl.isUrgentAlert(alert);
    final isTaskReminder = ctrl.isTaskReminderAlert(alert);
    final accentColor = isUrgent
        ? (ext?.danger ?? CompanionColors.danger)
        : (ext?.accent ?? CompanionColors.lightAccent);
    final modalCount =
        ctrl.activeAlerts.where((e) => ctrl.usesCenterPopup(e)).length;
    final triggeredLocal = parseServerUtcDateTime(alert.triggeredAt);
    final headerLabel = switch (alert.sourceType) {
      'alarm' => 'ALARM RINGING',
      'task_reminder' => 'TASK REMINDER',
      _ => 'REMINDER DUE',
    };

    return Container(
      color: Colors.black.withValues(alpha: isDark ? 0.56 : 0.34),
      padding: const EdgeInsets.all(CompanionSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SoftGlassPanel(
            key: const Key('shell_center_alert_modal'),
            padding: const EdgeInsets.all(CompanionSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        borderRadius: CompanionRadius.borderMd,
                      ),
                      child: Icon(
                        isUrgent
                            ? Icons.alarm_on_rounded
                            : Icons.notifications_active_rounded,
                        size: 24,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: CompanionSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            modalCount > 1
                                ? '$headerLabel (+${modalCount - 1} more)'
                                : headerLabel,
                            style: CompanionTypography.caption.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert.title,
                            style: CompanionTypography.titleMedium.copyWith(
                              color: ext?.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (triggeredLocal != null) ...[
                  const SizedBox(height: CompanionSpacing.sm),
                  Text(
                    formatDateTime12h(triggeredLocal),
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.textMuted,
                    ),
                  ),
                ],
                if (alert.body != null && alert.body!.trim().isNotEmpty) ...[
                  const SizedBox(height: CompanionSpacing.sm),
                  Text(
                    alert.body!,
                    style: CompanionTypography.bodyMedium.copyWith(
                      color: ext?.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: CompanionSpacing.lg),
                Wrap(
                  spacing: CompanionSpacing.sm,
                  runSpacing: CompanionSpacing.sm,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('center_alert_view_all_button'),
                      onPressed: () =>
                          setState(() => _isBacklogDrawerOpen = true),
                      child: const Text('View All'),
                    ),
                    TextButton(
                      key: const Key('center_alert_dismiss_button'),
                      onPressed: ctrl.isMutating
                          ? null
                          : () => ctrl.dismissNotification(alert.id),
                      child: const Text('Dismiss'),
                    ),
                    OutlinedButton(
                      key: const Key('center_alert_snooze_button'),
                      onPressed: ctrl.isMutating
                          ? null
                          : () => ctrl.snoozeNotification(alert.id),
                      child: const Text('Snooze 10m'),
                    ),
                    FilledButton(
                      key: const Key('center_alert_primary_button'),
                      style: isUrgent
                          ? FilledButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                            )
                          : null,
                      onPressed: ctrl.isMutating
                          ? null
                          : () => ctrl.acknowledgeNotification(
                                alert.id,
                                completeTask: isTaskReminder,
                              ),
                      child: Text(ctrl.primaryActionLabel(alert)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
