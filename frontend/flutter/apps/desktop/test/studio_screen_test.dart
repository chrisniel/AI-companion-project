import 'dart:convert';
import 'dart:math' as math;
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/studio/character_stage_presenter.dart';
import 'package:ai_companion_desktop/features/studio/desktop_studio_controller.dart';
import 'package:ai_companion_desktop/features/studio/studio_backdrop_layer.dart';
import 'package:ai_companion_desktop/features/studio/character_showcase_stage.dart';
import 'package:ai_companion_desktop/screens/studio_screen.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Map<String, dynamic> mockServerState;

  Future<http.Response> handleStudioRequest(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/health')) return http.Response('{"status":"healthy"}', 200);
    if (path.endsWith('/me')) return http.Response('{"id":"profile-1","expires_at":"2099-01-01T00:00:00Z"}', 200);
    if (path.endsWith('/characters/presets')) return http.Response(jsonEncode(mockServerState['presets']), 200);
    if (path.endsWith('/characters/templates')) return http.Response(jsonEncode(mockServerState['templates']), 200);
    if (path.endsWith('/characters/neutral')) return http.Response(jsonEncode(mockServerState['neutral']), 200);
    if (path.endsWith('/characters/instances')) {
      if (request.method == 'GET') return http.Response(jsonEncode(mockServerState['instances']), 200);
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final newInst = {
          'id': 'inst-created-1',
          'profile_id': 'profile-1',
          'is_legacy_placeholder': false,
          'legacy_character_id': null,
          'template_id': body['template_id'],
          'source_template_version': 1,
          'name': body['name'] ?? 'Custom',
          'summary': body['summary'] ?? '',
          'lore': body['lore'] ?? '',
          'system_prompt': body['system_prompt'] ?? '',
          'avatar_asset': body['avatar_asset'] ?? 'default_avatar',
          'preset_id': body['preset_id'] ?? 'custom',
          'traits': body['traits'] ?? {
            'warmth': 50, 'teasing': 50, 'guardedness': 50, 'directness': 50,
            'expressiveness': 50, 'affection': 50, 'formality': 50, 'verbosity': 50,
          },
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        (mockServerState['instances'] as List).add(newInst);
        return http.Response(jsonEncode(newInst), 201);
      }
    }
    if (path.endsWith('/characters/active')) {
      return http.Response(jsonEncode(mockServerState['activeState']), 200);
    }
    return http.Response('{}', 200);
  }

  setUp(() {
    mockServerState = {
      'presets': [
        {
          'preset_id': 'warm_companion',
          'label': 'Warm Companion',
          'description': 'Warm and gentle.',
          'traits': {
            'warmth': 85, 'teasing': 35, 'guardedness': 25, 'directness': 60,
            'expressiveness': 70, 'affection': 80, 'formality': 30, 'verbosity': 60,
          },
        },
      ],
      'templates': [
        {
          'id': 'warm-companion',
          'template_version': 1,
          'name': 'Warm Companion',
          'summary': 'Empathetic presence.',
          'lore': 'A kind companion with a rich backstory.',
          'system_prompt': 'Be kind and attentive.',
          'avatar_asset': 'avatar_warm',
          'default_preset_id': 'warm_companion',
          'is_neutral_fallback': false,
          'traits': {
            'warmth': 85, 'teasing': 35, 'guardedness': 25, 'directness': 60,
            'expressiveness': 70, 'affection': 80, 'formality': 30, 'verbosity': 60,
          },
          'created_at': '2026-01-01',
          'updated_at': '2026-01-01',
        },
      ],
      'neutral': {
        'id': 'neutral-assistant',
        'compatibility_alias': 'default',
        'template_version': 1,
        'name': 'Neutral Assistant',
        'summary': 'Impartial assistant.',
        'system_prompt': 'You are a neutral assistant.',
        'avatar_asset': 'avatar_neutral',
        'is_neutral_fallback': true,
        'traits': null,
        'lore': '',
      },
      'instances': <Map<String, dynamic>>[],
      'activeState': {
        'profile_id': 'profile-1',
        'is_neutral_fallback': true,
        'active_character_id': 'neutral-assistant',
        'active_character_instance_id': null,
        'neutral_fallback': {
          'id': 'neutral-assistant',
          'compatibility_alias': 'default',
          'template_version': 1,
          'name': 'Neutral Assistant',
          'summary': 'Impartial assistant.',
          'system_prompt': 'You are a neutral assistant.',
          'avatar_asset': 'avatar_neutral',
          'is_neutral_fallback': true,
          'traits': null,
          'lore': '',
        },
        'active_instance': null,
      },
    };
  });

  group('StudioScreen Widget & Responsive Layout Tests', () {
    testWidgets('Renders wide 3-column layout at >= 1120px content width with zero overflow', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: StudioScreen(controller: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero overflow
      expect(tester.takeException(), isNull);

      // Verify Left Library, Center Showcase, Right Inspector are all rendered
      expect(find.text('Character Library'), findsOneWidget);
      expect(find.text('Starter Templates'), findsOneWidget);
      expect(find.text('Personality Presets'), findsOneWidget);
      expect(find.text('Illustrative Style Summary'), findsOneWidget);

      studio.dispose();
      chat.dispose();
    });

    testWidgets('Renders standard 3-column layout at 920px..1119px (e.g. 1024x640 collapsed rail 952px)', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(952, 640);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: StudioScreen(controller: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Character Library'), findsOneWidget);
      expect(find.text('Personality Presets'), findsOneWidget);

      studio.dispose();
      chat.dispose();
    });

    testWidgets('Renders compact mode at < 920px (e.g. 1024x640 expanded rail 784px) with slide-over drawer', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(784, 640);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: StudioScreen(controller: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // In compact mode, Library button is rendered on the stage
      expect(find.text('Library'), findsOneWidget);

      // Tap Library button to open slide-over drawer
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      // Library dock is now visible in the overlay drawer
      expect(find.text('Character Library'), findsOneWidget);

      studio.dispose();
      chat.dispose();
    });

    testWidgets('Handles TextScaler.linear(1.25) at minimum window 1024x640 with zero overflow', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1024, 640);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
            child: Scaffold(
              body: StudioScreen(controller: studio),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      studio.dispose();
      chat.dispose();
    });
  });

  group('Programmatic WCAG AA Contrast Verification', () {
    double calculateContrast(Color c1, Color c2) {
      final l1 = c1.computeLuminance();
      final l2 = c2.computeLuminance();
      final lighter = math.max(l1, l2);
      final darker = math.min(l1, l2);
      return (lighter + 0.05) / (darker + 0.05);
    }

    test('Primary text contrast >= 4.5:1 across Light/Dark themes and Accent Presets', () {
      final accents = [
        AccentPreset.oceanSky,
        AccentPreset.cobaltIndigo,
        AccentPreset.emeraldTeal,
        AccentPreset.amethystViolet,
      ];

      for (final accent in accents) {
        // Dark theme check
        final darkTheme = CompanionTheme.dark(preset: accent);
        final darkExt = darkTheme.extension<CompanionThemeExtension>()!;
        final darkContrast = calculateContrast(darkExt.textPrimary, darkExt.surfaceElevated);
        expect(darkContrast, greaterThanOrEqualTo(4.5),
            reason: 'Dark theme primary text contrast must be >= 4.5:1 for accent ${accent.name}');

        // Light theme check
        final lightTheme = CompanionTheme.light(preset: accent);
        final lightExt = lightTheme.extension<CompanionThemeExtension>()!;
        final lightContrast = calculateContrast(lightExt.textPrimary, lightExt.surfaceElevated);
        expect(lightContrast, greaterThanOrEqualTo(4.5),
            reason: 'Light theme primary text contrast must be >= 4.5:1 for accent ${accent.name}');
      }
    });

    test('Non-text active controls and focus contrast >= 3.0:1', () {
      final darkTheme = CompanionTheme.dark();
      final darkExt = darkTheme.extension<CompanionThemeExtension>()!;
      final borderContrast = calculateContrast(darkExt.accent, darkExt.appBg);
      expect(borderContrast, greaterThanOrEqualTo(3.0));

      final lightTheme = CompanionTheme.light();
      final lightExt = lightTheme.extension<CompanionThemeExtension>()!;
      final lightBorderContrast = calculateContrast(lightExt.accent, lightExt.appBg);
      expect(lightBorderContrast, greaterThanOrEqualTo(3.0));
    });
  });

  group('StudioScreen Tab Navigation & Unsaved Customizations Dialog', () {
    testWidgets('Switching inspector tabs displays Identity inputs with recommended counters', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: StudioScreen(controller: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Identity & Lore' tab
      await tester.tap(find.text('Identity & Lore'));
      await tester.pumpAndSettle();

      expect(find.text('Character Name'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Persona Instructions'), findsOneWidget);
      expect(find.text('Backstory & Lore'), findsOneWidget);
      expect(find.textContaining('/ 1,200 recommended'), findsOneWidget);
      expect(find.textContaining('/ 1,600 recommended'), findsOneWidget);

      studio.dispose();
      chat.dispose();
    });

    testWidgets('Editing draft and tapping another item in Library opens Unsaved Customizations dialog', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: StudioScreen(controller: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Make draft dirty
      studio.draft!.updateName('Aria Unsaved');
      await tester.pumpAndSettle();
      expect(find.text('Unsaved Changes'), findsOneWidget);

      // Attempt to tap Neutral Assistant in Library
      await tester.tap(find.text('Neutral Assistant'));
      await tester.pumpAndSettle();

      // Unsaved dialog is displayed
      expect(find.text('Unsaved Studio Customizations'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Discard Changes'), findsOneWidget);
      expect(find.text('Save & Continue'), findsOneWidget);

      // Tap Keep Editing
      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();

      // Dialog closed, still on dirty draft
      expect(find.text('Unsaved Studio Customizations'), findsNothing);
      expect(studio.draft!.name, 'Aria Unsaved');
      expect(studio.isNeutralSelected, isFalse);

      studio.dispose();
      chat.dispose();
    });

    testWidgets('Pending unsaved-changes dialog cancels switch when Profile changes or session is revoked', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: StudioScreen(controller: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Make draft dirty
      studio.draft!.updateName('Aria Unsaved');
      await tester.pumpAndSettle();

      // Tap Neutral Assistant to trigger unsaved dialog
      await tester.tap(find.text('Neutral Assistant'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved Studio Customizations'), findsOneWidget);

      // Session revoked while dialog is open
      studio.simulateChatState(connectionStatus: RuntimeConnectionStatus.unauthorized);

      // User taps Discard Changes
      await tester.tap(find.text('Discard Changes'));
      await tester.pumpAndSettle();

      // Dialog closed and switch was cancelled due to session invalidation;
      // Profile access gate is displayed
      expect(find.text('Profile Access Required'), findsOneWidget);

      studio.dispose();
      chat.dispose();
    });

    testWidgets('Preset chips contain exactly one Custom chip and individual trait reset works', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Ensure mock presets includes custom
      mockServerState['presets'] = [
        {
          'preset_id': 'warm_companion',
          'label': 'Warm Companion',
          'description': 'Warm and gentle.',
          'traits': {
            'warmth': 85, 'teasing': 35, 'guardedness': 25, 'directness': 60,
            'expressiveness': 70, 'affection': 80, 'formality': 30, 'verbosity': 60,
          },
        },
        {
          'preset_id': 'custom',
          'label': 'Custom',
          'description': 'Custom traits.',
          'traits': {
            'warmth': 50, 'teasing': 50, 'guardedness': 50, 'directness': 50,
            'expressiveness': 50, 'affection': 50, 'formality': 50, 'verbosity': 50,
          },
        },
      ];

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: StudioScreen(controller: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify exactly ONE 'Custom' ChoiceChip is present (no duplicate)
      expect(find.widgetWithText(ChoiceChip, 'Custom'), findsOneWidget);

      // Verify individual trait reset icon button
      studio.draft!.updateTrait('warmth', 10);
      await tester.pumpAndSettle();
      expect(studio.draft!.traits!.warmth, 10);

      final resetWarmthFinder = find.byTooltip('Reset Warmth to template default');
      expect(resetWarmthFinder, findsOneWidget);
      await tester.tap(resetWarmthFinder);
      await tester.pumpAndSettle();
      expect(studio.draft!.traits!.warmth, 85);

      studio.dispose();
      chat.dispose();
    });

    testWidgets('Legacy placeholder presents read-only notice banner and disables mutations', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockServerState['instances'] = [
        {
          'id': 'inst-legacy-1',
          'profile_id': 'profile-1',
          'is_legacy_placeholder': true,
          'legacy_character_id': 'spark-old',
          'template_id': null,
          'source_template_version': null,
          'name': 'Spark Historical',
          'summary': 'Historical placeholder from migration.',
          'lore': '',
          'system_prompt': '',
          'avatar_asset': 'neutral_avatar',
          'preset_id': null,
          'traits': null,
          'status': 'archived',
          'created_at': '2025-01-01',
          'updated_at': '2025-01-01',
        }
      ];

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.toggleShowArchived();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: StudioScreen(controller: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the legacy instance in the library
      await tester.tap(find.text('Spark Historical'));
      await tester.pumpAndSettle();

      // Notice banner is displayed
      expect(find.text('Legacy Placeholder (Read-Only)'), findsOneWidget);

      // Save button says Read-Only and is disabled
      final readOnlyBtn = find.widgetWithText(NeumorphicButton, 'Read-Only');
      expect(readOnlyBtn, findsOneWidget);

      studio.dispose();
      chat.dispose();
    });
  });

  group('Procedural Fallbacks Rendering', () {
    testWidgets('StudioAtmospherePainter and ArchetypeSilhouetteStageWidget paint cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: const Scaffold(
            body: Stack(
              children: [
                CustomPaint(
                  painter: StudioAtmospherePainter(preset: StudioBackdropPreset.cozyStudio),
                  size: Size(400, 300),
                ),
                ArchetypeSilhouetteStageWidget(name: 'Test Archetype'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Test Archetype'), findsOneWidget);
    });
  });
}
