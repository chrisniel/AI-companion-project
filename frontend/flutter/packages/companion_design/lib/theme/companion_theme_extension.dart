import 'dart:ui';
import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';

/// ThemeExtension providing semantic color and SoftGlass tokens via BuildContext.
@immutable
class CompanionThemeExtension extends ThemeExtension<CompanionThemeExtension> {
  final Color appBg;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceGlass;
  final Color surfaceGlassBorder;
  final Color surfaceElevated;
  final Color surfaceRecessed;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderHighlight;
  final Color borderSubtle;
  final Color accent;
  final Color accentSecondary;
  final Color accentGlow;
  final Color success;
  final Color warning;
  final Color danger;
  final double glassBlur;

  const CompanionThemeExtension({
    required this.appBg,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceGlass,
    required this.surfaceGlassBorder,
    required this.surfaceElevated,
    required this.surfaceRecessed,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderHighlight,
    required this.borderSubtle,
    required this.accent,
    required this.accentSecondary,
    required this.accentGlow,
    required this.success,
    required this.warning,
    required this.danger,
    required this.glassBlur,
  });

  factory CompanionThemeExtension.light({AccentPreset preset = AccentPreset.oceanSky}) {
    return CompanionThemeExtension(
      appBg: CompanionColors.lightAppBg,
      surfacePrimary: CompanionColors.lightSurfacePrimary,
      surfaceSecondary: CompanionColors.lightSurfaceSecondary,
      surfaceGlass: CompanionColors.lightSurfaceGlass,
      surfaceGlassBorder: CompanionColors.lightSurfaceGlassBorder,
      surfaceElevated: CompanionColors.lightSurfaceElevated,
      surfaceRecessed: CompanionColors.lightSurfaceRecessed,
      textPrimary: CompanionColors.lightTextPrimary,
      textSecondary: CompanionColors.lightTextSecondary,
      textMuted: CompanionColors.lightTextMuted,
      borderHighlight: CompanionColors.lightBorderHighlight,
      borderSubtle: CompanionColors.lightBorderSubtle,
      accent: preset.primary,
      accentSecondary: preset.secondary,
      accentGlow: preset.glow,
      success: CompanionColors.success,
      warning: CompanionColors.warning,
      danger: CompanionColors.danger,
      glassBlur: CompanionColors.glassBlur,
    );
  }

  factory CompanionThemeExtension.dark({AccentPreset preset = AccentPreset.oceanSky}) {
    return CompanionThemeExtension(
      appBg: CompanionColors.darkAppBg,
      surfacePrimary: CompanionColors.darkSurfacePrimary,
      surfaceSecondary: CompanionColors.darkSurfaceSecondary,
      surfaceGlass: CompanionColors.darkSurfaceGlass,
      surfaceGlassBorder: CompanionColors.darkSurfaceGlassBorder,
      surfaceElevated: CompanionColors.darkSurfaceElevated,
      surfaceRecessed: CompanionColors.darkSurfaceRecessed,
      textPrimary: CompanionColors.darkTextPrimary,
      textSecondary: CompanionColors.darkTextSecondary,
      textMuted: CompanionColors.darkTextMuted,
      borderHighlight: CompanionColors.darkBorderHighlight,
      borderSubtle: CompanionColors.darkBorderSubtle,
      accent: preset.secondary,
      accentSecondary: preset.primary,
      accentGlow: preset.glow,
      success: CompanionColors.success,
      warning: CompanionColors.warning,
      danger: CompanionColors.darkDanger,
      glassBlur: CompanionColors.glassBlur,
    );
  }

  @override
  CompanionThemeExtension copyWith({
    Color? appBg,
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? surfaceGlass,
    Color? surfaceGlassBorder,
    Color? surfaceElevated,
    Color? surfaceRecessed,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderHighlight,
    Color? borderSubtle,
    Color? accent,
    Color? accentSecondary,
    Color? accentGlow,
    Color? success,
    Color? warning,
    Color? danger,
    double? glassBlur,
  }) {
    return CompanionThemeExtension(
      appBg: appBg ?? this.appBg,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      surfaceGlassBorder: surfaceGlassBorder ?? this.surfaceGlassBorder,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceRecessed: surfaceRecessed ?? this.surfaceRecessed,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderHighlight: borderHighlight ?? this.borderHighlight,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentGlow: accentGlow ?? this.accentGlow,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      glassBlur: glassBlur ?? this.glassBlur,
    );
  }

  @override
  CompanionThemeExtension lerp(ThemeExtension<CompanionThemeExtension>? other, double t) {
    if (other is! CompanionThemeExtension) return this;
    return CompanionThemeExtension(
      appBg: Color.lerp(appBg, other.appBg, t) ?? appBg,
      surfacePrimary: Color.lerp(surfacePrimary, other.surfacePrimary, t) ?? surfacePrimary,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t) ?? surfaceSecondary,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t) ?? surfaceGlass,
      surfaceGlassBorder: Color.lerp(surfaceGlassBorder, other.surfaceGlassBorder, t) ?? surfaceGlassBorder,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      surfaceRecessed: Color.lerp(surfaceRecessed, other.surfaceRecessed, t) ?? surfaceRecessed,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      borderHighlight: Color.lerp(borderHighlight, other.borderHighlight, t) ?? borderHighlight,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t) ?? accentSecondary,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t) ?? accentGlow,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      glassBlur: lerpDouble(glassBlur, other.glassBlur, t) ?? glassBlur,
    );
  }
}
