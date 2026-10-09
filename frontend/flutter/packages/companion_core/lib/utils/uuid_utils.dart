import 'dart:math';

/// Utility for generating RFC 4122 version 4 UUIDs using cryptographically secure random bytes.
class UuidUtils {
  const UuidUtils._();

  /// Generates a random UUID v4 string (e.g., `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`).
  static String generateV4([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

    // Version 4 bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Variant RFC 4122 bits
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
