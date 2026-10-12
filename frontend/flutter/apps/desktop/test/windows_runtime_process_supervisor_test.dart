import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_desktop/platform/process_launcher_adapter.dart';
import 'package:ai_companion_desktop/platform/windows_runtime_process_supervisor.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProcess implements Process {
  @override
  final int pid;
  @override
  final Stream<List<int>> stdout;
  @override
  final Stream<List<int>> stderr;
  @override
  final Future<int> exitCode;
  bool wasKilled = false;

  FakeProcess({
    this.pid = 9999,
    Stream<List<int>>? stdout,
    Stream<List<int>>? stderr,
    Future<int>? exitCode,
  })  : stdout = stdout ?? const Stream.empty(),
        stderr = stderr ?? const Stream.empty(),
        exitCode = exitCode ?? Future.value(0);

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    wasKilled = true;
    return true;
  }
}

class FakeProcessLauncher implements ProcessLauncherAdapter {
  FakeProcess? processToStart;
  Exception? startException;
  String? startedCommand;
  List<String>? startedArgs;
  ProcessResult? runResult;

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    startedCommand = executable;
    startedArgs = arguments;
    if (startException != null) throw startException!;
    return processToStart ?? FakeProcess();
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    if (runResult != null) return runResult!;
    throw UnimplementedError('run() should not be used when start() is required for process lifecycle control');
  }

  @override
  Future<bool> killPid(int pid, [ProcessSignal signal = ProcessSignal.sigterm]) async {
    throw UnimplementedError('Arbitrary killPid must not be called during inspection timeout');
  }
}

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

      final helperPath = _resolveLockHelperPath();
      final dartExe = Platform.executable.contains('dart') ? Platform.executable : 'dart';
      final helper = await Process.start(
        dartExe,
        ['run', helperPath, lockFile.path, '2000'],
        workingDirectory: Directory.current.path,
        runInShell: Platform.isWindows,
      );

      final stderrBuffer = StringBuffer();
      helper.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

      final completer = Completer<String>();
      final sub = helper.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim() == 'LOCKED' && !completer.isCompleted) {
          completer.complete(line.trim());
        }
      }, onError: (Object err) {
        if (!completer.isCompleted) completer.completeError(err);
      }, onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError(
              'Lock helper exited before emitting LOCKED. Stderr: ${stderrBuffer.toString().trim()}',
            ),
          );
        }
      });

      helper.exitCode.then((code) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError(
              'Lock helper terminated prematurely with code $code. Stderr: ${stderrBuffer.toString().trim()}',
            ),
          );
        }
      });

      final line = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'Timed out waiting for LOCKED from helper. Stderr: ${stderrBuffer.toString().trim()}',
          );
        },
      );
      expect(line, equals('LOCKED'));
      await sub.cancel();

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

    test('discoverRuntimeProcesses: normal empty inspection results return noProcess', () async {
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = FakeProcess(
        stdout: Stream.value(utf8.encode('')),
        exitCode: Future.value(0),
      );
      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\test\python.exe',
      );

      expect(result.status, equals(ProcessDiscoveryStatus.noProcess));
    });

    test('discoverRuntimeProcesses: unexpected non-JSON output returns inspectionUnavailable, never noProcess', () async {
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = FakeProcess(
        stdout: Stream.value(utf8.encode('Get-CimInstance : Invalid namespace or access denied')),
        exitCode: Future.value(0),
      );
      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\test\python.exe',
      );

      expect(result.status, equals(ProcessDiscoveryStatus.inspectionUnavailable));
      expect(result.diagnostic, contains('Non-JSON output'));
    });

    test('discoverRuntimeProcesses: malformed JSON output returns inspectionUnavailable, never noProcess', () async {
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = FakeProcess(
        stdout: Stream.value(utf8.encode('[{ "ProcessId": 1234, "CommandLine": ')),
        exitCode: Future.value(0),
      );
      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\test\python.exe',
      );

      expect(result.status, equals(ProcessDiscoveryStatus.inspectionUnavailable));
      expect(result.diagnostic, contains('Malformed JSON'));
    });

    test('discoverRuntimeProcesses: query failure with non-zero exit code returns inspectionUnavailable', () async {
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = FakeProcess(
        stderr: Stream.value(utf8.encode('WMI service unavailable')),
        exitCode: Future.value(1),
      );
      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\test\python.exe',
      );

      expect(result.status, equals(ProcessDiscoveryStatus.inspectionUnavailable));
      expect(result.diagnostic, contains('code 1'));
    });

    test('discoverRuntimeProcesses: query timeout terminates subprocess via retained handle and returns inspectionUnavailable', () async {
      final fakeProcess = FakeProcess(
        exitCode: Completer<int>().future, // Never completes
      );
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = fakeProcess;

      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\test\python.exe',
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.status, equals(ProcessDiscoveryStatus.inspectionUnavailable));
      expect(result.diagnostic, contains('timed out'));
      expect(fakeProcess.wasKilled, isTrue);
    });
    test('discoverRuntimeProcesses: query with exit code 0 but stderr error returns inspectionUnavailable', () async {
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = FakeProcess(
        stdout: Stream.value(utf8.encode('')),
        stderr: Stream.value(utf8.encode('Get-CimInstance : Access is denied')),
        exitCode: Future.value(0),
      );
      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\test\python.exe',
      );

      expect(result.status, equals(ProcessDiscoveryStatus.inspectionUnavailable));
      expect(result.diagnostic, contains('stderr'));
    });

    test('discoverRuntimeProcesses: valid JSON with invalid process schema returns inspectionUnavailable', () async {
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = FakeProcess(
        stdout: Stream.value(utf8.encode('{"Message":"Access denied"}')),
        exitCode: Future.value(0),
      );
      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\test\python.exe',
      );

      expect(result.status, equals(ProcessDiscoveryStatus.inspectionUnavailable));
      expect(result.diagnostic, contains('ProcessId'));
    });

    test('discoverRuntimeProcesses: valid process query output returns verified result', () async {
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = FakeProcess(
        stdout: Stream.value(utf8.encode(jsonEncode({
          'ProcessId': 4321,
          'ExecutablePath': r'C:\test\python.exe',
          'CommandLine': r'C:\test\python.exe -m uvicorn app.main:app --port 8000',
          'CreationDate': '2026-10-11T10:00:00.0000000Z',
        }))),
        exitCode: Future.value(0),
      );
      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\test\python.exe',
      );

      expect(result.status, equals(ProcessDiscoveryStatus.verified));
      expect(result.verifiedProcess?.pid, equals(4321));
    });

    test('discoverRuntimeProcesses: hanging output collection respects bounded deadline and terminates subprocess', () async {
      final fakeProcess = FakeProcess(
        exitCode: Future.value(0),
        stdout: Completer<List<int>>().future.asStream(), // Output stream never closes
      );
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = fakeProcess;

      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\test\python.exe',
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.status, equals(ProcessDiscoveryStatus.inspectionUnavailable));
      expect(result.diagnostic, contains('timed out'));
      expect(fakeProcess.wasKilled, isTrue);
    });

    test('isExecutablePathMatch: matches sibling python.exe and pythonw.exe in identical directory', () {
      expect(
        WindowsRuntimeProcessSupervisor.isExecutablePathMatch(
          r'C:\venv\Scripts\python.exe',
          r'C:\venv\Scripts\pythonw.exe',
        ),
        isTrue,
      );
      expect(
        WindowsRuntimeProcessSupervisor.isExecutablePathMatch(
          r'C:\venv\Scripts\pythonw.exe',
          r'C:\venv\Scripts\python.exe',
        ),
        isTrue,
      );
      expect(
        WindowsRuntimeProcessSupervisor.isExecutablePathMatch(
          r'C:\foreign\Scripts\python.exe',
          r'C:\venv\Scripts\pythonw.exe',
        ),
        isFalse,
      );
    });

    test('isProcessActiveAndMatching: accepts python.exe image when expected executable is pythonw.exe', () async {
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.runResult = ProcessResult(
        1234,
        0,
        '"python.exe","1234","Console","1","50,000 K"\r\n',
        '',
      );
      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final isMatch = await supervisor.isProcessActiveAndMatching(
        1234,
        expectedExecutable: r'C:\venv\Scripts\pythonw.exe',
      );
      expect(isMatch, isTrue);
    });

    test('discoverRuntimeProcesses: discovers existing python.exe process when expected executable is pythonw.exe', () async {
      final fakeLauncher = FakeProcessLauncher();
      fakeLauncher.processToStart = FakeProcess(
        stdout: Stream.value(utf8.encode(jsonEncode({
          'ProcessId': 7890,
          'ExecutablePath': r'C:\venv\Scripts\python.exe',
          'CommandLine': r'C:\venv\Scripts\python.exe -m uvicorn app.main:app --port 8000',
          'CreationDate': '2026-10-11T10:00:00.0000000Z',
        }))),
        exitCode: Future.value(0),
      );
      final supervisor = WindowsRuntimeProcessSupervisor(launcher: fakeLauncher);

      final result = await supervisor.discoverRuntimeProcesses(
        port: 8000,
        expectedExecutable: r'C:\venv\Scripts\pythonw.exe',
      );

      expect(result.status, equals(ProcessDiscoveryStatus.verified));
      expect(result.verifiedProcess?.pid, equals(7890));
      expect(fakeLauncher.startedCommand, equals('powershell'));
      expect(fakeLauncher.startedArgs?.join(' '), contains("Name LIKE 'python%'"));
    });
  });
}

