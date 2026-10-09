import 'dart:async';
import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:flutter/foundation.dart';

/// Connection status between the Flutter desktop client and the Local AI Runtime.
enum RuntimeConnectionStatus {
  unconnected,
  connecting,
  connected,
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

/// Controller managing desktop conversation state, REST integration, and live SSE streaming.
class DesktopChatController extends ChangeNotifier {
  final CompanionClient client;

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
  bool _isDisposed = false;

  DesktopChatController({
    required this.client,
  });

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

  String get connectionStatusLabel {
    switch (_connectionStatus) {
      case RuntimeConnectionStatus.connected:
        return 'Runtime: Connected';
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

  /// Probes public health and protected auth to update connection status.
  Future<void> checkConnection() async {
    if (_isDisposed) return;
    _connectionStatus = RuntimeConnectionStatus.connecting;
    notifyListeners();

    try {
      final health = await client.getHealth();
      if (health.status == 'healthy') {
        try {
          final auth = await client.verifyAuth();
          if (auth.authenticated) {
            _connectionStatus = RuntimeConnectionStatus.connected;
          } else {
            _connectionStatus = RuntimeConnectionStatus.error;
            _errorMessage = 'Authentication verification failed';
          }
        } catch (_) {
          // Public health succeeded, pairing token missing or unverified
          _connectionStatus = RuntimeConnectionStatus.connected;
        }

        try {
          final modelStatus = await client.getModelStatus();
          _activeModelName = modelStatus.activeModel ?? 'default';
        } catch (_) {}
      } else {
        _connectionStatus = RuntimeConnectionStatus.unconnected;
      }
    } catch (e) {
      _connectionStatus = RuntimeConnectionStatus.unconnected;
      _errorMessage = e.toString();
    }

    if (!_isDisposed) notifyListeners();
  }

  /// Loads available conversations from backend.
  Future<void> loadConversations() async {
    if (_isDisposed) return;
    try {
      final res = await client.listConversations();
      _conversations = res.items;

      if (_conversations.isNotEmpty && _activeConversation == null) {
        await selectConversation(_conversations.first);
      }
    } catch (_) {
      // Offline fallback: keep existing list or stay empty
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Switches active conversation thread and loads its authoritative message history.
  Future<void> selectConversation(ConversationOut conversation) async {
    if (_isDisposed) return;
    _activeConversation = conversation;
    _messages = [];
    _streamingText = '';
    _generationState = ChatGenerationState.idle;
    notifyListeners();

    await loadMessages(conversation.id);
  }

  /// Creates a new persistent conversation thread and selects it.
  Future<void> createNewConversation({String title = 'New Conversation'}) async {
    if (_isDisposed) return;
    try {
      final created = await client.createConversation(title: title);
      _conversations = [created, ..._conversations];
      await selectConversation(created);
    } catch (e) {
      // Local fallback in standalone/unconnected mode
      final fallback = ConversationOut(
        id: 'local-${UuidUtils.generateV4()}',
        title: title,
        characterId: 'default',
        ownerId: 'local_owner',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        messageCount: 0,
      );
      _conversations = [fallback, ..._conversations];
      await selectConversation(fallback);
    }
  }

  /// Fetches authoritative message history for a conversation.
  Future<void> loadMessages(String conversationId) async {
    if (_isDisposed) return;
    try {
      final res = await client.listMessages(conversationId);
      _messages = res.items;
    } catch (_) {}
    if (!_isDisposed) notifyListeners();
  }

  /// Submits a user prompt, adds optimistic turns, and consumes streaming tokens.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isGenerating || _isDisposed) return;

    if (_activeConversation == null) {
      await createNewConversation();
    }
    final activeConv = _activeConversation;
    if (activeConv == null) return;

    final clientMessageId = UuidUtils.generateV4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final userMsg = MessageOut(
      id: 'local-user-${UuidUtils.generateV4()}',
      conversationId: activeConv.id,
      sender: 'user',
      content: trimmed,
      status: 'completed',
      sequenceNo: _messages.length + 1,
      clientMessageId: clientMessageId,
      createdAt: nowIso,
    );

    final assistantMsg = MessageOut(
      id: 'local-asst-${UuidUtils.generateV4()}',
      conversationId: activeConv.id,
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
      final stream = client.sendMessageStream(
        activeConv.id,
        MessageSend(
          userText: trimmed,
          clientMessageId: clientMessageId,
        ),
      );

      _currentStreamSubscription = stream.listen(
        (event) {
          if (_isDisposed) return;
          if (event is SseTokenEvent) {
            _streamingText += event.token;
            // Update live content on placeholder message
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
            _finalizeTurn(activeConv.id);
          } else if (event is SseErrorEvent) {
            _generationState = ChatGenerationState.error;
            _errorMessage = event.message;
            _finalizeTurn(activeConv.id);
          }
        },
        onError: (Object err) {
          if (_isDisposed) return;
          _generationState = ChatGenerationState.error;
          if (err is CompanionApiException) {
            _errorMessage = err.message;
          } else {
            _errorMessage = err.toString();
          }
          _finalizeTurn(activeConv.id);
        },
        onDone: () {
          if (_isDisposed) return;
          if (_generationState == ChatGenerationState.generating) {
            _generationState = ChatGenerationState.idle;
            _streamingText = '';
            _finalizeTurn(activeConv.id);
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      _generationState = ChatGenerationState.error;
      _errorMessage = e.toString();
      _finalizeTurn(activeConv.id);
    }

    await completer.future;
  }

  void _finalizeTurn(String conversationId) {
    _currentStreamSubscription = null;
    if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
      _turnCompleter!.complete();
    }
    // Reload authoritative message history from backend to ensure consistent sequence numbers
    loadMessages(conversationId);
  }

  /// Cancels active stream generation on user demand.
  Future<void> cancelGeneration() async {
    if (!isGenerating) return;

    await _currentStreamSubscription?.cancel();
    _currentStreamSubscription = null;
    _generationState = ChatGenerationState.cancelled;
    _streamingText = '';

    if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
      _turnCompleter!.complete();
    }

    if (_activeConversation != null) {
      await loadMessages(_activeConversation!.id);
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
