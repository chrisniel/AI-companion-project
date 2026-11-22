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
    expect(find.text('Voice'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Runtime: Standalone (Unconnected)'), findsWidgets);
  });

  testWidgets('routes lifecycle actions through DesktopNavigationRail power menu and General Settings shows tray status', (tester) async {
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

    // No duplicate lifecycle action buttons inside Settings
    expect(find.text('Hide to Tray'), findsNothing);
    expect(find.text('Exit Companion'), findsNothing);

    // Navigate to General & Lifecycle via Rail power menu item
    await tester.tap(find.byKey(const Key('rail_power_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close & Startup Settings...'));
    await tester.pumpAndSettle();
    expect(find.text('System Tray: Active (Close-to-Tray Active)'), findsOneWidget);

    // Tap "Minimize to System Tray" from Rail power menu
    await tester.tap(find.byKey(const Key('rail_power_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minimize to System Tray'));
    await tester.pumpAndSettle();
    expect(windowAdapter.visible, isFalse);
    expect(windowAdapter.hideCallCount, equals(1));

    // Tap "Exit Companion" from Rail power menu
    await tester.tap(find.byKey(const Key('rail_power_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit Companion'));
    await tester.pumpAndSettle();
    expect(find.text('Exit AI Companion?'), findsOneWidget);

    // Confirm in dialog
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Exit Companion'),
    ));
    await tester.pumpAndSettle();

    expect(exitHandled, isTrue);
    expect(windowAdapter.isDestroyed, isTrue);
  });

  testWidgets('disables Minimize to System Tray in Rail power menu when tray is unavailable', (tester) async {
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

    // Check General & Lifecycle section reports tray unavailability without duplicate buttons
    await tester.tap(find.byKey(const Key('settings_nav_general')));
    await tester.pumpAndSettle();
    expect(find.text('System Tray: Unavailable (Close Exits App)'), findsOneWidget);
    expect(find.text('Hide to Tray'), findsNothing);
    expect(find.text('Exit Companion'), findsNothing);

    // Verify Minimize to System Tray is disabled in Rail power menu
    await tester.tap(find.byKey(const Key('rail_power_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minimize to System Tray'));
    await tester.pump();
    // Menu stays open because item was disabled
    expect(find.text('Exit Companion'), findsOneWidget);

    // Tap Exit Companion (remains enabled)
    await tester.tap(find.text('Exit Companion'));
    await tester.pumpAndSettle();
    expect(find.text('Exit AI Companion?'), findsOneWidget);

    // Confirm in dialog
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Exit Companion'),
    ));
    await tester.pumpAndSettle();

    expect(exitHandled, isTrue);
  });
}
