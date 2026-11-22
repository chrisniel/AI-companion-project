import 'dart:convert';

import 'package:companion_api/companion_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('M2 Batch E DTOs and CompanionClient', () {
    test('ModelRegistryEntry preserves const backward compatibility and enriches metadata', () {
      const legacyConst = ModelRegistryEntry(
        id: 'qwen3-vl-2b-instruct',
        displayName: 'Qwen3-VL 2B Instruct',
        primaryFile: 'vision/qwen3-vl-2b-instruct/Qwen.gguf',
        primaryFileExists: true,
        validationStatus: 'verified',
      );
      expect(legacyConst.isVerified, isTrue);
      expect(legacyConst.isInstalled, isFalse);
      expect(legacyConst.recommendedProfiles, equals(['balanced']));

      final parsed = ModelRegistryEntry.fromJson({
        'manifest': {
          'id': 'custom-gemma',
          'display_name': 'Custom Gemma 4B',
          'primary_file': 'custom-gemma/gemma.gguf',
          'architecture': 'gemma3',
          'quantization': 'Q4_K_M',
          'parameters': '4B',
          'variant': 'instruct',
          'model_max_context': 8192,
          'capabilities': ['chat', 'vision'],
          'sha256_primary': 'abc123',
        },
        'library_state': {
          'validation_status': 'verified',
          'primary_file_exists': true,
          'available_capabilities': ['chat', 'vision'],
          'size_gb': 2.5,
        },
        'hints': {
          'recommended_profiles': ['eco', 'balanced'],
          'estimated_vram_gb': 3.5,
          'estimated_ram_gb': 0.9,
        },
        'runtime_model_id': 'custom-gemma',
        'registry_source': 'installed',
      });

      expect(parsed.isInstalled, isTrue);
      expect(parsed.architecture, equals('gemma3'));
      expect(parsed.quantization, equals('Q4_K_M'));
      expect(parsed.parameters, equals('4B'));
      expect(parsed.variant, equals('instruct'));
      expect(parsed.modelMaxContext, equals(8192));
      expect(parsed.recommendedProfiles, equals(['eco', 'balanced']));
      expect(parsed.estimatedRamGb, equals(0.9));
      expect(parsed.sha256Primary, equals('abc123'));
    });

    test('CompanionClient calls host-admin storage, autostart, and D6 model endpoints cleanly', () async {
      final seenRequests = <String>[];
      final mockHttp = MockClient((request) async {
        seenRequests.add('${request.method} ${request.url.path}');
        expect(request.headers['X-Host-Admin-Secret'], equals('admin-secret-value'));

        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/v1/system/storage':
            return http.Response(
              jsonEncode({
                'bootstrap_path': r'C:\Users\Chris\AppData\Local\AI Companion\bootstrap.json',
                'library_root': r'D:\AILibrary',
                'import_inbox_dir': r'D:\AILibrary\imports\inbox',
                'library_relocatable': true,
                'roots': [
                  {
                    'key': 'library',
                    'label': 'Asset & Model Library Root',
                    'path': r'D:\AILibrary',
                    'exists': true,
                    'free_bytes': 1024,
                    'total_bytes': 4096,
                    'source': 'bootstrap',
                  }
                ],
              }),
              200,
            );
          case 'PUT /api/v1/system/storage/library-root':
            final req = jsonDecode(request.body) as Map<String, dynamic>;
            expect(req['new_library_root'], equals(r'E:\NewLib'));
            return http.Response(
              jsonEncode({
                'bootstrap_path': r'C:\Users\Chris\AppData\Local\AI Companion\bootstrap.json',
                'library_root': r'E:\NewLib',
                'import_inbox_dir': r'E:\NewLib\imports\inbox',
                'library_relocatable': true,
                'roots': <Map<String, dynamic>>[],
              }),
              200,
            );
          case 'GET /api/v1/system/autostart':
          case 'PUT /api/v1/system/autostart':
            return http.Response(
              jsonEncode({
                'supported': true,
                'enabled': true,
                'task_registered': true,
                'task_name': 'AICompanionAutostart',
                'minimized_to_tray': true,
                'command': 'ai_companion_desktop.exe --minimized-to-tray',
                'working_directory': r'C:\AICompanion',
                'status_detail': 'Registered',
              }),
              200,
            );
          case 'PATCH /api/v1/models/profile':
            return http.Response(
              jsonEncode({
                'provider': 'llama_cpp',
                'requested_profile': 'eco',
              }),
              200,
            );
          case 'POST /api/v1/models/import/scan':
            return http.Response(
              jsonEncode({
                'inbox_dir': r'D:\AILibrary\imports\inbox',
                'candidates': [
                  {
                    'relative_path': 'gemma/gemma.gguf',
                    'primary_filename': 'gemma.gguf',
                    'suggested_model_id': 'gemma',
                    'display_name': 'Gemma 4B',
                    'file_size_bytes': 2000000,
                    'size_gb': 2.0,
                    'artifact_valid': true,
                    'architecture': 'gemma3',
                    'quantization': 'Q4_K_M',
                    'detected_capabilities': ['chat', 'vision'],
                    'preflight': {
                      'status': 'recommended',
                      'estimated_vram_gb': 2.9,
                      'host_dedicated_vram_gb': 8.0,
                      'recommended_profile': 'balanced',
                      'message': 'Fits comfortably',
                    },
                  }
                ],
                'warnings': <String>[],
              }),
              200,
            );
          case 'POST /api/v1/models/import/install':
            return http.Response(
              jsonEncode({
                'installed_id': 'gemma',
                'display_name': 'Gemma 4B',
                'primary_file': 'gemma/gemma.gguf',
                'validation_status': 'verified',
                'sha256_primary': 'deadbeef',
              }),
              200,
            );
          case 'DELETE /api/v1/models/registry/gemma':
            return http.Response(
              jsonEncode({
                'deleted_id': 'gemma',
                'message': 'Uninstalled',
              }),
              200,
            );
        }
        return http.Response('Not Found', 404);
      });

      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockHttp,
        hostAdminStore: InMemoryCredentialStore('admin-secret-value'),
      );

      final storage = await client.getStorageRoots();
      expect(storage.libraryRoot, equals(r'D:\AILibrary'));
      expect(storage.roots.single.key, equals('library'));

      final moved = await client.relocateLibraryRoot(
        const LibraryRootUpdateRequest(newLibraryRoot: r'E:\NewLib'),
      );
      expect(moved.libraryRoot, equals(r'E:\NewLib'));

      final autoStatus = await client.getAutostartStatus();
      expect(autoStatus.enabled, isTrue);

      final autoUpdated = await client.updateAutostart(
        const AutostartUpdateRequest(enabled: true, minimizedToTray: true),
      );
      expect(autoUpdated.minimizedToTray, isTrue);

      final profStatus = await client.updateModelProfile('eco');
      expect(profStatus.requestedProfile, equals('eco'));

      final scan = await client.scanModelImportInbox();
      expect(scan.candidates.single.suggestedModelId, equals('gemma'));

      final installed = await client.installModelFromInbox(
        const ModelImportInstallRequest(
          relativePath: 'gemma/gemma.gguf',
          modelId: 'gemma',
        ),
      );
      expect(installed.installedId, equals('gemma'));

      final deleted = await client.deleteInstalledModel('gemma');
      expect(deleted.deletedId, equals('gemma'));

      expect(seenRequests.length, equals(8));
    });
  });
}
