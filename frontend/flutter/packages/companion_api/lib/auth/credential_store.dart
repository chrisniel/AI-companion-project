/// Abstract interface for pairing credential storage across platforms.
abstract class CredentialStore {
  /// Retrieves the stored pairing token, or null if unset or unreadable.
  Future<String?> readToken();

  /// Persists the pairing token securely.
  Future<void> writeToken(String token);

  /// Deletes the stored pairing token.
  Future<void> deleteToken();
}
