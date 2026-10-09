import 'dart:async';
import 'dart:convert';
import 'package:companion_api/companion_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('CompanionClient REST & SSE', () {
    test('validates URL scheme and loopback security', () async {
      expect(
        () => CompanionClient(baseUrl: 'ftp://localhost:8000'),
        throwsArgumentError,
      );

      // Plaintext remote HTTP with pairing token must fail state error
      final remoteClient = CompanionClient(
        baseUrl: 'http://remote-server.com:8000',
        credentialStore: InMemoryCredentialStore('secret_token'),
      );
      expect(
        () => remoteClient.verifyAuth(),
        throwsStateError,
      );
    });

    test('getHealth returns HealthResponse on 200', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/health');
        expect(request.method, 'GET');
        return http.Response(jsonEncode({'status': 'healthy'}), 200);
      });

      final client = CompanionClient(httpClient: mock);
      final health = await client.getHealth();
      expect(health.status, 'healthy');
    });

    test('verifyAuth sends Bearer token and returns AuthVerifyResponse', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/verify');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer valid_test_token');
        return http.Response(
          jsonEncode({
            'authenticated': true,
            'token_type': 'Bearer',
            'message': 'Token verified',
          }),
          200,
        );
      });

      final store = InMemoryCredentialStore('valid_test_token');
      final client = CompanionClient(httpClient: mock, credentialStore: store);
      final auth = await client.verifyAuth();
      expect(auth.authenticated, isTrue);
    });

    test('verifyAuth throws CompanionApiException on 401', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid or expired token'}),
          401,
        );
      });

      final client = CompanionClient(httpClient: mock);
      expect(
        () => client.verifyAuth(),
        throwsA(isA<CompanionApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('getSystemStatus returns SystemStatusResponse', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/system/status');
        return http.Response(
          jsonEncode({
            'status': 'online',
            'platform': 'Windows 11',
            'python_version': '3.11.9',
            'hostname': 'HOST',
            'version': '0.1.0',
            'database_connected': true,
            'timestamp': '2026-10-09T12:00:00Z',
          }),
          200,
        );
      });

      final client = CompanionClient(httpClient: mock);
      final status = await client.getSystemStatus();
      expect(status.platform, 'Windows 11');
      expect(status.databaseConnected, isTrue);
    });

    test('getModelStatus returns ModelStatusResponse', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/models');
        return http.Response(
          jsonEncode({
            'provider': 'llama.cpp',
            'runtime_state': 'MODEL_READY',
            'active_model': 'qwen2.5-7b',
            'available_models': ['qwen2.5-7b'],
          }),
          200,
        );
      });

      final client = CompanionClient(httpClient: mock);
      final status = await client.getModelStatus();
      expect(status.provider, 'llama.cpp');
      expect(status.activeModel, 'qwen2.5-7b');
    });

    test('createConversation and listConversations round trip', () async {
      final mock = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({
              'id': 'conv-101',
              'title': 'New Chat',
              'character_id': 'default',
              'owner_id': 'owner',
              'created_at': '2026-10-09T12:00:00Z',
              'updated_at': '2026-10-09T12:00:00Z',
              'message_count': 0,
            }),
            201,
          );
        } else if (request.method == 'GET' && request.url.path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'conv-101',
                  'title': 'New Chat',
                  'character_id': 'default',
                  'owner_id': 'owner',
                  'created_at': '2026-10-09T12:00:00Z',
                  'updated_at': '2026-10-09T12:00:00Z',
                  'message_count': 0,
                }
              ],
              'total': 1,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = CompanionClient(httpClient: mock);
      final created = await client.createConversation(title: 'New Chat');
      expect(created.id, 'conv-101');

      final list = await client.listConversations();
      expect(list.total, 1);
      expect(list.items.first.id, 'conv-101');
    });

    test('listMessages parses message history', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/conversations/conv-1/messages');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'm1',
                'conversation_id': 'conv-1',
                'sender': 'user',
                'content': 'Hi',
                'status': 'completed',
                'sequence_no': 1,
                'created_at': '2026-10-09T12:00:00Z',
                'attachments': <Map<String, dynamic>>[],
              }
            ],
            'total': 1,
          }),
          200,
        );
      });

      final client = CompanionClient(httpClient: mock);
      final messages = await client.listMessages('conv-1');
      expect(messages.total, 1);
      expect(messages.items.first.content, 'Hi');
    });

    test('sendMessageStream parses SSE stream chunks into typed events', () async {
      final sseLines = [
        'data: {"type": "token", "content": "Hello"}\n\n',
        'data: {"type": "token", "content": " friend"}\n\n',
        'data: {"type": "done", "finish_reason": "stop"}\n\n',
      ];
      final bodyBytes = utf8.encode(sseLines.join());

      final mockStreamClient = MockClient.streaming((request, bodyStream) async {
        expect(request.url.path, '/api/v1/conversations/conv-1/messages');
        expect(request.headers['Accept'], 'text/event-stream');
        final stream = Stream.fromIterable(<List<int>>[bodyBytes]);
        return http.StreamedResponse(stream, 200);
      });

      final client = CompanionClient();
      final stream = client.sendMessageStream(
        'conv-1',
        const MessageSend(userText: 'Hello'),
        customClient: mockStreamClient,
      );

      final events = await stream.toList();
      expect(events.length, 3);
      expect(events[0], const SseTokenEvent('Hello'));
      expect(events[1], const SseTokenEvent(' friend'));
      expect(events[2], const SseDoneEvent(finishReason: 'stop'));
    });

    test('sendMessageStream propagates HTTP 409 CONVERSATION_BUSY error', () async {
      final mockStreamClient = MockClient.streaming((request, bodyStream) async {
        final errBytes = utf8.encode(jsonEncode({'detail': 'CONVERSATION_BUSY'}));
        return http.StreamedResponse(Stream.fromIterable([errBytes]), 409);
      });

      final client = CompanionClient();
      final stream = client.sendMessageStream(
        'conv-1',
        const MessageSend(userText: 'Busy turn'),
        customClient: mockStreamClient,
      );

      expect(
        stream.toList(),
        throwsA(isA<CompanionApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', 'CONVERSATION_BUSY')),
      );
    });

    test('sendMessageStream propagates HTTP 503 LLM_UNAVAILABLE error', () async {
      final mockStreamClient = MockClient.streaming((request, bodyStream) async {
        final errBytes = utf8.encode(jsonEncode({'detail': 'LLM_UNAVAILABLE'}));
        return http.StreamedResponse(Stream.fromIterable([errBytes]), 503);
      });

      final client = CompanionClient();
      final stream = client.sendMessageStream(
        'conv-1',
        const MessageSend(userText: 'Turn'),
        customClient: mockStreamClient,
      );

      expect(
        stream.toList(),
        throwsA(isA<CompanionApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.isUnavailable, 'isUnavailable', isTrue)),
      );
    });

    test('getConversation retrieves specific conversation by id', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/conversations/conv-42');
        return http.Response(
          jsonEncode({
            'id': 'conv-42',
            'title': 'Specific Thread',
            'character_id': 'default',
            'owner_id': 'owner',
            'created_at': '2026-10-09T12:00:00Z',
            'updated_at': '2026-10-09T12:00:00Z',
            'message_count': 5,
          }),
          200,
        );
      });

      final client = CompanionClient(httpClient: mock);
      final conv = await client.getConversation('conv-42');
      expect(conv.id, 'conv-42');
      expect(conv.title, 'Specific Thread');
      expect(conv.messageCount, 5);
    });

    test('deleteConversation deletes conversation by id', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/conversations/conv-42');
        return http.Response('', 204);
      });

      final client = CompanionClient(httpClient: mock);
      await expectLater(client.deleteConversation('conv-42'), completes);
    });

    test('renameConversation sends PATCH and returns updated ConversationOut', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/conversations/conv-42');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Renamed Chat');
        return http.Response(
          jsonEncode({
            'id': 'conv-42',
            'title': 'Renamed Chat',
            'character_id': 'default',
            'owner_id': 'owner',
            'created_at': '2026-10-09T12:00:00Z',
            'updated_at': '2026-10-09T12:05:00Z',
            'message_count': 3,
          }),
          200,
        );
      });

      final client = CompanionClient(httpClient: mock);
      final res = await client.renameConversation('conv-42', 'Renamed Chat');
      expect(res.id, 'conv-42');
      expect(res.title, 'Renamed Chat');
      expect(res.messageCount, 3);
    });

    test('generateConversationTitle sends POST and returns updated ConversationOut', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/conversations/conv-42/generate-title');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['current_title'], 'Current');
        expect(body['fallback_title'], 'Fallback');
        return http.Response(
          jsonEncode({
            'id': 'conv-42',
            'title': 'Model Generated Title',
            'character_id': 'default',
            'owner_id': 'owner',
            'created_at': '2026-10-09T12:00:00Z',
            'updated_at': '2026-10-09T12:05:00Z',
            'message_count': 1,
          }),
          200,
        );
      });

      final client = CompanionClient(httpClient: mock);
      final res = await client.generateConversationTitle(
        'conv-42',
        currentTitle: 'Current',
        fallbackTitle: 'Fallback',
      );
      expect(res.id, 'conv-42');
      expect(res.title, 'Model Generated Title');
    });

    test('sendMessageStream triggers onAccepted callback on HTTP 200', () async {
      final sseLines = [
        'data: {"type": "token", "content": "Hi"}\n\n',
        'data: {"type": "done", "finish_reason": "stop"}\n\n',
      ];
      final bodyBytes = utf8.encode(sseLines.join());

      final mockStreamClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(Stream.fromIterable([bodyBytes]), 200);
      });

      bool acceptedCalled = false;
      final client = CompanionClient();
      final stream = client.sendMessageStream(
        'conv-1',
        const MessageSend(userText: 'Hello'),
        customClient: mockStreamClient,
        onAccepted: () {
          acceptedCalled = true;
        },
      );

      final events = await stream.toList();
      expect(events.length, 2);
      expect(acceptedCalled, isTrue);
    });

    test('sendMessageStream does NOT trigger onAccepted callback on HTTP 503', () async {
      final mockStreamClient = MockClient.streaming((request, bodyStream) async {
        final errBytes = utf8.encode(jsonEncode({'detail': 'LLM_UNAVAILABLE'}));
        return http.StreamedResponse(Stream.fromIterable([errBytes]), 503);
      });

      bool acceptedCalled = false;
      final client = CompanionClient();
      final stream = client.sendMessageStream(
        'conv-1',
        const MessageSend(userText: 'Turn'),
        customClient: mockStreamClient,
        onAccepted: () {
          acceptedCalled = true;
        },
      );

      try {
        await stream.toList();
      } catch (_) {}
      expect(acceptedCalled, isFalse);
    });

    test('validateBaseUrl parses valid URL and rejects invalid scheme', () {
      final valid = CompanionClient.validateBaseUrl('http://localhost:8000/');
      expect(valid.scheme, 'http');
      expect(valid.port, 8000);

      expect(
        () => CompanionClient.validateBaseUrl('ftp://localhost:8000'),
        throwsArgumentError,
      );
    });
  });
}
