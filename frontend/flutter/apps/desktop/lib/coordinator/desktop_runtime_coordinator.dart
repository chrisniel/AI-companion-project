import 'dart:async';
import 'dart:io';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import '../platform/windows_runtime_process_supervisor.dart';

/// Coordinates the lifecycle, single-instance startup, and connection state
/// of the Local AI Runtime on Windows.
///
/// Implements double-checked locking under exclusive file guard, orthogonal
/// supervision mode modeling (`localLoopback` vs `remoteHost`), decoupled health
/// and authentication verification, and non-destructive PID handling.
class DesktopRuntimeCoordinator {
  final String baseUrl;
  final WindowsRuntimeProcessSupervisor _supervisor;
  final CompanionClient _client;
  final File? _customLockFile;
  final String? _customExecutablePath;
  final String? _customLogFilePath;
  final String? _customWorkingDirectory;

  late final Uri _uri;
  late final SupervisionMode _supervisionMode;
  late final String _host;
  late final int _port;

  final StreamController<RuntimeProcessState> _stateController =
      StreamController<RuntimeProcessState>.broadcast();

  RuntimeProcessState _currentState;
  RuntimeLockfileData? _activeRuntimeInfo;

  DesktopRuntimeCoordinator({
    required this.baseUrl,
    WindowsRuntimeProcessSupervisor? supervisor,
    CompanionClient? client,
    CredentialStore? credentialStore,
    File? customLockFile,
    String? customExecutablePath,
    String? customLogFilePath,
    String? customWorkingDirectory,
  })  : _supervisor = supervisor ?? WindowsRuntimeProcessSupervisor(),
        _client = client ??
            CompanionClient(
              baseUrl: baseUrl,
              credentialStore: credentialStore,
            ),
        _customLockFile = customLockFile,
        _customExecutablePath = customExecutablePath,
        _customLogFilePath = customLogFilePath,
        _customWorkingDirectory = customWorkingDirectory,
        _currentState = RuntimeProcessState(
          supervisionMode: _isLoopbackHost(baseUrl)
              ? SupervisionMode.localLoopback
              : SupervisionMode.remoteHost,
          status: RuntimeStatus.dormant,
          port: _parsePort(baseUrl),
        ) {
    _uri = Uri.parse(baseUrl);
    _host = _uri.host.isNotEmpty ? _uri.host : '127.0.0.1';
    _port = _uri.port != 0 ? _uri.port : 8000;
    _supervisionMode = _isLoopbackHost(_host)
        ? SupervisionMode.localLoopback
        : SupervisionMode.remoteHost;
  }

  static bool _isLoopbackHost(String hostOrUrl) {
    String host = hostOrUrl;
    if (hostOrUrl.contains('://')) {
      try {
        host = Uri.parse(hostOrUrl).host;
      } catch (_) {}
    }
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  static int _parsePort(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.port != 0 ? uri.port : 8000;
    } catch (_) {
      return 8000;
    }
  }

  Stream<RuntimeProcessState> get stateStream => _stateController.stream;
  RuntimeProcessState get currentState => _currentState;
  RuntimeLockfileData? get activeRuntimeInfo => _activeRuntimeInfo;
  bool get isLocalLoopback => _supervisionMode == SupervisionMode.localLoopback;

