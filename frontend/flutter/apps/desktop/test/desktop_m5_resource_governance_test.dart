import 'dart:io';

import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/settings/sections/settings_performance_section.dart';
import 'package:ai_companion_desktop/features/settings/settings_section.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/platform/windows_shell_adapter.dart';
import 'package:ai_companion_desktop/shell/desktop_shell.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

import 'desktop_lifecycle_test.dart';

class _FakeResourceGovernanceClient extends CompanionClient {
  _FakeResourceGovernanceClient({ResourcePolicyStatusOut? initialStatus})
      : status = initialStatus ??
            const ResourcePolicyStatusOut(
              requestedMode: 'normal',
              effectiveMode: 'normal',
              lowImpactActive: false,
              lowImpactStrategy: 'cpu_eco',
              lowImpactModelId: null,
              gameProcessList: <String>['valorant.exe'],
              detectedActiveGames: <String>[],
              cooldownSeconds: 45,
              cooldownRemainingSeconds: 0,
              transitionState: 'idle',
              degradationReason: null,
              deferredBackgroundWork: false,
              hostGpuName: null,
              hostVramGb: null,
              hostRamGb: 32.0,
              availableRamGb: 18.4,
              appliedProfile: 'balanced',
              requestedProfile: 'balanced',
              telemetrySource: 'windows_global_memory_status',
            ),
        super(
          baseUrl: 'http://127.0.0.1:8000',
          credentialStore: InMemoryCredentialStore('pair-tok'),
          hostAdminStore: InMemoryCredentialStore('admin-tok'),
        );

  ResourcePolicyStatusOut status;
  int getResourceCalls = 0;
  final List<ResourcePolicyUpdateRequest> updateRequests = <ResourcePolicyUpdateRequest>[];
  String? updateError;
  List<ModelRegistryEntry> registryEntries = const <ModelRegistryEntry>[
    ModelRegistryEntry(
      id: 'qwen3-1.7b-mini',
      displayName: 'Qwen3 1.7B Mini',
      primaryFile: 'qwen3-1.7b-mini.gguf',
      primaryFileExists: true,
      validationStatus: 'verified',
      registrySource: 'installed',
    ),
  ];

  @override
  Future<ResourcePolicyStatusOut> getResourcePolicy({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    getResourceCalls++;
    return status;
  }

  @override
  Future<ResourcePolicyStatusOut> updateResourcePolicy(
    ResourcePolicyUpdateRequest request, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    updateRequests.add(request);
    if (updateError != null) {
      throw CompanionApiException(statusCode: 422, message: updateError!);
    }
    final nextMode = request.resourceMode ?? status.requestedMode;
    final nextStrategy = request.lowImpactStrategy ?? status.lowImpactStrategy;
    final nextGames = request.gameProcessList ?? status.gameProcessList;
    final nextCooldown = request.cooldownSeconds ?? status.cooldownSeconds;
    final nextModel = request.clearLowImpactModel
        ? null
        : (request.lowImpactModelId ?? status.lowImpactModelId);
    final isLow = nextMode == 'low_impact';
    status = ResourcePolicyStatusOut(
      requestedMode: nextMode,
      effectiveMode: isLow ? 'low_impact' : 'normal',
      lowImpactActive: isLow,
      lowImpactStrategy: nextStrategy,
      lowImpactModelId: nextModel,
      gameProcessList: nextGames,
      detectedActiveGames: status.detectedActiveGames,
      cooldownSeconds: nextCooldown,
      cooldownRemainingSeconds: isLow ? 0 : status.cooldownRemainingSeconds,
      transitionState: 'idle',
      degradationReason: status.degradationReason,
      deferredBackgroundWork: isLow,
      hostGpuName: status.hostGpuName,
      hostVramGb: status.hostVramGb,
      hostRamGb: status.hostRamGb,
      availableRamGb: status.availableRamGb,
      appliedProfile: isLow && nextStrategy == 'cpu_eco' ? 'eco' : status.appliedProfile,
      requestedProfile: status.requestedProfile,
      telemetrySource: status.telemetrySource,
    );
    return status;
  }

  @override
  Future<List<ModelRegistryEntry>> getModelRegistry() async => registryEntries;
}

class _FakeExecutablePickerShellAdapter implements DesktopShellAdapter {
  _FakeExecutablePickerShellAdapter({this.pickedPaths = const <String>[]});

  final List<String> pickedPaths;
  int pickExeCalls = 0;

  @override
  Future<void> openFolder(String path, {bool createIfMissing = false}) async {}

  @override
  Future<List<String>> pickExecutableFiles({
    String? title,
    bool allowMultiple = true,
    String? initialDirectory,
  }) async {
    pickExeCalls++;
    return pickedPaths;
  }

  @override
  Future<String?> pickFolder({String? title, String? initialDirectory}) async => null;

  @override
  Future<List<String>> pickModelFiles({
    String? title,
    bool allowMultiple = true,
    String? initialDirectory,
  }) async =>
      const <String>[];

