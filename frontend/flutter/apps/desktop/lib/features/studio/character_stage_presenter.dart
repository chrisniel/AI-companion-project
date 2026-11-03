import 'package:companion_api/companion_api.dart';
import 'package:flutter/material.dart';

/// Presentation mode boundary isolating 2D rendering from future 3D/VRM/Live2D engines (ADR-0012).
enum CharacterStageRenderMode {
  portrait2d,
  live2dPlaceholder,
  vrm3dPlaceholder,
}

/// Thematic backdrops available for the Character Studio customization showcase.
enum StudioBackdropPreset {
  cozyStudio(
    label: 'Cozy Studio',
    description: 'Warm ambient light, natural wood, and comforting glow',
    assetPath: 'assets/studio/backdrop_cozy_studio.png',
    gradientColors: [Color(0xFF1E1714), Color(0xFF2C221C), Color(0xFF140F0D)],
  ),
  cyberLounge(
    label: 'Cyber Lounge',
    description: 'Neon cyan, indigo pulse, and dark glass reflections',
    assetPath: 'assets/studio/backdrop_cyber_lounge.png',
    gradientColors: [Color(0xFF0B1021), Color(0xFF151C38), Color(0xFF070B18)],
  ),
  twilightBalcony(
    label: 'Twilight Balcony',
    description: 'Sunset amber, twilight violet, and evening sky',
    assetPath: 'assets/studio/backdrop_twilight_balcony.png',
    gradientColors: [Color(0xFF221327), Color(0xFF381C3F), Color(0xFF140B19)],
  ),
  minimalistVault(
    label: 'Minimalist Vault',
    description: 'Clean geometric slate, soft ambient mist, and architectural poise',
    assetPath: 'assets/studio/backdrop_minimalist_vault.png',
    gradientColors: [Color(0xFF12161F), Color(0xFF1E2433), Color(0xFF0C0F16)],
  );

  const StudioBackdropPreset({
    required this.label,
    required this.description,
    required this.assetPath,
    required this.gradientColors,
  });

  final String label;
  final String description;
  final String assetPath;
  final List<Color> gradientColors;
}

/// Formatted local tendency summary for the Right Inspector's Illustrative Style card.
@immutable
class IllustrativeStyleSummary {
  final String toneLabel;
  final String expressionLabel;
  final String deliveryLabel;
  final String registerLabel;
  final String? dynamicLabel;
  final bool autonomyGuardActive;
  final String autonomyGuardText;

  const IllustrativeStyleSummary({
    required this.toneLabel,
    required this.expressionLabel,
    required this.deliveryLabel,
    required this.registerLabel,
    this.dynamicLabel,
    required this.autonomyGuardActive,
    this.autonomyGuardText = 'Autonomy Guard: Non-coercive, respectful boundaries',
  });
}

/// Visual presentation spec passed to the Character Showcase Stage.
@immutable
class CharacterStageVisualSpec {
  final CharacterStageRenderMode renderMode;
  final String avatarAsset;
  final String displayName;
  final String badgeText;
  final double zoomLevel;
  final Offset panOffset;
  final StudioBackdropPreset backdropPreset;

  const CharacterStageVisualSpec({
    this.renderMode = CharacterStageRenderMode.portrait2d,
    required this.avatarAsset,
    required this.displayName,
    this.badgeText = '',
    this.zoomLevel = 1.0,
    this.panOffset = Offset.zero,
    this.backdropPreset = StudioBackdropPreset.cozyStudio,
  });
}

/// Presenter coordinating visual presentation, zoom state, and illustrative summary logic.
class CharacterStagePresenter {
  /// Resolves the raster asset path for a given avatar identifier.
  ///
  /// Supports Migration 009 seeded avatar identifiers:
  /// - 'neutral_avatar', 'avatar_neutral', 'neutral-assistant', 'default_avatar'
  /// - 'warm_companion_avatar', 'avatar_warm', 'warm_companion'
  /// - 'playful_companion_avatar', 'avatar_playful', 'playful'
  /// - 'formal_advisor_avatar', 'avatar_formal', 'formal_advisor'
  ///
  /// Returns null for unknown/unsupported keys so the stage renders a truthful
  /// neutral silhouette fallback rather than displaying an unrelated Character portrait.
  static String? resolveAvatarPath(String asset) {
    switch (asset) {
      case 'neutral_avatar':
      case 'avatar_neutral':
      case 'neutral-assistant':
      case 'default_avatar':
        return 'assets/studio/portrait_neutral_assistant.png';
      case 'warm_companion_avatar':
      case 'avatar_warm':
      case 'warm_companion':
        return 'assets/studio/portrait_warm_companion.png';
      case 'playful_companion_avatar':
      case 'avatar_playful':
      case 'playful':
        return 'assets/studio/portrait_playful.png';
      case 'formal_advisor_avatar':
      case 'avatar_formal':
      case 'formal_advisor':
        return 'assets/studio/portrait_formal_advisor.png';
      default:
        if (asset.startsWith('assets/')) return asset;
        return null;
    }
  }

  static String getTraitBandLabel(int value) {
    if (value <= 19) return 'Very Low';
    if (value <= 39) return 'Low';
    if (value <= 59) return 'Balanced';
    if (value <= 79) return 'High';
    return 'Very High';
  }

  static IllustrativeStyleSummary buildIllustrativeStyleSummary(
    CharacterTraitVector traits,
    String? presetId,
  ) {
    final tone = '${getTraitBandLabel(traits.warmth)} Warmth · ${getTraitBandLabel(traits.affection)} Affection';
    final expr = '${getTraitBandLabel(traits.guardedness)} Guardedness · ${getTraitBandLabel(traits.expressiveness)} Expressiveness';
    final deliv = '${getTraitBandLabel(traits.teasing)} Teasing · ${getTraitBandLabel(traits.directness)} Directness';
    final reg = '${getTraitBandLabel(traits.formality)} Formality · ${getTraitBandLabel(traits.verbosity)} Verbosity';

    String? dynamic;
    if (traits.guardedness >= 65 && traits.teasing >= 60 && (traits.warmth >= 55 || traits.affection >= 55)) {
      dynamic = 'Tsundere (Guarded Banter)';
    } else if (traits.guardedness >= 65 && traits.directness <= 45 && traits.teasing <= 35 && (traits.warmth >= 60 || traits.affection >= 60)) {
      dynamic = 'Dandere (Shy Devotion)';
    } else if (traits.guardedness >= 65 && traits.expressiveness <= 35 && traits.directness >= 65) {
      dynamic = 'Kuudere (Stoic Care)';
    } else if (traits.formality >= 75 && traits.directness >= 75 && traits.teasing <= 25) {
      dynamic = 'Formal Advisor (Analytical Precision)';
    }

    final autonomyGuard = traits.affection >= 80 || presetId == 'yandere';

    return IllustrativeStyleSummary(
      toneLabel: tone,
      expressionLabel: expr,
      deliveryLabel: deliv,
      registerLabel: reg,
      dynamicLabel: dynamic,
      autonomyGuardActive: autonomyGuard,
    );
  }
}
