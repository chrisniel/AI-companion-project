import 'package:tray_manager/tray_manager.dart';

/// Abstract contract for system tray operations.
abstract class DesktopTrayAdapter {
  /// Sets the system tray icon from an asset or filesystem path.
  Future<void> setIcon(String path);

  /// Sets the hover tooltip for the system tray icon.
  Future<void> setToolTip(String toolTip);

  /// Configures the right-click context menu.
  Future<void> setContextMenu(Menu menu);

  /// Removes the system tray icon and releases native resources.
  Future<void> destroy();

  /// Subscribes a listener for tray interaction events.
  void addListener(TrayListener listener);

  /// Unsubscribes a listener for tray interaction events.
  void removeListener(TrayListener listener);
}
