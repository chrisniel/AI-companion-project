import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/shell/desktop_shell.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_lifecycle_test.dart';

void main() {
  void setupDesktopViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Desktop Shell Keyboard Shortcuts', () {
    testWidgets('Ctrl+, navigates directly to Settings screen', (tester) async {
      setupDesktopViewport(tester);

      final controller = DesktopSettingsController(
        initialDestination: DesktopNavDestination.chat,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(controller: controller),
        ),
      );

      expect(controller.currentDestination, equals(DesktopNavDestination.chat));

      // Trigger Ctrl+,
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.currentDestination, equals(DesktopNavDestination.settings));
      expect(find.text('Appearance & Theme'), findsOneWidget);
    });

    testWidgets('Escape hides to tray when system tray is active', (tester) async {
      setupDesktopViewport(tester);

      final windowAdapter = FakeDesktopWindowAdapter();
      final trayAdapter = FakeDesktopTrayAdapter();
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: trayAdapter,
      );
      await coordinator.initialize();

      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(
            controller: controller,
            coordinator: coordinator,
          ),
        ),
      );

      expect(windowAdapter.visible, isTrue);

      // Trigger Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(windowAdapter.visible, isFalse);
      expect(windowAdapter.hideCallCount, equals(1));
    });

    testWidgets('Escape does not hide window when system tray is unavailable', (tester) async {
      setupDesktopViewport(tester);

      final windowAdapter = FakeDesktopWindowAdapter();
      final failingTray = FailingDesktopTrayAdapter();
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: failingTray,
      );
      await coordinator.initialize();
      expect(coordinator.isTrayAvailable, isFalse);

      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(
            controller: controller,
            coordinator: coordinator,
          ),
        ),
      );

      expect(windowAdapter.visible, isTrue);

      // Trigger Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Window should still be visible because tray is unavailable
      expect(windowAdapter.visible, isTrue);
      expect(windowAdapter.hideCallCount, equals(0));
    });
  });
}
