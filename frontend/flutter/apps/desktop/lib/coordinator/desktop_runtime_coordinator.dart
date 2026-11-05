import 'dart:async';
import 'dart:io';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import '../platform/host_admin_secret_store.dart';
import '../platform/windows_runtime_process_supervisor.dart';

/// Four-outcome classification for runtime shutdown.
enum ShutdownOutcome {
  /// Clean exit within cooperative window, lock cleared, runtime stopped.
  gracefulSuccess,

  /// In-flight persistence or provider cleanup did not complete; runtime kept alive.
  incompleteCleanup,

  /// Runtime was completely unresponsive and fallback termination was unavailable or unverified.
  unresponsiveRuntime,

  /// Handle-bound OS fallback verified and terminated the runtime (emergency stop).
  emergencyTerminated,
}

/// Coordinates the lifecycle, single-instance startup, and connection state
/// of the Local AI Runtime on Windows.
///
/// Implements double-checked locking under exclusive file guard, orthogonal
/// supervision mode modeling (`localLoopback` vs `remoteHost`), decoupled health
/// and authentication verification, and non-destructive PID handling.
class DesktopRuntimeCoordinator {
  String baseUrl;
  final WindowsRuntimeProcessSupervisor _supervisor;
  final CredentialStore _hostAdminStore;
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
  Future<ShutdownOutcome>? _activeShutdownFuture;
  int? _lastKnownManagedLlmPid;
  bool _lastKnownManagedByCore = false;

  RuntimeProcessState _currentState;
  RuntimeLockfileData? _activeRuntimeInfo;

