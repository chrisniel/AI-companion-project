import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/diagnostics/windows_storage_diagnostic_reader.dart';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/profiles/desktop_profile_controller.dart';
import 'package:ai_companion_desktop/features/settings/settings_section.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/platform/desktop_client_settings.dart';
import 'package:ai_companion_desktop/screens/settings_screen.dart';
import 'package:ai_companion_desktop/shell/desktop_navigation_rail.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_lifecycle_test.dart';

void main() {
  void setupViewport(WidgetTester tester, [Size size = const Size(1280, 800)]) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('SettingsSection catalog & search filtering', () {
    test('exposes Web-aligned available and truthful planned sections', () {
      final ids = kSettingsSections.map((s) => s.id).toSet();
      expect(
        ids,
        containsAll(<SettingsSectionId>{
          SettingsSectionId.appearance,
          SettingsSectionId.general,
          SettingsSectionId.notifications,
          SettingsSectionId.profiles,
          SettingsSectionId.runtime,
          SettingsSectionId.storage,
          SettingsSectionId.voice,
          SettingsSectionId.tools,
          SettingsSectionId.health,
          SettingsSectionId.network,
        }),
      );

      final voice = kSettingsSections.firstWhere((s) => s.id == SettingsSectionId.voice);
      expect(voice.status, equals(SettingsSectionStatus.available));
      expect(voice.milestoneHint, isNull);

      final tools = kSettingsSections.firstWhere((s) => s.id == SettingsSectionId.tools);
      expect(tools.status, equals(SettingsSectionStatus.available));
      expect(tools.milestoneHint, isNull);

      final perf = kSettingsSections.firstWhere((s) => s.id == SettingsSectionId.health);
      expect(perf.label, equals('Performance & Gaming'));
      expect(perf.status, equals(SettingsSectionStatus.available));
      expect(perf.milestoneHint, isNull);

      final general = kSettingsSections.firstWhere((s) => s.id == SettingsSectionId.general);
      expect(general.status, equals(SettingsSectionStatus.available));
    });

    test('filterSettingsSections matches labels, descriptions, and keywords case-insensitively', () {
      expect(filterSettingsSections('').length, equals(kSettingsSections.length));
      expect(filterSettingsSections('   ').length, equals(kSettingsSections.length));

      final dpapiMatches = filterSettingsSections('dpapi');
      expect(dpapiMatches.map((s) => s.id), contains(SettingsSectionId.runtime));

      final quietMatches = filterSettingsSections('QUIET');
      expect(quietMatches.map((s) => s.id), contains(SettingsSectionId.notifications));

      final d9Matches = filterSettingsSections('kill switch');
      expect(d9Matches.map((s) => s.id), contains(SettingsSectionId.tools));

      expect(filterSettingsSections('nonexistent-xyz-term'), isEmpty);
    });
  });

  group('DesktopSettingsController section state', () {
    test('defaults to appearance and maps initialScrollToDiagnostics to storage', () {
      final defaultCtrl = DesktopSettingsController();
      expect(defaultCtrl.selectedSettingsSection, equals(SettingsSectionId.appearance));

      final diagCtrl = DesktopSettingsController(initialScrollToDiagnostics: true);
      expect(diagCtrl.selectedSettingsSection, equals(SettingsSectionId.storage));
    });

    test('setSettingsSection, setScrollToDiagnostics, and openSettingsSection notify listeners', () {
      final ctrl = DesktopSettingsController(initialDestination: DesktopNavDestination.chat);
      var notifications = 0;
      ctrl.addListener(() => notifications++);

      ctrl.setSettingsSection(SettingsSectionId.notifications);
      expect(ctrl.selectedSettingsSection, equals(SettingsSectionId.notifications));
      expect(ctrl.currentDestination, equals(DesktopNavDestination.chat));
      expect(notifications, equals(1));

      ctrl.setScrollToDiagnostics(true);
      expect(ctrl.selectedSettingsSection, equals(SettingsSectionId.storage));
      expect(notifications, equals(2));

      ctrl.openSettingsSection(SettingsSectionId.general);
      expect(ctrl.currentDestination, equals(DesktopNavDestination.settings));
      expect(ctrl.selectedSettingsSection, equals(SettingsSectionId.general));
      expect(notifications, equals(3));
    });

    test('requestOpenSettingsSection respects navigationGuard', () async {
      final ctrl = DesktopSettingsController(
        initialDestination: DesktopNavDestination.studio,
        initialSettingsSection: SettingsSectionId.appearance,
      );
      var guardInvocations = 0;
      ctrl.navigationGuard = (from, to) async {
        guardInvocations++;
        expect(from, equals(DesktopNavDestination.studio));
        expect(to, equals(DesktopNavDestination.settings));
        return false;
      };

      final blocked = await ctrl.requestOpenSettingsSection(SettingsSectionId.general);
      expect(blocked, isFalse);
      expect(guardInvocations, equals(1));
      expect(ctrl.currentDestination, equals(DesktopNavDestination.studio));
      expect(ctrl.selectedSettingsSection, equals(SettingsSectionId.appearance));

      ctrl.navigationGuard = (_, __) async => true;
      final allowed = await ctrl.requestOpenSettingsSection(SettingsSectionId.general);
      expect(allowed, isTrue);
      expect(ctrl.currentDestination, equals(DesktopNavDestination.settings));
      expect(ctrl.selectedSettingsSection, equals(SettingsSectionId.general));
    });
  });

  group('DesktopNavigationRail power menu', () {
    testWidgets('renders power menu button in expanded and collapsed states without overflow at 1024x640 1.3x', (tester) async {
      for (final collapsed in [false, true]) {
        setupViewport(tester, const Size(1024, 640));
        final controller = DesktopSettingsController(initialRailCollapsed: collapsed);

        await tester.pumpWidget(
          MaterialApp(
            theme: CompanionTheme.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: Row(
                  children: [
                    DesktopNavigationRail(controller: controller),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('rail_power_menu_button')), findsOneWidget);
      }
    });

    testWidgets('power menu triggers Minimize to System Tray, Close & Startup Settings, and Exit Companion', (tester) async {
      setupViewport(tester);
      final windowAdapter = FakeDesktopWindowAdapter();
      final trayAdapter = FakeDesktopTrayAdapter();
      var exitCalls = 0;

      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: trayAdapter,
        onExitRequested: () async {},
      );
      await coordinator.initialize();

      final controller = DesktopSettingsController(
        initialDestination: DesktopNavDestination.chat,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: Row(
              children: [
                DesktopNavigationRail(
                  controller: controller,
                  coordinator: coordinator,
                  onExitRequested: () => exitCalls++,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open menu & Minimize to System Tray
      await tester.tap(find.byKey(const Key('rail_power_menu_button')));
      await tester.pumpAndSettle();
      expect(find.text('Minimize to System Tray'), findsOneWidget);
      expect(find.text('Close & Startup Settings...'), findsOneWidget);
      expect(find.text('Exit Companion'), findsOneWidget);

      await tester.tap(find.text('Minimize to System Tray'));
      await tester.pumpAndSettle();
      expect(windowAdapter.hideCallCount, equals(1));

      // 2. Open menu & Close & Startup Settings...
      await tester.tap(find.byKey(const Key('rail_power_menu_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close & Startup Settings...'));
      await tester.pumpAndSettle();
      expect(controller.currentDestination, equals(DesktopNavDestination.settings));
      expect(controller.selectedSettingsSection, equals(SettingsSectionId.general));

      // 3. Open menu & Exit Companion
      await tester.tap(find.byKey(const Key('rail_power_menu_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit Companion'));
      await tester.pumpAndSettle();
      expect(exitCalls, equals(1));
    });

    testWidgets('power menu disables Minimize to System Tray when tray is unavailable', (tester) async {
      setupViewport(tester);
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: FakeDesktopWindowAdapter(),
        trayAdapter: FailingDesktopTrayAdapter(),
        onExitRequested: () async {},
      );
      await coordinator.initialize();
      expect(coordinator.isTrayAvailable, isFalse);

      var exitCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: Row(
              children: [
                DesktopNavigationRail(
                  controller: DesktopSettingsController(),
                  coordinator: coordinator,
                  onExitRequested: () => exitCalls++,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rail_power_menu_button')));
      await tester.pumpAndSettle();

      // Tapping disabled Minimize to System Tray should not close menu or hide
      await tester.tap(find.text('Minimize to System Tray'));
      await tester.pump();
      expect(find.text('Exit Companion'), findsOneWidget);

      // Exit Companion remains enabled
      await tester.tap(find.text('Exit Companion'));
      await tester.pumpAndSettle();
      expect(exitCalls, equals(1));
    });
  });

  group('Revamped SettingsScreen two-column workspace', () {
    testWidgets('omits Hide to Tray and Exit Companion buttons inside Settings and switches sections standalone', (tester) async {
      setupViewport(tester);
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

      // Zero duplicate lifecycle action buttons inside Settings
      expect(find.text('Hide to Tray'), findsNothing);
      expect(find.text('Exit Companion'), findsNothing);

      // Default tab is Appearance
      expect(find.text('Appearance & Theme'), findsOneWidget);
      expect(find.byKey(const Key('settings_search_input')), findsOneWidget);

      // Tap Voice & Audio (Available M4 Batch C; standalone fallback without controller)
      await tester.tap(find.byKey(const Key('settings_nav_voice')));
      await tester.pumpAndSettle();
      expect(controller.selectedSettingsSection, equals(SettingsSectionId.voice));
      expect(find.text('Voice & Audio'), findsWidgets);
      expect(find.textContaining('Connect to the Local AI Runtime'), findsOneWidget);

      // Tap Tools & Safety (Available M4 Batch A; standalone fallback without controller)
      await tester.tap(find.byKey(const Key('settings_nav_tools')));
      await tester.pumpAndSettle();
      expect(controller.selectedSettingsSection, equals(SettingsSectionId.tools));
      expect(find.textContaining('Tools & Safety Controls'), findsOneWidget);

      // Tap Notifications & Profiles without wired controllers shows clean fallback
      await tester.tap(find.byKey(const Key('settings_nav_notifications')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Schedule service unavailable'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_nav_profiles')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Profile management unavailable'), findsOneWidget);
    });

    testWidgets('search filters sidebar while keeping active pane rendered and supports clear reset', (tester) async {
      setupViewport(tester);
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

      // Filter by 'dpapi' -> shows AI Runtime & Models
      await tester.enterText(find.byKey(const Key('settings_search_input')), 'dpapi');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings_nav_runtime')), findsOneWidget);
      expect(find.byKey(const Key('settings_nav_voice')), findsNothing);
      // Right active pane remains Appearance until switched
      expect(find.text('Appearance & Theme'), findsOneWidget);

      // Unmatched query -> empty sidebar state + Clear button + active pane preserved
      await tester.enterText(find.byKey(const Key('settings_search_input')), 'zzzz-no-match');
      await tester.pumpAndSettle();
      expect(find.text('No matching settings categories'), findsOneWidget);
      expect(find.text('Appearance & Theme'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_search_clear_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings_nav_voice')), findsOneWidget);
    });

    testWidgets('preserves unsaved Runtime URL edits when switching tabs and honors scrollToDiagnostics', (tester) async {
      setupViewport(tester);
      final mockReader = WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Mock\AppData\Local',
        fileExistsChecker: (_) => false,
        directoryExistsChecker: (_) => false,
      );
      final controller = DesktopSettingsController(
        initialScrollToDiagnostics: true,
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

      // initialScrollToDiagnostics opens Storage & Diagnostics immediately
      expect(controller.selectedSettingsSection, equals(SettingsSectionId.storage));
      expect(find.text('Storage Diagnostics'), findsOneWidget);

      // Switch to Runtime, enter custom URL
      await tester.tap(find.byKey(const Key('settings_nav_runtime')));
      await tester.pumpAndSettle();
      final urlField = find.byKey(const Key('runtime_host_url_input'));
      expect(urlField, findsOneWidget);
      await tester.enterText(urlField, 'http://127.0.0.1:9123');
      await tester.pump();

      // Switch away to General and back to Runtime
      await tester.tap(find.byKey(const Key('settings_nav_general')));
      await tester.pumpAndSettle();
      expect(find.text('Window & Tray Lifecycle'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_nav_runtime')));
      await tester.pumpAndSettle();
      final textFieldWidget = tester.widget<TextField>(urlField);
      expect(textFieldWidget.controller?.text, equals('http://127.0.0.1:9123'));
    });

    testWidgets('adapts cleanly to compact width (< 720px) without overflow', (tester) async {
      setupViewport(tester, const Size(640, 640));
      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: Scaffold(
              body: SettingsScreen(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('settings_search_input')), findsOneWidget);
      expect(find.byKey(const Key('settings_nav_general')), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings_nav_general')));
      await tester.pumpAndSettle();
      expect(find.text('Window & Tray Lifecycle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('caches storage diagnostic reads across search rebuilds', (tester) async {
      setupViewport(tester);
      final reader = _CountingStorageDiagnosticReader();
      final controller = DesktopSettingsController(diagnosticReader: reader);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SettingsScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reader.readCount, equals(1));

      await tester.enterText(find.byKey(const Key('settings_search_input')), 'storage');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_nav_storage')));
      await tester.pumpAndSettle();

      expect(reader.readCount, equals(1));
    });

    testWidgets('refreshes model data on intra-Settings runtime tab switch and preserves cleared dirty token', (tester) async {
      setupViewport(tester);
      final fakeClient = _FakeRuntimeRefreshClient();
      final controller = DesktopSettingsController(
        initialDestination: DesktopNavDestination.settings,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SettingsScreen(
              controller: controller,
              client: fakeClient,
              clientSettings: _InMemoryDesktopClientSettings(),
              credentialStore: InMemoryCredentialStore('saved-secret-token'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialCalls = fakeClient.registryCalls;
      expect(initialCalls, greaterThanOrEqualTo(1));

      // Enter Runtime tab -> triggers refresh
      await tester.tap(find.byKey(const Key('settings_nav_runtime')));
      await tester.pumpAndSettle();
      expect(fakeClient.registryCalls, equals(initialCalls + 1));

      // Expand Advanced diagnostics when connected before accessing pairing token field
      final advToggle = find.byKey(const Key('runtime_advanced_toggle'));
      await tester.ensureVisible(advToggle);
      await tester.tap(advToggle);
      await tester.pumpAndSettle();

      // Clear pairing token (marks dirty), switch away and back -> cleared token is not overwritten
      final tokenField = find.byKey(const Key('runtime_pairing_token_input'));
      await tester.enterText(tokenField, '');
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings_nav_appearance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_nav_runtime')));
      await tester.pumpAndSettle();

      expect(fakeClient.registryCalls, equals(initialCalls + 2));
      expect(tester.widget<TextField>(tokenField).controller?.text, isEmpty);
    });

    testWidgets('ProfileAccessCard deleted profiles wrap cleanly at 1024x640 with 1.3x text scale', (tester) async {
      setupViewport(tester, const Size(1024, 640));
      final chatController = DesktopChatController(
        client: CompanionClient(credentialStore: InMemoryCredentialStore('t')),
      );
      final profileController = DesktopProfileController(chat: chatController)
        ..deletedProfiles = [
          <String, dynamic>{
            'id': 'deleted-1',
            'name': 'Archived Work Workspace Profile With Very Long Name',
            'purge_after': DateTime.now().toUtc().add(const Duration(days: 14)).toIso8601String(),
          },
        ];
      addTearDown(() {
        profileController.dispose();
        chatController.dispose();
      });

      final controller = DesktopSettingsController(
        initialDestination: DesktopNavDestination.settings,
        initialSettingsSection: SettingsSectionId.profiles,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SettingsScreen(
                controller: controller,
                profileController: profileController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Permanently Delete'), findsOneWidget);
    });
  });
}

class _CountingStorageDiagnosticReader implements StorageDiagnosticReader {
  int readCount = 0;

  @override
  Future<List<StorageDiagnosticInfo>> readDiagnosticRoots() async {
    readCount++;
    return const [
      StorageDiagnosticInfo(
        rootType: StorageRootType.data,
        locatorStatus: LocatorStatus.absent,
        source: StorageRootSource.localDiagnostic,
        resolvedPath: r'C:\Mock\AppData\Local\AI Companion',
        details: 'Mocked diagnostic root',
      ),
    ];
  }
}

class _FakeRuntimeRefreshClient extends CompanionClient {
  int registryCalls = 0;

  _FakeRuntimeRefreshClient()
      : super(credentialStore: InMemoryCredentialStore('saved-secret-token'));

  @override
  Future<List<ModelRegistryEntry>> getModelRegistry() async {
    registryCalls++;
    return const [];
  }

  @override
  Future<ModelStatusResponse> getModelStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return const ModelStatusResponse(provider: 'llama.cpp');
  }
}

class _InMemoryDesktopClientSettings extends DesktopClientSettings {
  String _hostUrl = 'http://127.0.0.1:8000';
  String? _selectedModel;

  @override
  Future<String> readHostUrl({
    String defaultValue = 'http://127.0.0.1:8000',
  }) async =>
      _hostUrl;

  @override
  Future<void> writeHostUrl(String hostUrl) async {
    _hostUrl = hostUrl;
  }

  @override
  Future<String?> readSelectedModel() async => _selectedModel;

  @override
  Future<void> writeSelectedModel(String? modelId) async {
    _selectedModel = modelId;
  }
}
