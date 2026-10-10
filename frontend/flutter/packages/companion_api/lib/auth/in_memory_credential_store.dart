import 'credential_store.dart';

/// In-memory implementation of [CredentialStore] for testing and headless usage.
class InMemoryCredentialStore implements CredentialStore {
  String? _token;

  InMemoryCredentialStore([this._token]);

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<void> deleteToken() async {
    _token = null;
  }
}
