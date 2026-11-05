import 'dart:io';

import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/coordinator/desktop_runtime_coordinator.dart';
import 'package:ai_companion_desktop/diagnostics/windows_storage_diagnostic_reader.dart';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_tray_adapter.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_window_adapter.dart';
import 'package:ai_companion_desktop/platform/desktop_client_settings.dart';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:ai_companion_desktop/screens/settings_screen.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

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

    testWidgets('renders Unload Model button when model is loaded and triggers unloadModel', (tester) async {
      setupDesktopViewport(tester);

      final tempDir = Directory.systemTemp.createTempSync('settings_unload_test_');
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

      final unloadButtons = find.widgetWithText(OutlinedButton, 'Unload Model / Free VRAM');
      expect(unloadButtons, findsWidgets);

      await tester.ensureVisible(unloadButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(unloadButtons.first);
      await tester.pumpAndSettle();

      expect(fakeClient.unloadModelCalls, equals(1));
      expect(find.text('Model unloaded successfully.'), findsOneWidget);
      expect(find.textContaining('VRAM released'), findsNothing);
    });

    testWidgets('shows error and does not announce success when unloadModel throws 409 conflict', (tester) async {
      setupDesktopViewport(tester);

      final tempDir = Directory.systemTemp.createTempSync('settings_unload_err_test_');
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
      fakeClient.unloadModelException = const CompanionApiException(
        message: 'MODEL_BUSY: active generation',
        statusCode: 409,
      );
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

      final unloadButtons = find.widgetWithText(OutlinedButton, 'Unload Model / Free VRAM');
      await tester.ensureVisible(unloadButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(unloadButtons.first);
      await tester.pumpAndSettle();

      expect(fakeClient.unloadModelCalls, equals(1));
      expect(find.textContaining('Failed to unload model:'), findsOneWidget);
      expect(find.textContaining('MODEL_BUSY'), findsOneWidget);
      expect(find.textContaining('Model unloaded successfully'), findsNothing);
    });

    testWidgets('does not announce success when unloadModel returns modelLoaded == true', (tester) async {
      setupDesktopViewport(tester);

      final tempDir = Directory.systemTemp.createTempSync('settings_unload_refused_test_');
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
      fakeClient.unloadModelResponseOverride = const ModelStatusResponse(
        provider: 'llama.cpp',
        runtimeState: 'MODEL_READY',
        activeModel: 'qwen3-vl-2b-instruct',
        selectedModel: 'qwen3-vl-2b-instruct',
        modelLoaded: true,
        modelResident: true,
      );
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

      final unloadButtons = find.widgetWithText(OutlinedButton, 'Unload Model / Free VRAM');
      await tester.ensureVisible(unloadButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(unloadButtons.first);
      await tester.pumpAndSettle();

      expect(fakeClient.unloadModelCalls, equals(1));
      expect(find.text('Model unload refused or incomplete: model remains loaded.'), findsOneWidget);
      expect(find.textContaining('Model unloaded successfully'), findsNothing);
    });

    testWidgets('disables Unload Model button when chat generation is active', (tester) async {
      setupDesktopViewport(tester);

      final tempDir = Directory.systemTemp.createTempSync('settings_unload_disabled_test_');
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
      final mockChatController = FakeGeneratingChatController(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SettingsScreen(
              controller: controller,
              client: fakeClient,
              chatController: mockChatController,
              clientSettings: isolatedSettings,
              credentialStore: isolatedCredentials,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final unloadButtons = find.widgetWithText(OutlinedButton, 'Unload Model / Free VRAM');
      expect(unloadButtons, findsWidgets);

      final button = tester.widget<OutlinedButton>(unloadButtons.first);
      expect(button.onPressed, isNull);
    });

    testWidgets('handles STILL_LOADING when selectModel returns MODEL_LOADING and shows Refresh Model Status button', (tester) async {
      setupDesktopViewport(tester);

      final tempDir = Directory.systemTemp.createTempSync('settings_still_loading_test_');
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
      fakeClient.getModelStatusResponseOverride = const ModelStatusResponse(
        provider: 'llama.cpp',
        runtimeState: 'MODEL_UNLOADED',
        activeModel: null,
        selectedModel: 'qwen3-vl-2b-instruct',
        modelLoaded: false,
        modelResident: false,
      );
      fakeClient.selectModelResponseOverride = const ModelStatusResponse(
        provider: 'llama.cpp',
        runtimeState: 'MODEL_LOADING',
        activeModel: null,
        selectedModel: 'qwen3-vl-2b-instruct',
        modelLoaded: false,
      );

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

      final loadButtons = find.widgetWithText(FilledButton, 'Load Model');
      expect(loadButtons, findsWidgets);

      await tester.ensureVisible(loadButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(loadButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fakeClient.selectedModelCalls, equals(1));
      expect(find.textContaining('Model is still loading in the background'), findsOneWidget);
      expect(find.text('Refresh Model Status'), findsOneWidget);

      // Now switch status to MODEL_READY and tap Refresh
      fakeClient.getModelStatusResponseOverride = const ModelStatusResponse(
        provider: 'llama.cpp',
        runtimeState: 'MODEL_READY',
        activeModel: 'qwen3-vl-2b-instruct',
        selectedModel: 'qwen3-vl-2b-instruct',
        modelLoaded: true,
      );

      await tester.tap(find.text('Refresh Model Status'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Model is ready: qwen3-vl-2b-instruct'), findsOneWidget);
    });

    testWidgets('Exit Companion button opens exit confirmation dialog and respects Cancel', (tester) async {
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

      await tester.pumpAndSettle();

      final exitButtons = find.widgetWithText(FilledButton, 'Exit Companion');
      expect(exitButtons, findsOneWidget);

      await tester.ensureVisible(exitButtons);
      await tester.tap(exitButtons);
      await tester.pumpAndSettle();

      expect(find.text('Exit AI Companion?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Exit AI Companion?'), findsNothing);
    });

    testWidgets('failed forceEmergencyStopLocalRuntime preserves SettingsScreen UI and shows error SnackBar', (tester) async {
      setupDesktopViewport(tester);

      final controller = DesktopSettingsController();
      final supervisor = FakeEmergencyFailingSupervisor();
      supervisor.storedDescriptor = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'fail-inst',
        pid: 7788,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\Python\pythonw.exe',
      );
      final client = FakeEmergencyMockClient();
      final runtimeCoordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: supervisor,
        client: client,
      );
      await runtimeCoordinator.ensureRuntimeReady();

      bool exitRequestedCalled = false;
      final lifecycleCoordinator = DesktopLifecycleCoordinator(
        windowAdapter: MockSettingsWindowAdapter(),
        trayAdapter: MockSettingsTrayAdapter(),
        onExitRequested: () async {
          exitRequestedCalled = true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SettingsScreen(
              controller: controller,
              runtimeCoordinator: runtimeCoordinator,
              coordinator: lifecycleCoordinator,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final exitButtons = find.widgetWithText(FilledButton, 'Exit Companion');
      await tester.ensureVisible(exitButtons);
      await tester.tap(exitButtons);
      await tester.pumpAndSettle();

      // Confirm exit
      expect(find.text('Exit AI Companion?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Exit Companion').last);
      await tester.pumpAndSettle();

      // Incomplete shutdown dialog appears due to incomplete_db_quiescence_timeout
      expect(find.text('Incomplete Shutdown'), findsOneWidget);

      // Tap 'Force Stop Local Runtime'
      await tester.tap(find.text('Force Stop Local Runtime'));
      await tester.pumpAndSettle();

      // Emergency termination failed:
      // 1. handleExitRequested must NOT be called
      expect(exitRequestedCalled, isFalse);

      // 2. Error SnackBar must be displayed
      expect(find.textContaining('Emergency stop failed'), findsOneWidget);
      expect(find.textContaining('PowerShell access denied'), findsOneWidget);

      // 3. Settings UI remains rendered
      expect(find.text('Settings'), findsWidgets);
    });
  });
}

class FakeGeneratingChatController extends DesktopChatController {
  FakeGeneratingChatController({required super.client});

  @override
  bool get isGenerating => true;
}

class FakeModelSelectionClient extends CompanionClient {
  int selectedModelCalls = 0;
  int unloadModelCalls = 0;
  int getModelStatusCalls = 0;
  String? lastSelectedModel;
  ModelStatusResponse? getModelStatusResponseOverride;
  ModelStatusResponse? selectModelResponseOverride;

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
  Future<ModelStatusResponse> getModelStatus({Duration timeout = const Duration(seconds: 5)}) async {
    getModelStatusCalls++;
    if (getModelStatusResponseOverride != null) {
      return getModelStatusResponseOverride!;
    }
    return const ModelStatusResponse(
      provider: 'llama.cpp',
      runtimeState: 'MODEL_READY',
      activeModel: 'qwen3-vl-2b-instruct',
      selectedModel: 'qwen3-vl-2b-instruct',
      modelLoaded: true,
      modelResident: true,
    );
  }

  @override
  Future<ModelStatusResponse> selectModel(
    String modelName, {
    bool loadImmediately = false,
    String? profile,
    Duration? timeout,
  }) async {
    selectedModelCalls++;
    lastSelectedModel = modelName;
    if (selectModelResponseOverride != null) {
      return selectModelResponseOverride!;
    }
    return ModelStatusResponse(
      provider: 'llama.cpp',
      runtimeState: 'MODEL_READY',
      activeModel: loadImmediately ? modelName : 'qwen3-vl-2b-instruct',
      selectedModel: modelName,
      modelLoaded: loadImmediately,
    );
  }

  @override
  Future<ModelStatusResponse> loadModel({
    String? modelName,
    String? profile,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    return ModelStatusResponse(
      provider: 'llama.cpp',
      runtimeState: 'MODEL_READY',
      activeModel: modelName ?? 'qwen3-vl-2b-instruct',
      selectedModel: modelName ?? 'qwen3-vl-2b-instruct',
      modelLoaded: true,
    );
  }

  ModelStatusResponse? unloadModelResponseOverride;
  Exception? unloadModelException;

  @override
  Future<ModelStatusResponse> unloadModel({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    unloadModelCalls++;
    if (unloadModelException != null) {
      throw unloadModelException!;
    }
    if (unloadModelResponseOverride != null) {
      return unloadModelResponseOverride!;
    }
    return const ModelStatusResponse(
      provider: 'llama.cpp',
      runtimeState: 'MODEL_UNLOADED',
      activeModel: null,
      selectedModel: 'qwen3-vl-2b-instruct',
      modelLoaded: false,
      modelResident: false,
    );
  }
}

class MockSettingsWindowAdapter implements DesktopWindowAdapter {
  bool isDestroyed = false;
  final List<WindowListener> listeners = [];
  @override
  Future<void> ensureInitialized() async {}
  @override
  Future<void> setSize(Size newSize) async {}
  @override
  Future<void> setMinimumSize(Size newMinimumSize) async {}
  @override
  Future<void> center() async {}
  @override
  Future<void> setTitle(String newTitle) async {}
  @override
  Future<void> waitUntilReadyToShow([WindowOptions? options, VoidCallback? callback]) async {
    callback?.call();
  }
  @override
  Future<void> setPreventClose(bool isPrevent) async {}
  @override
  Future<bool> isPreventClose() async => true;
  @override
  Future<bool> isVisible() async => true;
  @override
  Future<void> show() async {}
  @override
  Future<void> hide() async {}
  @override
  Future<void> focus() async {}
  @override
  Future<void> destroy() async { isDestroyed = true; }
  @override
  void addListener(WindowListener listener) { listeners.add(listener); }
  @override
  void removeListener(WindowListener listener) { listeners.remove(listener); }
}

class MockSettingsTrayAdapter implements DesktopTrayAdapter {
  bool isDestroyed = false;
  final List<TrayListener> listeners = [];
  @override
  Future<void> setIcon(String path) async {}
  @override
  Future<void> setToolTip(String tip) async {}
  @override
  Future<void> setContextMenu(Menu menu) async {}
  @override
  Future<void> destroy() async { isDestroyed = true; }
  @override
  void addListener(TrayListener listener) { listeners.add(listener); }
  @override
  void removeListener(TrayListener listener) { listeners.remove(listener); }
}

class FakeEmergencyFailingSupervisor extends WindowsRuntimeProcessSupervisor {
  RuntimeLockfileData? storedDescriptor;
  @override
  Future<bool> isPortListening(String host, int port, {Duration timeout = const Duration(milliseconds: 500)}) async => true;
  @override
  Future<RuntimeLockfileData?> readDescriptorDirect(File lockFile) async => storedDescriptor;
  @override
  Future<RandomAccessFile?> acquireStartupLock(File lockFile, {Duration timeout = const Duration(seconds: 5)}) async => null;
  @override
  Future<bool> isProcessActiveAndMatching(int pid, {required String expectedExecutable}) async => true;
  @override
  Future<TerminationResult> terminateVerifiedRuntimeProcess({
    required RuntimeLockfileData expectedDescriptor,
    int? managedLlmPid,
    bool managedByCore = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return const TerminationResult(
      status: TerminationResultStatus.inspectionUnavailable,
      diagnostic: 'PowerShell access denied',
    );
  }
}

class FakeEmergencyMockClient extends CompanionClient {
  FakeEmergencyMockClient() : super(credentialStore: InMemoryCredentialStore('token'));
  @override
  Future<HealthResponse> getHealth({Duration timeout = const Duration(seconds: 3)}) async => const HealthResponse(status: 'healthy');
  @override
  Future<AuthVerifyResponse> verifyAuth({Duration timeout = const Duration(seconds: 5)}) async => const AuthVerifyResponse(authenticated: true, tokenType: 'Bearer', message: 'ok');
  @override
  Future<SystemShutdownResponse> shutdownSystem({String reason = 'user_exit_companion', double drainTimeoutSeconds = 6.0, Duration timeout = const Duration(seconds: 5)}) async {
    return const SystemShutdownResponse(status: 'shutting_down', pid: 1234, message: 'shutting down');
  }
  @override
  Future<SystemStatusResponse> getSystemStatus({Duration timeout = const Duration(seconds: 5)}) async {
    return SystemStatusResponse(
      status: 'online',
      platform: 'windows',
      pythonVersion: '3.11.9',
      hostname: 'test-host',
      version: '0.1.0',
      databaseConnected: true,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      shuttingDown: true,
      shutdownPhase: 'drain_persistence',
      shutdownQuiescenceStatus: 'incomplete_db_quiescence_timeout',
    );
  }
}
