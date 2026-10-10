import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowsRuntimeProcessSupervisor', () {
    test('opens lockfile with append mode and writes descriptor through locked handle without truncating on open', () async {
      final tempDir = await Directory.systemTemp.createTemp('lock_test_');
      final lockFile = File('${tempDir.path}\\runtime.lock');
      final supervisor = WindowsRuntimeProcessSupervisor();

      // First acquisition
      final handle1 = await supervisor.acquireStartupLock(lockFile);
      expect(handle1, isNotNull);

      final data = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'test-inst-1',
        pid: 1001,
        port: 8000,
        startedAt: DateTime.now().toUtc(),
        executablePath: r'C:\test\python.exe',
      );
      await supervisor.writeDescriptorThroughHandle(handle1!, data);
      final readBack = await supervisor.readDescriptorThroughHandle(handle1);
      expect(readBack?.instanceId, equals('test-inst-1'));

      await supervisor.releaseStartupLock(handle1);

      // Reopening in append mode must NOT truncate existing descriptor
      final handle2 = await supervisor.acquireStartupLock(lockFile);
      expect(handle2, isNotNull);
      final readAgain = await supervisor.readDescriptorThroughHandle(handle2!);
      expect(readAgain?.instanceId, equals('test-inst-1'));
      await supervisor.releaseStartupLock(handle2);

      await tempDir.delete(recursive: true);
    });

    test('detects cross-process lock contention via helper process', () async {
      final tempDir = await Directory.systemTemp.createTemp('cross_proc_test_');
      final lockFile = File('${tempDir.path}\\runtime.lock');
      final supervisor = WindowsRuntimeProcessSupervisor();

      // Launch external Dart helper process that holds lock for 2 seconds
      final dartExe = Platform.executable.contains('dart') ? Platform.executable : 'dart';
      final helper = await Process.start(
        dartExe,
        ['run', 'test/helpers/lock_holder_helper.dart', lockFile.path, '2000'],
        workingDirectory: Directory.current.path,
        runInShell: Platform.isWindows,
      );

      // Wait for LOCKED signal
      final line = await helper.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((l) => l.trim() == 'LOCKED')
          .timeout(const Duration(seconds: 5));
      expect(line, equals('LOCKED'));

      // Immediate attempt with 100ms timeout must detect lock contention and return null
      final handle = await supervisor.acquireStartupLock(lockFile, timeout: const Duration(milliseconds: 100));
      expect(handle, isNull);

      await helper.exitCode;
      await tempDir.delete(recursive: true);
    });

    test('refuses to kill or touch foreign or unverified PID', () async {
      final supervisor = WindowsRuntimeProcessSupervisor();
      // Probe PID 4 (System) or 0 with non-matching executable
      final isMatch = await supervisor.isProcessActiveAndMatching(
        4,
        expectedExecutable: 'python.exe',
      );
      expect(isMatch, isFalse);
    });

    test('fails closed when runtime executable is absent', () async {
      final supervisor = WindowsRuntimeProcessSupervisor();
      expect(
        () => supervisor.spawnDetachedRuntime(
          executable: r'C:\nonexistent\python.exe',
          args: [],
          workingDirectory: r'C:\',
          logFilePath: r'C:\temp\run.log',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
