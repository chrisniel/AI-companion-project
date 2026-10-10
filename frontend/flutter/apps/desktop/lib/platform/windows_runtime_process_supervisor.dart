import 'dart:convert';
import 'dart:io';
import 'package:companion_core/companion_core.dart';
import 'process_launcher_adapter.dart';

/// Native Windows runtime process supervisor.
///
/// Manages kernel-level file locking (`RandomAccessFile.lock(FileLock.exclusive)`),
/// safe descriptor write-through, bounded port polling, detached background process
/// launching with rotating file logging, and non-destructive Windows process table
/// queries (`tasklist`). Never attempts destructive PID termination.
class WindowsRuntimeProcessSupervisor {
  final ProcessLauncherAdapter _launcher;

  WindowsRuntimeProcessSupervisor({
    ProcessLauncherAdapter launcher = const DefaultProcessLauncherAdapter(),
  }) : _launcher = launcher;

  /// Probes whether a TCP port is listening on [host].
  ///
  /// Bounded by [timeout] (default 500ms). Returns true if connect succeeds.
  Future<bool> isPortListening(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Acquires an exclusive kernel lock on [lockFile] without file truncation.
  ///
  /// Opens the file using [FileMode.append] so existing file content is not destroyed
  /// before acquiring the lock. Retries with exponential backoff until [timeout].
  /// Returns the locked [RandomAccessFile] handle, or null on timeout / error.
  Future<RandomAccessFile?> acquireStartupLock(
    File lockFile, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await lockFile.parent.create(recursive: true);
    RandomAccessFile? handle;
    try {
      handle = await lockFile.open(mode: FileMode.append);
    } catch (_) {
      return null;
    }

    final stopwatch = Stopwatch()..start();
    var delayMs = 25;

    while (true) {
      try {
        await handle.lock(FileLock.exclusive);
        return handle;
      } on FileSystemException {
        // Exclusive lock is held by another process
        if (stopwatch.elapsed >= timeout) {
          try {
            await handle.close();
          } catch (_) {}
          return null;
        }
        final remainingMs = timeout.inMilliseconds - stopwatch.elapsedMilliseconds;
        final sleepTime = delayMs < remainingMs ? delayMs : remainingMs;
        if (sleepTime <= 0) {
          try {
            await handle.close();
          } catch (_) {}
          return null;
        }
        await Future<void>.delayed(Duration(milliseconds: sleepTime));
        delayMs = (delayMs * 1.5).round();
        if (delayMs > 250) delayMs = 250;
      } catch (_) {
        try {
          await handle.close();
        } catch (_) {}
        return null;
      }
    }
  }

  /// Releases kernel lock and closes the handle.
  Future<void> releaseStartupLock(RandomAccessFile lockHandle) async {
    try {
      await lockHandle.unlock();
    } catch (_) {}
    try {
      await lockHandle.close();
    } catch (_) {}
  }

  /// Atomically writes [data] descriptor through the currently held [lockHandle].
  ///
  /// Resets position to 0, truncates to 0, writes JSON string, and flushes to disk.
  Future<void> writeDescriptorThroughHandle(
    RandomAccessFile lockHandle,
    RuntimeLockfileData data,
  ) async {
    await lockHandle.setPosition(0);
    await lockHandle.truncate(0);
    await lockHandle.writeString(data.toRawJson());
    await lockHandle.flush();
  }

  /// Reads [RuntimeLockfileData] descriptor through the currently held [lockHandle].
  Future<RuntimeLockfileData?> readDescriptorThroughHandle(
    RandomAccessFile lockHandle,
  ) async {
    try {
      await lockHandle.setPosition(0);
      final length = await lockHandle.length();
      if (length <= 0) return null;
      final bytes = await lockHandle.read(length);
      final content = utf8.decode(bytes).trim();
      if (content.isEmpty) return null;
      return RuntimeLockfileData.fromRawJson(content);
    } catch (_) {
      return null;
    }
  }

  /// Directly reads [RuntimeLockfileData] from [lockFile] without acquiring an exclusive lock.
  ///
  /// Returns null if file is missing, empty, or unparseable.
  Future<RuntimeLockfileData?> readDescriptorDirect(File lockFile) async {
    try {
      if (!await lockFile.exists()) return null;
      final content = (await lockFile.readAsString()).trim();
      if (content.isEmpty) return null;
      return RuntimeLockfileData.fromRawJson(content);
    } catch (_) {
      return null;
    }
  }

  /// Verifies whether [pid] is running and its executable image matches [expectedExecutable].
  ///
  /// Uses Windows `tasklist /FI "PID eq <pid>"` non-destructive query.
  /// Returns false on missing PID, non-matching image name, or non-zero exit code.
  /// Never executes `taskkill` or modifies process state.
  Future<bool> isProcessActiveAndMatching(
    int pid, {
    required String expectedExecutable,
  }) async {
    if (pid <= 0) return false;
    try {
      final result = await _launcher.run(
        'tasklist',
        ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH'],
        runInShell: false,
      );
      if (result.exitCode != 0) return false;
      final stdoutStr = result.stdout.toString().trim();
      if (stdoutStr.isEmpty || stdoutStr.contains('INFO: No tasks are running') || stdoutStr.contains('No tasks are running which match the specified criteria.')) {
        return false;
      }

      final lines = stdoutStr.split(RegExp(r'\r?\n'));
      final targetExeBase = expectedExecutable.split(RegExp(r'[\\/]')).last.toLowerCase();

      for (final line in lines) {
        if (!line.contains('"$pid"')) continue;
        final match = RegExp(r'^"([^"]+)"').firstMatch(line.trim());
        if (match != null) {
          final imageName = match.group(1)?.toLowerCase() ?? '';
          if (imageName == targetExeBase || imageName.startsWith(targetExeBase.replaceAll('.exe', ''))) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Spawns the local runtime in detached background mode (`ProcessStartMode.detached`).
  ///
  /// Configures `COMPANION_LOG_FILE` environment variable so Python writes directly
  /// to [logFilePath] with rotating file logging. Returns spawned process PID.
  /// Throws [FileSystemException] if [executable] is missing from disk.
  Future<int> spawnDetachedRuntime({
    required String executable,
    required List<String> args,
    required String workingDirectory,
    required String logFilePath,
    Map<String, String>? environment,
  }) async {
    final exeFile = File(executable);
    if (!await exeFile.exists()) {
      throw FileSystemException('Runtime executable not found', executable);
    }

    final logFile = File(logFilePath);
    await logFile.parent.create(recursive: true);

    final env = Map<String, String>.from(Platform.environment);
    if (environment != null) {
      env.addAll(environment);
    }
    env['COMPANION_LOG_FILE'] = logFilePath;
    env['PYTHONUNBUFFERED'] = '1';

    final process = await _launcher.start(
      executable,
      args,
      workingDirectory: workingDirectory,
      environment: env,
      includeParentEnvironment: true,
      runInShell: false,
      mode: ProcessStartMode.detached,
    );

    return process.pid;
  }

  /// Evaluates whether [commandLine] contains an exact argument matching `--port <port>`.
  ///
  /// Prevents false matches where [port] appears as a substring in another port number
  /// (e.g. searching for 8000 matching 80000 or 18000), a timeout, or a file path.
  static bool matchesExactPort(String commandLine, int port) {
    if (port <= 0 || commandLine.isEmpty) return false;
    final regex = RegExp(
      r'(?:^|\s)--port(?:\s+|=)["\x27]?(\d+)["\x27]?(?:\s|"|\x27|$)',
      caseSensitive: false,
    );
    final matches = regex.allMatches(commandLine);
    for (final match in matches) {
      final matchedStr = match.group(1);
      if (matchedStr != null && int.tryParse(matchedStr) == port) {
        return true;
      }
    }
    return false;
  }

  /// Verifies whether [actualPath] matches [expectedPath] on Windows filesystem.
  static bool isExecutablePathMatch(String actualPath, String expectedPath) {
    if (actualPath.isEmpty || expectedPath.isEmpty) return false;
    final normActual = File(actualPath).absolute.path.replaceAll('/', '\\').toLowerCase();
    final normExpected = File(expectedPath).absolute.path.replaceAll('/', '\\').toLowerCase();
    if (normActual == normExpected) return true;

    final expectedBase = expectedPath.split(RegExp(r'[\\/]')).last.toLowerCase();
    final actualBase = actualPath.split(RegExp(r'[\\/]')).last.toLowerCase();
    if (actualBase != expectedBase) return false;

    final expectedRel = expectedPath.replaceAll('/', '\\').toLowerCase();
    return normActual.endsWith(expectedRel);
  }

  /// Discovers and evaluates candidate runtime processes configured for [port].
  ///
  /// Uses a non-destructive Win32_Process query to inspect process table entries.
  /// Fails closed on ambiguity (multiple candidates or unverified provenance).
  Future<ProcessDiscoveryResult> discoverRuntimeProcesses({
    required int port,
    required String expectedExecutable,
  }) async {
    if (port <= 0) {
      return const ProcessDiscoveryResult(
        status: ProcessDiscoveryStatus.noProcess,
      );
    }

    try {
      final exeBase = expectedExecutable.split(RegExp(r'[\\/]')).last.toLowerCase();
      final exeNamePrefix = exeBase.replaceAll('.exe', '').replaceAll("'", "''");
      final filter = "Name LIKE '$exeNamePrefix%'";

      final result = await _launcher.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'Get-CimInstance Win32_Process -Filter "$filter" | '
              'Select-Object -Property ProcessId, ExecutablePath, CommandLine, @{Name=\x27CreationDate\x27;Expression={\$_.CreationDate.ToUniversalTime().ToString(\x27o\x27)}} | '
              'ConvertTo-Json',
        ],
        runInShell: false,
      );

      if (result.exitCode != 0) {
        return ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.inspectionUnavailable,
          diagnostic: 'Process inspection query exited with code ${result.exitCode}: ${result.stderr}',
        );
      }

      final jsonStr = result.stdout.toString().trim();
      final List<dynamic> rawList;
      if (jsonStr.isEmpty) {
        rawList = const [];
      } else if (jsonStr.startsWith('[')) {
        rawList = jsonDecode(jsonStr) as List<dynamic>;
      } else if (jsonStr.startsWith('{')) {
        rawList = [jsonDecode(jsonStr)];
      } else {
        rawList = const [];
      }

      final candidates = <DiscoveredProcessIdentity>[];
      for (final raw in rawList) {
        if (raw is! Map) continue;
        final candPid = int.tryParse('${raw['ProcessId']}') ?? 0;
        if (candPid <= 0 || candPid == pid) continue;

        final cmdLine = (raw['CommandLine'] ?? '').toString();
        if (!matchesExactPort(cmdLine, port)) {
          continue;
        }

        final execPath = (raw['ExecutablePath'] ?? '').toString();
        final creationDateStr = (raw['CreationDate'] ?? '').toString();
        final creationTime = DateTime.tryParse(creationDateStr);

        candidates.add(
          DiscoveredProcessIdentity(
            pid: candPid,
            executablePath: execPath,
            commandLine: cmdLine,
            creationTime: creationTime ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
      }

      if (candidates.isEmpty) {
        return const ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.noProcess,
        );
      }

      if (candidates.length > 1) {
        return ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.multipleCandidates,
          candidates: candidates,
          diagnostic: 'Found ${candidates.length} candidate processes configured for port $port',
        );
      }

      final candidate = candidates.first;

      // 1. Creation time must be genuinely present and valid
      if (candidate.creationTime.millisecondsSinceEpoch == 0) {
        return ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.unverifiedCandidate,
          candidates: candidates,
          diagnostic: 'Candidate PID ${candidate.pid} is missing valid OS creation-time evidence',
        );
      }

      // 2. Command line must contain companion application module
      if (!candidate.commandLine.contains('uvicorn') || !candidate.commandLine.contains('app.main:app')) {
        return ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.unverifiedCandidate,
          candidates: candidates,
          diagnostic: 'Candidate PID ${candidate.pid} is running foreign or non-companion application module',
        );
      }

      // 3. Executable path must match expected executable provenance
      if (!isExecutablePathMatch(candidate.executablePath, expectedExecutable)) {
        return ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.unverifiedCandidate,
          candidates: candidates,
          diagnostic: 'Candidate PID ${candidate.pid} executable (${candidate.executablePath}) does not match expected executable ($expectedExecutable)',
        );
      }

      return ProcessDiscoveryResult(
        status: ProcessDiscoveryStatus.verified,
        verifiedProcess: candidate,
        candidates: candidates,
      );
    } catch (e) {
      return ProcessDiscoveryResult(
        status: ProcessDiscoveryStatus.inspectionUnavailable,
        diagnostic: 'Exception during process inspection: $e',
      );
    }
  }

  /// Finds an active verified runtime process running on [port] and matching [expectedExecutable].
  ///
  /// Used to recover from crashes that occur between child spawn and descriptor recording.
  /// Uses a non-destructive Win32_Process query to inspect process command lines.
  /// Returns the verified PID if found, or null otherwise. Never modifies process state.
  Future<int?> findActiveRuntimeProcess({
    required int port,
    required String expectedExecutable,
  }) async {
    final result = await discoverRuntimeProcesses(
      port: port,
      expectedExecutable: expectedExecutable,
    );
    return result.status == ProcessDiscoveryStatus.verified ? result.verifiedProcess?.pid : null;
  }
}

