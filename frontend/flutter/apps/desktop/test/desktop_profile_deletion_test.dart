import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/profiles/desktop_profile_controller.dart';
import 'package:ai_companion_desktop/features/profiles/profile_access_card.dart';
import 'package:ai_companion_desktop/features/profiles/profile_dialogs.dart';
import 'package:ai_companion_desktop/platform/desktop_client_settings.dart';
import 'package:companion_api/companion_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('DEL-16 & DEL-17: Profile Deletion, Recovery & Permanent Purge Desktop UI', () {
    late Directory tempDir;
    late DesktopClientSettings settings;
    late List<Map<String, dynamic>> serverProfiles;
    late List<Map<String, dynamic>> serverDeletedProfiles;
    late List<http.Request> recordedRequests;
    late String currentActiveToken;
    late String mintedToken;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('profile_deletion_test');
      settings = DesktopClientSettings(
        customFilePath: '${tempDir.path}\\client_settings.json',
      );
      serverProfiles = [
        {
          'id': 'profile-default',
          'name': 'Default Profile',
          'is_default': true,
          'status': 'active',
          'pin_protected': false,
          'is_deleted': false,
        },
        {
          'id': 'profile-work',
          'name': 'Work',
          'is_default': false,
          'status': 'active',
          'pin_protected': false,
          'is_deleted': false,
        },
      ];
      serverDeletedProfiles = [];
      recordedRequests = [];
      currentActiveToken = 'psk_default';
      mintedToken = 'psk_minted_1';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    CompanionClient createMockClient({CredentialStore? sessionStore, bool includeExpiry = true}) {
      final store = sessionStore ?? InMemoryCredentialStore(currentActiveToken);
      return CompanionClient(
        sessionStore: store,
        hostAdminStore: InMemoryCredentialStore('test_host_admin_secret'),
        httpClient: MockClient((request) async {
          recordedRequests.add(request);
          final path = request.url.path;

          if (path.endsWith('/health')) {
            return http.Response('{"status":"healthy"}', 200);
          }

          if (path.endsWith('/session/me')) {
            final auth = request.headers['Authorization'];
            if (auth == null || !auth.startsWith('Bearer ')) {
              return http.Response('{"detail":"Unauthorized"}', 401);
            }
            final token = auth.substring(7);
            if (token == 'psk_work') {
              return http.Response(
                jsonEncode({
                  'id': 'profile-work',
                  'name': 'Work',
                  'is_default': false,
                  'status': 'active',
                  'pin_protected': false,
                  if (includeExpiry) 'expires_at': '2099-01-01T00:00:00Z',
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'id': 'profile-default',
                'name': 'Default Profile',
                'is_default': true,
                'status': 'active',
                'pin_protected': false,
                if (includeExpiry) 'expires_at': '2099-01-01T00:00:00Z',
              }),
              200,
            );
          }

          if (path.endsWith('/ticket')) {
            return http.Response('{"ticket":"ptk_test"}', 200);
          }

          if (path.endsWith('/exchange')) {
            return http.Response(
              jsonEncode({
                'token': mintedToken,
                'profile_id': 'profile-default',
                if (includeExpiry) 'expires_at': '2099-01-01T00:00:00Z',
                'client_type': 'desktop',
              }),
              200,
            );
          }

          if (path.endsWith('/revoke')) {
            return http.Response('', 204);
          }

          if (path.endsWith('/profiles/deleted') && request.method == 'GET') {
            return http.Response(jsonEncode(serverDeletedProfiles), 200);
          }

          if (path.endsWith('/profiles') && request.method == 'GET') {
            return http.Response(jsonEncode(serverProfiles), 200);
          }

          if (path.endsWith('/requests')) {
            return http.Response('[]', 200);
          }

          if (path.endsWith('/models')) {
            return http.Response('{"active_model":"test-model"}', 200);
          }

          if (path.endsWith('/characters/active')) {
            return http.Response('{"active_instance":null,"effective_traits":{}}', 200);
          }

          if (path.endsWith('/conversations')) {
            return http.Response('{"items":[],"total":0}', 200);
          }

          // DELETE /api/v1/profiles/{id}
          final deleteMatch = RegExp(r'/api/v1/profiles/([^/]+)$').firstMatch(path);
          if (deleteMatch != null && request.method == 'DELETE') {
            final profileId = deleteMatch.group(1)!;
            final idx = serverProfiles.indexWhere((p) => p['id'] == profileId);
            if (idx == -1) {
              return http.Response('{"detail":"Profile not found."}', 404);
            }
            final removed = serverProfiles.removeAt(idx);
            final deletedEntry = {
              ...removed,
              'status': 'deleted',
              'is_deleted': true,
              'deleted_at': DateTime.now().toUtc().toIso8601String(),
              'purge_after': DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(),
            };
            serverDeletedProfiles.add(deletedEntry);
            return http.Response(jsonEncode(deletedEntry), 200);
          }

          // POST /api/v1/profiles/{id}/restore
          final restoreMatch = RegExp(r'/api/v1/profiles/([^/]+)/restore$').firstMatch(path);
          if (restoreMatch != null && request.method == 'POST') {
            final profileId = restoreMatch.group(1)!;
            final idx = serverDeletedProfiles.indexWhere((p) => p['id'] == profileId);
            if (idx == -1) {
              return http.Response('{"detail":"Profile not found or recovery window expired."}', 404);
            }
            final restored = serverDeletedProfiles.removeAt(idx);
            final restoredEntry = {
              ...restored,
              'status': 'active',
              'is_deleted': false,
              'deleted_at': null,
              'purge_after': null,
            };
            serverProfiles.add(restoredEntry);
            return http.Response(jsonEncode(restoredEntry), 200);
          }

          // POST /api/v1/profiles/{id}/purge
          final purgeMatch = RegExp(r'/api/v1/profiles/([^/]+)/purge$').firstMatch(path);
          if (purgeMatch != null && request.method == 'POST') {
            final profileId = purgeMatch.group(1)!;
            serverDeletedProfiles.removeWhere((p) => p['id'] == profileId);
            return http.Response(jsonEncode({'purged': true, 'profile_id': profileId}), 200);
          }

          return http.Response('{"detail":"Not Found"}', 404);
        }),
      );
    }

    test('DEL-16: deleteProfile moves active profile to Recently Deleted and falls back to default profile', () async {
      final store = InMemoryCredentialStore('psk_work');
      final client = createMockClient(sessionStore: store);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat, clientSettings: settings);
      addTearDown(controller.dispose);
      addTearDown(chat.dispose);

      await controller.refresh(initializeDefault: true);
      expect(controller.activeProfileId, 'profile-work');

      final deleted = await controller.deleteProfile('profile-work');
      expect(deleted, isNotNull);
      expect(deleted!.isDeleted, isTrue);
      expect(deleted.deletedAt, isNotNull);

      // Active profile disconnected and switched to default profile
      expect(controller.activeProfileId, 'profile-default');
      expect(controller.profiles.any((p) => p['id'] == 'profile-work'), isFalse);
      expect(controller.deletedProfiles.any((p) => p['id'] == 'profile-work'), isTrue);
    });

    test('DEL-17: restoreProfile restores profile and purgeProfileImmediately purges data permanently', () async {
      // Start with Work profile deleted
      serverDeletedProfiles.add({
        'id': 'profile-work',
        'name': 'Work',
        'is_default': false,
        'status': 'deleted',
        'pin_protected': false,
        'is_deleted': true,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'purge_after': DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(),
      });
      serverProfiles.removeWhere((p) => p['id'] == 'profile-work');

      final store = InMemoryCredentialStore('psk_default');
      final client = createMockClient(sessionStore: store);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat, clientSettings: settings);
      addTearDown(controller.dispose);
      addTearDown(chat.dispose);

      await controller.refresh(initializeDefault: true);
      expect(controller.deletedProfiles.length, 1);

      // 1. Test Restore
      final restored = await controller.restoreProfile('profile-work');
      expect(restored, isNotNull);
      expect(restored!.isDeleted, isFalse);
      expect(controller.profiles.any((p) => p['id'] == 'profile-work'), isTrue);
      expect(controller.deletedProfiles, isEmpty);

      // 2. Delete and then Permanent Purge
      await controller.deleteProfile('profile-work');
      expect(controller.deletedProfiles.length, 1);

      final purged = await controller.purgeProfileImmediately('profile-work');
      expect(purged, isTrue);
      expect(controller.deletedProfiles, isEmpty);
      expect(controller.profiles.any((p) => p['id'] == 'profile-work'), isFalse);
    });

    testWidgets('DEL-16: showMoveToRecentlyDeletedDialog validates typed confirmation', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = createMockClient(includeExpiry: true);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat);

      await controller.refresh(initializeDefault: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showMoveToRecentlyDeletedDialog(
                  ctx,
                  controller,
                  profileId: 'profile-work',
                  profileName: 'Work',
                ),
                child: const Text('Open Move Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Move Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Move to Recently Deleted'), findsWidgets);
      expect(
        find.textContaining('30 days before being permanently purged'),
        findsOneWidget,
      );

      final confirmBtn = find.widgetWithText(FilledButton, 'Move to Recently Deleted');
      expect(confirmBtn, findsOneWidget);
      expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNull);

      // Mismatched name
      await tester.enterText(find.byType(TextField), 'WorkProfile');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNull);

      // Exact matching name
      await tester.enterText(find.byType(TextField), 'Work');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNotNull);

      // Submit
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog dismissed and profile soft-deleted
      expect(find.text('Move to Recently Deleted'), findsNothing);
      expect(controller.deletedProfiles.any((p) => p['id'] == 'profile-work'), isTrue);

            await tester.pumpWidget(const SizedBox());
      controller.dispose();
      chat.dispose();
    });

    testWidgets('DEL-17: showPermanentDeleteProfileDialog validates typed confirmation', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      serverDeletedProfiles.add({
        'id': 'profile-work',
        'name': 'Work',
        'is_default': false,
        'status': 'deleted',
        'pin_protected': false,
        'is_deleted': true,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'purge_after': DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(),
      });
      serverProfiles.removeWhere((p) => p['id'] == 'profile-work');

      final client = createMockClient(includeExpiry: true);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat);

      await controller.refresh(initializeDefault: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showPermanentDeleteProfileDialog(
                  ctx,
                  controller,
                  profileId: 'profile-work',
                  profileName: 'Work',
                ),
                child: const Text('Open Purge Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Purge Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Permanently Delete Profile'), findsWidgets);
      expect(find.text('This action is irreversible.'), findsOneWidget);
      expect(find.textContaining('will be permanently erased'), findsOneWidget);

      final confirmPurgeBtn = find.widgetWithText(FilledButton, 'Permanently Delete');
      expect(confirmPurgeBtn, findsOneWidget);
      expect(tester.widget<FilledButton>(confirmPurgeBtn).onPressed, isNull);

      // Mismatched name
      await tester.enterText(find.byType(TextField), 'WorkProfile');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmPurgeBtn).onPressed, isNull);

      // Exact matching name
      await tester.enterText(find.byType(TextField), 'Work');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmPurgeBtn).onPressed, isNotNull);

      // Submit
      await tester.tap(confirmPurgeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog dismissed and profile permanently purged
      expect(find.text('Permanently Delete Profile'), findsNothing);
      expect(controller.deletedProfiles, isEmpty);

            await tester.pumpWidget(const SizedBox());
      controller.dispose();
      chat.dispose();
    });

    testWidgets('ProfileAccessCard renders Delete Profile button and Recently Deleted section', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      serverDeletedProfiles.add({
        'id': 'profile-old',
        'name': 'Old Projects',
        'is_default': false,
        'status': 'deleted',
        'pin_protected': false,
        'is_deleted': true,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'purge_after': DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(),
      });

      final client = createMockClient(sessionStore: InMemoryCredentialStore('psk_work'), includeExpiry: true);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat);

      await controller.refresh(initializeDefault: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileAccessCard(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      // Non-default active profile has Delete Profile button
      expect(find.text('Delete Profile'), findsOneWidget);

      // Recently Deleted section
      expect(find.text('Recently Deleted (1)'), findsOneWidget);
      expect(find.text('Old Projects'), findsOneWidget);
      expect(find.text('30 days remaining'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Permanently Delete'), findsOneWidget);

            await tester.pumpWidget(const SizedBox());
      controller.dispose();
      chat.dispose();
    });
  });
}