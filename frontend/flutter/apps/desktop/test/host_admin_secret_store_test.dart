import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_desktop/platform/host_admin_secret_store.dart';

void main() {
  test('failed ACL validation cannot release or persist host secret', () async {
    final store = HostAdminSecretStore(
        run: (executable, args) async =>
            ProcessResult(1, 1, 'secret-that-must-not-escape', 'ACL failure'));
    await expectLater(store.readToken(), throwsStateError);
    await expectLater(store.writeToken('replacement'), throwsUnsupportedError);
    await expectLater(store.deleteToken(), throwsUnsupportedError);
  });

  test('reader validates the fixed local path with direct CLR access control',
      () async {
    final store = HostAdminSecretStore(run: (executable, args) async {
      expect(executable, 'powershell.exe');
      final script = args.last;
      expect(script, contains('desktop_admin.secret'));
      expect(script, contains('AreAccessRulesProtected'));
      expect(script, contains('ReparsePoint'));
      expect(script, contains('S-1-5-18'));
      expect(script, contains('[System.IO.Directory]::GetAccessControl'));
      expect(script, contains('[System.IO.File]::GetAccessControl'));
      expect(script, isNot(contains('Get-Acl')));
      return ProcessResult(1, 0, 'hsk_test\r\n', '');
    });
    expect(await store.readToken(), 'hsk_test');
  });

  test('real HostAdminSecretStore execution on Windows executes cleanly',
      () async {
    if (!Platform.isWindows) return;
    final store = HostAdminSecretStore();
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) return;

    final secretFile =
        File('$localAppData\\AICompanion\\secrets\\desktop_admin.secret');
    if (secretFile.existsSync()) {
      final token = await store.readToken();
      expect(token, isNotNull);
      expect(token!.startsWith('hsk_'), isTrue);
    } else {
      // When unprovisioned, it must fail closed and throw StateError, never crash.
      await expectLater(store.readToken(), throwsStateError);
    }
  });
}
