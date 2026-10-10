import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_desktop/platform/windows_dpapi_credential_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowsDpapiCredentialStore', () {
    late Directory tempDir;
    late String testFilePath;
    late WindowsDpapiCredentialStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ai_companion_dpapi_test');
      testFilePath = '${tempDir.path}\\test_credentials.bin';
      store = WindowsDpapiCredentialStore(customFilePath: testFilePath);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('readToken returns null when file is absent', () async {
      expect(await store.readToken(), isNull);
    });

    test('writes encrypted token and reads it back without plaintext leakage on disk', () async {
      const secret = 'super_secret_pairing_token_abc123';
      await store.writeToken(secret);

      // Verify file exists on disk
      final file = File(testFilePath);
      expect(await file.exists(), isTrue);

      final rawFileBytes = await file.readAsBytes();
      expect(rawFileBytes, isNotEmpty);

      if (Platform.isWindows) {
        // Disk ciphertext MUST NOT contain the plaintext secret
        final rawFileString = String.fromCharCodes(rawFileBytes);
        expect(rawFileString.contains(secret), isFalse);
      }

      // Decrypt and verify round trip
      final recovered = await store.readToken();
      expect(recovered, secret);
    });

    test('deleteToken removes the file', () async {
      await store.writeToken('to_be_deleted');
      expect(await store.readToken(), 'to_be_deleted');

      await store.deleteToken();
      expect(await store.readToken(), isNull);
      expect(await File(testFilePath).exists(), isFalse);
    });

    test('fails closed as null on corrupt file contents', () async {
      final file = File(testFilePath);
      await file.writeAsBytes(utf8.encode('corrupt_non_dpapi_junk'));

      if (Platform.isWindows) {
        expect(await store.readToken(), isNull);
      }
    });
  });
}
