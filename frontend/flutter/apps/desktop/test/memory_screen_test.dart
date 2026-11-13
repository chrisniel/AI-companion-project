import 'dart:convert';
import 'package:ai_companion_desktop/features/memory/desktop_memory_controller.dart';
import 'package:ai_companion_desktop/screens/memory_screen.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('MemoryScreen Widget Tests', () {
    late List<Map<String, dynamic>> recordedRequests;
    late List<Map<String, dynamic>> mockMemories;
    late List<Map<String, dynamic>> mockConflicts;
    late bool filterByTier;
    late int mockKnowledgeCount;
    late int mockLongTermCount;
    late int mockShortTermCount;

    void setupDesktopViewport(WidgetTester tester, {Size size = const Size(1280, 800)}) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    setUp(() {
      recordedRequests = [];
      filterByTier = false;
      mockKnowledgeCount = 1;
      mockLongTermCount = 1;
      mockShortTermCount = 0;
      mockMemories = [
        {
          'id': 'mem-1',
          'content': 'User loves iced matcha lattes',
          'category': 'preference',
          'importance': 0.8,
          'source_type': 'auto_extracted',
          'user_verified': false,
          'created_at': '2026-11-06T10:00:00Z',
          'owner_id': 'prof-1',
          'scope': 'profile',
          'is_core': false,
          'recall_count': 0,
        },
        {
          'id': 'mem-2',
          'content': 'User lives in Tokyo',
          'category': 'fact',
          'importance': 1.0,
          'source_type': 'user_explicit',
          'user_verified': true,
          'created_at': '2026-11-06T09:00:00Z',
          'owner_id': 'prof-1',
          'scope': 'profile',
          'is_core': true,
          'recall_count': 2,
        },
      ];
      mockConflicts = [
        {
          'id': 'mem-conflict-1',
          'content': 'User dislikes matcha',
          'category': 'preference',
          'importance': 1.0,
          'source_type': 'conflict',
          'user_verified': false,
          'created_at': '2026-11-06T11:00:00Z',
          'owner_id': 'prof-1',
          'scope': 'profile',
          'is_core': false,
        },
      ];
    });

    CompanionClient createMockClient() {
      final mockHttpClient = MockClient((request) async {
        recordedRequests.add({
          'method': request.method,
          'url': request.url.toString(),
          'body': request.body.isNotEmpty ? jsonDecode(request.body) : null,
        });

        final path = request.url.path;

        // GET /api/v1/memories
        if (request.method == 'GET' && path == '/api/v1/memories') {
          final isConflictQuery = request.url.queryParameters['source_type'] == 'conflict' &&
              request.url.queryParameters['user_verified'] == 'false';

          if (isConflictQuery) {
            return http.Response(
              jsonEncode({
                'items': mockConflicts,
                'total': mockConflicts.length,
                'page': 1,
                'page_size': 10,
                'knowledge_count': mockKnowledgeCount,
                'long_term_count': mockLongTermCount,
                'short_term_count': mockShortTermCount,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          final requestedTier = request.url.queryParameters['tier'];
          final items = filterByTier && requestedTier != null
              ? mockMemories.where((m) => m['_tier'] == requestedTier).toList()
              : mockMemories;

          return http.Response(
            jsonEncode({
              'items': items,
              'total': items.length,
              'page': 1,
              'page_size': 20,
              'knowledge_count': mockKnowledgeCount,
              'long_term_count': mockLongTermCount,
              'short_term_count': mockShortTermCount,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // POST /api/v1/memories
        if (request.method == 'POST' && path == '/api/v1/memories') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 'mem-new-1',
              'content': body['content'] ?? '',
              'category': body['category'] ?? 'fact',
              'importance': body['importance'] ?? 1.0,
              'source_type': body['source_type'] ?? 'manual',
              'user_verified': true,
              'created_at': '2026-11-13T10:00:00Z',
              'owner_id': 'prof-1',
              'scope': body['scope'] ?? 'profile',
              'is_core': body['is_core'] ?? false,
              'trigger_keywords': body['trigger_keywords'],
              'expires_at': body['expires_at'],
              'recall_count': 0,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        // PATCH /api/v1/memories/{id}
        if (request.method == 'PATCH' && path.startsWith('/api/v1/memories/')) {
          final id = path.split('/').last;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': id,
              'content': body['content'] ?? 'Updated content',
              'category': body['category'] ?? 'fact',
              'importance': 0.8,
              'source_type': body['source_type'] ?? 'user_explicit',
              'user_verified': body['user_verified'] ?? true,
              'created_at': '2026-11-06T10:00:00Z',
              'owner_id': 'prof-1',
              'scope': 'profile',
              'is_core': body['is_core'] ?? false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // DELETE /api/v1/memories/{id}
        if (request.method == 'DELETE' && path.startsWith('/api/v1/memories/')) {
          return http.Response(
            jsonEncode({'status': 'deleted'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // PATCH /api/v1/profiles/{id}
        if (request.method == 'PATCH' && path.startsWith('/api/v1/profiles/')) {
          return http.Response(
            jsonEncode({
              'id': 'prof-1',
              'name': 'Test Profile',
              'memory_extraction_enabled': true,
              'status': 'active',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      return CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_test'),
        hostAdminStore: InMemoryCredentialStore('test-admin-secret'),
        httpClient: mockHttpClient,
      );
    }

    testWidgets('renders initializing state when controller is null', (tester) async {
      setupDesktopViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: const Scaffold(body: MemoryScreen(controller: null)),
        ),
      );

      expect(find.text('Memory service is initializing...'), findsOneWidget);
    });

    testWidgets('renders screen header, toggle switch, and empty state when empty', (tester) async {
      setupDesktopViewport(tester);

      mockMemories.clear();
      mockConflicts.clear();

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Memory & Knowledge'), findsOneWidget);
      expect(find.text('Auto-Extract Facts'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('No memories found'), findsOneWidget);
    });

    testWidgets('renders memory cards, badges, and conflict banner when populated', (tester) async {
      setupDesktopViewport(tester);

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Verify conflict banner
      expect(find.text('Memory Contradiction Detected (1)'), findsOneWidget);
      expect(find.text('User dislikes matcha'), findsOneWidget);
      expect(find.text('Keep New'), findsOneWidget);
      expect(find.textContaining('Keep Old'), findsOneWidget);

      // Verify memory cards
      expect(find.text('User loves iced matcha lattes'), findsOneWidget);
      expect(find.text('User lives in Tokyo'), findsOneWidget);
      expect(find.text('PENDING REVIEW'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('approving pending memory updates item status', (tester) async {
      setupDesktopViewport(tester);

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      final patchReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'PATCH' && (r['url'] as String).contains('/api/v1/memories/mem-1'),
      );
      expect((patchReq['body'] as Map<String, dynamic>)['user_verified'], isTrue);
    });

    testWidgets('resolves conflict using Keep New action', (tester) async {
      setupDesktopViewport(tester);

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keep New'), findsOneWidget);
      await tester.tap(find.text('Keep New'));
      await tester.pumpAndSettle();

      final keepNewReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'PATCH' && (r['url'] as String).contains('mem-conflict-1'),
      );
      final body = keepNewReq['body'] as Map<String, dynamic>;
      expect(body['user_verified'], isTrue);
      expect(body['source_type'], equals('manual'));
    });

    testWidgets('toggling auto-extract facts switch calls API', (tester) async {
      setupDesktopViewport(tester);

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final profileReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'PATCH' && (r['url'] as String).contains('/api/v1/profiles/prof-1'),
      );
      expect((profileReq['body'] as Map<String, dynamic>)['memory_extraction_enabled'], isFalse);
    });

    testWidgets('opens edit dialog and saves modified memory', (tester) async {
      setupDesktopViewport(tester);

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Find the edit button for the first memory
      final editButton = find.byTooltip('Edit Memory').first;
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Edit Memory'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Enter new text in the content field
      await tester.enterText(find.byKey(const Key('memory_content_field')), 'User loves hot green tea');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify PATCH request
      final patchReq = recordedRequests.lastWhere(
        (r) => r['method'] == 'PATCH' && (r['url'] as String).contains('/api/v1/memories/mem-1'),
      );
      expect((patchReq['body'] as Map<String, dynamic>)['content'], equals('User loves hot green tea'));
    });

    testWidgets('opens delete confirmation and deletes memory', (tester) async {
      setupDesktopViewport(tester);

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      final deleteButton = find.byTooltip('Delete Memory').first;
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Delete Memory?'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      final deleteReq = recordedRequests.firstWhere(
        (r) => r['method'] == 'DELETE' && (r['url'] as String).contains('/api/v1/memories/mem-1'),
      );
      expect(deleteReq, isNotNull);
    });

    testWidgets('Option 2A tier sidebar switches tiers, updates CTA, and supports compact layout', (tester) async {
      setupDesktopViewport(tester);
      filterByTier = true;
      mockKnowledgeCount = 2;
      mockLongTermCount = 3;
      mockShortTermCount = 1;
      mockConflicts.clear();

      mockMemories = [
        {
          '_tier': 'knowledge',
          'id': 'k-1',
          'content': 'Sarah loves sourdough bread',
          'category': 'fact',
          'importance': 1.5,
          'source_type': 'manual',
          'user_verified': true,
          'created_at': '2026-11-13T10:00:00Z',
          'owner_id': 'prof-1',
          'scope': 'profile',
          'is_core': false,
          'trigger_keywords': ['sarah', 'cook'],
          'recall_count': 4,
        },
        {
          '_tier': 'long_term',
          'id': 'lt-1',
          'content': 'User enjoys sci-fi novels',
          'category': 'preference',
          'importance': 1.0,
          'source_type': 'user_explicit',
          'user_verified': true,
          'created_at': '2026-11-13T10:00:00Z',
          'owner_id': 'prof-1',
          'scope': 'profile',
          'is_core': false,
          'recall_count': 1,
        },
        {
          '_tier': 'short_term',
          'id': 'st-1',
          'content': 'User has a deadline tonight',
          'category': 'context',
          'importance': 0.9,
          'source_type': 'auto_extracted',
          'user_verified': false,
          'created_at': '2026-11-13T10:00:00Z',
          'owner_id': 'prof-1',
          'scope': 'profile',
          'expires_at': DateTime.now().toUtc().add(const Duration(hours: 48)).toIso8601String(),
          'is_core': false,
          'recall_count': 0,
        },
      ];

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Default tier is Knowledge & Profile with keyword chips and recall counter
      expect(find.text('Knowledge & Profile'), findsOneWidget);
      expect(find.text('Long-Term Memories'), findsOneWidget);
      expect(find.text('Short-Term Context'), findsOneWidget);
      expect(find.text('Add Knowledge'), findsOneWidget);
      expect(find.text('Sarah loves sourdough bread'), findsOneWidget);
      expect(find.text('#sarah'), findsOneWidget);
      expect(find.text('#cook'), findsOneWidget);
      expect(find.text('RECALLED 4×'), findsOneWidget);

      // Switch to Long-Term Memories
      await tester.tap(find.byKey(const Key('memory_tier_long_term')));
      await tester.pumpAndSettle();
      expect(find.text('Add Memory'), findsOneWidget);
      expect(find.text('User enjoys sci-fi novels'), findsOneWidget);
      expect(
        recordedRequests.any((r) => (r['url'] as String).contains('tier=long_term')),
        isTrue,
      );

      // Switch to Short-Term Context and promote entry
      await tester.tap(find.byKey(const Key('memory_tier_short_term')));
      await tester.pumpAndSettle();
      expect(find.text('Add Context'), findsOneWidget);
      expect(find.text('User has a deadline tonight'), findsOneWidget);
      expect(find.text('Promote'), findsOneWidget);
      expect(find.textContaining('TTL'), findsOneWidget);

      await tester.tap(find.byKey(const Key('promote_memory_st-1')));
      await tester.pumpAndSettle();

      final promotePatch = recordedRequests.lastWhere(
        (r) => r['method'] == 'PATCH' && (r['url'] as String).contains('/api/v1/memories/st-1'),
      );
      final promoteBody = promotePatch['body'] as Map<String, dynamic>;
      expect(promoteBody['expires_at'], isNull);
      expect(promoteBody['category'], 'fact');
      expect(promoteBody['source_type'], 'user_explicit');
      expect(promoteBody['user_verified'], isTrue);
    });

    testWidgets('Add Knowledge dialog submits manual lorebook trigger keywords', (tester) async {
      setupDesktopViewport(tester);
      mockConflicts.clear();

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_memory_cta')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('memory_content_field')),
        'Kael runs the harbor workshop',
      );
      await tester.enterText(
        find.byKey(const Key('memory_keywords_field')),
        'kael, harbor, workshop',
      );
      await tester.tap(find.text('Create Memory'));
      await tester.pumpAndSettle();

      final postReq = recordedRequests.lastWhere((r) => r['method'] == 'POST');
      final body = postReq['body'] as Map<String, dynamic>;
      expect(body['content'], 'Kael runs the harbor workshop');
      expect(body['source_type'], 'manual');
      expect(body['is_core'], isTrue);
      expect(body['trigger_keywords'], ['kael', 'harbor', 'workshop']);
    });

    testWidgets('renders compact horizontal tier switcher under narrow width without overflow', (tester) async {
      setupDesktopViewport(tester, size: const Size(640, 800));
      mockConflicts.clear();

      final client = createMockClient();
      final controller = DesktopMemoryController(
        client: client,
        profileId: 'prof-1',
        initialExtractionEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(body: MemoryScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('memory_tier_knowledge')), findsOneWidget);
      expect(find.byKey(const Key('memory_tier_long_term')), findsOneWidget);
      expect(find.byKey(const Key('memory_tier_short_term')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