  File get _lockFile {
    final custom = _customLockFile;
    if (custom != null) return custom;
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) {
      return File('runtime.lock');
    }
    return File('$localAppData\\AI Companion\\runtime.lock');
  }

  String _resolveLogFilePath() {
    final custom = _customLogFilePath;
    if (custom != null) return custom;
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) {
      return 'runtime.log';
    }
    return '$localAppData\\AI Companion\\Logs\\runtime.log';
  }

  String _resolveExecutablePath() {
    final custom = _customExecutablePath;
    if (custom != null) return custom;
    final envExe = Platform.environment['COMPANION_RUNTIME_EXE'];
    if (envExe != null && envExe.isNotEmpty) return envExe;

    final candidates = [
      r'backend\.venv\Scripts\python.exe',
      r'..\..\..\backend\.venv\Scripts\python.exe',
      r'D:\OtherProjects\AI-companion-project\backend\.venv\Scripts\python.exe',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) {
        return File(c).absolute.path;
      }
    }
    return candidates.first;
  }

  String _resolveWorkingDirectory() {
    final custom = _customWorkingDirectory;
    if (custom != null) return custom;
    final candidates = [
      'backend',
      '..\\..\\..\\backend',
      r'D:\OtherProjects\AI-companion-project\backend',
    ];
    for (final c in candidates) {
      if (Directory(c).existsSync()) {
        return Directory(c).absolute.path;
      }
    }
    return Directory.current.path;
  }


  RuntimeProcessState _updateState(RuntimeProcessState newState) {
    _currentState = newState;
    _stateController.add(newState);
    return newState;
  }

  /// Ensures that the runtime is operational and ready to accept requests.
  ///
  /// For remote hosts: verifies reachability and authentication over HTTP.
  /// For local loopback: manages atomic single-instance startup, double-checked locking,
  /// and detached process supervision.
  Future<RuntimeProcessState> ensureRuntimeReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_supervisionMode == SupervisionMode.remoteHost) {
      return _ensureRemoteHostReady(timeout: timeout);
    }
    return _ensureLocalLoopbackReady(timeout: timeout);
  }

  Future<RuntimeProcessState> _ensureRemoteHostReady({
    required Duration timeout,
  }) async {
    _updateState(RuntimeProcessState(
      supervisionMode: SupervisionMode.remoteHost,
      status: RuntimeStatus.launching,
      port: _port,
    ));

    try {
      await _client.getHealth(timeout: const Duration(seconds: 3));
    } catch (e) {
      return _updateState(RuntimeProcessState(
        supervisionMode: SupervisionMode.remoteHost,
        status: RuntimeStatus.unreachable,
        port: _port,
        diagnosticMessage: 'Remote host unreachable: $e',
      ));
    }

    try {
      await _client.verifyAuth();
      return _updateState(RuntimeProcessState(
        supervisionMode: SupervisionMode.remoteHost,
        status: RuntimeStatus.readyAndAuthenticated,
        port: _port,
      ));
    } on CompanionApiException catch (e) {
      if (e.statusCode == 401) {
        return _updateState(RuntimeProcessState(
          supervisionMode: SupervisionMode.remoteHost,
          status: RuntimeStatus.reachableUnauthenticated,
          port: _port,
          diagnosticMessage: 'Remote host authentication failed: ${e.message}',
        ));
      }
      return _updateState(RuntimeProcessState(
        supervisionMode: SupervisionMode.remoteHost,
        status: RuntimeStatus.unreachable,
        port: _port,
        diagnosticMessage: 'Remote host verification error: ${e.message}',
      ));
    } catch (e) {
      return _updateState(RuntimeProcessState(
        supervisionMode: SupervisionMode.remoteHost,
        status: RuntimeStatus.unreachable,
        port: _port,
        diagnosticMessage: 'Remote host unexpected error: $e',
      ));
    }
  }

  Future<RuntimeProcessState> _ensureLocalLoopbackReady({
    required Duration timeout,
  }) async {
    // 1. Initial check: is port already listening?
    final alreadyListening = await _supervisor.isPortListening(_host, _port);
    if (alreadyListening) {
      try {
        await _client.getHealth(timeout: const Duration(seconds: 2));
      } catch (e) {
        return _updateState(RuntimeProcessState(
          supervisionMode: SupervisionMode.localLoopback,
          status: RuntimeStatus.alienPortConflict,
          port: _port,
          diagnosticMessage: 'Port $_port responded with non-companion payload: $e',
        ));
      }

      final desc = await _supervisor.readDescriptorDirect(_lockFile);
      if (desc != null) _activeRuntimeInfo = desc;

      try {
        await _client.verifyAuth();
        return _updateState(RuntimeProcessState(
          supervisionMode: SupervisionMode.localLoopback,
          status: RuntimeStatus.readyAndAuthenticated,
          pid: _activeRuntimeInfo?.pid,
          port: _port,
        ));
      } on CompanionApiException catch (e) {
        if (e.statusCode == 401) {
          return _updateState(RuntimeProcessState(
            supervisionMode: SupervisionMode.localLoopback,
            status: RuntimeStatus.reachableUnauthenticated,
            pid: _activeRuntimeInfo?.pid,
            port: _port,
            diagnosticMessage: 'Local runtime reachable but unauthenticated: ${e.message}',
          ));
        }
        rethrow;
      }
    }

    // 2. Port not listening -> Enter single-instance launch sequence with lock
    _updateState(RuntimeProcessState(
      supervisionMode: SupervisionMode.localLoopback,
      status: RuntimeStatus.launching,
      port: _port,
    ));

    final lockHandle = await _supervisor.acquireStartupLock(_lockFile, timeout: const Duration(seconds: 5));
    if (lockHandle == null) {
      return _updateState(RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.startupTimeout,
        port: _port,
        diagnosticMessage: 'Timed out acquiring exclusive startup lock on ${_lockFile.path}',
      ));
    }

    try {
      // 3. Double-checked recheck under exclusive guard:
      final listeningNow = await _supervisor.isPortListening(_host, _port);
      if (listeningNow) {
        try {
          await _client.getHealth(timeout: const Duration(seconds: 2));
          await _client.verifyAuth();
          final desc = await _supervisor.readDescriptorThroughHandle(lockHandle);
          if (desc != null) _activeRuntimeInfo = desc;
          return _updateState(RuntimeProcessState(
            supervisionMode: SupervisionMode.localLoopback,
            status: RuntimeStatus.readyAndAuthenticated,
            pid: _activeRuntimeInfo?.pid,
            port: _port,
          ));
        } catch (_) {}
      }

      // 4. Validate existing descriptor and check process liveness
      final desc = await _supervisor.readDescriptorThroughHandle(lockHandle);
      if (desc != null && desc.pid > 0) {
        final isAlive = await _supervisor.isProcessActiveAndMatching(
          desc.pid,
          expectedExecutable: desc.executablePath,
        );
        if (isAlive) {
          _activeRuntimeInfo = desc;
          return _updateState(RuntimeProcessState(
            supervisionMode: SupervisionMode.localLoopback,
            status: RuntimeStatus.processUnresponsive,
            pid: desc.pid,
            port: _port,
            diagnosticMessage: 'Runtime PID ${desc.pid} is alive in process table but unresponsive on port $_port',
          ));
        }
      }

      // 5. Safe spawn: verify executable existence
      final exe = File(_resolveExecutablePath());
      if (!await exe.exists()) {
        return _updateState(RuntimeProcessState(
          supervisionMode: SupervisionMode.localLoopback,
          status: RuntimeStatus.executableNotFound,
          port: _port,
          diagnosticMessage: 'Runtime executable not found at ${exe.path}',
        ));
      }

      final spawnedPid = await _supervisor.spawnDetachedRuntime(
        executable: exe.path,
        args: ['-m', 'uvicorn', 'app.main:app', '--host', _host, '--port', '$_port'],
        workingDirectory: _resolveWorkingDirectory(),
        logFilePath: _resolveLogFilePath(),
      );

      final newDesc = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: UuidUtils.generateV4(),
        pid: spawnedPid,
        port: _port,
        startedAt: DateTime.now().toUtc(),
        executablePath: exe.path,
      );
      await _supervisor.writeDescriptorThroughHandle(lockHandle, newDesc);
      _activeRuntimeInfo = newDesc;
    } finally {
      await _supervisor.releaseStartupLock(lockHandle);
    }

    // 6. Poll for readiness up to timeout
    final stopwatch = Stopwatch()..start();
    var delayMs = 100;

    while (stopwatch.elapsed < timeout) {
      try {
        final isListening = await _supervisor.isPortListening(_host, _port, timeout: const Duration(milliseconds: 200));
        if (isListening) {
          await _client.getHealth(timeout: const Duration(milliseconds: 500));
          try {
            await _client.verifyAuth();
            return _updateState(RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.readyAndAuthenticated,
              pid: _activeRuntimeInfo?.pid,
              port: _port,
            ));
          } on CompanionApiException catch (e) {
            if (e.statusCode == 401) {
              return _updateState(RuntimeProcessState(
                supervisionMode: SupervisionMode.localLoopback,
                status: RuntimeStatus.reachableUnauthenticated,
                pid: _activeRuntimeInfo?.pid,
                port: _port,
                diagnosticMessage: 'Runtime reachable but token unauthenticated: ${e.message}',
              ));
            }
          }
        }
      } catch (_) {}

      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (delayMs < 1000) {
        delayMs = (delayMs * 1.5).round();
      }
    }

    return _updateState(RuntimeProcessState(
      supervisionMode: SupervisionMode.localLoopback,
      status: RuntimeStatus.startupTimeout,
      pid: _activeRuntimeInfo?.pid,
      port: _port,
      diagnosticMessage: 'Runtime failed to become ready within ${timeout.inSeconds} seconds',
    ));
  }

  void dispose() {
    _stateController.close();
  }
}
