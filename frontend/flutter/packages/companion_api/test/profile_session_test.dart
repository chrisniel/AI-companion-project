import 'dart:convert';
import 'package:companion_api/companion_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('own-session introspection preserves metadata and exact server expiry', () async {
    const expiry = '2099-01-01T00:37:00.123456Z';
    final metadata = {
      'id': 'p1', 'name': 'Test Profile', 'is_default': true,
      'status': 'active', 'pin_protected': false, 'expires_at': expiry,
    };
    final store = InMemoryCredentialStore('psk_session');
    final client = CompanionClient(
      sessionStore: store,
      hostAdminStore: InMemoryCredentialStore('admin'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/session/me');
        expect(request.method, 'GET');
        expect(request.followRedirects, isFalse);
        expect(request.headers['Authorization'], 'Bearer psk_session');
        expect(request.headers['X-Host-Admin-Secret'], isNull);
        return http.Response(jsonEncode(metadata), 200);
      }),
    );
    expect(await client.getOwnSession(), metadata);
    expect(await client.getOwnSession(), metadata);
    expect(await store.readToken(), 'psk_session');
    client.close();
  });
  test('native ticket exchange refuses proof forwarding through redirects', () async {
    final client = CompanionClient(hostAdminStore:InMemoryCredentialStore('admin'), httpClient:MockClient((r) async {
      if (r.url.path.endsWith('/ticket')) return http.Response('{"ticket":"ptk_proof"}',200);
      expect(r.followRedirects,isFalse);
      return http.Response('',307,headers:{'location':'https://remote.example/collect'});
    }));
    await expectLater(client.establishProfileSession('profile'),throwsA(isA<CompanionApiException>().having((e) => e.statusCode,'status',307)));
  });
  test('all Host Admin requests refuse redirects before credentials can leave loopback', () async {
    final client = CompanionClient(hostAdminStore:InMemoryCredentialStore('admin'), httpClient:MockClient((r) async {
      expect(r.followRedirects,isFalse);
      expect(r.headers['X-Host-Admin-Secret'],'admin');
      return http.Response('',302,headers:{'location':'https://remote.example/collect'});
    }));
    for (final call in <Future<dynamic> Function()>[
      client.listProfiles, client.pendingBrowserRequests, client.getSystemStatus,
      () => client.selectModel('model'), client.loadModel, client.unloadModel,
      () => client.approveBrowserRequest('request','profile'),
      () => client.establishProfileSession('profile'),
    ]) {
      await expectLater(call(),throwsA(isA<CompanionApiException>().having((e) => e.statusCode,'status',302)));
    }
  });
  test('personal calls cannot fall back to pairing token', () async {
    final client = CompanionClient(
      credentialStore: InMemoryCredentialStore('pairing'),
      httpClient: MockClient((r) async {
        expect(r.headers['Authorization'], isNull);
        expect(r.headers['X-Host-Admin-Secret'], isNull);
        return http.Response('{"items": [], "total": 0}', 200);
      }),
    );
    await client.listConversations();
  });
  test('profile, telemetry and admin method credentials stay separate',
      () async {
    final requests = <http.Request>[];
    final client = CompanionClient(
      credentialStore: InMemoryCredentialStore('pairing'),
      hostAdminStore: InMemoryCredentialStore('admin'),
      sessionStore: InMemoryCredentialStore('psk_session'),
      httpClient: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/profiles')) return http.Response('[]', 200);
        return http.Response('{"items":[], "total":0}', 200);
      }),
    );
    await client.listConversations();
    await client.listProfiles();
    expect(requests[0].headers['Authorization'], 'Bearer psk_session');
    expect(requests[0].headers['X-Host-Admin-Secret'], isNull);
    expect(requests[1].headers['Authorization'], isNull);
    expect(requests[1].headers['X-Host-Admin-Secret'], 'admin');
  });
  test('admin credentials never leave validated local loopback host', () async {
    final client = CompanionClient(
        baseUrl: 'https://remote.example',
        hostAdminStore: InMemoryCredentialStore('admin'));
    await expectLater(client.listProfiles(), throwsStateError);
  });
  test('direct session bootstrap never uses pairing authority', () async {
    final store = InMemoryCredentialStore();
    final client = CompanionClient(
      hostAdminStore: InMemoryCredentialStore('admin'),
      sessionStore: store,
      httpClient: MockClient((r) async {
        if (r.url.path.endsWith('/ticket')) {
          expect(r.headers['X-Host-Admin-Secret'], 'admin');
          expect(jsonDecode(r.body), {'profile_id': 'p1'});
          return http.Response('{"ticket":"ptk_test"}', 200);
        }
        expect(r.headers['X-Host-Admin-Secret'], isNull);
        expect(jsonDecode(r.body), {'ticket': 'ptk_test'});
        return http.Response(
            '{"token":"psk_new","profile_id":"p1","expires_at":"2099-01-01","client_type":"desktop"}',
            200);
      }),
    );
    await client.establishProfileSession('p1');
    expect(await store.readToken(), 'psk_new');
  });

  test('createProfile sends POST to /profiles with Host Admin authority', () async {
    final client = CompanionClient(
      hostAdminStore: InMemoryCredentialStore('admin_secret'),
      httpClient: MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/v1/profiles');
        expect(r.headers['X-Host-Admin-Secret'], 'admin_secret');
        expect(jsonDecode(r.body), {'name': 'Work'});
        return http.Response(
          jsonEncode({
            'id': 'p2',
            'name': 'Work',
            'is_default': false,
            'status': 'active',
            'pin_protected': false,
          }),
          201,
        );
      }),
    );
    final created = await client.createProfile(const ProfileCreateRequest(name: 'Work'));
    expect(created.id, 'p2');
    expect(created.name, 'Work');
    expect(created.isDefault, isFalse);
    expect(created.status, 'active');
    expect(created.pinProtected, isFalse);
  });

  test('renameProfile sends PATCH to /profiles/{id} with Host Admin authority', () async {
    final client = CompanionClient(
      hostAdminStore: InMemoryCredentialStore('admin_secret'),
      httpClient: MockClient((r) async {
        expect(r.method, 'PATCH');
        expect(r.url.path, '/api/v1/profiles/p1');
        expect(r.headers['X-Host-Admin-Secret'], 'admin_secret');
        expect(jsonDecode(r.body), {'name': 'Personal'});
        return http.Response(
          jsonEncode({
            'id': 'p1',
            'name': 'Personal',
            'is_default': true,
            'status': 'active',
            'pin_protected': false,
          }),
          200,
        );
      }),
    );
    final updated = await client.renameProfile('p1', const ProfileUpdateRequest(name: 'Personal'));
    expect(updated.id, 'p1');
    expect(updated.name, 'Personal');
    expect(updated.isDefault, isTrue);
  });

  test('mintAndExchangeProfileSession exchanges session without writing to store', () async {
    final store = InMemoryCredentialStore('psk_old');
    final client = CompanionClient(
      hostAdminStore: InMemoryCredentialStore('admin_secret'),
      sessionStore: store,
      httpClient: MockClient((r) async {
        if (r.url.path.endsWith('/ticket')) {
          return http.Response('{"ticket":"ptk_mint"}', 200);
        }
        return http.Response(
          '{"token":"psk_minted","profile_id":"p2","expires_at":"2099-01-01T00:00:00Z","client_type":"desktop"}',
          200,
        );
      }),
    );
    final session = await client.mintAndExchangeProfileSession('p2');
    expect(session['token'], 'psk_minted');
    expect(await store.readToken(), 'psk_old');
  });

  test('deleteProfile sends DELETE to /profiles/{id} with Host Admin authority', () async {
    final client = CompanionClient(
      hostAdminStore: InMemoryCredentialStore('admin_secret'),
      httpClient: MockClient((r) async {
        expect(r.method, 'DELETE');
        expect(r.url.path, '/api/v1/profiles/p2');
        expect(r.headers['X-Host-Admin-Secret'], 'admin_secret');
        return http.Response(
          jsonEncode({
            'id': 'p2',
            'name': 'Work',
            'is_default': false,
            'status': 'deleted',
            'pin_protected': false,
            'is_deleted': true,
            'deleted_at': '2026-11-06T10:00:00Z',
            'purge_after': '2026-12-06T10:00:00Z',
          }),
          200,
        );
      }),
    );
    final res = await client.deleteProfile('p2');
    expect(res.id, 'p2');
    expect(res.isDeleted, isTrue);
    expect(res.deletedAt, isNotNull);
  });

  test('listDeletedProfiles sends GET to /profiles/deleted with Host Admin authority', () async {
    final client = CompanionClient(
      hostAdminStore: InMemoryCredentialStore('admin_secret'),
      httpClient: MockClient((r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/api/v1/profiles/deleted');
        expect(r.headers['X-Host-Admin-Secret'], 'admin_secret');
        return http.Response(
          jsonEncode([
            {
              'id': 'p2',
              'name': 'Work',
              'is_default': false,
              'status': 'deleted',
              'pin_protected': false,
              'is_deleted': true,
              'deleted_at': '2026-11-06T10:00:00Z',
              'purge_after': '2026-12-06T10:00:00Z',
            }
          ]),
          200,
        );
      }),
    );
    final res = await client.listDeletedProfiles();
    expect(res.length, 1);
    expect(res[0]['id'], 'p2');
  });

  test('restoreProfile sends POST to /profiles/{id}/restore with Host Admin authority', () async {
    final client = CompanionClient(
      hostAdminStore: InMemoryCredentialStore('admin_secret'),
      httpClient: MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/v1/profiles/p2/restore');
        expect(r.headers['X-Host-Admin-Secret'], 'admin_secret');
        return http.Response(
          jsonEncode({
            'id': 'p2',
            'name': 'Work',
            'is_default': false,
            'status': 'active',
            'pin_protected': false,
            'is_deleted': false,
          }),
          200,
        );
      }),
    );
    final res = await client.restoreProfile('p2');
    expect(res.id, 'p2');
    expect(res.isDeleted, isFalse);
  });

  test('purgeProfile sends POST to /profiles/{id}/purge with Host Admin authority', () async {
    final client = CompanionClient(
      hostAdminStore: InMemoryCredentialStore('admin_secret'),
      httpClient: MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/v1/profiles/p2/purge');
        expect(r.headers['X-Host-Admin-Secret'], 'admin_secret');
        return http.Response(
          jsonEncode({
            'purged': true,
            'profile_id': 'p2',
          }),
          200,
        );
      }),
    );
    final res = await client.purgeProfile('p2');
    expect(res['purged'], isTrue);
  });

  test('runPurgeMaintenance sends POST to /system/maintenance/purge-profiles', () async {
    final client = CompanionClient(
      hostAdminStore: InMemoryCredentialStore('admin_secret'),
      httpClient: MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/v1/system/maintenance/purge-profiles');
        expect(r.headers['X-Host-Admin-Secret'], 'admin_secret');
        return http.Response(
          jsonEncode({
            'purged_profile_ids': ['p2'],
            'failed_profile_ids': <String>[],
          }),
          200,
        );
      }),
    );
    final res = await client.runPurgeMaintenance();
    expect(res.purgedProfileIds, ['p2']);
    expect(res.failedProfileIds, isEmpty);
  });

  test('revokeSessionToken sends POST to /auth/session/revoke with specific token', () async {
    final client = CompanionClient(
      httpClient: MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/api/v1/auth/session/revoke');
        expect(r.headers['Authorization'], 'Bearer psk_custom');
        return http.Response('', 204);
      }),
    );
    await client.revokeSessionToken('psk_custom');
  });
}
