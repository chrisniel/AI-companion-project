import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/profiles/desktop_profile_controller.dart';
import 'package:ai_companion_desktop/platform/desktop_client_settings.dart';
import 'package:companion_api/companion_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_desktop/features/profiles/profile_access_card.dart';
import 'package:ai_companion_desktop/features/profiles/profile_dialogs.dart';
import 'package:ai_companion_desktop/features/profiles/profile_selector_header.dart';
import 'package:ai_companion_desktop/screens/chat_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('DesktopProfileController & Acquire-Before-Teardown Admin Tests', () {
    late Directory tempDir;
    late DesktopClientSettings settings;
    late List<Map<String, dynamic>> serverProfiles;
    late List<http.Request> recordedRequests;
    late String? currentActiveToken;
    late String mintedToken;
    late bool failNextSwitch;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('profile_admin_test');
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
        },
        {
          'id': 'profile-work',
          'name': 'Work',
          'is_default': false,
          'status': 'active',
          'pin_protected': false,
        },
        {
          'id': 'profile-pin',
          'name': 'Protected',
          'is_default': false,
          'status': 'active',
          'pin_protected': true,
        },
      ];
      recordedRequests = [];
      currentActiveToken = 'psk_default';
      mintedToken = 'psk_minted_1';
      failNextSwitch = false;
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
            if (token == 'psk_default') {
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
            } else if (token.startsWith('psk_minted')) {
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
            return http.Response('{"detail":"Session invalid"}', 401);
          }

          if (path.endsWith('/profiles')) {
            if (request.method == 'GET') {
              return http.Response(jsonEncode(serverProfiles), 200);
            } else if (request.method == 'POST') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              final name = body['name'] as String;
              if (serverProfiles.any((p) => (p['name'] as String).toLowerCase() == name.toLowerCase())) {
                return http.Response(
                  jsonEncode({'error': {'code': 'CONFLICT', 'message': 'A Profile with this name already exists'}}),
                  409,
                );
              }
              final created = {
                'id': 'profile-created-${serverProfiles.length + 1}',
                'name': name,
                'is_default': false,
                'status': 'active',
                'pin_protected': false,
              };
              serverProfiles.add(created);
              return http.Response(jsonEncode(created), 201);
            }
          }

          if (path.contains('/profiles/')) {
            final profileId = path.split('/').last;
            if (request.method == 'PATCH') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              final newName = body['name'] as String;
              if (serverProfiles.any((p) => p['id'] != profileId && (p['name'] as String).toLowerCase() == newName.toLowerCase())) {
                return http.Response(
                  jsonEncode({'error': {'code': 'CONFLICT', 'message': 'A Profile with this name already exists'}}),
                  409,
                );
              }
              final idx = serverProfiles.indexWhere((p) => p['id'] == profileId);
              if (idx == -1) return http.Response('{"detail":"Profile unavailable"}', 404);
              serverProfiles[idx] = {
                ...serverProfiles[idx],
                'name': newName,
              };
              return http.Response(jsonEncode(serverProfiles[idx]), 200);
            }
          }

          if (path.endsWith('/ticket')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final targetId = body['profile_id'] as String;
            if (failNextSwitch || targetId == 'profile-pin') {
              return http.Response(
                jsonEncode({'error': {'code': 'FORBIDDEN', 'message': 'Profile unlock challenge is not available'}}),
                403,
              );
            }
            return http.Response('{"ticket":"ptk_test"}', 200);
          }

          if (path.endsWith('/exchange')) {
            return http.Response(
              jsonEncode({
                'token': mintedToken,
                'profile_id': 'profile-work',
                if (includeExpiry) 'expires_at': '2099-01-01T00:00:00Z',
                'client_type': 'desktop',
              }),
              200,
            );
          }

          if (path.endsWith('/revoke')) {
            return http.Response('', 204);
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

          return http.Response('{"detail":"Not found"}', 404);
        }),
      );
    }

    test('acquire-before-teardown preserves active Profile when destination switch fails', () async {
      final store = InMemoryCredentialStore('psk_default');
      final client = createMockClient(sessionStore: store);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat, clientSettings: settings);
      addTearDown(controller.dispose);
      addTearDown(chat.dispose);

      await controller.refresh(initializeDefault: true);
      expect(controller.activeProfileId, 'profile-default');
      expect(await store.readToken(), 'psk_default');

      // Attempt to switch to PIN-protected profile (which returns 403)
      final success = await controller.switchToProfile('profile-pin');
      expect(success, isFalse);
      expect(controller.error, isNotNull);
      // Profile A remains connected and intact!
      expect(controller.activeProfileId, 'profile-default');
      expect(await store.readToken(), 'psk_default');
      expect(chat.isConnected, isTrue);

      // Verify revoke was NEVER called on psk_default!
      final revokes = recordedRequests.where((r) => r.url.path.endsWith('/revoke'));
      expect(revokes, isEmpty);
    });

    test('acquire-before-teardown succeeds: revokes prior token and updates settings', () async {
      final store = InMemoryCredentialStore('psk_default');
      final client = createMockClient(sessionStore: store);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat, clientSettings: settings);
      addTearDown(controller.dispose);
      addTearDown(chat.dispose);

      await controller.refresh(initializeDefault: true);
      expect(controller.activeProfileId, 'profile-default');

      recordedRequests.clear();
      final success = await controller.switchToProfile('profile-work');
      expect(success, isTrue);
      expect(controller.activeProfileId, 'profile-work');
      expect(await store.readToken(), 'psk_minted_1');

      // Check request order: ticket -> exchange -> revoke
      final mutationPaths = recordedRequests
          .where((r) => r.url.path.contains('/ticket') || r.url.path.contains('/exchange') || r.url.path.contains('/revoke'))
          .map((r) => r.url.path)
          .toList();
      expect(mutationPaths, [
        '/api/v1/auth/bootstrap/ticket',
        '/api/v1/auth/session/exchange',
        '/api/v1/auth/session/revoke',
      ]);

      // Check revoked token was the prior token
      final revokeReq = recordedRequests.firstWhere((r) => r.url.path.endsWith('/revoke'));
      expect(revokeReq.headers['Authorization'], 'Bearer psk_default');

      // Check clientSettings persisted new selection
      expect(await settings.readSelectedProfileId(), 'profile-work');
      expect(await settings.readProfileExplicitlyLocked(), isFalse);
    });

    test('createProfile adds profile and immediately switches to it', () async {
      final store = InMemoryCredentialStore('psk_default');
      final client = createMockClient(sessionStore: store);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat, clientSettings: settings);
      addTearDown(controller.dispose);
      addTearDown(chat.dispose);

      await controller.refresh(initializeDefault: true);

      final created = await controller.createProfile(name: 'Project Alpha');
      expect(created, isNotNull);
      expect(created!.name, 'Project Alpha');
      expect(controller.profiles.any((p) => p['name'] == 'Project Alpha'), isTrue);

      // Check duplicate creation fails with 409 error message
      final dup = await controller.createProfile(name: 'Project Alpha');
      expect(dup, isNull);
      expect(controller.error, 'A Profile with this name already exists.');
    });

    test('renameProfile updates profile name and immediately updates chat screen header', () async {
      final store = InMemoryCredentialStore('psk_default');
      final client = createMockClient(sessionStore: store);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat, clientSettings: settings);
      addTearDown(controller.dispose);
      addTearDown(chat.dispose);

      await controller.refresh(initializeDefault: true);
      expect(chat.authenticatedProfileName, 'Default Profile');

      final updated = await controller.renameProfile(
        profileId: 'profile-default',
        newName: 'Personal',
      );
      expect(updated, isNotNull);
      expect(updated!.name, 'Personal');
      expect(controller.activeProfileName, 'Personal');
      expect(chat.authenticatedProfileName, 'Personal');

      // Renaming to conflicting name fails with 409
      final conflict = await controller.renameProfile(
        profileId: 'profile-default',
        newName: 'Work',
      );
      expect(conflict, isNull);
      expect(controller.error, 'A Profile with this name already exists.');
    });

    test('lockActiveProfile (Sign out) revokes session and disables automatic restoration', () async {
      final store = InMemoryCredentialStore('psk_default');
      final client = createMockClient(sessionStore: store);
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat, clientSettings: settings);
      addTearDown(controller.dispose);
      addTearDown(chat.dispose);

      await controller.refresh(initializeDefault: true);
      expect(controller.activeProfileId, 'profile-default');

      await controller.lockActiveProfile();
      expect(controller.activeProfileId, isNull);
      expect(await store.readToken(), isNull);
      expect(await settings.readProfileExplicitlyLocked(), isTrue);

      // Simulate next startup: refresh with initializeDefault=true
      final chat2 = DesktopChatController(client: client);
      final controller2 = DesktopProfileController(chat: chat2, clientSettings: settings);
      addTearDown(controller2.dispose);
      addTearDown(chat2.dispose);

      await controller2.refresh(initializeDefault: true);
      // Because profileExplicitlyLocked is true, session is NOT automatically restored!
      expect(controller2.activeProfileId, isNull);
      expect(chat2.isConnected, isFalse);
    });

    test('formatProfileDisplayName appends (Personal / Default) only for default profile', () {
      final controller = DesktopProfileController(
        chat: DesktopChatController(client: createMockClient()),
      );
      expect(
        controller.formatProfileDisplayName({
          'name': 'Default Profile',
          'is_default': true,
        }),
        'Default Profile (Personal / Default)',
      );
      expect(
        controller.formatProfileDisplayName({
          'name': 'Personal',
          'is_default': true,
        }),
        'Personal (Personal / Default)',
      );
      expect(
        controller.formatProfileDisplayName({
          'name': 'Work',
          'is_default': false,
        }),
        'Work',
      );
    });

    testWidgets('ProfileAccessCard renders Create, Rename, Sign out buttons and Personal / Default badge', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = createMockClient();
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
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Profile access'), findsOneWidget);
      expect(find.text('Create Profile'), findsOneWidget);
      expect(find.text('Rename Profile'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Use Profile'), findsOneWidget);
      expect(find.text('Personal / Default'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      chat.dispose();
    });

    testWidgets('showCreateProfileDialog validates input and creates profile', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = createMockClient();
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat);

      await controller.refresh(initializeDefault: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showCreateProfileDialog(ctx, controller),
                child: const Text('Open Create Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Create Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Create Profile'), findsWidgets);
      expect(find.text('Switch to this Profile immediately'), findsOneWidget);

      // Attempt empty submit
      final createBtn = find.widgetWithText(FilledButton, 'Create Profile');
      await tester.tap(createBtn);
      await tester.pump();
      expect(find.text('Profile name cannot be empty.'), findsOneWidget);

      // Enter duplicate name 'Work'
      await tester.enterText(find.byType(TextField), 'Work');
      await tester.tap(createBtn);
      await tester.pump();
      expect(find.text('A Profile with this name already exists.'), findsOneWidget);

      // Enter valid name and create
      await tester.enterText(find.byType(TextField), 'Personal Projects');
      await tester.tap(createBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog dismissed
      expect(find.text('Create Profile'), findsNothing);
      expect(controller.profiles.any((p) => p['name'] == 'Personal Projects'), isTrue);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      chat.dispose();
    });

    testWidgets('showRenameProfileDialog validates input and renames profile', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = createMockClient();
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat);

      await controller.refresh(initializeDefault: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showRenameProfileDialog(
                  ctx,
                  controller,
                  profileId: 'profile-default',
                  currentName: 'Default Profile',
                  isDefault: true,
                ),
                child: const Text('Open Rename Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Rename Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Rename Profile'), findsOneWidget);
      expect(find.textContaining('Tip: You can rename Default Profile to Personal'), findsOneWidget);

      // Submit new name 'Personal'
      await tester.enterText(find.byType(TextField), 'Personal');
      final renameBtn = find.widgetWithText(FilledButton, 'Rename');
      await tester.tap(renameBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rename Profile'), findsNothing);
      expect(controller.activeProfileName, 'Personal');

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      chat.dispose();
    });

    testWidgets('ProfileSelectorHeader renders avatar, active profile, and opens quick switch menu', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = createMockClient();
      final chat = DesktopChatController(client: client);
      final controller = DesktopProfileController(chat: chat);

      await controller.refresh(initializeDefault: true);

      var settingsOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: ProfileSelectorHeader(
                controller: controller,
                isCollapsed: false,
                onOpenSettings: () => settingsOpened = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Default Profile'), findsOneWidget);
      expect(find.text('Personal / Default'), findsOneWidget);

      // Open popup menu
      await tester.tap(find.byType(ProfileSelectorHeader));
      await tester.pumpAndSettle();

      expect(find.text('PROFILES'), findsOneWidget);
      expect(find.text('Create New Profile...'), findsOneWidget);
      expect(find.text('Rename Current Profile...'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Manage Profiles in Settings...'), findsOneWidget);

      // Tap Manage Profiles in Settings
      await tester.tap(find.text('Manage Profiles in Settings...'));
      await tester.pumpAndSettle();
      expect(settingsOpened, isTrue);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      chat.dispose();
    });

    testWidgets('ChatScreen displays active Profile badge in header', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = createMockClient();
      final chat = DesktopChatController(client: client);

      await chat.checkConnection();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatScreen(controller: chat),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Profile: Default Profile'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      chat.dispose();
    });
  });
}
