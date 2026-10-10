import 'dart:convert';
import 'dart:io';

/// Manages non-secret persistent desktop client settings on Windows.
///
/// Plaintext preferences (such as the runtime host URL) are persisted in
/// `%LOCALAPPDATA%\AI Companion\client_settings.json`.
/// Secret credentials (pairing tokens) are strictly stored separately in DPAPI.
class DesktopClientSettings {
  final String? customFilePath;

  DesktopClientSettings({this.customFilePath});

  String get _filePath {
    if (customFilePath != null) return customFilePath!;
    final envSettings = Platform.environment['COMPANION_CLIENT_SETTINGS_FILE'];
    if (envSettings != null && envSettings.trim().isNotEmpty) {
      return envSettings.trim();
    }
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) {
      return 'client_settings.json';
    }
    return '$localAppData\\AI Companion\\client_settings.json';
  }

  /// Reads configured host URL from local client settings file, falling back to defaultValue.
  Future<String> readHostUrl({String defaultValue = 'http://127.0.0.1:8000'}) async {
    try {
      final file = File(_filePath);
      if (!await file.exists()) {
        return defaultValue;
      }
      final content = await file.readAsString();
      final dynamic decoded = jsonDecode(content);
      if (decoded is Map && decoded['hostUrl'] is String) {
        final url = (decoded['hostUrl'] as String).trim();
        return url.isNotEmpty ? url : defaultValue;
      }
      return defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  /// Persists configured host URL into local client settings file.
  Future<void> writeHostUrl(String hostUrl) async {
    final file = File(_filePath);
    await file.parent.create(recursive: true);

    Map<String, dynamic> data = {};
    try {
      if (await file.exists()) {
        final content = await file.readAsString();
        final dynamic decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          data = Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}

    data['hostUrl'] = hostUrl.trim();
    data['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await file.writeAsString(jsonEncode(data), flush: true);
  }

  /// Deletes client settings file.
  Future<void> deleteSettings() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
