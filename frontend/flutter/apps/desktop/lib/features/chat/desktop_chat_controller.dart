import 'dart:async';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter/foundation.dart';

/// Connection status between the Flutter desktop client and the Local AI Runtime.
enum RuntimeConnectionStatus {
  unconnected,
  connecting,
  connected,
  unauthorized,
  reconnecting,
  error,
}

/// Generation lifecycle state of the assistant chat stream.
enum ChatGenerationState {
  idle,
  generating,
  cancelled,
  error,
}

typedef CompanionClientFactory = CompanionClient Function({
  required String baseUrl,
  CredentialStore? credentialStore,
});

/// Controller managing desktop conversation state, REST integration, and live SSE streaming.
class DesktopChatController extends ChangeNotifier {
  CompanionClient _client;
  final CompanionClientFactory? _clientFactory;

  RuntimeConnectionStatus _connectionStatus = RuntimeConnectionStatus.unconnected;
  ChatGenerationState _generationState = ChatGenerationState.idle;

  List<ConversationOut> _conversations = [];
  ConversationOut? _activeConversation;
  List<MessageOut> _messages = [];
  String _streamingText = '';
  String? _activeModelName;
  String? _errorMessage;

  StreamSubscription<SseEvent>? _currentStreamSubscription;
  Completer<void>? _turnCompleter;
  int _configEpoch = 0;
  int _turnSequenceToken = 0;
  int _loadSequenceToken = 0;
  bool _isDisposed = false;

  DesktopChatController({
    required CompanionClient client,
    CompanionClientFactory? clientFactory,
  })  : _client = client,
        _clientFactory = clientFactory;

  CompanionClient get client => _client;
  RuntimeConnectionStatus get connectionStatus => _connectionStatus;
  ChatGenerationState get generationState => _generationState;
  List<ConversationOut> get conversations => List.unmodifiable(_conversations);
  ConversationOut? get activeConversation => _activeConversation;
  List<MessageOut> get messages => List.unmodifiable(_messages);
  String get streamingText => _streamingText;
  String? get activeModelName => _activeModelName;
  String? get errorMessage => _errorMessage;

  bool get isGenerating => _generationState == ChatGenerationState.generating;
  bool get isConnected => _connectionStatus == RuntimeConnectionStatus.connected;
  bool get canSend => isConnected && !isGenerating;

  String get connectionStatusLabel {
    switch (_connectionStatus) {
      case RuntimeConnectionStatus.connected:
        return 'Runtime: Connected';
      case RuntimeConnectionStatus.unauthorized:
        return 'Runtime: Unauthorized';
      case RuntimeConnectionStatus.connecting:
        return 'Runtime: Connecting...';
      case RuntimeConnectionStatus.reconnecting:
        return 'Runtime: Reconnecting...';
      case RuntimeConnectionStatus.error:
        return 'Runtime: Error';
      case RuntimeConnectionStatus.unconnected:
        return 'Runtime: Standalone (Unconnected)';
    }
  }

  /// Updates runtime configuration authoritatively, discarding in-flight operations.
  Future<void> updateConfiguration({required String baseUrl, String? pairingToken}) async {
    if (_isDisposed) return;
    CompanionClient.validateBaseUrl(baseUrl);
    final currentEpoch = ++_configEpoch;

    if (isGenerating) {
      await cancelGeneration();
    }

    if (pairingToken != null && _client.credentialStore != null) {
      await _client.credentialStore!.writeToken(pairingToken.trim());
    }

    _client = _clientFactory != null
        ? _clientFactory(baseUrl: baseUrl, credentialStore: _client.credentialStore)
        : CompanionClient(
            baseUrl: baseUrl,
            credentialStore: _client.credentialStore,
          );

    _conversations = [];
    _activeConversation = null;
    _messages = [];
    _streamingText = '';
    _errorMessage = null;
    notifyListeners();

    await checkConnection();
    if (_configEpoch == currentEpoch && isConnected && !_isDisposed) {
      await loadConversations();
    }
  }

