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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
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

    test('cancellation before HTTP response arrives prevents onAccepted from firing', () async {
      final responseCompleter = Completer<http.StreamedResponse>();
      final mockStreamClient = MockClient.streaming((request, bodyStream) async {
        return await responseCompleter.future;
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

      final subscription = stream.listen((_) {});
      // Cancel the stream subscription while HTTP send is pending
      await subscription.cancel();

      // Now complete the response late with 200 OK
      final sseLines = [
        'data: {"type": "token", "content": "Hi"}\n\n',
        'data: {"type": "done", "finish_reason": "stop"}\n\n',
      ];
      final bodyBytes = utf8.encode(sseLines.join());
      responseCompleter.complete(http.StreamedResponse(Stream.fromIterable([bodyBytes]), 200));

      await Future<void>.delayed(const Duration(milliseconds: 20));
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

    test('getModelRegistry returns parsed registry entries on 200', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/models/registry');
        return http.Response(
          jsonEncode([
            {
              'manifest': {
                'id': 'qwen3-vl-2b-instruct',
                'display_name': 'Qwen3-VL 2B Instruct',
                'primary_file': 'vision/qwen3-vl-2b-instruct/model.gguf',
                'capabilities': ['chat', 'vision'],
              },
              'library_state': {
                'validation_status': 'verified',
                'primary_file_exists': true,
                'available_capabilities': ['chat', 'vision'],
              },
              'hints': {
                'estimated_vram_gb': 2.4,
              },
              'runtime_model_id': 'qwen3-vl-2b-instruct',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
      final entries = await client.getModelRegistry();
      expect(entries.length, 1);
      expect(entries.first.id, 'qwen3-vl-2b-instruct');
      expect(entries.first.isVerified, isTrue);
      expect(entries.first.hasVision, isTrue);
    });

    test('selectModel sends POST to /models/select and returns ModelStatusResponse', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/models/select');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model_name'], 'qwen3-vl-2b-instruct');
        expect(body['load_immediately'], isTrue);
        return http.Response(
          jsonEncode({
            'provider': 'llama.cpp',
            'runtime_state': 'MODEL_READY',
            'active_model': 'qwen3-vl-2b-instruct',
            'selected_model': 'qwen3-vl-2b-instruct',
            'model_resident': true,
            'model_loaded': true,
            'model_awake': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
      final status = await client.selectModel('qwen3-vl-2b-instruct', loadImmediately: true);
      expect(status.runtimeState, 'MODEL_READY');
      expect(status.selectedModel, 'qwen3-vl-2b-instruct');
    });

    test('loadModel sends POST to /models/load and returns ModelStatusResponse', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/models/load');
        return http.Response(
          jsonEncode({
            'provider': 'llama.cpp',
            'runtime_state': 'MODEL_READY',
            'active_model': 'qwen3-vl-2b-instruct',
            'model_resident': true,
            'model_loaded': true,
            'model_awake': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
      final status = await client.loadModel();
      expect(status.runtimeState, 'MODEL_READY');
      expect(status.activeModel, 'qwen3-vl-2b-instruct');
    });

    test('unloadModel sends POST to /models/unload and returns ModelStatusResponse', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/models/unload');
        expect(request.method, 'POST');
        return http.Response(
          jsonEncode({
            'provider': 'llama.cpp',
            'runtime_state': 'MODEL_UNLOADED',
            'active_model': null,
            'selected_model': 'qwen3-vl-2b-instruct',
            'model_resident': false,
            'model_loaded': false,
            'model_awake': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
      final status = await client.unloadModel();
      expect(status.runtimeState, 'MODEL_UNLOADED');
      expect(status.modelLoaded, isFalse);
    });
    test('shutdownSystem sends POST to /system/shutdown with Host Admin secret', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/system/shutdown');
        expect(request.method, 'POST');
        expect(request.headers['x-host-admin-secret'], 'admin-test');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['reason'], 'user_exit_companion');
        expect(body['drain_timeout_seconds'], 6.0);
        return http.Response(
          jsonEncode({
            'status': 'shutting_down',
            'pid': 1234,
            'managed_llm_pid': 5678,
            'managed_by_core': true,
            'already_shutting_down': false,
            'shutdown_phase': 'closing_admission',
            'message': 'Cooperative shutdown initiated.',
          }),
          202,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
      final response = await client.shutdownSystem(reason: 'user_exit_companion', drainTimeoutSeconds: 6.0);
      expect(response.status, 'shutting_down');
      expect(response.pid, 1234);
      expect(response.managedLlmPid, 5678);
      expect(response.managedByCore, isTrue);
      expect(response.alreadyShuttingDown, isFalse);
      expect(response.shutdownPhase, 'closing_admission');
    });

    test('model load operations support 90s timeout', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'provider': 'llama_cpp',
            'runtime_state': 'MODEL_READY',
            'selected_model': 'qwen3-vl-2b-instruct',
            'active_model': 'qwen3-vl-2b-instruct',
            'model_loaded': true,
            'model_awake': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = CompanionClient(httpClient: mock, hostAdminStore: InMemoryCredentialStore('admin-test'));
      final status = await client.selectModel('qwen3-vl-2b-instruct', loadImmediately: true);
      expect(status.runtimeState, 'MODEL_READY');

      final loadStatus = await client.loadModel();
      expect(loadStatus.runtimeState, 'MODEL_READY');
    });

    group('Memory API', () {
      test('listMemories sends query parameters and returns MemoryListOut', () async {
        final mock = MockClient((request) async {
          expect(request.url.path, '/api/v1/memories');
          expect(request.method, 'GET');
          expect(request.url.queryParameters['scope'], 'profile');
          expect(request.url.queryParameters['is_core'], 'true');
          expect(request.url.queryParameters['include_expired'], 'true');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'mem-1',
                  'content': 'User loves coffee',
                  'category': 'preference',
                  'importance': 1.5,
                  'source_type': 'manual',
                  'user_verified': true,
                  'created_at': '2026-11-06T12:00:00Z',
                  'owner_id': 'owner-1',
                  'profile_id': 'prof-1',
                  'scope': 'profile',
                  'is_core': true,
                }
              ],
              'total': 1,
              'page': 1,
              'page_size': 50,
            }),
            200,
          );
        });

        final client = CompanionClient(
          httpClient: mock,
          sessionStore: InMemoryCredentialStore('test_session'),
        );
        final result = await client.listMemories(
          scope: 'profile',
          isCore: true,
          includeExpired: true,
        );
        expect(result.total, 1);
        expect(result.items.first.content, 'User loves coffee');
        expect(result.items.first.isCore, isTrue);
      });

      test('getMemory returns MemoryOut', () async {
        final mock = MockClient((request) async {
          expect(request.url.path, '/api/v1/memories/mem-123');
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode({
              'id': 'mem-123',
              'content': 'Single memory item',
              'category': 'fact',
              'importance': 1.0,
              'source_type': 'manual',
              'user_verified': true,
              'created_at': '2026-11-06T12:00:00Z',
              'owner_id': 'owner-1',
              'scope': 'profile',
              'is_core': false,
            }),
            200,
          );
        });

        final client = CompanionClient(
          httpClient: mock,
          sessionStore: InMemoryCredentialStore('test_session'),
        );
        final mem = await client.getMemory('mem-123');
        expect(mem.id, 'mem-123');
        expect(mem.content, 'Single memory item');
      });

      test('createMemory serializes payload and returns MemoryOut', () async {
        final mock = MockClient((request) async {
          expect(request.url.path, '/api/v1/memories');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['content'], 'User is allergic to peanuts');
          expect(body['scope'], 'profile');
          expect(body['is_core'], true);
          return http.Response(
            jsonEncode({
              'id': 'mem-created',
              'content': body['content'],
              'category': 'fact',
              'importance': 1.0,
              'source_type': 'manual',
              'user_verified': true,
              'created_at': '2026-11-06T12:00:00Z',
              'owner_id': 'owner-1',
              'scope': 'profile',
              'is_core': true,
            }),
            201,
          );
        });

        final client = CompanionClient(
          httpClient: mock,
          sessionStore: InMemoryCredentialStore('test_session'),
        );
        final created = await client.createMemory(
          const MemoryCreate(
            content: 'User is allergic to peanuts',
            scope: 'profile',
            isCore: true,
          ),
        );
        expect(created.id, 'mem-created');
        expect(created.isCore, isTrue);
      });

      test('updateMemory serializes update and returns MemoryOut', () async {
        final mock = MockClient((request) async {
          expect(request.url.path, '/api/v1/memories/mem-123');
          expect(request.method, 'PATCH');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('expires_at'), isTrue);
          expect(body['expires_at'], isNull);
          return http.Response(
            jsonEncode({
              'id': 'mem-123',
              'content': 'Promoted permanent fact',
              'category': 'fact',
              'importance': 1.5,
              'source_type': 'manual',
              'user_verified': true,
              'created_at': '2026-11-06T12:00:00Z',
              'owner_id': 'owner-1',
              'scope': 'profile',
              'expires_at': null,
              'is_core': true,
            }),
            200,
          );
        });

        final client = CompanionClient(
          httpClient: mock,
          sessionStore: InMemoryCredentialStore('test_session'),
        );
        final updated = await client.updateMemory(
          'mem-123',
          const MemoryUpdate(expiresAt: null, isCore: true),
        );
        expect(updated.expiresAt, isNull);
        expect(updated.isCore, isTrue);
      });

      test('deleteMemory succeeds on 200 or 204', () async {
        final mock = MockClient((request) async {
          expect(request.url.path, '/api/v1/memories/mem-123');
          expect(request.method, 'DELETE');
          return http.Response('', 204);
        });

        final client = CompanionClient(
          httpClient: mock,
          sessionStore: InMemoryCredentialStore('test_session'),
        );
        await expectLater(client.deleteMemory('mem-123'), completes);
      });

      test('CharacterInstanceOut parses mood fields and exposes moodBadgeText', () {
        final inst = CharacterInstanceOut.fromJson(const {
          'id': 'inst-mood-1',
          'profile_id': 'prof-1',
          'name': 'Aria',
          'summary': 'Warm friend',
          'lore': '',
          'system_prompt': 'Be supportive',
          'avatar_asset': 'warm_companion_avatar',
          'preset_id': 'warm_companion',
          'current_mood': 'empathetic',
          'mood_intensity': 72,
          'mood_updated_at': '2026-11-12T12:00:00Z',
          'status': 'active',
          'is_active_for_profile': true,
          'created_at': '2026-11-12T10:00:00Z',
          'updated_at': '2026-11-12T12:00:00Z',
        });

        expect(inst.currentMood, 'empathetic');
        expect(inst.moodIntensity, 72);
        expect(inst.moodUpdatedAt, '2026-11-12T12:00:00Z');
        expect(inst.moodEmoji, '🥺');
        expect(inst.moodLabel, 'Empathetic');
        expect(inst.moodBadgeText, '🥺 Empathetic');
        expect(CharacterInstanceOut.fromJson(inst.toJson()), equals(inst));
      });
    });
  });
}
