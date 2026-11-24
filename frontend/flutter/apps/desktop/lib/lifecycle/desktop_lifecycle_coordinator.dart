import 'dart:async';

import 'package:companion_core/companion_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_tray_adapter.dart';
import 'desktop_window_adapter.dart';

/// Coordinates desktop window and system tray lifecycle for the Windows client.
///
/// Enforces:
/// - Default window dimensions: 1280 x 800.
/// - Minimum window dimensions: 1024 x 640.
/// - Centered window placement.
/// - Close button interception and hide-to-tray when tray is available.
/// - Fallback graceful exit when system tray is unavailable (does not trap user).
/// - System tray context menu routing and window restoration.
/// - Controlled UI exit without affecting independent backend runtime.
class DesktopLifecycleCoordinator with WindowListener, TrayListener {
  DesktopLifecycleCoordinator({
    required this.windowAdapter,
    required this.trayAdapter,
    this.trayIconPath = defaultTrayIconPath,
    this.trayToolTip = defaultTrayToolTip,
    this.onExitRequested,
  });

  static const Size defaultWindowSize = Size(1280, 800);
  static const Size minimumWindowSize = Size(1024, 640);
  static const String defaultWindowTitle = 'AI Companion';
  static const String defaultTrayIconPath = 'assets/icons/tray_icon.ico';
  static const String defaultTrayToolTip = 'AI Companion';

  final DesktopWindowAdapter windowAdapter;
  final DesktopTrayAdapter trayAdapter;
  final String trayIconPath;
  final String trayToolTip;
  final Future<void> Function()? onExitRequested;
  Future<void> Function()? onExitMenuTriggered;
  Future<void> Function()? onKillSwitchTriggered;
  Future<void> Function()? onMuteToggleTriggered;
  Future<void> Function(String mode)? onResourceModeSelected;
  VoidCallback? onWindowRestored;
  bool _globalKillSwitchActive = false;
  bool _audioMuted = false;
  String _resourceRequestedMode = 'normal';
  bool _lowImpactActive = false;

  bool _isInitialized = false;
  bool _isWindowVisible = false;
  bool _isTrayAvailable = false;
  bool _isDisposed = false;
  bool _pendingMaximizeOnFirstShow = false;
  bool _isRestoringWindow = false;

  bool get isInitialized => _isInitialized;
  bool get isWindowVisible => _isWindowVisible;
  bool get isTrayAvailable => _isTrayAvailable;
  bool get isDisposed => _isDisposed;

  /// Initializes window constraints, close interception, and system tray.
  Future<void> initialize({
    bool showImmediately = true,
    Size? initialWindowSize,
    bool maximizeOnStart = false,
  }) async {
    if (_isInitialized || _isDisposed) return;

    await windowAdapter.ensureInitialized();
    await windowAdapter.setPreventClose(true);
    windowAdapter.addListener(this);

    try {
      await trayAdapter.setIcon(trayIconPath);
      await trayAdapter.setToolTip(trayToolTip);
      await trayAdapter.setContextMenu(buildTrayContextMenu());
      trayAdapter.addListener(this);
      _isTrayAvailable = true;
    } catch (e) {
      // Tray may be unsupported or unavailable in headless/virtualized environments.
      _isTrayAvailable = false;
      debugPrint('DesktopLifecycleCoordinator: System tray unavailable: $e');

      // Avoid orphaned native tray resources after partial initialization failure
      try {
        await trayAdapter.destroy();
      } catch (_) {}
      trayAdapter.removeListener(this);
    }

    final windowOptions = WindowOptions(
      size: initialWindowSize ?? defaultWindowSize,
      minimumSize: minimumWindowSize,
      center: true,
      title: defaultWindowTitle,
    );

    await windowAdapter.waitUntilReadyToShow(windowOptions);
    _pendingMaximizeOnFirstShow = maximizeOnStart;

    if (showImmediately && !_isDisposed) {
      await restoreAndFocusWindow();
    } else if (!showImmediately && !_isDisposed) {
      if (_isTrayAvailable) {
        await windowAdapter.hide();
        _isWindowVisible = false;
      } else {
        await restoreAndFocusWindow();
      }
    }

    _isInitialized = true;
  }

