import 'dart:async';
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

  /// Acquires an exclusive kernel lock on [lockFile], truncates it to 0 bytes,
  /// flushes, releases the lock, and deletes the file.
  Future<bool> clearRuntimeLockfileThroughHandle(
    File lockFile, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final handle = await acquireStartupLock(lockFile, timeout: timeout);
    if (handle == null) {
      return false;
    }
    try {
      await handle.setPosition(0);
      await handle.truncate(0);
      await handle.flush();
    } catch (_) {
      // Best-effort truncation before release
    } finally {
      await releaseStartupLock(handle);
    }
    try {
      if (await lockFile.exists()) {
        await lockFile.delete();
      }
    } catch (_) {}
    return true;
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
          if ((targetExeBase == 'python.exe' || targetExeBase == 'pythonw.exe') &&
              (imageName == 'python.exe' || imageName == 'pythonw.exe')) {
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

  /// Evaluates whether [commandLine] matches a companion runtime entrypoint.
  ///
  /// Verifies module (`app.runtime_server` or `uvicorn`) and target (`app.main:app`).
  /// When [expectedPort] is provided, verifies that `--port <port>` matches exactly.
  static bool isCompanionRuntimeCommandLine(
    String commandLine, {
    int? expectedPort,
  }) {
    if (commandLine.isEmpty) return false;
    final hasModule = (commandLine.contains('app.runtime_server') || commandLine.contains('uvicorn')) &&
        commandLine.contains('app.main:app');
    if (!hasModule) return false;
    if (expectedPort != null) {
      return matchesExactPort(commandLine, expectedPort);
    }
    return true;
  }

  /// Verifies whether [actualPath] matches [expectedPath] on Windows filesystem.
  static bool isExecutablePathMatch(String actualPath, String expectedPath) {
    if (actualPath.isEmpty || expectedPath.isEmpty) return false;
    final normActual = File(actualPath).absolute.path.replaceAll('/', '\\').toLowerCase();
    final normExpected = File(expectedPath).absolute.path.replaceAll('/', '\\').toLowerCase();
    if (normActual == normExpected) return true;

    final expectedBase = expectedPath.split(RegExp(r'[\\/]')).last.toLowerCase();
    final actualBase = actualPath.split(RegExp(r'[\\/]')).last.toLowerCase();

    // Sibling Python binaries (e.g. python.exe vs pythonw.exe) in the exact same directory
    final isPythonFamily = (actualBase == 'python.exe' || actualBase == 'pythonw.exe' || actualBase == 'python3.exe') &&
        (expectedBase == 'python.exe' || expectedBase == 'pythonw.exe' || expectedBase == 'python3.exe');
    if (isPythonFamily) {
      final actualDir = File(normActual).parent.path.toLowerCase();
      final expectedDir = File(normExpected).parent.path.toLowerCase();
      if (actualDir == expectedDir) return true;
    }

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
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (port <= 0) {
      return const ProcessDiscoveryResult(
        status: ProcessDiscoveryStatus.noProcess,
      );
    }

    try {
      final exeBase = expectedExecutable.split(RegExp(r'[\\/]')).last.toLowerCase();
      final String filter;
      if (exeBase == 'python.exe' || exeBase == 'pythonw.exe') {
        filter = "Name LIKE 'python%'";
      } else {
        final exeNamePrefix = exeBase.replaceAll('.exe', '').replaceAll("'", "''");
        filter = "Name LIKE '$exeNamePrefix%'";
      }

      final process = await _launcher.start(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '\$ErrorActionPreference = \x27Stop\x27; '
              'Get-CimInstance Win32_Process -Filter "$filter" -ErrorAction Stop | '
              'Select-Object -Property ProcessId, ExecutablePath, CommandLine, @{Name=\x27CreationDate\x27;Expression={if (\$_.CreationDate) { \$_.CreationDate.ToUniversalTime().ToString(\x27o\x27) } else { \x27\x27 }}} | '
              'ConvertTo-Json',
        ],
        runInShell: false,
      );

      final stdoutFuture = utf8.decoder.bind(process.stdout).join().catchError((_) => '');
      final stderrFuture = utf8.decoder.bind(process.stderr).join().catchError((_) => '');

      int exitCode;
      String stdoutStr = '';
      String stderrStr = '';
      try {
        final results = await Future.wait([
          process.exitCode,
          stdoutFuture,
          stderrFuture,
        ]).timeout(timeout);
        exitCode = results[0] as int;
        stdoutStr = results[1] as String;
        stderrStr = results[2] as String;
      } on TimeoutException {
        process.kill();
        return ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.inspectionUnavailable,
          diagnostic: 'Process inspection query timed out after ${timeout.inMilliseconds}ms',
        );
      }

      if (exitCode != 0) {
        return ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.inspectionUnavailable,
          diagnostic: 'Process inspection query exited with code $exitCode: $stderrStr',
        );
      }

      if (stderrStr.trim().isNotEmpty) {
        return ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.inspectionUnavailable,
          diagnostic: 'Process inspection query reported stderr error: ${stderrStr.trim()}',
        );
      }

      final jsonStr = stdoutStr.trim();
      final List<dynamic> rawList;
      if (jsonStr.isEmpty) {
        rawList = const [];
      } else if (jsonStr.startsWith('[') || jsonStr.startsWith('{')) {
        try {
          final decoded = jsonDecode(jsonStr);
          if (decoded is List) {
            rawList = decoded;
          } else if (decoded is Map) {
            rawList = [decoded];
          } else {
            return ProcessDiscoveryResult(
              status: ProcessDiscoveryStatus.inspectionUnavailable,
              diagnostic: 'Unexpected JSON payload type: ${decoded.runtimeType}',
            );
          }
        } on FormatException catch (e) {
          return ProcessDiscoveryResult(
            status: ProcessDiscoveryStatus.inspectionUnavailable,
            diagnostic: 'Malformed JSON output from process inspection query: $e',
          );
        }
      } else {
        return ProcessDiscoveryResult(
          status: ProcessDiscoveryStatus.inspectionUnavailable,
          diagnostic: 'Non-JSON output from process inspection query: $jsonStr',
        );
      }

      final candidates = <DiscoveredProcessIdentity>[];
      for (final raw in rawList) {
        if (raw is! Map) {
          return ProcessDiscoveryResult(
            status: ProcessDiscoveryStatus.inspectionUnavailable,
            diagnostic: 'Unexpected non-map entry in process list: ${raw.runtimeType}',
          );
        }

        // Validate Win32_Process schema: must contain ProcessId and expected properties
        if (!raw.containsKey('ProcessId') || raw['ProcessId'] == null) {
          return ProcessDiscoveryResult(
            status: ProcessDiscoveryStatus.inspectionUnavailable,
            diagnostic: 'Process inspection query output missing ProcessId field: $raw',
          );
        }

        final candPid = int.tryParse('${raw['ProcessId']}');
        if (candPid == null || candPid <= 0) {
          return ProcessDiscoveryResult(
            status: ProcessDiscoveryStatus.inspectionUnavailable,
            diagnostic: 'Process inspection query output contains invalid ProcessId: ${raw['ProcessId']}',
          );
        }

        if (!raw.containsKey('CommandLine') || !raw.containsKey('ExecutablePath')) {
          return ProcessDiscoveryResult(
            status: ProcessDiscoveryStatus.inspectionUnavailable,
            diagnostic: 'Process inspection query output missing required Win32_Process fields: $raw',
          );
        }

        if (candPid == pid) continue;

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
      if (!isCompanionRuntimeCommandLine(candidate.commandLine, expectedPort: port)) {
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
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final result = await discoverRuntimeProcesses(
      port: port,
      expectedExecutable: expectedExecutable,
      timeout: timeout,
    );
    return result.status == ProcessDiscoveryStatus.verified ? result.verifiedProcess?.pid : null;
  }

  /// Performs handle-bound, provenance-verified termination of a local runtime process.
  ///
  /// Fails closed if process identity, executable provenance, start time, or command line
  /// cannot be verified via the held process handle and Windows process table.
  /// When [managedByCore] is true and [managedLlmPid] is provided, also terminates
  /// the child inference server process if verified as a llama-server instance.
  Future<TerminationResult> terminateVerifiedRuntimeProcess({
    required RuntimeLockfileData expectedDescriptor,
    int? managedLlmPid,
    bool managedByCore = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final escapedExe = expectedDescriptor.executablePath.replaceAll("'", "''");
    final startedAtStr = expectedDescriptor.startedAt.toUtc().toIso8601String();
    final targetPid = expectedDescriptor.pid;
    final targetPort = expectedDescriptor.port;
    final managedPid = managedLlmPid ?? 0;
    final coreManaged = managedByCore ? '\$true' : '\$false';

    final script = '''
\$ErrorActionPreference = 'Stop'
\$targetPid = $targetPid
\$expectedExe = '$escapedExe'
\$expectedPort = $targetPort
\$startedAtStr = '$startedAtStr'
\$managedLlmPid = $managedPid
\$managedByCore = $coreManaged

try {
  \$proc = [System.Diagnostics.Process]::GetProcessById(\$targetPid)
} catch {
  [PSCustomObject]@{ status = 'alreadyExited'; childTerminated = \$false } | ConvertTo-Json -Compress
  exit 0
}

try {
  \$null = \$proc.Handle
  \$procStartTimeUtc = \$proc.StartTime.ToUniversalTime()
  \$expectedStartTimeUtc = [DateTime]::Parse(\$startedAtStr).ToUniversalTime()
  \$diffSec = [Math]::Abs((\$procStartTimeUtc - \$expectedStartTimeUtc).TotalSeconds)
  if (\$diffSec -gt 15) {
    [PSCustomObject]@{ status = 'provenanceMismatch'; childTerminated = \$false; diagnostic = "Process start time drift (\$diffSec s) exceeds 15s" } | ConvertTo-Json -Compress
    exit 0
  }

  \$cim = Get-CimInstance Win32_Process -Filter "ProcessId = \$targetPid" -ErrorAction Stop
  if (\$null -eq \$cim) {
    [PSCustomObject]@{ status = 'provenanceMismatch'; childTerminated = \$false; diagnostic = 'WMI query returned no process for targetPid' } | ConvertTo-Json -Compress
    exit 0
  }

  \$cmdLine = if (\$cim.CommandLine) { \$cim.CommandLine } else { '' }
  \$actualExe = if (\$cim.ExecutablePath) { \$cim.ExecutablePath } else { '' }

  \$normExpectedExe = [IO.Path]::GetFullPath(\$expectedExe).ToLowerInvariant()
  \$normActualExe = if (\$actualExe) { [IO.Path]::GetFullPath(\$actualExe).ToLowerInvariant() } else { '' }

  \$exeMatches = \$false
  if (\$normActualExe -eq \$normExpectedExe) {
    \$exeMatches = \$true
  } else {
    \$actBase = [IO.Path]::GetFileName(\$normActualExe)
    \$expBase = [IO.Path]::GetFileName(\$normExpectedExe)
    if ((\$actBase -in @('python.exe', 'pythonw.exe', 'python3.exe')) -and (\$expBase -in @('python.exe', 'pythonw.exe', 'python3.exe'))) {
      if ([IO.Path]::GetDirectoryName(\$normActualExe) -eq [IO.Path]::GetDirectoryName(\$normExpectedExe)) {
        \$exeMatches = \$true
      }
    }
  }

  if (-not \$exeMatches) {
    [PSCustomObject]@{ status = 'provenanceMismatch'; childTerminated = \$false; diagnostic = "Executable path mismatch: actual '\$actualExe' vs expected '\$expectedExe'" } | ConvertTo-Json -Compress
    exit 0
  }

  \$isCompanion = (\$cmdLine -match 'app\\.runtime_server' -or \$cmdLine -match 'uvicorn') -and (\$cmdLine -match 'app\\.main:app')
  \$portPattern = "(?:^|\\s)--port(?:\\s+|=)[`"']?" + \$expectedPort + "[`"']?(?:\\s|`"|'|\$)"
  \$portMatches = (\$cmdLine -match \$portPattern)

  if (-not \$isCompanion -or -not \$portMatches) {
    [PSCustomObject]@{ status = 'provenanceMismatch'; childTerminated = \$false; diagnostic = "CommandLine did not match companion runtime or port \${expectedPort}: \$cmdLine" } | ConvertTo-Json -Compress
    exit 0
  }

  \$childKilled = \$false
  \$childDiagnostic = ''
  \$childWasAlive = \$false
  \$childProc = \$null

  if (\$managedByCore -and \$managedLlmPid -gt 0) {
    try {
      \$childProc = [System.Diagnostics.Process]::GetProcessById(\$managedLlmPid)
      \$null = \$childProc.Handle
      \$childWasAlive = \$true
    } catch {
      \$childWasAlive = \$false
      \$childDiagnostic = "Child PID \$managedLlmPid already exited or not found"
    }

    if (\$childWasAlive -and (\$null -ne \$childProc)) {
      try {
        \$childProcStartTimeUtc = \$childProc.StartTime.ToUniversalTime()
        \$childCim = Get-CimInstance Win32_Process -Filter "ProcessId = \$managedLlmPid" -ErrorAction SilentlyContinue

        if (\$null -eq \$childCim) {
          \$childDiagnostic = "Child PID \${managedLlmPid}: CIM query returned no process"
        } else {
          \$childCimCreationUtc = if (\$childCim.CreationDate) { [DateTime]\$childCim.CreationDate } else { [DateTime]::MinValue }
          \$childTimeDiff = [Math]::Abs((\$childProcStartTimeUtc - \$childCimCreationUtc.ToUniversalTime()).TotalSeconds)
          \$handleMatchesCim = (\$childTimeDiff -le 3)

          # 1. Authoritative Parentage check: ParentProcessId must equal \$targetPid
          \$isChildOfRuntime = (\$childCim.ParentProcessId -eq \$targetPid)

          # 2. Executable provenance: exact executable name (llama-server.exe or llama-server)
          \$childExeName = if (\$childCim.Name) { [IO.Path]::GetFileName(\$childCim.Name).ToLowerInvariant() } else { '' }
          \$childExePath = if (\$childCim.ExecutablePath) { [IO.Path]::GetFileName(\$childCim.ExecutablePath).ToLowerInvariant() } else { '' }
          \$exeMatches = (\$childExeName -in @('llama-server.exe', 'llama-server')) -or (\$childExePath -in @('llama-server.exe', 'llama-server'))

          # 3. Creation time relationship: child must not predate parent runtime
          \$timeMatches = (\$childProcStartTimeUtc -ge \$procStartTimeUtc.AddSeconds(-2))

          # 4. Command-line inspection: must contain --port and (--models-dir or --model)
          \$childCmdLine = if (\$childCim.CommandLine) { \$childCim.CommandLine.ToLowerInvariant() } else { '' }
          \$cmdMatches = (\$childCmdLine -match '--port') -and ((\$childCmdLine -match '--models-dir') -or (\$childCmdLine -match '--model'))

          if (\$handleMatchesCim -and \$isChildOfRuntime -and \$exeMatches -and \$timeMatches -and \$cmdMatches) {
            \$childProc.Kill()
            \$null = \$childProc.WaitForExit(3000)
            \$childKilled = \$childProc.HasExited
            if (-not \$childKilled) {
              \$childDiagnostic = "Child PID \$managedLlmPid failed to exit within 3000ms after kill"
            }
          } else {
            \$childDiagnostic = "Child PID \$managedLlmPid failed provenance verification: HandleMatch=\$handleMatchesCim, ParentMatch=\$isChildOfRuntime, ExeMatch=\$exeMatches, TimeMatch=\$timeMatches, CmdMatch=\$cmdMatches"
          }
        }
      } catch {
        \$childDiagnostic = "Child verification error: \$(\$_.Exception.Message)"
      }
    }
  }

  \$proc.Kill()
  \$null = \$proc.WaitForExit(5000)

  if (\$managedByCore -and \$childWasAlive -and (-not \$childKilled)) {
    [PSCustomObject]@{ status = 'partialTermination'; childTerminated = \$false; diagnostic = "Parent terminated, but owned child router PID \$managedLlmPid could not be verified or terminated: \$childDiagnostic" } | ConvertTo-Json -Compress
  } else {
    [PSCustomObject]@{ status = 'terminated'; childTerminated = \$childKilled; diagnostic = \$childDiagnostic } | ConvertTo-Json -Compress
  }
} catch {
  [PSCustomObject]@{ status = 'inspectionUnavailable'; childTerminated = \$false; diagnostic = \$_.Exception.Message } | ConvertTo-Json -Compress
}
''';

    try {
      final process = await _launcher.start(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          script,
        ],
        runInShell: false,
      );

      final stdoutFuture = utf8.decoder.bind(process.stdout).join().catchError((_) => '');
      final stderrFuture = utf8.decoder.bind(process.stderr).join().catchError((_) => '');

      int exitCode;
      String stdoutStr = '';
      String stderrStr = '';
      try {
        final results = await Future.wait([
          process.exitCode,
          stdoutFuture,
          stderrFuture,
        ]).timeout(timeout);
        exitCode = results[0] as int;
        stdoutStr = results[1] as String;
        stderrStr = results[2] as String;
      } on TimeoutException {
        try {
          process.kill();
        } catch (_) {}
        return const TerminationResult(
          status: TerminationResultStatus.timeout,
          diagnostic: 'Termination timed out while waiting for PowerShell script',
        );
      }

      if (exitCode != 0) {
        return TerminationResult(
          status: TerminationResultStatus.inspectionUnavailable,
          diagnostic: 'Termination script failed with exit code $exitCode: $stderrStr',
        );
      }

      final jsonStr = stdoutStr.trim();
      if (jsonStr.isEmpty) {
        return const TerminationResult(
          status: TerminationResultStatus.inspectionUnavailable,
          diagnostic: 'Empty output from termination script',
        );
      }

      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        return TerminationResult(
          status: TerminationResultStatus.inspectionUnavailable,
          diagnostic: 'Unexpected JSON output structure: $decoded',
        );
      }

      final statusStr = decoded['status'] as String? ?? '';
      final childTerminated = decoded['childTerminated'] as bool? ?? false;
      final diagnostic = decoded['diagnostic'] as String?;

      switch (statusStr) {
        case 'terminated':
          return TerminationResult(
            status: TerminationResultStatus.terminated,
            childTerminated: childTerminated,
            diagnostic: diagnostic,
          );
        case 'partialTermination':
          return TerminationResult(
            status: TerminationResultStatus.partialTermination,
            childTerminated: childTerminated,
            diagnostic: diagnostic,
          );
        case 'alreadyExited':
          return TerminationResult(
            status: TerminationResultStatus.alreadyExited,
            childTerminated: childTerminated,
            diagnostic: diagnostic,
          );
        case 'provenanceMismatch':
          return TerminationResult(
            status: TerminationResultStatus.provenanceMismatch,
            childTerminated: childTerminated,
            diagnostic: diagnostic,
          );
        case 'timeout':
          return TerminationResult(
            status: TerminationResultStatus.timeout,
            childTerminated: childTerminated,
            diagnostic: diagnostic,
          );
        default:
          return TerminationResult(
            status: TerminationResultStatus.inspectionUnavailable,
            childTerminated: childTerminated,
            diagnostic: diagnostic ?? 'Unknown termination status: $statusStr',
          );
      }
    } catch (e) {
      return TerminationResult(
        status: TerminationResultStatus.inspectionUnavailable,
        diagnostic: 'Exception during process termination: $e',
      );
    }
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

/// Status of process termination attempt.
enum TerminationResultStatus {
  /// The process was verified and successfully terminated.
  terminated,

  /// The process was already dead / not found.
  alreadyExited,

  /// Process failed provenance verification (different executable, PID reuse, start time drift, etc.).
  provenanceMismatch,

  /// Process inspection or OS command failed / threw an exception.
  inspectionUnavailable,

  /// The termination attempt timed out.
  timeout,

  /// The parent process was terminated, but the Core-managed child process could not be verified or terminated.
  partialTermination,
}

/// Result of handle-bound process termination.
class TerminationResult {
  final TerminationResultStatus status;
  final String? diagnostic;
  final bool childTerminated;

  const TerminationResult({
    required this.status,
    this.diagnostic,
    this.childTerminated = false,
  });
}
