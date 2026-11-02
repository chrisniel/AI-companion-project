import 'dart:convert';
import 'package:companion_api/companion_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('CompanionClient Character Foundation Endpoints', () {
    test('listCharacterTemplates sends GET to /characters/templates and returns list', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/characters/templates');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test_session_token');
        return http.Response(
          jsonEncode([
            {
              'id': 'neutral-assistant',
              'template_version': 1,
              'name': 'Neutral Assistant',
              'summary': 'Objective assistant',
              'lore': '',
              'system_prompt': 'Neutral prompt',
              'avatar_asset': 'neutral_avatar',
              'default_preset_id': null,
              'is_neutral_fallback': true,
              'traits': null,
              'created_at': '2026-11-02T10:00:00Z',
              'updated_at': '2026-11-02T10:00:00Z',
            }
          ]),
          200,
        );
      });

      final client = CompanionClient(
        httpClient: mock,
        sessionStore: InMemoryCredentialStore('test_session_token'),
      );
      final templates = await client.listCharacterTemplates();
      expect(templates.length, 1);
      expect(templates.first.id, 'neutral-assistant');
      expect(templates.first.isNeutralFallback, isTrue);
    });

    test('listCharacterPresets sends GET to /characters/presets and returns list', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/characters/presets');
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode([
            {
              'preset_id': 'warm_companion',
              'label': 'Warm Companion',
              'description': 'Friendly and warm',
              'traits': {
                'warmth': 85,
                'teasing': 35,
                'guardedness': 15,
                'directness': 60,
                'expressiveness': 75,
                'affection': 80,
                'formality': 25,
                'verbosity': 60,
              },
            }
          ]),
          200,
        );
      });

      final client = CompanionClient(
        httpClient: mock,
        sessionStore: InMemoryCredentialStore('test_session_token'),
      );
      final presets = await client.listCharacterPresets();
      expect(presets.length, 1);
      expect(presets.first.presetId, 'warm_companion');
      expect(presets.first.traits.warmth, 85);
    });

    test('getNeutralAssistant sends GET to /characters/neutral', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/characters/neutral');
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode({
            'id': 'neutral-assistant',
            'compatibility_alias': 'default',
            'template_version': 1,
            'name': 'Neutral Assistant',
            'summary': 'Objective assistant',
            'system_prompt': 'You are neutral.',
            'avatar_asset': 'neutral_avatar',
            'is_neutral_fallback': true,
            'traits': null,
            'lore': '',
          }),
          200,
        );
      });

      final client = CompanionClient(
        httpClient: mock,
        sessionStore: InMemoryCredentialStore('test_session_token'),
      );
      final neutral = await client.getNeutralAssistant();
      expect(neutral.id, 'neutral-assistant');
      expect(neutral.isNeutralFallback, isTrue);
      expect(neutral.traits, isNull);
    });

    test('getActiveCharacterState, selectActiveCharacter, and resetActiveCharacterToNeutral', () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/api/v1/characters/active' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'profile_id': 'prof-1',
              'is_neutral_fallback': true,
              'active_character_id': 'neutral-assistant',
              'active_character_instance_id': null,
              'neutral_fallback': {
                'id': 'neutral-assistant',
                'compatibility_alias': 'default',
                'template_version': 1,
                'name': 'Neutral Assistant',
                'summary': 'Objective assistant',
                'system_prompt': 'Neutral.',
                'avatar_asset': 'neutral_avatar',
                'is_neutral_fallback': true,
                'traits': null,
                'lore': '',
              },
              'active_instance': null,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/characters/active' && request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map;
          expect(body['character_id'], 'inst-custom-1');
          return http.Response(
            jsonEncode({
              'profile_id': 'prof-1',
              'is_neutral_fallback': false,
              'active_character_id': 'inst-custom-1',
              'active_character_instance_id': 'inst-custom-1',
              'neutral_fallback': {
                'id': 'neutral-assistant',
                'compatibility_alias': 'default',
                'template_version': 1,
                'name': 'Neutral Assistant',
                'summary': 'Objective assistant',
                'system_prompt': 'Neutral.',
                'avatar_asset': 'neutral_avatar',
                'is_neutral_fallback': true,
                'traits': null,
                'lore': '',
              },
              'active_instance': {
                'id': 'inst-custom-1',
                'profile_id': 'prof-1',
                'is_legacy_placeholder': false,
                'template_id': 'warm-companion',
                'source_template_version': 1,
                'name': 'Custom Warm',
                'summary': 'My custom warm companion',
                'lore': '',
                'system_prompt': 'Warm prompt',
                'avatar_asset': 'avatar_1',
                'preset_id': 'warm_companion',
                'status': 'active',
                'is_active_for_profile': true,
                'created_at': '2026-11-02T10:00:00Z',
                'updated_at': '2026-11-02T10:00:00Z',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/characters/active/reset-neutral' && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'profile_id': 'prof-1',
              'is_neutral_fallback': true,
              'active_character_id': 'neutral-assistant',
              'active_character_instance_id': null,
              'neutral_fallback': {
                'id': 'neutral-assistant',
                'compatibility_alias': 'default',
                'template_version': 1,
                'name': 'Neutral Assistant',
                'summary': 'Objective assistant',
                'system_prompt': 'Neutral.',
                'avatar_asset': 'neutral_avatar',
                'is_neutral_fallback': true,
                'traits': null,
                'lore': '',
              },
              'active_instance': null,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = CompanionClient(
        httpClient: mock,
        sessionStore: InMemoryCredentialStore('test_session_token'),
      );

      final init = await client.getActiveCharacterState();
      expect(init.isNeutralFallback, isTrue);

      final selected = await client.selectActiveCharacter('inst-custom-1');
      expect(selected.isNeutralFallback, isFalse);
      expect(selected.activeCharacterId, 'inst-custom-1');

      final reset = await client.resetActiveCharacterToNeutral();
      expect(reset.isNeutralFallback, isTrue);
      expect(reset.activeCharacterId, 'neutral-assistant');
    });

    test('Instance CRUD operations', () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/api/v1/characters/instances' && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 'inst-123',
              'profile_id': 'prof-1',
              'is_legacy_placeholder': false,
              'template_id': 'warm-companion',
              'source_template_version': 1,
              'name': 'New Companion',
              'summary': 'Summary',
              'lore': '',
              'system_prompt': 'Prompt',
              'avatar_asset': 'avatar',
              'preset_id': 'warm_companion',
              'status': 'active',
              'is_active_for_profile': false,
              'created_at': '2026-11-02T10:00:00Z',
              'updated_at': '2026-11-02T10:00:00Z',
            }),
            201,
          );
        }
        if (request.url.path == '/api/v1/characters/instances/inst-123' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 'inst-123',
              'profile_id': 'prof-1',
              'is_legacy_placeholder': false,
              'name': 'New Companion',
              'summary': 'Summary',
              'lore': '',
              'system_prompt': 'Prompt',
              'avatar_asset': 'avatar',
              'status': 'active',
              'created_at': '2026-11-02T10:00:00Z',
              'updated_at': '2026-11-02T10:00:00Z',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/characters/instances/inst-123' && request.method == 'PATCH') {
          return http.Response(
            jsonEncode({
              'id': 'inst-123',
              'profile_id': 'prof-1',
              'is_legacy_placeholder': false,
              'name': 'Renamed Companion',
              'summary': 'Summary',
              'lore': '',
              'system_prompt': 'Prompt',
              'avatar_asset': 'avatar',
              'status': 'active',
              'created_at': '2026-11-02T10:00:00Z',
              'updated_at': '2026-11-02T10:00:00Z',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/characters/instances/inst-123' && request.method == 'DELETE') {
          return http.Response('', 204);
        }
        if (request.url.path == '/api/v1/characters/instances' && request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'inst-123',
                'profile_id': 'prof-1',
                'is_legacy_placeholder': false,
                'name': 'Renamed Companion',
                'summary': 'Summary',
                'lore': '',
                'system_prompt': 'Prompt',
                'avatar_asset': 'avatar',
                'status': 'active',
                'created_at': '2026-11-02T10:00:00Z',
                'updated_at': '2026-11-02T10:00:00Z',
              }
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = CompanionClient(
        httpClient: mock,
        sessionStore: InMemoryCredentialStore('test_session_token'),
      );

      final created = await client.createCharacterInstance(
        const CharacterInstanceCreate(templateId: 'warm-companion', name: 'New Companion'),
      );
      expect(created.id, 'inst-123');

      final fetched = await client.getCharacterInstance('inst-123');
      expect(fetched.name, 'New Companion');

      final updated = await client.updateCharacterInstance(
        'inst-123',
        const CharacterInstanceUpdate(name: 'Renamed Companion'),
      );
      expect(updated.name, 'Renamed Companion');

      final instances = await client.listCharacterInstances();
      expect(instances.length, 1);

      await client.deleteCharacterInstance('inst-123');
    });

    test('listCharacterInstances passes include_archived and include_legacy query parameters', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/characters/instances');
        expect(request.url.queryParameters['include_archived'], 'true');
        expect(request.url.queryParameters['include_legacy'], 'true');
        return http.Response(jsonEncode([]), 200);
      });
      final client = CompanionClient(
        httpClient: mock,
        sessionStore: InMemoryCredentialStore('test_session_token'),
      );
      final res = await client.listCharacterInstances(includeLegacy: true);
      expect(res, isEmpty);
    });
  });
}
