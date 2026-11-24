import 'dart:io';

import 'package:flutter/services.dart';

/// Raw candidate process record returned by fast native process inspection.
class RawDiscoveredProcessCandidate {
  const RawDiscoveredProcessCandidate({
    required this.pid,
    required this.executablePath,
    required this.commandLine,
    required this.creationDate,
  });

  final int pid;
  final String executablePath;
  final String commandLine;
  final String creationDate;
}

/// Result of a native OS process enumeration query before Dart provenance validation.
class NativeProcessDiscoveryBatch {
  const NativeProcessDiscoveryBatch({
    required this.needsFallback,
    this.candidates = const <RawDiscoveredProcessCandidate>[],
  });

  final bool needsFallback;
  final List<RawDiscoveredProcessCandidate> candidates;
}

/// Strictly read-only native OS process inspection interface for [WindowsRuntimeProcessSupervisor].
abstract class DesktopProcessInspector {
  /// Returns `true` if [pid] is alive and its executable matches [expectedExecutable],
  /// `false` if not alive or mismatched, or `null` if native inspection is unavailable
  /// and callers should fall back to `tasklist`.
  Future<bool?> isProcessAliveAndMatching({
    required int pid,
    required String expectedExecutable,
  });

  /// Enumerates candidate processes matching [targetExecutableBase] or requests
  /// PowerShell fallback (`needsFallback: true` / `null`).
  Future<NativeProcessDiscoveryBatch?> discoverCandidateProcesses({
    required String targetExecutableBase,
  });
}

/// Zero-plugin Win32 C++ implementation routed over `ai_companion/windows_shell`.
class WindowsProcessInspector implements DesktopProcessInspector {
  const WindowsProcessInspector();

  static const MethodChannel _channel =
      MethodChannel('ai_companion/windows_shell');

  @override
  Future<bool?> isProcessAliveAndMatching({
    required int pid,
    required String expectedExecutable,
  }) async {
    if (pid <= 0 ||
        !Platform.isWindows ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      return await _channel.invokeMethod<bool>('isProcessAliveAndMatching', {
        'pid': pid,
        'expectedExecutable': expectedExecutable,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<NativeProcessDiscoveryBatch?> discoverCandidateProcesses({
    required String targetExecutableBase,
  }) async {
    if (!Platform.isWindows || Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'discoverCandidateProcesses',
        {
          'targetExecutableBase': targetExecutableBase,
        },
      );
      if (raw == null) return null;
      if (raw['needsFallback'] == true) {
        return const NativeProcessDiscoveryBatch(needsFallback: true);
      }
      final rawCandidates = raw['candidates'];
      if (rawCandidates is! List) {
        return const NativeProcessDiscoveryBatch(needsFallback: true);
      }
      final parsed = <RawDiscoveredProcessCandidate>[];
      for (final item in rawCandidates) {
        if (item is! Map) {
          return const NativeProcessDiscoveryBatch(needsFallback: true);
        }
        final pid = int.tryParse('${item['pid']}');
        if (pid == null || pid <= 0) {
          return const NativeProcessDiscoveryBatch(needsFallback: true);
        }
        parsed.add(
          RawDiscoveredProcessCandidate(
            pid: pid,
            executablePath: (item['executablePath'] ?? '').toString(),
            commandLine: (item['commandLine'] ?? '').toString(),
            creationDate: (item['creationDate'] ?? '').toString(),
          ),
        );
      }
      return NativeProcessDiscoveryBatch(
        needsFallback: false,
        candidates: parsed,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
