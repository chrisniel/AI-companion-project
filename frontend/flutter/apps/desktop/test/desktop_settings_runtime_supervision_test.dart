import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/diagnostics/windows_storage_diagnostic_reader.dart';
import 'package:ai_companion_desktop/screens/settings_screen.dart';
import 'package:companion_core/companion_core.dart';
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

  group('DesktopSettingsRuntimeSupervision', () {
    testWidgets('displays runtime supervision card with mode, status, and PID', (tester) async {
      setupDesktopViewport(tester);

      final controller = DesktopSettingsController(
        diagnosticReader: WindowsStorageDiagnosticReader(
          localAppDataOverride: r'C:\Mock\AppData\Local',
          fileExistsChecker: (path) => false,
          directoryExistsChecker: (path) => false,
        ),
      );

      controller.updateRuntimeState(
        const RuntimeProcessState(
          supervisionMode: SupervisionMode.localLoopback,
          status: RuntimeStatus.readyAndAuthenticated,
          pid: 4321,
          port: 8000,
        ),

        RuntimeLockfileData(
          schemaVersion: 1,
          instanceId: 'inst-1234',
          pid: 4321,
          port: 8000,
          startedAt: DateTime.utc(2026, 10, 11, 10, 0, 0),
          executablePath: r'C:\Python\python.exe',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SettingsScreen(controller: controller),
          ),
        ),
      );

      expect(find.text('Runtime Process Supervision'), findsOneWidget);
      expect(find.textContaining('Local Loopback'), findsOneWidget);
      expect(find.textContaining('4321'), findsOneWidget);
      expect(find.text('Bound Port'), findsOneWidget);
      expect(find.text('8000'), findsOneWidget);

    });
  });
}
