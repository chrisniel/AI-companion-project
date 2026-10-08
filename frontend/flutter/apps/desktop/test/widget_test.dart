import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_lifecycle_test.dart';

void main() {
  testWidgets('renders AI Companion desktop Batch 2 foundation screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AiCompanionDesktopApp());

    expect(find.text('AI Companion'), findsOneWidget);
    expect(find.text('Windows Window & Tray Lifecycle (M1 Batch 2)'), findsOneWidget);
    expect(find.textContaining('Window Constraints: 1280x800'), findsOneWidget);
    expect(find.text('Hide to Tray'), findsOneWidget);
    expect(find.text('Exit Companion'), findsOneWidget);
  });

  testWidgets('routes UI action buttons through DesktopLifecycleCoordinator when tray is active', (WidgetTester tester) async {
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

    await tester.pumpWidget(AiCompanionDesktopApp(coordinator: coordinator));

    expect(find.text('System Tray: Active (Close-to-Tray Active)'), findsOneWidget);

    // Tap "Hide to Tray"
    await tester.tap(find.text('Hide to Tray'));
    await tester.pump();
    expect(windowAdapter.visible, isFalse);
    expect(windowAdapter.hideCallCount, equals(1));

    // Tap "Exit Companion"
    await tester.tap(find.text('Exit Companion'));
    await tester.pump();
    expect(exitHandled, isTrue);
    expect(windowAdapter.isDestroyed, isTrue);
  });

  testWidgets('disables Hide to Tray button when tray is unavailable', (WidgetTester tester) async {
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

    await tester.pumpWidget(AiCompanionDesktopApp(coordinator: coordinator));

    expect(find.text('System Tray: Unavailable (Close Exits App)'), findsOneWidget);

    // Verify Hide to Tray button is disabled
    final hideButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Hide to Tray'),
    );
    expect(hideButton.onPressed, isNull);

    // Tap Exit Companion (should remain enabled)
    await tester.tap(find.text('Exit Companion'));
    await tester.pump();
    expect(exitHandled, isTrue);
  });
}
