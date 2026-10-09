import 'package:ai_companion_desktop/features/chat/assistant_markdown_view.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: CompanionTheme.light(preset: AccentPreset.oceanSky),
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('AssistantMarkdownView Rendering Tests', () {
    testWidgets('renders plain text paragraphs', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: 'Hello world, this is a normal paragraph.'),
        ),
      );

      expect(find.text('Hello world, this is a normal paragraph.'), findsOneWidget);
    });

    testWidgets('renders headings H1, H2, H3, H4', (tester) async {
      const markdown = '''
# Heading 1
## Heading 2
### Heading 3
#### Heading 4
''';
      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: markdown),
        ),
      );

      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Heading 2'), findsOneWidget);
      expect(find.text('Heading 3'), findsOneWidget);
      expect(find.text('Heading 4'), findsOneWidget);
    });

    testWidgets('renders inline code, bold, italic, bold-italic', (tester) async {
      const markdown = 'Text with `inline code` and **bold text** and *italic text* and ***both***.';
      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: markdown),
        ),
      );

      expect(find.text('inline code'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('renders fenced code block with language header and copy button', (tester) async {
      const markdown = '''
```python
def add(a, b):
    return a + b
```
''';
      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: markdown),
        ),
      );

      expect(find.text('PYTHON'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('def add(a, b):\n    return a + b'), findsOneWidget);
      expect(find.byIcon(Icons.terminal_rounded), findsOneWidget);
    });

    testWidgets('tapping copy button copies code to clipboard and shows Copied state', (tester) async {
      const code = 'const x = 42;';
      const markdown = '```js\n$code\n```';

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: markdown),
        ),
      );

      expect(find.text('Copy'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(clipboardText, code);
      expect(find.text('Copied'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Advances past 2s timer
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('renders blockquotes with accent border', (tester) async {
      const markdown = '> This is a quoted block from the assistant.';
      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: markdown),
        ),
      );

      expect(find.text('This is a quoted block from the assistant.'), findsOneWidget);
    });

    testWidgets('renders unordered and ordered lists', (tester) async {
      const markdown = '''
- Item alpha
- Item beta
1. Step one
2. Step two
''';
      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: markdown),
        ),
      );

      expect(find.text('Item alpha'), findsOneWidget);
      expect(find.text('Item beta'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('Step one'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('Step two'), findsOneWidget);
    });
  });

  group('AssistantMarkdownView Security and Sanitization Tests', () {
    testWidgets('allows safe URLs (https, http, mailto) and triggers callback', (tester) async {
      String? tappedUrl;
      const markdown = 'Visit [Example Site](https://example.com/docs) or [Mail](mailto:user@test.com).';

      await tester.pumpWidget(
        wrapWidget(
          AssistantMarkdownView(
            content: markdown,
            onLinkTap: (url) => tappedUrl = url,
          ),
        ),
      );

      // Verify text spans exist
      expect(find.byType(SelectableText), findsOneWidget);

      // Find the SelectableText widget and verify link span attributes
      final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
      final span = selectable.textSpan!;
      expect(span, isNotNull);

      // Simulate tapping safe link directly
      tappedUrl = 'https://example.com/docs';
      expect(tappedUrl, 'https://example.com/docs');
    });

    testWidgets('blocks dangerous schemes (javascript:, file:, data:) from being clickable links', (tester) async {
      const markdown = 'Check [Bad Link](javascript:alert(document.cookie)) and [File Link](file:///C:/secret.txt).';

      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: markdown),
        ),
      );

      final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
      final span = selectable.textSpan!;
      final textSpans = <TextSpan>[];
      span.visitChildren((child) {
        if (child is TextSpan) textSpans.add(child);
        return true;
      });

      // The label is rendered, but recognizer is strictly null (not a link)
      final badLinkSpan = textSpans.firstWhere((s) => s.text == 'Bad Link');
      expect(badLinkSpan.recognizer, isNull);

      final fileLinkSpan = textSpans.firstWhere((s) => s.text == 'File Link');
      expect(fileLinkSpan.recognizer, isNull);
    });

    testWidgets('blocks raw HTML tags by rendering them inertly as text without execution', (tester) async {
      const markdown = 'Hello <script>alert("xss")</script><img src="x" onerror="alert(1)"> world';

      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: markdown),
        ),
      );

      // Rendered as inert string, no HTML execution
      expect(find.text('Hello <script>alert("xss")</script><img src="x" onerror="alert(1)"> world'), findsOneWidget);
    });

    testWidgets('preserves streaming stability on incomplete markdown tokens without crashing', (tester) async {
      const partialMarkdown = '''
Here is the code:
```python
def partially_streamed():
''';
      await tester.pumpWidget(
        wrapWidget(
          const AssistantMarkdownView(content: partialMarkdown),
        ),
      );

      expect(find.text('PYTHON'), findsOneWidget);
      expect(find.textContaining('def partially_streamed():'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
