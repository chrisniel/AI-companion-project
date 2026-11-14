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
  modelSelectionRequired,
}

typedef CompanionClientFactory = CompanionClient Function({
  required String baseUrl,
  CredentialStore? credentialStore,
});

/// Controller managing desktop conversation state, REST integration, and live SSE streaming.
class DesktopChatController extends ChangeNotifier {
  CompanionClient _client;
  final CompanionClientFactory? _clientFactory;
  final DateTime Function() _now;

  RuntimeConnectionStatus _connectionStatus = RuntimeConnectionStatus.unconnected;
  ChatGenerationState _generationState = ChatGenerationState.idle;

  List<ConversationOut> _conversations = [];
  ConversationOut? _activeConversation;
  List<MessageOut> _messages = [];
  String _streamingText = '';
  String? _activeModelName;
  String? _authenticatedProfileId;
  String? _authenticatedProfileName;
  DateTime? _authenticatedSessionExpiry;
  ModelStatusResponse? _modelStatus;
  String? _errorMessage;
  bool _isLoadingConversations = false;
  String? _conversationError;
  ConversationSummaryOut? _activeSummary;
  bool _isCompacting = false;
  int _summarySequenceToken = 0;

  ActiveCharacterStateOut? _activeCharacterState;
  final Map<String, CharacterInstanceOut> _characterCache = <String, CharacterInstanceOut>{};
  final Set<String> _missingCharacterIds = <String>{};
  final Set<String> _fetchingCharacterIds = <String>{};

  StreamSubscription<SseEvent>? _currentStreamSubscription;
  final Set<StreamSubscription<SseEvent>> _profileSubscriptions = {};
  Completer<bool>? _turnCompleter;
  int _configEpoch = 0;
  int _turnSequenceToken = 0;
  int _loadSequenceToken = 0;
  bool _isDisposed = false;
  Timer? _sessionExpiryTimer;
  bool _isCreatingConversation = false;
  bool _isAwaitingAcceptance = false;
  final Set<String> _userRenamedConversationIds = <String>{};
  final Set<String> _titleGenerationInProgress = <String>{};
  final Set<String> _modelRefinedConversationIds = <String>{};
  final Map<String, Future<void>> _pendingRenameFutures = <String, Future<void>>{};
  final Map<String, String> _conversationDrafts = <String, String>{};
  final Map<String, double> _conversationScrollOffsets = <String, double>{};

  String getDraft(String conversationId) => _conversationDrafts[conversationId] ?? '';

  void setDraft(String conversationId, String draft) {
    if (draft.isEmpty) {
      _conversationDrafts.remove(conversationId);
    } else {
      _conversationDrafts[conversationId] = draft;
    }
  }

  double? getScrollOffset(String conversationId) => _conversationScrollOffsets[conversationId];

  void setScrollOffset(String conversationId, double offset) {
    _conversationScrollOffsets[conversationId] = offset;
  }

  DesktopChatController({
    required CompanionClient client,
    CompanionClientFactory? clientFactory,
    DateTime Function()? now,
  })  : _client = client,
        _clientFactory = clientFactory,
        _now = now ?? DateTime.now;

  CompanionClient get client => _client;
  int get profileEpoch => _configEpoch;
  String? get authenticatedProfileId =>
      isConnected ? _authenticatedProfileId : null;
  String? get authenticatedProfileName =>
      isConnected ? _authenticatedProfileName : null;
  DateTime? get authenticatedSessionExpiry =>
      isConnected ? _authenticatedSessionExpiry : null;

  void updateAuthenticatedProfileName(String name) {
    _authenticatedProfileName = name;
    if (!_isDisposed) notifyListeners();
  }

  void _clearPersonalState() {
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;
    _authenticatedProfileId = null;
    _authenticatedProfileName = null;
    _authenticatedSessionExpiry = null;
    ++_configEpoch;
    ++_loadSequenceToken;
    ++_summarySequenceToken;
    _conversations = [];
    _activeConversation = null;
    _messages = [];
    _streamingText = '';
    _activeSummary = null;
    _isCompacting = false;
    _errorMessage = null;
    _conversationError = null;
    _conversationDrafts.clear();
    _conversationScrollOffsets.clear();
    _userRenamedConversationIds.clear();
    _titleGenerationInProgress.clear();
    _modelRefinedConversationIds.clear();
    _pendingRenameFutures.clear();
    _activeCharacterState = null;
    _characterCache.clear();
    _missingCharacterIds.clear();
    _fetchingCharacterIds.clear();
    _isLoadingConversations = false;
    _isCreatingConversation = false;
    _cancelProfileSubscriptions();
    _connectionStatus = RuntimeConnectionStatus.unauthorized;
  }

