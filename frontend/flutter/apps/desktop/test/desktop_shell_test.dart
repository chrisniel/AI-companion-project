import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/shell/desktop_shell.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopShell', () {
    void setupDesktopViewport(WidgetTester tester) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('renders navigation rail, brand title, and default Chat destination', (tester) async {
      setupDesktopViewport(tester);

      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(controller: controller),
        ),
      );

      // Verify brand title and rail items
      expect(find.text('AI Companion'), findsWidgets);
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Voice'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Memory'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify truthful runtime status
      expect(find.text('Runtime: Standalone (Unconnected)'), findsWidgets);

      // Verify planned milestone badges
      expect(find.text('M4'), findsOneWidget);
      expect(find.text('M3'), findsNWidgets(3));
    });

    testWidgets('navigates between destinations when clicking rail items', (tester) async {
      setupDesktopViewport(tester);

      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(controller: controller),
        ),
      );

      // Navigate to Voice
      await tester.tap(find.text('Voice'));
      await tester.pumpAndSettle();
      expect(find.text('Voice Interaction'), findsOneWidget);
      expect(find.text('PLANNED MILESTONE M4'), findsOneWidget);

      // Navigate to Schedule
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule & Routines'), findsOneWidget);
      expect(find.text('PLANNED MILESTONE M3'), findsOneWidget);

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Appearance & Theme'), findsOneWidget);
    });

    testWidgets('collapses and expands navigation rail with toggle button', (tester) async {
      setupDesktopViewport(tester);

      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(controller: controller),
        ),
      );

      expect(controller.isRailCollapsed, isFalse);

      // Tap collapse button
      await tester.tap(find.byTooltip('Collapse Navigation'));
      await tester.pumpAndSettle();
      expect(controller.isRailCollapsed, isTrue);

      // In collapsed state, 'Collapse Navigation' becomes 'Expand Navigation'
      await tester.tap(find.byTooltip('Expand Navigation'));
      await tester.pumpAndSettle();
      expect(controller.isRailCollapsed, isFalse);
    });
  });
}
