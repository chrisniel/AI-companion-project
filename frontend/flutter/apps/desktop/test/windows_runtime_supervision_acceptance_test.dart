import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_desktop/coordinator/desktop_runtime_coordinator.dart';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter_test/flutter_test.dart';

class AcceptanceSpawnRecord {
  final int pid;
  final int port;
  final String logPath;
  final DateTime spawnTime;
  final Process? processHandle;

  AcceptanceSpawnRecord({
    required this.pid,
    required this.port,
    required this.logPath,
    required this.spawnTime,
    this.processHandle,
  });
}

class AcceptanceTrackingSupervisor extends WindowsRuntimeProcessSupervisor {
  final List<AcceptanceSpawnRecord> spawnedRecords;

  AcceptanceTrackingSupervisor({required this.spawnedRecords});

  @override
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

    final spawnTime = DateTime.now().toUtc();
    final process = await Process.start(
      executable,
      args,
      workingDirectory: workingDirectory,
      environment: env,
      includeParentEnvironment: true,
      runInShell: false,
      mode: ProcessStartMode.detached,
    );

    int port = 0;
    final portIdx = args.indexOf('--port');
    if (portIdx != -1 && portIdx + 1 < args.length) {
      port = int.tryParse(args[portIdx + 1]) ?? 0;
    }
    spawnedRecords.add(
      AcceptanceSpawnRecord(
        pid: process.pid,
        port: port,
        logPath: logFilePath,
        spawnTime: spawnTime,
        processHandle: process,
      ),
    );
    return process.pid;
  }
}