  @override
  Future<int> stageFilesToInbox({
    required List<String> sourcePaths,
    required String inboxDir,
    required bool moveFiles,
  }) async =>
      0;
}

void main() {
  void setupViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('M5 Batch A Performance & Gaming UI & Tray Sync', () {
    testWidgets('SettingsPerformanceSection honors FLUTTER_TEST offline guard when client is null', (tester) async {
      setupViewport(tester);
      expect(Platform.environment.containsKey('FLUTTER_TEST'), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SettingsPerformanceSection(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Performance & Gaming'), findsOneWidget);
      expect(find.textContaining('Connect to the Local AI Runtime'), findsOneWidget);
    });

    testWidgets('displays Requested vs Applied telemetry, Unavailable GPU cleanly, mode switches, watchlist & exe picker', (tester) async {
      setupViewport(tester);
      final fakeClient = _FakeResourceGovernanceClient();
      final fakeShell = _FakeExecutablePickerShellAdapter(
        pickedPaths: <String>[r'D:\Games\EldenRing\eldenring.exe'],
      );
      final synced = <ResourcePolicyStatusOut>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsPerformanceSection(
                client: fakeClient,
                shellAdapter: fakeShell,
                onResourcePolicyChanged: synced.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeClient.getResourceCalls, greaterThanOrEqualTo(1));
      expect(find.textContaining('Unavailable'), findsWidgets);
      expect(find.textContaining('18.4 / 32.0 GiB'), findsOneWidget);
      expect(find.text('valorant.exe'), findsOneWidget);

      // Switch to Low-Impact mode
      await tester.tap(find.byKey(const Key('resource_mode_chip_low_impact')));
      await tester.pumpAndSettle();
      expect(fakeClient.updateRequests.last.resourceMode, equals('low_impact'));
      expect(synced.last.lowImpactActive, isTrue);

      // Browse .exe picks basename cleanly
      await tester.ensureVisible(find.byKey(const Key('resource_browse_exe_button')));
      await tester.tap(find.byKey(const Key('resource_browse_exe_button')));
      await tester.pumpAndSettle();
      expect(fakeShell.pickExeCalls, equals(1));
      expect(find.widgetWithText(InputChip, 'eldenring.exe'), findsOneWidget);

      // Manual .exe entry + Add
      await tester.enterText(
        find.byKey(const Key('resource_add_exe_input')),
        'Cyberpunk2077.exe',
      );
      await tester.tap(find.byKey(const Key('resource_add_exe_button')));
      await tester.pumpAndSettle();
      expect(fakeClient.updateRequests.last.gameProcessList, contains('cyberpunk2077.exe'));
      expect(find.text('cyberpunk2077.exe'), findsOneWidget);

      // Strategy -> Lightweight Model surfaces dropdown and cooldown update
      await tester.ensureVisible(find.byKey(const Key('resource_strategy_chip_lightweight_model')));
      await tester.tap(find.byKey(const Key('resource_strategy_chip_lightweight_model')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource_lightweight_model_dropdown')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('resource_cooldown_input')));
      await tester.enterText(find.byKey(const Key('resource_cooldown_input')), '90');
      await tester.tap(find.byKey(const Key('resource_cooldown_apply_button')));
      await tester.pumpAndSettle();
      expect(fakeClient.updateRequests.last.cooldownSeconds, equals(90));
    });

    test('DesktopLifecycleCoordinator builds performance mode submenu and dispatches tray selections', () async {
      final winAdapter = FakeDesktopWindowAdapter();
      final trayAdapter = FakeDesktopTrayAdapter();
      final coord = DesktopLifecycleCoordinator(
        windowAdapter: winAdapter,
        trayAdapter: trayAdapter,
      );
      final selectedModes = <String>[];
      coord.onResourceModeSelected = (mode) async {
        selectedModes.add(mode);
      };
      await coord.initialize();

      await coord.updateResourceMode('auto', true);
      final items = coord.buildTrayMenuItems(null, false);
      final perfMenu = items.firstWhere((i) => i.key == 'performance_mode_menu');
      expect(perfMenu.type, equals('submenu'));
      expect(perfMenu.label, contains('Low-Impact'));
      final subItems = perfMenu.submenu!.items!;
      expect(
        subItems.firstWhere((i) => i.key == 'resource_mode_auto').checked,
        isTrue,
      );
      expect(
        subItems.firstWhere((i) => i.key == 'resource_mode_normal').checked,
        isFalse,
      );

      coord.onTrayMenuItemClick(MenuItem(key: 'resource_mode_low_impact'));
      coord.onTrayMenuItemClick(MenuItem(key: 'resource_mode_normal'));
      expect(selectedModes, equals(<String>['low_impact', 'normal']));
    });

    testWidgets('DesktopShell synchronizes Settings -> Performance & Gaming and Tray callbacks', (tester) async {
      setupViewport(tester);
      final fakeClient = _FakeResourceGovernanceClient();
      final chat = DesktopChatController(client: fakeClient);
      final coord = DesktopLifecycleCoordinator(
        windowAdapter: FakeDesktopWindowAdapter(),
        trayAdapter: FakeDesktopTrayAdapter(),
      );
      await coord.initialize();
      addTearDown(() async {
        await coord.dispose();
        chat.dispose();
      });

      final settingsCtrl = DesktopSettingsController(
        initialDestination: DesktopNavDestination.settings,
        initialSettingsSection: SettingsSectionId.health,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(
            controller: settingsCtrl,
            coordinator: coord,
            chatController: chat,
            enableSchedulePolling: false,
            shellAdapter: _FakeExecutablePickerShellAdapter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger tray click -> DesktopShell calls fakeClient.updateResourcePolicy and updates tray + notifier
      coord.onTrayMenuItemClick(MenuItem(key: 'resource_mode_low_impact'));
      await tester.pumpAndSettle();

      expect(fakeClient.updateRequests.last.resourceMode, equals('low_impact'));
      final perfMenu = coord
          .buildTrayMenuItems(null, false)
          .firstWhere((i) => i.key == 'performance_mode_menu');
      expect(
        perfMenu.submenu!.items!
            .firstWhere((i) => i.key == 'resource_mode_low_impact')
            .checked,
        isTrue,
      );
      // Verify SettingsScreen opened on health renders SettingsPerformanceSection and syncs Low-Impact text
      expect(find.byType(SettingsPerformanceSection), findsOneWidget);
      expect(find.textContaining('Low-Impact'), findsWidgets);
    });

    testWidgets('focus-aware live polling polls only when active & focused and preserves cooldown focus input', (tester) async {
      setupViewport(tester);
      final fakeClient = _FakeResourceGovernanceClient();
      final focusNotifier = ValueNotifier<bool>(true);
      bool isActiveTab = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              theme: CompanionTheme.dark(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      SettingsPerformanceSection(
                        client: fakeClient,
                        isActiveTab: isActiveTab,
                        windowFocusedListenable: focusNotifier,
                        enableLivePolling: true,
                        activationDebounce: const Duration(milliseconds: 50),
                        pollInterval: const Duration(milliseconds: 80),
                        activeTransitionPollInterval:
                            const Duration(milliseconds: 60),
                      ),
                      TextButton(
                        key: const Key('toggle_tab_test_btn'),
                        onPressed: () =>
                            setState(() => isActiveTab = !isActiveTab),
                        child: const Text('Toggle Tab'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pump();
      final initialCalls = fakeClient.getResourceCalls;

      // Debounce + first live poll fires
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final callsWhileFocused = fakeClient.getResourceCalls;
      expect(callsWhileFocused, greaterThan(initialCalls));

      // Focus cooldown field and type without being overwritten by incoming polls
      await tester.ensureVisible(find.byKey(const Key('resource_cooldown_input')));
      await tester.tap(find.byKey(const Key('resource_cooldown_input')));
      await tester.enterText(find.byKey(const Key('resource_cooldown_input')), '120');
      await tester.pump(const Duration(milliseconds: 100));
      final cooldownField = tester.widget<TextField>(
        find.byKey(const Key('resource_cooldown_input')),
      );
      expect(cooldownField.controller?.text, equals('120'));

      // Unfocus window -> polling stops cleanly
      focusNotifier.value = false;
      await tester.pump();
      final callsAtBlur = fakeClient.getResourceCalls;
      await tester.pump(const Duration(milliseconds: 250));
      expect(fakeClient.getResourceCalls, equals(callsAtBlur));

      // Refocus window -> debounce resumes polling; switching off tab stops it again
      focusNotifier.value = true;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fakeClient.getResourceCalls, greaterThan(callsAtBlur));

      await tester.ensureVisible(find.byKey(const Key('toggle_tab_test_btn')));
      await tester.tap(find.byKey(const Key('toggle_tab_test_btn')));
      await tester.pump();
      final callsOffTab = fakeClient.getResourceCalls;
      await tester.pump(const Duration(milliseconds: 250));
      expect(fakeClient.getResourceCalls, equals(callsOffTab));
    });

    test('DesktopLifecycleCoordinator tracks focus/minimize/restore state and invokes onTrayMenuOpening', () async {
      final winAdapter = FakeDesktopWindowAdapter();
      final trayAdapter = FakeDesktopTrayAdapter();
      final coord = DesktopLifecycleCoordinator(
        windowAdapter: winAdapter,
        trayAdapter: trayAdapter,
      );
      await coord.initialize();
      expect(coord.isWindowFocused, isTrue);

      coord.onWindowBlur();
      expect(coord.isWindowFocused, isFalse);
      coord.onWindowFocus();
      expect(coord.isWindowFocused, isTrue);
      coord.onWindowMinimize();
      expect(coord.isWindowFocused, isFalse);
      coord.onWindowRestore();
      expect(coord.isWindowFocused, isTrue);

      int refreshCalls = 0;
      coord.onTrayMenuOpening = () async {
        refreshCalls++;
      };
      coord.onTrayIconRightMouseDown();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(refreshCalls, equals(1));
      await coord.dispose();
    });
  });
}
