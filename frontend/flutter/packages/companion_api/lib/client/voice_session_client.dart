import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../auth/credential_store.dart';
import '../dto/voice_dto.dart';
import '../transport/ws_transport.dart';
import '../transport/ws_transport_io.dart';

/// Stateful typed client for full-duplex voice turns over `WS /api/v1/voice/ws`.
///
/// Tracks `turn_id` lifecycles across `stt.final`, `llm.delta`, `tts.audio.chunk`,
/// `tts.end`, and `turn.cancelled` so stale audio chunks or tokens from an
/// interrupted turn are immediately suppressed client-side upon barge-in.
class VoiceSessionClient {
  final CompanionWebSocketClient _wsClient;
  final bool _ownsWsClient;
  final StreamController<VoiceWsEvent> _eventsController =
      StreamController<VoiceWsEvent>.broadcast();

  StreamSubscription<dynamic>? _wsSubscription;
  final Set<int> _suppressedTurnIds = <int>{};
  int? _latestTurnId;

  VoiceSessionClient({CompanionWebSocketClient? wsClient})
      : _wsClient = wsClient ?? WebSocketChannelCompanionClient(),
        _ownsWsClient = wsClient == null {
    _wsSubscription = _wsClient.incomingStream.listen(
      _handleIncomingRaw,
      onError: (Object error, StackTrace stackTrace) {
        if (!_eventsController.isClosed) {
          _eventsController.addError(error, stackTrace);
        }
      },
    );
  }

  CompanionWebSocketState get state => _wsClient.state;

  Stream<VoiceWsEvent> get events => _eventsController.stream;

  int? get latestTurnId => _latestTurnId;

  Set<int> get suppressedTurnIds => Set.unmodifiable(_suppressedTurnIds);

  /// Derives the WebSocket URI (`http -> ws`, `https -> wss`) for `/api/v1/voice/ws`.
  static Uri buildWebSocketUri(Uri baseUri) {
    final normalizedBasePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri.replace(
      scheme: wsScheme,
      path: '$normalizedBasePath/api/v1/voice/ws',
    );
  }

  /// Connects to `/api/v1/voice/ws` and sends `session.start`.
  ///
  /// When [sessionStore] holds a session token, attaches both the `Authorization`
  /// HTTP upgrade header and fallback `session_token` inside `session.start`.
  Future<void> connect({
    required Uri baseUri,
    CredentialStore? sessionStore,
    String? conversationId,
    String? sessionToken,
  }) async {
    final resolvedToken = sessionToken ?? await sessionStore?.readToken();
    final wsUri = buildWebSocketUri(baseUri);
    final headers = <String, dynamic>{
      if (resolvedToken != null && resolvedToken.isNotEmpty)
        'Authorization': 'Bearer $resolvedToken',
    };
    await _wsClient.connect(
      wsUri,
      headers: headers.isEmpty ? null : headers,
    );
    startSession(
      conversationId: conversationId,
      sessionToken: resolvedToken,
    );
  }

  void startSession({String? conversationId, String? sessionToken}) {
    _sendFrame({
      'type': 'session.start',
      if (conversationId != null) 'conversation_id': conversationId,
      if (sessionToken != null && sessionToken.isNotEmpty)
        'session_token': sessionToken,
    });
  }

  void sendAudioChunk(Uint8List pcm16Bytes, {int sampleRate = 16000}) {
    _sendFrame({
      'type': 'audio.chunk',
      'pcm16_base64': base64Encode(pcm16Bytes),
      'sample_rate': sampleRate,
    });
  }

  void commitAudio() {
    _sendFrame({'type': 'audio.commit'});
  }

  /// Immediately marks the current turn cancelled locally and sends `barge_in`.
  void sendBargeIn({String? reason}) {
    final activeTurn = _latestTurnId;
    if (activeTurn != null) {
      _suppressedTurnIds.add(activeTurn);
    }
    _sendFrame({
      'type': 'barge_in',
      if (reason != null) 'reason': reason,
    });
  }

  void updateConfig({
    String? bargeInPolicy,
    String? vadSensitivity,
    String? voiceId,
    double? ttsSpeed,
    String? sttLanguage,
  }) {
    _sendFrame({
      'type': 'config.update',
      if (bargeInPolicy != null) 'barge_in_policy': bargeInPolicy,
      if (vadSensitivity != null) 'vad_sensitivity': vadSensitivity,
      if (voiceId != null) 'voice_id': voiceId,
      if (ttsSpeed != null) 'tts_speed': ttsSpeed,
      if (sttLanguage != null) 'stt_language': sttLanguage,
    });
  }

  void ping() {
    _sendFrame({'type': 'ping'});
  }

  void stopSession() {
    _sendFrame({'type': 'session.stop'});
  }

  Future<void> disconnect() async {
    _suppressedTurnIds.clear();
    _latestTurnId = null;
    await _wsClient.disconnect();
  }

  Future<void> dispose() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await disconnect();
    if (_ownsWsClient && _wsClient is WebSocketChannelCompanionClient) {
      await _wsClient.dispose();
    }
    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
  }

  void _sendFrame(Map<String, dynamic> payload) {
    _wsClient.send(jsonEncode(payload));
  }

  void _handleIncomingRaw(dynamic raw) {
    if (_eventsController.isClosed) return;
    final Map<String, dynamic> decoded;
    if (raw is String) {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return;
      decoded = Map<String, dynamic>.from(parsed);
    } else if (raw is Map) {
      decoded = Map<String, dynamic>.from(raw);
    } else {
      return;
    }

    final event = VoiceWsEvent.fromJson(decoded);
    final turnId = event.turnId;

    if (turnId != null && (_latestTurnId == null || turnId > _latestTurnId!)) {
      _latestTurnId = turnId;
    }

    if (event.type == 'turn.cancelled' && turnId != null) {
      _suppressedTurnIds.add(turnId);
      _eventsController.add(event);
      return;
    }

    if (event.type == 'vad.state' &&
        event.state == 'barge_in_triggered' &&
        turnId != null) {
      _suppressedTurnIds.add(turnId);
    }

    final isSuppressedOutput = turnId != null &&
        _suppressedTurnIds.contains(turnId) &&
        (event.type == 'tts.audio.chunk' ||
            event.type == 'tts.end' ||
            event.type == 'llm.delta');
    if (isSuppressedOutput) {
      return;
    }

    _eventsController.add(event);
  }
}
