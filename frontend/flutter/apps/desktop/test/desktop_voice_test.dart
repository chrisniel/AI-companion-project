import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_companion_desktop/features/voice/desktop_voice_controller.dart';
import 'package:ai_companion_desktop/lifecycle/desktop_lifecycle_coordinator.dart';
import 'package:ai_companion_desktop/platform/desktop_audio_adapter.dart';
import 'package:ai_companion_desktop/platform/desktop_client_settings.dart';
import 'package:companion_api/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'desktop_lifecycle_test.dart';

class _FakeAudioAdapter implements DesktopAudioAdapter {
  final StreamController<CapturedAudioFrame> _captureCtrl =
      StreamController<CapturedAudioFrame>.broadcast();
  final StreamController<void> _hotkeyCtrl = StreamController<void>.broadcast();
  bool _capturing = false;
  int flushCount = 0;
  int? lastFlushedGeneration;
  final List<int> playedGenerations = [];
  int testToneCount = 0;
  VoiceShortcutBinding? registeredHotkey;

  @override
  bool get isCapturing => _capturing;

  @override
  Stream<CapturedAudioFrame> get captureFrames => _captureCtrl.stream;

  @override
  Stream<void> get globalHotkeyEvents => _hotkeyCtrl.stream;

  void pushMicFrame(Uint8List pcm16, {double rms = 0.25}) {
    _captureCtrl.add(CapturedAudioFrame(pcm16Bytes: pcm16, rms: rms));
  }

  void triggerHotkey() => _hotkeyCtrl.add(null);

  @override
  Future<List<AudioDeviceInfo>> listInputDevices() async => const [
        AudioDeviceInfo(id: '', name: 'Default Windows Microphone', isDefault: true),
        AudioDeviceInfo(id: 'usb-mic', name: 'USB Condenser Mic'),
      ];

  @override
  Future<List<AudioDeviceInfo>> listOutputDevices() async => const [
        AudioDeviceInfo(id: '', name: 'Default Windows Speaker', isDefault: true),
        AudioDeviceInfo(id: 'hdmi-spk', name: 'Headphones'),
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
    playedGenerations.add(generation);
  }

  @override
  Future<void> flushPlayback(int minGeneration) async {
    flushCount++;
    lastFlushedGeneration = minGeneration;
  }

  @override
  Future<void> playTestTone({String? deviceId}) async {
    testToneCount++;
  }

  @override
  Future<HotkeyRegistrationResult> registerGlobalHotkey(VoiceShortcutBinding binding) async {
    registeredHotkey = binding;
    return const HotkeyRegistrationResult(registered: true);
  }

  @override
  Future<void> unregisterGlobalHotkey() async {
    registeredHotkey = null;
  }

  @override
  Future<void> dispose() async {
    _capturing = false;
    await _captureCtrl.close();
    await _hotkeyCtrl.close();
  }
}

class _FakeWsTransport implements CompanionWebSocketClient {
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

  void pushEvent(Map<String, dynamic> payload) {
    _controller.add(jsonEncode(payload));
  }

  @override
  Future<void> disconnect() async {
    _state = CompanionWebSocketState.disconnected;
  }

  Future<void> close() async => _controller.close();
}

