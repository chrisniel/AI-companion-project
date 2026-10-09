import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_window_adapter.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_tray_adapter.dart';

class FakeDesktopWindowAdapter implements DesktopWindowAdapter {
  Size? size;
  Size? minimumSize;
  String? title;
  bool isCentered = false;
  bool preventClose = false;
  bool visible = false;
  bool focused = false;
  bool isDestroyed = false;
  int showCallCount = 0;
  int hideCallCount = 0;
  WindowOptions? capturedOptions;
  final List<WindowListener> listeners = [];

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> setSize(Size newSize) async {
    size = newSize;
  }

  @override
  Future<void> setMinimumSize(Size newMinimumSize) async {
    minimumSize = newMinimumSize;
  }

  @override
  Future<void> center() async {
    isCentered = true;
  }

  @override
  Future<void> setTitle(String newTitle) async {
    title = newTitle;
  }

  @override
  Future<void> waitUntilReadyToShow([
    WindowOptions? options,
    VoidCallback? callback,
  ]) async {
    capturedOptions = options;
    if (options?.size != null) size = options!.size;
    if (options?.minimumSize != null) minimumSize = options!.minimumSize;
    if (options?.center == true) isCentered = true;
    if (options?.title != null) title = options!.title;
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
  Future<void> show() async {
    visible = true;
    showCallCount++;
  }

  @override
  Future<void> hide() async {
    visible = false;
    hideCallCount++;
  }

  @override
  Future<void> focus() async {
    focused = true;
  }

  @override
  Future<void> destroy() async {
    isDestroyed = true;
  }

  @override
  void addListener(WindowListener listener) {
    listeners.add(listener);
  }

  @override
  void removeListener(WindowListener listener) {
    listeners.remove(listener);
  }
}

class FakeDesktopTrayAdapter implements DesktopTrayAdapter {
  String? iconPath;
  String? toolTip;
  Menu? contextMenu;
  bool isDestroyed = false;
  final List<TrayListener> listeners = [];

  @override
  Future<void> setIcon(String path) async {
    iconPath = path;
  }

  @override
  Future<void> setToolTip(String tip) async {
    toolTip = tip;
  }

  @override
  Future<void> setContextMenu(Menu menu) async {
    contextMenu = menu;
  }

  @override
  Future<void> destroy() async {
    isDestroyed = true;
  }

  @override
  void addListener(TrayListener listener) {
    listeners.add(listener);
  }

  @override
  void removeListener(TrayListener listener) {
    listeners.remove(listener);
  }
}

class FailingDesktopTrayAdapter implements DesktopTrayAdapter {
  @override
  Future<void> setIcon(String path) async {
    throw Exception('Tray unavailable on host platform');
  }

  @override
  Future<void> setToolTip(String tip) async {
    throw Exception('Tray unavailable on host platform');
  }

  @override
  Future<void> setContextMenu(Menu menu) async {
    throw Exception('Tray unavailable on host platform');
  }

  @override
  Future<void> destroy() async {}

  @override
  void addListener(TrayListener listener) {}

