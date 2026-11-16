import 'package:meta/meta.dart';
import 'tools_dto.dart';

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

/// Emitted when the companion orchestrator intends to invoke a D9 typed tool.
@immutable
class SseToolIntentEvent extends SseEvent {
  final String toolName;
  final int? riskTier;
  final String? provenance;
  final String? targetSummary;

  const SseToolIntentEvent({
    required this.toolName,
    this.riskTier,
    this.provenance,
    this.targetSummary,
  });
}

/// Emitted after deterministic D9 policy evaluation and tool execution/denial.
@immutable
class SseToolResultEvent extends SseEvent {
  final String toolName;
  final String decision;
  final String outcomeStatus;
  final String summary;
  final List<WebSourceRefOut> sources;
  final String? confirmationId;

  const SseToolResultEvent({
    required this.toolName,
    required this.decision,
    required this.outcomeStatus,
    required this.summary,
    this.sources = const [],
    this.confirmationId,
  });
}

/// Emitted when a Risk 1/2 tool requires explicit user confirmation before execution.
@immutable
class SseToolConfirmationRequiredEvent extends SseEvent {
  final String toolName;
  final ToolConfirmationOut confirmation;

  const SseToolConfirmationRequiredEvent({
    required this.toolName,
    required this.confirmation,
  });
}
