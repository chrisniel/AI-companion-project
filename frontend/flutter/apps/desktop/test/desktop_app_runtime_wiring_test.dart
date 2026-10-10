import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/coordinator/desktop_runtime_coordinator.dart';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_tray_adapter.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_window_adapter.dart';
import 'package:ai_companion_desktop/main.dart';
import 'package:ai_companion_desktop/platform/desktop_client_settings.dart';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class MockWindowAdapter implements DesktopWindowAdapter {
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
  Future<void> destroy() async {}
  @override
  void addListener(WindowListener listener) {}
  @override
  void removeListener(WindowListener listener) {}
}

class MockTrayAdapter implements DesktopTrayAdapter {
  Menu? lastMenu;
  @override
  Future<void> setIcon(String path) async {}
  @override
  Future<void> setToolTip(String tip) async {}
  @override
  Future<void> setContextMenu(Menu menu) async {
    lastMenu = menu;
  }
  @override
  Future<void> destroy() async {}
  @override
  void addListener(TrayListener listener) {}
  @override
  void removeListener(TrayListener listener) {}
}

class FakeChatClient extends CompanionClient {
  int healthCallCount = 0;
  FakeChatClient({super.baseUrl = 'http://127.0.0.1:8000'})
      : super(credentialStore: InMemoryCredentialStore('test-token'));

  @override
  Future<HealthResponse> getHealth({Duration timeout = const Duration(seconds: 3)}) async {
    healthCallCount++;
    return const HealthResponse(status: 'healthy');
  }

  @override
  Future<AuthVerifyResponse> verifyAuth({Duration timeout = const Duration(seconds: 5)}) async {
    return const AuthVerifyResponse(
      authenticated: true,
      tokenType: 'Bearer',
      message: 'Token verified',
    );
  }

  @override
  Future<ModelStatusResponse> getModelStatus() async {
    return const ModelStatusResponse(
      provider: 'llama.cpp',
      activeModel: 'qwen2.5-7b',
      modelLoaded: true,
      runtimeState: 'MODEL_READY',
    );
  }

  @override
  Future<ConversationListOut> listConversations({int skip = 0, int limit = 50}) async {
    return const ConversationListOut(items: [], total: 0);
  }
}

class FakeProcessSupervisor extends WindowsRuntimeProcessSupervisor {
  bool listening = true;
  @override
  Future<bool> isPortListening(String host, int port, {Duration timeout = const Duration(milliseconds: 500)}) async {
    return listening;
  }
  @override
  Future<RuntimeLockfileData?> readDescriptorDirect(File lockFile) async {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setupDesktopViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Desktop App Runtime Wiring', () {
    late Directory tempSettingsDir;
    late File tempSettingsFile;
    late DesktopClientSettings isolatedSettings;
    late InMemoryCredentialStore isolatedCredentialStore;

    DateTime? prodSettingsModBefore;
    DateTime? prodCredsModBefore;
    int? prodSettingsLenBefore;
    int? prodCredsLenBefore;

    setUp(() {
      tempSettingsDir = Directory.systemTemp.createTempSync('companion_wiring_test_');
      tempSettingsFile = File('${tempSettingsDir.path}${Platform.pathSeparator}client_settings.json');
      isolatedSettings = DesktopClientSettings(customFilePath: tempSettingsFile.path);
      isolatedCredentialStore = InMemoryCredentialStore('test-token');

      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        final prodSettings = File('$localAppData\\AI Companion\\client_settings.json');
        if (prodSettings.existsSync()) {
          prodSettingsModBefore = prodSettings.lastModifiedSync();
          prodSettingsLenBefore = prodSettings.lengthSync();
        }
        final prodCreds = File('$localAppData\\AI Companion\\credentials.bin');
        if (prodCreds.existsSync()) {
          prodCredsModBefore = prodCreds.lastModifiedSync();
          prodCredsLenBefore = prodCreds.lengthSync();
        }
      }
    });

