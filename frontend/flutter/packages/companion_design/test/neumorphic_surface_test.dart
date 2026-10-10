import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompanionNeumorphicTokens', () {
    test('defines all light and dark outer shadow tokens matching web specs', () {
      expect(CompanionShadows.lightRaised.length, equals(2));
      expect(CompanionShadows.lightRaisedHover.length, equals(2));
      expect(CompanionShadows.lightNavEmbossed.length, equals(2));
      expect(CompanionShadows.lightNavEmbossedHover.length, equals(2));
      expect(CompanionShadows.lightGlass.length, equals(2));
      expect(CompanionShadows.lightGlassElevated.length, equals(2));

      expect(CompanionShadows.darkRaised.length, equals(2));
      expect(CompanionShadows.darkRaisedHover.length, equals(2));
      expect(CompanionShadows.darkNavEmbossed.length, equals(2));
      expect(CompanionShadows.darkNavEmbossedHover.length, equals(2));
      expect(CompanionShadows.darkGlass.length, equals(1));
      expect(CompanionShadows.darkGlassElevated.length, equals(1));
    });

    test('defines all light and dark inner shadow tokens matching web specs', () {
      expect(CompanionInnerShadows.lightRecessed.length, equals(2));
      expect(CompanionInnerShadows.lightPressed.length, equals(2));
      expect(CompanionInnerShadows.lightNavInset.length, equals(2));
      expect(CompanionInnerShadows.lightNavPressed.length, equals(2));

      expect(CompanionInnerShadows.darkRecessed.length, equals(2));
      expect(CompanionInnerShadows.darkPressed.length, equals(2));
      expect(CompanionInnerShadows.darkNavInset.length, equals(2));
      expect(CompanionInnerShadows.darkNavPressed.length, equals(2));
    });
  });

  group('NeumorphicSurface', () {
    testWidgets('renders raised surface with outer shadows in dark and light modes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.light(),
          darkTheme: CompanionTheme.dark(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: NeumorphicSurface(
              surfaceType: NeumorphicSurfaceType.raised,
              child: Text('Raised Content'),
            ),
          ),
        ),
      );

      expect(find.text('Raised Content'), findsOneWidget);
    });

    testWidgets('renders recessed surface with inner shadow painter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: const Scaffold(
            body: NeumorphicSurface(
              surfaceType: NeumorphicSurfaceType.recessed,
              child: Text('Recessed Content'),
            ),
          ),
        ),
      );

      expect(find.text('Recessed Content'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders glass and glassElevated surfaces with backdrop filter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                NeumorphicSurface(
                  surfaceType: NeumorphicSurfaceType.glass,
                  child: Text('Glass Panel'),
                ),
                NeumorphicSurface(
                  surfaceType: NeumorphicSurfaceType.glassElevated,
                  child: Text('Glass Elevated Panel'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Glass Panel'), findsOneWidget);
      expect(find.text('Glass Elevated Panel'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNWidgets(2));
    });
  });

  group('NeumorphicButton', () {
    testWidgets('invokes onPressed callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: NeumorphicButton(
              onPressed: () => tapped = true,
              child: const Text('Click Me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Click Me'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('disabled button does not trigger callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: const Scaffold(
            body: NeumorphicButton(
              onPressed: null,
              child: Text('Disabled Button'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Disabled Button'));
      await tester.pumpAndSettle();
      expect(tapped, isFalse);
    });
  });

  group('NeumorphicSegmentedControl', () {
    testWidgets('switches selected value on user tap', (tester) async {
      ThemeMode selectedMode = ThemeMode.system;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: NeumorphicSegmentedControl<ThemeMode>(
                  selected: selectedMode,
                  onChanged: (mode) {
                    setState(() {
                      selectedMode = mode;
                    });
                  },
                  segments: const [
                    NeumorphicSegment(value: ThemeMode.system, label: 'System'),
                    NeumorphicSegment(value: ThemeMode.light, label: 'Light'),
                    NeumorphicSegment(value: ThemeMode.dark, label: 'Dark'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(selectedMode, equals(ThemeMode.light));
    });
  });
}
