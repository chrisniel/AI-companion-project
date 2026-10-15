import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/profiles/desktop_profile_controller.dart';
import 'package:ai_companion_desktop/platform/windows_dpapi_credential_store.dart';
import 'package:companion_api/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _profile(String id) => {
      'id': id,
      'name': id == 'default' ? 'Default Profile' : 'Profile B',
      'is_default': id == 'default',
      'status': 'active',
      'pin_protected': false,
    };

class _Runtime {
  _Runtime({this.savedProfile = 'profile-b'});
  final String savedProfile;
  final requests = <http.Request>[];
  String? rejectedSession;
  String mintedProfile = 'default';
  bool adminAvailable = true;

  CompanionClient client(CredentialStore store,
          {String baseUrl = 'http://127.0.0.1:8000'}) =>
      CompanionClient(
        baseUrl: baseUrl,
        sessionStore: store,
        hostAdminStore: InMemoryCredentialStore('synthetic-host-admin'),
        httpClient: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          final isSaved =
              request.headers['Authorization'] == 'Bearer psk_saved';
          final profile = isSaved ? savedProfile : mintedProfile;
          if (path.endsWith('/health')) {
            return http.Response('{"status":"healthy"}', 200);
          }
          if (path.endsWith('/session/me')) {
            if (isSaved && rejectedSession != null) {
              return http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'AUTHENTICATION_REQUIRED',
                      'message': rejectedSession,
                    }
                  }),
                  401);
            }
            return http.Response(jsonEncode({
              ..._profile(profile),
              'expires_at': '2099-01-01T00:00:00Z',
            }), 200);
          }
          if (path.endsWith('/profiles')) {
            return adminAvailable
                ? http.Response(
                    jsonEncode([_profile('default'), _profile('profile-b')]),
                    200)
                : http.Response('{}', 503);
          }
          if (path.endsWith('/requests')) return http.Response('[]', 200);
          if (path.endsWith('/ticket')) {
            mintedProfile = jsonDecode(request.body)['profile_id'] as String;
            return http.Response('{"ticket":"ptk_synthetic"}', 200);
          }
          if (path.endsWith('/exchange')) {
            return http.Response(
                jsonEncode({
                  'token': 'psk_new',
                  'profile_id': mintedProfile,
                  'expires_at': '2099-01-01T00:00:00Z',
                  'client_type': 'desktop',
                }),
                200);
          }
          if (path.endsWith('/revoke')) return http.Response('', 204);
          if (path.endsWith('/models')) return http.Response('{}', 200);
          if (path.endsWith('/conversations')) {
            return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': '$profile-conversation',
                      'title': '$profile private conversation',
                      'character_id': 'default',
                      'owner_id': 'local_user',
                      'created_at': '2026-01-01T00:00:00Z',
                      'updated_at': '2026-01-01T00:00:00Z',
                      'message_count': 0,
                    }
                  ],
                  'total': 1
                }),
                200);
          }
          return http.Response('{"items":[],"total":0}', 200);
        }),
      );

  Iterable<http.Request> get sessionMutations => requests.where((request) =>
      request.url.path.endsWith('/ticket') ||
      request.url.path.endsWith('/exchange') ||
      request.url.path.endsWith('/revoke'));
}

