import 'dart:async';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/screens/chat_screen.dart';

class MockCompanionClient extends CompanionClient {
  bool shouldHealthSucceed;
  bool shouldAuthSucceed;
  int authStatusCode;
  bool shouldModelSucceed;
  bool shouldCreateConvSucceed;
  Stream<SseEvent>? customEventStream;

  bool healthCalled = false;
  bool verifyAuthCalled = false;
  bool modelStatusCalled = false;
  bool createConvCalled = false;
  bool sendMessageCalled = false;

  MockCompanionClient({
    String token = 'valid_test_token',
    this.shouldHealthSucceed = true,
    this.shouldAuthSucceed = true,
    this.authStatusCode = 200,
    this.shouldModelSucceed = true,
    this.shouldCreateConvSucceed = true,
    this.customEventStream,
  }) : super(
          baseUrl: 'http://127.0.0.1:8000',
          credentialStore: InMemoryCredentialStore(token),
        );

  @override
  Future<HealthResponse> getHealth({Duration timeout = const Duration(seconds: 3)}) async {
    healthCalled = true;
    if (!shouldHealthSucceed) {
      throw const CompanionApiException(statusCode: 503, message: 'Runtime starting up.');
    }
    return const HealthResponse(status: 'healthy');
  }

  @override
  Future<AuthVerifyResponse> verifyAuth() async {
    verifyAuthCalled = true;
    if (authStatusCode == 401) {
      throw const CompanionApiException(statusCode: 401, message: 'Invalid or expired token.');
    }
    if (!shouldAuthSucceed) {
      return const AuthVerifyResponse(authenticated: false, message: 'Token verification failed.');
    }
    return const AuthVerifyResponse(authenticated: true, tokenType: 'Bearer', message: 'Token verified.');
  }

