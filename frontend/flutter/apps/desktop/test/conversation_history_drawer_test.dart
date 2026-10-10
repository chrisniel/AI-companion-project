import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion_desktop/features/chat/conversation_history_drawer.dart';

void main() {
  final sampleConversations = [
    const ConversationOut(
      id: 'conv-1',
      title: 'First Chat with Antigravity',
      characterId: 'default',
      ownerId: 'owner-1',
      createdAt: '2026-10-09T10:00:00Z',
      updatedAt: '2026-10-09T10:05:00Z',
      messageCount: 5,
    ),
    const ConversationOut(
      id: 'conv-2',
      title: 'Debugging Python runtime',
      characterId: 'default',
      ownerId: 'owner-1',
      createdAt: '2026-10-08T15:30:00Z',
      updatedAt: '2026-10-08T15:45:00Z',
      messageCount: 2,
    ),
  ];

  Widget buildTestableWidget({
    bool isOpen = true,
    VoidCallback? onClose,
    String? activeConversationId = 'conv-1',
    ValueChanged<ConversationOut>? onSelectConversation,
    VoidCallback? onNewConversation,
    Future<void> Function(String)? onDeleteConversation,
    List<ConversationOut>? conversations,
    bool isLoading = false,
    String? errorMessage,
    VoidCallback? onRetry,
    bool isActionsDisabled = false,
    bool isSwitchingDisabled = false,
  }) {
    return MaterialApp(
      theme: CompanionTheme.dark(),
      home: Scaffold(
        body: ConversationHistoryDrawer(
          isOpen: isOpen,
          onClose: onClose ?? () {},
          activeConversationId: activeConversationId,
          onSelectConversation: onSelectConversation ?? (_) {},
          onNewConversation: onNewConversation ?? () {},
          onDeleteConversation: onDeleteConversation,
          conversations: conversations ?? sampleConversations,
          isLoading: isLoading,
          errorMessage: errorMessage,
          onRetry: onRetry,
          isActionsDisabled: isActionsDisabled,
          isSwitchingDisabled: isSwitchingDisabled,
        ),
      ),
    );
  }

  group('ConversationHistoryDrawer Widget Tests', () {
    testWidgets('renders nothing when isOpen is false', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isOpen: false));
      expect(find.text('Conversation History'), findsNothing);
    });

    testWidgets('renders conversations list, session count, and badges when open', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isOpen: true));
      await tester.pumpAndSettle();

      expect(find.text('Conversation History'), findsOneWidget);
      expect(find.text('2 Local Sessions'), findsOneWidget);
      expect(find.text('First Chat with Antigravity'), findsOneWidget);
      expect(find.text('5 msgs'), findsOneWidget);
      expect(find.text('Debugging Python runtime'), findsOneWidget);
      expect(find.text('2 msgs'), findsOneWidget);
      expect(find.text('Local conversation storage'), findsOneWidget);
    });

    testWidgets('filters conversations by search query', (tester) async {
      await tester.pumpWidget(buildTestableWidget(isOpen: true));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'debugging');
      await tester.pumpAndSettle();

      expect(find.text('Debugging Python runtime'), findsOneWidget);
      expect(find.text('First Chat with Antigravity'), findsNothing);

      // Search with non-matching term
      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pumpAndSettle();

      expect(find.text('No conversations found matching "nonexistent"'), findsOneWidget);
    });

    testWidgets('selecting conversation calls onSelectConversation and onClose', (tester) async {
      ConversationOut? selected;
      bool closed = false;

      await tester.pumpWidget(
        buildTestableWidget(
          isOpen: true,
          onSelectConversation: (conv) => selected = conv,
          onClose: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Debugging Python runtime'));
      await tester.pumpAndSettle();

      expect(selected?.id, 'conv-2');
      expect(closed, isTrue);
    });

    testWidgets('tapping New Conversation calls onNewConversation and onClose', (tester) async {
      bool newCalled = false;
      bool closed = false;

      await tester.pumpWidget(
        buildTestableWidget(
          isOpen: true,
          onNewConversation: () => newCalled = true,
          onClose: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Conversation'));
      await tester.pumpAndSettle();

      expect(newCalled, isTrue);
      expect(closed, isTrue);
    });

    testWidgets('delete conversation calls onDeleteConversation callback', (tester) async {
      String? deletedId;

      await tester.pumpWidget(
        buildTestableWidget(
          isOpen: true,
          onDeleteConversation: (id) async {
            deletedId = id;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Find trash icons
      final deleteIcons = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteIcons, findsNWidgets(2));

      await tester.tap(deleteIcons.first);
      await tester.pumpAndSettle();

      expect(deletedId, 'conv-1');
    });

    testWidgets('displays empty state when conversations is empty', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          isOpen: true,
          conversations: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No conversations yet'), findsOneWidget);
      expect(find.text('0 Local Sessions'), findsOneWidget);
    });

    testWidgets('displays error message and calls onRetry when error present', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        buildTestableWidget(
          isOpen: true,
          conversations: [],
          errorMessage: 'Failed to load conversations from backend.',
          onRetry: () => retried = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load conversations from backend.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('escape key triggers onClose', (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        buildTestableWidget(
          isOpen: true,
          onClose: () => closed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });
}
