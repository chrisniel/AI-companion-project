import 'dart:async';

import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/profiles/desktop_profile_controller.dart';
import 'package:companion_api/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _SessionClient extends CompanionClient {
  _SessionClient() : super(sessionStore: InMemoryCredentialStore('psk_saved'));

  String profileId = 'profile-b';
  String? expiry =
      DateTime.now().toUtc().add(const Duration(minutes: 1)).toIso8601String();
  int grants = 0;
  int revocations = 0;
  int privateLoads = 0;
  bool failLoad = false;
  bool streamCancelled = false;
  late final stream =
      StreamController<SseEvent>(onCancel: () => streamCancelled = true);
  Completer<ConversationListOut>? delayedLoad;
  Completer<void>? loadStarted;

  @override
  Future<HealthResponse> getHealth(
          {Duration timeout = const Duration(seconds: 3)}) async =>
      const HealthResponse(status: 'healthy');

  @override
  Future<Map<String, dynamic>> getOwnSession() async => {
        'id': profileId,
        'name': profileId,
        'is_default': profileId == 'default',
        'status': 'active',
        'pin_protected': false,
        if (expiry != null) 'expires_at': expiry,
      };

  @override
  Future<ModelStatusResponse> getModelStatus() async =>
      const ModelStatusResponse(
          provider: 'synthetic',
          runtimeState: 'MODEL_READY',
          modelLoaded: true);

  ConversationOut get conversation => ConversationOut(
        id: '$profileId-conversation',
        title: '$profileId private history',
        characterId: 'default',
        ownerId: 'local_user',
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z',
        messageCount: 1,
      );

  @override
  Future<ConversationListOut> listConversations(
      {int skip = 0, int limit = 50}) async {
    privateLoads++;
    if (failLoad) {
      throw const CompanionApiException(
          statusCode: 500, message: 'private history failure');
    }
    if (delayedLoad != null) {
      loadStarted!.complete();
      return delayedLoad!.future;
    }
    return ConversationListOut(items: [conversation], total: 1);
  }

  @override
  Future<MessageListOut> listMessages(String conversationId,
          {int skip = 0, int limit = 100}) async =>
      MessageListOut(items: [
        MessageOut(
          id: 'private-message',
          conversationId: conversationId,
          sender: 'user',
          content: 'private message',
          status: 'completed',
          sequenceNo: 1,
          createdAt: '2026-01-01T00:00:00Z',
        )
      ], total: 1);

  @override
  Future<List<Map<String, dynamic>>> listProfiles() async => [
        for (final id in ['default', 'profile-b'])
          {
            'id': id,
            'name': id,
            'is_default': id == 'default',
            'status': 'active',
            'pin_protected': false,
          }
      ];

  @override
  Future<List<Map<String, dynamic>>> pendingBrowserRequests() async => [];

  @override
  Future<void> revokeProfileSession() async {
    revocations++;
    await sessionStore.deleteToken();
  }

  @override
  Future<Map<String, dynamic>> establishProfileSession(String id) async {
    grants++;
    profileId = id;
    await sessionStore.writeToken('psk_new');
    return {'profile_id': id, 'expires_at': expiry};
  }

  @override
  Stream<SseEvent> sendMessageStream(String conversationId, MessageSend payload,
      {http.Client? customClient, void Function()? onAccepted}) {
    onAccepted?.call();
    return stream.stream;
  }

  @override
  void close() {
    unawaited(stream.close());
    super.close();
  }
}

