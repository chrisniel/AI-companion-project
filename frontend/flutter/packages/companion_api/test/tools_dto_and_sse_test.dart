import 'dart:convert';

import 'package:companion_api/companion_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('D9 Tools DTOs and SSE events', () {
    test('MessageOut parses toolReceipts, sources, and pendingConfirmations', () {
      final msg = MessageOut.fromJson({
        'id': 'm1',
        'conversation_id': 'c1',
        'sender': 'assistant',
        'content': 'Forecast ready.',
        'status': 'completed',
        'sequence_no': 2,
        'created_at': '2026-11-16T10:00:00Z',
        'tool_receipts': [
          {
            'tool_name': 'weather_lookup',
            'risk_tier': 0,
            'provenance': 'EXPLICIT_USER',
            'decision': 'ALLOW',
            'outcome_status': 'executed',
            'summary': 'Weather in Manila: Clear 30C.',
            'duration_ms': 42,
          },
        ],
        'sources': [
          {
            'title': 'Open-Meteo: Manila',
            'url': 'https://api.open-meteo.com/v1/forecast',
            'domain': 'api.open-meteo.com',
            'snippet': '30C clear',
          },
        ],
        'pending_confirmations': [
          {
            'id': 'conf1',
            'conversation_id': 'c1',
            'tool_name': 'delete_task',
            'risk_tier': 2,
            'provenance': 'EXPLICIT_USER',
            'target_summary': 'Old Task',
            'arguments_preview': '{"task_id":"t1"}',
            'fingerprint': 'abcd',
            'status': 'pending',
            'expires_at': '2026-11-16T10:02:00Z',
            'created_at': '2026-11-16T10:00:00Z',
          },
        ],
      });

      expect(msg.toolReceipts, hasLength(1));
      expect(msg.toolReceipts.first.toolName, 'weather_lookup');
      expect(msg.sources, hasLength(1));
      expect(msg.sources.first.domain, 'api.open-meteo.com');
      expect(msg.pendingConfirmations, hasLength(1));
      expect(msg.pendingConfirmations.first.toolName, 'delete_task');
    });

    test('SseStreamParser parses D9 tool_intent, tool_confirmation_required, and tool_result', () async {
      final frames = [
        'data: ${jsonEncode({'type': 'tool_intent', 'tool_name': 'weather_lookup', 'risk_tier': 0, 'provenance': 'EXPLICIT_USER'})}\n\n',
        'data: ${jsonEncode({'type': 'tool_result', 'tool_name': 'weather_lookup', 'decision': 'ALLOW', 'outcome_status': 'executed', 'summary': '30C', 'sources': [{'title': 'OM', 'url': 'https://api.open-meteo.com/v1', 'domain': 'api.open-meteo.com'}]})}\n\n',
        'data: ${jsonEncode({'type': 'tool_confirmation_required', 'tool_name': 'delete_task', 'confirmation': {'id': 'c1', 'conversation_id': 'conv1', 'tool_name': 'delete_task', 'risk_tier': 2, 'provenance': 'EXPLICIT_USER', 'target_summary': 'Task 1', 'arguments_preview': '{}', 'fingerprint': 'fp1', 'status': 'pending', 'expires_at': '2026-11-16T10:05:00Z', 'created_at': '2026-11-16T10:00:00Z'}})}\n\n',
        'data: ${jsonEncode({'type': 'token', 'content': 'Done.'})}\n\n',
        'data: ${jsonEncode({'type': 'done', 'finish_reason': 'stop'})}\n\n',
        'data: [DONE]\n\n',
      ];

      final events = await const SseStreamParser()
          .parseByteStream(Stream<List<int>>.fromIterable(frames.map(utf8.encode)))
          .toList();

      expect(events[0], isA<SseToolIntentEvent>());
      expect((events[0] as SseToolIntentEvent).toolName, 'weather_lookup');
      expect(events[1], isA<SseToolResultEvent>());
      expect((events[1] as SseToolResultEvent).sources.single.domain, 'api.open-meteo.com');
      expect(events[2], isA<SseToolConfirmationRequiredEvent>());
      expect((events[2] as SseToolConfirmationRequiredEvent).confirmation.id, 'c1');
      expect(events[3], const SseTokenEvent('Done.'));
      expect(events[4], const SseDoneEvent(finishReason: 'stop'));
      expect(events.length, 5);
    });

    test('CompanionClient routes D9 endpoints and Host Admin controls accurately', () async {
      final recorded = <String>[];
      final mockClient = MockClient((http.Request req) async {
        recorded.add('${req.method} ${req.url.path} admin=${req.headers.containsKey('X-Host-Admin-Secret')}');
        if (req.url.path == '/api/v1/tools/policy' && req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'profile_id': 'p1',
              'global_kill_switch': false,
              'risk0_policy': 'allow',
              'risk1_explicit_policy': 'allow',
              'risk1_suggested_policy': 'confirm',
              'risk2_policy': 'confirm',
              'weather_provider': 'open_meteo',
              'web_search_provider': 'public_search',
              'search_api_key_configured': false,
              'updated_at': '2026-11-16T10:00:00Z',
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/tools/kill-switch' && req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'global_kill_switch': body['enabled']}),
            200,
          );
        }
        if (req.url.path == '/api/v1/tools/web-config' && req.method == 'PUT') {
          return http.Response(
            jsonEncode({
              'weather_provider': 'open_meteo',
              'web_search_provider': 'searxng',
              'searxng_base_url': 'http://127.0.0.1:8888',
              'search_api_key_configured': false,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final sessStore = InMemoryCredentialStore()..writeToken('sess-tok');
      final adminStore = InMemoryCredentialStore()..writeToken('admin-sec');
      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockClient,
        sessionStore: sessStore,
        hostAdminStore: adminStore,
      );

      final policy = await client.getToolPolicy();
      expect(policy.risk0Policy, 'allow');

      final onRes = await client.setKillSwitch(const KillSwitchRequest(enabled: true));
      expect(onRes.globalKillSwitch, isTrue);

      final offRes = await client.setKillSwitch(const KillSwitchRequest(enabled: false));
      expect(offRes.globalKillSwitch, isFalse);

      final webRes = await client.updateWebConfig(
        const WebConfigUpdateRequest(webSearchProvider: 'searxng', searxngBaseUrl: 'http://127.0.0.1:8888'),
      );
      expect(webRes.webSearchProvider, 'searxng');

      expect(recorded[0], 'GET /api/v1/tools/policy admin=false');
      expect(recorded[1], 'POST /api/v1/tools/kill-switch admin=false');
      expect(recorded[2], 'POST /api/v1/tools/kill-switch admin=true');
      expect(recorded[3], 'PUT /api/v1/tools/web-config admin=true');
    });
  });
}
