import 'package:companion_api/companion_api.dart';
import 'package:test/test.dart';

void main() {
  group('ConversationCreate Character Foundation', () {
    test('omitted characterId serializes without character_id property', () {
      const create = ConversationCreate(title: 'Chat Without Explicit Character');
      final json = create.toJson();
      expect(json.containsKey('character_id'), isFalse);
      expect(json['title'], 'Chat Without Explicit Character');
    });

    test('explicit default characterId serializes character_id', () {
      const create = ConversationCreate(title: 'Default Chat', characterId: 'default');
      final json = create.toJson();
      expect(json['character_id'], 'default');
    });

    test('explicit instanceId serializes character_id', () {
      const create = ConversationCreate(title: 'Instance Chat', characterId: 'inst-custom-123');
      final json = create.toJson();
      expect(json['character_id'], 'inst-custom-123');
    });

    test('ConversationOut deserializes and serializes characterInstanceId', () {
      final json = {
        'id': 'conv-1',
        'title': 'Test Chat',
        'character_id': 'inst-1',
        'character_instance_id': 'inst-1',
        'owner_id': 'user-1',
        'created_at': '2026-11-02T10:00:00Z',
        'updated_at': '2026-11-02T10:00:00Z',
        'message_count': 5,
      };
      final out = ConversationOut.fromJson(json);
      expect(out.characterId, 'inst-1');
      expect(out.characterInstanceId, 'inst-1');
      expect(out.toJson()['character_instance_id'], 'inst-1');
    });
  });

  group('Character DTOs', () {
    test('CharacterTraitVector round trip and equality', () {
      const traits = CharacterTraitVector(
        warmth: 85,
        teasing: 35,
        guardedness: 15,
        directness: 60,
        expressiveness: 75,
        affection: 80,
        formality: 25,
        verbosity: 60,
      );
      final json = traits.toJson();
      final parsed = CharacterTraitVector.fromJson(json);
      expect(parsed, equals(traits));
      expect(parsed.hashCode, equals(traits.hashCode));
      expect(parsed.warmth, 85);
    });

    test('CharacterPresetOut round trip', () {
      final json = {
        'preset_id': 'warm_companion',
        'label': 'Warm Companion',
        'description': 'Affectionate and empathetic',
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
      };
      final preset = CharacterPresetOut.fromJson(json);
      expect(preset.presetId, 'warm_companion');
      expect(preset.traits.warmth, 85);
      expect(preset.toJson(), json);
    });

    test('NeutralAssistantOut has null traits and immutable fallback properties', () {
      final json = {
        'id': 'neutral-assistant',
        'compatibility_alias': 'default',
        'template_version': 1,
        'name': 'Neutral Assistant',
        'summary': 'Objective assistant',
        'system_prompt': 'You are a neutral assistant.',
        'avatar_asset': 'neutral_avatar',
        'is_neutral_fallback': true,
        'traits': null,
        'lore': '',
      };
      final neutral = NeutralAssistantOut.fromJson(json);
      expect(neutral.id, 'neutral-assistant');
      expect(neutral.compatibilityAlias, 'default');
      expect(neutral.isNeutralFallback, isTrue);
      expect(neutral.traits, isNull);
      expect(neutral.toJson()['traits'], isNull);
    });

    test('CharacterTemplateOut round trip', () {
      final json = {
        'id': 'warm-companion',
        'template_version': 1,
        'name': 'Warm Companion',
        'summary': 'Warm and friendly',
        'lore': '',
        'system_prompt': 'You are warm.',
        'avatar_asset': 'warm_avatar',
        'default_preset_id': 'warm_companion',
        'is_neutral_fallback': false,
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
        'created_at': '2026-11-02T10:00:00Z',
        'updated_at': '2026-11-02T10:00:00Z',
      };
      final tmpl = CharacterTemplateOut.fromJson(json);
      expect(tmpl.id, 'warm-companion');
      expect(tmpl.traits?.warmth, 85);
      expect(tmpl.toJson(), json);
    });

    test('CharacterInstanceCreate and Update round trips', () {
      const create = CharacterInstanceCreate(
        templateId: 'warm-companion',
        name: 'My Warm Companion',
        presetId: 'warm_companion',
      );
      expect(create.toJson()['template_id'], 'warm-companion');
      expect(create.toJson()['name'], 'My Warm Companion');

      const update = CharacterInstanceUpdate(
        name: 'Updated Name',
        status: 'archived',
      );
      expect(update.toJson()['name'], 'Updated Name');
      expect(update.toJson()['status'], 'archived');
      expect(update.toJson().containsKey('lore'), isFalse);
    });

    test('ActiveCharacterStateOut round trip', () {
      final json = {
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
          'system_prompt': 'You are neutral.',
          'avatar_asset': 'neutral_avatar',
          'is_neutral_fallback': true,
          'traits': null,
          'lore': '',
        },
        'active_instance': null,
      };
      final state = ActiveCharacterStateOut.fromJson(json);
      expect(state.profileId, 'prof-1');
      expect(state.isNeutralFallback, isTrue);
      expect(state.activeCharacterId, 'neutral-assistant');
      expect(state.activeCharacterInstanceId, isNull);
    });
  });
}
