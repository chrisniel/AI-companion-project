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
  test('reader validates the fixed local path before returning secret',
      () async {
    final store = HostAdminSecretStore(run: (executable, args) async {
      expect(executable, 'powershell.exe');
      expect(args.last, contains('desktop_admin.secret'));
      expect(args.last, contains('AreAccessRulesProtected'));
      expect(args.last, contains('ReparsePoint'));
      expect(args.last, contains('S-1-5-18'));
      return ProcessResult(1, 0, 'hsk_test\r\n', '');
    });
    expect(await store.readToken(), 'hsk_test');
  });
}
