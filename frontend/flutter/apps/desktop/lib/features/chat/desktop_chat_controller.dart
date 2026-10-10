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

/// Categorized model availability for truthful UI telemetry.
enum ModelRuntimeStateCategory {
  unreachable,
  pairingRequired,
  authenticatedNoModel,
  modelUnloaded,
  modelLoading,
  modelReady,
  modelSleeping,
  modelLoadFailed,
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
  ModelStatusResponse? _modelStatus;
  String? _errorMessage;
  bool _isLoadingConversations = false;
  String? _conversationError;

  StreamSubscription<SseEvent>? _currentStreamSubscription;
  Completer<bool>? _turnCompleter;
  int _configEpoch = 0;
  int _turnSequenceToken = 0;
  int _loadSequenceToken = 0;
  bool _isDisposed = false;
  bool _isCreatingConversation = false;
  bool _isAwaitingAcceptance = false;
  final Set<String> _userRenamedConversationIds = <String>{};
  final Map<String, Future<void>> _pendingRenameFutures = <String, Future<void>>{};

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
  ModelStatusResponse? get modelStatus => _modelStatus;
  String? get errorMessage => _errorMessage;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isCreatingConversation => _isCreatingConversation;
  bool get isAwaitingAcceptance => _isAwaitingAcceptance;
  String? get conversationError => _conversationError;

  bool get isGenerating =>
      _generationState == ChatGenerationState.generating || _isAwaitingAcceptance;
  bool get isConnected => _connectionStatus == RuntimeConnectionStatus.connected;
  bool get canSend =>
      isConnected && !isGenerating && !_isCreatingConversation;

  /// Filtered conversations for the history drawer matching Web Phase 8C logic:
  /// Hides old, inactive, untouched empty drafts from the drawer without deleting database records.
  /// Preserves the currently active empty draft.
  List<ConversationOut> get drawerConversations {
    final activeId = _activeConversation?.id;
    final activeMsgCount = _messages.length;
    return _conversations.where((c) {
      final count = c.id == activeId ? activeMsgCount : c.messageCount;
      final isUntouchedTitle = c.title.isEmpty ||
          c.title == 'New Conversation' ||
          c.title.startsWith('New Conversation');
      final isOldEmptyDraft = isUntouchedTitle && count == 0 && c.id != activeId;
      return !isOldEmptyDraft;
    }).toList();
  }

  ModelRuntimeStateCategory get modelStateCategory {
    if (_connectionStatus == RuntimeConnectionStatus.unconnected) {
      return ModelRuntimeStateCategory.unreachable;
    }
    if (_connectionStatus == RuntimeConnectionStatus.unauthorized) {
      return ModelRuntimeStateCategory.pairingRequired;
    }
    if (_connectionStatus != RuntimeConnectionStatus.connected) {
      return ModelRuntimeStateCategory.unreachable;
    }

    final ms = _modelStatus;
    if (ms == null) {
      return ModelRuntimeStateCategory.authenticatedNoModel;
    }

    if (ms.lastRuntimeError != null && ms.lastRuntimeError!.isNotEmpty) {
      return ModelRuntimeStateCategory.modelLoadFailed;
    }

    final state = ms.runtimeState.toUpperCase();
    if (state == 'MODEL_READY') {
      return ModelRuntimeStateCategory.modelReady;
    }
    if (state == 'MODEL_SLEEPING') {
      return ModelRuntimeStateCategory.modelSleeping;
    }
    if (state == 'MODEL_LOADING' || state == 'SERVER_STARTING') {
      return ModelRuntimeStateCategory.modelLoading;
    }
    if (state == 'MODEL_ERROR' || state == 'SERVER_ERROR' || state == 'LOAD_FAILED') {
      return ModelRuntimeStateCategory.modelLoadFailed;
    }
    if (state == 'MODEL_UNLOADED' || state == 'SERVER_STOPPED') {
      return ModelRuntimeStateCategory.modelUnloaded;
    }

    if (ms.modelLoaded && ms.modelAwake) {
      return ModelRuntimeStateCategory.modelReady;
    }
    if (ms.modelLoaded && !ms.modelAwake) {
      return ModelRuntimeStateCategory.modelSleeping;
    }

    return ModelRuntimeStateCategory.modelUnloaded;
  }