  void _cancelProfileSubscriptions() {
    for (final subscription in _profileSubscriptions) {
      unawaited(subscription.cancel());
    }
    _profileSubscriptions.clear();
    _currentStreamSubscription = null;
  }

  Future<void> invalidateProfileSession({bool clearStoredToken = true}) async {
    _clearPersonalState();
    await cancelGeneration();
    if (clearStoredToken) {
      await _client.sessionStore.deleteToken();
    }
    if (!_isDisposed) notifyListeners();
  }

  void _scheduleSessionExpiry(DateTime expiresAt) {
    _sessionExpiryTimer?.cancel();
    final epoch = _configEpoch;
    final remaining = expiresAt.difference(_now().toUtc());
    _sessionExpiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        if (!_isDisposed && epoch == _configEpoch) {
          // Keep expired saved authority inert until explicit authorization.
          unawaited(invalidateProfileSession(clearStoredToken: false));
        }
      },
    );
  }

  /// A Profile change invalidates every pending operation and personal cache.
  /// Uses acquire-before-teardown to ensure Profile A remains intact if destination authorization fails.
  Future<void> selectProfile(String profileId) async {
    final priorToken = await _client.sessionStore.readToken();

    // 1. Acquire destination session before clearing state or revoking prior token.
    final session = await _client.mintAndExchangeProfileSession(profileId);

    // 2. Teardown active generation and clear Profile A's personal cache.
    _clearPersonalState();
    await cancelGeneration();
    notifyListeners();

    // 3. Revoke previous session if one was active.
    if (priorToken != null && priorToken.isNotEmpty) {
      try {
        await _client.revokeSessionToken(priorToken);
      } on CompanionApiException catch (error) {
        if (error.statusCode != 401 && error.statusCode != 403) rethrow;
      }
    }

    // 4. Store newly acquired token and schedule session expiry.
    await _client.sessionStore.writeToken(session['token'] as String);
    final expires = DateTime.tryParse(session['expires_at']?.toString() ?? '');
    if (expires != null && expires.isUtc) {
      _scheduleSessionExpiry(expires);
    }
    await checkConnection();
  }
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
  ConversationSummaryOut? get activeSummary => _activeSummary;
  bool get isCompacting => _isCompacting;
  ActiveCharacterStateOut? get activeCharacterState => _activeCharacterState;

  /// Explicitly updates or sets the active character state for the active profile.
  void updateActiveCharacterState(ActiveCharacterStateOut state) {
    _activeCharacterState = state;
    if (state.activeInstance != null) {
      _characterCache[state.activeInstance!.id] = state.activeInstance!;
    }
    notifyListeners();
  }

  Timer? _modelLoadingPollTimer;

  /// Updates the model status and initiates background polling if model is loading.
  void updateModelStatus(ModelStatusResponse status) {
    _modelStatus = status;
    if (status.runtimeState == 'MODEL_SELECTION_REQUIRED') {
      _activeModelName = null;
    } else {
      _activeModelName = status.activeModel ?? status.selectedModel;
    }
    notifyListeners();

    if (status.runtimeState == 'MODEL_LOADING' || status.runtimeState == 'SERVER_STARTING') {
      _startModelLoadingPollTimer();
    } else {
      _stopModelLoadingPollTimer();
    }
  }

  void _stopModelLoadingPollTimer() {
    _modelLoadingPollTimer?.cancel();
    _modelLoadingPollTimer = null;
  }

  void _startModelLoadingPollTimer() {
    _stopModelLoadingPollTimer();
    _modelLoadingPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      try {
        final freshStatus = await _client.getModelStatus();
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        _modelStatus = freshStatus;
        if (freshStatus.runtimeState != 'MODEL_SELECTION_REQUIRED') {
          _activeModelName = freshStatus.activeModel ?? freshStatus.selectedModel;
        }
        notifyListeners();

        if (freshStatus.runtimeState == 'MODEL_READY' ||
            freshStatus.runtimeState == 'MODEL_ERROR' ||
            freshStatus.runtimeState == 'SERVER_ERROR' ||
            freshStatus.runtimeState == 'LOAD_FAILED') {
          timer.cancel();
          _modelLoadingPollTimer = null;
        }
      } catch (_) {
        // Continue polling or retry
      }
    });
  }

  /// Caches an authoritative instance definition in memory.
  void cacheCharacterInstance(CharacterInstanceOut instance) {
    _characterCache[instance.id] = instance;
    _missingCharacterIds.remove(instance.id);
    notifyListeners();
  }

  /// Re-fetches active character state from the backend.
  Future<void> refreshActiveCharacter() async {
    if (!isConnected || _authenticatedProfileId == null) return;
    final epoch = _configEpoch;
    try {
      final state = await _client.getActiveCharacterState();
      if (_configEpoch != epoch || _isDisposed) return;
      _activeCharacterState = state;
      if (state.activeInstance != null) {
        _characterCache[state.activeInstance!.id] = state.activeInstance!;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _fetchAndCacheCharacterInstance(String instanceId) async {
    if (_fetchingCharacterIds.contains(instanceId) ||
        _missingCharacterIds.contains(instanceId) ||
        _characterCache.containsKey(instanceId) ||
        !isConnected) {
      return;
    }
    final epoch = _configEpoch;
    _fetchingCharacterIds.add(instanceId);
    try {
      final inst = await _client.getCharacterInstance(instanceId);
      if (_configEpoch != epoch || _isDisposed) return;
      _characterCache[instanceId] = inst;
      notifyListeners();
    } catch (e) {
      if (_configEpoch != epoch || _isDisposed) return;
      if (e is CompanionApiException && e.statusCode == 404) {
        _missingCharacterIds.add(instanceId);
        notifyListeners();
      }
    } finally {
      _fetchingCharacterIds.remove(instanceId);
    }
  }

  /// Authoritative display name for the profile's active character.
  String getActiveProfileCharacterName() {
    if (!isConnected) return 'Disconnected';
    if (_activeCharacterState == null) return 'Neutral Assistant';
    if (_activeCharacterState!.isNeutralFallback || _activeCharacterState!.activeCharacterInstanceId == null) {
      return 'Neutral Assistant';
    }
    if (_activeCharacterState!.activeInstance != null) {
      return _activeCharacterState!.activeInstance!.name;
    }
    return _activeCharacterState!.activeCharacterId;
  }

  /// Authoritative display name for the character permanently bound to a conversation.
  String getConversationCharacterName(ConversationOut? conv) {
    if (conv == null) return 'No Conversation';
    if (conv.characterInstanceId == null ||
        conv.characterId == 'default' ||
        conv.characterId == 'neutral-assistant') {
      return 'Neutral Assistant';
    }
    final instId = conv.characterInstanceId!;
    if (_activeCharacterState?.activeCharacterInstanceId == instId &&
        _activeCharacterState?.activeInstance != null) {
      return _formatInstanceName(_activeCharacterState!.activeInstance!);
    }
    if (_characterCache.containsKey(instId)) {
      return _formatInstanceName(_characterCache[instId]!);
    }
    if (_missingCharacterIds.contains(instId)) {
      return 'Missing Character';
    }
    unawaited(_fetchAndCacheCharacterInstance(instId));
    return 'Loading...';
  }

  /// Authoritative mood badge text (e.g., '😌 Calm' or '😊 Cheerful') for the character bound to a conversation.
  String? getConversationCharacterMoodBadge(ConversationOut? conv) {
    if (conv == null ||
        conv.characterInstanceId == null ||
        conv.characterId == 'default' ||
        conv.characterId == 'neutral-assistant') {
      return null;
    }
    final instId = conv.characterInstanceId!;
    final cached = _characterCache[instId] ??
        (_activeCharacterState?.activeCharacterInstanceId == instId
            ? _activeCharacterState?.activeInstance
            : null);
    if (cached == null || cached.isLegacyPlaceholder) {
      return null;
    }
    return cached.moodBadgeText;
  }

  Future<void> _refreshCharacterInstanceMood(String instanceId) async {
    if (!isConnected || _isDisposed) return;
    final epoch = _configEpoch;
    try {
      final inst = await _client.getCharacterInstance(instanceId);
      if (_configEpoch != epoch || _isDisposed) return;
      _characterCache[instanceId] = inst;
      if (_activeCharacterState != null &&
          _activeCharacterState!.activeCharacterInstanceId == instanceId) {
        _activeCharacterState = ActiveCharacterStateOut(
          profileId: _activeCharacterState!.profileId,
          isNeutralFallback: _activeCharacterState!.isNeutralFallback,
          activeCharacterId: _activeCharacterState!.activeCharacterId,
          activeCharacterInstanceId: _activeCharacterState!.activeCharacterInstanceId,
          neutralFallback: _activeCharacterState!.neutralFallback,
          activeInstance: inst,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  String _formatInstanceName(CharacterInstanceOut inst) {
    if (inst.isLegacyPlaceholder) return '${inst.name} (Legacy)';
    if (inst.status == 'archived') return '${inst.name} (Archived)';
    return inst.name;
  }

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

    final state = ms.runtimeState.toUpperCase();
    if (state == 'MODEL_SELECTION_REQUIRED' || ms.lastRuntimeError == 'MODEL_SELECTION_REQUIRED') {
      return ModelRuntimeStateCategory.modelSelectionRequired;
    }

    if (ms.lastRuntimeError != null && ms.lastRuntimeError!.isNotEmpty) {
      return ModelRuntimeStateCategory.modelLoadFailed;
    }

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
        return 'Profile Access Required';
      case ModelRuntimeStateCategory.authenticatedNoModel:
        return _activeModelName ?? 'No Model';
      case ModelRuntimeStateCategory.modelSelectionRequired:
        return 'No Model Selected';
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
        return 'Profile access required. Select a Profile in Settings.';
      case ModelRuntimeStateCategory.authenticatedNoModel:
        return 'Authenticated with runtime. No active model configured.';
      case ModelRuntimeStateCategory.modelSelectionRequired:
        return 'No model is selected. Choose a model in Settings to begin chat.';
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
  Future<void> updateConfiguration({
    required String baseUrl,
    String? pairingToken,
    bool restoreSavedSession = false,
  }) async {
    if (_isDisposed) return;
    final targetUri = CompanionClient.validateBaseUrl(baseUrl);
    final isLocalRuntime =
        ['127.0.0.1', 'localhost', '::1'].contains(targetUri.host);
    final currentEpoch = ++_configEpoch;
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;

    if (isGenerating) {
      await cancelGeneration();
    }
    _cancelProfileSubscriptions();
    if (!restoreSavedSession && await _client.sessionStore.readToken() != null) {
      try { await _client.revokeProfileSession(); }
      on CompanionApiException catch (error) {
        if (error.statusCode != 401 && error.statusCode != 403) rethrow;
      }
    }
    _conversationDrafts.clear();
    _conversationScrollOffsets.clear();

    if (pairingToken != null && _client.credentialStore != null) {
      await _client.credentialStore!.writeToken(pairingToken.trim());
    }

    _client = _clientFactory != null && (!restoreSavedSession || isLocalRuntime)
        ? _clientFactory(baseUrl: baseUrl, credentialStore: _client.credentialStore)
        : CompanionClient(
            baseUrl: baseUrl,
            credentialStore: _client.credentialStore,
            hostAdminStore: _client.hostAdminStore,
            sessionStore: restoreSavedSession && !isLocalRuntime
                ? InMemoryCredentialStore()
                : _client.sessionStore,
          );

    _conversations = [];
    _activeConversation = null;
    _messages = [];
    _streamingText = '';
    _errorMessage = null;
    _activeSummary = null;
    _isCompacting = false;
    ++_summarySequenceToken;
    if (restoreSavedSession) {
      _authenticatedProfileId = null;
      _authenticatedProfileName = null;
      _authenticatedSessionExpiry = null;
      _connectionStatus = RuntimeConnectionStatus.unauthorized;
    }
    notifyListeners();

    // Startup authenticates through /session/me only after runtime readiness.
    // Keep saved local authority intact; explicit configuration changes revoke.
    if (restoreSavedSession) return;

    await checkConnection();
    if (_configEpoch == currentEpoch && isConnected && !_isDisposed) {
      await loadConversations();
    }
  }

  /// Probes public health and protected auth to update connection status.
  Future<void> checkConnection({bool preserveSavedSessionOnFailure = false}) async {
    if (_isDisposed) return;
    final epoch = _configEpoch;
    _authenticatedProfileId = null;
    _authenticatedProfileName = null;
    _authenticatedSessionExpiry = null;
    _connectionStatus = RuntimeConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final health = await _client.getHealth();
      if (_configEpoch != epoch || _isDisposed) return;

      if (health.status == 'healthy') {
        // Health 200 proves runtime reachability only, NOT authorization.
        // Check if pairing credentials exist and verify them fail-closed.
        final token = await _client.sessionStore.readToken();
        if (_configEpoch != epoch || _isDisposed) return;

        if (token == null || token.trim().isEmpty) {
          _connectionStatus = RuntimeConnectionStatus.unauthorized;
          _errorMessage = 'Profile access is required. Select a Profile in Settings.';
          _activeModelName = null;
          notifyListeners();
          return;
        }

        try {
          final auth = await _client.getOwnSession();
          if (_configEpoch != epoch || _isDisposed) return;

          final expires = DateTime.tryParse(auth['expires_at']?.toString() ?? '');
          if (auth['id'] is String &&
              expires != null &&
              expires.isUtc &&
              expires.isAfter(_now().toUtc())) {
            _scheduleSessionExpiry(expires);
            _authenticatedProfileId = auth['id'] as String;
            _authenticatedProfileName = auth['name']?.toString();
            _authenticatedSessionExpiry = expires;
            _connectionStatus = RuntimeConnectionStatus.connected;
            _errorMessage = null;

            try {
              final modelStatus = await _client.getModelStatus();
              if (_configEpoch != epoch || _isDisposed) return;
              _modelStatus = modelStatus;
              if (modelStatus.runtimeState == 'MODEL_SELECTION_REQUIRED') {
                _activeModelName = null;
              } else {
                _activeModelName = modelStatus.activeModel ?? modelStatus.selectedModel;
              }
            } catch (_) {
              if (_configEpoch != epoch || _isDisposed) return;
              // Valid auth + unavailable model: retain connected/authorized status
              _modelStatus = null;
              _activeModelName = 'Unavailable';
            }

            try {
              final charState = await _client.getActiveCharacterState();
              if (_configEpoch == epoch && !_isDisposed) {
                _activeCharacterState = charState;
                if (charState.activeInstance != null) {
                  _characterCache[charState.activeInstance!.id] = charState.activeInstance!;
                }
              }
            } catch (_) {
              // Non-fatal if character service unavailable
            }

            if (!_isDisposed && _configEpoch == epoch) {
              await loadConversations();
            }
          } else {
            await invalidateProfileSession(clearStoredToken: false);
            _errorMessage = 'Profile session verification failed.';
            _activeModelName = null;
          }
        } on CompanionApiException catch (authEx) {
          if (_configEpoch != epoch || _isDisposed) return;
          if (authEx.statusCode == 401 || authEx.statusCode == 403) {
            await invalidateProfileSession(
                clearStoredToken: !preserveSavedSessionOnFailure);
          }
          _connectionStatus = RuntimeConnectionStatus.unauthorized;
          _errorMessage = authEx.message.isNotEmpty
              ? authEx.message
              : 'Authentication failed (HTTP ${authEx.statusCode}).';
          _activeModelName = null;
          if (!_isDisposed) notifyListeners();
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
    final epoch = _configEpoch;
    _isLoadingConversations = true;
    _conversationError = null;
    notifyListeners();

    try {
      final res = await _client.listConversations();
      if (_isDisposed || epoch != _configEpoch) return;
      _conversations = res.items;

      if (_conversations.isNotEmpty && _activeConversation == null) {
        await selectConversation(_conversations.first);
      }
    } catch (e) {
      if (_isDisposed || epoch != _configEpoch) return;
      _conversationError = e.toString();
    } finally {
      if (!_isDisposed && epoch == _configEpoch) {
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
    _activeSummary = null;
    _isCompacting = false;
    ++_summarySequenceToken;

    if (conversation.characterInstanceId != null &&
        !_characterCache.containsKey(conversation.characterInstanceId) &&
        !_missingCharacterIds.contains(conversation.characterInstanceId)) {
      unawaited(_fetchAndCacheCharacterInstance(conversation.characterInstanceId!));
    }

    notifyListeners();

    await Future.wait([
      loadMessages(conversation.id),
      loadConversationSummary(conversationId: conversation.id),
    ]);
  }

  /// Creates a new persistent conversation thread and selects it.
  ///
  /// Reuses existing untouched empty draft conversation if already active and its bound
  /// Character matches the intended Character selection (matching Web Phase 8C + PC-CLIENT-007).
  /// If the active Profile Character has changed, creates a genuinely new conversation
  /// without mutating historical associations.
  /// Enforces synchronous transition lock to prevent duplicate creation on rapid clicks.
  /// Never fabricates fake local conversation records when backend calls fail.
  Future<void> createNewConversation({String title = 'New Conversation', String? targetCharacterId}) async {
    if (_isDisposed) return;
    final epoch = _configEpoch;
    if (_isCreatingConversation) return;
    if (!isConnected) {
      _errorMessage = 'Cannot create conversation: Runtime is not connected and authorized.';
      notifyListeners();
      throw StateError('Runtime is not connected.');
    }

    final String? intendedInstanceId;
    if (targetCharacterId != null) {
      intendedInstanceId = (targetCharacterId == 'default' || targetCharacterId == 'neutral-assistant')
          ? null
          : targetCharacterId;
    } else {
      intendedInstanceId = (_activeCharacterState?.isNeutralFallback == true)
          ? null
          : _activeCharacterState?.activeCharacterInstanceId;
    }

    final convInstanceId = _activeConversation?.characterInstanceId;
    final bool characterMatches = convInstanceId == intendedInstanceId;

    final isCurrentEmptyDraft = _activeConversation != null &&
        (_activeConversation!.title == 'New Conversation' ||
            _activeConversation!.title.isEmpty ||
            _activeConversation!.title == title) &&
        _messages.isEmpty &&
        _activeConversation!.messageCount == 0 &&
        characterMatches;
    if (isCurrentEmptyDraft) {
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isCreatingConversation = true;
    notifyListeners();
    try {
      final created = await _client.createConversation(
        title: title,
        characterId: intendedInstanceId,
      );
      if (_isDisposed || epoch != _configEpoch) return;
      _conversations = [created, ..._conversations];
      await selectConversation(created);
    } catch (e) {
      if (_isDisposed || epoch != _configEpoch) return;
      _errorMessage = 'Failed to create conversation: $e';
      if (!_isDisposed) notifyListeners();
      rethrow;
    } finally {
      if (!_isDisposed && epoch == _configEpoch) {
        _isCreatingConversation = false;
        notifyListeners();
      }
    }
  }

  /// Deletes a conversation thread by ID.
  ///
  /// Fails closed if runtime is not connected, or if deleting active thread during generation.
  Future<void> deleteConversation(String conversationId) async {
    if (_isDisposed) return;
    final epoch = _configEpoch;
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
      if (_isDisposed || epoch != _configEpoch) return;
      _conversations = _conversations.where((c) => c.id != conversationId).toList();
      if (_activeConversation?.id == conversationId) {
        if (_conversations.isNotEmpty) {
          await selectConversation(_conversations.first);
        } else {
          _activeConversation = null;
          _messages = [];
          _streamingText = '';
          _generationState = ChatGenerationState.idle;
          _activeSummary = null;
          _isCompacting = false;
          ++_summarySequenceToken;
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    } catch (e) {
      if (_isDisposed || epoch != _configEpoch) return;
      _errorMessage = 'Failed to delete conversation: $e';
      if (!_isDisposed) notifyListeners();
      rethrow;
    }
  }

  /// Loads the latest active episode digest summary for the selected thread.
  Future<void> loadConversationSummary({String? conversationId}) async {
    final targetId = conversationId ?? _activeConversation?.id;
    if (_isDisposed || !isConnected || targetId == null) return;
    final epoch = _configEpoch;
    final summaryToken = ++_summarySequenceToken;
    try {
      final summary = await _client.getConversationSummary(targetId);
      if (_isDisposed ||
          epoch != _configEpoch ||
          summaryToken != _summarySequenceToken ||
          _activeConversation?.id != targetId) {
        return;
      }
      _activeSummary = summary;
      notifyListeners();
    } catch (_) {
      // Summary lookup is non-fatal so chat selection and unmocked tests stay resilient.
    }
  }

  /// Requests manual context compaction for the currently active conversation.
  Future<ConversationCompactResponse?> compactActiveConversation({
    int? keepRecentMessages,
  }) async {
    if (_isDisposed) return null;
    final activeConv = _activeConversation;
    if (!isConnected || activeConv == null || isGenerating || _isCompacting) {
      return null;
    }
    final epoch = _configEpoch;
    final targetId = activeConv.id;
    _isCompacting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.compactConversation(
        targetId,
        ConversationCompactRequest(
          keepRecentMessages: keepRecentMessages,
          force: true,
        ),
      );
      if (_isDisposed ||
          epoch != _configEpoch ||
          _activeConversation?.id != targetId) {
        return null;
      }
      ++_summarySequenceToken;
      if (response.summary != null) {
        _activeSummary = response.summary;
      }
      return response;
    } catch (e) {
      if (_isDisposed || epoch != _configEpoch) return null;
      _errorMessage = 'Failed to compact context: $e';
      return null;
    } finally {
      if (!_isDisposed && epoch == _configEpoch) {
        _isCompacting = false;
        notifyListeners();
      }
    }
  }

  /// Bookmarks a chat message snippet into long-term memory or fixed knowledge.
  Future<bool> bookmarkMessageToMemory(
    String content, {
    required bool asKnowledge,
  }) async {
    if (_isDisposed || !isConnected) return false;
    var trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > 1000) {
      trimmed = '${trimmed.substring(0, 997).trimRight()}...';
    }
    final epoch = _configEpoch;
    try {
      await _client.createMemory(
        MemoryCreate(
          content: trimmed,
          category: 'fact',
          importance: asKnowledge ? 1.5 : 1.0,
          scope: 'profile',
          isCore: asKnowledge,
          sourceType: 'user_explicit',
        ),
      );
      return !_isDisposed && epoch == _configEpoch;
    } catch (e) {
      if (_isDisposed || epoch != _configEpoch) return false;
      _errorMessage = 'Failed to bookmark message: $e';
      notifyListeners();
      return false;
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
    final epoch = _configEpoch;
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
        if (_isDisposed || epoch != _configEpoch) return false;
      } catch (e) {
        if (_isDisposed || epoch != _configEpoch) return false;
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
          characterInstanceId: activeConv.characterInstanceId,
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

      late final StreamSubscription<SseEvent> subscription;
      subscription = stream.listen(
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
            if (_messages.isNotEmpty && _messages.last.sender == 'assistant') {
              final last = _messages.last;
              final finalStatus = event.finishReason == 'length' ? 'length' : 'completed';
              _messages = [
                ..._messages.sublist(0, _messages.length - 1),
                MessageOut(
                  id: last.id,
                  conversationId: last.conversationId,
                  sender: last.sender,
                  content: last.content,
                  status: finalStatus,
                  sequenceNo: last.sequenceNo,
                  createdAt: last.createdAt,
                ),
              ];
            }
            _finalizeTurn(boundConvId, turnToken, hasBeenAccepted: hasBeenAccepted);
            final boundInstId = _activeConversation?.characterInstanceId;
            if (boundInstId != null && boundInstId.isNotEmpty) {
              unawaited(_refreshCharacterInstanceMood(boundInstId));
            }
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
            if (err.statusCode == 401 || err.statusCode == 403) unawaited(invalidateProfileSession());
            if ((err.statusCode == 422 || err.statusCode == 503) &&
                err.message.contains('MODEL_SELECTION_REQUIRED')) {
              _errorMessage = 'No model selected. Choose a model in Settings to begin chat.';
            } else if (err.statusCode == 503) {
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
          _profileSubscriptions.remove(subscription);
          if (_isDisposed ||
              _turnSequenceToken != turnToken ||
              _activeConversation?.id != boundConvId) {
            return;
          }
          if (_generationState == ChatGenerationState.generating) {
            _generationState = ChatGenerationState.idle;
            _streamingText = '';
            if (_messages.isNotEmpty && _messages.last.sender == 'assistant') {
              final last = _messages.last;
              _messages = [
                ..._messages.sublist(0, _messages.length - 1),
                MessageOut(
                  id: last.id,
                  conversationId: last.conversationId,
                  sender: last.sender,
                  content: last.content,
                  status: 'interrupted',
                  sequenceNo: last.sequenceNo,
                  createdAt: last.createdAt,
                ),
              ];
            }
            _finalizeTurn(boundConvId, turnToken, hasBeenAccepted: hasBeenAccepted);
            _maybeGenerateModelTitle(boundConvId, deterministicTitle);
          }
          if (!completer.isCompleted) completer.complete(hasBeenAccepted);
        },
        cancelOnError: false,
      );
      _currentStreamSubscription = subscription;
      _profileSubscriptions.add(subscription);
    } catch (e) {
      _isAwaitingAcceptance = false;
      _generationState = ChatGenerationState.error;
      if (e is CompanionApiException) {
        if ((e.statusCode == 422 || e.statusCode == 503) &&
            e.message.contains('MODEL_SELECTION_REQUIRED')) {
          _errorMessage = 'No model selected. Choose a model in Settings to begin chat.';
        } else if (e.statusCode == 503) {
          final backendReason = _modelStatus?.lastRuntimeError;
          if (backendReason != null && backendReason.isNotEmpty) {
            _errorMessage = 'Local AI model unavailable (503): $backendReason';
          } else {
            _errorMessage =
                'Local AI model unavailable (503): Model engine is not loaded or ready. Start the local LLM router or check model status in Settings.';
          }
        } else {
          _errorMessage = e.message;
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
      unawaited(loadConversationSummary(conversationId: conversationId));
    }
  }

  Future<void> _persistDeterministicTitle(String conversationId, String title) async {
    final epoch = _configEpoch;
    if (_userRenamedConversationIds.contains(conversationId)) return;
    try {
      final updated = await _client.renameConversation(conversationId, title);
      if (_isDisposed || epoch != _configEpoch) return;
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
    final epoch = _configEpoch;
    if (fallbackTitle == null ||
        _userRenamedConversationIds.contains(conversationId) ||
        _modelRefinedConversationIds.contains(conversationId) ||
        _titleGenerationInProgress.contains(conversationId)) {
      return;
    }
    if (!isConnected) return;

    _titleGenerationInProgress.add(conversationId);

    try {
      // Await the deterministic title persistence PATCH if still in flight
      final pendingPatch = _pendingRenameFutures[conversationId];
      if (pendingPatch != null) {
        try {
          await pendingPatch;
        } catch (_) {}
      }

      if (_isDisposed || epoch != _configEpoch ||
          _userRenamedConversationIds.contains(conversationId) ||
          _modelRefinedConversationIds.contains(conversationId)) {
        return;
      }
      if (!isConnected) return;

      // If model was not loaded at connection time or cached status indicates unloaded,
      // perform authoritative post-turn readiness probe
      if (_modelStatus?.modelLoaded != true) {
        try {
          final fresh = await _client.getModelStatus();
          if (!_isDisposed && epoch == _configEpoch &&
              !_userRenamedConversationIds.contains(conversationId)) {
            _modelStatus = fresh;
            _activeModelName = fresh.activeModel ?? 'default';
            notifyListeners();
          }
        } catch (_) {
          // Probing failed or backend offline
        }
      }

      if (_isDisposed || epoch != _configEpoch ||
          _userRenamedConversationIds.contains(conversationId) ||
          _modelRefinedConversationIds.contains(conversationId)) {
        return;
      }
      if (!isConnected || _modelStatus?.modelLoaded != true) return;

      try {
        final res = await _client.generateConversationTitle(
          conversationId,
          currentTitle: fallbackTitle,
          fallbackTitle: fallbackTitle,
        );
        if (_isDisposed || epoch != _configEpoch ||
            _userRenamedConversationIds.contains(conversationId) ||
            _modelRefinedConversationIds.contains(conversationId)) {
          return;
        }
        if (res.title.isNotEmpty && res.title != 'New Conversation') {
          _modelRefinedConversationIds.add(conversationId);
          _conversations =
              _conversations.map((c) => c.id == conversationId ? res : c).toList();
          if (_activeConversation?.id == conversationId) {
            _activeConversation = res;
          }
          notifyListeners();
        }
      } catch (_) {
        // Gracefully keep fallbackTitle
      }
    } finally {
      if (epoch == _configEpoch) {
        _titleGenerationInProgress.remove(conversationId);
        _pendingRenameFutures.remove(conversationId);
      }
    }
  }

  /// Renames a conversation thread by ID.
  Future<void> renameConversation(String conversationId, String newTitle) async {
    if (_isDisposed) return;
    final epoch = _configEpoch;
    if (!isConnected) {
      _errorMessage = 'Cannot rename conversation: Runtime is not connected and authorized.';
      notifyListeners();
      throw StateError('Runtime is not connected.');
    }
    _userRenamedConversationIds.add(conversationId);
    try {
      final updated = await _client.renameConversation(conversationId, newTitle);
      if (_isDisposed || epoch != _configEpoch) return;
      _conversations =
          _conversations.map((c) => c.id == conversationId ? updated : c).toList();
      if (_activeConversation?.id == conversationId) {
        _activeConversation = updated;
      }
      notifyListeners();
    } catch (e) {
      if (_isDisposed || epoch != _configEpoch) return;
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
    _profileSubscriptions.remove(sub);

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
    _sessionExpiryTimer?.cancel();
    _modelLoadingPollTimer?.cancel();
    _isDisposed = true;
    _cancelProfileSubscriptions();
    super.dispose();
  }
}