void main() {
  testWidgets(
      'restored expiry clears authority, private caches and subscriptions',
      (tester) async {
    final client = _SessionClient();
    final chat = DesktopChatController(client: client);
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(() {
      profiles.dispose();
      chat.dispose();
      client.close();
    });
    await profiles.refresh(initializeDefault: true);
    expect(profiles.activeProfileId, 'profile-b');
    await chat.selectConversation(client.conversation);
    chat.setDraft(client.conversation.id, 'private draft');
    chat.setScrollOffset(client.conversation.id, 123);
    final sending = chat.sendMessage('private request');
    await tester.pump();
    client.stream.add(const SseTokenEvent('private response'));
    await tester.pump();
    expect(chat.messages, isNotEmpty);
    expect(chat.streamingText, 'private response');
    final epoch = chat.profileEpoch;
    await tester.pump(const Duration(minutes: 2));
    expect(chat.isConnected, isFalse);
    expect(chat.canSend, isFalse);
    expect(chat.authenticatedProfileId, isNull);
    expect(profiles.activeProfileId, isNull);
    expect(chat.profileEpoch, greaterThan(epoch));
    expect(chat.conversations, isEmpty);
    expect(chat.activeConversation, isNull);
    expect(chat.messages, isEmpty);
    expect(chat.streamingText, isEmpty);
    expect(chat.getDraft(client.conversation.id), isEmpty);
    expect(chat.getScrollOffset(client.conversation.id), isNull);
    expect(client.streamCancelled, isTrue);
    expect(await sending, isTrue);
    // Keep the expired credential inert so restart cannot become first run.
    expect(await client.sessionStore.readToken(), 'psk_saved');
    expect(client.grants, 0);
    expect(client.revocations, 0);
    client.stream.add(const SseTokenEvent('late private response'));
    await tester.pump();
    expect(chat.messages, isEmpty);
    unawaited(client.stream.close());
  });

  for (final expiry in [
    null,
    'invalid',
    '2000-01-01T00:00:00Z',
    '2099-01-01T00:00:00'
  ]) {
    testWidgets('restoration fails closed for expiry $expiry', (tester) async {
      final client = _SessionClient()..expiry = expiry;
      final chat = DesktopChatController(client: client);
      final profiles = DesktopProfileController(chat: chat);
      addTearDown(profiles.dispose);
      addTearDown(chat.dispose);
      await profiles.refresh(initializeDefault: true);
      expect(chat.isConnected, isFalse);
      expect(profiles.activeProfileId, isNull);
      expect(client.privateLoads, 0);
      expect(client.grants, 0);
      expect(await client.sessionStore.readToken(), 'psk_saved');
    });
  }

  testWidgets('revalidation preserves the absolute server expiry',
      (tester) async {
    final deadline =
        tester.binding.clock.now().toUtc().add(const Duration(minutes: 1));
    final client = _SessionClient()..expiry = deadline.toIso8601String();
    final chat =
        DesktopChatController(client: client, now: tester.binding.clock.now);
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    await tester.pump(const Duration(seconds: 30));
    await profiles.refresh(initializeDefault: true);
    expect(profiles.activeProfileId, 'profile-b');
    await tester.pump(const Duration(seconds: 29));
    expect(chat.isConnected, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(chat.isConnected, isFalse);
    expect(profiles.activeProfileId, isNull);
    expect(client.expiry, deadline.toIso8601String());
    expect(client.grants, 0);
    expect(client.revocations, 0);
  });

  testWidgets(
      'explicit switch replaces the old timer with the new server expiry',
      (tester) async {
    final start = tester.binding.clock.now().toUtc();
    final client = _SessionClient()
      ..expiry = start.add(const Duration(seconds: 30)).toIso8601String();
    final chat =
        DesktopChatController(client: client, now: tester.binding.clock.now);
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    chat.setDraft(client.conversation.id, 'Profile B draft');
    client.expiry = start.add(const Duration(minutes: 2)).toIso8601String();
    profiles.select('default');
    await profiles.useSelected();
    expect(chat.getDraft('profile-b-conversation'), isEmpty);
    expect(profiles.activeProfileId, 'default');
    expect(client.revocations, 1);
    expect(client.grants, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(chat.isConnected, isTrue);
    expect(chat.conversations.single.id, 'default-conversation');
    await tester.pump(const Duration(seconds: 90));
    expect(chat.isConnected, isFalse);
    expect(chat.conversations, isEmpty);
    expect(profiles.activeProfileId, isNull);
    expect(await client.sessionStore.readToken(), 'psk_new');
  });

  testWidgets('late personal cache loads cannot repopulate after expiry',
      (tester) async {
    final client = _SessionClient()
      ..expiry = tester.binding.clock
          .now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
    final chat =
        DesktopChatController(client: client, now: tester.binding.clock.now);
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(profiles.dispose);
    addTearDown(chat.dispose);
    await profiles.refresh(initializeDefault: true);
    final oldConversation = client.conversation;
    client.delayedLoad = Completer<ConversationListOut>();
    client.loadStarted = Completer<void>();
    final loading = chat.loadConversations();
    await client.loadStarted!.future;
    await tester.pump(const Duration(minutes: 1));
    expect(chat.isConnected, isFalse);
    client.delayedLoad!
        .complete(ConversationListOut(items: [oldConversation], total: 1));
    await loading;
    expect(chat.conversations, isEmpty);
    expect(chat.messages, isEmpty);
    expect(profiles.activeProfileId, isNull);
  });

  for (final terminal in [
    const SseDoneEvent(),
    const SseErrorEvent(code: 'PRIVATE', message: 'private stream failure')
  ]) {
    testWidgets(
        'expiry clears errors and closes a stream left open after $terminal',
        (tester) async {
      final client = _SessionClient()
        ..expiry = tester.binding.clock
            .now()
            .toUtc()
            .add(const Duration(minutes: 1))
            .toIso8601String();
      final chat =
          DesktopChatController(client: client, now: tester.binding.clock.now);
      final profiles = DesktopProfileController(chat: chat);
      addTearDown(() {
        profiles.dispose();
        chat.dispose();
        client.close();
      });
      await profiles.refresh(initializeDefault: true);
      final sending = chat.sendMessage('private request');
      await tester.pump();
      client.stream.add(terminal);
      await tester.pump();
      expect(await sending, isTrue);
      // Typed completion precedes transport EOF; leave normal cleanup to it.
      expect(client.streamCancelled, isFalse);
      client.failLoad = true;
      await chat.loadConversations();
      expect(chat.conversationError, contains('private history failure'));
      await tester.pump(const Duration(minutes: 1));
      expect(chat.errorMessage, isNull);
      expect(chat.conversationError, isNull);
      expect(client.streamCancelled, isTrue);
      expect(chat.messages, isEmpty);
      unawaited(client.stream.close());
    });
  }

  testWidgets(
      'a switch finishing after expiry cannot restore the active Profile',
      (tester) async {
    final client = _SessionClient()
      ..expiry = tester.binding.clock
          .now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String();
    final chat =
        DesktopChatController(client: client, now: tester.binding.clock.now);
    final profiles = DesktopProfileController(chat: chat);
    addTearDown(() {
      profiles.dispose();
      chat.dispose();
      client.close();
    });
    await profiles.refresh(initializeDefault: true);
    client.delayedLoad = Completer<ConversationListOut>();
    client.loadStarted = Completer<void>();
    profiles.select('default');
    final switching = profiles.useSelected();
    await client.loadStarted!.future;
    await tester.pump(const Duration(minutes: 1));
    expect(profiles.activeProfileId, isNull);
    client.delayedLoad!
        .complete(ConversationListOut(items: [client.conversation], total: 1));
    await switching;
    expect(chat.isConnected, isFalse);
    expect(profiles.activeProfileId, isNull);
    expect(chat.conversations, isEmpty);
  });
}
