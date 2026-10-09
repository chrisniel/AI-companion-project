import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Abstract contract for desktop window operations.
abstract class DesktopWindowAdapter {
  /// Ensures the platform window manager channel is initialized.
  Future<void> ensureInitialized();

  /// Sets the window dimensions.
  Future<void> setSize(Size size);

  /// Sets the minimum allowable window dimensions.
  Future<void> setMinimumSize(Size size);

  /// Centers the window on the active screen.
  Future<void> center();

  /// Changes the title of the native window.
  Future<void> setTitle(String title);

  /// Waits until the native window is ready to show and configures window options.
  Future<void> waitUntilReadyToShow([
    WindowOptions? options,
    VoidCallback? callback,
  ]);

  /// Intercepts native close events instead of automatically destroying the process.
  Future<void> setPreventClose(bool isPreventClose);

  /// Checks if close interception is active.
  Future<bool> isPreventClose();

  /// Checks if the window is currently visible.
  Future<bool> isVisible();

  /// Brings the window into view.
  Future<void> show();

  /// Hides the window without closing the process.
  Future<void> hide();

  /// Requests input focus for the window.
  Future<void> focus();

  /// Disposes native window resources.
  Future<void> destroy();

  /// Subscribes a listener for window lifecycle events.
  void addListener(WindowListener listener);

  /// Unsubscribes a listener for window lifecycle events.
  void removeListener(WindowListener listener);
}
