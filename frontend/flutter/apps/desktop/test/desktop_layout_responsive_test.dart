import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/diagnostics/windows_storage_diagnostic_reader.dart';
import 'package:ai_companion_desktop/shell/desktop_shell.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Desktop Layout Responsive Verification', () {
    void setupViewport(WidgetTester tester, Size size) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    Widget createTestApp({
      required DesktopSettingsController controller,
      ThemeMode mode = ThemeMode.dark,
      double textScaleFactor = 1.0,
    }) {
      return MaterialApp(
        theme: CompanionTheme.light(),
        darkTheme: CompanionTheme.dark(),
        themeMode: mode,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScaleFactor),
            ),
            child: child!,
          );
        },
        home: DesktopShell(controller: controller),
      );
    }

    testWidgets('Chat screen renders without overflow at default 1280x800 with expanded rail', (tester) async {
      setupViewport(tester, const Size(1280, 800));
      final controller = DesktopSettingsController();

      await tester.pumpWidget(createTestApp(controller: controller));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Conversational workspace'), findsOneWidget);
      expect(find.text('AI Companion Desktop'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Chat screen renders without overflow at minimum 1024x640 with expanded rail', (tester) async {
      setupViewport(tester, const Size(1024, 640));
      final controller = DesktopSettingsController();

      await tester.pumpWidget(createTestApp(controller: controller));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Conversational workspace'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Chat screen renders without overflow at minimum 1024x640 with collapsed rail', (tester) async {
      setupViewport(tester, const Size(1024, 640));
      final controller = DesktopSettingsController();
      controller.toggleRailCollapsed();

      await tester.pumpWidget(createTestApp(controller: controller));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.isRailCollapsed, isTrue);
      expect(find.text('Chat'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Settings appearance controls render cleanly at 1280x800 and 1024x640', (tester) async {
      for (final size in const [Size(1280, 800), Size(1024, 640)]) {
        setupViewport(tester, size);
        final controller = DesktopSettingsController();

        await tester.pumpWidget(createTestApp(controller: controller));
        await tester.pumpAndSettle();

        // Switch to Settings
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Appearance & Theme'), findsOneWidget);
        expect(find.text('Color Mode'), findsOneWidget);
        expect(find.text('Accent Color Preset'), findsOneWidget);

        // Verify all 5 accent chips are present and interactive
        for (final preset in AccentPreset.values) {
          expect(find.text(preset.label), findsOneWidget);
        }
      }
    });

    testWidgets('Settings diagnostics card renders cleanly at 1280x800 and 1024x640', (tester) async {
      for (final size in const [Size(1280, 800), Size(1024, 640)]) {
        setupViewport(tester, size);
        final mockReader = WindowsStorageDiagnosticReader(
          localAppDataOverride: r'C:\Users\Test\AppData\Local',
          appInstallDirOverride: r'C:\Program Files\AI Companion',
          fileExistsChecker: (path) => false,
          directoryExistsChecker: (path) => true,
        );
        final controller = DesktopSettingsController(diagnosticReader: mockReader);

        await tester.pumpWidget(createTestApp(controller: controller));
        await tester.pumpAndSettle();

        // Switch to Settings
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Storage Diagnostics'), findsOneWidget);
        expect(find.text('Client Fail-Closed Inspection'), findsOneWidget);
        expect(find.text('Bootstrap Locator'), findsOneWidget);
        expect(find.text('Default Storage Root (DATA)'), findsOneWidget);
        expect(find.text('Application Install (APP_INSTALL)'), findsOneWidget);
        expect(find.text('Model & Library Root (LIBRARY)'), findsOneWidget);
        expect(find.text('Not reported by backend'), findsWidgets);
      }
    });

    testWidgets('Minimum 1024x640 viewport handles text scaling (1.2x and 1.3x) without overflow', (tester) async {
      for (final scale in [1.2, 1.3]) {
        setupViewport(tester, const Size(1024, 640));
        final controller = DesktopSettingsController();

        await tester.pumpWidget(createTestApp(
          controller: controller,
          textScaleFactor: scale,
        ));
        await tester.pumpAndSettle();

        // 1. Chat screen with scaled text
        expect(tester.takeException(), isNull);
        expect(find.text('Chat'), findsWidgets);

        // 2. Settings screen with scaled text
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Appearance & Theme'), findsOneWidget);
        expect(find.text('Storage Diagnostics'), findsOneWidget);
        expect(find.text('Window & Tray Lifecycle'), findsOneWidget);
      }
    });
  });
}