    tearDown(() {
      if (tempSettingsDir.existsSync()) {
        try {
          tempSettingsDir.deleteSync(recursive: true);
        } catch (_) {}
      }

      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        final prodSettings = File('$localAppData\\AI Companion\\client_settings.json');
        if (prodSettingsModBefore != null && prodSettings.existsSync()) {
          expect(prodSettings.lastModifiedSync(), equals(prodSettingsModBefore),
              reason: 'Production client_settings.json must not be modified by tests');
          expect(prodSettings.lengthSync(), equals(prodSettingsLenBefore));
        }
        final prodCreds = File('$localAppData\\AI Companion\\credentials.bin');
        if (prodCredsModBefore != null && prodCreds.existsSync()) {
          expect(prodCreds.lastModifiedSync(), equals(prodCredsModBefore),
              reason: 'Production credentials.bin must not be modified by tests');
          expect(prodCreds.lengthSync(), equals(prodCredsLenBefore));
        }
      }
    });

    testWidgets('AiCompanionDesktopApp wires runtime coordinator to settings and lifecycle coordinators', (tester) async {
      setupDesktopViewport(tester);

      final windowAdapter = MockWindowAdapter();
      final trayAdapter = MockTrayAdapter();
      final lifecycleCoordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: trayAdapter,
      );
      await lifecycleCoordinator.initialize();

      final settingsController = DesktopSettingsController();
      final fakeClient = FakeChatClient();
      final chatController = DesktopChatController(client: fakeClient);
      final fakeSupervisor = FakeProcessSupervisor();

      final runtimeCoordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: fakeClient,
      );

      await tester.pumpWidget(
        AiCompanionDesktopApp(
          coordinator: lifecycleCoordinator,
          settingsController: settingsController,
          chatController: chatController,
          runtimeCoordinator: runtimeCoordinator,
          clientSettings: isolatedSettings,
          credentialStore: isolatedCredentialStore,
        ),
      );
      await tester.pumpAndSettle();

      expect(runtimeCoordinator.currentState.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(settingsController.runtimeProcessState?.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(lifecycleCoordinator.runtimeProcessState?.status, equals(RuntimeStatus.readyAndAuthenticated));

      final statusItem = trayAdapter.lastMenu?.items?.firstWhere((i) => i.key == 'status');
      expect(statusItem?.label, contains('Active'));

      expect(fakeClient.healthCallCount, greaterThan(0));

      runtimeCoordinator.dispose();
      await lifecycleCoordinator.dispose();
    });

    testWidgets('SettingsScreen Apply & Save reconfigures runtime coordinator and re-runs readiness', (tester) async {
      setupDesktopViewport(tester);

      final settingsController = DesktopSettingsController(
        initialDestination: DesktopNavDestination.settings,
      );
      final fakeClient = FakeChatClient();
      final chatController = DesktopChatController(client: fakeClient);
      final fakeSupervisor = FakeProcessSupervisor();

      final runtimeCoordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:8000',
        supervisor: fakeSupervisor,
        client: fakeClient,
      );

      await tester.pumpWidget(
        AiCompanionDesktopApp(
          settingsController: settingsController,
          chatController: chatController,
          runtimeCoordinator: runtimeCoordinator,
          clientSettings: isolatedSettings,
          credentialStore: isolatedCredentialStore,
        ),
      );
      await tester.pumpAndSettle();

      final urlFinder = find.byType(TextField).first;
      expect(urlFinder, findsOneWidget);

      await tester.enterText(urlFinder, 'http://127.0.0.1:8765');
      await tester.pump();

      // Drag settings scrollable up to bring Apply & Save into view
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final saveFinder = find.widgetWithText(NeumorphicButton, 'Apply & Save');
      expect(saveFinder, findsOneWidget);

      await tester.ensureVisible(saveFinder);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(saveFinder);
        for (int i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (runtimeCoordinator.baseUrl == 'http://127.0.0.1:8765' &&
              settingsController.runtimeProcessState?.port == 8765) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pumpAndSettle();

      expect(runtimeCoordinator.baseUrl, equals('http://127.0.0.1:8765'));
      expect(settingsController.runtimeProcessState?.port, equals(8765));

      // Verify that isolated file was written and not real AppData
      expect(tempSettingsFile.existsSync(), isTrue);
      final savedContent = jsonDecode(tempSettingsFile.readAsStringSync()) as Map<String, dynamic>;
      expect(savedContent['hostUrl'], equals('http://127.0.0.1:8765'));

      runtimeCoordinator.dispose();
    });
  });
}