  @override
  void removeListener(TrayListener listener) {}
}

void main() {
  group('DesktopLifecycleCoordinator', () {
    late FakeDesktopWindowAdapter windowAdapter;
    late FakeDesktopTrayAdapter trayAdapter;
    late DesktopLifecycleCoordinator coordinator;
    late bool exitRequested;

    setUp(() {
      windowAdapter = FakeDesktopWindowAdapter();
      trayAdapter = FakeDesktopTrayAdapter();
      exitRequested = false;

      coordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: trayAdapter,
        onExitRequested: () async {
          exitRequested = true;
        },
      );
    });

    tearDown(() async {
      await coordinator.dispose();
    });

    test('initializes window with 1280x800 default, 1024x640 minimum, centered, preventClose true', () async {
      await coordinator.initialize();

      expect(windowAdapter.size, const Size(1280, 800));
      expect(windowAdapter.minimumSize, const Size(1024, 640));
      expect(windowAdapter.title, DesktopLifecycleCoordinator.defaultWindowTitle);
      expect(windowAdapter.capturedOptions?.title, DesktopLifecycleCoordinator.defaultWindowTitle);
      expect(windowAdapter.capturedOptions?.size, const Size(1280, 800));
      expect(windowAdapter.capturedOptions?.minimumSize, const Size(1024, 640));
      expect(windowAdapter.capturedOptions?.center, isTrue);
      expect(windowAdapter.isCentered, isTrue);
      expect(windowAdapter.preventClose, isTrue);
      expect(windowAdapter.visible, isTrue);
      expect(windowAdapter.focused, isTrue);
      expect(coordinator.isWindowVisible, isTrue);
    });

    test('initializes window with custom initial size when specified', () async {
      await coordinator.initialize(initialWindowSize: const Size(1024, 640));

      expect(windowAdapter.size, const Size(1024, 640));
      expect(windowAdapter.capturedOptions?.size, const Size(1024, 640));
      expect(windowAdapter.title, DesktopLifecycleCoordinator.defaultWindowTitle);
    });

    test('initializes system tray with icon, tooltip, and required menu actions', () async {
      await coordinator.initialize();

      expect(trayAdapter.iconPath, DesktopLifecycleCoordinator.defaultTrayIconPath);
      expect(trayAdapter.toolTip, 'AI Companion');
      expect(trayAdapter.contextMenu, isNotNull);

      final items = trayAdapter.contextMenu!.items;
      expect(items, isNotNull);
      expect(items!.any((item) => item.key == 'open' && item.label == 'Open AI Companion'), isTrue);
      expect(items.any((item) => item.key == 'status' && item.disabled), isTrue);
      expect(items.any((item) => item.key == 'stop' && item.disabled), isTrue);
      expect(items.any((item) => item.key == 'exit' && item.label == 'Exit Companion'), isTrue);
    });

    test('intercepts window close and hides to tray without process destruction', () async {
      await coordinator.initialize();

      coordinator.onWindowClose();
      // Allow async handlers to run
      await pumpEventQueue();

      expect(windowAdapter.visible, isFalse);
      expect(windowAdapter.hideCallCount, equals(1));
      expect(windowAdapter.isDestroyed, isFalse);
      expect(coordinator.isWindowVisible, isFalse);
    });

    test('restores and focuses window via tray icon click', () async {
      await coordinator.initialize();
      coordinator.onWindowClose();
      await pumpEventQueue();
      expect(coordinator.isWindowVisible, isFalse);

      coordinator.onTrayIconMouseDown();
      await pumpEventQueue();

      expect(windowAdapter.visible, isTrue);
      expect(windowAdapter.focused, isTrue);
      expect(windowAdapter.showCallCount, equals(2)); // initial show + restore
      expect(coordinator.isWindowVisible, isTrue);
    });

    test('routes tray context menu actions accurately', () async {
      await coordinator.initialize();
      coordinator.onWindowClose();
      await pumpEventQueue();

      // Click "open"
      final openItem = MenuItem(key: 'open', label: 'Open AI Companion');
      coordinator.onTrayMenuItemClick(openItem);
      await pumpEventQueue();
      expect(coordinator.isWindowVisible, isTrue);

      // Click "exit"
      final exitItem = MenuItem(key: 'exit', label: 'Exit Companion');
      coordinator.onTrayMenuItemClick(exitItem);
      await pumpEventQueue();
      expect(exitRequested, isTrue);
    });

    test('handles repeated close and show cycles predictably', () async {
      await coordinator.initialize();

      for (var i = 1; i <= 3; i++) {
        coordinator.onWindowClose();
        await pumpEventQueue();
        expect(coordinator.isWindowVisible, isFalse);
        expect(windowAdapter.hideCallCount, equals(i));

        coordinator.onTrayIconMouseDown();
        await pumpEventQueue();
        expect(coordinator.isWindowVisible, isTrue);
        expect(windowAdapter.showCallCount, equals(i + 1));
      }
    });

    test('cleans up window and tray listeners during controlled shutdown', () async {
      await coordinator.initialize();
      expect(windowAdapter.listeners.contains(coordinator), isTrue);
      expect(trayAdapter.listeners.contains(coordinator), isTrue);

      await coordinator.handleExitRequested();

      expect(windowAdapter.listeners.contains(coordinator), isFalse);
      expect(trayAdapter.listeners.contains(coordinator), isFalse);
      expect(trayAdapter.isDestroyed, isTrue);
      expect(windowAdapter.isDestroyed, isTrue);
      expect(exitRequested, isTrue);
    });

    test('gracefully falls back when tray adapter encounters platform failure', () async {
      final failingTray = FailingDesktopTrayAdapter();
      final robustCoordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: failingTray,
      );

      // Should not throw
      await robustCoordinator.initialize();

      expect(windowAdapter.visible, isTrue);
      expect(robustCoordinator.isTrayAvailable, isFalse);
      expect(robustCoordinator.isWindowVisible, isTrue);

      await robustCoordinator.dispose();
    });

    test('when tray is unavailable, onWindowClose does not hide window and triggers graceful exit', () async {
      var exitTriggered = false;
      final failingTray = FailingDesktopTrayAdapter();
      final robustCoordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: failingTray,
        onExitRequested: () async {
          exitTriggered = true;
        },
      );

      await robustCoordinator.initialize();
      expect(windowAdapter.visible, isTrue);

      robustCoordinator.onWindowClose();
      await pumpEventQueue();

      // Window must NOT have been hidden into an unrecoverable state
      expect(windowAdapter.hideCallCount, equals(0));
      expect(exitTriggered, isTrue);

      await robustCoordinator.dispose();
    });

