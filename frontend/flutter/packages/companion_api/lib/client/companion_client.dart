import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../auth/credential_store.dart';
import '../dto/auth_dto.dart';
import '../dto/conversation_dto.dart';
import '../dto/health_dto.dart';
import '../dto/message_dto.dart';
import '../dto/model_status_dto.dart';
import '../dto/sse_event_dto.dart';
import '../dto/system_status_dto.dart';
import '../transport/sse_parser.dart';
import 'companion_api_exception.dart';

/// Typed client communicating with the Local AI Runtime.
class CompanionClient {
  final Uri baseUri;
  final http.Client _httpClient;
  final CredentialStore? credentialStore;
  final SseStreamParser _sseParser;

  CompanionClient({
    String baseUrl = 'http://127.0.0.1:8000',
    http.Client? httpClient,
    this.credentialStore,
    SseStreamParser? sseParser,
  })  : baseUri = validateBaseUrl(baseUrl),
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

  Future<Map<String, String>> _buildHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth && credentialStore != null) {
      final token = await credentialStore!.readToken();
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

  Never _handleErrorResponse(http.Response response) {
    String? code;
    String message = 'HTTP ${response.statusCode}';
    dynamic details;

    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map) {
        code = body['code']?.toString() ?? body['detail']?.toString();
        message = body['message']?.toString() ?? body['detail']?.toString() ?? message;
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
  Future<AuthVerifyResponse> verifyAuth() async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/auth/verify');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.post(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return AuthVerifyResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Retrieves host machine hardware profile and runtime status via GET /api/v1/system/status.
  Future<SystemStatusResponse> getSystemStatus() async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/system/status');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return SystemStatusResponse.fromJson(Map<String, dynamic>.from(json as Map));
    }
    _handleErrorResponse(response);
  }

  /// Retrieves model status and runtime state via GET /api/v1/models.
  Future<ModelStatusResponse> getModelStatus() async {
    final uri = baseUri.replace(path: '${baseUri.path}/api/v1/models');
    final headers = await _buildHeaders(requiresAuth: true);
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final dynamic json = jsonDecode(response.body);
      return ModelStatusResponse.fromJson(Map<String, dynamic>.from(json as Map));
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

  void close() {
    _httpClient.close();
  }
}
