import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../auth/credential_store.dart';
import '../auth/in_memory_credential_store.dart';
import '../dto/character_dto.dart';
import '../dto/auth_dto.dart';
import '../dto/conversation_dto.dart';
import '../dto/health_dto.dart';
import '../dto/memory_dto.dart';
import '../dto/message_dto.dart';
import '../dto/model_registry_dto.dart';
import '../dto/model_status_dto.dart';
import '../dto/profile_dto.dart';
import '../dto/scheduling_dto.dart';
import '../dto/sse_event_dto.dart';
import '../dto/system_status_dto.dart';
import '../dto/task_dto.dart';
import '../dto/tools_dto.dart';
import '../dto/voice_dto.dart';
import '../transport/sse_parser.dart';
import 'companion_api_exception.dart';

/// Typed client communicating with the Local AI Runtime.
class CompanionClient {
  final Uri baseUri;
  final http.Client _httpClient;
  final CredentialStore? credentialStore;
  final CredentialStore? hostAdminStore;
  final CredentialStore sessionStore;
  final SseStreamParser _sseParser;

  CompanionClient({
    String baseUrl = 'http://127.0.0.1:8000',
    http.Client? httpClient,
    this.credentialStore,
    this.hostAdminStore,
    CredentialStore? sessionStore,
    SseStreamParser? sseParser,
  })  : sessionStore = sessionStore ?? InMemoryCredentialStore(),
        baseUri = validateBaseUrl(baseUrl),
        _httpClient = httpClient ?? http.Client(),
        _sseParser = sseParser ?? const SseStreamParser();

