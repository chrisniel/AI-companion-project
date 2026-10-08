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
/// - Close button interception and hide-to-tray.
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
  Future<void> initialize({bool showImmediately = true}) async {
    if (_isInitialized) return;

    await windowAdapter.ensureInitialized();
    await windowAdapter.setSize(defaultWindowSize);
    await windowAdapter.setMinimumSize(minimumWindowSize);
    await windowAdapter.center();
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
    }

    if (showImmediately) {
      await restoreAndFocusWindow();
    }

    _isInitialized = true;
  }

  /// Builds the tray context menu with M1-supported items and disabled future actions.
  Menu buildTrayContextMenu() {
    return Menu(
      items: [
        MenuItem(
          key: 'open',
          label: 'Open AI Companion',
        ),
        MenuItem(
          key: 'status',
          label: 'Runtime Status: Standalone',
          disabled: true,
        ),
        MenuItem(
          key: 'stop',
          label: 'Stop Runtime (Planned M2)',
          disabled: true,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: 'Exit Companion',
        ),
      ],
    );
  }

  /// Restores the window from hidden/minimized state and requests focus.
  Future<void> restoreAndFocusWindow() async {
    await windowAdapter.show();
    await windowAdapter.focus();
    _isWindowVisible = true;
  }

  /// Intercepts the window close action and hides to tray.
  Future<void> hideToTray() async {
    await windowAdapter.hide();
    _isWindowVisible = false;
  }

  /// Performs controlled shutdown of Flutter UI, tray, and event listeners.
  ///
  /// Note: The independent Python backend process remains untouched.
  Future<void> handleExitRequested() async {
    if (_isDisposed) return;
    _isDisposed = true;

    windowAdapter.removeListener(this);
    trayAdapter.removeListener(this);

    if (_isTrayAvailable) {
      try {
        await trayAdapter.destroy();
      } catch (e) {
        debugPrint('DesktopLifecycleCoordinator: Error destroying tray: $e');
      }
    }

    try {
      await windowAdapter.destroy();
    } catch (e) {
      debugPrint('DesktopLifecycleCoordinator: Error destroying window: $e');
    }

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
    hideToTray();
  }

  // --- TrayListener Overrides ---

  @override
  void onTrayIconMouseDown() {
    restoreAndFocusWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'open') {
      restoreAndFocusWindow();
    } else if (menuItem.key == 'exit') {
      handleExitRequested();
    }
  }
}