String _resolveLockHelperPath() {
  final candidates = [
    File('${Directory.current.path}/test/helpers/lock_holder_helper.dart'),
    File('${Directory.current.path}/apps/desktop/test/helpers/lock_holder_helper.dart'),
    File('${Directory.current.path}/frontend/flutter/apps/desktop/test/helpers/lock_holder_helper.dart'),
  ];
  if (Platform.script.scheme == 'file') {
    final scriptDir = File(Platform.script.toFilePath()).parent;
    candidates.add(File('${scriptDir.path}/helpers/lock_holder_helper.dart'));
    candidates.add(File('${scriptDir.path}/test/helpers/lock_holder_helper.dart'));
  }
  for (final candidate in candidates) {
    if (candidate.existsSync()) {
      return candidate.absolute.path;
    }
  }
  Directory dir = Directory.current.absolute;
  for (var i = 0; i < 5; i++) {
    final candidate = File('${dir.path}/frontend/flutter/apps/desktop/test/helpers/lock_holder_helper.dart');
    if (candidate.existsSync()) return candidate.path;
    final candidate2 = File('${dir.path}/apps/desktop/test/helpers/lock_holder_helper.dart');
    if (candidate2.existsSync()) return candidate2.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('Could not resolve lock_holder_helper.dart path from ${Directory.current.path}');
}
