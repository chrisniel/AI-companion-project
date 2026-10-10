import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/main.dart';
import 'package:flutter/material.dart';
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

  testWidgets('renders AI Companion desktop shell with SoftGlass navigation rail and chat screen', (tester) async {
    setupDesktopViewport(tester);

    await tester.pumpWidget(const AiCompanionDesktopApp());

    expect(find.text('AI Companion'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Runtime: Standalone (Unconnected)'), findsWidgets);
  });

  testWidgets('routes UI action buttons through DesktopLifecycleCoordinator on Settings screen when tray is active', (tester) async {
    setupDesktopViewport(tester);

    final windowAdapter = FakeDesktopWindowAdapter();
    final trayAdapter = FakeDesktopTrayAdapter();
    var exitHandled = false;

    final coordinator = DesktopLifecycleCoordinator(
      windowAdapter: windowAdapter,
      trayAdapter: trayAdapter,
      onExitRequested: () async {
        exitHandled = true;
      },
    );

    await coordinator.initialize();

    final controller = DesktopSettingsController(
      initialDestination: DesktopNavDestination.settings,
    );

    await tester.pumpWidget(
      AiCompanionDesktopApp(
        coordinator: coordinator,
        settingsController: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Tray: Active (Close-to-Tray Active)'), findsOneWidget);

    // Tap "Hide to Tray"
    await tester.ensureVisible(find.text('Hide to Tray'));
    await tester.tap(find.text('Hide to Tray'));
    await tester.pump();
    expect(windowAdapter.visible, isFalse);
    expect(windowAdapter.hideCallCount, equals(1));

    // Tap "Exit Companion"
    await tester.ensureVisible(find.text('Exit Companion'));
    await tester.tap(find.text('Exit Companion'));
    await tester.pump();
    expect(exitHandled, isTrue);
    expect(windowAdapter.isDestroyed, isTrue);
  });

  testWidgets('disables Hide to Tray button on Settings screen when tray is unavailable', (tester) async {
    setupDesktopViewport(tester);

    final windowAdapter = FakeDesktopWindowAdapter();
    final failingTray = FailingDesktopTrayAdapter();
    var exitHandled = false;

    final coordinator = DesktopLifecycleCoordinator(
      windowAdapter: windowAdapter,
      trayAdapter: failingTray,
      onExitRequested: () async {
        exitHandled = true;
      },
    );

    await coordinator.initialize();
    expect(coordinator.isTrayAvailable, isFalse);

    final controller = DesktopSettingsController(
      initialDestination: DesktopNavDestination.settings,
    );

    await tester.pumpWidget(
      AiCompanionDesktopApp(
        coordinator: coordinator,
        settingsController: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Tray: Unavailable (Close Exits App)'), findsOneWidget);

    // Verify Hide to Tray button is disabled
    final hideButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Hide to Tray'),
    );
    expect(hideButton.onPressed, isNull);

    // Tap Exit Companion (should remain enabled)
    await tester.ensureVisible(find.text('Exit Companion'));
    await tester.tap(find.text('Exit Companion'));
    await tester.pump();
    expect(exitHandled, isTrue);
  });
}
