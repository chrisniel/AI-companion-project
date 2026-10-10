import 'package:meta/meta.dart';

/// Base class for all typed Server-Sent Events (SSE) from the Assistant stream.
@immutable
sealed class SseEvent {
  const SseEvent();
}

/// Token chunk yielded during live assistant text generation.
@immutable
class SseTokenEvent extends SseEvent {
  final String token;

  const SseTokenEvent(this.token);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SseTokenEvent && runtimeType == other.runtimeType && token == other.token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() => 'SseTokenEvent("$token")';
}

/// Terminal completion event indicating normal stream finish.
@immutable
class SseDoneEvent extends SseEvent {
  final String finishReason;

  const SseDoneEvent({this.finishReason = 'stop'});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SseDoneEvent &&
          runtimeType == other.runtimeType &&
          finishReason == other.finishReason;

  @override
  int get hashCode => finishReason.hashCode;

  @override
  String toString() => 'SseDoneEvent(finishReason: "$finishReason")';
}

/// Error event indicating mid-stream failure from assistant orchestrator.
@immutable
class SseErrorEvent extends SseEvent {
  final String code;
  final String message;

  const SseErrorEvent({
    required this.code,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SseErrorEvent &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'SseErrorEvent(code: "$code", message: "$message")';
}

/// Unrecognized or raw SSE event frame.
@immutable
class SseUnknownEvent extends SseEvent {
  final String rawData;

  const SseUnknownEvent(this.rawData);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SseUnknownEvent && runtimeType == other.runtimeType && rawData == other.rawData;

  @override
  int get hashCode => rawData.hashCode;

  @override
  String toString() => 'SseUnknownEvent("$rawData")';
}
