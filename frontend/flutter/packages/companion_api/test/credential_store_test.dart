import 'package:companion_api/companion_api.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryCredentialStore', () {
    test('writes, reads, and deletes token in memory', () async {
      final store = InMemoryCredentialStore();
      expect(await store.readToken(), isNull);

      await store.writeToken('test_token_123');
      expect(await store.readToken(), 'test_token_123');

      await store.deleteToken();
      expect(await store.readToken(), isNull);
    });

    test('initializes with default token if provided', () async {
      final store = InMemoryCredentialStore('initial_secret');
      expect(await store.readToken(), 'initial_secret');
    });
  });
}
