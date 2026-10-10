/// Connection states for the companion WebSocket transport.
enum CompanionWebSocketState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// Minimal platform-neutral WebSocket client contract per PC-CLIENT-004.
/// Voice pipelines and audio streams remain strictly deferred to M4.
abstract interface class CompanionWebSocketClient {
  CompanionWebSocketState get state;

  Stream<dynamic> get incomingStream;

  Future<void> connect(Uri uri, {Map<String, dynamic>? headers});

  void send(dynamic message);

  Future<void> disconnect();
}
