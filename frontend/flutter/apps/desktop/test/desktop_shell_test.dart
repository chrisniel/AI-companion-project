import 'dart:async';
import 'dart:convert';
import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/studio/desktop_studio_controller.dart';
import 'package:ai_companion_desktop/shell/desktop_shell.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
      expect(find.text('M3'), findsNWidgets(2)); // Schedule and Studio (Memory is active in M3)
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

    testWidgets('Leaving Studio through navigation guard blocks navigation if newer edits remain unsaved after saveDraft', (tester) async {
      setupDesktopViewport(tester);

      final saveCompleter = Completer<http.Response>();
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/health')) return http.Response('{"status":"healthy"}', 200);
          if (request.url.path.endsWith('/me')) return http.Response('{"id":"p1","expires_at":"2099-01-01T00:00:00Z"}', 200);
          if (request.url.path.endsWith('/models')) return http.Response('{}', 200);
          if (request.url.path.endsWith('/characters/presets')) return http.Response('[]', 200);
          if (request.url.path.endsWith('/characters/templates')) {
            return http.Response(jsonEncode([
              {
                'id': 'warm-companion',
                'template_version': 1,
                'name': 'Warm Companion',
                'summary': 'Empathetic presence.',
                'lore': '',
                'system_prompt': '',
                'avatar_asset': 'avatar_warm',
                'default_preset_id': 'custom',
                'is_neutral_fallback': false,
                'traits': null,
                'created_at': '2026-01-01',
                'updated_at': '2026-01-01',
              }
            ]), 200);
          }
          if (request.url.path.endsWith('/characters/neutral')) {
            return http.Response('{"id":"neutral-assistant","name":"Neutral Assistant","system_prompt":"Be neutral.","avatar_asset":"avatar_neutral","is_neutral_fallback":true,"summary":""}', 200);
          }
          if (request.url.path.endsWith('/characters/instances') && request.method == 'GET') {
            return http.Response('[]', 200);
          }
          if (request.url.path.endsWith('/characters/instances') && request.method == 'POST') {
            return saveCompleter.future;
          }
          if (request.url.path.endsWith('/characters/active')) {
            return http.Response('{"profile_id":"p1","is_neutral_fallback":true,"active_character_id":"neutral-assistant","active_character_instance_id":null,"neutral_fallback":{"id":"neutral-assistant","name":"Neutral Assistant","system_prompt":"Be neutral.","avatar_asset":"avatar_neutral","is_neutral_fallback":true,"summary":""}}', 200);
          }
          return http.Response('{"error":"not_found"}', 404);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      final settingsController = DesktopSettingsController();
      settingsController.requestDestination(DesktopNavDestination.studio);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(
            controller: settingsController,
            chatController: chat,
            studioController: studio,
          ),
        ),
      );
      await tester.pumpAndSettle();

      studio.draft!.updateName('Aria Draft V1');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved Studio Customizations'), findsOneWidget);
      expect(find.text('Save & Leave'), findsOneWidget);

      await tester.tap(find.text('Save & Leave'));
      await tester.pump();

      studio.draft!.updateName('Aria Draft V2 Newer');
      expect(studio.draft!.isDirty, isTrue);

      saveCompleter.complete(http.Response(
        jsonEncode({
          'id': 'inst-1',
          'profile_id': 'p1',
          'template_id': 'warm-companion',
          'name': 'Aria Draft V1',
          'summary': '',
          'lore': '',
          'system_prompt': '',
          'avatar_asset': 'avatar_warm',
          'preset_id': 'custom',
          'traits': null,
          'status': 'active',
          'created_at': '2026-01-01',
          'updated_at': '2026-01-01',
        }),
        201,
      ));
      await tester.pumpAndSettle();

      expect(settingsController.currentDestination, DesktopNavDestination.studio);
      expect(studio.draft!.isDirty, isTrue);
      expect(studio.draft!.name, 'Aria Draft V2 Newer');

      studio.dispose();
      chat.dispose();
    });
  });
}
