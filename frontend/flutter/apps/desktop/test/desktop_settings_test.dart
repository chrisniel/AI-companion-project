import 'dart:io';

import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/diagnostics/windows_storage_diagnostic_reader.dart';
import 'package:ai_companion_desktop/platform/desktop_client_settings.dart';
import 'package:ai_companion_desktop/screens/settings_screen.dart';
import 'package:companion_api/companion_api.dart';
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

    testWidgets('renders model selection card with capability badges and triggers selection', (tester) async {
      setupDesktopViewport(tester);

      final tempDir = Directory.systemTemp.createTempSync('settings_test_');
      final tempSettingsFile = File('${tempDir.path}${Platform.pathSeparator}client_settings.json');
      final isolatedSettings = DesktopClientSettings(customFilePath: tempSettingsFile.path);
      final isolatedCredentials = InMemoryCredentialStore('test-token');
      addTearDown(() {
        if (tempDir.existsSync()) {
          try {
            tempDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      });

      final fakeClient = FakeModelSelectionClient();
      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SettingsScreen(
              controller: controller,
              client: fakeClient,
              clientSettings: isolatedSettings,
              credentialStore: isolatedCredentials,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Local LLM Model Selection'), findsOneWidget);
      expect(find.text('Qwen3-VL 2B Instruct'), findsOneWidget);
      expect(find.text('Qwen3-VL 4B Instruct'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Text-Only (Companion Missing)'), findsOneWidget);
      expect(find.text('Vision'), findsWidgets);

      // Tap select on the second model
      final selectButtons = find.widgetWithText(OutlinedButton, 'Select');
      expect(selectButtons, findsWidgets);

      await tester.ensureVisible(selectButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(selectButtons.first);
      await tester.pumpAndSettle();

      expect(fakeClient.selectedModelCalls, greaterThan(0));
    });
  });
}

class FakeModelSelectionClient extends CompanionClient {
  int selectedModelCalls = 0;
  String? lastSelectedModel;

  FakeModelSelectionClient()
      : super(credentialStore: InMemoryCredentialStore('test-token'));

  @override
  Future<List<ModelRegistryEntry>> getModelRegistry() async {
    return const [
      ModelRegistryEntry(
        id: 'qwen3-vl-2b-instruct',
        displayName: 'Qwen3-VL 2B Instruct',
        capabilities: ['chat', 'vision'],
        availableCapabilities: ['chat', 'vision'],
        primaryFile: 'vision/qwen3-vl-2b-instruct/Qwen_Qwen3-VL-2B-Instruct-Q4_K_M.gguf',
        primaryFileExists: true,
        validationStatus: 'verified',
      ),
      ModelRegistryEntry(
        id: 'qwen3-vl-4b-instruct',
        displayName: 'Qwen3-VL 4B Instruct',
        capabilities: ['chat', 'vision'],
        availableCapabilities: ['chat'],
        primaryFile: 'vision/qwen3-vl-4b-instruct/Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf',
        primaryFileExists: true,
        validationStatus: 'missing_companion',
      ),
    ];
  }

  @override
  Future<ModelStatusResponse> getModelStatus() async {
    return const ModelStatusResponse(
      provider: 'llama.cpp',
      runtimeState: 'MODEL_READY',
      activeModel: 'qwen3-vl-2b-instruct',
      selectedModel: 'qwen3-vl-2b-instruct',
    );
  }

  @override
  Future<ModelStatusResponse> selectModel(
    String modelName, {
    bool loadImmediately = false,
    String? profile,
  }) async {
    selectedModelCalls++;
    lastSelectedModel = modelName;
    return ModelStatusResponse(
      provider: 'llama.cpp',
      runtimeState: 'MODEL_READY',
      activeModel: loadImmediately ? modelName : 'qwen3-vl-2b-instruct',
      selectedModel: modelName,
    );
  }

  @override
  Future<ModelStatusResponse> loadModel({String? modelName, String? profile}) async {
    return ModelStatusResponse(
      provider: 'llama.cpp',
      runtimeState: 'MODEL_READY',
      activeModel: modelName ?? 'qwen3-vl-2b-instruct',
      selectedModel: modelName ?? 'qwen3-vl-2b-instruct',
      modelLoaded: true,
    );
  }
}
