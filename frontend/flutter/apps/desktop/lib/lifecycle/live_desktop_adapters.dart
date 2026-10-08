import 'dart:ui';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_tray_adapter.dart';
import 'desktop_window_adapter.dart';

/// Concrete adapter wrapping the real `window_manager` plugin for Windows desktop.
class LiveDesktopWindowAdapter implements DesktopWindowAdapter {
  const LiveDesktopWindowAdapter();

  @override
  Future<void> ensureInitialized() => windowManager.ensureInitialized();

  @override
  Future<void> setSize(Size size) => windowManager.setSize(size);

  @override
  Future<void> setMinimumSize(Size size) => windowManager.setMinimumSize(size);

  @override
  Future<void> center() => windowManager.center();

  @override
  Future<void> setPreventClose(bool isPreventClose) =>
      windowManager.setPreventClose(isPreventClose);

  @override
  Future<bool> isPreventClose() => windowManager.isPreventClose();

  @override
  Future<bool> isVisible() => windowManager.isVisible();

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> focus() => windowManager.focus();

  @override
  Future<void> destroy() => windowManager.destroy();

  @override
  void addListener(WindowListener listener) => windowManager.addListener(listener);

  @override
  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);
}

/// Concrete adapter wrapping the real `tray_manager` plugin for Windows desktop.
class LiveDesktopTrayAdapter implements DesktopTrayAdapter {
  const LiveDesktopTrayAdapter();

  @override
  Future<void> setIcon(String path) => trayManager.setIcon(path);

  @override
  Future<void> setToolTip(String toolTip) => trayManager.setToolTip(toolTip);

  @override
  Future<void> setContextMenu(Menu menu) => trayManager.setContextMenu(menu);

  @override
  Future<void> destroy() => trayManager.destroy();

  @override
  void addListener(TrayListener listener) => trayManager.addListener(listener);

  @override
  void removeListener(TrayListener listener) =>
      trayManager.removeListener(listener);
}
