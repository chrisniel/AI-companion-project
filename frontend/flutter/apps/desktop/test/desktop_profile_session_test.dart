import 'dart:convert';
import 'dart:async';
import 'package:companion_api/companion_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_desktop/features/profiles/desktop_profile_controller.dart';
import 'package:ai_companion_desktop/features/profiles/profile_access_card.dart';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';

void main() {
  test(
      'Profile switch revokes prior session and rejects late personal cache loads',
      () async {
    final delayed = Completer<http.Response>();
    final started = Completer<void>();
    final paths = <String>[];
    final client = CompanionClient(
        sessionStore: InMemoryCredentialStore('psk_old'),
        hostAdminStore: InMemoryCredentialStore('admin'),
        httpClient: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('/health')) {
            return http.Response('{"status":"healthy"}', 200);
          }
          if (r.url.path.endsWith('/me')) {
            return http.Response('{"id":"p1"}', 200);
          }
          if (r.url.path.endsWith('/models')) return http.Response('{}', 200);
          if (r.url.path.endsWith('/revoke')) return http.Response('', 204);
          if (r.url.path.endsWith('/ticket')) {
            return http.Response('{"ticket":"ptk_new"}', 200);
          }
          if (r.url.path.endsWith('/exchange')) {
            return http.Response('{"token":"psk_new","profile_id":"p2"}', 200);
          }
          if (r.url.path.endsWith('/conversations') &&
              r.headers['Authorization'] == 'Bearer psk_old') {
            started.complete();
            return delayed.future;
          }
          return http.Response('{"items":[],"total":0}', 200);
        }));
    final chat = DesktopChatController(client: client);
    chat.setDraft('old', 'private draft');
    final loading = chat.checkConnection();
    await started.future;
    await chat.selectProfile('p2');
    delayed.complete(http.Response(
        '{"items":[{"id":"old","title":"Old private conversation","character_id":"default","owner_id":"owner","created_at":"2026-01-01","updated_at":"2026-01-01"}],"total":1}',
        200));
    await loading;
    expect(chat.conversations, isEmpty);
    expect(chat.getDraft('old'), '');
    expect(paths.indexOf('/api/v1/auth/session/revoke'),
        lessThan(paths.indexOf('/api/v1/auth/bootstrap/ticket')));
    chat.dispose();
  });
  testWidgets(
      'shows pending origin and approves only on explicit selected Profile action',
      (tester) async {
    final requests = <http.Request>[];
    final client = CompanionClient(
        hostAdminStore: InMemoryCredentialStore('admin'),
        httpClient: MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/profiles')) {
            return http.Response(
                '[{"id":"p1","name":"Chris","is_default":true,"status":"active","pin_protected":false}]',
                200);
          }
          if (r.url.path.endsWith('/requests')) {
            return http.Response(
                '[{"request_id":"request-1","origin":"http://localhost:5173","expires_at":"2099-01-01"}]',
                200);
          }
          if (r.url.path.endsWith('/ticket')) {
            return http.Response(jsonEncode({'ticket': 'ptk_x'}), 200);
          }
          if (r.url.path.endsWith('/exchange')) {
            return http.Response('{"token":"psk_x","profile_id":"p1"}', 200);
          }
          return http.Response('{}', 200);
        }));
    final chat = DesktopChatController(client: client);
    final controller = DesktopProfileController(chat: chat);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProfileAccessCard(controller: controller))));
    expect(find.textContaining('http://localhost:5173'), findsOneWidget);
    expect(requests.where((r) => r.url.path.endsWith('/ticket')), isEmpty);
    await tester.tap(find.text('Use Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve request'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.url.path.endsWith('/ticket')).length, 2);
    expect(
        jsonDecode(
            requests.lastWhere((r) => r.url.path.endsWith('/ticket')).body),
        {'profile_id': 'p1', 'request_id': 'request-1'});
    await chat.invalidateProfileSession();
    expect(controller.activeProfileId,isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    chat.dispose();
  });
}
