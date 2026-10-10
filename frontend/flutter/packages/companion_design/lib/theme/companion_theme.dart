import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/layout_tokens.dart';
import '../tokens/typography.dart';
import 'companion_theme_extension.dart';

/// Central theme builder configuring Material 3 ThemeData with SoftGlass extensions.
abstract final class CompanionTheme {
  /// Builds the light theme with the specified [AccentPreset].
  static ThemeData light({AccentPreset preset = AccentPreset.oceanSky}) {
    final ext = CompanionThemeExtension.light(preset: preset);
    final colorScheme = ColorScheme.light(
      primary: ext.accent,
      secondary: ext.accentSecondary,
      surface: ext.surfacePrimary,
      surfaceContainerHighest: ext.surfaceSecondary,
      error: ext.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: ext.textPrimary,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ext.appBg,
      cardColor: ext.surfacePrimary,
      dividerColor: ext.borderSubtle,
      textTheme: _buildTextTheme(ext.textPrimary, ext.textSecondary),
      extensions: [ext],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: CompanionTypography.titleMedium.copyWith(color: ext.textPrimary),
        iconTheme: IconThemeData(color: ext.textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ext.accent,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: CompanionRadius.borderMd),
          textStyle: CompanionTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ext.textPrimary,
          side: BorderSide(color: ext.borderSubtle),
          shape: const RoundedRectangleBorder(borderRadius: CompanionRadius.borderMd),
          textStyle: CompanionTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  /// Builds the dark theme with the specified [AccentPreset].
  static ThemeData dark({AccentPreset preset = AccentPreset.oceanSky}) {
    final ext = CompanionThemeExtension.dark(preset: preset);
    final colorScheme = ColorScheme.dark(
      primary: ext.accent,
      secondary: ext.accentSecondary,
      surface: ext.surfacePrimary,
      surfaceContainerHighest: ext.surfaceSecondary,
      error: ext.danger,
      onPrimary: ext.appBg,
      onSecondary: Colors.white,
      onSurface: ext.textPrimary,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ext.appBg,
      cardColor: ext.surfacePrimary,
      dividerColor: ext.borderSubtle,
      textTheme: _buildTextTheme(ext.textPrimary, ext.textSecondary),
      extensions: [ext],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: CompanionTypography.titleMedium.copyWith(color: ext.textPrimary),
        iconTheme: IconThemeData(color: ext.textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ext.accent,
          foregroundColor: ext.appBg,
          shape: const RoundedRectangleBorder(borderRadius: CompanionRadius.borderMd),
          textStyle: CompanionTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ext.textPrimary,
          side: BorderSide(color: ext.borderSubtle),
          shape: const RoundedRectangleBorder(borderRadius: CompanionRadius.borderMd),
          textStyle: CompanionTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: CompanionTypography.display.copyWith(color: primary),
      titleLarge: CompanionTypography.titleLarge.copyWith(color: primary),
      titleMedium: CompanionTypography.titleMedium.copyWith(color: primary),
      titleSmall: CompanionTypography.titleSmall.copyWith(color: primary),
      bodyLarge: CompanionTypography.bodyLarge.copyWith(color: primary),
      bodyMedium: CompanionTypography.bodyMedium.copyWith(color: secondary),
      bodySmall: CompanionTypography.bodySmall.copyWith(color: secondary),
      labelSmall: CompanionTypography.caption.copyWith(color: secondary),
    );
  }
}