  String get modelStatusLabel {
    switch (modelStateCategory) {
      case ModelRuntimeStateCategory.unreachable:
        return 'Offline';
      case ModelRuntimeStateCategory.pairingRequired:
        return 'Pairing Required';
      case ModelRuntimeStateCategory.authenticatedNoModel:
        return _activeModelName ?? 'No Model';
      case ModelRuntimeStateCategory.modelReady:
        return _modelStatus?.activeModel ?? _activeModelName ?? 'Ready';
      case ModelRuntimeStateCategory.modelSleeping:
        return '${_modelStatus?.activeModel ?? _activeModelName ?? "Model"} (Sleeping)';
      case ModelRuntimeStateCategory.modelLoading:
        return 'Loading...';
      case ModelRuntimeStateCategory.modelUnloaded:
        return 'Unloaded';
      case ModelRuntimeStateCategory.modelLoadFailed:
        return 'Load Failed';
    }
  }

  String get modelStatusDescription {
    switch (modelStateCategory) {
      case ModelRuntimeStateCategory.unreachable:
        return 'Cannot connect to Local AI Runtime.';
      case ModelRuntimeStateCategory.pairingRequired:
        return 'Pairing token required. Configure credentials in Settings.';
      case ModelRuntimeStateCategory.authenticatedNoModel:
        return 'Authenticated with runtime. No active model configured.';
      case ModelRuntimeStateCategory.modelReady:
        return 'Local model is active in memory and ready for generation.';
      case ModelRuntimeStateCategory.modelSleeping:
        return 'Model is sleeping to preserve VRAM; wakes on next prompt.';
      case ModelRuntimeStateCategory.modelLoading:
        return 'Model weights are currently loading into memory.';
      case ModelRuntimeStateCategory.modelUnloaded:
        return 'No model is currently loaded in memory. Turns trigger on-demand load.';
      case ModelRuntimeStateCategory.modelLoadFailed:
        return _modelStatus?.lastRuntimeError ?? 'Failed to load local model weights.';
    }
  }

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
              _modelStatus = modelStatus;
              _activeModelName = modelStatus.activeModel ?? 'default';
            } catch (_) {
              if (_configEpoch != epoch || _isDisposed) return;
              // Valid auth + unavailable model: retain connected/authorized status
              _modelStatus = null;
              _activeModelName = 'Unavailable';
            }

            if (!_isDisposed && _configEpoch == epoch) {
              await loadConversations();
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
    _isLoadingConversations = true;
    _conversationError = null;
    notifyListeners();

    try {
      final res = await _client.listConversations();
      if (_isDisposed) return;
      _conversations = res.items;

      if (_conversations.isNotEmpty && _activeConversation == null) {
        await selectConversation(_conversations.first);
      }
    } catch (e) {
      if (_isDisposed) return;
      _conversationError = e.toString();
    } finally {
      if (!_isDisposed) {
        _isLoadingConversations = false;
        notifyListeners();
      }
    }
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
  /// Creates a new persistent conversation thread and selects it.
  ///
  /// Reuses existing untouched empty draft conversation if already active (matching Web Phase 8C).
  /// Enforces synchronous transition lock to prevent duplicate creation on rapid clicks.
  /// Never fabricates fake local conversation records when backend calls fail.
  Future<void> createNewConversation({String title = 'New Conversation'}) async {
    if (_isDisposed) return;
    if (_isCreatingConversation) return;
    if (!isConnected) {
      _errorMessage = 'Cannot create conversation: Runtime is not connected and authorized.';
      notifyListeners();
      throw StateError('Runtime is not connected.');
    }

    // Replicate React Web AssistantView.tsx (Phase 8C):
    // If the active conversation is already an untouched empty draft, reuse it rather than POSTing another row.
    final isCurrentEmptyDraft = _activeConversation != null &&
        (_activeConversation!.title == 'New Conversation' ||
            _activeConversation!.title.isEmpty ||
            _activeConversation!.title == title) &&
        _messages.isEmpty &&
        _activeConversation!.messageCount == 0;
    if (isCurrentEmptyDraft) {
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isCreatingConversation = true;
    notifyListeners();
    try {
      final created = await _client.createConversation(title: title);
      _conversations = [created, ..._conversations];
      await selectConversation(created);
    } catch (e) {
      _errorMessage = 'Failed to create conversation: $e';
      if (!_isDisposed) notifyListeners();
      rethrow;
    } finally {
      _isCreatingConversation = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Deletes a conversation thread by ID.
  ///
  /// Fails closed if runtime is not connected, or if deleting active thread during generation.
  Future<void> deleteConversation(String conversationId) async {
    if (_isDisposed) return;
    if (!isConnected) {
      _errorMessage = 'Cannot delete conversation: Runtime is not connected and authorized.';
      notifyListeners();
      throw StateError('Runtime is not connected.');
    }
    if (isGenerating && _activeConversation?.id == conversationId) {
      throw StateError('Cannot delete active conversation while turn generation is active.');
    }

    try {
      await _client.deleteConversation(conversationId);
      _conversations = _conversations.where((c) => c.id != conversationId).toList();
      if (_activeConversation?.id == conversationId) {
        if (_conversations.isNotEmpty) {
          await selectConversation(_conversations.first);
        } else {
          _activeConversation = null;
          _messages = [];
          _streamingText = '';
          _generationState = ChatGenerationState.idle;
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to delete conversation: $e';
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

  /// Submits a user prompt, adds optimistic turns upon server acceptance, and consumes streaming tokens.
  ///
  /// Returns `true` if the turn was accepted by the runtime and streaming commenced/completed;
  /// returns `false` if rejected before acceptance (preserving the user's draft in the composer).
  Future<bool> sendMessage(
    String text, {
    void Function()? onAccepted,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty ||
        isGenerating ||
        _isAwaitingAcceptance ||
        _isDisposed ||
        _isCreatingConversation) {
      return false;
    }
    if (!isConnected) {
      _errorMessage = 'Cannot send message: Runtime is not connected and authorized.';
      notifyListeners();
      throw StateError('Cannot send message: Runtime is not connected.');
    }

    // If no active conversation exists, create and select one BEFORE entering
    // the turn-awaiting phase to prevent self-deadlock with selectConversation's
    // isGenerating guard.
    if (_activeConversation == null) {
      try {
        await createNewConversation();
      } catch (e) {
        _errorMessage = 'Failed to prepare conversation: $e';
        if (!_isDisposed) notifyListeners();
        return false;
      }
    }

    final activeConv = _activeConversation;
    if (activeConv == null) {
      _errorMessage = 'No active conversation available.';
      if (!_isDisposed) notifyListeners();
      return false;
    }

    _isAwaitingAcceptance = true;
    _errorMessage = null;
    notifyListeners();

    // Phase 8C First-turn automatic conversation naming with deterministic fallback
    final isFirstTurn = _messages.isEmpty && (activeConv.messageCount == 0);
    final isUntouched = (activeConv.title.isEmpty ||
            activeConv.title == 'New Conversation' ||
            activeConv.title.startsWith('New Conversation')) &&
        !_userRenamedConversationIds.contains(activeConv.id);
    final String? deterministicTitle =
        (isFirstTurn && isUntouched) ? deriveDeterministicTitle(trimmed) : null;

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

    final completer = Completer<bool>();
    _turnCompleter = completer;
    bool hasBeenAccepted = false;

    void commitAcceptance() {
      if (hasBeenAccepted ||
          _isDisposed ||
          _turnSequenceToken != turnToken ||
          _activeConversation?.id != boundConvId) {
        return;
      }
      hasBeenAccepted = true;
      _isAwaitingAcceptance = false;
      _generationState = ChatGenerationState.generating;
      _errorMessage = null;

      // Commit messages to UI upon verified server acceptance
      _messages = [..._messages, userMsg, assistantMsg];
      _streamingText = '';

      // Optimistically apply deterministic fallback title if first turn
      if (deterministicTitle != null) {
        _activeConversation = ConversationOut(
          id: activeConv.id,
          title: deterministicTitle,
          characterId: activeConv.characterId,
          ownerId: activeConv.ownerId,
          createdAt: activeConv.createdAt,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          messageCount: _messages.length,
        );
        _conversations = _conversations
            .map((c) => c.id == boundConvId ? _activeConversation! : c)
            .toList();
        _pendingRenameFutures[boundConvId] =
            _persistDeterministicTitle(boundConvId, deterministicTitle);
      }

      onAccepted?.call();
      notifyListeners();
    }

    try {
      final stream = _client.sendMessageStream(
        boundConvId,
        MessageSend(
          userText: trimmed,
          clientMessageId: clientMessageId,
        ),
        onAccepted: commitAcceptance,
      );

      _currentStreamSubscription = stream.listen(
        (event) {
          if (_isDisposed ||
              _turnSequenceToken != turnToken ||
              _activeConversation?.id != boundConvId) {
            return;
          }
          if (!hasBeenAccepted) {
            commitAcceptance();
          }

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
            _finalizeTurn(boundConvId, turnToken, hasBeenAccepted: hasBeenAccepted);
            _maybeGenerateModelTitle(boundConvId, deterministicTitle);
            if (!completer.isCompleted) completer.complete(true);
          } else if (event is SseErrorEvent) {
            _generationState = ChatGenerationState.error;
            _errorMessage = event.message;
            _finalizeTurn(boundConvId, turnToken, hasBeenAccepted: hasBeenAccepted);
            if (!completer.isCompleted) completer.complete(hasBeenAccepted);
          }
        },
        onError: (Object err) {
          if (_isDisposed ||
              _turnSequenceToken != turnToken ||
              _activeConversation?.id != boundConvId) {
            return;
          }
          _isAwaitingAcceptance = false;
          _generationState = ChatGenerationState.error;

          if (err is CompanionApiException) {
            if (err.statusCode == 503) {
              final backendReason = _modelStatus?.lastRuntimeError;
              if (backendReason != null && backendReason.isNotEmpty) {
                _errorMessage = 'Local AI model unavailable (503): $backendReason';
              } else {
                _errorMessage =
                    'Local AI model unavailable (503): Model engine is not loaded or ready. Start the local LLM router or check model status in Settings.';
              }
            } else {
              _errorMessage = err.message;
            }
          } else {
            // Transport error before HTTP response or mid-stream
            if (!hasBeenAccepted) {
              _errorMessage =
                  'Connection interrupted before server confirmed message acceptance: $err. Please check connection and reload conversation before retrying.';
              // Reconcile uncertain outcome without blindly retrying
              loadMessages(boundConvId, expectedTurnToken: turnToken);
            } else {
              _errorMessage = err.toString();
            }
          }

          _finalizeTurn(boundConvId, turnToken, hasBeenAccepted: hasBeenAccepted);
          if (!completer.isCompleted) completer.complete(hasBeenAccepted);
        },
        onDone: () {
          if (_isDisposed ||
              _turnSequenceToken != turnToken ||
              _activeConversation?.id != boundConvId) {
            return;
          }
          if (_generationState == ChatGenerationState.generating) {
            _generationState = ChatGenerationState.idle;
            _streamingText = '';
            _finalizeTurn(boundConvId, turnToken, hasBeenAccepted: hasBeenAccepted);
            _maybeGenerateModelTitle(boundConvId, deterministicTitle);
          }
          if (!completer.isCompleted) completer.complete(hasBeenAccepted);
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isAwaitingAcceptance = false;
      _generationState = ChatGenerationState.error;
      if (e is CompanionApiException && e.statusCode == 503) {
        final backendReason = _modelStatus?.lastRuntimeError;
        if (backendReason != null && backendReason.isNotEmpty) {
          _errorMessage = 'Local AI model unavailable (503): $backendReason';
        } else {
          _errorMessage =
              'Local AI model unavailable (503): Model engine is not loaded or ready. Start the local LLM router or check model status in Settings.';
        }
      } else {
        _errorMessage = e.toString();
      }
      _finalizeTurn(boundConvId, turnToken, hasBeenAccepted: false);
      if (!completer.isCompleted) completer.complete(false);
    }

    return await completer.future;
  }

  void _finalizeTurn(String conversationId, int turnToken, {bool hasBeenAccepted = true}) {
    if (_turnSequenceToken != turnToken) return;
    _currentStreamSubscription = null;
    if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
      _turnCompleter!.complete(hasBeenAccepted);
    }
    if (hasBeenAccepted) {
      loadMessages(conversationId, expectedTurnToken: turnToken);
    }
  }

  Future<void> _persistDeterministicTitle(String conversationId, String title) async {
    if (_userRenamedConversationIds.contains(conversationId)) return;
    try {
      final updated = await _client.renameConversation(conversationId, title);
      if (!_userRenamedConversationIds.contains(conversationId)) {
        _conversations =
            _conversations.map((c) => c.id == conversationId ? updated : c).toList();
        if (_activeConversation?.id == conversationId) {
          _activeConversation = updated;
        }
        if (!_isDisposed) notifyListeners();
      }
    } catch (_) {
      // Graceful fallback: local UI already has the deterministic title
    }
  }

  Future<void> _maybeGenerateModelTitle(String conversationId, String? fallbackTitle) async {
    if (fallbackTitle == null || _userRenamedConversationIds.contains(conversationId)) return;
    if (!isConnected || _modelStatus?.modelLoaded != true) return;

    // Await the deterministic title persistence PATCH if still in flight
    final pendingPatch = _pendingRenameFutures[conversationId];
    if (pendingPatch != null) {
      try {
        await pendingPatch;
      } catch (_) {}
    }

    if (_isDisposed || _userRenamedConversationIds.contains(conversationId)) return;
    if (!isConnected || _modelStatus?.modelLoaded != true) return;

    try {
      final res = await _client.generateConversationTitle(
        conversationId,
        currentTitle: fallbackTitle,
        fallbackTitle: fallbackTitle,
      );
      if (_isDisposed || _userRenamedConversationIds.contains(conversationId)) return;
      if (res.title.isNotEmpty && res.title != 'New Conversation') {
        _conversations =
            _conversations.map((c) => c.id == conversationId ? res : c).toList();
        if (_activeConversation?.id == conversationId) {
          _activeConversation = res;
        }
        notifyListeners();
      }
    } catch (_) {
      // Gracefully keep fallbackTitle
    } finally {
      _pendingRenameFutures.remove(conversationId);
    }
  }

  /// Renames a conversation thread by ID.
  Future<void> renameConversation(String conversationId, String newTitle) async {
    if (_isDisposed) return;
    if (!isConnected) {
      _errorMessage = 'Cannot rename conversation: Runtime is not connected and authorized.';
      notifyListeners();
      throw StateError('Runtime is not connected.');
    }
    _userRenamedConversationIds.add(conversationId);
    try {
      final updated = await _client.renameConversation(conversationId, newTitle);
      _conversations =
          _conversations.map((c) => c.id == conversationId ? updated : c).toList();
      if (_activeConversation?.id == conversationId) {
        _activeConversation = updated;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to rename conversation: $e';
      if (!_isDisposed) notifyListeners();
      rethrow;
    }
  }

  /// Cancels active stream generation on user demand.
  Future<void> cancelGeneration() async {
    if (!isGenerating) return;

    final turnToken = ++_turnSequenceToken;
    final wasAwaitingAcceptance = _isAwaitingAcceptance;
    _isAwaitingAcceptance = false;
    _generationState = ChatGenerationState.cancelled;
    _streamingText = '';

    final sub = _currentStreamSubscription;
    _currentStreamSubscription = null;

    if (_turnCompleter != null && !_turnCompleter!.isCompleted) {
      _turnCompleter!.complete(!wasAwaitingAcceptance);
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
