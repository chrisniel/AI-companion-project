import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:companion_api/companion_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

class _FakeWebSocketClient implements CompanionWebSocketClient {
  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();
  final List<Map<String, dynamic>> sentFrames = [];
  Uri? connectedUri;
  Map<String, dynamic>? connectedHeaders;
  CompanionWebSocketState _state = CompanionWebSocketState.disconnected;

  @override
  CompanionWebSocketState get state => _state;

  @override
  Stream<dynamic> get incomingStream => _controller.stream;

  @override
  Future<void> connect(Uri uri, {Map<String, dynamic>? headers}) async {
    connectedUri = uri;
    connectedHeaders = headers;
    _state = CompanionWebSocketState.connected;
  }

  @override
  void send(dynamic message) {
    sentFrames.add(Map<String, dynamic>.from(jsonDecode(message as String) as Map));
  }

  void pushServerFrame(Map<String, dynamic> payload) {
    _controller.add(jsonEncode(payload));
  }

  @override
  Future<void> disconnect() async {
    _state = CompanionWebSocketState.disconnected;
  }

  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  group('Voice DTOs and Character voiceId', () {
    test('VoiceStatusOut, VoiceSettingsOut, and catalog round-trip JSON', () {
      final status = VoiceStatusOut.fromJson({
        'stt_available': true,
        'stt_provider': 'whisper.cpp',
        'stt_model': 'ggml-base.en.bin',
        'vad_available': true,
        'vad_provider': 'silero-onnx',
        'tts_available': true,
        'tts_provider': 'kokoro-onnx',
        'cpu_first': true,
        'active_voice_sessions': 2,
      });
      expect(status.sttAvailable, isTrue);
      expect(status.sttModel, 'ggml-base.en.bin');
      expect(status.activeVoiceSessions, 2);
      expect(VoiceStatusOut.fromJson(status.toJson()).ttsProvider, 'kokoro-onnx');

      final settings = VoiceSettingsOut.fromJson({
        'profile_id': 'p1',
        'barge_in_policy': 'smart_auto',
        'vad_sensitivity': 'medium',
        'stt_language': 'en',
        'tts_speed': 1.15,
        'default_voice_id': 'af_nicole',
        'auto_read_replies': true,
        'proactive_speech_enabled': false,
        'cloud_stt_enabled': false,
        'cloud_tts_enabled': false,
        'updated_at': '2026-11-16T12:00:00Z',
      });
      expect(settings.autoReadReplies, isTrue);
      expect(settings.ttsSpeed, 1.15);
      expect(VoiceSettingsOut.fromJson(settings.toJson()).defaultVoiceId, 'af_nicole');

      final catalog = VoiceCatalogOut.fromJson({
        'voices': [
          {
            'voice_id': 'af_nicole',
            'name': 'Nicole',
            'provider': 'kokoro-onnx',
            'language': 'en-US',
            'sample_rate': 24000,
          },
        ],
      });
      expect(catalog.voices, hasLength(1));
      expect(catalog.voices.first.sampleRate, 24000);
    });

    test('CharacterInstanceUpdate supports explicit clearVoiceId: true', () {
      const keepUnchanged = CharacterInstanceUpdate(name: 'Aria');
      expect(keepUnchanged.toJson().containsKey('voice_id'), isFalse);

      const clearVoice = CharacterInstanceUpdate();
      final clearedJson = clearVoice.toJson(clearVoiceId: true);
      expect(clearedJson.containsKey('voice_id'), isTrue);
      expect(clearedJson['voice_id'], isNull);

      final out = CharacterInstanceOut.fromJson({
        'id': 'c1',
        'profile_id': 'p1',
        'name': 'Aria',
        'summary': 'Helper',
        'lore': '',
        'system_prompt': 'Be helpful',
        'avatar_asset': 'aria',
        'voice_id': 'af_bella',
        'status': 'active',
        'created_at': '2026-11-16T10:00:00Z',
        'updated_at': '2026-11-16T10:00:00Z',
      });
      expect(out.voiceId, 'af_bella');
      expect(out.toJson()['voice_id'], 'af_bella');
    });
  });

