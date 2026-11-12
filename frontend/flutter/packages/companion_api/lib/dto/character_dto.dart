import 'package:meta/meta.dart';

/// Eight continuous personality trait dimensions (0-100).
@immutable
class CharacterTraitVector {
  final int warmth;
  final int teasing;
  final int guardedness;
  final int directness;
  final int expressiveness;
  final int affection;
  final int formality;
  final int verbosity;

  const CharacterTraitVector({
    required this.warmth,
    required this.teasing,
    required this.guardedness,
    required this.directness,
    required this.expressiveness,
    required this.affection,
    required this.formality,
    required this.verbosity,
  });

  factory CharacterTraitVector.fromJson(Map<String, dynamic> json) {
    return CharacterTraitVector(
      warmth: json['warmth'] as int,
      teasing: json['teasing'] as int,
      guardedness: json['guardedness'] as int,
      directness: json['directness'] as int,
      expressiveness: json['expressiveness'] as int,
      affection: json['affection'] as int,
      formality: json['formality'] as int,
      verbosity: json['verbosity'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'warmth': warmth,
        'teasing': teasing,
        'guardedness': guardedness,
        'directness': directness,
        'expressiveness': expressiveness,
        'affection': affection,
        'formality': formality,
        'verbosity': verbosity,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterTraitVector &&
          runtimeType == other.runtimeType &&
          warmth == other.warmth &&
          teasing == other.teasing &&
          guardedness == other.guardedness &&
          directness == other.directness &&
          expressiveness == other.expressiveness &&
          affection == other.affection &&
          formality == other.formality &&
          verbosity == other.verbosity;

  @override
  int get hashCode => Object.hash(
        warmth,
        teasing,
        guardedness,
        directness,
        expressiveness,
        affection,
        formality,
        verbosity,
      );

  @override
  String toString() =>
      'CharacterTraitVector(w: $warmth, t: $teasing, g: $guardedness, d: $directness, e: $expressiveness, a: $affection, f: $formality, v: $verbosity)';
}

/// Baseline configuration for a frozen personality preset.
@immutable
class CharacterPresetOut {
  final String presetId;
  final String label;
  final String description;
  final CharacterTraitVector traits;

  const CharacterPresetOut({
    required this.presetId,
    required this.label,
    required this.description,
    required this.traits,
  });

  factory CharacterPresetOut.fromJson(Map<String, dynamic> json) {
    return CharacterPresetOut(
      presetId: json['preset_id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      traits: CharacterTraitVector.fromJson(Map<String, dynamic>.from(json['traits'] as Map)),
    );
  }

  Map<String, dynamic> toJson() => {
        'preset_id': presetId,
        'label': label,
        'description': description,
        'traits': traits.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterPresetOut &&
          runtimeType == other.runtimeType &&
          presetId == other.presetId &&
          label == other.label &&
          description == other.description &&
          traits == other.traits;

  @override
  int get hashCode => Object.hash(presetId, label, description, traits);

  @override
  String toString() => 'CharacterPresetOut(id: $presetId, label: $label)';
}

/// Application-owned character template.
@immutable
class CharacterTemplateOut {
  final String id;
  final int templateVersion;
  final String name;
  final String summary;
  final String lore;
  final String systemPrompt;
  final String avatarAsset;
  final String? defaultPresetId;
  final bool isNeutralFallback;
  final CharacterTraitVector? traits;
  final String createdAt;
  final String updatedAt;

  const CharacterTemplateOut({
    required this.id,
    required this.templateVersion,
    required this.name,
    required this.summary,
    required this.lore,
    required this.systemPrompt,
    required this.avatarAsset,
    this.defaultPresetId,
    required this.isNeutralFallback,
    this.traits,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CharacterTemplateOut.fromJson(Map<String, dynamic> json) {
    return CharacterTemplateOut(
      id: json['id'] as String,
      templateVersion: json['template_version'] as int,
      name: json['name'] as String,
      summary: json['summary'] as String? ?? '',
      lore: json['lore'] as String? ?? '',
      systemPrompt: json['system_prompt'] as String,
      avatarAsset: json['avatar_asset'] as String? ?? 'default_avatar',
      defaultPresetId: json['default_preset_id'] as String?,
      isNeutralFallback: json['is_neutral_fallback'] as bool? ?? false,
      traits: json['traits'] != null
          ? CharacterTraitVector.fromJson(Map<String, dynamic>.from(json['traits'] as Map))
          : null,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'template_version': templateVersion,
        'name': name,
        'summary': summary,
        'lore': lore,
        'system_prompt': systemPrompt,
        'avatar_asset': avatarAsset,
        if (defaultPresetId != null) 'default_preset_id': defaultPresetId,
        'is_neutral_fallback': isNeutralFallback,
        if (traits != null) 'traits': traits!.toJson(),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterTemplateOut &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          templateVersion == other.templateVersion &&
          name == other.name &&
          summary == other.summary &&
          lore == other.lore &&
          systemPrompt == other.systemPrompt &&
          avatarAsset == other.avatarAsset &&
          defaultPresetId == other.defaultPresetId &&
          isNeutralFallback == other.isNeutralFallback &&
          traits == other.traits &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        templateVersion,
        name,
        summary,
        lore,
        systemPrompt,
        avatarAsset,
        defaultPresetId,
        isNeutralFallback,
        traits,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'CharacterTemplateOut(id: $id, v: $templateVersion, name: $name)';
}

/// Immutable Neutral Assistant fallback definition.
@immutable
class NeutralAssistantOut {
  final String id;
  final String compatibilityAlias;
  final int templateVersion;
  final String name;
  final String summary;
  final String systemPrompt;
  final String avatarAsset;
  final bool isNeutralFallback;
  final CharacterTraitVector? traits;
  final String lore;

  const NeutralAssistantOut({
    this.id = 'neutral-assistant',
    this.compatibilityAlias = 'default',
    this.templateVersion = 1,
    this.name = 'Neutral Assistant',
    this.summary = 'Objective, dependable system assistant fallback.',
    required this.systemPrompt,
    this.avatarAsset = 'neutral_avatar',
    this.isNeutralFallback = true,
    this.traits,
    this.lore = '',
  });

  factory NeutralAssistantOut.fromJson(Map<String, dynamic> json) {
    return NeutralAssistantOut(
      id: json['id'] as String? ?? 'neutral-assistant',
      compatibilityAlias: json['compatibility_alias'] as String? ?? 'default',
      templateVersion: json['template_version'] as int? ?? 1,
      name: json['name'] as String? ?? 'Neutral Assistant',
      summary: json['summary'] as String? ?? '',
      systemPrompt: json['system_prompt'] as String,
      avatarAsset: json['avatar_asset'] as String? ?? 'neutral_avatar',
      isNeutralFallback: json['is_neutral_fallback'] as bool? ?? true,
      traits: json['traits'] != null
          ? CharacterTraitVector.fromJson(Map<String, dynamic>.from(json['traits'] as Map))
          : null,
      lore: json['lore'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'compatibility_alias': compatibilityAlias,
        'template_version': templateVersion,
        'name': name,
        'summary': summary,
        'system_prompt': systemPrompt,
        'avatar_asset': avatarAsset,
        'is_neutral_fallback': isNeutralFallback,
        if (traits != null) 'traits': traits!.toJson(),
        'lore': lore,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NeutralAssistantOut &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          compatibilityAlias == other.compatibilityAlias &&
          templateVersion == other.templateVersion &&
          name == other.name &&
          summary == other.summary &&
          systemPrompt == other.systemPrompt &&
          avatarAsset == other.avatarAsset &&
          isNeutralFallback == other.isNeutralFallback &&
          traits == other.traits &&
          lore == other.lore;

  @override
  int get hashCode => Object.hash(
        id,
        compatibilityAlias,
        templateVersion,
        name,
        summary,
        systemPrompt,
        avatarAsset,
        isNeutralFallback,
        traits,
        lore,
      );

  @override
  String toString() => 'NeutralAssistantOut(id: $id, alias: $compatibilityAlias)';
}

/// Request to instantiate a Profile-owned CharacterInstance snapshot.
@immutable
class CharacterInstanceCreate {
  final String templateId;
  final String? presetId;
  final String? name;
  final String? summary;
  final String? lore;
  final String? systemPrompt;
  final String? avatarAsset;
  final CharacterTraitVector? traits;

  const CharacterInstanceCreate({
    required this.templateId,
    this.presetId,
    this.name,
    this.summary,
    this.lore,
    this.systemPrompt,
    this.avatarAsset,
    this.traits,
  });

  factory CharacterInstanceCreate.fromJson(Map<String, dynamic> json) {
    return CharacterInstanceCreate(
      templateId: json['template_id'] as String,
      presetId: json['preset_id'] as String?,
      name: json['name'] as String?,
      summary: json['summary'] as String?,
      lore: json['lore'] as String?,
      systemPrompt: json['system_prompt'] as String?,
      avatarAsset: json['avatar_asset'] as String?,
      traits: json['traits'] != null
          ? CharacterTraitVector.fromJson(Map<String, dynamic>.from(json['traits'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'template_id': templateId,
        if (presetId != null) 'preset_id': presetId,
        if (name != null) 'name': name,
        if (summary != null) 'summary': summary,
        if (lore != null) 'lore': lore,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        if (avatarAsset != null) 'avatar_asset': avatarAsset,
        if (traits != null) 'traits': traits!.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterInstanceCreate &&
          runtimeType == other.runtimeType &&
          templateId == other.templateId &&
          presetId == other.presetId &&
          name == other.name &&
          summary == other.summary &&
          lore == other.lore &&
          systemPrompt == other.systemPrompt &&
          avatarAsset == other.avatarAsset &&
          traits == other.traits;

  @override
  int get hashCode => Object.hash(
        templateId,
        presetId,
        name,
        summary,
        lore,
        systemPrompt,
        avatarAsset,
        traits,
      );

  @override
  String toString() => 'CharacterInstanceCreate(templateId: $templateId, name: $name)';
}

/// Request to update a Profile-owned CharacterInstance snapshot.
@immutable
class CharacterInstanceUpdate {
  final String? name;
  final String? summary;
  final String? lore;
  final String? systemPrompt;
  final String? avatarAsset;
  final String? presetId;
  final CharacterTraitVector? traits;
  final String? status;

  const CharacterInstanceUpdate({
    this.name,
    this.summary,
    this.lore,
    this.systemPrompt,
    this.avatarAsset,
    this.presetId,
    this.traits,
    this.status,
  });

  factory CharacterInstanceUpdate.fromJson(Map<String, dynamic> json) {
    return CharacterInstanceUpdate(
      name: json['name'] as String?,
      summary: json['summary'] as String?,
      lore: json['lore'] as String?,
      systemPrompt: json['system_prompt'] as String?,
      avatarAsset: json['avatar_asset'] as String?,
      presetId: json['preset_id'] as String?,
      traits: json['traits'] != null
          ? CharacterTraitVector.fromJson(Map<String, dynamic>.from(json['traits'] as Map))
          : null,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (summary != null) 'summary': summary,
        if (lore != null) 'lore': lore,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        if (avatarAsset != null) 'avatar_asset': avatarAsset,
        if (presetId != null) 'preset_id': presetId,
        if (traits != null) 'traits': traits!.toJson(),
        if (status != null) 'status': status,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterInstanceUpdate &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          summary == other.summary &&
          lore == other.lore &&
          systemPrompt == other.systemPrompt &&
          avatarAsset == other.avatarAsset &&
          presetId == other.presetId &&
          traits == other.traits &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        name,
        summary,
        lore,
        systemPrompt,
        avatarAsset,
        presetId,
        traits,
        status,
      );

  @override
  String toString() => 'CharacterInstanceUpdate(name: $name, status: $status)';
}

/// Profile-owned character instance.
@immutable
class CharacterInstanceOut {
  final String id;
  final String profileId;
  final bool isLegacyPlaceholder;
  final String? legacyCharacterId;
  final String? templateId;
  final int? sourceTemplateVersion;
  final String name;
  final String summary;
  final String lore;
  final String systemPrompt;
  final String avatarAsset;
  final String? presetId;
  final CharacterTraitVector? traits;
  final String? currentMood;
  final int? moodIntensity;
  final String? moodUpdatedAt;
  final String status;
  final bool isActiveForProfile;
  final String createdAt;
  final String updatedAt;

  const CharacterInstanceOut({
    required this.id,
    required this.profileId,
    this.isLegacyPlaceholder = false,
    this.legacyCharacterId,
    this.templateId,
    this.sourceTemplateVersion,
    required this.name,
    required this.summary,
    required this.lore,
    required this.systemPrompt,
    required this.avatarAsset,
    this.presetId,
    this.traits,
    this.currentMood,
    this.moodIntensity,
    this.moodUpdatedAt,
    required this.status,
    this.isActiveForProfile = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String? get moodEmoji {
    switch (currentMood) {
      case 'calm':
        return '😌';
      case 'cheerful':
        return '😊';
      case 'playful':
        return '😜';
      case 'thoughtful':
        return '🤔';
      case 'empathetic':
        return '🥺';
      case 'curious':
        return '✨';
      case 'attentive':
        return '🎯';
      default:
        return null;
    }
  }

  String? get moodLabel {
    switch (currentMood) {
      case 'calm':
        return 'Calm';
      case 'cheerful':
        return 'Cheerful';
      case 'playful':
        return 'Playful';
      case 'thoughtful':
        return 'Thoughtful';
      case 'empathetic':
        return 'Empathetic';
      case 'curious':
        return 'Curious';
      case 'attentive':
        return 'Attentive';
      default:
        return null;
    }
  }

  String? get moodBadgeText {
    final emoji = moodEmoji;
    final label = moodLabel;
    if (emoji == null || label == null) return null;
    return '$emoji $label';
  }

  factory CharacterInstanceOut.fromJson(Map<String, dynamic> json) {
    return CharacterInstanceOut(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      isLegacyPlaceholder: json['is_legacy_placeholder'] as bool? ?? false,
      legacyCharacterId: json['legacy_character_id'] as String?,
      templateId: json['template_id'] as String?,
      sourceTemplateVersion: json['source_template_version'] as int?,
      name: json['name'] as String,
      summary: json['summary'] as String? ?? '',
      lore: json['lore'] as String? ?? '',
      systemPrompt: json['system_prompt'] as String,
      avatarAsset: json['avatar_asset'] as String? ?? 'default_avatar',
      presetId: json['preset_id'] as String?,
      traits: json['traits'] != null
          ? CharacterTraitVector.fromJson(Map<String, dynamic>.from(json['traits'] as Map))
          : null,
      currentMood: json['current_mood'] as String?,
      moodIntensity: json['mood_intensity'] as int?,
      moodUpdatedAt: json['mood_updated_at'] as String?,
      status: json['status'] as String,
      isActiveForProfile: json['is_active_for_profile'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'is_legacy_placeholder': isLegacyPlaceholder,
        if (legacyCharacterId != null) 'legacy_character_id': legacyCharacterId,
        if (templateId != null) 'template_id': templateId,
        if (sourceTemplateVersion != null) 'source_template_version': sourceTemplateVersion,
        'name': name,
        'summary': summary,
        'lore': lore,
        'system_prompt': systemPrompt,
        'avatar_asset': avatarAsset,
        if (presetId != null) 'preset_id': presetId,
        if (traits != null) 'traits': traits!.toJson(),
        if (currentMood != null) 'current_mood': currentMood,
        if (moodIntensity != null) 'mood_intensity': moodIntensity,
        if (moodUpdatedAt != null) 'mood_updated_at': moodUpdatedAt,
        'status': status,
        'is_active_for_profile': isActiveForProfile,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterInstanceOut &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          profileId == other.profileId &&
          isLegacyPlaceholder == other.isLegacyPlaceholder &&
          legacyCharacterId == other.legacyCharacterId &&
          templateId == other.templateId &&
          sourceTemplateVersion == other.sourceTemplateVersion &&
          name == other.name &&
          summary == other.summary &&
          lore == other.lore &&
          systemPrompt == other.systemPrompt &&
          avatarAsset == other.avatarAsset &&
          presetId == other.presetId &&
          traits == other.traits &&
          currentMood == other.currentMood &&
          moodIntensity == other.moodIntensity &&
          moodUpdatedAt == other.moodUpdatedAt &&
          status == other.status &&
          isActiveForProfile == other.isActiveForProfile &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        profileId,
        isLegacyPlaceholder,
        legacyCharacterId,
        templateId,
        sourceTemplateVersion,
        name,
        summary,
        lore,
        systemPrompt,
        avatarAsset,
        presetId,
        traits,
        currentMood,
        moodIntensity,
        moodUpdatedAt,
        status,
        isActiveForProfile,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'CharacterInstanceOut(id: $id, name: $name, status: $status)';
}

/// Active character state for the authenticated Profile.
@immutable
class ActiveCharacterStateOut {
  final String profileId;
  final bool isNeutralFallback;
  final String activeCharacterId;
  final String? activeCharacterInstanceId;
  final NeutralAssistantOut neutralFallback;
  final CharacterInstanceOut? activeInstance;

  const ActiveCharacterStateOut({
    required this.profileId,
    required this.isNeutralFallback,
    required this.activeCharacterId,
    this.activeCharacterInstanceId,
    required this.neutralFallback,
    this.activeInstance,
  });

  factory ActiveCharacterStateOut.fromJson(Map<String, dynamic> json) {
    return ActiveCharacterStateOut(
      profileId: json['profile_id'] as String,
      isNeutralFallback: json['is_neutral_fallback'] as bool? ?? false,
      activeCharacterId: json['active_character_id'] as String,
      activeCharacterInstanceId: json['active_character_instance_id'] as String?,
      neutralFallback: NeutralAssistantOut.fromJson(Map<String, dynamic>.from(json['neutral_fallback'] as Map)),
      activeInstance: json['active_instance'] != null
          ? CharacterInstanceOut.fromJson(Map<String, dynamic>.from(json['active_instance'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'is_neutral_fallback': isNeutralFallback,
        'active_character_id': activeCharacterId,
        if (activeCharacterInstanceId != null) 'active_character_instance_id': activeCharacterInstanceId,
        'neutral_fallback': neutralFallback.toJson(),
        if (activeInstance != null) 'active_instance': activeInstance!.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveCharacterStateOut &&
          runtimeType == other.runtimeType &&
          profileId == other.profileId &&
          isNeutralFallback == other.isNeutralFallback &&
          activeCharacterId == other.activeCharacterId &&
          activeCharacterInstanceId == other.activeCharacterInstanceId &&
          neutralFallback == other.neutralFallback &&
          activeInstance == other.activeInstance;

  @override
  int get hashCode => Object.hash(
        profileId,
        isNeutralFallback,
        activeCharacterId,
        activeCharacterInstanceId,
        neutralFallback,
        activeInstance,
      );

  @override
  String toString() =>
      'ActiveCharacterStateOut(profileId: $profileId, active: $activeCharacterId, neutral: $isNeutralFallback)';
}

/// Request to select active character.
@immutable
class ActiveCharacterSelectRequest {
  final String characterId;

  const ActiveCharacterSelectRequest({required this.characterId});

  factory ActiveCharacterSelectRequest.fromJson(Map<String, dynamic> json) {
    return ActiveCharacterSelectRequest(characterId: json['character_id'] as String);
  }

  Map<String, dynamic> toJson() => {'character_id': characterId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveCharacterSelectRequest &&
          runtimeType == other.runtimeType &&
          characterId == other.characterId;

  @override
  int get hashCode => characterId.hashCode;

  @override
  String toString() => 'ActiveCharacterSelectRequest(characterId: $characterId)';
}