  DesktopRuntimeCoordinator({
    required this.baseUrl,
    WindowsRuntimeProcessSupervisor? supervisor,
    CompanionClient? client,
    CompanionClient Function(String baseUrl, CredentialStore? credentialStore)? clientFactory,
    CredentialStore? credentialStore,
    CredentialStore? hostAdminStore,
    File? customLockFile,
    String? customExecutablePath,
    String? customLogFilePath,
    String? customWorkingDirectory,
    Map<String, String>? customEnvironment,
  })  : _supervisor = supervisor ?? WindowsRuntimeProcessSupervisor(),
        _clientFactory = clientFactory ?? (client != null ? ((url, store) => client) : null),
        _hostAdminStore = hostAdminStore ?? HostAdminSecretStore(),
        _client = client ??
            (clientFactory != null
                ? clientFactory(baseUrl, credentialStore)
                : CompanionClient(
                    baseUrl: baseUrl,
                    credentialStore: credentialStore,
                    hostAdminStore: hostAdminStore ?? HostAdminSecretStore(),
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
    final oldPort = _port;
    baseUrl = newBaseUrl;
    _uri = Uri.parse(newBaseUrl);
    _host = _uri.host.isNotEmpty ? _uri.host : '127.0.0.1';
    _port = _uri.port != 0 ? _uri.port : 8000;
    _supervisionMode = _isLoopbackHost(_host)
        ? SupervisionMode.localLoopback
        : SupervisionMode.remoteHost;
    if (_supervisionMode == SupervisionMode.remoteHost || _port != oldPort) {
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
        hostAdminStore: _hostAdminStore,
      );
    }
    _updateState(
      RuntimeProcessState(
        supervisionMode: _supervisionMode,
        status: RuntimeStatus.dormant,
        pid: (_supervisionMode == SupervisionMode.localLoopback && _activeRuntimeInfo?.port == _port)
            ? _activeRuntimeInfo?.pid
            : null,
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
    if (envExe != null && envExe.isNotEmpty) {
      if (Platform.isWindows && envExe.toLowerCase().endsWith(r'\python.exe')) {
        final siblingW = File(envExe.replaceAll(RegExp(r'python\.exe$', caseSensitive: false), 'pythonw.exe'));
        if (siblingW.existsSync()) return siblingW.path;
      }
      return envExe;
    }

    final searchBases = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];

    final relativeSubPaths = [
      if (Platform.isWindows) ...[
        r'backend\.venv\Scripts\pythonw.exe',
        r'.venv\Scripts\pythonw.exe',
      ] else ...[
        'backend/.venv/bin/python',
        '.venv/bin/python',
      ],
    ];

    String? expectedWindowlessPath;

    for (final base in searchBases) {
      Directory current = base.absolute;
      for (var i = 0; i < 5; i++) {
        for (final sub in relativeSubPaths) {
          final candidate = File('${current.path}${Platform.pathSeparator}$sub');
          if (candidate.existsSync()) {
            return candidate.path;
          }
        }
        if (Platform.isWindows && expectedWindowlessPath == null) {
          final consoleCandidate = File('${current.path}${Platform.pathSeparator}backend\\.venv\\Scripts\\python.exe');
          if (consoleCandidate.existsSync()) {
            expectedWindowlessPath = '${current.path}${Platform.pathSeparator}backend\\.venv\\Scripts\\pythonw.exe';
          }
        }
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    }

    if (expectedWindowlessPath != null) {
      return expectedWindowlessPath;
    }

    return Platform.isWindows
        ? r'backend\.venv\Scripts\pythonw.exe'
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
    RuntimeLockfileData? attemptVerifiedRuntime;

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
      if (desc != null && desc.port == targetPort) {
        attemptVerifiedRuntime = desc;
        _activeRuntimeInfo = desc;
      } else {
        _activeRuntimeInfo = null;
      }

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
            pid: attemptVerifiedRuntime?.pid ?? _activeRuntimeInfo?.pid,
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
            pid: attemptVerifiedRuntime?.pid ?? _activeRuntimeInfo?.pid,
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
              pid: attemptVerifiedRuntime?.pid ?? _activeRuntimeInfo?.pid,
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
              pid: attemptVerifiedRuntime?.pid ?? _activeRuntimeInfo?.pid,
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
        if (desc != null && desc.port == targetPort) {
          attemptVerifiedRuntime = desc;
          _activeRuntimeInfo = desc;
        } else {
          _activeRuntimeInfo = null;
        }

        final recheckAuthTimeout = remainingTime() < const Duration(seconds: 5)
            ? remainingTime()
            : const Duration(seconds: 5);
        try {
          await _client.verifyAuth(timeout: recheckAuthTimeout).timeout(recheckAuthTimeout);
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.readyAndAuthenticated,
              pid: attemptVerifiedRuntime?.pid ?? _activeRuntimeInfo?.pid,
              port: targetPort,
            ),
            generation: generation,
          );
        } on TimeoutException {
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.startupTimeout,
              pid: attemptVerifiedRuntime?.pid ?? _activeRuntimeInfo?.pid,
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
                pid: attemptVerifiedRuntime?.pid ?? _activeRuntimeInfo?.pid,
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
              pid: attemptVerifiedRuntime?.pid ?? _activeRuntimeInfo?.pid,
              port: targetPort,
              diagnosticMessage: 'Local runtime verification error: ${e.message}',
            ),
            generation: generation,
          );
        }
      }

      // 4. Validate existing descriptor and check process liveness
      final desc = await _supervisor.readDescriptorThroughHandle(lockHandle);
      if (desc != null && desc.port == targetPort && desc.pid > 0) {
        final isAlive = await _supervisor.isProcessActiveAndMatching(
          desc.pid,
          expectedExecutable: desc.executablePath,
        );
        if (generation != _activeGeneration || _isDisposed) return _currentState;
        if (isAlive) {
          attemptVerifiedRuntime = desc;
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
        // desc.pid is dead in process table. Stale descriptor.
        _activeRuntimeInfo = null;
      } else {
        _activeRuntimeInfo = null;
      }

      // 5. Evaluate OS process candidates on targetPort under exclusive lock
      final discovery = await _supervisor.discoverRuntimeProcesses(
        port: targetPort,
        expectedExecutable: targetExecutablePath,
      );
      if (generation != _activeGeneration || _isDisposed) return _currentState;

      switch (discovery.status) {
        case ProcessDiscoveryStatus.verified:
          final verified = discovery.verifiedProcess!;
          final recoveredDesc = RuntimeLockfileData(
            schemaVersion: 1,
            instanceId: UuidUtils.generateV4(),
            pid: verified.pid,
            port: targetPort,
            startedAt: verified.creationTime,
            executablePath: verified.executablePath,
          );
          await _supervisor.writeDescriptorThroughHandle(lockHandle, recoveredDesc);
          attemptVerifiedRuntime = recoveredDesc;
          _activeRuntimeInfo = recoveredDesc;
          break;

        case ProcessDiscoveryStatus.multipleCandidates:
        case ProcessDiscoveryStatus.unverifiedCandidate:
          _activeRuntimeInfo = null;
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.alienPortConflict,
              port: targetPort,
              diagnosticMessage: 'Port $targetPort has ambiguous or unverified candidate process: ${discovery.diagnostic}',
            ),
            generation: generation,
          );

        case ProcessDiscoveryStatus.inspectionUnavailable:
          _activeRuntimeInfo = null;
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.startupTimeout,
              port: targetPort,
              diagnosticMessage: 'OS process inspection unavailable on port $targetPort: ${discovery.diagnostic}',
            ),
            generation: generation,
          );

        case ProcessDiscoveryStatus.noProcess:
          attemptVerifiedRuntime = null;
          _activeRuntimeInfo = null;
          break;
      }

      // If active runtime was not verified in this attempt, proceed to safe spawn
      if (attemptVerifiedRuntime == null) {
        // 5. Safe spawn: verify executable existence
        if (generation != _activeGeneration || _isDisposed) return _currentState;
        final exe = File(targetExecutablePath);
        if (!await exe.exists()) {
          final siblingConsolePy = (Platform.isWindows && exe.path.toLowerCase().endsWith(r'\pythonw.exe'))
              ? File(exe.path.replaceAll(RegExp(r'pythonw\.exe$', caseSensitive: false), 'python.exe'))
              : null;
          final diagnostic = (siblingConsolePy != null && siblingConsolePy.existsSync())
              ? 'Windowless runtime executable pythonw.exe not found at ${exe.path}. Normal Windows startup requires pythonw.exe to prevent visible console windows. (python.exe exists at ${siblingConsolePy.path}, but automatic fallback is prohibited; set COMPANION_RUNTIME_EXE to explicitly override for development).'
              : 'Runtime executable not found at ${exe.path}';
          return _updateState(
            RuntimeProcessState(
              supervisionMode: SupervisionMode.localLoopback,
              status: RuntimeStatus.executableNotFound,
              port: targetPort,
              diagnosticMessage: diagnostic,
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
          args: ['-m', 'app.runtime_server', '--app', 'app.main:app', '--host', targetHost, '--port', '$targetPort', '--no-use-colors'],
          workingDirectory: targetWorkingDirectory,
          logFilePath: targetLogFilePath,
          environment: _customEnvironment,
        );

        final newDesc = RuntimeLockfileData(
          schemaVersion: 1,
          instanceId: UuidUtils.generateV4(),
          pid: spawnedPid,
          port: targetPort,
          startedAt: DateTime.now().toUtc(),
          executablePath: exe.path,
        );
        await _supervisor.writeDescriptorThroughHandle(lockHandle, newDesc);
        attemptVerifiedRuntime = newDesc;
        _activeRuntimeInfo = newDesc;

        // If attempt was superseded or coordinator disposed during spawn, do not destroy runtime.
        // Option A preserves runtime independence.
        if (generation != _activeGeneration || _isDisposed) {
          return _currentState;
        }
      }
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
                pid: attemptVerifiedRuntime.pid,
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
                  pid: attemptVerifiedRuntime.pid,
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
        pid: attemptVerifiedRuntime.pid,
        port: targetPort,
        diagnosticMessage: 'Runtime failed to become ready within ${timeout.inSeconds} seconds',
      ),
      generation: generation,
    );
  }

  /// Gracefully terminates the local runtime within a cooperative [timeout] window (default 25s).
  ///
  /// Never terminates remote hosts over the network.
  /// If the runtime completes cleanup cleanly, returns [ShutdownOutcome.gracefulSuccess].
  /// If in-flight work or provider lock times out, keeps runtime alive and returns [ShutdownOutcome.incompleteCleanup].
  /// If runtime is completely unresponsive, returns [ShutdownOutcome.unresponsiveRuntime].
  Future<ShutdownOutcome> shutdownLocalRuntime({
    Duration timeout = const Duration(seconds: 25),
  }) {
    if (_activeShutdownFuture != null) {
      return _activeShutdownFuture!;
    }
    final future = _executeShutdownLocalRuntime(timeout: timeout);
    _activeShutdownFuture = future;
    return future.whenComplete(() {
      if (_activeShutdownFuture == future) {
        _activeShutdownFuture = null;
      }
    });
  }

  Future<ShutdownOutcome> _executeShutdownLocalRuntime({
    Duration timeout = const Duration(seconds: 25),
  }) async {
    _activeGeneration++;
    final generation = _activeGeneration;

    // Remote host protection: never send /system/shutdown over the network
    if (_supervisionMode == SupervisionMode.remoteHost) {
      _updateState(
        _currentState.copyWith(status: RuntimeStatus.stopped),
        generation: generation,
      );
      return ShutdownOutcome.gracefulSuccess;
    }

    _updateState(
      _currentState.copyWith(status: RuntimeStatus.shuttingDown),
      generation: generation,
    );

    final targetHost = _host;
    final targetPort = _port;
    final targetLockFile = _lockFile;

    // 1. Initial check: is port listening?
    final initialListening = await _supervisor.isPortListening(
      targetHost,
      targetPort,
      timeout: const Duration(milliseconds: 500),
    );
    if (generation != _activeGeneration || _isDisposed) {
      return ShutdownOutcome.incompleteCleanup;
    }

    if (!initialListening) {
      // Check if process is still active despite closed/inactive port
      final descriptor = _activeRuntimeInfo ?? await _supervisor.readDescriptorDirect(targetLockFile);
      if (descriptor != null) {
        final isAlive = await _supervisor.isProcessActiveAndMatching(
          descriptor.pid,
          expectedExecutable: descriptor.executablePath,
        );
        if (isAlive) {
          // Process is still alive; do not clear lockfile or claim graceful success
          _updateState(
            _currentState.copyWith(
              status: RuntimeStatus.shutdownFailed,
              shutdownFailureReason: ShutdownFailureReason.incompleteCleanup,
              diagnosticMessage: 'Runtime port $targetPort is closed, but process PID ${descriptor.pid} remains active.',
            ),
            generation: generation,
          );
          return ShutdownOutcome.incompleteCleanup;
        }
      }
      await _supervisor.clearRuntimeLockfileThroughHandle(targetLockFile);
      _activeRuntimeInfo = null;
      _updateState(
        _currentState.copyWith(status: RuntimeStatus.stopped),
        generation: generation,
      );
      return ShutdownOutcome.gracefulSuccess;
    }

    // 2. Request cooperative shutdown via POST /api/v1/system/shutdown
    try {
      final response = await _client.shutdownSystem(
        reason: 'Desktop Exit Companion',
        drainTimeoutSeconds: 6.0,
        timeout: const Duration(seconds: 5),
      );
      if (response.managedLlmPid != null) {
        _lastKnownManagedLlmPid = response.managedLlmPid;
      }
      _lastKnownManagedByCore = response.managedByCore;
    } catch (e) {
      if ((e is CompanionApiException && (e.statusCode == 401 || e.statusCode == 403)) ||
          e.toString().toLowerCase().contains('401') ||
          e.toString().toLowerCase().contains('403') ||
          e.toString().toLowerCase().contains('unauthorized') ||
          e.toString().toLowerCase().contains('forbidden')) {
        // DO NOT silently kill runtime on auth error!
        _updateState(
          _currentState.copyWith(
            status: RuntimeStatus.shutdownFailed,
            shutdownFailureReason: ShutdownFailureReason.incompleteCleanup,
            diagnosticMessage: 'Shutdown rejected by host admin authorization: $e',
          ),
          generation: generation,
        );
        return ShutdownOutcome.incompleteCleanup;
      }

      // Check if runtime is responsive to status
      try {
        final status = await _client.getSystemStatus(
          timeout: const Duration(milliseconds: 500),
        );
        if (status.managedLlmPid != null) {
          _lastKnownManagedLlmPid = status.managedLlmPid;
        }
        _lastKnownManagedByCore = status.managedByCore;
      } catch (_) {
        // Status failed too: check if port stopped listening
        final isStillListening = await _supervisor.isPortListening(
          targetHost,
          targetPort,
          timeout: const Duration(milliseconds: 500),
        );
        if (!isStillListening) {
          final descriptor = _activeRuntimeInfo ?? await _supervisor.readDescriptorDirect(targetLockFile);
          if (descriptor != null) {
            final isAlive = await _supervisor.isProcessActiveAndMatching(
              descriptor.pid,
              expectedExecutable: descriptor.executablePath,
            );
            if (!isAlive) {
              await _supervisor.clearRuntimeLockfileThroughHandle(targetLockFile);
              _activeRuntimeInfo = null;
              _updateState(
                _currentState.copyWith(status: RuntimeStatus.stopped),
                generation: generation,
              );
              return ShutdownOutcome.gracefulSuccess;
            }
          }
        }
      }
    }

    // 3. Cooperative observation loop (up to timeout)
    final stopwatch = Stopwatch()..start();
    var delayMs = 100;

    while (stopwatch.elapsed < timeout) {
      if (generation != _activeGeneration || _isDisposed) {
        return ShutdownOutcome.incompleteCleanup;
      }

      // Check if port stopped listening
      final isListening = await _supervisor.isPortListening(
        targetHost,
        targetPort,
        timeout: const Duration(milliseconds: 300),
      );

      if (!isListening) {
        // Port closed! Verify descriptor/process table
        final descriptor = _activeRuntimeInfo ?? await _supervisor.readDescriptorDirect(targetLockFile);
        if (descriptor != null) {
          final isAlive = await _supervisor.isProcessActiveAndMatching(
            descriptor.pid,
            expectedExecutable: descriptor.executablePath,
          );
          if (isAlive) {
            // Process still exiting, wait and continue observation loop
            await Future<void>.delayed(const Duration(milliseconds: 150));
            continue;
          }
        }

        // Process has completely exited. Clean lockfile and complete graceful shutdown.
        await _supervisor.clearRuntimeLockfileThroughHandle(targetLockFile);
        _activeRuntimeInfo = null;
        _updateState(
          _currentState.copyWith(status: RuntimeStatus.stopped),
          generation: generation,
        );
        return ShutdownOutcome.gracefulSuccess;
      }

      // Port is still listening: query system status to inspect quiescence status
      try {
        final status = await _client.getSystemStatus(
          timeout: const Duration(milliseconds: 500),
        );
        if (status.managedLlmPid != null) {
          _lastKnownManagedLlmPid = status.managedLlmPid;
        }
        _lastKnownManagedByCore = status.managedByCore;

        final quiescence = status.shutdownQuiescenceStatus;
        if (quiescence != null && quiescence.startsWith('incomplete_')) {
          _updateState(
            _currentState.copyWith(
              status: RuntimeStatus.shutdownFailed,
              shutdownFailureReason: ShutdownFailureReason.incompleteCleanup,
              diagnosticMessage: 'Runtime reported $quiescence; runtime and database kept alive to prevent data loss.',
            ),
            generation: generation,
          );
          return ShutdownOutcome.incompleteCleanup;
        }
      } catch (_) {
        // Status query may fail or 503 while runtime is shutting down; this is normal
      }

      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (delayMs < 500) {
        delayMs = (delayMs * 1.5).round();
      }
    }

    // 4. Observation window expired!
    if (generation != _activeGeneration || _isDisposed) {
      return ShutdownOutcome.incompleteCleanup;
    }

    // Check if process is still active at window expiry
    final descriptorAtExpiry = _activeRuntimeInfo ?? await _supervisor.readDescriptorDirect(targetLockFile);
    if (descriptorAtExpiry != null) {
      final isAlive = await _supervisor.isProcessActiveAndMatching(
        descriptorAtExpiry.pid,
        expectedExecutable: descriptorAtExpiry.executablePath,
      );
      if (isAlive) {
        // Process still alive after timeout! Do NOT claim graceful success!
        bool isResponsive = false;
        try {
          final status = await _client.getSystemStatus(timeout: const Duration(milliseconds: 500));
          if (status.shuttingDown) {
            isResponsive = true;
          }
        } catch (_) {}

        if (isResponsive) {
          _updateState(
            _currentState.copyWith(
              status: RuntimeStatus.shutdownFailed,
              shutdownFailureReason: ShutdownFailureReason.incompleteCleanup,
              diagnosticMessage: 'Shutdown observation window expired while runtime was still performing cleanup.',
            ),
            generation: generation,
          );
          return ShutdownOutcome.incompleteCleanup;
        } else {
          // Runtime is unresponsive: do NOT silently OS-kill; let user confirm via the Unresponsive Recovery Dialog.
          _updateState(
            _currentState.copyWith(
              status: RuntimeStatus.shutdownFailed,
              shutdownFailureReason: ShutdownFailureReason.unresponsiveRuntime,
              diagnosticMessage: 'Shutdown observation window expired while runtime was unresponsive.',
            ),
            generation: generation,
          );
          return ShutdownOutcome.unresponsiveRuntime;
        }
      }
    }

    // Double-check if still listening
    final stillListeningAtExpiry = await _supervisor.isPortListening(
      targetHost,
      targetPort,
      timeout: const Duration(milliseconds: 300),
    );

    if (!stillListeningAtExpiry) {
      await _supervisor.clearRuntimeLockfileThroughHandle(targetLockFile);
      _activeRuntimeInfo = null;
      _updateState(
        _currentState.copyWith(status: RuntimeStatus.stopped),
        generation: generation,
      );
      return ShutdownOutcome.gracefulSuccess;
    }

    _updateState(
      _currentState.copyWith(
        status: RuntimeStatus.shutdownFailed,
        shutdownFailureReason: ShutdownFailureReason.unresponsiveRuntime,
        diagnosticMessage: 'Runtime port remains open and process did not exit within observation window.',
      ),
      generation: generation,
    );
    return ShutdownOutcome.unresponsiveRuntime;
  }

  Future<ShutdownOutcome> _fallbackEmergencyTermination({
    int? managedLlmPid,
    bool managedByCore = false,
    required int generation,
  }) async {
    RuntimeLockfileData? descriptor = _activeRuntimeInfo ?? await _supervisor.readDescriptorDirect(_lockFile);
    if (descriptor == null) {
      final activePid = await _supervisor.findActiveRuntimeProcess(
        port: _port,
        expectedExecutable: _resolveExecutablePath(),
      );
      if (activePid != null) {
        descriptor = RuntimeLockfileData(
          schemaVersion: 1,
          instanceId: UuidUtils.generateV4(),
          pid: activePid,
          port: _port,
          startedAt: DateTime.now().toUtc(),
          executablePath: _resolveExecutablePath(),
        );
      }
    }

    if (descriptor == null) {
      _updateState(
        _currentState.copyWith(
          status: RuntimeStatus.shutdownFailed,
          shutdownFailureReason: ShutdownFailureReason.unresponsiveRuntime,
          diagnosticMessage: 'Cannot perform emergency termination: no runtime descriptor found.',
        ),
        generation: generation,
      );
      return ShutdownOutcome.unresponsiveRuntime;
    }

    final result = await _supervisor.terminateVerifiedRuntimeProcess(
      expectedDescriptor: descriptor,
      managedLlmPid: managedLlmPid,
      managedByCore: managedByCore,
    );

    if (result.status == TerminationResultStatus.partialTermination) {
      _updateState(
        _currentState.copyWith(
          status: RuntimeStatus.shutdownFailed,
          shutdownFailureReason: ShutdownFailureReason.incompleteCleanup,
          diagnosticMessage: 'Handle-bound emergency termination partial: ${result.diagnostic ?? 'child router not terminated'}',
        ),
        generation: generation,
      );
      return ShutdownOutcome.incompleteCleanup;
    }

    if (result.status == TerminationResultStatus.terminated ||
        result.status == TerminationResultStatus.alreadyExited) {
      if (managedByCore && managedLlmPid != null && managedLlmPid > 0 && !result.childTerminated) {
        final childAlive = await _supervisor.isProcessActiveAndMatching(
          managedLlmPid,
          expectedExecutable: 'llama-server.exe',
        );
        if (childAlive) {
          _updateState(
            _currentState.copyWith(
              status: RuntimeStatus.shutdownFailed,
              shutdownFailureReason: ShutdownFailureReason.incompleteCleanup,
              diagnosticMessage: 'Runtime terminated, but owned router PID $managedLlmPid remains active.',
            ),
            generation: generation,
          );
          return ShutdownOutcome.incompleteCleanup;
        }
      }
      await _supervisor.clearRuntimeLockfileThroughHandle(_lockFile);
      _activeRuntimeInfo = null;
      _updateState(
        _currentState.copyWith(status: RuntimeStatus.stopped),
        generation: generation,
      );
      return ShutdownOutcome.emergencyTerminated;
    }

    if (result.status == TerminationResultStatus.partialTermination) {
      _updateState(
        _currentState.copyWith(
          status: RuntimeStatus.shutdownFailed,
          shutdownFailureReason: ShutdownFailureReason.incompleteCleanup,
          diagnosticMessage: 'Handle-bound emergency termination partial: ${result.diagnostic ?? 'child process cleanup failed'}',
        ),
        generation: generation,
      );
      return ShutdownOutcome.incompleteCleanup;
    }

    _updateState(
      _currentState.copyWith(
        status: RuntimeStatus.shutdownFailed,
        shutdownFailureReason: ShutdownFailureReason.unresponsiveRuntime,
        diagnosticMessage: 'Handle-bound emergency termination failed: ${result.diagnostic ?? result.status.name}',
      ),
      generation: generation,
    );
    return ShutdownOutcome.unresponsiveRuntime;
  }

  /// Explicit user-confirmed force termination of the local runtime.
  ///
  /// Invoked when the user chooses "Force Stop Local Runtime" from the
  /// Incomplete Shutdown Dialog.
  Future<ShutdownOutcome> forceEmergencyStopLocalRuntime() async {
    _activeGeneration++;
    final generation = _activeGeneration;

    return _fallbackEmergencyTermination(
      managedLlmPid: _lastKnownManagedLlmPid,
      managedByCore: _lastKnownManagedByCore,
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
