import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:ai_companion_desktop/features/voice/desktop_voice_controller.dart';
import 'package:ai_companion_desktop/features/voice/voice_shortcut_recorder.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/platform/desktop_audio_adapter.dart';
import 'package:ai_companion_desktop/shell/desktop_shell.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'desktop_lifecycle_test.dart';

void main() {
  void setupDesktopViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Desktop Shell Keyboard Shortcuts', () {
    testWidgets('Ctrl+, navigates directly to Settings screen', (tester) async {
      setupDesktopViewport(tester);

      final controller = DesktopSettingsController(
        initialDestination: DesktopNavDestination.chat,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(controller: controller),
        ),
      );

      expect(controller.currentDestination, equals(DesktopNavDestination.chat));

      // Trigger Ctrl+,
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.currentDestination, equals(DesktopNavDestination.settings));
      expect(find.text('Appearance & Theme'), findsOneWidget);
    });

    testWidgets('Escape hides to tray when system tray is active', (tester) async {
      setupDesktopViewport(tester);

      final windowAdapter = FakeDesktopWindowAdapter();
      final trayAdapter = FakeDesktopTrayAdapter();
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: trayAdapter,
      );
      await coordinator.initialize();

      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(
            controller: controller,
            coordinator: coordinator,
          ),
        ),
      );

      expect(windowAdapter.visible, isTrue);

      // Trigger Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(windowAdapter.visible, isFalse);
      expect(windowAdapter.hideCallCount, equals(1));
    });

    testWidgets('Escape does not hide window when system tray is unavailable', (tester) async {
      setupDesktopViewport(tester);

      final windowAdapter = FakeDesktopWindowAdapter();
      final failingTray = FailingDesktopTrayAdapter();
      final coordinator = DesktopLifecycleCoordinator(
        windowAdapter: windowAdapter,
        trayAdapter: failingTray,
      );
      await coordinator.initialize();
      expect(coordinator.isTrayAvailable, isFalse);

      final controller = DesktopSettingsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: DesktopShell(
            controller: controller,
            coordinator: coordinator,
          ),
        ),
      );

      expect(windowAdapter.visible, isTrue);

      // Trigger Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Window should still be visible because tray is unavailable
      expect(windowAdapter.visible, isTrue);
      expect(windowAdapter.hideCallCount, equals(0));
    });

    testWidgets(
      'Ctrl+Shift+V and F8 work regardless of widget focus, and Escape closes Chat history before hiding to tray',
      (tester) async {
        setupDesktopViewport(tester);

        final windowAdapter = FakeDesktopWindowAdapter();
        final trayAdapter = FakeDesktopTrayAdapter();
        final coordinator = DesktopLifecycleCoordinator(
          windowAdapter: windowAdapter,
          trayAdapter: trayAdapter,
        );
        await coordinator.initialize();

        final store = InMemoryCredentialStore()..writeToken('sess-tok');
        final client = CompanionClient(
          baseUrl: 'http://127.0.0.1:8000',
          sessionStore: store,
          httpClient: MockClient((req) async {
            final path = req.url.path;
            if (path == '/api/v1/health') {
              return http.Response(jsonEncode({'status': 'healthy'}), 200);
            }
            if (path == '/api/v1/auth/verify') {
              return http.Response(jsonEncode({'authenticated': true, 'profile_id': 'p1'}), 200);
            }
            if (path == '/api/v1/conversations' && req.method == 'POST') {
              return http.Response(
                jsonEncode({
                  'id': 'conv-sc-1',
                  'title': 'Voice Chat',
                  'created_at': '2026-11-18T10:00:00Z',
                  'updated_at': '2026-11-18T10:00:00Z',
                }),
                201,
              );
            }
            if (path == '/api/v1/voice/status') {
              return http.Response(
                jsonEncode({
                  'stt_available': true,
                  'stt_provider': 'whisper_cpp',
                  'vad_available': true,
                  'vad_provider': 'silero_onnx',
                  'tts_available': true,
                  'tts_provider': 'kokoro_onnx',
                  'cpu_first': true,
                }),
                200,
              );
            }
            if (path == '/api/v1/voice/voices') {
              return http.Response(jsonEncode({'voices': <dynamic>[]}), 200);
            }
            if (path == '/api/v1/voice/settings') {
              return http.Response(
                jsonEncode({
                  'profile_id': 'p1',
                  'barge_in_policy': 'smart_auto',
                  'vad_sensitivity': 'medium',
                  'stt_language': 'auto',
                  'tts_speed': 1.0,
                  'default_voice_id': 'af_nicole',
                  'auto_read_replies': false,
                  'proactive_speech_enabled': false,
                  'cloud_stt_enabled': false,
                  'cloud_tts_enabled': false,
                  'updated_at': '2026-11-18T10:00:00Z',
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'items': <dynamic>[], 'total': 0}), 200);
          }),
        );

        final chat = DesktopChatController(client: client);
        await chat.checkConnection();
        final ws = _ShortcutFakeWs();
        final voice = DesktopVoiceController(
          clientProvider: () => client,
          audioAdapter: _ShortcutFakeAudio(),
          voiceSessionClientFactory: () => VoiceSessionClient(wsClient: ws),
          ensureActiveConversationId: () async => 'conv-sc-1',
        );
        await voice.initialize();

        final controller = DesktopSettingsController(
          initialDestination: DesktopNavDestination.chat,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: CompanionTheme.dark(),
            home: DesktopShell(
              controller: controller,
              coordinator: coordinator,
              chatController: chat,
              voiceController: voice,
              enableSchedulePolling: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Click Settings tab via mouse so focus lands on ModalRoute Scope above DesktopShell Focus
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(controller.currentDestination, DesktopNavDestination.settings);

        // Press Ctrl+Shift+V while on Settings -> switches to Chat and starts Live Voice
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(controller.currentDestination, DesktopNavDestination.chat);
        expect(voice.isLiveVoiceActive, isTrue);

        // Press Ctrl+Shift+V a second time -> toggles Live Voice off
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(voice.isLiveVoiceActive, isFalse);

        // Default mute toggle Ctrl+Shift+M works everywhere too
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(voice.isAudioMuted, isTrue);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(voice.isAudioMuted, isFalse);

        // Open History drawer in Chat -> first Escape closes drawer WITHOUT hiding window to tray
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.text('Conversation History'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Conversation History'), findsNothing);
        expect(windowAdapter.hideCallCount, 0);

        // Second Escape hides window to tray
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(windowAdapter.hideCallCount, 1);

        // Press F8 backup mute toggle -> mutes & unmutes cleanly
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        expect(voice.isAudioMuted, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.f8);
        await tester.pumpAndSettle();
        expect(voice.isAudioMuted, isFalse);

        // Physical key fallback: CapsLock/Shift altered keyM (uppercase M keyId) still matches Ctrl+Shift+M
        expect(
          VoiceShortcutKeyMapper.physicalToVirtualKey(PhysicalKeyboardKey.keyM),
          equals(0x4D),
        );

        await ws.close();
        voice.dispose();
        chat.dispose();
        client.close();
      },
    );

    testWidgets(
      'Ctrl+H works globally when launched directly on Settings before Chat is visited',
      (tester) async {
        setupDesktopViewport(tester);

        final controller = DesktopSettingsController(
          initialDestination: DesktopNavDestination.settings,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: CompanionTheme.dark(),
            home: DesktopShell(
              controller: controller,
              enableSchedulePolling: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.currentDestination, DesktopNavDestination.settings);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(controller.currentDestination, DesktopNavDestination.chat);
        expect(find.text('Conversation History'), findsOneWidget);
      },
    );
  });
}

class _ShortcutFakeAudio implements DesktopAudioAdapter {
  bool _capturing = false;
  @override
  bool get isCapturing => _capturing;
  @override
  Stream<CapturedAudioFrame> get captureFrames => const Stream.empty();
  @override
  Stream<void> get globalHotkeyEvents => const Stream.empty();
  @override
  Future<List<AudioDeviceInfo>> listInputDevices() async => const [];
  @override
  Future<List<AudioDeviceInfo>> listOutputDevices() async => const [];
  @override
  Future<void> startCapture({String? deviceId}) async => _capturing = true;
  @override
  Future<void> stopCapture() async => _capturing = false;
  @override
  Future<void> playAudio(Uint8List bytes, {String? deviceId, int sampleRate = 24000, int generation = 0}) async {}
  @override
  Future<void> flushPlayback(int minGeneration) async {}
  @override
  Future<void> playTestTone({String? deviceId}) async {}
  @override
  Future<HotkeyRegistrationResult> registerGlobalHotkey(VoiceShortcutBinding binding) async =>
      const HotkeyRegistrationResult(registered: true);
  @override
  Future<void> unregisterGlobalHotkey() async {}
  @override
  Future<void> dispose() async {}
}

class _ShortcutFakeWs implements CompanionWebSocketClient {
  final StreamController<dynamic> _c = StreamController<dynamic>.broadcast();
  @override
  CompanionWebSocketState get state => CompanionWebSocketState.connected;
  @override
  Stream<dynamic> get incomingStream => _c.stream;
  @override
  Future<void> connect(Uri uri, {Map<String, dynamic>? headers}) async {}
  @override
  void send(dynamic message) {}
  @override
  Future<void> disconnect() async {}
  Future<void> close() => _c.close();
}
