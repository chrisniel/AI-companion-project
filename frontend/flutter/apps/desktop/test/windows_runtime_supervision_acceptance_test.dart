import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_desktop/coordinator/desktop_runtime_coordinator.dart';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final Set<int> testSpawnedPids = <int>{};

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
      for (final pid in testSpawnedPids) {
        if (pid > 0) {
          try {
            final isMatching = await supervisor.isProcessActiveAndMatching(
              pid,
              expectedExecutable: 'python.exe',
            );
            if (isMatching) {
              Process.killPid(pid);
            }
          } catch (_) {}
        }
      }
      if (Platform.environment['COMPANION_TEST_TEMP_ROOT'] == null) {
        try {
          await tempRoot.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('Scenario A: Launches detached runtime through coordinator, verifies lockfile and rotating log', () async {
      final supervisor = WindowsRuntimeProcessSupervisor();
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
      if (launchedPid != null) {
        testSpawnedPids.add(launchedPid!);
      }

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
      final recoveryCoordinator = DesktopRuntimeCoordinator(
        baseUrl: 'http://127.0.0.1:$testPortD',
        supervisor: supervisor,
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

      testSpawnedPids.add(recoveryState.pid!);

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
