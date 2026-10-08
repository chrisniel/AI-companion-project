import 'package:ai_companion_desktop/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders AI Companion desktop foundation screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AiCompanionDesktopApp());

    expect(find.text('AI Companion'), findsOneWidget);
    expect(find.text('Desktop Client Foundation (M1 Batch 1)'), findsOneWidget);
    expect(find.text('Windows Native Scaffolding Active'), findsOneWidget);
  });
}
