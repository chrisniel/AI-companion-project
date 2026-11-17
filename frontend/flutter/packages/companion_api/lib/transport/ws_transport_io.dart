import 'dart:async';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_transport.dart';

typedef WebSocketChannelFactory = WebSocketChannel Function(
  Uri uri, {
  Map<String, dynamic>? headers,
});

/// Native IO [CompanionWebSocketClient] powered by `IOWebSocketChannel`.
///
/// Supports custom HTTP upgrade headers (e.g., `Authorization: Bearer ...`)
/// on Windows, macOS, Linux, Android, and iOS while refusing unencrypted
/// remote credentialed `ws://` connections to non-loopback hosts.
class WebSocketChannelCompanionClient implements CompanionWebSocketClient {
  final WebSocketChannelFactory _channelFactory;
  final StreamController<dynamic> _incomingController =
      StreamController<dynamic>.broadcast();

  CompanionWebSocketState _state = CompanionWebSocketState.disconnected;
  WebSocketChannel? _channel;
  // Cancelled in disconnect() / dispose().
  // ignore: cancel_subscriptions
  StreamSubscription<dynamic>? _subscription;

  WebSocketChannelCompanionClient({WebSocketChannelFactory? channelFactory})
      : _channelFactory = channelFactory ?? _defaultChannelFactory;

  static WebSocketChannel _defaultChannelFactory(
    Uri uri, {
    Map<String, dynamic>? headers,
  }) {
    return IOWebSocketChannel.connect(uri, headers: headers);
  }

  static bool _isLoopback(String host) {
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  @override
  CompanionWebSocketState get state => _state;

  @override
  Stream<dynamic> get incomingStream => _incomingController.stream;

  @override
  Future<void> connect(Uri uri, {Map<String, dynamic>? headers}) async {
    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      throw ArgumentError.value(
        uri.toString(),
        'uri',
        'WebSocket URL must use ws or wss scheme.',
      );
    }
    final hasAuthHeader = headers?.keys.any(
          (k) => k.toLowerCase() == 'authorization',
        ) ??
        false;
    if (hasAuthHeader && uri.scheme == 'ws' && !_isLoopback(uri.host)) {
      throw StateError(
        'Refusing to transmit session credentials over unencrypted ws:// to ${uri.host}. Use wss:// for remote connections.',
      );
    }

    if (_state != CompanionWebSocketState.disconnected) {
      await disconnect();
    }

    _state = CompanionWebSocketState.connecting;
    try {
      final channel = _channelFactory(uri, headers: headers);
      await channel.ready;
      _channel = channel;
      _state = CompanionWebSocketState.connected;
      // Cancelled cleanly in disconnect() / dispose().
      // ignore: cancel_subscriptions
      _subscription = channel.stream.listen(
        (event) {
          if (!_incomingController.isClosed) {
            _incomingController.add(event);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_incomingController.isClosed) {
            _incomingController.addError(error, stackTrace);
          }
        },
        onDone: () {
          _channel = null;
          _subscription = null;
          _state = CompanionWebSocketState.disconnected;
        },
      );
    } catch (_) {
      _channel = null;
      _subscription = null;
      _state = CompanionWebSocketState.disconnected;
      rethrow;
    }
  }

  @override
  void send(dynamic message) {
    final channel = _channel;
    if (channel == null || _state != CompanionWebSocketState.connected) {
      throw StateError('WebSocket is not connected.');
    }
    channel.sink.add(message);
  }

  @override
  Future<void> disconnect() async {
    if (_state == CompanionWebSocketState.disconnected) {
      return;
    }
    _state = CompanionWebSocketState.disconnecting;
    final sub = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    try {
      await sub?.cancel();
      await channel?.sink.close();
    } finally {
      _state = CompanionWebSocketState.disconnected;
    }
  }

  Future<void> dispose() async {
    await disconnect();
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
  }
}