  static Uri validateBaseUrl(String url) {
    final uri = Uri.parse(url.endsWith('/') ? url.substring(0, url.length - 1) : url);
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError.value(
        url,
        'baseUrl',
        'Runtime base URL must use http or https scheme.',
      );
    }
    return uri;
  }


  bool _isLoopback(String host) {
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  Future<Map<String, String>> _buildHeaders({bool requiresAuth = true, bool admin = false, bool telemetry = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (admin) {
      if (!_isLoopback(baseUri.host) || baseUri.userInfo.isNotEmpty || baseUri.path.isNotEmpty) {
        throw StateError('Host administration requires a local loopback runtime root.');
      }
      final secret = await hostAdminStore?.readToken();
      if (secret == null || secret.isEmpty) throw StateError('Host administrator authority is unavailable.');
      headers['X-Host-Admin-Secret'] = secret;
    } else if (requiresAuth) {
      final session = await sessionStore.readToken();
      final token = session ?? (telemetry ? await credentialStore?.readToken() : null);
      if (token != null && token.isNotEmpty) {
        // Guard against sending credentials over unencrypted remote HTTP
        if (baseUri.scheme == 'http' && !_isLoopback(baseUri.host)) {
          throw StateError(
            'Refusing to transmit pairing credentials over unencrypted remote HTTP to ${baseUri.host}. Use HTTPS for remote connections.',
          );
        }
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> _sessionRequest(
    String path, {
    bool admin = false,
    Map<String, dynamic>? body,
    bool post = false,
    String? method,
    bool public = false,
  }) async {
    final effectiveMethod = method ?? (post ? 'POST' : 'GET');
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/$path');
    final headers = admin ? null : await _buildHeaders(requiresAuth: !public);
    final response = admin
        ? await _adminRequest(effectiveMethod, uri, body: body == null ? null : jsonEncode(body))
        : await _requestWithoutRedirects(effectiveMethod, uri, headers: headers!, body: body == null ? null : jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) _handleErrorResponse(response);
    return response.statusCode == 204 ? null : jsonDecode(response.body);
  }

  /// Administrator authority never follows redirects, even to another loopback port.
  Future<http.Response> _adminRequest(
    String method,
    Uri uri, {
    String? body,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return _requestWithoutRedirects(
      method,
      uri,
      headers: await _buildHeaders(admin: true),
      body: body,
      timeout: timeout,
    );
  }

  Future<http.Response> _requestWithoutRedirects(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers.addAll(headers);
    if (body != null) request.body = body;
    final response = await _httpClient.send(request).timeout(timeout);
    return http.Response.fromStream(response).timeout(timeout);
  }

  Future<List<Map<String, dynamic>>> listProfiles() async =>
      (await _sessionRequest('profiles', admin: true) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<ProfileMetadata> createProfile(ProfileCreateRequest request) async {
    final dynamic json = await _sessionRequest(
      'profiles',
      admin: true,
      method: 'POST',
      body: request.toJson(),
    );
    return ProfileMetadata.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<ProfileMetadata> renameProfile(String profileId, ProfileUpdateRequest request) async {
    final dynamic json = await _sessionRequest(
      'profiles/$profileId',
      admin: true,
      method: 'PATCH',
      body: request.toJson(),
    );
    return ProfileMetadata.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<ProfileMetadata> deleteProfile(String profileId) async {
    final dynamic json = await _sessionRequest(
      'profiles/$profileId',
      admin: true,
      method: 'DELETE',
    );
    return ProfileMetadata.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<List<Map<String, dynamic>>> listDeletedProfiles() async =>
      (await _sessionRequest('profiles/deleted', admin: true) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<ProfileMetadata> restoreProfile(String profileId) async {
    final dynamic json = await _sessionRequest(
      'profiles/$profileId/restore',
      admin: true,
      post: true,
    );
    return ProfileMetadata.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<Map<String, dynamic>> purgeProfile(String profileId) async {
    final dynamic json = await _sessionRequest(
      'profiles/$profileId/purge',
      admin: true,
      post: true,
    );
    return Map<String, dynamic>.from(json as Map);
  }

  Future<PurgeMaintenanceResult> runPurgeMaintenance({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/system/maintenance/purge-profiles');
    final response = await _adminRequest('POST', uri, timeout: timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return PurgeMaintenanceResult.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  Future<List<Map<String, dynamic>>> pendingBrowserRequests() async =>
      (await _sessionRequest('auth/bootstrap/requests', admin: true) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> approveBrowserRequest(String requestId, String profileId) async {
    await _sessionRequest('auth/bootstrap/ticket', admin: true, post: true, body: {'profile_id': profileId, 'request_id': requestId});
  }

  Future<Map<String, dynamic>> establishProfileSession(String profileId, {bool writeToStore = true}) async {
    final ticket = await _sessionRequest('auth/bootstrap/ticket', admin: true, post: true, body: {'profile_id': profileId});
    final session = Map<String, dynamic>.from(await _sessionRequest('auth/session/exchange', public: true, post: true, body: {'ticket': ticket['ticket']}) as Map);
    if (writeToStore) {
      await sessionStore.writeToken(session['token'] as String);
    }
    return session;
  }

  Future<Map<String, dynamic>> mintAndExchangeProfileSession(String profileId) async {
    return establishProfileSession(profileId, writeToStore: false);
  }

  Future<Map<String, dynamic>> getOwnSession() async => Map<String, dynamic>.from(await _sessionRequest('auth/session/me') as Map);

  Future<void> revokeProfileSession() async {
    try {
      await _sessionRequest('auth/session/revoke', post: true);
    } finally {
      await sessionStore.deleteToken();
    }
  }

  Future<void> revokeSessionToken(String token) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/auth/session/revoke');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response = await _requestWithoutRedirects('POST', uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _handleErrorResponse(response);
    }
  }

  Never _handleErrorResponse(http.Response response) {
    String? code;
    String message = 'HTTP ${response.statusCode}';
    dynamic details;

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map) {
        final nestedError = body['error'];
        if (nestedError is Map) {
          code = nestedError['code']?.toString();
          message = nestedError['message']?.toString() ?? message;
        }
        code ??= body['code']?.toString() ?? body['detail']?.toString();
        if (message == 'HTTP ${response.statusCode}') {
          message = body['message']?.toString() ??
              body['detail']?.toString() ??
              message;
        }
        details = body;
      }
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : message;
    }

    throw CompanionApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      details: details,
    );
  }

  /// Probes runtime liveness via public GET /api/v1/health.
  Future<HealthResponse> getHealth({Duration timeout = const Duration(seconds: 3)}) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/health');
    try {
      final response = await _httpClient.get(uri).timeout(timeout);
      if (response.statusCode == 200) {
        final dynamic json = jsonDecode(response.body);
        return HealthResponse.fromJson(Map<String, dynamic>.from(json as Map));
      }
      _handleErrorResponse(response);
    } on TimeoutException {
      throw const CompanionApiException(
        statusCode: 408,
        code: 'TIMEOUT',
        message: 'Runtime health probe timed out.',
      );
    }
  }

  /// Verifies pairing token via POST /api/v1/auth/verify.
  Future<AuthVerifyResponse> verifyAuth({Duration timeout = const Duration(seconds: 5)}) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/auth/verify');
    final headers = await _buildHeaders(telemetry: true);
    try {
      final response = await _httpClient.post(uri, headers: headers).timeout(timeout);
      if (response.statusCode == 200) {
        final dynamic json = jsonDecode(response.body);
        return AuthVerifyResponse.fromJson(Map<String, dynamic>.from(json as Map));
      }
      _handleErrorResponse(response);
    } on TimeoutException {
      throw const CompanionApiException(
        statusCode: 408,
        code: 'TIMEOUT',
        message: 'Authentication verification timed out.',
      );
    }
  }

  /// Retrieves host machine hardware profile and runtime status via GET /api/v1/system/status.
  Future<SystemStatusResponse> getSystemStatus({Duration timeout = const Duration(seconds: 5)}) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/system/status');
    final response = await _adminRequest('GET', uri, timeout: timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return SystemStatusResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Requests cooperative runtime shutdown via POST /api/v1/system/shutdown.
  Future<SystemShutdownResponse> shutdownSystem({
    String reason = 'user_exit_companion',
    double drainTimeoutSeconds = 6.0,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/system/shutdown');
    final body = jsonEncode({
      'reason': reason,
      'drain_timeout_seconds': drainTimeoutSeconds,
    });
    final response = await _adminRequest('POST', uri, body: body, timeout: timeout);
    if (response.statusCode == 202) {
      final dynamic json = jsonDecode(response.body);
      return SystemShutdownResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Retrieves model status and runtime state via GET /api/v1/models.
  Future<ModelStatusResponse> getModelStatus({Duration timeout = const Duration(seconds: 5)}) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/models');
    final headers = await _buildHeaders(telemetry: true);
    final response = await _httpClient.get(uri, headers: headers).timeout(timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ModelStatusResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Retrieves model catalog and validation states via GET /api/v1/models/registry.
  Future<List<ModelRegistryEntry>> getModelRegistry() async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/models/registry');
    final headers = await _buildHeaders(telemetry: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      if (json is List) {
        return json
            .map((e) => ModelRegistryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return const [];
    }
    _handleErrorResponse(response);
  }

  /// Selects a model in persistent host configuration via POST /api/v1/models/select.
  Future<ModelStatusResponse> selectModel(
    String modelName, {
    bool loadImmediately = false,
    String? profile,
    Duration? timeout,
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/models/select');
    final body = jsonEncode({
      'model_name': modelName,
      'load_immediately': loadImmediately,
      if (profile != null) 'profile': profile,
    });
    final effectiveTimeout = timeout ??
        (loadImmediately ? const Duration(seconds: 90) : const Duration(seconds: 10));
    final response = await _adminRequest('POST', uri, body: body, timeout: effectiveTimeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ModelStatusResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Explicitly loads model weights into VRAM via POST /api/v1/models/load.
  Future<ModelStatusResponse> loadModel({
    String? modelName,
    String? profile,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/models/load');
    final body = jsonEncode({
      if (modelName != null) 'model_name': modelName,
      if (profile != null) 'profile': profile,
    });
    final response = await _adminRequest('POST', uri, body: body, timeout: timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ModelStatusResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Explicitly unloads model weights and releases VRAM via POST /api/v1/models/unload.
  Future<ModelStatusResponse> unloadModel({Duration timeout = const Duration(seconds: 20)}) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/models/unload');
    final response = await _adminRequest('POST', uri, timeout: timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ModelStatusResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Updates the persisted hardware performance profile via PATCH /api/v1/models/profile.
  Future<ModelStatusResponse> updateModelProfile(
    String profile, {
    String? contextMode,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/models/profile');
    final body = jsonEncode({
      'profile': profile,
      if (contextMode != null) 'context_mode': contextMode,
    });
    final response = await _adminRequest('PATCH', uri, body: body, timeout: timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ModelStatusResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Inspects the five canonical host storage roots via GET /api/v1/system/storage.
  Future<StorageRootsResponse> getStorageRoots({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/system/storage');
    final response = await _adminRequest('GET', uri, timeout: timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return StorageRootsResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Relocates LIBRARY_ROOT atomically in bootstrap.json via PUT /api/v1/system/storage/library-root.
  Future<StorageRootsResponse> relocateLibraryRoot(
    LibraryRootUpdateRequest request, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/system/storage/library-root');
    final response = await _adminRequest(
      'PUT',
      uri,
      body: jsonEncode(request.toJson()),
      timeout: timeout,
    );
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return StorageRootsResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Queries Windows Task Scheduler autostart status via GET /api/v1/system/autostart.
  Future<AutostartStatusOut> getAutostartStatus({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/system/autostart');
    final response = await _adminRequest('GET', uri, timeout: timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return AutostartStatusOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Updates Windows Task Scheduler autostart registration via PUT /api/v1/system/autostart.
  Future<AutostartStatusOut> updateAutostart(
    AutostartUpdateRequest request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/system/autostart');
    final response = await _adminRequest(
      'PUT',
      uri,
      body: jsonEncode(request.toJson()),
      timeout: timeout,
    );
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return AutostartStatusOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Manually scans IMPORT_INBOX_DIR for D6 GGUF model bundles via POST /api/v1/models/import/scan.
  Future<ModelImportScanOut> scanModelImportInbox({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/models/import/scan');
    final response = await _adminRequest('POST', uri, timeout: timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ModelImportScanOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Stages, verifies, and atomically installs a confirmed D6 bundle via POST /api/v1/models/import/install.
  Future<ModelImportInstallOut> installModelFromInbox(
    ModelImportInstallRequest request, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/models/import/install');
    final response = await _adminRequest(
      'POST',
      uri,
      body: jsonEncode(request.toJson()),
      timeout: timeout,
    );
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ModelImportInstallOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Uninstalls a D6 user-imported model via DELETE /api/v1/models/registry/{model_id}.
  Future<ModelDeleteOut> deleteInstalledModel(
    String modelId, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/models/registry/${Uri.encodeComponent(modelId)}',
    );
    final response = await _adminRequest('DELETE', uri, timeout: timeout);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ModelDeleteOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Creates a new persistent conversation thread via POST /api/v1/conversations.
  Future<ConversationOut> createConversation({String? title, String? characterId}) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/conversations');
    final headers = await _buildHeaders(requiresAuth: true);
    final payload = ConversationCreate(title: title, characterId: characterId);
    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode == 201) {
      final dynamic json = jsonDecode(response.body);
      return ConversationOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Lists conversations chronologically via GET /api/v1/conversations.
  Future<ConversationListOut> listConversations({int skip = 0, int limit = 50}) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/conversations',
      queryParameters: {'skip': skip.toString(), 'limit': limit.toString()},
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ConversationListOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Retrieves a specific conversation thread by ID via GET /api/v1/conversations/{conversation_id}.
  Future<ConversationOut> getConversation(String conversationId) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/conversations/$conversationId',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ConversationOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Deletes a conversation thread by ID via DELETE /api/v1/conversations/{conversation_id}.
  Future<void> deleteConversation(String conversationId) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/conversations/$conversationId',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.delete(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    _handleErrorResponse(response);
  }

  /// Lists messages for a conversation via GET /api/v1/conversations/{id}/messages.
  Future<MessageListOut> listMessages(String conversationId,
      {int skip = 0, int limit = 100}) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/conversations/$conversationId/messages',
      queryParameters: {'skip': skip.toString(), 'limit': limit.toString()},
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return MessageListOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Renames a conversation title via PATCH /api/v1/conversations/{conversation_id}.
  Future<ConversationOut> renameConversation(
    String conversationId,
    String title,
  ) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/conversations/$conversationId',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final payload = ConversationUpdate(title: title);
    final response = await _httpClient.patch(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ConversationOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Fetches the active rolling episode summary via GET /api/v1/conversations/{conversation_id}/summary.
  Future<ConversationSummaryOut?> getConversationSummary(
    String conversationId,
  ) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/conversations/$conversationId/summary',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded == null) return null;
      return ConversationSummaryOut.fromJson(
        Map<String, dynamic>.from(decoded as Map),
      );
    }
    _handleErrorResponse(response);
  }

  /// Triggers manual episode context compaction via POST /api/v1/conversations/{conversation_id}/compact.
  Future<ConversationCompactResponse> compactConversation(
    String conversationId, [
    ConversationCompactRequest? request,
  ]) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/conversations/$conversationId/compact',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final payload = request ?? const ConversationCompactRequest();
    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      return ConversationCompactResponse.fromJson(
        Map<String, dynamic>.from(decoded as Map),
      );
    }
    _handleErrorResponse(response);
  }

  /// Generates a model-assisted conversation title via POST /api/v1/conversations/{conversation_id}/generate-title.
  Future<ConversationOut> generateConversationTitle(
    String conversationId, {
    String? currentTitle,
    String? fallbackTitle,
  }) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/conversations/$conversationId/generate-title',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final payload = GenerateTitleRequest(
      currentTitle: currentTitle,
      fallbackTitle: fallbackTitle,
    );
    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ConversationOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Sends a user turn and consumes streaming assistant tokens via SSE.
  ///
  /// Supports per-request cancellation: cancelling the returned StreamSubscription
  /// terminates the underlying HTTP stream connection.
  Stream<SseEvent> sendMessageStream(
    String conversationId,
    MessageSend payload, {
    http.Client? customClient,
    void Function()? onAccepted,
  }) {
    late StreamController<SseEvent> outputController;
    http.Client? activeClient;
    StreamSubscription<SseEvent>? parserSubscription;
    final bool isCustomClient = customClient != null;
    bool isCancelled = false;

    void cleanup() {
      if (!isCustomClient) {
        activeClient?.close();
      }
    }

    outputController = StreamController<SseEvent>(
      onListen: () async {
        try {
          final uri = baseUri.replace(
            path: '${baseUri.path}/api/v1/conversations/$conversationId/messages',
          );
          final headers = await _buildHeaders(requiresAuth: true);
          if (isCancelled) {
            cleanup();
            return;
          }
          headers['Accept'] = 'text/event-stream';
          headers['Cache-Control'] = 'no-cache';

          final request = http.Request('POST', uri);
          request.headers.addAll(headers);
          request.body = jsonEncode(payload.toJson());

          if (isCancelled) {
            cleanup();
            return;
          }

          activeClient = customClient ?? http.Client();
          final streamedResponse = await activeClient!.send(request);

          if (isCancelled) {
            cleanup();
            return;
          }

          if (streamedResponse.statusCode != 200) {
            try {
              final errorBytes = await streamedResponse.stream.toBytes();
              final errorBody = utf8.decode(errorBytes, allowMalformed: true);
              String? code;
              String message = 'HTTP ${streamedResponse.statusCode}';
              dynamic details;
              try {
                final dynamic body = jsonDecode(errorBody);
                if (body is Map) {
                  code = body['code']?.toString() ?? body['detail']?.toString();
                  message = body['message']?.toString() ?? body['detail']?.toString() ?? message;
                  details = body;
                }
              } catch (_) {
                if (errorBody.isNotEmpty) message = errorBody;
              }

              if (!isCancelled && !outputController.isClosed) {
                outputController.addError(
                  CompanionApiException(
                    statusCode: streamedResponse.statusCode,
                    code: code,
                    message: message,
                    details: details,
                  ),
                );
              }
            } finally {
              cleanup();
              if (!outputController.isClosed) {
                await outputController.close();
              }
            }
            return;
          }

          if (isCancelled) {
            cleanup();
            return;
          }

          onAccepted?.call();

          final eventStream = _sseParser.parseByteStream(streamedResponse.stream);
          parserSubscription = eventStream.listen(
            (event) {
              if (!isCancelled && !outputController.isClosed) {
                outputController.add(event);
              }
            },
            onError: (Object err, StackTrace st) {
              cleanup();
              if (!isCancelled && !outputController.isClosed) {
                outputController.addError(err, st);
                outputController.close();
              }
            },
            onDone: () {
              cleanup();
              if (!outputController.isClosed) {
                outputController.close();
              }
            },
            cancelOnError: false,
          );
        } catch (err, st) {
          cleanup();
          if (!isCancelled && !outputController.isClosed) {
            outputController.addError(err, st);
            await outputController.close();
          }
        }
      },
      onCancel: () async {
        isCancelled = true;
        try {
          await parserSubscription?.cancel();
        } finally {
          cleanup();
        }
      },
    );

    return outputController.stream;
  }


  /// Lists application-owned character templates via GET /api/v1/characters/templates.
  Future<List<CharacterTemplateOut>> listCharacterTemplates() async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/templates');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return (json as List)
          .map((e) => CharacterTemplateOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    _handleErrorResponse(response);
  }

  /// Lists frozen personality presets via GET /api/v1/characters/presets.
  Future<List<CharacterPresetOut>> listCharacterPresets() async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/presets');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return (json as List)
          .map((e) => CharacterPresetOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    _handleErrorResponse(response);
  }

  /// Retrieves the immutable Neutral Assistant fallback via GET /api/v1/characters/neutral.
  Future<NeutralAssistantOut> getNeutralAssistant() async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/neutral');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return NeutralAssistantOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Retrieves the active character state for the profile via GET /api/v1/characters/active.
  Future<ActiveCharacterStateOut> getActiveCharacterState() async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/active');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ActiveCharacterStateOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Selects the active character via PUT /api/v1/characters/active.
  Future<ActiveCharacterStateOut> selectActiveCharacter(String characterId) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/active');
    final headers = await _buildHeaders(requiresAuth: true);
    final payload = ActiveCharacterSelectRequest(characterId: characterId);
    final response = await _httpClient.put(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ActiveCharacterStateOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Resets the active character to Neutral Assistant via POST /api/v1/characters/active/reset-neutral.
  Future<ActiveCharacterStateOut> resetActiveCharacterToNeutral() async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/active/reset-neutral');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.post(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ActiveCharacterStateOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Lists character instances owned by the Profile via GET /api/v1/characters/instances.
  Future<List<CharacterInstanceOut>> listCharacterInstances({
    bool includeArchived = true,
    bool includeLegacy = false,
  }) async {
    final queryParams = <String, String>{
      'include_archived': includeArchived.toString(),
      'include_legacy': includeLegacy.toString(),
    };
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/characters/instances',
      queryParameters: queryParams,
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return (json as List)
          .map((e) => CharacterInstanceOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    _handleErrorResponse(response);
  }

  /// Creates a new character instance via POST /api/v1/characters/instances.
  Future<CharacterInstanceOut> createCharacterInstance(CharacterInstanceCreate payload) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/instances');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode == 201) {
      final dynamic json = jsonDecode(response.body);
      return CharacterInstanceOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Retrieves a character instance by ID via GET /api/v1/characters/instances/{instance_id}.
  Future<CharacterInstanceOut> getCharacterInstance(String instanceId) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/instances/$instanceId');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return CharacterInstanceOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Updates a character instance by ID via PATCH /api/v1/characters/instances/{instance_id}.
  Future<CharacterInstanceOut> updateCharacterInstance(
    String instanceId,
    CharacterInstanceUpdate payload, {
    bool clearVoiceId = false,
  }) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/instances/$instanceId');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.patch(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson(clearVoiceId: clearVoiceId)),
    );
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return CharacterInstanceOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Deletes/archives a character instance by ID via DELETE /api/v1/characters/instances/{instance_id}.
  Future<void> deleteCharacterInstance(String instanceId) async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/characters/instances/$instanceId');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.delete(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    _handleErrorResponse(response);
  }

  /// Lists memories via GET /api/v1/memories.
  Future<MemoryListOut> listMemories({
    String? category,
    String? scope,
    String? characterInstanceId,
    bool? isCore,
    bool? userVerified,
    String? sourceType,
    String? tier,
    String? q,
    bool includeExpired = false,
    int skip = 0,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
      if (q != null && q.isNotEmpty) 'q': q,
      if (category != null) 'category': category,
      if (scope != null) 'scope': scope,
      if (characterInstanceId != null) 'character_instance_id': characterInstanceId,
      if (isCore != null) 'is_core': isCore.toString(),
      if (userVerified != null) 'user_verified': userVerified.toString(),
      if (sourceType != null) 'source_type': sourceType,
      if (tier != null) 'tier': tier,
      if (includeExpired) 'include_expired': 'true',
    };
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/memories',
      queryParameters: queryParams,
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return MemoryListOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Retrieves a specific memory by ID via GET /api/v1/memories/{memory_id}.
  Future<MemoryOut> getMemory(String memoryId) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/memories/$memoryId',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return MemoryOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Creates a new memory record via POST /api/v1/memories.
  Future<MemoryOut> createMemory(MemoryCreate payload) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/memories',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic json = jsonDecode(response.body);
      return MemoryOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Updates an existing memory record via PATCH /api/v1/memories/{memory_id}.
  Future<MemoryOut> updateMemory(String memoryId, MemoryUpdate payload) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/memories/$memoryId',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.patch(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return MemoryOut.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Deletes a memory record via DELETE /api/v1/memories/{memory_id}.
  Future<void> deleteMemory(String memoryId) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/api/v1/memories/$memoryId',
    );
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.delete(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    _handleErrorResponse(response);
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String fullPath, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    int expectedStatus = 200,
    bool admin = false,
  }) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}$fullPath',
      queryParameters:
          queryParameters == null || queryParameters.isEmpty ? null : queryParameters,
    );
    final headers = await _buildHeaders(requiresAuth: !admin, admin: admin);
    final encoded = body == null ? null : jsonEncode(body);
    late final http.Response response;
    if (admin) {
      response = await _adminRequest(method, uri, body: encoded);
    } else {
      switch (method) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
          break;
        case 'POST':
          response = await _httpClient.post(uri, headers: headers, body: encoded);
          break;
        case 'PATCH':
          response = await _httpClient.patch(uri, headers: headers, body: encoded);
          break;
        case 'PUT':
          response = await _httpClient.put(uri, headers: headers, body: encoded);
          break;
        case 'DELETE':
          response = await _httpClient.delete(uri, headers: headers);
          break;
        default:
          throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
      }
    }
    if (response.statusCode == expectedStatus) {
      final dynamic json = jsonDecode(response.body);
      return Map<String, dynamic>.from(json as Map);
    }
    _handleErrorResponse(response);
  }

  Future<void> _deleteNoContent(String fullPath) async {
    final uri = baseUri.replace(path: '${baseUri.path}$fullPath');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.delete(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    _handleErrorResponse(response);
  }

  // ---------------------------------------------------------------------------
  // Tasks (/api/v1/tasks)
  // ---------------------------------------------------------------------------

  /// Lists active tasks via GET /api/v1/tasks.
  Future<TaskListResponse> listTasks({
    String? status,
    String? priority,
    String? category,
    int skip = 0,
    int limit = 50,
  }) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/tasks',
      queryParameters: {
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (category != null) 'category': category,
        'skip': skip.toString(),
        'limit': limit.toString(),
      },
    );
    return TaskListResponse.fromJson(json);
  }

  /// Creates a task via POST /api/v1/tasks.
  Future<TaskResponse> createTask(TaskCreate payload) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/tasks',
      body: payload.toJson(),
      expectedStatus: 201,
    );
    return TaskResponse.fromJson(json);
  }

  /// Lists soft-deleted tasks in trash via GET /api/v1/tasks/trash.
  Future<TrashListResponse> listTrashTasks({
    int skip = 0,
    int limit = 50,
  }) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/tasks/trash',
      queryParameters: {
        'skip': skip.toString(),
        'limit': limit.toString(),
      },
    );
    return TrashListResponse.fromJson(json);
  }

  /// Fetches a task by ID via GET /api/v1/tasks/{task_id}.
  Future<TaskResponse> getTask(String taskId) async {
    final json = await _requestJson('GET', '/api/v1/tasks/$taskId');
    return TaskResponse.fromJson(json);
  }

  /// Partially updates a task via PATCH /api/v1/tasks/{task_id}.
  Future<TaskResponse> updateTask(
    String taskId,
    TaskUpdate payload, {
    bool clearNotes = false,
    bool clearDueDate = false,
    bool clearReminderMinutesBefore = false,
    bool clearReminderAt = false,
  }) async {
    final json = await _requestJson(
      'PATCH',
      '/api/v1/tasks/$taskId',
      body: payload.toJson(
        clearNotes: clearNotes,
        clearDueDate: clearDueDate,
        clearReminderMinutesBefore: clearReminderMinutesBefore,
        clearReminderAt: clearReminderAt,
      ),
    );
    return TaskResponse.fromJson(json);
  }

  /// Soft-deletes a task via DELETE /api/v1/tasks/{task_id}.
  Future<void> deleteTask(String taskId) async {
    await _deleteNoContent('/api/v1/tasks/$taskId');
  }

  /// Restores a soft-deleted task via POST /api/v1/tasks/{task_id}/restore.
  Future<TaskResponse> restoreTask(String taskId) async {
    final json = await _requestJson('POST', '/api/v1/tasks/$taskId/restore');
    return TaskResponse.fromJson(json);
  }

  /// Permanently purges a soft-deleted task via DELETE /api/v1/tasks/{task_id}/permanent.
  Future<void> permanentDeleteTask(String taskId) async {
    await _deleteNoContent('/api/v1/tasks/$taskId/permanent');
  }

  // ---------------------------------------------------------------------------
  // Quiet Hours (/api/v1/profiles/me/quiet-hours)
  // ---------------------------------------------------------------------------

  /// Retrieves the active profile Quiet Hours configuration.
  Future<QuietHoursOut> getQuietHours() async {
    final json = await _requestJson('GET', '/api/v1/profiles/me/quiet-hours');
    return QuietHoursOut.fromJson(json);
  }

  /// Updates the active profile Quiet Hours configuration.
  Future<QuietHoursOut> updateQuietHours(QuietHoursUpdate payload) async {
    final json = await _requestJson(
      'PATCH',
      '/api/v1/profiles/me/quiet-hours',
      body: payload.toJson(),
    );
    return QuietHoursOut.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Reminders (/api/v1/reminders)
  // ---------------------------------------------------------------------------

  /// Lists reminders via GET /api/v1/reminders.
  Future<ReminderListOut> listReminders({
    String? status,
    String? taskId,
    int skip = 0,
    int limit = 50,
  }) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/reminders',
      queryParameters: {
        if (status != null) 'status': status,
        if (taskId != null) 'task_id': taskId,
        'skip': skip.toString(),
        'limit': limit.toString(),
      },
    );
    return ReminderListOut.fromJson(json);
  }

  /// Creates a reminder via POST /api/v1/reminders.
  Future<ReminderOut> createReminder(ReminderCreate payload) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/reminders',
      body: payload.toJson(),
      expectedStatus: 201,
    );
    return ReminderOut.fromJson(json);
  }

  /// Fetches a reminder by ID via GET /api/v1/reminders/{reminder_id}.
  Future<ReminderOut> getReminder(String reminderId) async {
    final json = await _requestJson('GET', '/api/v1/reminders/$reminderId');
    return ReminderOut.fromJson(json);
  }

  /// Updates a reminder via PATCH /api/v1/reminders/{reminder_id}.
  Future<ReminderOut> updateReminder(
    String reminderId,
    ReminderUpdate payload,
  ) async {
    final json = await _requestJson(
      'PATCH',
      '/api/v1/reminders/$reminderId',
      body: payload.toJson(),
    );
    return ReminderOut.fromJson(json);
  }

  /// Soft-deletes a reminder via DELETE /api/v1/reminders/{reminder_id}.
  Future<void> deleteReminder(String reminderId) async {
    await _deleteNoContent('/api/v1/reminders/$reminderId');
  }

  /// Snoozes a reminder via POST /api/v1/reminders/{reminder_id}/snooze.
  Future<ReminderOut> snoozeReminder(
    String reminderId, {
    SnoozeRequest? payload,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/reminders/$reminderId/snooze',
      body: (payload ?? const SnoozeRequest()).toJson(),
    );
    return ReminderOut.fromJson(json);
  }

  /// Acknowledges a reminder via POST /api/v1/reminders/{reminder_id}/acknowledge.
  Future<ReminderOut> acknowledgeReminder(
    String reminderId, {
    AcknowledgeRequest? payload,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/reminders/$reminderId/acknowledge',
      body: (payload ?? const AcknowledgeRequest()).toJson(),
    );
    return ReminderOut.fromJson(json);
  }

  /// Dismisses a reminder via POST /api/v1/reminders/{reminder_id}/dismiss.
  Future<ReminderOut> dismissReminder(String reminderId) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/reminders/$reminderId/dismiss',
    );
    return ReminderOut.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Alarms (/api/v1/alarms)
  // ---------------------------------------------------------------------------

  /// Lists alarms via GET /api/v1/alarms.
  Future<AlarmListOut> listAlarms({
    bool? enabled,
    String? status,
    int skip = 0,
    int limit = 50,
  }) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/alarms',
      queryParameters: {
        if (enabled != null) 'enabled': enabled.toString(),
        if (status != null) 'status': status,
        'skip': skip.toString(),
        'limit': limit.toString(),
      },
    );
    return AlarmListOut.fromJson(json);
  }

  /// Creates an alarm via POST /api/v1/alarms.
  Future<AlarmOut> createAlarm(AlarmCreate payload) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/alarms',
      body: payload.toJson(),
      expectedStatus: 201,
    );
    return AlarmOut.fromJson(json);
  }

  /// Fetches an alarm by ID via GET /api/v1/alarms/{alarm_id}.
  Future<AlarmOut> getAlarm(String alarmId) async {
    final json = await _requestJson('GET', '/api/v1/alarms/$alarmId');
    return AlarmOut.fromJson(json);
  }

  /// Updates an alarm via PATCH /api/v1/alarms/{alarm_id}.
  Future<AlarmOut> updateAlarm(String alarmId, AlarmUpdate payload) async {
    final json = await _requestJson(
      'PATCH',
      '/api/v1/alarms/$alarmId',
      body: payload.toJson(),
    );
    return AlarmOut.fromJson(json);
  }

  /// Soft-deletes an alarm via DELETE /api/v1/alarms/{alarm_id}.
  Future<void> deleteAlarm(String alarmId) async {
    await _deleteNoContent('/api/v1/alarms/$alarmId');
  }

  /// Snoozes an alarm via POST /api/v1/alarms/{alarm_id}/snooze.
  Future<AlarmOut> snoozeAlarm(
    String alarmId, {
    SnoozeRequest? payload,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/alarms/$alarmId/snooze',
      body: (payload ?? const SnoozeRequest()).toJson(),
    );
    return AlarmOut.fromJson(json);
  }

  /// Acknowledges an alarm via POST /api/v1/alarms/{alarm_id}/acknowledge.
  Future<AlarmOut> acknowledgeAlarm(String alarmId) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/alarms/$alarmId/acknowledge',
    );
    return AlarmOut.fromJson(json);
  }

  /// Dismisses an alarm via POST /api/v1/alarms/{alarm_id}/dismiss.
  Future<AlarmOut> dismissAlarm(String alarmId) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/alarms/$alarmId/dismiss',
    );
    return AlarmOut.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Routines (/api/v1/routines)
  // ---------------------------------------------------------------------------

  /// Lists routines via GET /api/v1/routines.
  Future<RoutineListOut> listRoutines({
    bool? enabled,
    int skip = 0,
    int limit = 50,
  }) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/routines',
      queryParameters: {
        if (enabled != null) 'enabled': enabled.toString(),
        'skip': skip.toString(),
        'limit': limit.toString(),
      },
    );
    return RoutineListOut.fromJson(json);
  }

  /// Creates a routine via POST /api/v1/routines.
  Future<RoutineOut> createRoutine(RoutineCreate payload) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/routines',
      body: payload.toJson(),
      expectedStatus: 201,
    );
    return RoutineOut.fromJson(json);
  }

  /// Fetches a routine by ID via GET /api/v1/routines/{routine_id}.
  Future<RoutineOut> getRoutine(String routineId) async {
    final json = await _requestJson('GET', '/api/v1/routines/$routineId');
    return RoutineOut.fromJson(json);
  }

  /// Updates a routine via PATCH /api/v1/routines/{routine_id}.
  Future<RoutineOut> updateRoutine(
    String routineId,
    RoutineUpdate payload,
  ) async {
    final json = await _requestJson(
      'PATCH',
      '/api/v1/routines/$routineId',
      body: payload.toJson(),
    );
    return RoutineOut.fromJson(json);
  }

  /// Soft-deletes a routine via DELETE /api/v1/routines/{routine_id}.
  Future<void> deleteRoutine(String routineId) async {
    await _deleteNoContent('/api/v1/routines/$routineId');
  }

  /// Manually triggers a routine via POST /api/v1/routines/{routine_id}/run.
  Future<NotificationEventOut> runRoutineNow(String routineId) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/routines/$routineId/run',
    );
    return NotificationEventOut.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Notifications Backlog (/api/v1/notifications)
  // ---------------------------------------------------------------------------

  /// Lists notification backlog events via GET /api/v1/notifications.
  Future<NotificationListOut> listNotifications({
    String? status,
    String? sourceType,
    bool unreadOnly = false,
    int skip = 0,
    int limit = 50,
  }) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/notifications',
      queryParameters: {
        if (status != null) 'status': status,
        if (sourceType != null) 'source_type': sourceType,
        'unread_only': unreadOnly.toString(),
        'skip': skip.toString(),
        'limit': limit.toString(),
      },
    );
    return NotificationListOut.fromJson(json);
  }

  /// Clears all active notifications via POST /api/v1/notifications/clear-all.
  Future<NotificationClearResponse> clearAllNotifications() async {
    final json = await _requestJson('POST', '/api/v1/notifications/clear-all');
    return NotificationClearResponse.fromJson(json);
  }

  /// Marks unread notifications read via POST /api/v1/notifications/mark-all-read.
  Future<NotificationMarkReadResponse> markAllNotificationsRead() async {
    final json =
        await _requestJson('POST', '/api/v1/notifications/mark-all-read');
    return NotificationMarkReadResponse.fromJson(json);
  }

  /// Marks a notification read via POST /api/v1/notifications/{event_id}/read.
  Future<NotificationEventOut> markNotificationRead(String eventId) async {
    final json = await _requestJson('POST', '/api/v1/notifications/$eventId/read');
    return NotificationEventOut.fromJson(json);
  }

  /// Acknowledges a notification via POST /api/v1/notifications/{event_id}/acknowledge.
  Future<NotificationEventOut> acknowledgeNotification(
    String eventId, {
    AcknowledgeRequest? payload,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/notifications/$eventId/acknowledge',
      body: (payload ?? const AcknowledgeRequest()).toJson(),
    );
    return NotificationEventOut.fromJson(json);
  }

  /// Dismisses a notification via POST /api/v1/notifications/{event_id}/dismiss.
  Future<NotificationEventOut> dismissNotification(String eventId) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/notifications/$eventId/dismiss',
    );
    return NotificationEventOut.fromJson(json);
  }

  /// Snoozes a notification via POST /api/v1/notifications/{event_id}/snooze.
  Future<NotificationEventOut> snoozeNotification(
    String eventId, {
    SnoozeRequest? payload,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/notifications/$eventId/snooze',
      body: (payload ?? const SnoozeRequest()).toJson(),
    );
    return NotificationEventOut.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // D9 Deterministic Action Engine & Safety Controls (/api/v1/tools)
  // ---------------------------------------------------------------------------

  /// Lists registered D9 tools and permanently disabled Risk 3 capabilities.
  Future<ToolCatalogOut> getToolCatalog() async {
    final json = await _requestJson('GET', '/api/v1/tools/catalog');
    return ToolCatalogOut.fromJson(json);
  }

  /// Reads combined profile D9 risk policy, global Kill Switch, and Web config.
  Future<ToolPolicyOut> getToolPolicy() async {
    final json = await _requestJson('GET', '/api/v1/tools/policy');
    return ToolPolicyOut.fromJson(json);
  }

  /// Updates profile-scoped D9 risk policy thresholds via PATCH /api/v1/tools/policy.
  Future<ToolPolicyOut> updateToolPolicy(ToolPolicyUpdate payload) async {
    final json = await _requestJson(
      'PATCH',
      '/api/v1/tools/policy',
      body: payload.toJson(),
    );
    return ToolPolicyOut.fromJson(json);
  }

  /// Reads persistent Global Tool Kill Switch status via GET /api/v1/tools/kill-switch.
  Future<KillSwitchStateOut> getKillSwitch({bool useHostAdmin = false}) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/tools/kill-switch',
      admin: useHostAdmin,
    );
    return KillSwitchStateOut.fromJson(json);
  }

  /// Engages (session/admin) or disengages (Host Admin only) the Global Kill Switch.
  Future<KillSwitchStateOut> setKillSwitch(
    KillSwitchRequest payload, {
    bool useHostAdmin = false,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/tools/kill-switch',
      body: payload.toJson(),
      admin: useHostAdmin || !payload.enabled,
    );
    return KillSwitchStateOut.fromJson(json);
  }

  /// Updates Web retrieval provider routing and ACL-protected search API key (Host Admin).
  Future<WebConfigOut> updateWebConfig(WebConfigUpdateRequest payload) async {
    final json = await _requestJson(
      'PUT',
      '/api/v1/tools/web-config',
      body: payload.toJson(),
      admin: true,
    );
    return WebConfigOut.fromJson(json);
  }

  /// Clears device-local Web Search API key file (Host Admin).
  Future<WebApiKeyClearOut> clearWebApiKey() async {
    final json = await _requestJson(
      'DELETE',
      '/api/v1/tools/web-config/api-key',
      admin: true,
    );
    return WebApiKeyClearOut.fromJson(json);
  }

  /// Lists redacted D9 tool audit logs via GET /api/v1/tools/audit.
  Future<ToolAuditLogListOut> listToolAuditLogs({int limit = 50}) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/tools/audit',
      queryParameters: {'limit': limit.toString()},
    );
    return ToolAuditLogListOut.fromJson(json);
  }

  /// Lists D9 tool confirmations for the active profile via GET /api/v1/tools/confirmations.
  Future<ToolConfirmationListOut> listToolConfirmations({
    String? conversationId,
    String? status = 'pending',
  }) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/tools/confirmations',
      queryParameters: {
        if (conversationId != null) 'conversation_id': conversationId,
        if (status != null) 'status': status,
      },
    );
    return ToolConfirmationListOut.fromJson(json);
  }

  /// Atomically approves or rejects a pending D9 confirmation.
  Future<ToolConfirmationResolveResponse> resolveToolConfirmation(
    String confirmationId,
    ToolConfirmationResolveRequest payload,
  ) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/tools/confirmations/$confirmationId/resolve',
      body: payload.toJson(),
    );
    return ToolConfirmationResolveResponse.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Local Voice Pipeline (/api/v1/voice)
  // ---------------------------------------------------------------------------

  /// Returns truthful readiness status across STT, VAD, and TTS subsystems.
  Future<VoiceStatusOut> getVoiceStatus() async {
    final json = await _requestJson('GET', '/api/v1/voice/status');
    return VoiceStatusOut.fromJson(json);
  }

  /// Lists locally discovered TTS voices via GET /api/v1/voice/voices.
  Future<VoiceCatalogOut> listVoices() async {
    final json = await _requestJson('GET', '/api/v1/voice/voices');
    return VoiceCatalogOut.fromJson(json);
  }

  /// Retrieves per-Profile voice behavior and privacy preferences.
  Future<VoiceSettingsOut> getVoiceSettings() async {
    final json = await _requestJson('GET', '/api/v1/voice/settings');
    return VoiceSettingsOut.fromJson(json);
  }

  /// Partially updates per-Profile voice settings via PATCH /api/v1/voice/settings.
  Future<VoiceSettingsOut> updateVoiceSettings(VoiceSettingsUpdate payload) async {
    final json = await _requestJson(
      'PATCH',
      '/api/v1/voice/settings',
      body: payload.toJson(),
    );
    return VoiceSettingsOut.fromJson(json);
  }

  /// Transcribes bounded ephemeral dictation audio via POST /api/v1/voice/transcribe.
  Future<VoiceTranscribeOut> transcribeAudio(VoiceTranscribeRequest payload) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/voice/transcribe',
      body: payload.toJson(),
    );
    return VoiceTranscribeOut.fromJson(json);
  }

  /// Synthesizes text to an in-memory WAV payload via POST /api/v1/voice/synthesize.
  Future<VoiceSynthesizeOut> synthesizeSpeech(VoiceSynthesizeRequest payload) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/voice/synthesize',
      body: payload.toJson(),
    );
    return VoiceSynthesizeOut.fromJson(json);
  }

  void close() {
    _httpClient.close();
  }
}