  /// Probes public health and protected auth to update connection status.
  Future<void> checkConnection() async {
    if (_isDisposed) return;
    final epoch = _configEpoch;
    _connectionStatus = RuntimeConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final health = await _client.getHealth();
      if (_configEpoch != epoch || _isDisposed) return;

      if (health.status == 'healthy') {
        // Health 200 proves runtime reachability only, NOT authorization.
        // Check if pairing credentials exist and verify them fail-closed.
        final token = await _client.credentialStore?.readToken();
        if (_configEpoch != epoch || _isDisposed) return;

        if (token == null || token.trim().isEmpty) {
          _connectionStatus = RuntimeConnectionStatus.unauthorized;
          _errorMessage = 'Pairing token is missing. Configure token in Settings.';
          _activeModelName = null;
          notifyListeners();
          return;
        }

        try {
          final auth = await _client.verifyAuth();
          if (_configEpoch != epoch || _isDisposed) return;

          if (auth.authenticated) {
            _connectionStatus = RuntimeConnectionStatus.connected;
            _errorMessage = null;

            try {
              final modelStatus = await _client.getModelStatus();
              if (_configEpoch != epoch || _isDisposed) return;
              _activeModelName = modelStatus.activeModel ?? 'default';
            } catch (_) {
              if (_configEpoch != epoch || _isDisposed) return;
              // Valid auth + unavailable model: retain connected/authorized status
              _activeModelName = 'Unavailable';
            }
          } else {
            _connectionStatus = RuntimeConnectionStatus.unauthorized;
            _errorMessage = auth.message.isNotEmpty ? auth.message : 'Authentication verification failed.';
            _activeModelName = null;
          }
        } on CompanionApiException catch (authEx) {
          if (_configEpoch != epoch || _isDisposed) return;
          _connectionStatus = RuntimeConnectionStatus.unauthorized;
          _errorMessage = authEx.message.isNotEmpty
              ? authEx.message
              : 'Authentication failed (HTTP ${authEx.statusCode}).';
          _activeModelName = null;
        } catch (authErr) {
          if (_configEpoch != epoch || _isDisposed) return;
          _connectionStatus = RuntimeConnectionStatus.unauthorized;
          _errorMessage = 'Authentication verification failed: $authErr';
          _activeModelName = null;
        }
      } else {
        _connectionStatus = RuntimeConnectionStatus.unconnected;
        _errorMessage = 'Runtime reported unhealthy status: ${health.status}';
        _activeModelName = null;
      }
    } catch (e) {
      if (_configEpoch != epoch || _isDisposed) return;
      _connectionStatus = RuntimeConnectionStatus.unconnected;
      _errorMessage = e.toString();
      _activeModelName = null;
    }

