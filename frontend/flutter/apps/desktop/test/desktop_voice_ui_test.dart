import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/settings/sections/settings_voice_section.dart';
import 'package:ai_companion_desktop/features/voice/desktop_voice_controller.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/platform/desktop_audio_adapter.dart';
import 'package:ai_companion_desktop/screens/chat_screen.dart';
import 'package:ai_companion_desktop/shell/desktop_shell.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'desktop_lifecycle_test.dart';

class _TestVoiceAudioAdapter implements DesktopAudioAdapter {
  final StreamController<CapturedAudioFrame> _captureCtrl =
      StreamController<CapturedAudioFrame>.broadcast();
  final StreamController<void> _hotkeyCtrl = StreamController<void>.broadcast();
  bool _capturing = false;
  bool failNextHotkeyRegistration = false;
  int testToneCount = 0;
  int playCount = 0;
  int flushCount = 0;
  final List<String> spokenPayloads = [];

  @override
  bool get isCapturing => _capturing;

  @override
  Stream<CapturedAudioFrame> get captureFrames => _captureCtrl.stream;

  @override
  Stream<void> get globalHotkeyEvents => _hotkeyCtrl.stream;

  void pushFrame(Uint8List bytes, {double rms = 0.4}) {
    _captureCtrl.add(CapturedAudioFrame(pcm16Bytes: bytes, rms: rms));
  }

  void triggerGlobalHotkey() => _hotkeyCtrl.add(null);

  @override
  Future<List<AudioDeviceInfo>> listInputDevices() async => const [
        AudioDeviceInfo(id: '', name: 'Default Windows Mic', isDefault: true),
        AudioDeviceInfo(id: 'usb-mic-1', name: 'Desk USB Mic'),
      ];

  @override
  Future<List<AudioDeviceInfo>> listOutputDevices() async => const [
        AudioDeviceInfo(id: '', name: 'Default Windows Speaker', isDefault: true),
        AudioDeviceInfo(id: 'desk-spk-1', name: 'Studio Monitors'),
      ];

  @override
  Future<void> startCapture({String? deviceId}) async {
    _capturing = true;
  }

  @override
  Future<void> stopCapture() async {
    _capturing = false;
  }

  @override
  Future<void> playAudio(
    Uint8List wavOrPcmBytes, {
    String? deviceId,
    int sampleRate = 24000,
    int generation = 0,
  }) async {
    playCount++;
  }

  @override
  Future<void> flushPlayback(int minGeneration) async {
    flushCount++;
  }

  @override
  Future<void> playTestTone({String? deviceId}) async {
    testToneCount++;
  }

  @override
  Future<HotkeyRegistrationResult> registerGlobalHotkey(
    VoiceShortcutBinding binding,
  ) async {
    if (failNextHotkeyRegistration) {
      return HotkeyRegistrationResult(
        registered: false,
        errorMessage: 'Shortcut ${binding.label} is already registered by another app.',
      );
    }
    return const HotkeyRegistrationResult(registered: true);
  }

  @override
  Future<void> unregisterGlobalHotkey() async {}

  @override
  Future<void> dispose() async {
    _capturing = false;
    await _captureCtrl.close();
    await _hotkeyCtrl.close();
  }
}

class _TestVoiceWsTransport implements CompanionWebSocketClient {
  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();
  final List<Map<String, dynamic>> sent = [];
  CompanionWebSocketState _state = CompanionWebSocketState.disconnected;

  @override
  CompanionWebSocketState get state => _state;

  @override
  Stream<dynamic> get incomingStream => _controller.stream;

  @override
  Future<void> connect(Uri uri, {Map<String, dynamic>? headers}) async {
    _state = CompanionWebSocketState.connected;
  }

  @override
  void send(dynamic message) {
    sent.add(Map<String, dynamic>.from(jsonDecode(message as String) as Map));
  }

  void pushEvent(Map<String, dynamic> event) {
    _controller.add(jsonEncode(event));
  }

  @override
  Future<void> disconnect() async {
    _state = CompanionWebSocketState.disconnected;
  }

  Future<void> close() async => _controller.close();
}