void main() {
  test(
      'valid Profile B session survives restart using disposable DPAPI storage',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('companion-profile-restart-');
    addTearDown(() => directory.delete(recursive: true));
    WindowsDpapiCredentialStore newStore() => WindowsDpapiCredentialStore(
        localAppDataOverride: directory.path,
        slot: DesktopCredentialSlot.profileSession);
    await newStore().writeToken('psk_saved');
    final runtime = _Runtime();
    final beforeRestart =
        DesktopChatController(client: runtime.client(newStore()));
    await beforeRestart.checkConnection();
    expect(beforeRestart.conversations.single.id, 'profile-b-conversation');
    beforeRestart.dispose();
    runtime.requests.clear();

    final chat = DesktopChatController(client: runtime.client(newStore()));
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    expect(profiles.activeProfileId, 'profile-b');
    expect(profiles.selectedProfileId, 'profile-b');
    expect(chat.conversations.single.id, 'profile-b-conversation');
    expect(await newStore().readToken(), 'psk_saved');
    expect(runtime.sessionMutations, isEmpty);
    expect(
        runtime.requests.where((r) => r.url.path.endsWith('/session/me')),
        everyElement(predicate<http.Request>(
            (r) => r.headers['Authorization'] == 'Bearer psk_saved')));
  });

  test('valid Default session restores without issuing or revoking a session',
      () async {
    final store = InMemoryCredentialStore('psk_saved');
    final runtime = _Runtime(savedProfile: 'default');
    final chat = DesktopChatController(client: runtime.client(store));
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    expect(profiles.activeProfileId, 'default');
    expect(profiles.selectedProfileId, 'default');
    expect(await store.readToken(), 'psk_saved');
    expect(runtime.sessionMutations, isEmpty);
  });

  for (final failure in ['expired', 'revoked', 'inactive', 'another runtime']) {
    test(
        '$failure saved session fails closed without Default fallback on repeated startup',
        () async {
      final store = InMemoryCredentialStore('psk_saved');
      final runtime = _Runtime();
      final chat = DesktopChatController(client: runtime.client(store));
      final profiles = DesktopProfileController(chat: chat);
      await chat.checkConnection();
      chat.setDraft('profile-b-conversation', 'private draft');
      runtime.requests.clear();
      runtime.rejectedSession = failure;
      await profiles.refresh(initializeDefault: true);
      expect(profiles.activeProfileId, isNull);
      expect(profiles.selectedProfileId, isNull);
      expect(chat.canSend, isFalse);
      expect(chat.conversations, isEmpty);
      expect(chat.messages, isEmpty);
      expect(chat.getDraft('profile-b-conversation'), isEmpty);
      expect(
          runtime.requests.where((r) => r.url.path.contains('/conversations')),
          isEmpty);
      expect(runtime.sessionMutations, isEmpty);
      // Preserve the rejected saved credential until explicit authorization so
      // another process restart cannot turn rejection into first-run bootstrap.
      expect(await store.readToken(), 'psk_saved');
      profiles.dispose();
      chat.dispose();
      final restartedChat =
          DesktopChatController(client: runtime.client(store));
      final restartedProfiles = DesktopProfileController(chat: restartedChat);
      addTearDown(restartedProfiles.dispose);
      addTearDown(restartedChat.dispose);
      await restartedProfiles.refresh(initializeDefault: true);
      expect(restartedProfiles.activeProfileId, isNull);
      expect(restartedChat.canSend, isFalse);
      expect(runtime.sessionMutations, isEmpty);
    });
  }

  test('first run initializes Default only with Host Admin authorization',
      () async {
    final store = InMemoryCredentialStore();
    final runtime = _Runtime();
    final chat = DesktopChatController(client: runtime.client(store));
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    expect(profiles.activeProfileId, 'default');
    expect(profiles.selectedProfileId, 'default');
    expect(await store.readToken(), 'psk_new');
    final ticket =
        runtime.requests.singleWhere((r) => r.url.path.endsWith('/ticket'));
    expect(ticket.headers['X-Host-Admin-Secret'], 'synthetic-host-admin');
    expect(jsonDecode(ticket.body), {'profile_id': 'default'});
    expect(
        runtime.requests.where((r) => r.url.path.endsWith('/revoke')), isEmpty);
  });

  test(
      'saved Profile restoration does not depend on Host Admin catalog availability',
      () async {
    final runtime = _Runtime()..adminAvailable = false;
    final chat = DesktopChatController(
        client: runtime.client(InMemoryCredentialStore('psk_saved')));
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    expect(profiles.activeProfileId, 'profile-b');
    expect(profiles.selectedProfileId, 'profile-b');
    expect(chat.conversations.single.id, 'profile-b-conversation');
    expect(runtime.sessionMutations, isEmpty);
  });

  test(
      'runtime-ready hook revalidates a previously restored session before retaining private caches',
      () async {
    final runtime = _Runtime();
    final chat = DesktopChatController(
        client: runtime.client(InMemoryCredentialStore('psk_saved')));
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    chat.setDraft('profile-b-conversation', 'private draft');
    runtime.requests.clear();
    runtime.rejectedSession =
        'runtime restarted and rejected the saved session';
    await profiles.refresh(initializeDefault: true);
    expect(profiles.activeProfileId, isNull);
    expect(chat.canSend, isFalse);
    expect(chat.conversations, isEmpty);
    expect(chat.getDraft('profile-b-conversation'), isEmpty);
    expect(runtime.sessionMutations, isEmpty);
  });

  test('first run cannot bootstrap a non-default selection without Use Profile',
      () async {
    final store = InMemoryCredentialStore();
    final runtime = _Runtime();
    final chat = DesktopChatController(client: runtime.client(store));
    final profiles = DesktopProfileController(chat: chat)..select('profile-b');
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    expect(profiles.activeProfileId, isNull);
    expect(await store.readToken(), isNull);
    expect(runtime.sessionMutations, isEmpty);
  });

  test('first run cannot bootstrap without Host Admin authority', () async {
    final runtime = _Runtime()..adminAvailable = false;
    final chat = DesktopChatController(
        client: runtime.client(InMemoryCredentialStore()));
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    expect(profiles.activeProfileId, isNull);
    expect(chat.canSend, isFalse);
    expect(runtime.sessionMutations, isEmpty);
  });

  test(
      'explicit switch after restoration revokes Profile B and clears its private caches',
      () async {
    final runtime = _Runtime();
    final chat = DesktopChatController(
        client: runtime.client(InMemoryCredentialStore('psk_saved')));
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    chat.setDraft('profile-b-conversation', 'private draft');
    runtime.requests.clear();
    profiles.select('default');
    await profiles.useSelected();
    expect(profiles.activeProfileId, 'default');
    expect(profiles.selectedProfileId, 'default');
    expect(chat.conversations.single.id, 'default-conversation');
    expect(chat.getDraft('profile-b-conversation'), isEmpty);
    final mutations = runtime.sessionMutations.toList();
    expect(mutations.map((r) => r.url.path), [
      '/api/v1/auth/session/revoke',
      '/api/v1/auth/bootstrap/ticket',
      '/api/v1/auth/session/exchange',
    ]);
    expect(mutations.first.headers['Authorization'], 'Bearer psk_saved');
  });

  for (final rejected in [false, true]) {
    test(
        'saved startup runtime URL ${rejected ? 'rejects foreign authority' : 'restores Profile B'} without revocation',
        () async {
      final store = InMemoryCredentialStore('psk_saved');
      final runtime = _Runtime();
      if (rejected) {
        runtime.rejectedSession = 'session belongs to another runtime';
      }
      final chat = DesktopChatController(
          client: runtime.client(store),
          clientFactory: ({required baseUrl, credentialStore}) =>
              runtime.client(store, baseUrl: baseUrl));
      final profiles = DesktopProfileController(chat: chat);
      addTearDown(profiles.dispose);
      addTearDown(chat.dispose);
      await chat.updateConfiguration(
          baseUrl: 'http://127.0.0.1:8001', restoreSavedSession: true);
      expect(runtime.requests, isEmpty);
      expect(await store.readToken(), 'psk_saved');
      await profiles.refresh(initializeDefault: true);
      expect(profiles.activeProfileId, rejected ? isNull : 'profile-b');
      expect(profiles.selectedProfileId, rejected ? isNull : 'profile-b');
      expect(chat.canSend, !rejected);
      expect(runtime.sessionMutations, isEmpty);
      expect(
          runtime.requests
              .where((r) => r.url.path.endsWith('/session/me'))
              .single
              .url
              .port,
          8001);
    });
  }

  test('startup remote URL never receives the local DPAPI-scoped session',
      () async {
    final saved = InMemoryCredentialStore('psk_saved');
    final chat =
        DesktopChatController(client: CompanionClient(sessionStore: saved));
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await chat.updateConfiguration(
        baseUrl: 'https://remote.invalid', restoreSavedSession: true);
    await profiles.refresh(initializeDefault: true);
    expect(chat.client.baseUri.host, 'remote.invalid');
    expect(await chat.client.sessionStore.readToken(), isNull);
    expect(await saved.readToken(), 'psk_saved');
    expect(profiles.activeProfileId, isNull);
    expect(chat.canSend, isFalse);
  });
}
