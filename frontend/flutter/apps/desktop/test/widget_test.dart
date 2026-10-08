import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_lifecycle_test.dart';

void main() {
  testWidgets('renders AI Companion desktop Batch 2 foundation screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AiCompanionDesktopApp());

    expect(find.text('AI Companion'), findsOneWidget);
    expect(find.text('Windows Window & Tray Lifecycle (M1 Batch 2)'), findsOneWidget);
    expect(find.textContaining('Window Constraints: 1280x800'), findsOneWidget);
    expect(find.textContaining('Close Intercept: Hides to System Tray'), findsOneWidget);
    expect(find.text('Hide to Tray'), findsOneWidget);
    expect(find.text('Exit Companion'), findsOneWidget);
  });

  testWidgets('routes UI action buttons through DesktopLifecycleCoordinator', (WidgetTester tester) async {
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
}