void main() {
  void setupViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 860);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  ({
    CompanionClient client,
    Map<String, dynamic> voiceSettingsState,
    List<Map<String, dynamic>> patchPayloads,
    List<String> synthesizedTexts,
  }) buildVoiceBackend() {
    final settings = <String, dynamic>{
      'profile_id': 'profile-1',
      'barge_in_policy': 'smart_auto',
      'vad_sensitivity': 'medium',
      'stt_language': 'en',
      'tts_speed': 1.0,
      'default_voice_id': 'af_nicole',
      'auto_read_replies': false,
      'proactive_speech_enabled': false,
      'cloud_stt_enabled': false,
      'cloud_tts_enabled': false,
      'updated_at': '2026-01-01T00:00:00Z',
    };
    final patchPayloads = <Map<String, dynamic>>[];
    final synthesizedTexts = <String>[];

    final mockHttp = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/health')) {
        return http.Response('{"status":"healthy"}', 200);
      }
      if (path.endsWith('/me')) {
        return http.Response(
          jsonEncode({
            'id': 'profile-1',
            'name': 'Chris',
            'expires_at': '2099-01-01T00:00:00Z',
          }),
          200,
        );
      }
      if (path.endsWith('/voice/status')) {
        return http.Response(
          jsonEncode({
            'stt_available': true,
            'stt_provider': 'faster_whisper',
            'stt_model': 'tiny',
            'vad_available': true,
            'vad_provider': 'silero',
            'tts_available': true,
            'tts_provider': 'kokoro',
            'cpu_first': true,
          }),
          200,
        );
      }
      if (path.endsWith('/voice/voices')) {
        return http.Response(
          jsonEncode({
            'voices': [
              {
                'voice_id': 'af_nicole',
                'name': 'Nicole',
                'provider': 'kokoro',
                'language': 'en-us',
                'sample_rate': 24000,
              },
              {
                'voice_id': 'bf_emma',
                'name': 'Emma',
                'provider': 'kokoro',
                'language': 'en-gb',
                'sample_rate': 24000,
              },
            ],
          }),
          200,
        );
      }
      if (path.endsWith('/voice/settings')) {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(settings), 200);
        }
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          patchPayloads.add(body);
          settings.addAll(body);
          return http.Response(jsonEncode(settings), 200);
        }
      }
      if (path.endsWith('/voice/transcribe')) {
        return http.Response(
          jsonEncode({
            'text': 'hello from windows mic',
            'language': 'en',
            'duration_ms': 420,
            'provider': 'faster_whisper',
          }),
          200,
        );
      }
      if (path.endsWith('/voice/synthesize')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        synthesizedTexts.add(body['text'] as String);
        return http.Response(
          jsonEncode({
            'audio_base64': base64Encode([1, 2, 3, 4]),
            'mime_type': 'audio/wav',
            'sample_rate': 24000,
            'duration_ms': 250,
            'voice_id': body['voice_id'] ?? settings['default_voice_id'],
            'provider': 'kokoro',
          }),
          200,
        );
      }
      if (path.endsWith('/conversations') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'conv-1',
                'title': 'Voice Chat',
                'character_id': 'neutral-assistant',
                'owner_id': 'profile-1',
                'created_at': '2026-01-01T00:00:00Z',
                'updated_at': '2026-01-01T00:00:00Z',
                'message_count': 1,
              },
            ],
            'total': 1,
          }),
          200,
        );
      }
      if (path.endsWith('/conversations/conv-1/messages') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'msg-assistant-1',
                'conversation_id': 'conv-1',
                'sender': 'assistant',
                'content': 'Welcome back, ready to talk.',
                'sequence_no': 1,
                'status': 'completed',
                'created_at': '2026-01-01T00:00:00Z',
                'updated_at': '2026-01-01T00:00:00Z',
              },
            ],
            'total': 1,
          }),
          200,
        );
      }
      if (path.endsWith('/conversations/conv-1/summary')) {
        return http.Response('{"summary":null}', 200);
      }
      return http.Response('{}', 200);
    });

    final client = CompanionClient(
      sessionStore: InMemoryCredentialStore('psk_test'),
      httpClient: mockHttp,
    );

    return (
      client: client,
      voiceSettingsState: settings,
      patchPayloads: patchPayloads,
      synthesizedTexts: synthesizedTexts,
    );
  }

  group('SettingsVoiceSection Widget Tests', () {
    testWidgets(
      'renders engine readiness, RAM-only disclosure, devices, shortcuts conflict warning, and behavior controls',
      timeout: const Timeout(Duration(seconds: 10)),
      (tester) async {
      setupViewport(tester);
      final backend = buildVoiceBackend();
      final audio = _TestVoiceAudioAdapter();
      final controller = DesktopVoiceController(
        clientProvider: () => backend.client,
        audioAdapter: audio,
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsVoiceSection(voiceController: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_voice_readiness_card')), findsOneWidget);
      expect(find.textContaining('STT: Ready (faster_whisper · tiny)'), findsOneWidget);
      expect(find.textContaining('VAD: Ready (silero)'), findsOneWidget);
      expect(find.textContaining('TTS: Ready (kokoro)'), findsOneWidget);
      expect(find.textContaining('CPU-First Local'), findsOneWidget);
      expect(find.textContaining('temporary RAM only'), findsOneWidget);

      // Test Sound button
      await tester.ensureVisible(find.byKey(const Key('settings_voice_test_tone_button')));
      await tester.tap(find.byKey(const Key('settings_voice_test_tone_button')));
      await tester.pumpAndSettle();
      expect(audio.testToneCount, 1);

      // Proactive Speech opt-in defaults OFF
      final proactiveSwitch = tester.widget<Switch>(
        find.byKey(const Key('settings_voice_proactive_switch')),
      );
      expect(proactiveSwitch.value, isFalse);

      // Changing Barge-In Policy dispatches PATCH with strict_noisy
      await tester.ensureVisible(find.byKey(const Key('settings_voice_barge_in_dropdown')));
      await tester.tap(find.byKey(const Key('settings_voice_barge_in_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Strict Noisy Room').last);
      await tester.pumpAndSettle();
      expect(backend.patchPayloads.last['barge_in_policy'], 'strict_noisy');

      controller.dispose();
    });

    testWidgets(
      'surfaces hotkey registration conflict warning and Reset Defaults recovery',
      timeout: const Timeout(Duration(seconds: 10)),
      (tester) async {
      setupViewport(tester);
      final backend = buildVoiceBackend();
      final audio = _TestVoiceAudioAdapter();
      final controller = DesktopVoiceController(
        clientProvider: () => backend.client,
        audioAdapter: audio,
      );
      await controller.initialize();

      audio.failNextHotkeyRegistration = true;
      final err = await controller.updateShortcuts(
        controller.shortcuts.copyWith(
          globalToggle: const VoiceShortcutBinding(
            ctrl: true,
            alt: true,
            shift: false,
            virtualKey: 0x4B,
            label: 'Ctrl+Alt+K',
          ),
        ),
      );
      expect(err, contains('Ctrl+Alt+K'));
      expect(controller.globalHotkeyWarning, contains('Ctrl+Alt+K'));

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsVoiceSection(voiceController: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_voice_hotkey_warning')), findsOneWidget);

      audio.failNextHotkeyRegistration = false;
      await tester.ensureVisible(
        find.byKey(const Key('settings_voice_reset_shortcuts_button')),
      );
      await tester.tap(
        find.byKey(const Key('settings_voice_reset_shortcuts_button')),
      );
      await tester.pumpAndSettle();
      expect(controller.shortcuts.globalToggle.label, 'Ctrl+Alt+V');
      expect(find.byKey(const Key('settings_voice_hotkey_warning')), findsNothing);

      controller.dispose();
    });
  });

  group('ChatScreen Option A Voice Integration Tests', () {
    testWidgets(
      'Header Live Voice toggle opens stage panel, Dictate transcribes into draft, and Read Aloud works',
      timeout: const Timeout(Duration(seconds: 10)),
      (tester) async {
      setupViewport(tester);
      final backend = buildVoiceBackend();
      final audio = _TestVoiceAudioAdapter();
      final ws = _TestVoiceWsTransport();
      final chat = DesktopChatController(client: backend.client);
      await chat.checkConnection();
      await chat.loadConversations();

      final voice = DesktopVoiceController(
        clientProvider: () => backend.client,
        audioAdapter: audio,
        voiceSessionClientFactory: () => VoiceSessionClient(wsClient: ws),
        ensureActiveConversationId: () async => chat.activeConversation?.id,
      );
      await voice.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: ChatScreen(
              controller: chat,
              voiceController: voice,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Dictation preserves existing draft text
      await tester.enterText(find.byType(TextField), 'Note:');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat_dictate_button')));
      await tester.pump();
      expect(voice.isDictating, isTrue);
      audio.pushFrame(Uint8List.fromList(List.filled(64, 3)), rms: 0.4);
      await tester.tap(find.byKey(const Key('chat_dictate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Note: hello from windows mic'), findsOneWidget);

      // 2. Per-message Read Aloud triggers synthesis + Stop resets
      await tester.tap(find.byKey(const Key('message_speak_msg-assistant-1')));
      await tester.pumpAndSettle();
      expect(backend.synthesizedTexts, contains('Welcome back, ready to talk.'));
      expect(audio.playCount, 1);
      expect(find.text('Stop'), findsOneWidget);
      await tester.tap(find.byKey(const Key('message_speak_msg-assistant-1')));
      await tester.pumpAndSettle();
      expect(find.text('Read Aloud'), findsOneWidget);

      // 3. Header Live Voice opens LiveVoiceStagePanel and renders live captions
      await tester.tap(find.byKey(const Key('chat_voice_mode_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live_voice_stage_panel')), findsOneWidget);

      ws.pushEvent({'type': 'session.ready', 'conversation_id': 'conv-1'});
      ws.pushEvent({'type': 'stt.final', 'text': 'Check the calendar'});
      ws.pushEvent({'type': 'llm.delta', 'content': 'Looking now'});
      ws.pushEvent({'type': 'tool.intent', 'tool_name': 'list_events'});
      await tester.pumpAndSettle();

      expect(find.textContaining('Check the calendar'), findsOneWidget);
      expect(find.textContaining('Looking now'), findsOneWidget);
      expect(find.textContaining('list_events'), findsOneWidget);

      // Unfocused Spacebar triggers immediate barge-in interrupt
      await tester.tap(find.byKey(const Key('live_voice_phase_badge')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(ws.sent.any((f) => f['type'] == 'barge_in'), isTrue);

      // End Voice closes stage panel
      await tester.tap(find.byKey(const Key('live_voice_end_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live_voice_stage_panel')), findsNothing);

      await ws.close();
      voice.dispose();
      chat.dispose();
    });

    testWidgets(
      'Auto-Read toggle persists setting and speaks newly completed assistant turn cleanly',
      timeout: const Timeout(Duration(seconds: 10)),
      (tester) async {
        setupViewport(tester);
        final backend = buildVoiceBackend();
        final audio = _TestVoiceAudioAdapter();
        final voice = DesktopVoiceController(
          clientProvider: () => backend.client,
          audioAdapter: audio,
        );
        await voice.initialize();

        await tester.pumpWidget(
          MaterialApp(
            theme: CompanionTheme.dark(),
            home: Scaffold(
              body: ChatScreen(voiceController: voice),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enable Auto-Read via header chip
        await tester.tap(find.byKey(const Key('chat_auto_read_toggle')));
        await tester.pumpAndSettle();
        expect(backend.patchPayloads.last['auto_read_replies'], isTrue);
        expect(voice.voiceSettings?.autoReadReplies, isTrue);

        // Clean completion triggers synthesis; interrupted/cancelled turns do NOT
        await voice.handleChatCompletionForAutoRead(
          const MessageOut(
            id: 'msg-auto-1',
            conversationId: 'conv-1',
            sender: 'assistant',
            content: 'Here is your daily summary.',
            sequenceNo: 2,
            status: 'completed',
            createdAt: '2026-01-01T00:00:00Z',
          ),
        );
        expect(backend.synthesizedTexts, contains('Here is your daily summary.'));
        expect(audio.playCount, 1);

        await voice.handleChatCompletionForAutoRead(
          const MessageOut(
            id: 'msg-auto-2',
            conversationId: 'conv-1',
            sender: 'assistant',
            content: 'Cancelled turn',
            sequenceNo: 3,
            status: 'cancelled',
            createdAt: '2026-01-01T00:00:00Z',
          ),
        );
        expect(backend.synthesizedTexts, hasLength(1));

        voice.dispose();
      },
    );
  });

  group('DesktopShell Option A & Mic Privacy Indicator Tests', () {
    testWidgets(
      'shows glowing amber Mic Privacy Indicator on capture and syncs tray hard mute',
      timeout: const Timeout(Duration(seconds: 10)),
      (tester) async {
      setupViewport(tester);
      final backend = buildVoiceBackend();
      final audio = _TestVoiceAudioAdapter();
      final settings = DesktopSettingsController();
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: FakeDesktopWindowAdapter(),
        trayAdapter: FakeDesktopTrayAdapter(),
      );
      await coordinator.initialize();

      final chat = DesktopChatController(client: backend.client);
      await chat.checkConnection();

      final voice = DesktopVoiceController(
        clientProvider: () => backend.client,
        audioAdapter: audio,
        onAudioMutedChanged: coordinator.updateAudioMutedStatus,
      );
      await voice.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(
            controller: settings,
            coordinator: coordinator,
            chatController: chat,
            voiceController: voice,
            enableSchedulePolling: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 5 nav rail tabs only (Voice removed)
      expect(find.text('Voice'), findsNothing);
      expect(find.byKey(const Key('shell_mic_privacy_indicator')), findsNothing);

      // Start dictation -> Mic Active privacy indicator lights up in header utility strip
      await voice.startDictation();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shell_mic_privacy_indicator')), findsOneWidget);
      expect(find.text('Mic Active'), findsOneWidget);

      // Tray mute triggers hard mute -> mic stops capturing and Audio Muted badge shows
      await coordinator.onMuteToggleTriggered?.call();
      await tester.pumpAndSettle();
      expect(voice.isAudioMuted, isTrue);
      expect(audio.isCapturing, isFalse);
      expect(find.byKey(const Key('shell_mic_privacy_indicator')), findsNothing);
      expect(find.byKey(const Key('shell_mic_muted_indicator')), findsOneWidget);

      voice.dispose();
      chat.dispose();
      await coordinator.dispose();
    });
  });
}