  RuntimeProcessState? _runtimeProcessState;
  RuntimeProcessState? get runtimeProcessState => _runtimeProcessState;

  Future<void> _refreshTrayMenuSafe(String errorContext) async {
    if (_isTrayAvailable && !_isDisposed) {
      try {
        await trayAdapter.setContextMenu(
          buildTrayContextMenu(
            _runtimeProcessState,
            null,
            _globalKillSwitchActive,
            _audioMuted,
            _resourceRequestedMode,
            _lowImpactActive,
          ),
        );
      } catch (e) {
        debugPrint('DesktopLifecycleCoordinator: Error updating $errorContext: $e');
      }
    }
  }

  /// Updates the runtime process state and dynamically refreshes the system tray menu.
  Future<void> updateRuntimeStatus(RuntimeProcessState state) async {
    _runtimeProcessState = state;
    await _refreshTrayMenuSafe('tray context menu');
  }

  /// Updates the Global Tool Kill Switch state shown inside the system tray menu.
  Future<void> updateKillSwitchStatus(bool active) async {
    _globalKillSwitchActive = active;
    await _refreshTrayMenuSafe('tray kill switch menu');
  }

  /// Updates the Mute Audio toggle state shown inside the system tray menu.
  Future<void> updateAudioMutedStatus(bool muted) async {
    _audioMuted = muted;
    await _refreshTrayMenuSafe('tray mute menu');
  }

  /// Updates the Performance / Gaming Mode indicator shown in the system tray menu.
  Future<void> updateResourceMode(
    String? requestedMode,
    bool lowImpactActive,
  ) async {
    final normalized = (requestedMode ?? 'normal').trim().toLowerCase();
    _resourceRequestedMode =
        (normalized == 'low_impact' || normalized == 'auto')
            ? normalized
            : 'normal';
    _lowImpactActive = lowImpactActive;
    await _refreshTrayMenuSafe('tray resource mode menu');
  }

  /// Builds the tray context menu items reflecting runtime supervision state.
  List<MenuItem> buildTrayMenuItems([
    RuntimeProcessState? state,
    bool? includeDevTestActions,
  ]) {
    return buildTrayMenuItemsWithSafety(
      state,
      includeDevTestActions,
      _globalKillSwitchActive,
      _audioMuted,
      _resourceRequestedMode,
      _lowImpactActive,
    );
  }

