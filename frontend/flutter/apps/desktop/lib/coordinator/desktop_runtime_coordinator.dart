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
  String baseUrl;
  final WindowsRuntimeProcessSupervisor _supervisor;
  CompanionClient _client;
  final File? _customLockFile;
  final String? _customExecutablePath;
  final String? _customLogFilePath;
  final String? _customWorkingDirectory;
  final Map<String, String>? _customEnvironment;

  late Uri _uri;
  late SupervisionMode _supervisionMode;
  late String _host;
  late int _port;

  final StreamController<RuntimeProcessState> _stateController =
      StreamController<RuntimeProcessState>.broadcast();

  int _activeGeneration = 0;
  bool _isDisposed = false;

  RuntimeProcessState _currentState;
  RuntimeLockfileData? _activeRuntimeInfo;

  DesktopRuntimeCoordinator({
    required this.baseUrl,
    WindowsRuntimeProcessSupervisor? supervisor,
    CompanionClient? client,
    CompanionClient Function(String baseUrl, CredentialStore? credentialStore)? clientFactory,
    CredentialStore? credentialStore,
    File? customLockFile,
    String? customExecutablePath,
    String? customLogFilePath,
    String? customWorkingDirectory,
    Map<String, String>? customEnvironment,
  })  : _supervisor = supervisor ?? WindowsRuntimeProcessSupervisor(),
        _clientFactory = clientFactory ?? (client != null ? ((url, store) => client) : null),
        _client = client ??
            (clientFactory != null
                ? clientFactory(baseUrl, credentialStore)
                : CompanionClient(
                    baseUrl: baseUrl,
                    credentialStore: credentialStore,
                  )),
        _customLockFile = customLockFile,
        _customExecutablePath = customExecutablePath,
        _customLogFilePath = customLogFilePath,
        _customWorkingDirectory = customWorkingDirectory,
        _customEnvironment = customEnvironment,
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

  final CompanionClient Function(String baseUrl, CredentialStore? credentialStore)? _clientFactory;

  void updateConfiguration({
    required String newBaseUrl,
    CompanionClient? newClient,
    CredentialStore? credentialStore,
  }) {
    _activeGeneration++;
    final currentGen = _activeGeneration;
    baseUrl = newBaseUrl;
    _uri = Uri.parse(newBaseUrl);
    _host = _uri.host.isNotEmpty ? _uri.host : '127.0.0.1';
    _port = _uri.port != 0 ? _uri.port : 8000;
    _supervisionMode = _isLoopbackHost(_host)
        ? SupervisionMode.localLoopback
        : SupervisionMode.remoteHost;
    if (_supervisionMode == SupervisionMode.remoteHost) {
      _activeRuntimeInfo = null;
    }
    if (newClient != null) {
      _client = newClient;
    } else if (_clientFactory != null) {
      _client = _clientFactory(newBaseUrl, credentialStore);
    } else {
      _client = CompanionClient(
        baseUrl: newBaseUrl,
        credentialStore: credentialStore,
      );
    }
    _updateState(
      RuntimeProcessState(
        supervisionMode: _supervisionMode,
        status: RuntimeStatus.dormant,
        pid: _supervisionMode == SupervisionMode.localLoopback ? _activeRuntimeInfo?.pid : null,
        port: _port,
      ),
      generation: currentGen,
    );
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
    final envLock = Platform.environment['COMPANION_LOCK_FILE'];
    if (envLock != null && envLock.trim().isNotEmpty) {
      return File(envLock.trim());
    }
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) {
      return File('runtime.lock');
    }
    return File('$localAppData\\AI Companion\\runtime.lock');
  }

  String _resolveLogFilePath() {
    final custom = _customLogFilePath;
    if (custom != null) return custom;
    final envLog = Platform.environment['COMPANION_LOG_FILE'];
    if (envLog != null && envLog.trim().isNotEmpty) {
      return envLog.trim();
    }
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

    final searchBases = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];

    final relativeSubPaths = [
      Platform.isWindows
          ? r'backend\.venv\Scripts\python.exe'
          : 'backend/.venv/bin/python',
      Platform.isWindows
          ? r'.venv\Scripts\python.exe'
          : '.venv/bin/python',
    ];

    for (final base in searchBases) {
      Directory current = base.absolute;
      for (var i = 0; i < 5; i++) {
        for (final sub in relativeSubPaths) {
          final candidate = File('${current.path}${Platform.pathSeparator}$sub');
          if (candidate.existsSync()) {
            return candidate.path;
          }
        }
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    }

    return Platform.isWindows
        ? r'backend\.venv\Scripts\python.exe'
        : 'backend/.venv/bin/python';
  }

  String _resolveWorkingDirectory() {
    final custom = _customWorkingDirectory;
    if (custom != null) return custom;
    final envWd = Platform.environment['COMPANION_RUNTIME_DIR'];
    if (envWd != null && envWd.isNotEmpty) return envWd;

    final searchBases = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];

    for (final base in searchBases) {
      Directory current = base.absolute;
      for (var i = 0; i < 5; i++) {
        final mainPy = File('${current.path}${Platform.pathSeparator}backend${Platform.pathSeparator}app${Platform.pathSeparator}main.py');
        if (mainPy.existsSync()) {
          return File('${current.path}${Platform.pathSeparator}backend').path;
        }
        final directMainPy = File('${current.path}${Platform.pathSeparator}app${Platform.pathSeparator}main.py');
        if (directMainPy.existsSync()) {
          return current.path;
        }
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    }

    return Directory.current.path;
  }

  RuntimeProcessState _updateState(RuntimeProcessState newState, {int? generation}) {
    if (_isDisposed || (generation != null && generation != _activeGeneration)) {
      return _currentState;
    }
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
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
    final generation = _activeGeneration;
    final stopwatch = Stopwatch()..start();
    if (_supervisionMode == SupervisionMode.remoteHost) {
      return _ensureRemoteHostReady(
        timeout: timeout,
        generation: generation,
        stopwatch: stopwatch,
      );
    }
    return _ensureLocalLoopbackReady(
      timeout: timeout,
      generation: generation,
      stopwatch: stopwatch,
    );
  }

  Future<RuntimeProcessState> _ensureRemoteHostReady({
    required Duration timeout,
    required int generation,
    required Stopwatch stopwatch,
  }) async {
    _activeRuntimeInfo = null;

    Duration remainingTime() {
      final r = timeout - stopwatch.elapsed;
      return r.isNegative ? Duration.zero : r;
    }

    _updateState(
      RuntimeProcessState(
        supervisionMode: SupervisionMode.remoteHost,
        status: RuntimeStatus.launching,
        port: _port,
      ),
      generation: generation,
    );

    if (remainingTime() <= Duration.zero) {
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.remoteHost,
          status: RuntimeStatus.startupTimeout,
          port: _port,
          diagnosticMessage: 'Timeout before probing remote host',
        ),
        generation: generation,
      );
    }

    final healthTimeout = remainingTime() < const Duration(seconds: 3)
        ? remainingTime()
        : const Duration(seconds: 3);
    try {
      await _client.getHealth(timeout: healthTimeout);
    } catch (e) {
      if (generation != _activeGeneration || _isDisposed) return _currentState;
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.remoteHost,
          status: RuntimeStatus.unreachable,
          port: _port,
          diagnosticMessage: 'Remote host unreachable: $e',
        ),
        generation: generation,
      );
    }

    if (generation != _activeGeneration || _isDisposed) return _currentState;

    if (remainingTime() <= Duration.zero) {
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.remoteHost,
          status: RuntimeStatus.startupTimeout,
          port: _port,
          diagnosticMessage: 'Timeout before authenticating remote host',
        ),
        generation: generation,
      );
    }

    final authTimeout = remainingTime() < const Duration(seconds: 5)
        ? remainingTime()
        : const Duration(seconds: 5);

    try {
      await _client.verifyAuth(timeout: authTimeout).timeout(authTimeout);
      if (generation != _activeGeneration || _isDisposed) return _currentState;
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.remoteHost,
          status: RuntimeStatus.readyAndAuthenticated,
          port: _port,
        ),
        generation: generation,
      );
    } on TimeoutException {
      if (generation != _activeGeneration || _isDisposed) return _currentState;
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.remoteHost,
          status: RuntimeStatus.startupTimeout,
          port: _port,
          diagnosticMessage: 'Remote host authentication verification timed out',
        ),
        generation: generation,
      );
    } on CompanionApiException catch (e) {
      if (generation != _activeGeneration || _isDisposed) return _currentState;
      if (e.statusCode == 401) {
        return _updateState(
          RuntimeProcessState(
            supervisionMode: SupervisionMode.remoteHost,
            status: RuntimeStatus.reachableUnauthenticated,
            port: _port,
            diagnosticMessage: 'Remote host authentication failed: ${e.message}',
          ),
          generation: generation,
        );
      }
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.remoteHost,
          status: e.statusCode == 408 ? RuntimeStatus.startupTimeout : RuntimeStatus.unreachable,
          port: _port,
          diagnosticMessage: 'Remote host verification error: ${e.message}',
        ),
        generation: generation,
      );
    } catch (e) {
      if (generation != _activeGeneration || _isDisposed) return _currentState;
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.remoteHost,
          status: RuntimeStatus.unreachable,
          port: _port,
          diagnosticMessage: 'Remote host unexpected error: $e',
        ),
        generation: generation,
      );
    }
  }

  Future<RuntimeProcessState> _ensureLocalLoopbackReady({
    required Duration timeout,
    required int generation,
    required Stopwatch stopwatch,
  }) async {
    Duration remainingTime() {
      final r = timeout - stopwatch.elapsed;
      return r.isNegative ? Duration.zero : r;
    }

    final targetHost = _host;
    final targetPort = _port;
    final targetLockFile = _lockFile;
    final targetExecutablePath = _resolveExecutablePath();
    final targetWorkingDirectory = _resolveWorkingDirectory();
    final targetLogFilePath = _resolveLogFilePath();

    if (!_isLoopbackHost(targetHost)) {
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.remoteHost,
          status: RuntimeStatus.unreachable,
          port: targetPort,
          diagnosticMessage: 'Cannot perform local loopback launch on non-loopback host $targetHost',
        ),
        generation: generation,
      );
    }

    // 1. Initial check: is port already listening?
    final initialRemaining = remainingTime();
    final initialHealthTimeout = initialRemaining < const Duration(seconds: 2)
        ? initialRemaining
        : const Duration(seconds: 2);
    final alreadyListening = await _supervisor.isPortListening(targetHost, targetPort, timeout: initialHealthTimeout);
    if (generation != _activeGeneration || _isDisposed) return _currentState;

    if (alreadyListening) {
      try {
        await _client.getHealth(timeout: initialHealthTimeout);
      } catch (e) {
        if (generation != _activeGeneration || _isDisposed) return _currentState;
        return _updateState(
          RuntimeProcessState(
            supervisionMode: SupervisionMode.localLoopback,
            status: RuntimeStatus.alienPortConflict,
            port: targetPort,
            diagnosticMessage: 'Port $targetPort responded with non-companion payload: $e',
          ),
          generation: generation,
        );
      }

      if (generation != _activeGeneration || _isDisposed) return _currentState;

      final desc = await _supervisor.readDescriptorDirect(targetLockFile);
      if (desc != null) _activeRuntimeInfo = desc;

      final authTimeout = remainingTime() < const Duration(seconds: 5)
          ? remainingTime()
          : const Duration(seconds: 5);
      try {
        await _client.verifyAuth(timeout: authTimeout).timeout(authTimeout);
        if (generation != _activeGeneration || _isDisposed) return _currentState;
        return _updateState(
          RuntimeProcessState(
            supervisionMode: SupervisionMode.localLoopback,
            status: RuntimeStatus.readyAndAuthenticated,
            pid: _activeRuntimeInfo?.pid,
            port: targetPort,
          ),
          generation: generation,
        );
      } on TimeoutException {
        if (generation != _activeGeneration || _isDisposed) return _currentState;
        return _updateState(
          RuntimeProcessState(
            supervisionMode: SupervisionMode.localLoopback,
            status: RuntimeStatus.startupTimeout,
            pid: _activeRuntimeInfo?.pid,
            port: targetPort,
            diagnosticMessage: 'Local runtime authentication verification timed out',
          ),
          generation: generation,
        );
      } on CompanionApiException catch (e) {
        if (generation != _activeGeneration || _isDisposed) return _currentState;
        if (e.statusCode == 401) {
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.reachableUnauthenticated,
              pid: _activeRuntimeInfo?.pid,
              port: targetPort,
              diagnosticMessage: 'Local runtime reachable but unauthenticated: ${e.message}',
            ),
            generation: generation,
          );
        }
        if (e.statusCode == 408) {
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.startupTimeout,
              pid: _activeRuntimeInfo?.pid,
              port: targetPort,
              diagnosticMessage: 'Local runtime authentication verification timed out',
            ),
            generation: generation,
          );
        }
        rethrow;
      }
    }

    // 2. Port not listening -> Enter single-instance launch sequence with lock
    _updateState(
      RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.launching,
        port: targetPort,
      ),
      generation: generation,
    );

    final lockWait = remainingTime() < const Duration(seconds: 5)
        ? remainingTime()
        : const Duration(seconds: 5);
    if (lockWait <= Duration.zero) {
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.localLoopback,
          status: RuntimeStatus.startupTimeout,
          port: targetPort,
          diagnosticMessage: 'Timeout before acquiring startup lock',
        ),
        generation: generation,
      );
    }

    final lockHandle = await _supervisor.acquireStartupLock(targetLockFile, timeout: lockWait);
    if (generation != _activeGeneration || _isDisposed) {
      if (lockHandle != null) await _supervisor.releaseStartupLock(lockHandle);
      return _currentState;
    }

    if (lockHandle == null) {
      return _updateState(
        RuntimeProcessState(
          supervisionMode: SupervisionMode.localLoopback,
          status: RuntimeStatus.startupTimeout,
          port: targetPort,
          diagnosticMessage: 'Timed out acquiring exclusive startup lock on ${targetLockFile.path}',
        ),
        generation: generation,
      );
    }

    try {
      // 3. Double-checked recheck under exclusive guard:
      final listeningNow = await _supervisor.isPortListening(targetHost, targetPort, timeout: const Duration(milliseconds: 500));
      if (generation != _activeGeneration || _isDisposed) return _currentState;

      if (listeningNow) {
        final recheckHealthTimeout = remainingTime() < const Duration(seconds: 2)
            ? remainingTime()
            : const Duration(seconds: 2);
        try {
          await _client.getHealth(timeout: recheckHealthTimeout);
        } catch (e) {
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.alienPortConflict,
              port: targetPort,
              diagnosticMessage: 'Port $targetPort is occupied by another process and did not respond with companion health: $e',
            ),
            generation: generation,
          );
        }

        final desc = await _supervisor.readDescriptorThroughHandle(lockHandle);
        if (desc != null) _activeRuntimeInfo = desc;

        final recheckAuthTimeout = remainingTime() < const Duration(seconds: 5)
            ? remainingTime()
            : const Duration(seconds: 5);
        try {
          await _client.verifyAuth(timeout: recheckAuthTimeout).timeout(recheckAuthTimeout);
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.readyAndAuthenticated,
              pid: _activeRuntimeInfo?.pid,
              port: targetPort,
            ),
            generation: generation,
          );
        } on TimeoutException {
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.startupTimeout,
              pid: _activeRuntimeInfo?.pid,
              port: targetPort,
              diagnosticMessage: 'Local runtime authentication verification timed out',
            ),
            generation: generation,
          );
        } on CompanionApiException catch (e) {
          if (e.statusCode == 401) {
            return _updateState(
              RuntimeProcessState(
                supervisionMode: SupervisionMode.localLoopback,
                status: RuntimeStatus.reachableUnauthenticated,
                pid: _activeRuntimeInfo?.pid,
                port: targetPort,
                diagnosticMessage: 'Local runtime reachable under lock but unauthenticated: ${e.message}',
              ),
              generation: generation,
            );
          }
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.unreachable,
              pid: _activeRuntimeInfo?.pid,
              port: targetPort,
              diagnosticMessage: 'Local runtime verification error: ${e.message}',
            ),
            generation: generation,
          );
        }
      }

      // 4. Validate existing descriptor and check process liveness
      final desc = await _supervisor.readDescriptorThroughHandle(lockHandle);
      if (desc != null && desc.pid > 0) {
        final isAlive = await _supervisor.isProcessActiveAndMatching(
          desc.pid,
          expectedExecutable: desc.executablePath,
        );
        if (generation != _activeGeneration || _isDisposed) return _currentState;
        if (isAlive) {
          _activeRuntimeInfo = desc;
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.processUnresponsive,
              pid: desc.pid,
              port: targetPort,
              diagnosticMessage: 'Runtime PID ${desc.pid} is alive in process table but unresponsive on port $targetPort',
            ),
            generation: generation,
          );
        }
      }

      // 5. Safe spawn: verify executable existence
      if (generation != _activeGeneration || _isDisposed) return _currentState;
      final exe = File(targetExecutablePath);
      if (!await exe.exists()) {
        return _updateState(
          RuntimeProcessState(
            supervisionMode: SupervisionMode.localLoopback,
            status: RuntimeStatus.executableNotFound,
            port: targetPort,
            diagnosticMessage: 'Runtime executable not found at ${exe.path}',
          ),
          generation: generation,
        );
      }

      if (generation != _activeGeneration || _isDisposed) return _currentState;

      if (remainingTime() <= Duration.zero) {
        return _updateState(
          RuntimeProcessState(
            supervisionMode: SupervisionMode.localLoopback,
            status: RuntimeStatus.startupTimeout,
            port: targetPort,
            diagnosticMessage: 'Timeout before spawning detached runtime',
          ),
          generation: generation,
        );
      }

      final spawnedPid = await _supervisor.spawnDetachedRuntime(
        executable: exe.path,
        args: ['-m', 'uvicorn', 'app.main:app', '--host', targetHost, '--port', '$targetPort'],
        workingDirectory: targetWorkingDirectory,
        logFilePath: targetLogFilePath,
        environment: _customEnvironment,
      );

      // Clean up test or in-flight process if attempt was superseded or coordinator disposed during spawn
      if (generation != _activeGeneration || _isDisposed) {
        await _supervisor.terminateSpawnedProcess(spawnedPid);
        return _currentState;
      }

      final newDesc = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: UuidUtils.generateV4(),
        pid: spawnedPid,
        port: targetPort,
        startedAt: DateTime.now().toUtc(),
        executablePath: exe.path,
      );
      await _supervisor.writeDescriptorThroughHandle(lockHandle, newDesc);
      _activeRuntimeInfo = newDesc;
    } finally {
      await _supervisor.releaseStartupLock(lockHandle);
    }

    if (generation != _activeGeneration || _isDisposed) return _currentState;

    // 6. Poll for readiness up to timeout
    var delayMs = 100;
    while (stopwatch.elapsed < timeout) {
      if (generation != _activeGeneration || _isDisposed) return _currentState;
      final remaining = remainingTime();
      if (remaining <= Duration.zero) break;

      final checkTimeout = remaining < const Duration(milliseconds: 500)
          ? remaining
          : const Duration(milliseconds: 500);

      try {
        final isListening = await _supervisor.isPortListening(targetHost, targetPort, timeout: checkTimeout);
        if (generation != _activeGeneration || _isDisposed) return _currentState;

        if (isListening) {
          await _client.getHealth(timeout: checkTimeout);
          if (generation != _activeGeneration || _isDisposed) return _currentState;

          final authTimeout = remainingTime() < const Duration(seconds: 3)
              ? remainingTime()
              : const Duration(seconds: 3);
          try {
            await _client.verifyAuth(timeout: authTimeout).timeout(authTimeout);
            if (generation != _activeGeneration || _isDisposed) return _currentState;
            return _updateState(
              RuntimeProcessState(
                supervisionMode: SupervisionMode.localLoopback,
                status: RuntimeStatus.readyAndAuthenticated,
                pid: _activeRuntimeInfo?.pid,
                port: targetPort,
              ),
              generation: generation,
            );
          } on TimeoutException {
            // Continues polling until overall timeout
          } on CompanionApiException catch (e) {
            if (generation != _activeGeneration || _isDisposed) return _currentState;
            if (e.statusCode == 401) {
              return _updateState(
                RuntimeProcessState(
                  supervisionMode: SupervisionMode.localLoopback,
                  status: RuntimeStatus.reachableUnauthenticated,
                  pid: _activeRuntimeInfo?.pid,
                  port: targetPort,
                  diagnosticMessage: 'Runtime reachable but token unauthenticated: ${e.message}',
                ),
                generation: generation,
              );
            }
          }
        }
      } catch (_) {}

      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (delayMs < 1000) {
        delayMs = (delayMs * 1.5).round();
      }
    }

    if (generation != _activeGeneration || _isDisposed) return _currentState;

    return _updateState(
      RuntimeProcessState(
        supervisionMode: SupervisionMode.localLoopback,
        status: RuntimeStatus.startupTimeout,
        pid: _activeRuntimeInfo?.pid,
        port: targetPort,
        diagnosticMessage: 'Runtime failed to become ready within ${timeout.inSeconds} seconds',
      ),
      generation: generation,
    );
  }

  void dispose() {
    _isDisposed = true;
    _activeGeneration++;
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }
}
