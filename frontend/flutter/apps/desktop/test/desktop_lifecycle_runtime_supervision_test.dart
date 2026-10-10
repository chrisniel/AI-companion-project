import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_tray_adapter.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_window_adapter.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class MockWindowAdapter implements DesktopWindowAdapter {
  bool visible = true;
  bool isDestroyed = false;
  bool preventClose = true;
  final List<WindowListener> listeners = [];

  @override
  Future<void> ensureInitialized() async {}
  @override
  Future<void> setSize(Size newSize) async {}
  @override
  Future<void> setMinimumSize(Size newMinimumSize) async {}
  @override
  Future<void> center() async {}
  @override
  Future<void> setTitle(String newTitle) async {}
  @override
  Future<void> waitUntilReadyToShow([WindowOptions? options, VoidCallback? callback]) async {
    callback?.call();
  }
  @override
  Future<void> setPreventClose(bool isPrevent) async {
    preventClose = isPrevent;
  }
  @override
  Future<bool> isPreventClose() async => preventClose;
  @override
  Future<bool> isVisible() async => visible;
  @override
  Future<void> show() async { visible = true; }
  @override
  Future<void> hide() async { visible = false; }
  @override
  Future<void> focus() async {}
  @override
  Future<void> destroy() async { isDestroyed = true; }
  @override
  void addListener(WindowListener listener) { listeners.add(listener); }
  @override
  void removeListener(WindowListener listener) { listeners.remove(listener); }
}

class MockTrayAdapter implements DesktopTrayAdapter {
  Menu? contextMenu;
  bool isDestroyed = false;
  final List<TrayListener> listeners = [];

  @override
  Future<void> setIcon(String path) async {}
  @override
  Future<void> setToolTip(String tip) async {}
  @override
  Future<void> setContextMenu(Menu menu) async {
    contextMenu = menu;
  }
  @override
  Future<void> destroy() async { isDestroyed = true; }
  @override
  void addListener(TrayListener listener) { listeners.add(listener); }
  @override
  void removeListener(TrayListener listener) { listeners.remove(listener); }
}

void main() {
  group('DesktopLifecycleRuntimeSupervision', () {
    test('closing window to tray hides UI while leaving runtime process untouched', () async {
      final window = MockWindowAdapter();
      final tray = MockTrayAdapter();
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: window,
        trayAdapter: tray,
      );
      await coordinator.initialize();

      expect(coordinator.isWindowVisible, isTrue);
      final didHide = await coordinator.hideToTray();
      expect(didHide, isTrue);
      expect(coordinator.isWindowVisible, isFalse);
      expect(window.visible, isFalse);
      expect(window.isDestroyed, isFalse);
    });

    test('quit UI only destroys UI resources without process termination', () async {
      final window = MockWindowAdapter();
      final tray = MockTrayAdapter();
      bool exitInvoked = false;
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: window,
        trayAdapter: tray,
        onExitRequested: () async {
          exitInvoked = true;
        },
      );
      await coordinator.initialize();

      await coordinator.handleExitRequested();
      expect(window.isDestroyed, isTrue);
      expect(tray.isDestroyed, isTrue);
      expect(exitInvoked, isTrue);
    });

    test('buildTrayMenuItems keeps exit_full disabled with PC-HOST-005 planned label', () {
      final window = MockWindowAdapter();
      final tray = MockTrayAdapter();
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: window,
        trayAdapter: tray,
      );

      final items = coordinator.buildTrayMenuItems(
        const RuntimeProcessState(
          supervisionMode: SupervisionMode.localLoopback,
          status: RuntimeStatus.readyAndAuthenticated,
          pid: 1234,
          port: 8000,
        ),
      );

      final exitFullItem = items.firstWhere((i) => i.key == 'exit_full');
      expect(exitFullItem.disabled, isTrue);
      expect(exitFullItem.label, contains('PC-HOST-005'));
    });

    test('buildTrayMenuItems updates status label dynamically across runtime states', () {
      final window = MockWindowAdapter();
      final tray = MockTrayAdapter();
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: window,
        trayAdapter: tray,
      );

      final itemsReady = coordinator.buildTrayMenuItems(
        const RuntimeProcessState(
          supervisionMode: SupervisionMode.localLoopback,
          status: RuntimeStatus.readyAndAuthenticated,
          pid: 5678,
          port: 8000,
        ),
      );
      final statusItemReady = itemsReady.firstWhere((i) => i.key == 'status');
      expect(statusItemReady.label, contains('5678'));

      final itemsConflict = coordinator.buildTrayMenuItems(
        const RuntimeProcessState(
          supervisionMode: SupervisionMode.localLoopback,
          status: RuntimeStatus.alienPortConflict,
          port: 8000,
        ),
      );

      final statusItemConflict = itemsConflict.firstWhere((i) => i.key == 'status');
      expect(statusItemConflict.label, contains('Conflict'));
    });
  });
}