  /// Builds tray context menu items with optional explicit D9 Kill Switch, Mute & Resource Mode state.
  List<MenuItem> buildTrayMenuItemsWithSafety([
    RuntimeProcessState? state,
    bool? includeDevTestActions,
    bool? globalKillSwitchOverride,
    bool isAudioMuted = false,
    String? resourceModeOverride,
    bool? lowImpactActiveOverride,
  ]) {
    final runtime = state ?? _runtimeProcessState;
    final allowDevActions = includeDevTestActions ?? kDebugMode;
    final killSwitch = globalKillSwitchOverride ?? _globalKillSwitchActive;
    final resourceMode = resourceModeOverride ?? _resourceRequestedMode;
    final effectiveLowImpact = lowImpactActiveOverride ?? _lowImpactActive;
    String statusLabel;
    if (runtime == null) {
      statusLabel = 'Runtime: Standalone';
    } else {
      switch (runtime.status) {
        case RuntimeStatus.readyAndAuthenticated:
          if (runtime.isLocalSupervised) {
            statusLabel = 'Runtime: Active (PID ${runtime.pid ?? 'Local'})';
          } else {
            statusLabel = 'Runtime: Remote Host (Active)';
          }
          break;
        case RuntimeStatus.reachableUnauthenticated:
          statusLabel = 'Runtime: Pairing Required';
          break;
        case RuntimeStatus.alienPortConflict:
          statusLabel = 'Runtime: Alien Port Conflict';
          break;
        case RuntimeStatus.processUnresponsive:
          statusLabel = 'Runtime: Unresponsive (PID ${runtime.pid})';
          break;
        case RuntimeStatus.unreachable:
          statusLabel = 'Runtime: Unreachable';
          break;
        case RuntimeStatus.startupTimeout:
          statusLabel = 'Runtime: Startup Timeout';
          break;
        case RuntimeStatus.executableNotFound:
          statusLabel = 'Runtime: Executable Missing';
          break;
        case RuntimeStatus.launching:
          statusLabel = 'Runtime: Launching...';
          break;
        case RuntimeStatus.dormant:
          statusLabel = 'Runtime: Dormant';
          break;
        case RuntimeStatus.shuttingDown:
          statusLabel = 'Runtime: Shutting Down...';
          break;
        case RuntimeStatus.stopped:
          statusLabel = 'Runtime: Stopped';
          break;
        case RuntimeStatus.shutdownFailed:
          statusLabel = 'Runtime: Shutdown Failed';
          break;
      }
    }

    final items = <MenuItem>[
      MenuItem(
        key: 'open',
        label: 'Open AI Companion',
      ),
      MenuItem(
        key: 'status',
        label: statusLabel,
        disabled: true,
      ),
      MenuItem(
        key: 'hide_to_tray',
        label: 'Hide Window to Tray',
      ),
      MenuItem(
        key: 'mute_audio_toggle',
        label: isAudioMuted
            ? 'Unmute Audio (Ctrl+Shift+M)'
            : 'Mute Audio (Ctrl+Shift+M)',
      ),
      MenuItem(
        key: 'kill_switch_toggle',
        label: killSwitch ? 'Tools Killed (Reset in Settings)' : 'Emergency Stop Tools',
        disabled: killSwitch,
      ),
      MenuItem.submenu(
        key: 'performance_mode_menu',
        label: effectiveLowImpact
            ? (resourceMode == 'auto'
                ? 'Performance: Auto Gaming (Low-Impact)'
                : 'Performance: Low-Impact')
            : (resourceMode == 'auto'
                ? 'Performance: Auto Gaming (Normal)'
                : 'Performance: Normal'),
        submenu: Menu(
          items: [
            MenuItem.checkbox(
              key: 'resource_mode_normal',
              label: 'Normal',
              checked: resourceMode == 'normal',
            ),
            MenuItem.checkbox(
              key: 'resource_mode_low_impact',
              label: 'Low-Impact',
              checked: resourceMode == 'low_impact',
            ),
            MenuItem.checkbox(
              key: 'resource_mode_auto',
              label: 'Auto Gaming',
              checked: resourceMode == 'auto',
            ),
          ],
        ),
      ),
    ];

    if (allowDevActions) {
      items.add(
        MenuItem(
          key: 'quit_ui_dev',
          label: 'Close UI Only (Dev Test)',
        ),
      );
    }

    items.addAll([
      MenuItem.separator(),
      MenuItem(
        key: 'exit_full',
        label: 'Exit Companion',
        disabled: false,
      ),
    ]);

    return items;
  }

  /// Builds the tray context menu with truthful supervision actions and disabled future actions.
  Menu buildTrayContextMenu([
    RuntimeProcessState? state,
    bool? includeDevTestActions,
    bool globalKillSwitch = false,
    bool isAudioMuted = false,
    String? resourceModeOverride,
    bool? lowImpactActiveOverride,
  ]) {
    return Menu(
      items: buildTrayMenuItemsWithSafety(
        state,
        includeDevTestActions,
        globalKillSwitch,
        isAudioMuted,
        resourceModeOverride,
        lowImpactActiveOverride,
      ),
    );
  }


