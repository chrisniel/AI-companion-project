import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoftGlassPanel', () {
    testWidgets('renders child content properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: const Scaffold(
            body: SoftGlassPanel(
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('respects custom dimensions and radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.light(),
          home: const Scaffold(
            body: SoftGlassPanel(
              width: 200,
              height: 100,
              borderRadius: CompanionRadius.borderSm,
              child: SizedBox(),
            ),
          ),
        ),
      );

      final boxFinder = find.byType(SoftGlassPanel);
      expect(boxFinder, findsOneWidget);
      final size = tester.getSize(boxFinder);
      expect(size.width, equals(200.0));
      expect(size.height, equals(100.0));
    });

    testWidgets('can disable blur when blur is 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: const Scaffold(
            body: SoftGlassPanel(
              blur: 0,
              child: Text('No Blur'),
            ),
          ),
        ),
      );

      expect(find.text('No Blur'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