    if (!_isDisposed && _configEpoch == epoch) notifyListeners();
  }

  /// Loads available conversations from backend.
  Future<void> loadConversations() async {
    if (_isDisposed || !isConnected) return;
    try {
      final res = await _client.listConversations();
      if (_isDisposed) return;
      _conversations = res.items;

      if (_conversations.isNotEmpty && _activeConversation == null) {
        await selectConversation(_conversations.first);
      }
    } catch (_) {
      // Retain existing list on network glitch
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Switches active conversation thread and loads its authoritative message history.
  Future<void> selectConversation(ConversationOut conversation) async {
    if (_isDisposed) return;
    if (isGenerating) {
      throw StateError('Cannot switch conversation while turn generation is active.');
    }
    _activeConversation = conversation;
    _messages = [];
    _streamingText = '';
    _generationState = ChatGenerationState.idle;
    notifyListeners();

    await loadMessages(conversation.id);
  }

  /// Creates a new persistent conversation thread and selects it.
  ///
  /// Never fabricates fake local conversation records when backend calls fail.
  Future<void> createNewConversation({String title = 'New Conversation'}) async {
    if (_isDisposed) return;
    if (!isConnected) {
      _errorMessage = 'Cannot create conversation: Runtime is not connected and authorized.';
      notifyListeners();
      throw StateError('Runtime is not connected.');
    }
    try {
      final created = await _client.createConversation(title: title);
      _conversations = [created, ..._conversations];
      await selectConversation(created);
    } catch (e) {
      _errorMessage = 'Failed to create conversation: $e';
      if (!_isDisposed) notifyListeners();
      rethrow;
    }
  }

  /// Fetches authoritative message history for a conversation.
  Future<void> loadMessages(String conversationId, {int? expectedTurnToken}) async {
    if (_isDisposed) return;
    final loadToken = ++_loadSequenceToken;
    try {
      final res = await _client.listMessages(conversationId);
      if (_isDisposed) return;
      if (loadToken != _loadSequenceToken) return;
      if (expectedTurnToken != null && expectedTurnToken != _turnSequenceToken) return;

      if (_activeConversation?.id == conversationId) {
        _messages = res.items;
      }
    } catch (_) {}
    if (!_isDisposed) notifyListeners();
  }

  /// Submits a user prompt, adds optimistic turns, and consumes streaming tokens.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isGenerating || _isDisposed) return;
    if (!isConnected) {
      _errorMessage = 'Cannot send message: Runtime is not connected and authorized.';
      notifyListeners();
      throw StateError('Cannot send message: Runtime is not connected.');
    }

    if (_activeConversation == null) {
      await createNewConversation();
    }
    final activeConv = _activeConversation;
    if (activeConv == null) return;

    final turnToken = ++_turnSequenceToken;
    final boundConvId = activeConv.id;
    final clientMessageId = UuidUtils.generateV4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final userMsg = MessageOut(
      id: 'local-user-${UuidUtils.generateV4()}',
      conversationId: boundConvId,
      sender: 'user',
      content: trimmed,
      status: 'completed',
      sequenceNo: _messages.length + 1,
      clientMessageId: clientMessageId,
      createdAt: nowIso,
    );

    final assistantMsg = MessageOut(
      id: 'local-asst-${UuidUtils.generateV4()}',
      conversationId: boundConvId,
      sender: 'assistant',
      content: '',
      status: 'generating',
      sequenceNo: _messages.length + 2,
      createdAt: nowIso,
    );

    _messages = [..._messages, userMsg, assistantMsg];
    _streamingText = '';
    _generationState = ChatGenerationState.generating;
    _errorMessage = null;
    notifyListeners();

    final completer = Completer<void>();
    _turnCompleter = completer;

    try {
      final stream = _client.sendMessageStream(
        boundConvId,
        MessageSend(
          userText: trimmed,
          clientMessageId: clientMessageId,
        ),
      );

      _currentStreamSubscription = stream.listen(
        (event) {
          if (_isDisposed || _turnSequenceToken != turnToken || _activeConversation?.id != boundConvId) return;
          if (event is SseTokenEvent) {
            _streamingText += event.token;
            if (_messages.isNotEmpty && _messages.last.sender == 'assistant') {
              final last = _messages.last;
              _messages = [
                ..._messages.sublist(0, _messages.length - 1),
                MessageOut(
                  id: last.id,
                  conversationId: last.conversationId,
                  sender: last.sender,
                  content: _streamingText,
                  status: 'generating',
                  sequenceNo: last.sequenceNo,
                  createdAt: last.createdAt,
                ),
              ];
            }
            notifyListeners();
          } else if (event is SseDoneEvent) {
            _generationState = ChatGenerationState.idle;
            _streamingText = '';
            _finalizeTurn(boundConvId, turnToken);
          } else if (event is SseErrorEvent) {
            _generationState = ChatGenerationState.error;
            _errorMessage = event.message;
            _finalizeTurn(boundConvId, turnToken);
          }
        },
        onError: (Object err) {
          if (_isDisposed || _turnSequenceToken != turnToken || _activeConversation?.id != boundConvId) return;
          _generationState = ChatGenerationState.error;
          if (err is CompanionApiException) {
            _errorMessage = err.message;
          } else {
            _errorMessage = err.toString();
          }
          _finalizeTurn(boundConvId, turnToken);
        },
        onDone: () {
          if (_isDisposed || _turnSequenceToken != turnToken || _activeConversation?.id != boundConvId) return;
          if (_generationState == ChatGenerationState.generating) {
            _generationState = ChatGenerationState.idle;
            _streamingText = '';
            _finalizeTurn(boundConvId, turnToken);
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      _generationState = ChatGenerationState.error;
      _errorMessage = e.toString();
      _finalizeTurn(boundConvId, turnToken);
    }

    await completer.future;
  }

  void _finalizeTurn(String conversationId, int turnToken) {
    if (_turnSequenceToken != turnToken) return;
    _currentStreamSubscription = null;
    if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
      _turnCompleter!.complete();
    }
    loadMessages(conversationId, expectedTurnToken: turnToken);
  }

  /// Cancels active stream generation on user demand.
  Future<void> cancelGeneration() async {
    if (!isGenerating) return;

    final turnToken = ++_turnSequenceToken;
    _generationState = ChatGenerationState.cancelled;
    _streamingText = '';

    final sub = _currentStreamSubscription;
    _currentStreamSubscription = null;

    if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
      _turnCompleter!.complete();
    }

    unawaited(sub?.cancel());

    if (_activeConversation != null) {
      await loadMessages(_activeConversation!.id, expectedTurnToken: turnToken);
    }
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _currentStreamSubscription?.cancel();
    super.dispose();
  }
}