  group('CompanionClient Voice REST endpoints', () {
    test('calls all 6 /api/v1/voice/* endpoints and clearVoiceId update', () async {
      final recordedRequests = <http.Request>[];
      final mockClient = MockClient((request) async {
        recordedRequests.add(request);
        if (request.url.path == '/api/v1/voice/status') {
          return http.Response(
            jsonEncode({
              'stt_available': false,
              'stt_provider': 'unavailable',
              'vad_available': true,
              'vad_provider': 'adaptive-energy',
              'tts_available': true,
              'tts_provider': 'windows-sapi',
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
                  'voice_id': 'sapi_default',
                  'name': 'Windows Voice',
                  'provider': 'windows-sapi',
                  'language': 'en-US',
                  'sample_rate': 22050,
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
              'barge_in_policy': 'strict_noisy',
              'vad_sensitivity': 'high',
              'stt_language': 'en',
              'tts_speed': 1.0,
              'default_voice_id': 'af_nicole',
              'auto_read_replies': false,
              'proactive_speech_enabled': false,
              'cloud_stt_enabled': false,
              'cloud_tts_enabled': false,
              'updated_at': '2026-11-16T12:00:00Z',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/voice/transcribe') {
          return http.Response(
            jsonEncode({
              'text': 'hello world',
              'language': 'en',
              'duration_ms': 950,
              'provider': 'mock-stt',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/voice/synthesize') {
          return http.Response(
            jsonEncode({
              'audio_base64': 'UklGRg==',
              'mime_type': 'audio/wav',
              'sample_rate': 24000,
              'duration_ms': 420,
              'voice_id': 'af_nicole',
              'provider': 'mock-tts',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/characters/instances/inst1') {
          return http.Response(
            jsonEncode({
              'id': 'inst1',
              'profile_id': 'p1',
              'name': 'Aria',
              'summary': 'Summary',
              'lore': '',
              'system_prompt': 'Prompt',
              'avatar_asset': 'aria',
              'voice_id': null,
              'status': 'active',
              'created_at': '2026-11-16T10:00:00Z',
              'updated_at': '2026-11-16T12:00:00Z',
            }),
            200,
          );
        }
        return http.Response('{"detail": "not found"}', 404);
      });

      final sessionStore = InMemoryCredentialStore();
      await sessionStore.writeToken('sess-tok');
      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockClient,
        sessionStore: sessionStore,
      );

      final status = await client.getVoiceStatus();
      expect(status.vadProvider, 'adaptive-energy');

      final voices = await client.listVoices();
      expect(voices.voices.single.voiceId, 'sapi_default');

      final settings = await client.getVoiceSettings();
      expect(settings.bargeInPolicy, 'strict_noisy');

      final patched = await client.updateVoiceSettings(
        const VoiceSettingsUpdate(bargeInPolicy: 'strict_noisy'),
      );
      expect(patched.vadSensitivity, 'high');

      final tx = await client.transcribeAudio(
        const VoiceTranscribeRequest(audioBase64: 'UklGRg=='),
      );
      expect(tx.text, 'hello world');

      final synth = await client.synthesizeSpeech(
        const VoiceSynthesizeRequest(text: 'Good morning'),
      );
      expect(synth.durationMs, 420);

      final updatedChar = await client.updateCharacterInstance(
        'inst1',
        const CharacterInstanceUpdate(),
        clearVoiceId: true,
      );
      expect(updatedChar.voiceId, isNull);
      final patchBody = jsonDecode(recordedRequests.last.body) as Map<String, dynamic>;
      expect(patchBody.containsKey('voice_id'), isTrue);
      expect(patchBody['voice_id'], isNull);

      client.close();
    });
  });

  group('WebSocketChannelCompanionClient & VoiceSessionClient', () {
    test('refuses credentialed ws:// to non-loopback host per D5', () async {
      final ws = WebSocketChannelCompanionClient();
      expect(
        () => ws.connect(
          Uri.parse('ws://192.168.1.50:8000/api/v1/voice/ws'),
          headers: {'Authorization': 'Bearer secret'},
        ),
        throwsStateError,
      );
      await ws.dispose();
    });

    test('VoiceSessionClient sends duplex frames and drops stale chunks after barge-in',
        () async {
      final fakeWs = _FakeWebSocketClient();
      final sessionStore = InMemoryCredentialStore();
      await sessionStore.writeToken('session-123');

      final voiceClient = VoiceSessionClient(wsClient: fakeWs);
      final received = <VoiceWsEvent>[];
      final sub = voiceClient.events.listen(received.add);

      await voiceClient.connect(
        baseUri: Uri.parse('https://companion.local:8443'),
        sessionStore: sessionStore,
        conversationId: 'conv-1',
      );

      expect(
        fakeWs.connectedUri.toString(),
        'wss://companion.local:8443/api/v1/voice/ws',
      );
      expect(fakeWs.connectedHeaders?['Authorization'], 'Bearer session-123');
      expect(fakeWs.sentFrames.single['type'], 'session.start');
      expect(fakeWs.sentFrames.single['conversation_id'], 'conv-1');

      voiceClient.sendAudioChunk(Uint8List.fromList([1, 2, 3, 4]));
      voiceClient.commitAudio();
      voiceClient.updateConfig(voiceId: 'af_bella', ttsSpeed: 1.1);
      voiceClient.ping();

      expect(fakeWs.sentFrames[1]['type'], 'audio.chunk');
      expect(fakeWs.sentFrames[2]['type'], 'audio.commit');
      expect(fakeWs.sentFrames[3]['type'], 'config.update');
      expect(fakeWs.sentFrames[3]['voice_id'], 'af_bella');
      expect(fakeWs.sentFrames[4]['type'], 'ping');

      fakeWs.pushServerFrame({
        'type': 'llm.delta',
        'voice_session_id': 'vs1',
        'turn_id': 1,
        'token': 'Hello ',
      });
      fakeWs.pushServerFrame({
        'type': 'tts.audio.chunk',
        'voice_session_id': 'vs1',
        'turn_id': 1,
        'seq': 0,
        'wav_base64': 'AAAA',
      });
      await Future<void>.delayed(Duration.zero);

      expect(received.map((e) => e.type), ['llm.delta', 'tts.audio.chunk']);

      // Manual barge-in suppresses any delayed turn 1 audio chunks/deltas.
      voiceClient.sendBargeIn(reason: 'user_tap');
      fakeWs.pushServerFrame({
        'type': 'tts.audio.chunk',
        'voice_session_id': 'vs1',
        'turn_id': 1,
        'seq': 1,
        'wav_base64': 'BBBB',
      });
      fakeWs.pushServerFrame({
        'type': 'turn.cancelled',
        'voice_session_id': 'vs1',
        'turn_id': 1,
        'reason': 'user_tap',
      });
      // Turn 2 proceeds cleanly.
      fakeWs.pushServerFrame({
        'type': 'llm.delta',
        'voice_session_id': 'vs1',
        'turn_id': 2,
        'token': 'Yes?',
      });
      await Future<void>.delayed(Duration.zero);

      expect(
        received.map((e) => '${e.type}:${e.turnId}').toList(),
        [
          'llm.delta:1',
          'tts.audio.chunk:1',
          'turn.cancelled:1',
          'llm.delta:2',
        ],
      );

      voiceClient.stopSession();
      expect(fakeWs.sentFrames.last['type'], 'session.stop');

      await sub.cancel();
      await voiceClient.dispose();
      await fakeWs.close();
    });
  });
}
