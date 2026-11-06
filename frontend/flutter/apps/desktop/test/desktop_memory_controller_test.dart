import 'dart:convert';
import 'package:ai_companion_desktop/features/memory/desktop_memory_controller.dart';
import 'package:companion_api/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('DesktopMemoryController Unit Tests', () {
    late List<Map<String, dynamic>> recordedRequests;
    late MockClient mockHttpClient;
    late CompanionClient client;
    late DesktopMemoryController controller;

    setUp(() {
      recordedRequests = [];

      mockHttpClient = MockClient((request) async {
        recordedRequests.add({
          'method': request.method,
          'url': request.url.toString(),
          'body': request.body.isNotEmpty ? jsonDecode(request.body) : null,
        });

        // 1. GET /api/v1/memories
        if (request.method == 'GET' && request.url.path == '/api/v1/memories') {
          final isConflictQuery = request.url.queryParameters['source_type'] == 'conflict' &&
              request.url.queryParameters['user_verified'] == 'false';

          if (isConflictQuery) {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'mem-conflict-1',
                    'content': 'Conflicting statement: user dislikes tea',
                    'category': 'preference',
                    'importance': 1.0,
                    'source_type': 'conflict',
                    'user_verified': false,
                    'created_at': '2026-11-06T10:00:00Z',
                    'owner_id': 'prof-1',
                    'scope': 'profile',
                    'is_core': false,
                  }
                ],
                'total': 1,
                'page': 1,
                'page_size': 10,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'mem-1',
                  'content': 'User loves drinking matcha tea',
                  'category': 'preference',
                  'importance': 1.5,
                  'source_type': 'manual',
                  'user_verified': true,
                  'created_at': '2026-11-06T09:00:00Z',
                  'owner_id': 'prof-1',
                  'scope': 'profile',
                  'is_core': true,
                },
                {
                  'id': 'mem-2',
                  'content': 'Candidate fact about living in Seattle',
                  'category': 'fact',
                  'importance': 1.0,
                  'source_type': 'extracted',
                  'user_verified': false,
                  'created_at': '2026-11-06T09:30:00Z',
                  'owner_id': 'prof-1',
                  'scope': 'profile',
                  'is_core': false,
                }
              ],
              'total': 2,
              'page': 1,
              'page_size': 50,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // 2. PATCH /api/v1/memories/{id}
        if (request.method == 'PATCH' && request.url.path.startsWith('/api/v1/memories/')) {
          final id = request.url.pathSegments.last;
          final dynamic body = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'id': id,
              'content': body['content'] ?? 'Updated content',
              'category': body['category'] ?? 'fact',
              'importance': body['importance'] ?? 1.0,
              'source_type': body['source_type'] ?? 'manual',
              'user_verified': body['user_verified'] ?? true,
              'created_at': '2026-11-06T09:00:00Z',
              'owner_id': 'prof-1',
              'scope': 'profile',
              'last_verified_at': '2026-11-06T10:05:00Z',
              'is_core': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // 3. DELETE /api/v1/memories/{id}
        if (request.method == 'DELETE' && request.url.path.startsWith('/api/v1/memories/')) {
          return http.Response('', 204);
        }

        // 4. POST /api/v1/memories
        if (request.method == 'POST' && request.url.path == '/api/v1/memories') {
          final dynamic body = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'id': 'mem-new-1',
              'content': body['content'],
              'category': body['category'] ?? 'fact',
              'importance': body['importance'] ?? 1.0,
              'source_type': 'manual',
              'user_verified': true,
              'created_at': '2026-11-06T10:10:00Z',
              'owner_id': 'prof-1',
              'scope': body['scope'] ?? 'profile',
              'is_core': body['is_core'] ?? false,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // 5. PATCH /api/v1/profiles/{id}
        if (request.method == 'PATCH' && request.url.path.startsWith('/api/v1/profiles/')) {
          final id = request.url.pathSegments.last;
          final dynamic body = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'id': id,
              'name': 'Test Profile',
              'is_default': true,
              'status': 'active',
              'pin_protected': false,
              'memory_extraction_enabled': body['memory_extraction_enabled'] ?? true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockHttpClient,
        hostAdminStore: InMemoryCredentialStore('test-admin-secret'),
      );

      controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        activeCharacterInstanceId: 'char-1',
      );
    });

    test('loadMemories fetches both conflicts and main list', () async {
      await controller.loadMemories();

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.memories.length, equals(2));
      expect(controller.activeConflicts.length, equals(1));
      expect(controller.activeConflicts.first.id, equals('mem-conflict-1'));
    });

    test('approveMemory marks unverified memory as verified via PATCH', () async {
      await controller.loadMemories();
      final success = await controller.approveMemory('mem-2');

      expect(success, isTrue);
      final patchReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'PATCH' && (r['url'] as String).contains('/memories/mem-2'),
      );
      expect(patchReq['body']['user_verified'], isTrue);
    });

    test('deleteMemory calls DELETE /api/v1/memories/{id}', () async {
      await controller.loadMemories();
      final success = await controller.deleteMemory('mem-1');

      expect(success, isTrue);
      expect(
        recordedRequests.any(
          (r) => r['method'] == 'DELETE' && (r['url'] as String).contains('/memories/mem-1'),
        ),
        isTrue,
      );
    });

    test('createMemory calls POST /api/v1/memories with payload', () async {
      final success = await controller.createMemory(
        const MemoryCreate(content: 'New manual fact', category: 'fact'),
      );

      expect(success, isTrue);
      final postReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'POST' && (r['url'] as String).contains('/memories'),
      );
      expect(postReq['body']['content'], equals('New manual fact'));
    });

    test('resolveConflictKeepNew approves conflict and deletes old memory', () async {
      await controller.loadMemories();
      final conflict = controller.activeConflicts.first;
      final old = controller.memories.first;

      final success = await controller.resolveConflictKeepNew(
        conflictMemory: conflict,
        oldMemory: old,
      );

      expect(success, isTrue);
      // Verify conflict patched to verified & manual
      final patchReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'PATCH' && (r['url'] as String).contains('/memories/${conflict.id}'),
      );
      expect(patchReq['body']['user_verified'], isTrue);
      expect(patchReq['body']['source_type'], equals('manual'));

      // Verify old memory deleted
      final delReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'DELETE' && (r['url'] as String).contains('/memories/${old.id}'),
      );
      expect(delReq, isNotNull);
    });

    test('resolveConflictKeepOld deletes conflict memory', () async {
      await controller.loadMemories();
      final conflict = controller.activeConflicts.first;

      final success = await controller.resolveConflictKeepOld(conflictMemory: conflict);

      expect(success, isTrue);
      final delReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'DELETE' && (r['url'] as String).contains('/memories/${conflict.id}'),
      );
      expect(delReq, isNotNull);
    });

    test('resolveConflictMerge updates old memory and deletes conflict memory', () async {
      await controller.loadMemories();
      final conflict = controller.activeConflicts.first;
      final old = controller.memories.first;

      final success = await controller.resolveConflictMerge(
        conflictMemory: conflict,
        oldMemory: old,
        mergedContent: 'User prefers herbal tea over green tea',
      );

      expect(success, isTrue);
      final patchReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'PATCH' && (r['url'] as String).contains('/memories/${old.id}'),
      );
      expect(patchReq['body']['content'], equals('User prefers herbal tea over green tea'));

      final delReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'DELETE' && (r['url'] as String).contains('/memories/${conflict.id}'),
      );
      expect(delReq, isNotNull);
    });

    test('toggleProfileExtraction sends PATCH to profiles and updates state', () async {
      expect(controller.memoryExtractionEnabled, isTrue);

      final success = await controller.toggleProfileExtraction(false);

      expect(success, isTrue);
      expect(controller.memoryExtractionEnabled, isFalse);
      final patchProf = recordedRequests.firstWhere(
        (r) => r['method'] == 'PATCH' && (r['url'] as String).contains('/profiles/prof-1'),
      );
      expect(patchProf['body']['memory_extraction_enabled'], isFalse);
    });

    test('filters propagate to listMemories query parameters', () async {
      controller.setSearchQuery('matcha');
      controller.setScopeFilter('profile');
      controller.setCategoryFilter('preference');
      controller.setStatusFilter('verified');

      await controller.loadMemories();

      final lastListReq = recordedRequests.lastWhere(
        (r) => r['method'] == 'GET' && (r['url'] as String).contains('/api/v1/memories?'),
      );
      final url = lastListReq['url'] as String;
      expect(url, contains('q=matcha'));
      expect(url, contains('scope=profile'));
      expect(url, contains('category=preference'));
      expect(url, contains('user_verified=true'));
    });
  });
}
