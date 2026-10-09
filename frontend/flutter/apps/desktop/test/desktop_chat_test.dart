import 'dart:async';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/screens/chat_screen.dart';

class MockCompanionClient extends CompanionClient {
  MockCompanionClient()
      : super(
          baseUrl: 'http://127.0.0.1:8000',
          credentialStore: InMemoryCredentialStore(),
        );

  bool healthCalled = false;
  bool modelStatusCalled = false;
  bool createConvCalled = false;
  bool sendMessageCalled = false;

  @override
  Future<HealthResponse> getHealth({Duration timeout = const Duration(seconds: 3)}) async {
    healthCalled = true;
    return const HealthResponse(status: 'healthy');
  }

  @override
  Future<ModelStatusResponse> getModelStatus() async {
    modelStatusCalled = true;
    return const ModelStatusResponse(
      provider: 'llama.cpp',
      activeModel: 'qwen2.5-7b',
      modelLoaded: true,
      modelAwake: true,
      modelResident: true,
    );
  }

  @override
  Future<ConversationOut> createConversation({String? title, String? characterId}) async {
    createConvCalled = true;
    return ConversationOut(
      id: 'mock-conv-1',
      title: title ?? 'Mock Chat',
      characterId: characterId ?? 'default',
      ownerId: 'mock-owner',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      messageCount: 0,
    );
  }

  @override
  Future<ConversationListOut> listConversations({int skip = 0, int limit = 50}) async {
    return ConversationListOut(
      items: [
        ConversationOut(
          id: 'mock-conv-1',
          title: 'Existing Chat',
          characterId: 'default',
          ownerId: 'mock-owner',
          createdAt: DateTime.now().toUtc().toIso8601String(),
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          messageCount: 2,
        ),
      ],
      total: 1,
    );
  }

  @override
  Future<MessageListOut> listMessages(
    String conversationId, {
    int skip = 0,
    int limit = 100,
  }) async {
    return MessageListOut(
      items: [
        MessageOut(
          id: 'msg-1',
          conversationId: conversationId,
          sender: 'user',
          content: 'Hello Companion',
          status: 'completed',
          sequenceNo: 1,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
        MessageOut(
          id: 'msg-2',
          conversationId: conversationId,
          sender: 'assistant',
          content: 'Hello human!',
          status: 'completed',
          sequenceNo: 2,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      ],
      total: 2,
    );
  }

  @override
  Stream<SseEvent> sendMessageStream(
    String conversationId,
    MessageSend payload, {
    String? token,
    http.Client? customClient,
  }) async* {
    sendMessageCalled = true;
    yield const SseTokenEvent('Hello');
    yield const SseTokenEvent(' world!');
    yield const SseDoneEvent();
  }
}

void main() {
  group('DesktopChatController Unit Tests', () {
    late MockCompanionClient mockClient;
    late DesktopChatController controller;

    setUp(() {
      mockClient = MockCompanionClient();
      controller = DesktopChatController(client: mockClient);
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with default unconnected/idle state', () {
      expect(controller.isGenerating, isFalse);
      expect(controller.messages, isEmpty);
      expect(controller.conversations, isEmpty);
      expect(controller.activeConversation, isNull);
      expect(controller.connectionStatus, RuntimeConnectionStatus.unconnected);
    });

    test('checkConnection probes health and model status', () async {
      await controller.checkConnection();
      expect(mockClient.healthCalled, isTrue);
      expect(mockClient.modelStatusCalled, isTrue);
      expect(controller.connectionStatus, RuntimeConnectionStatus.connected);
      expect(controller.activeModelName, 'qwen2.5-7b');
    });

    test('loadConversations populates list and selects first conversation', () async {
      await controller.loadConversations();
      expect(controller.conversations, hasLength(1));
      expect(controller.activeConversation?.title, 'Existing Chat');
      expect(controller.messages, hasLength(2));
    });

    test('sendMessage creates optimistic local turn and streams response', () async {
      await controller.loadConversations();
      await controller.sendMessage('Test prompt');

      expect(mockClient.sendMessageCalled, isTrue);
      expect(controller.isGenerating, isFalse);
      // user turn + assistant turn
      expect(controller.messages.length, greaterThanOrEqualTo(3));
      final lastMsg = controller.messages.last;
      expect(lastMsg.sender, 'assistant');
      expect(lastMsg.content, 'Hello world!');
    });

    test('cancelGeneration halts active turn', () async {
      await controller.loadConversations();
      final future = controller.sendMessage('Interrupt me');
      controller.cancelGeneration();
      await future;

      expect(controller.isGenerating, isFalse);
    });
  });

  group('ChatScreen Widget Tests', () {
    testWidgets('renders interactive chat UI with message history and composer', (tester) async {
      final mockClient = MockCompanionClient();
      final controller = DesktopChatController(client: mockClient);
      await controller.loadConversations();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: ChatScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header
      expect(find.text('Existing Chat'), findsOneWidget);
      expect(find.text('Conversational workspace'), findsOneWidget);

      // Verify message bubbles
      expect(find.text('Hello Companion'), findsOneWidget);
      expect(find.text('Hello human!'), findsOneWidget);

      // Verify composer
      expect(find.byType(TextField), findsOneWidget);

      // Enter text and verify Send button triggers
      await tester.enterText(find.byType(TextField), 'Testing send message');
      await tester.pump();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(mockClient.sendMessageCalled, isTrue);

      controller.dispose();
    });
  });
}
