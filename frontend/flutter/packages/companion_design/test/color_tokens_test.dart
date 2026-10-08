import 'package:companion_design/companion_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompanionColors', () {
    test('defines valid distinct light and dark tokens', () {
      expect(CompanionColors.lightAppBg, isNot(equals(CompanionColors.darkAppBg)));
      expect(CompanionColors.lightSurfacePrimary, isNot(equals(CompanionColors.darkSurfacePrimary)));
      expect(CompanionColors.glassBlur, equals(16.0));
      expect(CompanionColors.glassOpacityLight, equals(0.78));
      expect(CompanionColors.glassOpacityDark, equals(0.72));
    });

    test('accent presets contain valid label and colors', () {
      expect(AccentPreset.values.length, equals(4));
      for (final preset in AccentPreset.values) {
        expect(preset.label, isNotEmpty);
        expect(preset.primary, isNotNull);
        expect(preset.secondary, isNotNull);
      }
    });
  });
}
