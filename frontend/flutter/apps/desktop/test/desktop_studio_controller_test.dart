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

    test('resolveAvatarPath resolves Migration 009 seeded avatar identifiers and null for unknown', () {
      expect(
        CharacterStagePresenter.resolveAvatarPath('neutral_avatar'),
        'assets/studio/portrait_neutral_assistant.png',
      );
      expect(
        CharacterStagePresenter.resolveAvatarPath('warm_companion_avatar'),
        'assets/studio/portrait_warm_companion.png',
      );
      expect(
        CharacterStagePresenter.resolveAvatarPath('playful_companion_avatar'),
        'assets/studio/portrait_playful.png',
      );
      expect(
        CharacterStagePresenter.resolveAvatarPath('formal_advisor_avatar'),
        'assets/studio/portrait_formal_advisor.png',
      );
      expect(
        CharacterStagePresenter.resolveAvatarPath('assets/custom/path.png'),
        'assets/custom/path.png',
      );
      expect(
        CharacterStagePresenter.resolveAvatarPath('unknown_avatar_key'),
        isNull,
      );
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
      if (path.contains('/characters/instances/')) {
        final id = path.split('/characters/instances/').last;
        final instances = mockServerState['instances'] as List;
        final idx = instances.indexWhere((i) => i['id'] == id);
        if (request.method == 'PATCH') {
          if (idx == -1) return http.Response('{"error":"not_found"}', 404);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final inst = Map<String, dynamic>.from(instances[idx] as Map);
          for (final key in body.keys) {
            inst[key] = body[key];
          }
          inst['updated_at'] = DateTime.now().toIso8601String();
          instances[idx] = inst;
          return http.Response(jsonEncode(inst), 200);
        }
        if (request.method == 'DELETE') {
          if (idx != -1) instances.removeAt(idx);
          return http.Response('{"status":"archived"}', 200);
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
      expect(studio.draft!.traits!.warmth, 95);

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
      expect(studio.draft!.traits!.warmth, 10);
      expect(studio.draft!.presetId, 'custom');

      studio.draft!.resetTraitToTemplate('warmth', tmpl.traits!);
      expect(studio.draft!.traits!.warmth, tmpl.traits!.warmth);

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

    test('Uncertain Character creation does not confirm on matching editable fields and requires deliberate retry', () async {
      mockServerState['instances'] = [
        {
          'id': 'inst-existing-1',
          'profile_id': 'profile-1',
          'is_legacy_placeholder': false,
          'legacy_character_id': null,
          'template_id': 'warm-companion',
          'source_template_version': 1,
          'name': 'Identical Name',
          'summary': 'Identical Summary',
          'lore': 'Identical Lore',
          'system_prompt': 'Identical Prompt',
          'avatar_asset': 'default_avatar',
          'preset_id': 'custom',
          'traits': {
            'warmth': 80, 'teasing': 50, 'guardedness': 50, 'directness': 50,
            'expressiveness': 50, 'affection': 50, 'formality': 50, 'verbosity': 50,
          },
          'status': 'active',
          'created_at': '2026-01-01',
          'updated_at': '2026-01-01',
        }
      ];

      bool shouldTimeoutCreate = false;
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/characters/instances') && req.method == 'POST') {
            if (shouldTimeoutCreate) {
              return http.Response('{"detail":"Request timeout"}', 408);
            }
          }
          return handleStudioRequest(req);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      expect(studio.instances.length, 1);

      // User creates a new draft with identical fields to inst-existing-1
      studio.selectTemplate(studio.templates.first);
      studio.draft!.updateName('Identical Name');
      studio.draft!.updateSummary('Identical Summary');
      studio.draft!.updateLore('Identical Lore');
      studio.draft!.updateSystemPrompt('Identical Prompt');
      studio.draft!.updateTrait('warmth', 80);

      // Save times out (408)
      shouldTimeoutCreate = true;
      final success = await studio.saveDraft();
      expect(success, isFalse);
      expect(studio.uncertainCreateWarning, isTrue);
      expect(studio.uncertainWriteWarning, isTrue);

      // Critical Invariant: Draft must NOT be replaced by inst-existing-1
      expect(studio.draft!.isNew, isTrue);
      expect(studio.draft!.instanceId, isNull);
      expect(studio.draft!.isDirty, isTrue);

      // An ordinary second saveDraft() click must not silently duplicate
      final secondClick = await studio.saveDraft();
      expect(secondClick, isFalse);
      expect(studio.error, contains('Confirm retry'));

      // Deliberate user retry when server is healthy succeeds
      shouldTimeoutCreate = false;
      final retrySuccess = await studio.retryCreateDraft();
      expect(retrySuccess, isTrue);
      expect(studio.draft!.isNew, isFalse);
      expect(studio.draft!.instanceId, isNotNull);
      expect(studio.uncertainCreateWarning, isFalse);

      studio.dispose();
      chat.dispose();
    });

    test('Character API 401/403 authorization failures trigger fail-closed session invalidation', () async {
      String? failEndpoint;
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((req) async {
          if (failEndpoint != null && req.url.path.endsWith(failEndpoint)) {
            return http.Response('{"detail":"Unauthorized"}', 401);
          }
          return handleStudioRequest(req);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      expect(studio.sessionStatus, StudioSessionStatus.authenticatedReady);

      // 1. Catalog reload 401
      failEndpoint = '/characters/instances';
      await studio.loadStudioCatalog();
      expect(studio.sessionStatus, StudioSessionStatus.sessionExpiredOrRevoked);
      expect(studio.draft, isNull);
      expect(studio.instances, isEmpty);

      // Restore session
      failEndpoint = null;
      await chat.checkConnection();
      await studio.loadStudioCatalog();
      expect(studio.sessionStatus, StudioSessionStatus.authenticatedReady);

      // 2. saveDraft 401
      studio.selectTemplate(studio.templates.first);
      failEndpoint = '/characters/instances';
      final saveSuccess = await studio.saveDraft();
      expect(saveSuccess, isFalse);
      expect(studio.sessionStatus, StudioSessionStatus.sessionExpiredOrRevoked);
      expect(studio.draft, isNull);

      studio.dispose();
      chat.dispose();
    });

    test('Concurrent edits during save request are preserved after response snapshot', () async {
      Completer<http.Response>? saveCompleter;
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/characters/instances') && req.method == 'POST') {
            if (saveCompleter != null) {
              return saveCompleter.future;
            }
          }
          return handleStudioRequest(req);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();

      studio.selectTemplate(studio.templates.first);
      studio.draft!.updateName('Aria Initial');

      // Trigger save with delayed server response
      saveCompleter = Completer<http.Response>();
      final saveFuture = studio.saveDraft();

      // While in flight, user makes additional edits (revision increments)
      studio.draft!.updateName('Aria Concurrent Edit');
      studio.draft!.updateTrait('warmth', 99);

      // Complete save with server response from snapshot
      final serverInst = {
        'id': 'inst-saved-1',
        'profile_id': 'profile-1',
        'is_legacy_placeholder': false,
        'legacy_character_id': null,
        'template_id': 'warm-companion',
        'source_template_version': 1,
        'name': 'Aria Initial',
        'summary': '',
        'lore': '',
        'system_prompt': '',
        'avatar_asset': 'default_avatar',
        'preset_id': 'warm_companion',
        'traits': {
          'warmth': 85, 'teasing': 35, 'guardedness': 25, 'directness': 60,
          'expressiveness': 70, 'affection': 80, 'formality': 30, 'verbosity': 60,
        },
        'status': 'active',
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      };
      saveCompleter.complete(http.Response(jsonEncode(serverInst), 201));
      final result = await saveFuture;

      expect(result, isTrue);
      // Critical Invariant: Instance ID is adopted, but newer edits are preserved
      expect(studio.draft!.instanceId, 'inst-saved-1');
      expect(studio.draft!.name, 'Aria Concurrent Edit');
      expect(studio.draft!.traits!.warmth, 99);
      expect(studio.draft!.isDirty, isTrue);

      studio.dispose();
      chat.dispose();
    });

    test('Stale catalog read does not overwrite active character state after mutation', () async {
      Completer<http.Response>? slowInstancesCompleter;
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/characters/instances') && req.method == 'GET') {
            if (slowInstancesCompleter != null) {
              return slowInstancesCompleter.future;
            }
          }
          return handleStudioRequest(req);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();

      // Trigger a slow catalog load
      slowInstancesCompleter = Completer<http.Response>();
      final slowLoadFuture = studio.loadStudioCatalog();

      // In the meantime, reset active character to neutral (increments _readGeneration)
      final resetSuccess = await studio.resetProfileToNeutral();
      expect(resetSuccess, isTrue);
      expect(studio.isNeutralActive, isTrue);

      // Now complete the slow catalog read with a pre-reset active character
      slowInstancesCompleter.complete(http.Response(jsonEncode(mockServerState['instances']), 200));
      await slowLoadFuture;

      // Stale read was dropped; neutral active state remains intact
      expect(studio.isNeutralActive, isTrue);

      studio.dispose();
      chat.dispose();
    });

    test('Legacy placeholder instances are loaded with includeLegacy, read-only, and reject mutations', () async {
      mockServerState['instances'] = [
        {
          'id': 'inst-legacy-1',
          'profile_id': 'profile-1',
          'is_legacy_placeholder': true,
          'legacy_character_id': 'spark-old',
          'template_id': null,
          'source_template_version': null,
          'name': 'Spark Legacy',
          'summary': 'Historical character.',
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

      expect(studio.instances.length, 1);
      final legacyInst = studio.instances.first;
      expect(legacyInst.isLegacyPlaceholder, isTrue);

      // Select legacy instance
      studio.selectInstance(legacyInst);
      expect(studio.draft!.isLegacyPlaceholder, isTrue);
      expect(studio.draft!.isReadOnly, isTrue);
      expect(studio.draft!.traits, isNull);

      // Edits are no-ops
      studio.draft!.updateName('Attempted Edit');
      expect(studio.draft!.name, 'Spark Legacy');
      studio.draft!.updateTrait('warmth', 99);
      expect(studio.draft!.traits, isNull);

      // Mutations rejected
      expect(await studio.saveDraft(), isFalse);
      expect(await studio.activateCharacter(legacyInst.id), isFalse);
      expect(await studio.archiveInstance(legacyInst.id), isFalse);

      studio.dispose();
      chat.dispose();
    });

    test('Pan offset updates when zoomed and resets with zoom', () {
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient(handleStudioRequest),
      );
      final chat = DesktopChatController(client: client);
      final studio = DesktopStudioController(chat: chat);

      expect(studio.panOffset, Offset.zero);

      // Pan at 1.0 zoom is ignored
      studio.updatePan(const Offset(50, 50));
      expect(studio.panOffset, Offset.zero);

      // Zoom in to 1.5x
      studio.zoomIn();
      studio.zoomIn();
      studio.zoomIn();
      studio.zoomIn();
      studio.zoomIn();
      expect(studio.zoomLevel, closeTo(1.5, 0.001));

      // Pan is permitted and clamped
      studio.updatePan(const Offset(30, 40));
      expect(studio.panOffset.dx, 30.0);
      expect(studio.panOffset.dy, 40.0);

      // Reset zoom resets pan to zero
      studio.resetZoom();
      expect(studio.zoomLevel, 1.0);
      expect(studio.panOffset, Offset.zero);

      studio.dispose();
      chat.dispose();
    });

    test('Uncertain PATCH reconciliation preserves dirty draft when server still contains original name', () async {
      mockServerState['instances'] = <Map<String, dynamic>>[
        {
          'id': 'inst-aria',
          'template_id': 'warm-companion',
          'profile_id': 'profile-1',
          'name': 'Aria',
          'summary': 'Companion',
          'lore': '',
          'system_prompt': '',
          'avatar_asset': 'warm_companion_avatar',
          'preset_id': 'custom',
          'traits': {
            'warmth': 50, 'teasing': 50, 'guardedness': 50, 'directness': 50,
            'expressiveness': 50, 'affection': 50, 'formality': 50, 'verbosity': 50,
          },
          'status': 'active',
          'created_at': '2025-01-01',
          'updated_at': '2025-01-01',
        }
      ];

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/instances/inst-aria') && request.method == 'PATCH') {
            return http.Response('{"detail":"Request timeout"}', 408);
          }
          return handleStudioRequest(request);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      final aria = studio.instances.first;
      studio.selectInstance(aria);

      studio.draft!.updateName('Aria V2');
      expect(studio.draft!.isDirty, isTrue);

      final saveResult = await studio.saveDraft();
      expect(saveResult, isFalse);

      await pumpEventQueue();

      expect(studio.draft!.name, 'Aria V2');
      expect(studio.draft!.isDirty, isTrue);
      expect(studio.error, contains('not confirmed'));

      studio.dispose();
      chat.dispose();
    });

    test('Uncertain PATCH reconciliation clears dirty draft when server committed Aria V2 before timeout', () async {
      mockServerState['instances'] = <Map<String, dynamic>>[
        {
          'id': 'inst-aria',
          'template_id': 'warm-companion',
          'profile_id': 'profile-1',
          'name': 'Aria',
          'summary': 'Companion',
          'lore': '',
          'system_prompt': '',
          'avatar_asset': 'warm_companion_avatar',
          'preset_id': 'custom',
          'traits': {
            'warmth': 50, 'teasing': 50, 'guardedness': 50, 'directness': 50,
            'expressiveness': 50, 'affection': 50, 'formality': 50, 'verbosity': 50,
          },
          'status': 'active',
          'created_at': '2025-01-01',
          'updated_at': '2025-01-01',
        }
      ];

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/instances/inst-aria') && request.method == 'PATCH') {
            (mockServerState['instances'] as List)[0]['name'] = 'Aria V2';
            return http.Response('{"detail":"Request timeout"}', 408);
          }
          return handleStudioRequest(request);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      final aria = studio.instances.first;
      studio.selectInstance(aria);

      studio.draft!.updateName('Aria V2');
      expect(studio.draft!.isDirty, isTrue);

      final saveResult = await studio.saveDraft();
      expect(saveResult, isFalse);

      await pumpEventQueue();

      expect(studio.draft!.name, 'Aria V2');
      expect(studio.draft!.isDirty, isFalse);
      expect(studio.uncertainWriteWarning, isFalse);

      studio.dispose();
      chat.dispose();
    });

    test('Uncertain PATCH reconciliation detects remote conflict when server record changed concurrently', () async {
      mockServerState['instances'] = <Map<String, dynamic>>[
        {
          'id': 'inst-aria',
          'template_id': 'warm-companion',
          'profile_id': 'profile-1',
          'name': 'Aria',
          'summary': 'Companion',
          'lore': '',
          'system_prompt': '',
          'avatar_asset': 'warm_companion_avatar',
          'preset_id': 'custom',
          'traits': {
            'warmth': 50, 'teasing': 50, 'guardedness': 50, 'directness': 50,
            'expressiveness': 50, 'affection': 50, 'formality': 50, 'verbosity': 50,
          },
          'status': 'active',
          'created_at': '2025-01-01',
          'updated_at': '2025-01-01',
        }
      ];

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/instances/inst-aria') && request.method == 'PATCH') {
            (mockServerState['instances'] as List)[0]['name'] = 'Aria Remote';
            return http.Response('{"detail":"Request timeout"}', 408);
          }
          return handleStudioRequest(request);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      final aria = studio.instances.first;
      studio.selectInstance(aria);

      studio.draft!.updateName('Aria V2');

      final saveResult = await studio.saveDraft();
      expect(saveResult, isFalse);

      await pumpEventQueue();

      expect(studio.draft!.name, 'Aria V2');
      expect(studio.draft!.isDirty, isTrue);
      expect(studio.error, contains('Conflict detected'));

      studio.dispose();
      chat.dispose();
    });

    test('Selection transitions are rejected while Character creation or save is in flight', () async {
      mockServerState['templates'] = [
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
        {
          'id': 'playful',
          'template_version': 1,
          'name': 'Playful Companion',
          'summary': 'Witty and energetic.',
          'lore': 'A fun friend.',
          'system_prompt': 'Be playful and fun.',
          'avatar_asset': 'avatar_playful',
          'default_preset_id': 'playful',
          'is_neutral_fallback': false,
          'traits': {
            'warmth': 75, 'teasing': 80, 'guardedness': 20, 'directness': 75,
            'expressiveness': 85, 'affection': 70, 'formality': 15, 'verbosity': 70,
          },
          'created_at': '2026-01-01',
          'updated_at': '2026-01-01',
        },
      ];

      final saveCompleter = Completer<http.Response>();
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/instances') && request.method == 'POST') {
            return saveCompleter.future;
          }
          return handleStudioRequest(request);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);
      studio.draft!.updateName('Character A');

      final saveFuture = studio.saveDraft();
      expect(studio.isMutating, isTrue);

      studio.selectTemplate(studio.templates[1]);
      expect(studio.draft!.name, 'Character A');
      expect(studio.draft!.sourceTemplateId, studio.templates.first.id);

      studio.selectNeutral();
      expect(studio.isNeutralSelected, isFalse);
      expect(studio.draft, isNotNull);

      saveCompleter.complete(await handleStudioRequest(
        http.Request('POST', Uri.parse('http://127.0.0.1:8000/api/v1/characters/instances'))
          ..body = jsonEncode({
            'template_id': studio.templates.first.id,
            'name': 'Character A',
          }),
      ));
      final success = await saveFuture;
      expect(success, isTrue);
      expect(studio.draft!.name, 'Character A');
      expect(studio.draft!.isNew, isFalse);

      studio.dispose();
      chat.dispose();
    });

    test('Saving instance A rejects selecting instance B while mutation in flight', () async {
      mockServerState['instances'] = <Map<String, dynamic>>[
        {
          'id': 'inst-a',
          'template_id': 'warm-companion',
          'profile_id': 'profile-1',
          'name': 'Instance A',
          'summary': '',
          'lore': '',
          'system_prompt': '',
          'avatar_asset': 'warm_companion_avatar',
          'preset_id': 'custom',
          'traits': {
            'warmth': 50, 'teasing': 50, 'guardedness': 50, 'directness': 50,
            'expressiveness': 50, 'affection': 50, 'formality': 50, 'verbosity': 50,
          },
          'status': 'active',
          'created_at': '2025-01-01',
          'updated_at': '2025-01-01',
        },
        {
          'id': 'inst-b',
          'template_id': 'playful',
          'profile_id': 'profile-1',
          'name': 'Instance B',
          'summary': '',
          'lore': '',
          'system_prompt': '',
          'avatar_asset': 'playful_companion_avatar',
          'preset_id': 'custom',
          'traits': {
            'warmth': 70, 'teasing': 70, 'guardedness': 30, 'directness': 50,
            'expressiveness': 70, 'affection': 60, 'formality': 30, 'verbosity': 60,
          },
          'status': 'active',
          'created_at': '2025-01-01',
          'updated_at': '2025-01-01',
        },
      ];

      final patchCompleter = Completer<http.Response>();
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/instances/inst-a') && request.method == 'PATCH') {
            return patchCompleter.future;
          }
          return handleStudioRequest(request);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectInstance(studio.instances[0]);
      studio.draft!.updateName('Instance A Updated');

      final saveFuture = studio.saveDraft();
      expect(studio.isMutating, isTrue);

      studio.selectInstance(studio.instances[1]);
      expect(studio.draft!.instanceId, 'inst-a');
      expect(studio.draft!.name, 'Instance A Updated');

      patchCompleter.complete(await handleStudioRequest(
        http.Request('PATCH', Uri.parse('http://127.0.0.1:8000/api/v1/characters/instances/inst-a'))
          ..body = jsonEncode({'name': 'Instance A Updated'}),
      ));

      expect(await saveFuture, isTrue);
      expect(studio.draft!.instanceId, 'inst-a');
      expect(studio.draft!.isDirty, isFalse);

      studio.dispose();
      chat.dispose();
    });

    test('Profile A delayed response does not unlock or interfere with Profile B pending mutation', () async {
      final profileAResponseCompleter = Completer<http.Response>();
      final profileBResponseCompleter = Completer<http.Response>();

      var callCount = 0;
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/instances') && request.method == 'POST') {
            callCount++;
            if (callCount == 1) {
              return profileAResponseCompleter.future;
            } else {
              return profileBResponseCompleter.future;
            }
          }
          return handleStudioRequest(request);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);
      studio.draft!.updateName('Profile A Character');

      final profileAFuture = studio.saveDraft();
      expect(studio.isMutating, isTrue);

      studio.simulateChatState(
        connectionStatus: RuntimeConnectionStatus.connected,
        authenticatedProfileId: 'profile-b',
        profileEpoch: 2,
      );
      expect(studio.boundProfileId, 'profile-b');
      expect(studio.isMutating, isFalse);

      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);
      studio.draft!.updateName('Profile B Character');
      final profileBFuture = studio.saveDraft();
      expect(studio.isMutating, isTrue);

      profileAResponseCompleter.complete(http.Response(
        jsonEncode({
          'id': 'inst-profile-a-late',
          'profile_id': 'profile-1',
          'template_id': 'warm-companion',
          'name': 'Profile A Character',
          'summary': '',
          'lore': '',
          'system_prompt': '',
          'avatar_asset': 'warm_companion_avatar',
          'preset_id': 'custom',
          'traits': null,
          'status': 'active',
          'created_at': '2025-01-01',
          'updated_at': '2025-01-01',
        }),
        200,
      ));
      await profileAFuture;

      // Profile B mutation is STILL PENDING and isMutating MUST REMAIN TRUE!
      expect(studio.isMutating, isTrue);
      expect(studio.draft!.name, 'Profile B Character');

      profileBResponseCompleter.complete(http.Response(
        jsonEncode({
          'id': 'inst-profile-b',
          'profile_id': 'profile-b',
          'template_id': 'warm-companion',
          'name': 'Profile B Character',
          'summary': '',
          'lore': '',
          'system_prompt': '',
          'avatar_asset': 'warm_companion_avatar',
          'preset_id': 'custom',
          'traits': null,
          'status': 'active',
          'created_at': '2025-01-01',
          'updated_at': '2025-01-01',
        }),
        201,
      ));
      final profileBSuccess = await profileBFuture;
      expect(profileBSuccess, isTrue);
      expect(studio.isMutating, isFalse);
      expect(studio.draft!.instanceId, 'inst-profile-b');

      studio.dispose();
      chat.dispose();
    });

    test('Changing selections retains protection against unguarded retry of uncertain creation', () async {
      mockServerState['instances'] = <Map<String, dynamic>>[];
      var postAttempts = 0;
      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/instances') && request.method == 'POST') {
            postAttempts++;
            return http.Response('{"detail":"Timeout"}', 408);
          }
          return handleStudioRequest(request);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();
      studio.selectTemplate(studio.templates.first);
      studio.draft!.updateName('Uncertain Hero');

      final result1 = await studio.saveDraft();
      expect(result1, isFalse);
      expect(studio.uncertainCreateWarning, isTrue);
      expect(postAttempts, 1);

      studio.selectNeutral();
      expect(studio.isNeutralSelected, isTrue);

      studio.selectTemplate(studio.templates.first);
      studio.draft!.updateName('Uncertain Hero');

      final result2 = await studio.saveDraft();
      expect(result2, isFalse);
      expect(postAttempts, 1);
      expect(studio.error, contains('timed out'));

      final result3 = await studio.retryCreateDraft();
      expect(result3, isFalse);
      expect(postAttempts, 2);

      studio.dispose();
      chat.dispose();
    });

    test('saveAndActivateDraft saves dirty draft changes before activating for Chat', () async {
      mockServerState['instances'] = [
        {
          'id': 'inst-existing-1',
          'profile_id': 'profile-1',
          'is_legacy_placeholder': false,
          'legacy_character_id': null,
          'template_id': 'warm-companion',
          'source_template_version': 1,
          'name': 'Existing Character',
          'summary': 'Summary',
          'lore': 'Lore',
          'system_prompt': 'Prompt',
          'avatar_asset': 'default_avatar',
          'preset_id': 'custom',
          'traits': {
            'warmth': 50, 'teasing': 50, 'guardedness': 50, 'directness': 50,
            'expressiveness': 50, 'affection': 50, 'formality': 50, 'verbosity': 50,
          },
          'status': 'active',
          'created_at': '2026-01-01',
          'updated_at': '2026-01-01',
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

      final target = studio.instances.first;
      studio.selectInstance(target);
      expect(studio.draft, isNotNull);
      expect(studio.draft!.isDirty, isFalse);

      studio.draft!.updateTrait('warmth', 99);
      expect(studio.draft!.isDirty, isTrue);

      final success = await studio.saveAndActivateDraft();
      expect(success, isTrue);

      expect(studio.draft!.isDirty, isFalse);
      expect(studio.draft!.traits?.warmth, 99);
      expect(studio.activeInstanceId, target.id);
      expect(chat.activeCharacterState?.activeCharacterInstanceId, target.id);

      studio.dispose();
      chat.dispose();
    });

    test('saveAndActivateDraft aborts activation and preserves dirty draft if save fails', () async {
      mockServerState['instances'] = [
        {
          'id': 'inst-existing-1',
          'profile_id': 'profile-1',
          'is_legacy_placeholder': false,
          'legacy_character_id': null,
          'template_id': 'warm-companion',
          'source_template_version': 1,
          'name': 'Existing Character',
          'summary': 'Summary',
          'lore': 'Lore',
          'system_prompt': 'Prompt',
          'avatar_asset': 'default_avatar',
          'preset_id': 'custom',
          'traits': {
            'warmth': 50, 'teasing': 50, 'guardedness': 50, 'directness': 50,
            'expressiveness': 50, 'affection': 50, 'formality': 50, 'verbosity': 50,
          },
          'status': 'active',
          'created_at': '2026-01-01',
          'updated_at': '2026-01-01',
        }
      ];

      var patchCalled = false;
      var putActiveCalled = false;

      final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/characters/instances/') && request.method == 'PATCH') {
            patchCalled = true;
            return http.Response('{"detail":"Database write error"}', 500);
          }
          if (request.url.path.endsWith('/characters/active') && request.method == 'PUT') {
            putActiveCalled = true;
          }
          return handleStudioRequest(request);
        }),
      );

      final chat = DesktopChatController(client: client);
      await chat.checkConnection();

      final studio = DesktopStudioController(chat: chat);
      await studio.loadStudioCatalog();

      final target = studio.instances.first;
      studio.selectInstance(target);
      studio.draft!.updateTrait('warmth', 99);
      expect(studio.draft!.isDirty, isTrue);

      final success = await studio.saveAndActivateDraft();
      expect(success, isFalse);

      expect(patchCalled, isTrue);
      expect(putActiveCalled, isFalse);
      expect(studio.draft!.isDirty, isTrue);
      expect(studio.draft!.traits?.warmth, 99);
      expect(studio.error, isNotNull);

      studio.dispose();
      chat.dispose();
    });
  });
}