  /// Restores the window from hidden/minimized state and requests focus.
  Future<void> restoreAndFocusWindow() async {
    if (_isDisposed || _isRestoringWindow) return;
    _isRestoringWindow = true;
    try {
      final wasHidden = !_isWindowVisible;
      await windowAdapter.show();
      await windowAdapter.focus();
      _isWindowVisible = true;
      if (_pendingMaximizeOnFirstShow && !_isDisposed) {
        _pendingMaximizeOnFirstShow = false;
        await windowAdapter.maximize();
      }
      if (wasHidden && _isInitialized && !_isDisposed) {
        onWindowRestored?.call();
      }
    } finally {
      _isRestoringWindow = false;
    }
  }

  /// Intercepts the window close action and hides to tray.
  ///
  /// Returns `true` if hidden to tray, or `false` if tray is unavailable or coordinator is disposed.
  Future<bool> hideToTray() async {
    if (_isDisposed) return false;
    if (!_isTrayAvailable) {
      // Do not hide the only usable application window when tray is unavailable
      return false;
    }
    await windowAdapter.hide();
    _isWindowVisible = false;
    return true;
  }

  /// Performs controlled shutdown of Flutter UI, tray, and event listeners.
  ///
  /// Note: The independent Python backend process remains untouched.
  Future<void> handleExitRequested() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // 1. Unsubscribe event listeners to prevent event re-entry
    windowAdapter.removeListener(this);
    trayAdapter.removeListener(this);

    // 2. Release close interception so platform window can terminate
    try {
      await windowAdapter.setPreventClose(false);
    } catch (e) {
      debugPrint('DesktopLifecycleCoordinator: Error releasing preventClose: $e');
    }

    // 3. Destroy tray icon to prevent ghost tray icons in taskbar
    if (_isTrayAvailable) {
      try {
        await trayAdapter.destroy();
      } catch (e) {
        debugPrint('DesktopLifecycleCoordinator: Error destroying tray: $e');
      }
    }

    // 4. Destroy native window resources
    try {
      await windowAdapter.destroy();
    } catch (e) {
      debugPrint('DesktopLifecycleCoordinator: Error destroying window: $e');
    }

    // 5. Invoke application exit callback
    if (onExitRequested != null) {
      await onExitRequested!();
    }
  }

  /// Disposes coordinator listeners and resources.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    windowAdapter.removeListener(this);
    trayAdapter.removeListener(this);
  }

  // --- WindowListener Overrides ---

  @override
  void onWindowClose() {
    if (_isDisposed) return;
    if (_isTrayAvailable) {
      hideToTray();
    } else {
      // Fallback: When system tray is unavailable, closing the window triggers
      // graceful exit rather than hiding the only accessible application window.
      handleExitRequested();
    }
  }

  // --- TrayListener Overrides ---

  @override
  void onTrayIconMouseDown() {
    if (_isDisposed) return;
    restoreAndFocusWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    if (_isDisposed || !_isTrayAvailable) return;
    unawaited(trayAdapter.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (_isDisposed) return;
    if (menuItem.key == 'open') {
      restoreAndFocusWindow();
    } else if (menuItem.key == 'hide_to_tray') {
      hideToTray();
    } else if (menuItem.key == 'mute_audio_toggle') {
      if (onMuteToggleTriggered != null) {
        onMuteToggleTriggered!();
      }
    } else if (menuItem.key == 'kill_switch_toggle') {
      if (onKillSwitchTriggered != null) {
        onKillSwitchTriggered!();
      }
    } else if (menuItem.key == 'resource_mode_normal') {
      onResourceModeSelected?.call('normal');
    } else if (menuItem.key == 'resource_mode_low_impact') {
      onResourceModeSelected?.call('low_impact');
    } else if (menuItem.key == 'resource_mode_auto') {
      onResourceModeSelected?.call('auto');
    } else if (menuItem.key == 'quit_ui_dev') {
      handleExitRequested();
    } else if (menuItem.key == 'exit_full' || menuItem.key == 'exit') {
      if (onExitMenuTriggered != null) {
        restoreAndFocusWindow();
        onExitMenuTriggered!();
      } else {
        handleExitRequested();
      }
    }
  }

}