void main() {
  group('Windows Runtime Supervision Acceptance (End-to-End)', () {
    late Directory tempRoot;
    late Directory dataDir;
    late File envFile;
    late File lockFile;
    late File logFile;
    late File settingsFile;
    late Map<String, String> testEnv;
    late int testPort;
    late String testToken;

    int? launchedPid;
    final List<AcceptanceSpawnRecord> trackedSpawnRecords = <AcceptanceSpawnRecord>[];

    setUpAll(() async {
      final envPort = Platform.environment['COMPANION_TEST_PORT'];
      testPort = envPort != null && envPort.isNotEmpty ? int.parse(envPort) : 8765;
      testToken = Platform.environment['COMPANION_API_KEY'] ?? 'companion_sec_test_verify_token_12345';

      final customTemp = Platform.environment['COMPANION_TEST_TEMP_ROOT'];
      if (customTemp != null && customTemp.isNotEmpty) {
        tempRoot = Directory(customTemp);
      } else {
        tempRoot = await Directory.systemTemp.createTemp('ai_companion_supervision_acceptance_');
      }

      dataDir = Directory('${tempRoot.path}\\Data');
      await dataDir.create(recursive: true);

      envFile = File('${tempRoot.path}\\.env');
      await envFile.writeAsString('COMPANION_API_KEY=$testToken\nPORT=$testPort\n', flush: true);

      lockFile = File('${tempRoot.path}\\runtime.lock');
      logFile = File('${tempRoot.path}\\Logs\\runtime.log');
      await logFile.parent.create(recursive: true);

      settingsFile = File('${tempRoot.path}\\client_settings.json');

      testEnv = {
        'COMPANION_API_KEY': testToken,
        'COMPANION_DATA_ROOT': dataDir.path,
        'COMPANION_ENV_FILE': envFile.path,
        'COMPANION_LOCK_FILE': lockFile.path,
        'COMPANION_LOG_FILE': logFile.path,
        'COMPANION_CLIENT_SETTINGS_FILE': settingsFile.path,
        'PYTHONUNBUFFERED': '1',
      };
    });

    tearDownAll(() async {
      final supervisor = WindowsRuntimeProcessSupervisor();
      for (final record in trackedSpawnRecords) {
        final pid = record.pid;
        if (pid <= 0) continue;

        try {
          // 1. Verify process is active and image name matches python.exe
          final isMatching = await supervisor.isProcessActiveAndMatching(
            pid,
            expectedExecutable: 'python.exe',
          );
          if (!isMatching) continue;

          // 2. Verify command line provenance and creation time via Win32_Process
          if (Platform.isWindows) {
            final procQuery = await Process.run(
              'powershell',
              [
                '-NoProfile',
                '-NonInteractive',
                '-Command',
                "Get-CimInstance Win32_Process -Filter 'ProcessId = $pid' | "
                    "Select-Object -Property ProcessId, CommandLine, @{Name='StartTime';Expression={\$_.CreationDate.ToUniversalTime().ToString('o')}} | "
                    'ConvertTo-Json',
              ],
              runInShell: false,
            );

            if (procQuery.exitCode == 0) {
              final jsonStr = procQuery.stdout.toString().trim();
              if (jsonStr.isNotEmpty && jsonStr.startsWith('{')) {
                final dynamic data = jsonDecode(jsonStr);
                final cmdLine = (data['CommandLine'] ?? '').toString();
                final startTimeStr = (data['StartTime'] ?? '').toString();

                // Fail-closed check: command line provenance MUST prove our uvicorn companion
                final hasExactPort = record.port == 0 ||
                    WindowsRuntimeProcessSupervisor.matchesExactPort(cmdLine, record.port);
                final isOurUvicorn = cmdLine.contains('uvicorn') &&
                    cmdLine.contains('app.main:app') &&
                    hasExactPort;
                if (!isOurUvicorn) continue;

                // Fail-closed check: valid creation time evidence is REQUIRED and MUST match recorded spawnTime
                if (startTimeStr.isEmpty) continue;
                final procStartTime = DateTime.tryParse(startTimeStr);
                if (procStartTime == null) continue;
                final diff = procStartTime.difference(record.spawnTime).abs();
                if (diff.inSeconds > 10) {
                  // PID reuse detected or creation time mismatch! Fail closed.
                  continue;
                }

                // 3. Terminate strictly verified test process using retained Process handle if available
                if (record.processHandle != null) {
                  record.processHandle!.kill();
                } else {
                  Process.killPid(pid);
                }
              }
            }
            // If Win32_Process provenance cannot be verified, fail closed: do NOT kill
          } else {
            // Non-Windows: verify command line via /proc or retained handle
            final procCmdLineFile = File('/proc/$pid/cmdline');
            if (procCmdLineFile.existsSync()) {
              final cmd = procCmdLineFile.readAsStringSync();
              if (cmd.contains('uvicorn') && cmd.contains('app.main:app')) {
                if (record.processHandle != null) {
                  record.processHandle!.kill();
                } else {
                  Process.killPid(pid);
                }
              }
            } else if (record.processHandle != null) {
              record.processHandle!.kill();
            }
          }
        } catch (_) {}
      }
      if (Platform.environment['COMPANION_TEST_TEMP_ROOT'] == null) {
        try {
          await tempRoot.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('Scenario A: Launches detached runtime through coordinator, verifies lockfile and rotating log', () async {
      final supervisor = AcceptanceTrackingSupervisor(spawnedRecords: trackedSpawnRecords);
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:$testPort',
        supervisor: supervisor,
        credentialStore: InMemoryCredentialStore(testToken),
        customLockFile: lockFile,
        customLogFilePath: logFile.path,
        customEnvironment: testEnv,
      );

      final state = await coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 25));
      expect(state.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(state.pid, isNotNull);
      expect(state.pid, greaterThan(0));

      launchedPid = state.pid;

      // Verify lockfile exists with Schema v1 descriptor
      expect(lockFile.existsSync(), isTrue);
      final lockData = await supervisor.readDescriptorDirect(lockFile);
      expect(lockData, isNotNull);
      expect(lockData?.schemaVersion, equals(1));
      expect(lockData?.pid, equals(state.pid));
      expect(lockData?.port, equals(testPort));

      // Verify rotating logfile was created and written to
      expect(logFile.existsSync(), isTrue);
      final logContent = await logFile.readAsString();
      expect(logContent.length, greaterThan(0));

      coordinator.dispose();
    }, timeout: const Timeout(Duration(seconds: 35)));

    test('Scenario B: Second coordinator instance attaches to existing runtime without duplicate spawn', () async {
      expect(launchedPid, isNotNull);

      final supervisor = WindowsRuntimeProcessSupervisor();
      final secondCoordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:$testPort',
        supervisor: supervisor,
        credentialStore: InMemoryCredentialStore(testToken),
        customLockFile: lockFile,
        customLogFilePath: logFile.path,
        customEnvironment: testEnv,
      );

      final state = await secondCoordinator.ensureRuntimeReady(timeout: const Duration(seconds: 10));
      expect(state.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(state.pid, equals(launchedPid));

      secondCoordinator.dispose();
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('Scenario C: Component-level runtime survival - UI exit leaves detached runtime process alive and listening (PC-HOST-001-MANUAL verifies full native OS shell lifecycle)', () async {
      expect(launchedPid, isNotNull);

      final supervisor = WindowsRuntimeProcessSupervisor();
      // Verify runtime process is still active and listening after coordinators are disposed
      final isListening = await supervisor.isPortListening('127.0.0.1', testPort);
      expect(isListening, isTrue);

      final isAlive = await supervisor.isProcessActiveAndMatching(
        launchedPid!,
        expectedExecutable: 'python.exe',
      );
      expect(isAlive, isTrue);
    });

    test('Scenario D: Stale lock recovery detects dead PID, spawns runtime, and overwrites lockfile descriptor with active PID', () async {
      final supervisor = WindowsRuntimeProcessSupervisor();
      const deadPid = 999999;

      final isAlive = await supervisor.isProcessActiveAndMatching(
        deadPid,
        expectedExecutable: 'python.exe',
      );
      expect(isAlive, isFalse);

      final testPortD = testPort + 2;
      final staleDataDir = Directory('${tempRoot.path}\\DataD');
      await staleDataDir.create(recursive: true);
      final staleEnvFile = File('${tempRoot.path}\\.envD');
      await staleEnvFile.writeAsString('COMPANION_API_KEY=$testToken\nPORT=$testPortD\n', flush: true);
      final staleLockFile = File('${tempRoot.path}\\stale.lock');
      final staleLogFile = File('${tempRoot.path}\\Logs\\stale_runtime.log');
      await staleLogFile.parent.create(recursive: true);

      final testEnvD = {
        'COMPANION_API_KEY': testToken,
        'COMPANION_DATA_ROOT': staleDataDir.path,
        'COMPANION_ENV_FILE': staleEnvFile.path,
        'COMPANION_LOCK_FILE': staleLockFile.path,
        'COMPANION_LOG_FILE': staleLogFile.path,
        'COMPANION_CLIENT_SETTINGS_FILE': settingsFile.path,
        'PYTHONUNBUFFERED': '1',
      };

      // 1. Seed the stale lockfile with dead PID descriptor
      final handle = await supervisor.acquireStartupLock(staleLockFile);
      expect(handle, isNotNull);
      await supervisor.writeDescriptorThroughHandle(
        handle!,
        RuntimeLockfileData(
          schemaVersion: 1,
          instanceId: 'stale-inst-dead-pid',
          pid: deadPid,
          port: testPortD,
          startedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
          executablePath: r'C:\test\python.exe',
        ),
      );
      await supervisor.releaseStartupLock(handle);

      // Verify dead PID is present in stale lockfile before recovery
      final staleDataBefore = await supervisor.readDescriptorDirect(staleLockFile);
      expect(staleDataBefore?.pid, equals(deadPid));

      // 2. Instantiate coordinator against stale lockfile and execute recovery
      final recoverySupervisor = AcceptanceTrackingSupervisor(spawnedRecords: trackedSpawnRecords);
      final recoveryCoordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:$testPortD',
        supervisor: recoverySupervisor,
        credentialStore: InMemoryCredentialStore(testToken),
        customLockFile: staleLockFile,
        customLogFilePath: staleLogFile.path,
        customEnvironment: testEnvD,
      );

      final recoveryState = await recoveryCoordinator.ensureRuntimeReady(
        timeout: const Duration(seconds: 25),
      );
      expect(recoveryState.status, equals(RuntimeStatus.readyAndAuthenticated));
      expect(recoveryState.pid, isNotNull);
      expect(recoveryState.pid, greaterThan(0));
      expect(recoveryState.pid, isNot(equals(deadPid)));

      // 3. Verify descriptor in stale lockfile was overwritten with the recovered live PID
      final staleDataAfter = await supervisor.readDescriptorDirect(staleLockFile);
      expect(staleDataAfter, isNotNull);
      expect(staleDataAfter?.pid, equals(recoveryState.pid));
      expect(staleDataAfter?.pid, isNot(equals(deadPid)));
      expect(staleDataAfter?.port, equals(testPortD));

      // 4. Verify process is genuinely active
      final isNewPidAlive = await supervisor.isProcessActiveAndMatching(
        recoveryState.pid!,
        expectedExecutable: 'python.exe',
      );
      expect(isNewPidAlive, isTrue);

      recoveryCoordinator.dispose();
    }, timeout: const Timeout(Duration(seconds: 35)));

    test('Scenario E: Alien port conflict reports alienPortConflict without terminating foreign listener', () async {
      final alienSocket = await ServerSocket.bind('127.0.0.1', 0);
      final alienPort = alienSocket.port;

      alienSocket.listen((client) {
        // Send non-HTTP alien data and close
        client.write('ALIEN_DATA\n');
        client.close();
      });

      final supervisor = WindowsRuntimeProcessSupervisor();
      final coordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:$alienPort',
        supervisor: supervisor,
        credentialStore: InMemoryCredentialStore(testToken),
        customEnvironment: testEnv,
      );

      final state = await coordinator.ensureRuntimeReady(timeout: const Duration(seconds: 3));
      expect(state.status, equals(RuntimeStatus.alienPortConflict));

      // Verify foreign listener was NOT killed or stopped
      expect(await supervisor.isPortListening('127.0.0.1', alienPort), isTrue);

      coordinator.dispose();
      await alienSocket.close();
    });

    test('Scenario F: Cross-process lock contention detected via Dart lock helper', () async {
      final tempDir = await Directory.systemTemp.createTemp('cross_proc_contention_');
      final contentionLockFile = File('${tempDir.path}\\runtime.lock');
      final supervisor = WindowsRuntimeProcessSupervisor();

      final dartExe = Platform.executable.contains('dart') ? Platform.executable : 'dart';
      final helper = await Process.start(
        dartExe,
        ['run', 'test/helpers/lock_holder_helper.dart', contentionLockFile.path, '2000'],
        workingDirectory: Directory.current.path,
        runInShell: Platform.isWindows,
      );

      final line = await helper.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((l) => l.trim() == 'LOCKED')
          .timeout(const Duration(seconds: 5));
      expect(line, equals('LOCKED'));

      final handle = await supervisor.acquireStartupLock(
        contentionLockFile,
        timeout: const Duration(milliseconds: 100),
      );
      expect(handle, isNull);

      await helper.exitCode;
      await tempDir.delete(recursive: true);
    });
  });
}
