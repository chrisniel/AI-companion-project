import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/diagnostics/windows_storage_diagnostic_reader.dart';
import 'package:ai_companion_desktop/screens/settings_screen.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void setupDesktopViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('SettingsScreen', () {
    testWidgets('allows changing color mode and accent preset', (tester) async {
      setupDesktopViewport(tester);

      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SettingsScreen(controller: controller),
          ),
        ),
      );

      expect(find.text('Appearance & Theme'), findsOneWidget);
      expect(find.text('Color Mode'), findsOneWidget);
      expect(find.text('Accent Color Preset'), findsOneWidget);

      // Change color mode to Light
      await tester.tap(find.text('Light'));
      await tester.pump();
      expect(controller.themeMode, equals(ThemeMode.light));

      // Change accent preset to Cobalt Indigo
      await tester.tap(find.text('Cobalt Indigo'));
      await tester.pump();
      expect(controller.accentPreset, equals(AccentPreset.cobaltIndigo));
    });

    testWidgets('displays storage diagnostics with truthful provenance and status', (tester) async {
      setupDesktopViewport(tester);

      final mockReader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Mock\AppData\Local',
        fileExistsChecker: (path) => false,
        directoryExistsChecker: (path) => false,
      );

      final controller = DesktopSettingsController(
        diagnosticReader: mockReader,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SettingsScreen(controller: controller),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Storage Diagnostics'), findsOneWidget);
      expect(find.text('Client Fail-Closed Inspection'), findsOneWidget);
      expect(find.text('Bootstrap Locator'), findsOneWidget);
      expect(find.text('Absent (Default OS Path)'), findsWidgets);
    });
  });
}