void main() {
  group('DesktopClientSettings Voice Hardware & Shortcut Persistence', () {
    late Directory tempDir;
    late DesktopClientSettings settings;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('desktop_voice_prefs_');
      settings = DesktopClientSettings(
        customFilePath: '${tempDir.path}\\client_settings.json',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists voice hardware prefs without clobbering existing client settings', () async {
      await settings.writeHostUrl('http://127.0.0.1:8000');
      await settings.writeChatZoomLevel(1.2);

      final defaults = await settings.readVoiceHardwarePrefs();
      expect(defaults.selectedMicDeviceId, '');
      expect(defaults.selectedSpeakerDeviceId, '');
      expect(defaults.audioMuted, isFalse);

      await settings.writeVoiceHardwarePrefs(
        const VoiceHardwarePrefs(
          selectedMicDeviceId: 'mic-usb-1',
          selectedSpeakerDeviceId: 'spk-headset-2',
          audioMuted: true,
        ),
      );

      final reloaded = await settings.readVoiceHardwarePrefs();
      expect(reloaded.selectedMicDeviceId, 'mic-usb-1');
      expect(reloaded.selectedSpeakerDeviceId, 'spk-headset-2');
      expect(reloaded.audioMuted, isTrue);
      expect(await settings.readHostUrl(), 'http://127.0.0.1:8000');
      expect(await settings.readChatZoomLevel(), 1.2);
    });

    test('persists customizable voice shortcuts and validates conflicts', () async {
      final defaults = await settings.readVoiceShortcuts();
      expect(defaults.inAppToggle.label, 'Ctrl+Shift+V');
      expect(defaults.globalToggle.label, 'Ctrl+Alt+V');
      expect(defaults.muteToggle.label, 'Ctrl+Shift+M');
      expect(defaults.pushToTalk.label, 'Right Alt');
      expect(defaults.validateConflict(), isNull);

      final custom = defaults.copyWith(
        globalToggle: const VoiceShortcutBinding(
          ctrl: true,
          alt: false,
          shift: true,
          virtualKey: 0x59, // Y
          label: 'Ctrl+Shift+Y',
        ),
      );
      await settings.writeVoiceShortcuts(custom);
      final loaded = await settings.readVoiceShortcuts();
      expect(loaded.globalToggle.label, 'Ctrl+Shift+Y');
      expect(loaded.globalToggle.virtualKey, 0x59);
      expect(loaded.globalToggle.win32Modifiers, 0x0002 | 0x0004);

      final altSpace = defaults.copyWith(
        globalToggle: const VoiceShortcutBinding(
          ctrl: false,
          alt: true,
          shift: false,
          virtualKey: 0x20, // VK_SPACE
          label: 'Alt+Space',
        ),
      );
      expect(altSpace.validateConflict(), contains('Alt+Space'));

      final duplicate = defaults.copyWith(
        inAppToggle: defaults.muteToggle,
      );
      expect(duplicate.validateConflict(), contains('Duplicate'));
    });

    test('NoOpDesktopAudioAdapter satisfies safe defaults without platform plugins', () async {
      final adapter = NoOpDesktopAudioAdapter();
      final mics = await adapter.listInputDevices();
      final speakers = await adapter.listOutputDevices();
      expect(mics.single.isDefault, isTrue);
      expect(speakers.single.isDefault, isTrue);
      expect(adapter.isCapturing, isFalse);

      await adapter.startCapture();
      expect(adapter.isCapturing, isTrue);
      await adapter.stopCapture();
      expect(adapter.isCapturing, isFalse);

      await adapter.playAudio(Uint8List.fromList([0, 0, 0, 0]), sampleRate: 16000, generation: 1);
      await adapter.flushPlayback(2);
      await adapter.playTestTone();
      final reg = await adapter.registerGlobalHotkey(VoiceShortcutConfig.defaults().globalToggle);
      expect(reg.registered, isTrue);
      await adapter.unregisterGlobalHotkey();
      await adapter.dispose();
    });
  });

  group('DesktopVoiceController State Machine & Tray Mute', () {
    Future<CompanionClient> buildVoiceClient({
      bool autoRead = true,
      String? lastTranscribeFormat,
      void Function(http.Request)? onRequest,
    }) async {
      final store = InMemoryCredentialStore();
      await store.writeToken('sess-tok');
      return CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        sessionStore: store,
        httpClient: MockClient((request) async {
          onRequest?.call(request);
          if (request.url.path == '/api/v1/voice/status') {
            return http.Response(
              jsonEncode({
                'stt_available': true,
                'stt_provider': 'whisper_cpp',
                'stt_model': 'ggml-base.bin',
                'vad_available': true,
                'vad_provider': 'silero_onnx',
                'tts_available': true,
                'tts_provider': 'kokoro_onnx',
                'cpu_first': true,
                'active_voice_sessions': 0,
              }),
              200,
            );
          }
          if (request.url.path == '/api/v1/voice/voices') {
            return http.Response(
              jsonEncode({
                'voices': [
                  {
                    'voice_id': 'af_nicole',
                    'name': 'Nicole',
                    'provider': 'kokoro_onnx',
                    'language': 'en',
                    'sample_rate': 24000,
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/v1/voice/settings') {
            return http.Response(
              jsonEncode({
                'profile_id': 'p1',
                'barge_in_policy': 'smart_auto',
                'vad_sensitivity': 'medium',
                'stt_language': 'auto',
                'tts_speed': 1.0,
                'default_voice_id': 'af_nicole',
                'auto_read_replies': autoRead,
                'proactive_speech_enabled': false,
                'cloud_stt_enabled': false,
                'cloud_tts_enabled': false,
                'updated_at': '2026-11-17T10:00:00Z',
              }),
              200,
            );
          }
          if (request.url.path == '/api/v1/voice/transcribe') {
            return http.Response(
              jsonEncode({
                'text': 'Open my schedule',
                'language': 'en',
                'duration_ms': 400,
                'provider': 'whisper_cpp',
              }),
              200,
            );
          }
          if (request.url.path == '/api/v1/voice/synthesize') {
            return http.Response(
              jsonEncode({
                'audio_base64': base64Encode(Uint8List.fromList([1, 2, 3, 4])),
                'mime_type': 'audio/wav',
                'sample_rate': 24000,
                'duration_ms': 300,
                'voice_id': 'af_nicole',
                'provider': 'kokoro_onnx',
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
    }

    test('dictation captures pcm16 frames and transcribes cleanly', () async {
      final capturedBodies = <Map<String, dynamic>>[];
      final client = await buildVoiceClient(onRequest: (req) {
        if (req.url.path == '/api/v1/voice/transcribe') {
          capturedBodies.add(Map<String, dynamic>.from(jsonDecode(req.body) as Map));
        }
      });
      final audio = _FakeAudioAdapter();
      final tempDir = await Directory.systemTemp.createTemp('dvc_dict_');
      addTearDown(() => tempDir.delete(recursive: true));

      final ctrl = DesktopVoiceController(
        clientProvider: () => client,
        audioAdapter: audio,
        clientSettings: DesktopClientSettings(customFilePath: '${tempDir.path}\\cs.json'),
      );
      await ctrl.initialize();
      await ctrl.startDictation();
      expect(ctrl.isDictating, isTrue);
      expect(audio.isCapturing, isTrue);

      audio.pushMicFrame(Uint8List.fromList(List<int>.filled(1024, 1)), rms: 0.42);
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.micRmsLevel, closeTo(0.42, 0.01));

      final transcript = await ctrl.stopDictationAndTranscribe();
      expect(transcript, 'Open my schedule');
      expect(audio.isCapturing, isFalse);
      expect(ctrl.phase, VoiceSessionPhase.idle);
      expect(capturedBodies.single['format'], 'pcm16');
      ctrl.dispose();
    });

    test('live voice enforces generation-fenced barge-in and immediate profile reset', () async {
      final client = await buildVoiceClient();
      final audio = _FakeAudioAdapter();
      final fakeWs = _FakeWsTransport();
      final refreshedConversations = <String>[];
      var mutedFromCallback = false;

      final ctrl = DesktopVoiceController(
        clientProvider: () => client,
        audioAdapter: audio,
        voiceSessionClientFactory: () => VoiceSessionClient(wsClient: fakeWs),
        ensureActiveConversationId: () async => 'conv-42',
        onConversationMessagesUpdated: (id) async => refreshedConversations.add(id),
        onAudioMutedChanged: (m) => mutedFromCallback = m,
      );
      await ctrl.initialize();
      await ctrl.startLiveVoice();
      expect(ctrl.isLiveVoiceActive, isTrue);
      expect(audio.isCapturing, isTrue);
      expect(fakeWs.sent.single['type'], 'session.start');

      // Turn 1 speaks
      fakeWs.pushEvent({'type': 'stt.final', 'turn_id': 1, 'text': 'Hello Aria'});
      fakeWs.pushEvent({'type': 'llm.delta', 'turn_id': 1, 'content': 'Hi there!'});
      fakeWs.pushEvent({
        'type': 'tts.audio.chunk',
        'turn_id': 1,
        'seq': 0,
        'sample_rate': 24000,
        'wav_base64': base64Encode(Uint8List.fromList([10, 20, 30, 40])),
      });
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.liveUserTranscript, 'Hello Aria');
      expect(ctrl.liveAssistantTranscript, 'Hi there!');
      expect(audio.playedGenerations, [1]);

      // Manual barge-in bumps generation and flushes native mixer immediately
      await ctrl.interruptBargeIn(reason: 'spacebar');
      expect(ctrl.playbackGeneration, 2);
      expect(audio.lastFlushedGeneration, 2);
      expect(fakeWs.sent.any((f) => f['type'] == 'barge_in'), isTrue);

      // Mute cuts OS mic capture & bumps flush generation
      await ctrl.setMuted(true);
      expect(mutedFromCallback, isTrue);
      expect(audio.isCapturing, isFalse);
      expect(ctrl.isLiveVoiceActive, isFalse);

      // Unmute and restart live voice -> profile epoch change kills everything cleanly
      await ctrl.setMuted(false);
      await ctrl.startLiveVoice();
      expect(audio.isCapturing, isTrue);
      await ctrl.handleProfileEpochChanged(99);
      expect(audio.isCapturing, isFalse);
      expect(ctrl.isLiveVoiceActive, isFalse);
      expect(refreshedConversations, contains('conv-42'));

      ctrl.dispose();
      await fakeWs.close();
    });

    test('auto-read only speaks completed non-empty assistant replies when enabled and unmuted', () async {
      final client = await buildVoiceClient(autoRead: true);
      final audio = _FakeAudioAdapter();
      final ctrl = DesktopVoiceController(
        clientProvider: () => client,
        audioAdapter: audio,
      );
      await ctrl.initialize();

      await ctrl.handleChatCompletionForAutoRead(
        const MessageOut(
          id: 'm1',
          conversationId: 'c1',
          sender: 'assistant',
          content: 'Good evening!',
          status: 'completed',
          sequenceNo: 2,
          createdAt: '2026-11-17T10:00:00Z',
        ),
      );
      expect(audio.playedGenerations, hasLength(1));

      await ctrl.handleChatCompletionForAutoRead(
        const MessageOut(
          id: 'm2',
          conversationId: 'c1',
          sender: 'assistant',
          content: 'Cancelled partial',
          status: 'cancelled',
          sequenceNo: 4,
          createdAt: '2026-11-17T10:01:00Z',
        ),
      );
      expect(audio.playedGenerations, hasLength(1));
      ctrl.dispose();
    });

    test('DesktopLifecycleCoordinator builds Mute Audio tray menu item cleanly', () {
      final coord = DesktopLifecycleCoordinator(
        windowAdapter: FakeDesktopWindowAdapter(),
        trayAdapter: FakeDesktopTrayAdapter(),
      );
      final unmutedItems = coord.buildTrayMenuItemsWithSafety(null, false, false);
      expect(unmutedItems.any((i) => i.key == 'mute_audio_toggle' && i.label == 'Mute Audio (Ctrl+Shift+M)'), isTrue);

      final mutedItems = coord.buildTrayMenuItemsWithSafety(null, false, false, true);
      expect(mutedItems.any((i) => i.key == 'mute_audio_toggle' && i.label == 'Unmute Audio (Ctrl+Shift+M)'), isTrue);
    });
  });
}
