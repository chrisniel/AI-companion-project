import 'package:companion_core/companion_core.dart';
import 'package:test/test.dart';

void main() {
  group('RuntimeLockfileData', () {
    test('serializes and deserializes valid descriptor accurately', () {
      final now = DateTime.utc(2026, 10, 11, 12, 0, 0);
      final lockfile = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: '550e8400-e29b-41d4-a716-446655440000',
        pid: 12345,
        port: 8000,
        startedAt: now,
        executablePath: r'D:\AI Companion\backend\.venv\Scripts\python.exe',
      );
      final jsonStr = lockfile.toRawJson();
      final restored = RuntimeLockfileData.fromRawJson(jsonStr);
      expect(restored.schemaVersion, equals(1));
      expect(restored.instanceId, equals('550e8400-e29b-41d4-a716-446655440000'));
      expect(restored.pid, equals(12345));
      expect(restored.port, equals(8000));
      expect(restored.startedAt, equals(now));
      expect(restored.executablePath, equals(r'D:\AI Companion\backend\.venv\Scripts\python.exe'));
    });

    test('fails closed on corrupt, partial, or invalid schema version descriptor', () {
      expect(() => RuntimeLockfileData.fromRawJson('{}'), throwsA(isA<FormatException>()));
      expect(() => RuntimeLockfileData.fromRawJson('{"schema_version": 2}'), throwsA(isA<FormatException>()));
      expect(() => RuntimeLockfileData.fromRawJson('not-json'), throwsA(isA<FormatException>()));
      expect(
        () => RuntimeLockfileData.fromRawJson(
          '{"schema_version": 1, "instance_id": "test", "pid": "bad_pid", "port": 8000, "started_at": "invalid", "executable_path": "cmd"}',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('toJson and fromJson handle map round-trip correctly', () {
      final now = DateTime.utc(2026, 10, 11, 10, 30, 0);
      final lockfile = RuntimeLockfileData(
        schemaVersion: 1,
        instanceId: 'instance-abc-123',
        pid: 54321,
        port: 8765,
        startedAt: now,
        executablePath: r'C:\Python\python.exe',
      );
      final map = lockfile.toJson();
      final fromMap = RuntimeLockfileData.fromJson(map);
      expect(fromMap.instanceId, equals('instance-abc-123'));
      expect(fromMap.pid, equals(54321));
      expect(fromMap.port, equals(8765));
      expect(fromMap.startedAt, equals(now));
      expect(fromMap.executablePath, equals(r'C:\Python\python.exe'));
    });
  });
}
