import 'package:meta/meta.dart';

/// Supervision topology for the Local AI Runtime.
enum SupervisionMode {
  /// Target is on loopback (127.0.0.1 or localhost); local supervisor is active.
  localLoopback,

  /// Target is on a remote host (LAN, Tailscale, or Cloudflare); local process management is bypassed.
  remoteHost,
}

/// Operational state machine for the Local AI Runtime.
enum RuntimeStatus {
  /// Runtime is not running and has not been launched in this session.
  dormant,

  /// Runtime is actively booting up; polling health endpoint.
  launching,

  /// Reachable, health 200, and verified via pairing token (ready for messaging).
  readyAndAuthenticated,

  /// Reachable on port, health 200, but pairing token is invalid or rejected (401).
  reachableUnauthenticated,

  /// Network target is unreachable or connection refused.
  unreachable,

  /// Port is occupied by a foreign or unresponsive process that fails health checks.
  alienPortConflict,

  /// Process was spawned or lock held, but failed to become healthy within timeout.
  startupTimeout,

  /// Process is alive in OS table but fails to respond to port requests.
  processUnresponsive,

  /// The configured Python or runtime executable does not exist on disk.
  executableNotFound,
}

/// Immutable snapshot representing the runtime process supervision state.
@immutable
class RuntimeProcessState {
  final SupervisionMode supervisionMode;
  final RuntimeStatus status;
  final int? pid;
  final int port;
  final String? diagnosticMessage;

  const RuntimeProcessState({
    required this.supervisionMode,
    required this.status,
    this.pid,
    this.port = 8000,
    this.diagnosticMessage,
  });

  /// Factory for default initial dormant state on loopback.
  factory RuntimeProcessState.initial({int port = 8000}) {
    return RuntimeProcessState(
      supervisionMode: SupervisionMode.localLoopback,
      status: RuntimeStatus.dormant,
      port: port,
    );
  }

  /// True when the runtime is ready and authenticated to receive inference turns.
  bool get isOperational => status == RuntimeStatus.readyAndAuthenticated;

  /// True when UI can send chat messages.
  bool get canSendMessages => isOperational;

  /// True when local OS process management is enabled (loopback).
  bool get isLocalSupervised => supervisionMode == SupervisionMode.localLoopback;

  RuntimeProcessState copyWith({
    SupervisionMode? supervisionMode,
    RuntimeStatus? status,
    int? pid,
    int? port,
    String? diagnosticMessage,
  }) {
    return RuntimeProcessState(
      supervisionMode: supervisionMode ?? this.supervisionMode,
      status: status ?? this.status,
      pid: pid ?? this.pid,
      port: port ?? this.port,
      diagnosticMessage: diagnosticMessage ?? this.diagnosticMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeProcessState &&
          runtimeType == other.runtimeType &&
          supervisionMode == other.supervisionMode &&
          status == other.status &&
          pid == other.pid &&
          port == other.port &&
          diagnosticMessage == other.diagnosticMessage;

  @override
  int get hashCode => Object.hash(
        supervisionMode,
        status,
        pid,
        port,
        diagnosticMessage,
      );

  @override
  String toString() {
    return 'RuntimeProcessState(mode: $supervisionMode, status: $status, pid: $pid, port: $port, diag: $diagnosticMessage)';
  }
}
