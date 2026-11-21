import 'dart:convert';

import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/settings/sections/settings_tools_section.dart';
import 'package:ai_companion_desktop/features/tools/desktop_tool_policy_controller.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_tray_adapter.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_window_adapter.dart';
import 'package:ai_companion_desktop/screens/chat_screen.dart';
import 'package:ai_companion_desktop/shell/desktop_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class _NoOpWindowAdapter implements DesktopWindowAdapter {
  @override
  void addListener(WindowListener listener) {}
  @override
  Future<void> center() async {}
  @override
  Future<void> destroy() async {}
  @override
  Future<void> ensureInitialized() async {}
  @override
  Future<void> focus() async {}
  @override
  Future<void> hide() async {}
  @override
  Future<bool> isPreventClose() async => false;
  @override
  Future<bool> isVisible() async => true;
  @override
  Future<void> maximize() async {}
  @override
  void removeListener(WindowListener listener) {}
  @override
  Future<void> setMinimumSize(Size size) async {}
  @override
  Future<void> setPreventClose(bool prevent) async {}
  @override
  Future<void> setSize(Size size) async {}
  @override
  Future<void> setTitle(String title) async {}
  @override
  Future<void> show() async {}
  @override
  Future<void> waitUntilReadyToShow([
    WindowOptions? options,
    VoidCallback? callback,
  ]) async {}
}

class _NoOpTrayAdapter implements DesktopTrayAdapter {
  @override
  void addListener(TrayListener listener) {}
  @override
  Future<void> destroy() async {}
  @override
  void removeListener(TrayListener listener) {}
  @override
  Future<void> setContextMenu(Menu menu) async {}
  @override
  Future<void> popUpContextMenu() async {}
  @override
  Future<void> setIcon(String iconPath) async {}
  @override
  Future<void> setToolTip(String toolTip) async {}
}

