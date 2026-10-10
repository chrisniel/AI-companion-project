import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  Future<AuthVerifyResponse> verifyAuth({Duration timeout = const Duration(seconds: 5)}) async {
    verifyAuthCalled = true;
    if (authStatusCode == 401) {
      throw const CompanionApiException(statusCode: 401, message: 'Invalid or expired token.');
    }
    if (!shouldAuthSucceed) {
      return const AuthVerifyResponse(authenticated: false, message: 'Token verification failed.');
    }
    return const AuthVerifyResponse(authenticated: true, tokenType: 'Bearer', message: 'Token verified.');
  }

  bool deleteConvCalled = false;
  String? lastDeletedConvId;
  ModelStatusResponse? customModelStatus;
  List<MessageOut>? customMessages;
  List<ConversationOut>? customConversations;
  List<MessageOut> _storedMessages = [
    MessageOut(
      id: 'msg-1',
      conversationId: 'mock-conv-1',
      sender: 'user',
      content: 'Hello Companion',
      status: 'completed',
      sequenceNo: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ),
    MessageOut(
      id: 'msg-2',
      conversationId: 'mock-conv-1',
      sender: 'assistant',
      content: 'Hello human!',
      status: 'completed',
      sequenceNo: 2,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ),
  ];

  @override
  Future<ModelStatusResponse> getModelStatus() async {
    modelStatusCalled = true;
    if (!shouldModelSucceed) {
      throw const CompanionApiException(statusCode: 503, message: 'Model unavailable.');
    }
    return customModelStatus ??
        const ModelStatusResponse(
          provider: 'llama.cpp',
          activeModel: 'qwen2.5-7b',
          modelLoaded: true,
          modelAwake: true,
          modelResident: true,
          runtimeState: 'MODEL_READY',
        );
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    deleteConvCalled = true;
    lastDeletedConvId = conversationId;
  }

  @override
  Future<ConversationOut> createConversation({String? title, String? characterId}) async {
    createConvCalled = true;
    _storedMessages = [];
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
    if (customConversations != null) {
      return ConversationListOut(
        items: customConversations!,
        total: customConversations!.length,
      );
    }
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
    if (customMessages != null) {
      return MessageListOut(items: customMessages!, total: customMessages!.length);
    }
    return MessageListOut(
      items: _storedMessages,
      total: _storedMessages.length,
    );
  }

  String? lastRenamedTitle;
  bool generateTitleCalled = false;
  bool autoAcceptStream = true;
  Future<void> Function(String id, String title)? onRename;
  Future<void> Function(String id)? onGenerateTitle;

  @override
  Future<ConversationOut> renameConversation(String conversationId, String title) async {
    lastRenamedTitle = title;
    if (onRename != null) {
      await onRename!(conversationId, title);
    }
    return ConversationOut(
      id: conversationId,
      title: title,
      characterId: 'default',
      ownerId: 'owner',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      messageCount: 1,
    );
  }

  @override
  Future<ConversationOut> generateConversationTitle(
    String conversationId, {
    String? currentTitle,
    String? fallbackTitle,
  }) async {
    generateTitleCalled = true;
    if (onGenerateTitle != null) {
      await onGenerateTitle!(conversationId);
    }
    return ConversationOut(
      id: conversationId,
      title: 'Model-Generated Title',
      characterId: 'default',
      ownerId: 'owner',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      messageCount: 1,
    );
  }

  @override
  Stream<SseEvent> sendMessageStream(
    String conversationId,
    MessageSend payload, {
    http.Client? customClient,
    void Function()? onAccepted,
  }) async* {
    sendMessageCalled = true;
    if (customEventStream != null) {
      bool accepted = false;
      await for (final event in customEventStream!) {
        if (!accepted && autoAcceptStream) {
          accepted = true;
          onAccepted?.call();
        }
        yield event;
      }
    } else {
      if (autoAcceptStream) {
        onAccepted?.call();
      }
      _storedMessages.add(
        MessageOut(
          id: 'msg-u-${DateTime.now().millisecondsSinceEpoch}',
          conversationId: conversationId,
          sender: 'user',
          content: payload.userText,
          status: 'completed',
          sequenceNo: _storedMessages.length + 1,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      _storedMessages.add(
        MessageOut(
          id: 'msg-a-${DateTime.now().millisecondsSinceEpoch}',
          conversationId: conversationId,
          sender: 'assistant',
          content: 'Hello world!',
          status: 'completed',
          sequenceNo: _storedMessages.length + 1,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
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

    test('production-style controller begins on Host A, updates to Host B, and subsequent requests target B never A', () async {
      final prevOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final serverA = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverB = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      final requestsA = <String>[];
      final requestsB = <String>[];

      void handleRequest(HttpRequest request, List<String> log) {
        log.add(request.uri.path);
        final response = request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json;
        if (request.uri.path == '/api/v1/health') {
          response.write(jsonEncode({'status': 'healthy'}));
        } else if (request.uri.path == '/api/v1/auth/verify') {
          response.write(jsonEncode({'authenticated': true, 'token_type': 'Bearer'}));
        } else if (request.uri.path == '/api/v1/models') {
          response.write(jsonEncode({
            'active_model': 'test-model',
            'model_loaded': true,
            'model_awake': true,
            'runtime_state': 'MODEL_READY',
          }));
        } else if (request.uri.path == '/api/v1/conversations') {
          response.write(jsonEncode([]));
        } else {
          response.write(jsonEncode({'status': 'ok'}));
        }
        response.close();
      }

      serverA.listen((request) => handleRequest(request, requestsA));
      serverB.listen((request) => handleRequest(request, requestsB));

      try {
        final initialClient = CompanionClient(
          baseUrl: 'http://127.0.0.1:${serverA.port}',
          credentialStore: InMemoryCredentialStore('token-a'),
        );

        // Production-style instantiation: NO clientFactory provided!
        final controller = DesktopChatController(client: initialClient);
        expect(controller.client.baseUri.port, equals(serverA.port));

        await controller.checkConnection();
        expect(requestsA, contains('/api/v1/health'));
        expect(requestsB, isEmpty);

        // Reconfigure to Host B
        await controller.updateConfiguration(
          baseUrl: 'http://127.0.0.1:${serverB.port}',
          pairingToken: 'token-b',
        );

        // Actual client endpoint must be replaced to Host B!
        expect(controller.client.baseUri.port, equals(serverB.port));
        expect(controller.client.baseUri.toString(), equals('http://127.0.0.1:${serverB.port}'));

        final aCountAfterReconfig = requestsA.length;
        expect(requestsB, contains('/api/v1/health'));

        // Subsequent checkConnection targets B, never A
        await controller.checkConnection();
        expect(requestsA.length, equals(aCountAfterReconfig));
        expect(requestsB.length, greaterThan(1));

        controller.dispose();
      } finally {
        HttpOverrides.global = prevOverrides;
        await serverA.close(force: true);
        await serverB.close(force: true);
      }
    });

    test('injected test clientFactory remains supported and is called on updateConfiguration', () async {
      final mockA = MockCompanionClient(token: 'token-a');
      final mockB = MockCompanionClient(token: 'token-b');
      var factoryCalledWithUrl = '';

      final controller = DesktopChatController(
        client: mockA,
        clientFactory: ({required baseUrl, credentialStore}) {
          factoryCalledWithUrl = baseUrl;
          return mockB;
        },
      );

      await controller.updateConfiguration(
        baseUrl: 'http://127.0.0.1:9999',
        pairingToken: 'token-b',
      );

      expect(factoryCalledWithUrl, equals('http://127.0.0.1:9999'));
      expect(controller.client, same(mockB));
      controller.dispose();
    });

    test('sendMessage throws StateError when runtime is not connected', () async {
      expect(controller.isConnected, isFalse);
      expect(() => controller.sendMessage('Test prompt'), throwsStateError);
    });

    test('createNewConversation throws on server failure without fabricating local fake ID', () async {
      await controller.checkConnection();
      expect(controller.conversations, hasLength(1));
      mockClient.shouldCreateConvSucceed = false;

      await expectLater(
        () => controller.createNewConversation(title: 'Failed Thread'),
        throwsA(isA<CompanionApiException>()),
      );
      expect(controller.conversations, hasLength(1));
      expect(controller.conversations.where((c) => c.title == 'Failed Thread'), isEmpty);
    });

    test('createNewConversation reuses active empty draft without creating duplicate rows', () async {
      await controller.checkConnection();
      expect(controller.conversations, hasLength(1));

      mockClient.customMessages = [];
      final emptyConv = ConversationOut(
        id: 'mock-empty-draft',
        title: 'New Conversation',
        characterId: 'default',
        ownerId: 'mock-owner',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        messageCount: 0,
      );
      await controller.selectConversation(emptyConv);
      expect(controller.activeConversation?.id, 'mock-empty-draft');
      expect(controller.messages, isEmpty);

      mockClient.createConvCalled = false;

      // Calling createNewConversation should reuse the active empty draft
      await controller.createNewConversation();

      expect(mockClient.createConvCalled, isFalse);
      expect(controller.activeConversation?.id, 'mock-empty-draft');
    });

    test('createNewConversation transition lock guards against rapid double-clicks', () async {
      await controller.checkConnection();
      mockClient.createConvCalled = false;

      // Existing chat has messageCount == 2
      expect(controller.activeConversation?.messageCount, 2);

      // Invoke concurrent createNewConversation calls
      final future1 = controller.createNewConversation(title: 'Thread 1');
      final future2 = controller.createNewConversation(title: 'Thread 2');

      await Future.wait([future1, future2]);

      // Only one conversation was created, second was guarded by transition lock
      expect(controller.conversations.where((c) => c.title == 'Thread 1'), hasLength(1));
      expect(controller.conversations.where((c) => c.title == 'Thread 2'), isEmpty);
    });

    test('failed 503 send preserves thread and reuses it on subsequent new conversation click', () async {
      await controller.checkConnection();

      mockClient.customMessages = [];
      final emptyConv = ConversationOut(
        id: 'conv-with-503',
        title: 'New Conversation',
        characterId: 'default',
        ownerId: 'mock-owner',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        messageCount: 0,
      );
      await controller.selectConversation(emptyConv);

      final streamController = StreamController<SseEvent>();
      mockClient.customEventStream = streamController.stream;

      final sendFuture = controller.sendMessage('Test prompt that 503s');
      streamController.addError(const CompanionApiException(statusCode: 503, message: 'LLM_UNAVAILABLE'));
      await streamController.close();
      await sendFuture;

      expect(controller.errorMessage, contains('503'));
      expect(controller.messages, isEmpty);
      expect(controller.activeConversation?.id, 'conv-with-503');

      // Tapping "New Conversation" now reuses this empty draft instead of creating another row
      mockClient.createConvCalled = false;
      await controller.createNewConversation();
      expect(mockClient.createConvCalled, isFalse);
      expect(controller.activeConversation?.id, 'conv-with-503');
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
    test('deleteConversation removes conversation and updates selection', () async {
      await controller.checkConnection();
      expect(controller.conversations, hasLength(1));
      expect(controller.activeConversation?.id, 'mock-conv-1');

      await controller.deleteConversation('mock-conv-1');
      expect(mockClient.deleteConvCalled, isTrue);
      expect(mockClient.lastDeletedConvId, 'mock-conv-1');
      expect(controller.conversations, isEmpty);
      expect(controller.activeConversation, isNull);
    });

    test('modelStateCategory reflects authoritative runtime telemetry', () async {
      expect(controller.modelStateCategory, ModelRuntimeStateCategory.unreachable);
      expect(controller.modelStatusLabel, 'Offline');

      mockClient.customModelStatus = const ModelStatusResponse(
        provider: 'llama.cpp',
        activeModel: 'qwen2.5-7b',
        modelLoaded: true,
        modelAwake: true,
        runtimeState: 'MODEL_READY',
      );
      await controller.checkConnection();
      expect(controller.modelStateCategory, ModelRuntimeStateCategory.modelReady);
      expect(controller.modelStatusLabel, 'qwen2.5-7b');

      mockClient.customModelStatus = const ModelStatusResponse(
        provider: 'llama.cpp',
        activeModel: 'qwen2.5-7b',
        modelLoaded: true,
        modelAwake: false,
        runtimeState: 'MODEL_SLEEPING',
      );
      await controller.checkConnection();
      expect(controller.modelStateCategory, ModelRuntimeStateCategory.modelSleeping);
      expect(controller.modelStatusLabel, contains('Sleeping'));

      mockClient.customModelStatus = const ModelStatusResponse(
        provider: 'llama.cpp',
        activeModel: null,
        modelLoaded: false,
        modelAwake: false,
        runtimeState: 'MODEL_UNLOADED',
      );
      await controller.checkConnection();
      expect(controller.modelStateCategory, ModelRuntimeStateCategory.modelUnloaded);
      expect(controller.modelStatusLabel, 'Unloaded');

      mockClient.customModelStatus = const ModelStatusResponse(
        provider: 'llama.cpp',
        activeModel: 'qwen2.5-7b',
        modelLoaded: false,
        modelAwake: false,
        runtimeState: 'LOAD_FAILED',
        lastRuntimeError: 'Vulkan out of memory',
      );
      await controller.checkConnection();
      expect(controller.modelStateCategory, ModelRuntimeStateCategory.modelLoadFailed);
      expect(controller.modelStatusLabel, 'Load Failed');
      expect(controller.modelStatusDescription, 'Vulkan out of memory');
    });

    test('sendMessage handles HTTP 503 LLM_UNAVAILABLE with explanatory error message', () async {
      await controller.checkConnection();

      final streamCtrl = StreamController<SseEvent>();
      mockClient.customEventStream = streamCtrl.stream;

      final sendFuture = controller.sendMessage('Hello model');
      streamCtrl.addError(
        const CompanionApiException(
          statusCode: 503,
          code: 'LLM_UNAVAILABLE',
          message: 'Local inference engine unavailable',
        ),
      );
      await streamCtrl.close();
      await sendFuture;

      expect(controller.generationState, ChatGenerationState.error);
      expect(controller.errorMessage, contains('Local AI model unavailable (503)'));
    });

    test('drawerConversations filters inactive untouched empty drafts while preserving active empty draft and populated sessions', () async {
      mockClient.customConversations = const [
        ConversationOut(
          id: 'conv-active-empty',
          title: 'New Conversation',
          characterId: 'default',
          ownerId: 'owner',
          createdAt: '2026-03-30T10:00:00Z',
          updatedAt: '2026-03-30T10:00:00Z',
          messageCount: 0,
        ),
        ConversationOut(
          id: 'conv-old-empty',
          title: 'New Conversation',
          characterId: 'default',
          ownerId: 'owner',
          createdAt: '2026-03-29T10:00:00Z',
          updatedAt: '2026-03-29T10:00:00Z',
          messageCount: 0,
        ),
        ConversationOut(
          id: 'conv-with-messages',
          title: 'Project Discussion',
          characterId: 'default',
          ownerId: 'owner',
          createdAt: '2026-03-28T10:00:00Z',
          updatedAt: '2026-03-28T10:00:00Z',
          messageCount: 5,
        ),
        ConversationOut(
          id: 'conv-renamed-empty',
          title: 'Custom Topic',
          characterId: 'default',
          ownerId: 'owner',
          createdAt: '2026-03-27T10:00:00Z',
          updatedAt: '2026-03-27T10:00:00Z',
          messageCount: 0,
        ),
      ];

      await controller.checkConnection();
      await controller.loadConversations();
      final activeConv = controller.conversations.firstWhere((c) => c.id == 'conv-active-empty');
      await controller.selectConversation(activeConv);

      expect(controller.conversations, hasLength(4));
      final drawerIds = controller.drawerConversations.map((c) => c.id).toList();
      expect(drawerIds, hasLength(3));
      expect(drawerIds, contains('conv-active-empty'));
      expect(drawerIds, contains('conv-with-messages'));
      expect(drawerIds, contains('conv-renamed-empty'));
      expect(drawerIds, isNot(contains('conv-old-empty')));
    });

    test('first turn generates deterministic title, persists rename, and triggers model refinement', () async {
      mockClient.customConversations = const [
        ConversationOut(
          id: 'conv-new',
          title: 'New Conversation',
          characterId: 'default',
          ownerId: 'owner',
          createdAt: '2026-03-30T10:00:00Z',
          updatedAt: '2026-03-30T10:00:00Z',
          messageCount: 0,
        ),
      ];

      mockClient.customMessages = [];
      await controller.checkConnection();
      await controller.loadConversations();
      await controller.selectConversation(controller.conversations.first);

      expect(controller.activeConversation?.title, 'New Conversation');

      const prompt = 'Tell me about quantum computing principles';
      final expectedDeterministic = deriveDeterministicTitle(prompt);

      await controller.sendMessage(prompt);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(mockClient.lastRenamedTitle, expectedDeterministic);
      expect(mockClient.generateTitleCalled, isTrue);
    });

    test('rejected turn (HTTP 503) does not rename conversation or corrupt title', () async {
      mockClient.customConversations = const [
        ConversationOut(
          id: 'conv-new-503',
          title: 'New Conversation',
          characterId: 'default',
          ownerId: 'owner',
          createdAt: '2026-03-30T10:00:00Z',
          updatedAt: '2026-03-30T10:00:00Z',
          messageCount: 0,
        ),
      ];
      mockClient.autoAcceptStream = false;

      final streamCtrl = StreamController<SseEvent>();
      mockClient.customEventStream = streamCtrl.stream;

      await controller.checkConnection();
      await controller.loadConversations();
      await controller.selectConversation(controller.conversations.first);

      final sendFuture = controller.sendMessage('Test rejected message');
      streamCtrl.addError(
        const CompanionApiException(
          statusCode: 503,
          code: 'LLM_UNAVAILABLE',
          message: 'Local inference engine unavailable',
        ),
      );
      await streamCtrl.close();
      final accepted = await sendFuture;

      expect(accepted, isFalse);
      expect(controller.activeConversation?.title, 'New Conversation');
      expect(mockClient.lastRenamedTitle, isNull);
      expect(mockClient.generateTitleCalled, isFalse);
    });

    test('manually renamed conversation is not overwritten by first-turn title generation', () async {
      mockClient.customConversations = const [
        ConversationOut(
          id: 'conv-manual',
          title: 'New Conversation',
          characterId: 'default',
          ownerId: 'owner',
          createdAt: '2026-03-30T10:00:00Z',
          updatedAt: '2026-03-30T10:00:00Z',
          messageCount: 0,
        ),
      ];

      mockClient.customMessages = [];
      await controller.checkConnection();
      await controller.loadConversations();
      await controller.selectConversation(controller.conversations.first);

      await controller.renameConversation('conv-manual', 'My Custom Topic');
      expect(controller.activeConversation?.title, 'My Custom Topic');
      expect(mockClient.lastRenamedTitle, 'My Custom Topic');

      await controller.sendMessage('Some prompt text');
      expect(controller.activeConversation?.title, 'My Custom Topic');
      expect(mockClient.lastRenamedTitle, 'My Custom Topic');
      expect(mockClient.generateTitleCalled, isFalse);
    });

    test('E2E lifecycle: create -> send -> stream tokens -> done -> restore history', () async {
      final e2eClient = MockCompanionClient();
      final e2eController = DesktopChatController(client: e2eClient);

      await e2eController.checkConnection();
      expect(e2eController.isConnected, isTrue);

      // Create new conversation
      await e2eController.createNewConversation(title: 'E2E Test Session');
      expect(e2eController.activeConversation, isNotNull);

      // Send prompt and consume tokens
      await e2eController.sendMessage('Hi there!');
      expect(e2eController.isGenerating, isFalse);
      expect(e2eController.messages, hasLength(greaterThanOrEqualTo(2)));
      expect(e2eController.messages.last.content, 'Hello world!');

      // Reload conversations and restore active selection
      await e2eController.loadConversations();
      expect(e2eController.conversations.isNotEmpty, isTrue);
      await e2eController.selectConversation(e2eController.conversations.first);
      expect(e2eController.messages.isNotEmpty, isTrue);

      e2eController.dispose();
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

    testWidgets('opens and closes conversation history drawer via header button and escape key', (tester) async {
      final mockClient = MockCompanionClient();
      final controller = DesktopChatController(client: mockClient);
      await controller.checkConnection();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: ChatScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // History button exists
      final historyBtn = find.byIcon(Icons.history_rounded);
      expect(historyBtn, findsOneWidget);

      // Tap history button to open drawer
      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      // Drawer is open
      expect(find.text('Conversation History'), findsOneWidget);
      expect(find.text('1 Local Sessions'), findsOneWidget);
      expect(find.text('Search past conversations...'), findsOneWidget);

      // Close button exists in drawer
      final closeBtn = find.byIcon(Icons.close_rounded);
      expect(closeBtn, findsOneWidget);

      // Tap close button
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Drawer is closed
      expect(find.text('Conversation History'), findsNothing);

      controller.dispose();
    });

    testWidgets('renders historical image attachment cards with truthful Preview unavailable badge', (tester) async {
      final mockClient = MockCompanionClient();
      mockClient.customMessages = [
        MessageOut(
          id: 'msg-with-att',
          conversationId: 'mock-conv-1',
          sender: 'user',
          content: 'Here is my design mockup',
          status: 'completed',
          sequenceNo: 1,
          createdAt: DateTime.now().toUtc().toIso8601String(),
          attachments: const [
            AttachmentRef(
              id: 'att-1',
              filenameDisplay: 'architecture_diagram.png',
              mimeType: 'image/png',
              sizeBytes: 256 * 1024,
            ),
          ],
        ),
      ];

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

      expect(find.text('architecture_diagram.png'), findsOneWidget);
      expect(find.text('256.0 KB'), findsOneWidget);
      expect(find.text('Preview unavailable (Planned M2)'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);

      controller.dispose();
    });

    testWidgets('preserves draft in composer and restores canSend when connected send is rejected with HTTP 503', (tester) async {
      final mockClient = MockCompanionClient();
      mockClient.autoAcceptStream = false;

      final streamCtrl = StreamController<SseEvent>();
      mockClient.customEventStream = streamCtrl.stream;

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

      const draftText = 'Draft message that must not be cleared on 503';
      await tester.enterText(find.byType(TextField), draftText);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      streamCtrl.addError(
        const CompanionApiException(
          statusCode: 503,
          code: 'LLM_UNAVAILABLE',
          message: 'Local inference engine unavailable',
        ),
      );
      await streamCtrl.close();
      await tester.pumpAndSettle();

      expect(find.text(draftText), findsOneWidget);
      expect(controller.errorMessage, contains('Local AI model unavailable (503)'));
      expect(controller.messages.where((m) => m.content == draftText), isEmpty);
      expect(controller.isGenerating, isFalse);
      expect(controller.isAwaitingAcceptance, isFalse);

      controller.dispose();
    });

    testWidgets('disables composer send button while awaiting server acceptance', (tester) async {
      final mockClient = MockCompanionClient();
      mockClient.autoAcceptStream = false;

      final streamCtrl = StreamController<SseEvent>();
      mockClient.customEventStream = streamCtrl.stream;

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

      await tester.enterText(find.byType(TextField), 'First submission in flight');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(controller.isAwaitingAcceptance, isTrue);
      expect(controller.canSend, isFalse);

      // While busy/awaiting acceptance, the send button is replaced by stop button, preventing duplicate submits
      expect(find.byIcon(Icons.send_rounded), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      streamCtrl.add(const SseDoneEvent());
      await streamCtrl.close();
      await tester.pumpAndSettle();

      controller.dispose();
    });

    testWidgets('authenticated user with zero conversations sends first prompt: creates conversation and sends message without deadlock or duplicate threads', (tester) async {
      final mockClient = MockCompanionClient();
      mockClient.customConversations = []; // Zero conversations initially

      final controller = DesktopChatController(client: mockClient);
      await controller.checkConnection();
      await controller.loadConversations();

      expect(controller.conversations, isEmpty);
      expect(controller.activeConversation, isNull);

      final result = await controller.sendMessage('Hello from first turn');

      expect(result, isTrue);
      expect(mockClient.createConvCalled, isTrue);
      expect(controller.conversations.length, 1);
      expect(controller.activeConversation, isNotNull);
      expect(controller.activeConversation!.id, 'mock-conv-1');
      expect(mockClient.sendMessageCalled, isTrue);
      expect(controller.errorMessage, isNull);
      expect(controller.isGenerating, isFalse);

      controller.dispose();
    });

    test('title refinement strictly awaits delayed deterministic PATCH before requesting model title', () async {
      final mockClient = MockCompanionClient();
      mockClient.customConversations = [
        ConversationOut(
          id: 'mock-conv-1',
          title: 'New Conversation',
          characterId: 'default',
          ownerId: 'mock-owner',
          createdAt: DateTime.now().toUtc().toIso8601String(),
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          messageCount: 0,
        ),
      ];
      mockClient.customMessages = [];

      final executionLog = <String>[];
      final renameCompleter = Completer<void>();

      mockClient.onRename = (id, title) async {
        executionLog.add('rename:start');
        await renameCompleter.future;
        executionLog.add('rename:end');
      };

      mockClient.onGenerateTitle = (id) async {
        executionLog.add('generateTitle');
      };

      final controller = DesktopChatController(client: mockClient);
      await controller.checkConnection();
      await controller.loadConversations();

      final sendFuture = controller.sendMessage('What is the architecture of this system?');

      // Allow streaming tokens to complete
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // At this point, rename is still in progress, so generateTitle MUST NOT have fired yet
      expect(executionLog, contains('rename:start'));
      expect(executionLog, isNot(contains('generateTitle')));

      // Now complete the rename PATCH
      renameCompleter.complete();
      await sendFuture;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(executionLog, ['rename:start', 'rename:end', 'generateTitle']);
      expect(controller.activeConversation?.title, 'Model-Generated Title');

      controller.dispose();
    });

    test('delayed deterministic PATCH does not overwrite manual user rename', () async {
      final mockClient = MockCompanionClient();
      mockClient.customConversations = [
        ConversationOut(
          id: 'mock-conv-1',
          title: 'New Conversation',
          characterId: 'default',
          ownerId: 'mock-owner',
          createdAt: DateTime.now().toUtc().toIso8601String(),
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          messageCount: 0,
        ),
      ];
      mockClient.customMessages = [];

      final renameCompleter = Completer<void>();
      int renameCallCount = 0;

      mockClient.onRename = (id, title) async {
        renameCallCount++;
        if (renameCallCount == 1) {
          // First rename is the deterministic title PATCH
          await renameCompleter.future;
        }
      };

      final controller = DesktopChatController(client: mockClient);
      await controller.checkConnection();
      await controller.loadConversations();

      final sendFuture = controller.sendMessage('Some query');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // User manually renames the conversation while deterministic PATCH is pending
      await controller.renameConversation('mock-conv-1', 'User Hand-Crafted Title');

      // Now complete the delayed deterministic PATCH
      renameCompleter.complete();
      await sendFuture;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.activeConversation?.title, 'User Hand-Crafted Title');
      expect(controller.conversations.first.title, 'User Hand-Crafted Title');

      controller.dispose();
    });

    testWidgets('cancelling generation while awaiting acceptance leaves draft in composer and prevents late events from committing turns', (tester) async {
      final mockClient = MockCompanionClient();
      mockClient.autoAcceptStream = false;
      final streamCtrl = StreamController<SseEvent>();
      mockClient.customEventStream = streamCtrl.stream;

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

      await tester.enterText(find.byType(TextField), 'Draft before cancel');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(controller.isAwaitingAcceptance, isTrue);

      // User presses Stop (or Esc) while awaiting acceptance
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      // Late tokens arrive from server after cancellation
      streamCtrl.add(const SseTokenEvent('Late token arrived'));
      streamCtrl.add(const SseDoneEvent());
      await streamCtrl.close();
      await tester.pumpAndSettle();

      expect(controller.isAwaitingAcceptance, isFalse);
      expect(controller.isGenerating, isFalse);
      expect(controller.canSend, isTrue);
      // Draft must be preserved
      expect(find.text('Draft before cancel'), findsOneWidget);
      // Turns must not be committed to UI
      expect(controller.messages.where((m) => m.content == 'Draft before cancel'), isEmpty);
      expect(controller.messages.where((m) => m.content.contains('Late token')), isEmpty);

      controller.dispose();
    });

    test('model initially unloaded at connection time, then ready post-turn, probes status and triggers AI title refinement', () async {
      final mockClient = MockCompanionClient();
      // At connection time, model is unloaded
      mockClient.customModelStatus = const ModelStatusResponse(
        provider: 'llama.cpp',
        activeModel: null,
        modelLoaded: false,
        modelAwake: false,
        modelResident: false,
        runtimeState: 'MODEL_UNLOADED',
      );
      mockClient.customConversations = [
        ConversationOut(
          id: 'conv-unloaded',
          title: 'New Conversation',
          characterId: 'default',
          ownerId: 'mock-owner',
          createdAt: DateTime.now().toUtc().toIso8601String(),
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          messageCount: 0,
        ),
      ];
      mockClient.customMessages = [];

      final controller = DesktopChatController(client: mockClient);
      await controller.checkConnection();
      await controller.loadConversations();

      expect(controller.modelStatus?.modelLoaded, isFalse);

      // Now model is loaded on demand during inference
      mockClient.customModelStatus = const ModelStatusResponse(
        provider: 'llama.cpp',
        activeModel: 'qwen2.5-7b',
        modelLoaded: true,
        modelAwake: true,
        modelResident: true,
        runtimeState: 'MODEL_READY',
      );

      await controller.sendMessage('Tell me about the universe');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(mockClient.generateTitleCalled, isTrue);
      expect(controller.activeConversation?.title, 'Model-Generated Title');

      controller.dispose();
    });
  });
}
