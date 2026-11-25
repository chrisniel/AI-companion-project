import 'dart:convert';

import 'package:companion_api/companion_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('M5 Batch A Resource Governance DTOs and CompanionClient', () {
    test('ResourcePolicyStatusOut parses complete and unavailable telemetry payloads', () {
      final full = ResourcePolicyStatusOut.fromJson({
        'requested_mode': 'auto',
        'effective_mode': 'low_impact',
        'low_impact_active': true,
        'low_impact_strategy': 'cpu_eco',
        'low_impact_model_id': null,
        'game_process_list': ['cyberpunk2077.exe'],
        'detected_active_games': ['cyberpunk2077.exe'],
        'cooldown_seconds': 45,
        'cooldown_remaining_seconds': 0,
        'transition_state': 'idle',
        'degradation_reason': null,
        'deferred_background_work': true,
        'host_gpu_name': 'Radeon RX 580 Series',
        'host_vram_gb': 8.0,
        'host_ram_gb': 32.0,
        'available_ram_gb': 18.5,
        'applied_profile': 'eco',
        'requested_profile': 'balanced',
        'telemetry_source': 'windows_global_memory_status+windows_winreg',
      });
      expect(full.requestedMode, equals('auto'));
      expect(full.effectiveMode, equals('low_impact'));
      expect(full.lowImpactActive, isTrue);
      expect(full.gameProcessList, equals(['cyberpunk2077.exe']));
      expect(full.hostVramGb, equals(8.0));
      expect(full.availableRamGb, equals(18.5));
      expect(full.appliedProfile, equals('eco'));
      expect(full.requestedProfile, equals('balanced'));

      final minimal = ResourcePolicyStatusOut.fromJson({
        'requested_mode': 'normal',
        'effective_mode': 'normal',
        'low_impact_active': false,
        'low_impact_strategy': 'cpu_eco',
        'game_process_list': <String>[],
        'detected_active_games': <String>[],
        'cooldown_seconds': 45,
        'cooldown_remaining_seconds': 0,
        'transition_state': 'idle',
        'deferred_background_work': false,
        'requested_profile': 'balanced',
        'telemetry_source': 'unavailable',
      });
      expect(minimal.hostGpuName, isNull);
      expect(minimal.hostVramGb, isNull);
      expect(minimal.hostRamGb, isNull);
      expect(minimal.availableRamGb, isNull);
      expect(minimal.appliedProfile, isNull);
    });

    test('CompanionClient getResourcePolicy and updateResourcePolicy hit /api/v1/system/resources with admin headers', () async {
      final calls = <String>[];
      final mockHttp = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        expect(request.headers['X-Host-Admin-Secret'], equals('admin-secret-value'));
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['resource_mode'], equals('low_impact'));
          expect(body['cooldown_seconds'], equals(60));
          expect(body['game_process_list'], equals(['eldenring.exe']));
        }
        return http.Response(
          jsonEncode({
            'requested_mode': request.method == 'PUT' ? 'low_impact' : 'normal',
            'effective_mode': request.method == 'PUT' ? 'low_impact' : 'normal',
            'low_impact_active': request.method == 'PUT',
            'low_impact_strategy': 'cpu_eco',
            'low_impact_model_id': null,
            'game_process_list': ['eldenring.exe'],
            'detected_active_games': <String>[],
            'cooldown_seconds': 60,
            'cooldown_remaining_seconds': 0,
            'transition_state': 'idle',
            'degradation_reason': null,
            'deferred_background_work': request.method == 'PUT',
            'host_gpu_name': null,
            'host_vram_gb': null,
            'host_ram_gb': 16.0,
            'available_ram_gb': 9.2,
            'applied_profile': request.method == 'PUT' ? 'eco' : 'balanced',
            'requested_profile': 'balanced',
            'telemetry_source': 'windows_global_memory_status',
          }),
          200,
        );
      });

      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        credentialStore: InMemoryCredentialStore('pairing-tok'),
        hostAdminStore: InMemoryCredentialStore('admin-secret-value'),
        httpClient: mockHttp,
      );
      try {
        final current = await client.getResourcePolicy();
        expect(current.requestedMode, equals('normal'));

        final updated = await client.updateResourcePolicy(
          const ResourcePolicyUpdateRequest(
            resourceMode: 'low_impact',
            lowImpactStrategy: 'cpu_eco',
            gameProcessList: ['eldenring.exe'],
            cooldownSeconds: 60,
          ),
        );
        expect(updated.lowImpactActive, isTrue);
        expect(updated.deferredBackgroundWork, isTrue);
        expect(calls, equals([
          'GET /api/v1/system/resources',
          'PUT /api/v1/system/resources',
        ]));
      } finally {
        client.close();
      }
    });
  });
}