/// Status of candidate process discovery on a target port.
enum ProcessDiscoveryStatus {
  /// Exactly one process matched all provenance criteria:
  /// - Exact executable path match
  /// - Command line contains app.main:app and uvicorn
  /// - Exact port match (--port <port>)
  /// - Genuine OS creation time obtained
  verified,

  /// No process was found configured for or running on the target port.
  noProcess,

  /// One or more candidate processes exist for the port, but fail provenance verification
  /// (foreign executable, foreign application module, or missing parameters).
  unverifiedCandidate,

  /// Multiple candidate processes were found matching the port (ambiguous ownership).
  multipleCandidates,

  /// OS process table inspection was unavailable, timed out, or threw an error.
  inspectionUnavailable,
}

/// Verified or candidate process discovered in the OS process table.
class DiscoveredProcessIdentity {
  final int pid;
  final String executablePath;
  final String commandLine;
  final DateTime creationTime;

  const DiscoveredProcessIdentity({
    required this.pid,
    required this.executablePath,
    required this.commandLine,
    required this.creationTime,
  });
}

/// Result of evaluating candidate processes for a target port.
class ProcessDiscoveryResult {
  final ProcessDiscoveryStatus status;
  final DiscoveredProcessIdentity? verifiedProcess;
  final List<DiscoveredProcessIdentity> candidates;
  final String? diagnostic;

  const ProcessDiscoveryResult({
    required this.status,
    this.verifiedProcess,
    this.candidates = const [],
    this.diagnostic,
  });
}
