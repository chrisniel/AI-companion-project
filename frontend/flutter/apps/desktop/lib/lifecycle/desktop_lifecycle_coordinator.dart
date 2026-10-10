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

  bool _isInitialized = false;
  bool _isWindowVisible = false;
  bool _isTrayAvailable = false;
  bool _isDisposed = false;

  bool get isInitialized => _isInitialized;
  bool get isWindowVisible => _isWindowVisible;
  bool get isTrayAvailable => _isTrayAvailable;
  bool get isDisposed => _isDisposed;

  /// Initializes window constraints, close interception, and system tray.
  Future<void> initialize({
    bool showImmediately = true,
    Size? initialWindowSize,
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

    if (showImmediately && !_isDisposed) {
      await restoreAndFocusWindow();
    }

    _isInitialized = true;
  }

  RuntimeProcessState? _runtimeProcessState;
  RuntimeProcessState? get runtimeProcessState => _runtimeProcessState;

  /// Updates the runtime process state and dynamically refreshes the system tray menu.
  Future<void> updateRuntimeStatus(RuntimeProcessState state) async {
    _runtimeProcessState = state;
    if (_isTrayAvailable && !_isDisposed) {
      try {
        await trayAdapter.setContextMenu(buildTrayContextMenu(state));
      } catch (e) {
        debugPrint('DesktopLifecycleCoordinator: Error updating tray context menu: $e');
      }
    }
  }

  /// Builds the tray context menu items reflecting runtime supervision state.
  List<MenuItem> buildTrayMenuItems([
    RuntimeProcessState? state,
    bool? includeDevTestActions,
  ]) {
    final runtime = state ?? _runtimeProcessState;
    final allowDevActions = includeDevTestActions ?? kDebugMode;
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
        label: 'Exit Companion (Full Shutdown - Planned PC-HOST-005)',
        disabled: true,
      ),
    ]);

    return items;
  }

  /// Builds the tray context menu with truthful supervision actions and disabled future actions.
  Menu buildTrayContextMenu([
    RuntimeProcessState? state,
    bool? includeDevTestActions,
  ]) {
    return Menu(items: buildTrayMenuItems(state, includeDevTestActions));
  }


  /// Restores the window from hidden/minimized state and requests focus.
  Future<void> restoreAndFocusWindow() async {
    if (_isDisposed) return;
    await windowAdapter.show();
    await windowAdapter.focus();
    _isWindowVisible = true;
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
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (_isDisposed) return;
    if (menuItem.key == 'open') {
      restoreAndFocusWindow();
    } else if (menuItem.key == 'hide_to_tray') {
      hideToTray();
    } else if (menuItem.key == 'quit_ui_dev' || menuItem.key == 'exit') {
      handleExitRequested();
    }
  }

}