  @override
  Future<ModelStatusResponse> getModelStatus() async {
    modelStatusCalled = true;
    if (!shouldModelSucceed) {
      throw const CompanionApiException(statusCode: 503, message: 'Model unavailable.');
    }
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
    if (!shouldCreateConvSucceed) {
      throw const CompanionApiException(statusCode: 500, message: 'Internal database error');
    }
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
    http.Client? customClient,
  }) async* {
    sendMessageCalled = true;
    if (customEventStream != null) {
      yield* customEventStream!;
    } else {
      yield const SseTokenEvent('Hello');
      yield const SseTokenEvent(' world!');
      yield const SseDoneEvent();
    }
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
      expect(controller.canSend, isFalse);
      expect(controller.messages, isEmpty);
      expect(controller.conversations, isEmpty);
      expect(controller.activeConversation, isNull);
      expect(controller.connectionStatus, RuntimeConnectionStatus.unconnected);
    });

    test('checkConnection: Health 200 + Valid Auth connects and loads model', () async {
      await controller.checkConnection();
      expect(mockClient.healthCalled, isTrue);
      expect(mockClient.verifyAuthCalled, isTrue);
      expect(mockClient.modelStatusCalled, isTrue);
      expect(controller.connectionStatus, RuntimeConnectionStatus.connected);
      expect(controller.canSend, isTrue);
      expect(controller.activeModelName, 'qwen2.5-7b');
    });

    test('checkConnection: Health 200 + Auth 401 marks unauthorized and blocks canSend', () async {
      mockClient.authStatusCode = 401;
      await controller.checkConnection();

      expect(mockClient.healthCalled, isTrue);
      expect(mockClient.verifyAuthCalled, isTrue);
      expect(controller.connectionStatus, RuntimeConnectionStatus.unauthorized);
      expect(controller.canSend, isFalse);
      expect(controller.activeModelName, isNull);
      expect(controller.errorMessage, contains('Invalid or expired token'));
    });

    test('checkConnection: Health 200 + missing token marks unauthorized', () async {
      final unauthedMock = MockCompanionClient(token: '');
      final unauthedController = DesktopChatController(client: unauthedMock);

      await unauthedController.checkConnection();
      expect(unauthedController.connectionStatus, RuntimeConnectionStatus.unauthorized);
      expect(unauthedController.canSend, isFalse);
      expect(unauthedController.errorMessage, contains('Pairing token is missing'));

      unauthedController.dispose();
    });

    test('checkConnection: Valid auth + unavailable model keeps connected but marks model Unavailable', () async {
      mockClient.shouldModelSucceed = false;
      await controller.checkConnection();

      expect(controller.connectionStatus, RuntimeConnectionStatus.connected);
      expect(controller.canSend, isTrue);
      expect(controller.activeModelName, 'Unavailable');
    });

    test('updateConfiguration recovers auth after saving valid token', () async {
      final mock = MockCompanionClient(token: '');
      final ctrl = DesktopChatController(
        client: mock,
        clientFactory: ({required baseUrl, credentialStore}) => mock,
      );

      await ctrl.checkConnection();
      expect(ctrl.connectionStatus, RuntimeConnectionStatus.unauthorized);
      expect(ctrl.canSend, isFalse);

      await ctrl.updateConfiguration(
        baseUrl: 'http://127.0.0.1:8000',
        pairingToken: 'restored_valid_token',
      );

      expect(ctrl.connectionStatus, RuntimeConnectionStatus.connected);
      expect(ctrl.canSend, isTrue);

      ctrl.dispose();
    });

    test('sendMessage throws StateError when runtime is not connected', () async {
      expect(controller.isConnected, isFalse);
      expect(() => controller.sendMessage('Test prompt'), throwsStateError);
    });

    test('createNewConversation throws on server failure without fabricating local fake ID', () async {
      await controller.checkConnection();
      mockClient.shouldCreateConvSucceed = false;

      await expectLater(
        () => controller.createNewConversation(title: 'Failed Thread'),
        throwsA(isA<CompanionApiException>()),
      );
      expect(controller.conversations, isEmpty);
      expect(controller.errorMessage, contains('Internal database error'));
    });

    test('selectConversation throws StateError when turn generation is in progress', () async {
      await controller.checkConnection();
      await controller.loadConversations();

      final streamController = StreamController<SseEvent>();
      mockClient.customEventStream = streamController.stream;

      // Start generation
      final sendFuture = controller.sendMessage('Long running turn');
      expect(controller.isGenerating, isTrue);

      // Attempt switching conversation while generating
      final otherConv = ConversationOut(
        id: 'other-conv',
        title: 'Other',
        characterId: 'default',
        ownerId: 'owner',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        messageCount: 0,
      );
      expect(() => controller.selectConversation(otherConv), throwsStateError);

      // Clean up stream
      streamController.add(const SseDoneEvent());
      await streamController.close();
      await sendFuture;
    });

    test('cancelGeneration transitions generationState to cancelled', () async {
      await controller.checkConnection();
      await controller.loadConversations();

      final streamController = StreamController<SseEvent>.broadcast();
      mockClient.customEventStream = streamController.stream;

      final sendFuture = controller.sendMessage('Prompt to cancel');
      expect(controller.isGenerating, isTrue);

      await controller.cancelGeneration();
      expect(controller.generationState, ChatGenerationState.cancelled);

      await sendFuture;
      expect(controller.generationState, ChatGenerationState.cancelled);

      await streamController.close();
    });

    test('loadConversations populates list and selects first conversation', () async {
      await controller.checkConnection();
      await controller.loadConversations();
      expect(controller.conversations, hasLength(1));
      expect(controller.activeConversation?.title, 'Existing Chat');
      expect(controller.messages, hasLength(2));
    });

    test('sendMessage creates optimistic local turn and streams response', () async {
      await controller.checkConnection();
      await controller.loadConversations();
      await controller.sendMessage('Test prompt');

      expect(mockClient.sendMessageCalled, isTrue);
      expect(controller.isGenerating, isFalse);
      expect(controller.messages.length, greaterThanOrEqualTo(3));
      final lastMsg = controller.messages.last;
      expect(lastMsg.sender, 'assistant');
      expect(lastMsg.content, 'Hello world!');
    });
  });

  group('ChatScreen Widget Tests', () {
    testWidgets('renders interactive chat UI and sends message when connected', (tester) async {
      final mockClient = MockCompanionClient();
      final controller = DesktopChatController(client: mockClient);
      await controller.checkConnection();
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
      expect(find.text('Runtime: Connected'), findsOneWidget);

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

    testWidgets('preserves typed text in composer if send fails before acceptance', (tester) async {
      final mockClient = MockCompanionClient(token: '');
      final controller = DesktopChatController(client: mockClient);
      // Controller is unauthenticated/unconnected -> canSend is false
      await controller.checkConnection();
      expect(controller.canSend, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: ChatScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter text in composer
      await tester.enterText(find.byType(TextField), 'Preserve this draft message');
      await tester.pump();

      // Send button is disabled because canSend is false
      final sendBtn = tester.widget<NeumorphicButton>(
        find.ancestor(of: find.byIcon(Icons.send_rounded), matching: find.byType(NeumorphicButton)),
      );
      expect(sendBtn.onPressed, isNull);

      // TextField still contains the draft text
      expect(find.text('Preserve this draft message'), findsOneWidget);

      controller.dispose();
    });
  });
}