    test('when tray is unavailable, hideToTray returns false and does not hide window', () async {
      final failingTray = FailingDesktopTrayAdapter();
      final robustCoordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: failingTray,
      );

      await robustCoordinator.initialize();
      expect(windowAdapter.visible, isTrue);

      final didHide = await robustCoordinator.hideToTray();

      expect(didHide, isFalse);
      expect(windowAdapter.hideCallCount, equals(0));
      expect(robustCoordinator.isWindowVisible, isTrue);

      await robustCoordinator.dispose();
    });

    test('partially initialized tray cleans up resources and avoids orphaned tray icon', () async {
      final partialTray = PartialFailureTrayAdapter();
      final robustCoordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: partialTray,
      );

      await robustCoordinator.initialize();

      expect(robustCoordinator.isTrayAvailable, isFalse);
      expect(partialTray.isDestroyed, isTrue);
      expect(partialTray.listeners.contains(robustCoordinator), isFalse);

      await robustCoordinator.dispose();
    });

    test('disposed coordinator ignores subsequent window and tray events', () async {
      await coordinator.initialize();
      await coordinator.handleExitRequested();

      expect(coordinator.isDisposed, isTrue);
      final initialHideCount = windowAdapter.hideCallCount;
      final initialShowCount = windowAdapter.showCallCount;

      // Dispatch events to disposed coordinator
      coordinator.onWindowClose();
      coordinator.onTrayIconMouseDown();
      coordinator.onTrayMenuItemClick(MenuItem(key: 'open', label: 'Open'));
      await pumpEventQueue();

      expect(windowAdapter.hideCallCount, equals(initialHideCount));
      expect(windowAdapter.showCallCount, equals(initialShowCount));
    });
  });
}

class PartialFailureTrayAdapter implements DesktopTrayAdapter {
  String? iconPath;
  bool isDestroyed = false;
  final List<TrayListener> listeners = [];

  @override
  Future<void> setIcon(String path) async {
    iconPath = path;
  }

  @override
  Future<void> setToolTip(String tip) async {
    throw Exception('Failed setting tooltip on host platform');
  }

  @override
  Future<void> setContextMenu(Menu menu) async {
    throw Exception('Failed setting context menu');
  }

  @override
  Future<void> destroy() async {
    isDestroyed = true;
    iconPath = null;
  }

  @override
  void addListener(TrayListener listener) {
    listeners.add(listener);
  }

  @override
  void removeListener(TrayListener listener) {
    listeners.remove(listener);
  }
}
