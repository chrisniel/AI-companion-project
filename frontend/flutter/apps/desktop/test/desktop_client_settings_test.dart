import 'dart:io';
import 'package:ai_companion_desktop/platform/desktop_client_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopClientSettings', () {
    late Directory tempDir;
    late String testPath;
    late DesktopClientSettings settings;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('client_settings_test');
      testPath = '${tempDir.path}\\client_settings.json';
      settings = DesktopClientSettings(customFilePath: testPath);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('readHostUrl returns default value when file absent', () async {
      final host = await settings.readHostUrl(defaultValue: 'http://127.0.0.1:8000');
      expect(host, 'http://127.0.0.1:8000');
    });

    test('writeHostUrl persists and reads back cleanly', () async {
      await settings.writeHostUrl('http://192.168.1.100:8000');
      final host = await settings.readHostUrl();
      expect(host, 'http://192.168.1.100:8000');

      final file = File(testPath);
      expect(await file.exists(), isTrue);
    });

    test('deleteSettings removes file', () async {
      await settings.writeHostUrl('http://localhost:8000');
      expect(await File(testPath).exists(), isTrue);

      await settings.deleteSettings();
      expect(await File(testPath).exists(), isFalse);
    });
  });
}
