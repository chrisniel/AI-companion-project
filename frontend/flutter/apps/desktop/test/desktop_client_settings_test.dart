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

    test('readChatZoomLevel returns 1.0 default when absent', () async {
      final zoom = await settings.readChatZoomLevel();
      expect(zoom, equals(1.0));
    });

    test('writeChatZoomLevel persists value and clamps to 0.8..1.6 range', () async {
      await settings.writeChatZoomLevel(1.25);
      expect(await settings.readChatZoomLevel(), equals(1.25));

      // Test clamping lower bound
      await settings.writeChatZoomLevel(0.5);
      expect(await settings.readChatZoomLevel(), equals(0.8));

      // Test clamping upper bound
      await settings.writeChatZoomLevel(2.5);
      expect(await settings.readChatZoomLevel(), equals(1.6));
    });

    test('readSelectedProfileId returns null when absent and persists cleanly', () async {
      expect(await settings.readSelectedProfileId(), isNull);

      await settings.writeSelectedProfileId('profile-uuid-123');
      expect(await settings.readSelectedProfileId(), 'profile-uuid-123');

      await settings.writeSelectedProfileId(null);
      expect(await settings.readSelectedProfileId(), isNull);
    });

    test('readSelectedProfileSessionExpiry returns null when absent and parses UTC ISO', () async {
      expect(await settings.readSelectedProfileSessionExpiry(), isNull);

      final expiry = DateTime.utc(2026, 12, 31, 23, 59, 59);
      await settings.writeSelectedProfileSessionExpiry(expiry);
      final read = await settings.readSelectedProfileSessionExpiry();
      expect(read, isNotNull);
      expect(read!.isUtc, isTrue);
      expect(read.toIso8601String(), expiry.toIso8601String());

      await settings.writeSelectedProfileSessionExpiry(null);
      expect(await settings.readSelectedProfileSessionExpiry(), isNull);
    });

    test('readProfileExplicitlyLocked returns false by default and persists toggle', () async {
      expect(await settings.readProfileExplicitlyLocked(), isFalse);

      await settings.writeProfileExplicitlyLocked(true);
      expect(await settings.readProfileExplicitlyLocked(), isTrue);

      await settings.writeProfileExplicitlyLocked(false);
      expect(await settings.readProfileExplicitlyLocked(), isFalse);
    });
  });
}
