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
}
