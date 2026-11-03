import 'dart:async';
import 'dart:convert';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/studio/character_stage_presenter.dart';
import 'package:ai_companion_desktop/features/studio/desktop_studio_controller.dart';
import 'package:companion_api/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('CharacterStagePresenter Unit Tests', () {
    test('buildIllustrativeStyleSummary returns formatted band labels and directives', () {
      const traits = CharacterTraitVector(
        warmth: 60,
        teasing: 75,
        guardedness: 80,
        directness: 70,
        expressiveness: 75,
        affection: 65,
        formality: 35,
        verbosity: 50,
      );

      final summary = CharacterStagePresenter.buildIllustrativeStyleSummary(traits, 'tsundere');
      expect(summary.toneLabel, contains('High Warmth'));
      expect(summary.expressionLabel, contains('Very High Guardedness'));
      expect(summary.deliveryLabel, contains('High Teasing'));
      expect(summary.registerLabel, contains('Low Formality'));
      expect(summary.dynamicLabel, isNotNull);
      expect(summary.dynamicLabel, contains('Tsundere'));
      expect(summary.autonomyGuardActive, isFalse);
    });

    test('buildIllustrativeStyleSummary enables autonomyGuardActive for affection >= 80 or yandere', () {
      const highAffection = CharacterTraitVector(
        warmth: 50, teasing: 50, guardedness: 50, directness: 50,
        expressiveness: 50, affection: 85, formality: 50, verbosity: 50,
      );
      final summaryA = CharacterStagePresenter.buildIllustrativeStyleSummary(highAffection, 'custom');
      expect(summaryA.autonomyGuardActive, isTrue);

      const yandereTraits = CharacterTraitVector(
        warmth: 50, teasing: 50, guardedness: 50, directness: 50,
        expressiveness: 50, affection: 40, formality: 50, verbosity: 50,
      );
      final summaryB = CharacterStagePresenter.buildIllustrativeStyleSummary(yandereTraits, 'yandere');
      expect(summaryB.autonomyGuardActive, isTrue);
    });

    test('StudioBackdropPreset contains 4 presets and default is cozyStudio', () {
      expect(StudioBackdropPreset.values.length, 4);
      expect(StudioBackdropPreset.cozyStudio.label, 'Cozy Studio');
      expect(StudioBackdropPreset.cyberLounge.label, 'Cyber Lounge');
      expect(StudioBackdropPreset.twilightBalcony.label, 'Twilight Balcony');
      expect(StudioBackdropPreset.minimalistVault.label, 'Minimalist Vault');
    });
  });

  group('DesktopStudioController Unit Tests', () {
    late Map<String, dynamic> mockServerState;

    Future<http.Response> handleStudioRequest(http.Request request) async {
      final path = request.url.path;
      if (path.endsWith('/health')) {
        return http.Response('{"status":"healthy"}', 200);
      }
      if (path.endsWith('/me')) {
        return http.Response('{"id":"profile-1","expires_at":"2099-01-01T00:00:00Z"}', 200);
      }
      if (path.endsWith('/models')) return http.Response('{}', 200);
      if (path.endsWith('/characters/presets')) {
        return http.Response(jsonEncode(mockServerState['presets']), 200);
      }
      if (path.endsWith('/characters/templates')) {
        return http.Response(jsonEncode(mockServerState['templates']), 200);
      }
      if (path.endsWith('/characters/neutral')) {
        return http.Response(jsonEncode(mockServerState['neutral']), 200);
      }
      if (path.endsWith('/characters/instances')) {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(mockServerState['instances']), 200);
        }
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final newInst = {
            'id': 'inst-${DateTime.now().millisecondsSinceEpoch}',
            'profile_id': 'profile-1',
            'is_legacy_placeholder': false,
            'legacy_character_id': null,
            'template_id': body['template_id'],
            'source_template_version': 1,
            'name': body['name'],
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
        if (request.method == 'GET') {
          return http.Response(jsonEncode(mockServerState['activeState']), 200);
        }
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          mockServerState['activeState'] = {
            'profile_id': 'profile-1',
            'is_neutral_fallback': false,
            'active_character_id': body['character_id'],
            'active_character_instance_id': body['character_id'],
            'neutral_fallback': mockServerState['neutral'],
            'active_instance': null,
          };
          return http.Response(jsonEncode(mockServerState['activeState']), 200);
        }
      }
      if (path.endsWith('/characters/active/reset-neutral')) {
        mockServerState['activeState'] = {
          'profile_id': 'profile-1',
          'is_neutral_fallback': true,
          'active_character_id': 'neutral-assistant',
          'active_character_instance_id': null,
          'neutral_fallback': mockServerState['neutral'],
          'active_instance': null,
        };
        return http.Response(jsonEncode(mockServerState['activeState']), 200);
      }
      return http.Response('{"error":"not_found"}', 404);
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
          {
            'preset_id': 'playful',
            'label': 'Playful Companion',
            'description': 'Lively and witty.',
            'traits': {
              'warmth': 75, 'teasing': 80, 'guardedness': 20, 'directness': 75,
              'expressiveness': 85, 'affection': 70, 'formality': 15, 'verbosity': 70,
            },
          },
        ],
        'templates': [
          {
            'id': 'warm-companion',
            'template_version': 1,
            'name': 'Warm Companion',
            'summary': 'Empathetic presence.',
            'lore': 'A kind companion.',
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

    test('Initial catalog load and draft creation from template', () async {
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();

      expect(studio.sessionStatus, StudioSessionStatus.authenticatedReady);
      expect(studio.templates.length, 1);
      expect(studio.presets.length, 2);
      expect(studio.isNeutralActive, isTrue);

      // Select template and inspect draft
      studio.selectTemplate(studio.templates.first);
      expect(studio.draft, isNotNull);
      expect(studio.draft!.name, 'Warm Companion');
      expect(studio.draft!.isDirty, isFalse);
      expect(studio.draft!.presetId, 'warm_companion');

      // Edit name -> marks dirty
      studio.draft!.updateName('Aria');
      expect(studio.draft!.isDirty, isTrue);

      // Edit slider -> auto-transitions presetId to 'custom'
      studio.draft!.updateTrait('warmth', 95);
      expect(studio.draft!.presetId, 'custom');
      expect(studio.draft!.traits.warmth, 95);

      // Save draft creates instance
      final success = await studio.saveDraft();
      expect(success, isTrue);
      expect(studio.draft!.isDirty, isFalse);
      expect(studio.instances.length, 1);
      expect(studio.instances.first.name, 'Aria');

      studio.dispose();
      chat.dispose();
    });

    test('Session classification: connecting preserves dirty draft, unauthorized purges immediately', () async {
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);
      studio.draft!.updateName('Unsaved Edits');
      expect(studio.draft!.isDirty, isTrue);

      // 1. Transient checkConnection starting (connecting status) with unchanged profileEpoch
      // Simulates transient network probe
      studio.simulateChatState(
        connectionStatus: RuntimeConnectionStatus.connecting,
        authenticatedProfileId: null,
      );
      expect(studio.sessionStatus, StudioSessionStatus.validatingConnection);
      expect(studio.draft, isNotNull);
      expect(studio.draft!.isDirty, isTrue);
      expect(studio.draft!.name, 'Unsaved Edits');

      // 2. Unchanged-epoch UNAUTHORIZED (e.g. missing token or 401)
      // Must immediately fail closed and purge all personal catalog and drafts!
      studio.simulateChatState(
        connectionStatus: RuntimeConnectionStatus.unauthorized,
        authenticatedProfileId: null,
      );
      expect(studio.sessionStatus, StudioSessionStatus.sessionExpiredOrRevoked);
      expect(studio.draft, isNull);
      expect(studio.instances, isEmpty);
      expect(studio.boundProfileId, isNull);

      studio.dispose();
      chat.dispose();
    });

    test('Mutation lock: concurrent mutations are rejected while _isMutating is true', () async {
      final slowResponseCompleter = Completer<http.Response>();
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/instances') && request.method == 'POST') {
            return slowResponseCompleter.future;
          }
          return handleStudioRequest(request);
        }),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      // Start first save
      final saveFuture1 = studio.saveDraft();
      expect(studio.isMutating, isTrue);

      // Attempt second save concurrently -> rejected
      final saveFuture2 = studio.saveDraft();
      final result2 = await saveFuture2;
      expect(result2, isFalse);

      // Complete first save
      slowResponseCompleter.complete(await handleStudioRequest(
        http.Request('POST', Uri.parse('http://127.0.0.1:8000/api/v1/characters/instances'))
          ..body = jsonEncode({
            'template_id': 'warm-companion',
            'name': 'Slow Character',
          }),
      ));
      final result1 = await saveFuture1;
      expect(result1, isTrue);
      expect(studio.isMutating, isFalse);

      studio.dispose();
      chat.dispose();
    });

    test('Late write commit after Profile switch is dropped', () async {
      final slowResponseCompleter = Completer<http.Response>();
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/instances') && request.method == 'POST') {
            return slowResponseCompleter.future;
          }
          return handleStudioRequest(request);
        }),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);

      final saveFuture = studio.saveDraft();
      expect(studio.isMutating, isTrue);

      // Profile switches while write is in flight
      studio.simulateChatState(
        connectionStatus: RuntimeConnectionStatus.connected,
        authenticatedProfileId: 'profile-2',
        profileEpoch: 2,
      );
      expect(studio.boundProfileId, 'profile-2');

      // Now server responds to Profile 1's write
      slowResponseCompleter.complete(await handleStudioRequest(
        http.Request('POST', Uri.parse('http://127.0.0.1:8000/api/v1/characters/instances'))
          ..body = jsonEncode({
            'template_id': 'warm-companion',
            'name': 'Profile 1 Late Character',
          }),
      ));
      await saveFuture;

      // Profile 1's instance must NOT leak into Profile 2's UI state
      expect(studio.instances.where((i) => i.name == 'Profile 1 Late Character'), isEmpty);

      studio.dispose();
      chat.dispose();
    });

    test('Uncertain write timeout (408) preserves dirty draft and triggers reconciliation', () async {
      var callCount = 0;
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/instances') && request.method == 'POST') {
            callCount++;
            return http.Response('{"detail":"Request timeout"}', 408);
          }
          return handleStudioRequest(request);
        }),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);
      studio.draft!.updateName('Timeout Character');

      final success = await studio.saveDraft();
      expect(success, isFalse);
      expect(studio.uncertainWriteWarning, isTrue);
      expect(studio.draft, isNotNull);
      expect(studio.draft!.isDirty, isTrue);
      expect(studio.draft!.name, 'Timeout Character');
      expect(callCount, 1);

      studio.dispose();
      chat.dispose();
    });

    test('Draft reset actions, neutral selection, and activation', () async {
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();

      // 1. Template selection and trait reset
      final tmpl = studio.templates.first;
      studio.selectTemplate(tmpl);
      studio.draft!.updateTrait('warmth', 10);
      expect(studio.draft!.traits.warmth, 10);
      expect(studio.draft!.presetId, 'custom');

      studio.draft!.resetTraitToTemplate('warmth', tmpl.traits!);
      expect(studio.draft!.traits.warmth, tmpl.traits!.warmth);

      studio.draft!.resetAllTraitsToTemplate(tmpl.traits!, tmpl.defaultPresetId);
      expect(studio.draft!.presetId, tmpl.defaultPresetId);

      // 2. Neutral selection
      studio.selectNeutral();
      expect(studio.isNeutralSelected, isTrue);
      expect(studio.draft, isNull);
      expect(studio.visualSpec.displayName, 'Neutral Assistant');

      // 3. Reset to neutral assistant
      final resetSuccess = await studio.resetProfileToNeutral();
      expect(resetSuccess, isTrue);
      expect(studio.isNeutralActive, isTrue);

      // 4. Zoom controls and backdrop selection
      studio.zoomIn();
      expect(studio.zoomLevel, 1.1);
      studio.zoomOut();
      expect(studio.zoomLevel, 1.0);
      studio.zoomOut(); // Clamped at 1.0
      expect(studio.zoomLevel, 1.0);
      studio.resetZoom();
      expect(studio.zoomLevel, 1.0);

      studio.setBackdropPreset(StudioBackdropPreset.cyberLounge);
      expect(studio.backdropPreset, StudioBackdropPreset.cyberLounge);

      studio.toggleShowArchived();
      expect(studio.showArchived, isTrue);

      studio.dispose();
      chat.dispose();
    });
  });
}