void main() {
  group('D9 Desktop Tool Policy, Kill Switch & Chat Surface', () {
    test('DesktopToolPolicyController handles absent Host Admin safely and clears on profile change', () async {
      final sessStore = InMemoryCredentialStore()..writeToken('sess-1');
      bool killed = false;
      final mockHttp = MockClient((req) async {
        if (req.url.path == '/api/v1/tools/catalog') {
          return http.Response(
            jsonEncode({'items': <dynamic>[], 'prohibited_capabilities': <String>['arbitrary_shell_execution']}),
            200,
          );
        }
        if (req.url.path == '/api/v1/tools/policy') {
          return http.Response(
            jsonEncode({
              'profile_id': 'p1',
              'global_kill_switch': killed,
              'risk0_policy': 'allow',
              'risk1_explicit_policy': 'allow',
              'risk1_suggested_policy': 'confirm',
              'risk2_policy': 'confirm',
              'weather_provider': 'open_meteo',
              'web_search_provider': 'public_search',
              'search_api_key_configured': false,
              'updated_at': '2026-11-16T10:00:00Z',
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/tools/kill-switch') {
          if (req.method == 'POST') {
            killed = (jsonDecode(req.body) as Map)['enabled'] as bool;
          }
          return http.Response(jsonEncode({'global_kill_switch': killed}), 200);
        }
        if (req.url.path == '/api/v1/tools/audit') {
          return http.Response(
            jsonEncode({
              'total': 1,
              'items': [
                {
                  'id': 'a1',
                  'profile_id': 'p1',
                  'tool_name': 'list_tasks',
                  'risk_tier': 0,
                  'provenance': 'EXPLICIT_USER',
                  'decision': 'ALLOW',
                  'outcome_status': 'executed',
                  'source_domains': <String>[],
                  'created_at': '2026-11-16T10:00:00Z',
                }
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockHttp,
        sessionStore: sessStore,
      );
      final ctrl = DesktopToolPolicyController(clientProvider: () => client);

      await ctrl.refreshAll();
      expect(ctrl.hasHostAdmin, isFalse);
      expect(ctrl.policy?.profileId, 'p1');
      expect(ctrl.auditLogs, hasLength(1));

      // Engaging Kill Switch works under Profile Session
      final engageOk = await ctrl.toggleKillSwitch(enabled: true, reason: 'emergency');
      expect(engageOk, isTrue);
      expect(ctrl.globalKillSwitch, isTrue);

      // Disengaging without Host Admin fails closed cleanly with readable message
      final disengageFail = await ctrl.toggleKillSwitch(enabled: false);
      expect(disengageFail, isFalse);
      expect(ctrl.error, contains('Host Admin'));

      // Switching profile clears profile-scoped policy & audit logs
      ctrl.resetForProfileChange();
      expect(ctrl.policy, isNull);
      expect(ctrl.auditLogs, isEmpty);
      expect(ctrl.globalKillSwitch, isTrue);
      ctrl.dispose();
    });

    test('DesktopLifecycleCoordinator preserves 2-arg tray builder and triggers Kill Switch', () {
      var triggered = false;
      final coord = DesktopLifecycleCoordinator(
        windowAdapter: _NoOpWindowAdapter(),
        trayAdapter: _NoOpTrayAdapter(),
      )..onKillSwitchTriggered = () async {
          triggered = true;
        };

      final items = coord.buildTrayMenuItems(null, false);
      final ksItem = items.firstWhere((m) => m.key == 'kill_switch_toggle');
      expect(ksItem.disabled, isFalse);
      coord.onTrayMenuItemClick(ksItem);
      expect(triggered, isTrue);
    });

    testWidgets('DesktopShell renders persistent Kill Switch pill independently and SettingsToolsSection handles Host Admin UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sessStore = InMemoryCredentialStore()..writeToken('sess-1');
      final adminStore = InMemoryCredentialStore()..writeToken('admin-1');
      final mockHttp = MockClient((req) async {
        if (req.url.path == '/api/v1/tools/catalog') {
          return http.Response(
            jsonEncode({'items': <dynamic>[], 'prohibited_capabilities': <String>['arbitrary_shell_execution']}),
            200,
          );
        }
        if (req.url.path == '/api/v1/tools/policy') {
          return http.Response(
            jsonEncode({
              'profile_id': 'p1',
              'global_kill_switch': false,
              'risk0_policy': 'allow',
              'risk1_explicit_policy': 'allow',
              'risk1_suggested_policy': 'confirm',
              'risk2_policy': 'confirm',
              'weather_provider': 'open_meteo',
              'web_search_provider': 'tavily',
              'search_api_key_configured': true,
              'updated_at': '2026-11-16T10:00:00Z',
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/tools/kill-switch') {
          return http.Response(jsonEncode({'global_kill_switch': false}), 200);
        }
        if (req.url.path == '/api/v1/tools/audit') {
          return http.Response(jsonEncode({'total': 0, 'items': <dynamic>[]}), 200);
        }
        return http.Response('{}', 200);
      });

      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockHttp,
        sessionStore: sessStore,
        hostAdminStore: adminStore,
      );
      final toolCtrl = DesktopToolPolicyController(clientProvider: () => client);
      final settingsCtrl = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.light(),
          home: DesktopShell(
            controller: settingsCtrl,
            toolPolicyController: toolCtrl,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shell top utility strip renders Kill Switch pill cleanly even without scheduleController
      expect(find.byKey(const Key('shell_kill_switch_button')), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsToolsSection(toolPolicyController: toolCtrl),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tools_kill_switch_toggle_button')), findsOneWidget);
      expect(find.byKey(const Key('web_search_api_key_input')), findsOneWidget);
      expect(find.byKey(const Key('web_clear_api_key_button')), findsOneWidget);

      settingsCtrl.dispose();
      toolCtrl.dispose();
    });

    testWidgets('ChatScreen renders sources strip and disables confirmation Approve under Kill Switch', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sessStore = InMemoryCredentialStore()..writeToken('sess-1');
      final mockHttp = MockClient((req) async {
        if (req.url.path == '/api/v1/health') {
          return http.Response(jsonEncode({'status': 'ok', 'service': 'ai-companion-runtime', 'version': '0.1.0'}), 200);
        }
        if (req.url.path == '/api/v1/models') {
          return http.Response(
            jsonEncode({
              'provider': 'mock',
              'runtime_state': 'MODEL_READY',
              'active_model': 'mock-model',
              'context_size': 4096,
              'gpu_layers': 0,
              'is_loaded': true,
              'active_profile': 'balanced',
              'available_models': <String>[],
              'available_registry': <String>[],
              'idle_timeout_seconds': 300,
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/conversations') {
          return http.Response(jsonEncode({'items': <dynamic>[], 'total': 0}), 200);
        }
        if (req.url.path == '/api/v1/tools/kill-switch') {
          return http.Response(
            jsonEncode({'global_kill_switch': req.method == 'POST' ? true : true}),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockHttp,
        sessionStore: sessStore,
      );
      final chatCtrl = DesktopChatController(client: client);
      final toolCtrl = DesktopToolPolicyController(clientProvider: () => client);
      await toolCtrl.toggleKillSwitch(enabled: true, reason: 'lock');

      // Seed active message with receipts, sources, and pending confirmation using test API
      await chatCtrl.checkConnection();
      // Inject conversation + message via MockClient listMessages flow
      final mockWithConv = MockClient((req) async {
        if (req.url.path == '/api/v1/conversations/conv1/messages') {
          return http.Response(
            jsonEncode({
              'total': 1,
              'items': [
                {
                  'id': 'm1',
                  'conversation_id': 'conv1',
                  'sender': 'assistant',
                  'content': 'Ready to delete task.',
                  'status': 'completed',
                  'sequence_no': 1,
                  'created_at': '2026-11-16T10:00:00Z',
                  'attachments': <dynamic>[],
                  'tool_receipts': [
                    {
                      'tool_name': 'delete_task',
                      'risk_tier': 2,
                      'provenance': 'EXPLICIT_USER',
                      'decision': 'CONFIRM',
                      'outcome_status': 'pending_confirmation',
                      'summary': 'Waiting approval',
                    }
                  ],
                  'sources': [
                    {
                      'title': 'Weather Manila',
                      'url': 'https://api.open-meteo.com/v1',
                      'domain': 'api.open-meteo.com',
                    }
                  ],
                  'pending_confirmations': [
                    {
                      'id': 'conf-99',
                      'conversation_id': 'conv1',
                      'tool_name': 'delete_task',
                      'risk_tier': 2,
                      'provenance': 'EXPLICIT_USER',
                      'target_summary': 'Old Task',
                      'arguments_preview': '{"task_id":"t1"}',
                      'fingerprint': 'fp',
                      'status': 'pending',
                      'expires_at': '2026-11-16T10:05:00Z',
                      'created_at': '2026-11-16T10:00:00Z',
                    }
                  ],
                }
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });
      final seededClient = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockWithConv,
        sessionStore: sessStore,
      );
      final seededChatCtrl = DesktopChatController(client: seededClient);
      await seededChatCtrl.selectConversation(
        const ConversationOut(
          id: 'conv1',
          title: 'Conv 1',
          characterId: 'default',
          ownerId: 'p1',
          createdAt: '2026-11-16T10:00:00Z',
          updatedAt: '2026-11-16T10:00:00Z',
          messageCount: 1,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.light(),
          home: Scaffold(
            body: ChatScreen(
              controller: seededChatCtrl,
              toolPolicyController: toolCtrl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand Sources strip
      expect(find.byKey(const Key('sources_toggle_m1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sources_toggle_m1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('api.open-meteo.com'), findsOneWidget);

      // Pending confirmation card rendered with Approve disabled by Kill Switch
      final approveBtn = tester.widget<FilledButton>(
        find.byKey(const Key('confirm_approve_conf-99')),
      );
      expect(approveBtn.onPressed, isNull);
      expect(find.textContaining('Approve disabled'), findsOneWidget);

      chatCtrl.dispose();
      seededChatCtrl.dispose();
      toolCtrl.dispose();
    });

    testWidgets('Slice 6C renders 7-day weather & reminder consumer cards without raw debug pills', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sessStore = InMemoryCredentialStore()..writeToken('sess-1');
      final mockHttp = MockClient((req) async {
        if (req.url.path == '/api/v1/conversations/conv-wx/messages') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
              'total': 3,
              'items': [
                {
                  'id': 'm-wx',
                  'conversation_id': 'conv-wx',
                  'sender': 'assistant',
                  'content': 'Expect moderate drizzle tomorrow in Caloocan (24.8–31.3°C).',
                  'status': 'completed',
                  'sequence_no': 1,
                  'created_at': '2026-11-20T10:00:00Z',
                  'attachments': <dynamic>[],
                  'tool_receipts': [
                    {
                      'tool_name': 'weather_lookup',
                      'risk_tier': 0,
                      'provenance': 'EXPLICIT_USER',
                      'decision': 'ALLOW',
                      'outcome_status': 'executed',
                      'summary':
                          'Weather in Caloocan, Philippines: Partly cloudy, 26.7°C now. 7-day forecast: 2026-11-20: Thunderstorm (25.7–30.6°C, rain 100%); 2026-11-21: Moderate drizzle (24.8–31.3°C, rain 51%); 2026-11-22: Clear sky (24.5–32.0°C, rain 10%); 2026-11-23: Partly cloudy (25.0–31.5°C, rain 20%); 2026-11-24: Light rain (24.1–29.8°C, rain 70%); 2026-11-25: Overcast (24.6–30.4°C, rain 40%); 2026-11-26: Clear sky (25.2–32.1°C, rain 5%).',
                    }
                  ],
                  'sources': [
                    {
                      'title': 'Open-Meteo Forecast (Caloocan, Philippines)',
                      'url': 'https://api.open-meteo.com/v1/forecast?latitude=14.65&longitude=120.97&forecast_days=7',
                      'domain': 'api.open-meteo.com',
                    }
                  ],
                  'pending_confirmations': <dynamic>[],
                },
                {
                  'id': 'm-rem',
                  'conversation_id': 'conv-wx',
                  'sender': 'assistant',
                  'content': 'I have scheduled your reminder for December 8.',
                  'status': 'completed',
                  'sequence_no': 2,
                  'created_at': '2026-11-20T10:01:00Z',
                  'attachments': <dynamic>[],
                  'tool_receipts': [
                    {
                      'tool_name': 'create_reminder',
                      'risk_tier': 1,
                      'provenance': 'EXPLICIT_USER',
                      'decision': 'ALLOW',
                      'outcome_status': 'executed',
                      'summary': "Created reminder 'Wedding suit fitting' for 2026-12-08T09:00+08:00.",
                    }
                  ],
                  'sources': <dynamic>[],
                  'pending_confirmations': <dynamic>[],
                },
                {
                  'id': 'm-web',
                  'conversation_id': 'conv-wx',
                  'sender': 'assistant',
                  'content': 'GTA VI is scheduled for release next year.',
                  'status': 'completed',
                  'sequence_no': 3,
                  'created_at': '2026-11-20T10:02:00Z',
                  'attachments': <dynamic>[],
                  'tool_receipts': [
                    {
                      'tool_name': 'web_search',
                      'risk_tier': 0,
                      'provenance': 'EXPLICIT_USER',
                      'decision': 'ALLOW',
                      'outcome_status': 'executed',
                      'summary': 'Found 5 public web results.',
                    }
                  ],
                  'sources': [
                    {
                      'title': 'Rockstar Games News',
                      'url': 'https://www.rockstargames.com/newswire',
                      'domain': 'www.rockstargames.com',
                    }
                  ],
                  'pending_confirmations': <dynamic>[],
                },
              ],
            }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      });

      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockHttp,
        sessionStore: sessStore,
      );
      final chatCtrl = DesktopChatController(client: client);
      await chatCtrl.selectConversation(
        const ConversationOut(
          id: 'conv-wx',
          title: 'Consumer Cards',
          characterId: 'default',
          ownerId: 'p1',
          createdAt: '2026-11-20T10:00:00Z',
          updatedAt: '2026-11-20T10:02:00Z',
          messageCount: 3,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: ChatScreen(controller: chatCtrl),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Raw developer receipt labels must NOT appear for executed consumer tools
      expect(find.textContaining('weather_lookup · executed'), findsNothing);
      expect(find.textContaining('create_reminder · executed'), findsNothing);
      expect(find.textContaining('web_search · executed'), findsNothing);

      // Auto-visible Weather Widget card & 7-day items appear cleanly
      expect(find.byKey(const Key('weather_widget_card')), findsOneWidget);
      expect(find.text('Caloocan, Philippines'), findsOneWidget);
      expect(find.textContaining('26.7°C'), findsOneWidget);
      expect(find.textContaining('Moderate drizzle'), findsWidgets);

      // Consumer Action Card renders cleanly for create_reminder
      expect(find.byKey(const Key('assistant_action_card_create_reminder')), findsOneWidget);
      expect(find.text('Reminder Set'), findsOneWidget);

      // Clean Sources pill remains visible for web_search
      expect(find.byKey(const Key('sources_toggle_m-web')), findsOneWidget);

      chatCtrl.dispose();
    });
  });
}
