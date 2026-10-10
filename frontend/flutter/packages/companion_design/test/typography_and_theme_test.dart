import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompanionTypography', () {
    test('defines required typographic hierarchy', () {
      expect(CompanionTypography.display.fontSize, equals(32.0));
      expect(CompanionTypography.titleLarge.fontSize, equals(24.0));
      expect(CompanionTypography.titleMedium.fontSize, equals(18.0));
      expect(CompanionTypography.titleSmall.fontSize, equals(16.0));
      expect(CompanionTypography.bodyLarge.fontSize, equals(15.0));
      expect(CompanionTypography.bodyMedium.fontSize, equals(14.0));
      expect(CompanionTypography.bodySmall.fontSize, equals(12.0));
      expect(CompanionTypography.caption.fontSize, equals(11.0));
    });
  });

  group('CompanionLayoutTokens', () {
    test('defines consistent spacing and radius scale', () {
      expect(CompanionSpacing.none, equals(0.0));
      expect(CompanionSpacing.xs, equals(4.0));
      expect(CompanionSpacing.sm, equals(8.0));
      expect(CompanionSpacing.md, equals(12.0));
      expect(CompanionSpacing.lg, equals(16.0));
      expect(CompanionSpacing.xl, equals(24.0));
      expect(CompanionSpacing.xxl, equals(32.0));

      expect(CompanionRadius.sm, equals(6.0));
      expect(CompanionRadius.md, equals(10.0));
      expect(CompanionRadius.lg, equals(14.0));
      expect(CompanionRadius.xl, equals(18.0));
      expect(CompanionRadius.full, equals(999.0));
    });

    test('defines elevation shadows', () {
      expect(CompanionShadows.lightRaised, isNotEmpty);
      expect(CompanionShadows.lightElevated, isNotEmpty);
      expect(CompanionShadows.darkRaised, isNotEmpty);
      expect(CompanionShadows.darkElevated, isNotEmpty);
    });
  });

  group('CompanionTheme & Extension', () {
    test('creates valid light and dark ThemeData with extension', () {
      final lightTheme = CompanionTheme.light(preset: AccentPreset.cobaltIndigo);
      expect(lightTheme.brightness, equals(Brightness.light));
      final lightExt = lightTheme.extension<CompanionThemeExtension>();
      expect(lightExt, isNotNull);
      expect(lightExt!.accent, equals(AccentPreset.cobaltIndigo.primary));
      expect(lightExt.glassBlur, equals(16.0));

      final darkTheme = CompanionTheme.dark(preset: AccentPreset.emeraldTeal);
      expect(darkTheme.brightness, equals(Brightness.dark));
      final darkExt = darkTheme.extension<CompanionThemeExtension>();
      expect(darkExt, isNotNull);
      expect(darkExt!.accent, equals(AccentPreset.emeraldTeal.secondary));
      expect(darkExt.glassBlur, equals(16.0));
    });

    test('supports copyWith and lerp interpolation', () {
      final base = CompanionThemeExtension.light(preset: AccentPreset.oceanSky);
      final modified = base.copyWith(glassBlur: 24.0);
      expect(modified.glassBlur, equals(24.0));
      expect(modified.accent, equals(base.accent));

      final dark = CompanionThemeExtension.dark(preset: AccentPreset.oceanSky);
      final interpolated = base.lerp(dark, 0.5);
      expect(interpolated.glassBlur, equals(16.0));
      expect(interpolated.appBg, isNot(equals(base.appBg)));
      expect(interpolated.appBg, isNot(equals(dark.appBg)));
    });
  });
}
