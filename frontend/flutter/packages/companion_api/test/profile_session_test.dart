import 'dart:convert';
import 'package:companion_api/companion_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
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
}
