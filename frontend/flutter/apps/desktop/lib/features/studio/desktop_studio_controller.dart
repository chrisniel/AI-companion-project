import 'dart:async';
import 'dart:ui';
import 'package:ai_companion_desktop/features/chat/desktop_chat_controller.dart';
import 'package:companion_api/companion_api.dart';
import 'package:flutter/foundation.dart';
import 'character_stage_presenter.dart';

/// Five session states for Desktop Character Studio (Section 3.5.1).
enum StudioSessionStatus {
  authenticatedReady,
  validatingConnection,
  runtimeOffline,
  sessionExpiredOrRevoked,
  confirmedProfileSwitch,
}

/// Mutable draft for the Character Studio inspector.
class CharacterStudioDraft {
  CharacterStudioDraft({
    String? instanceId,
    required this.sourceTemplateId,
    required String name,
    required String summary,
    required String lore,
    required String systemPrompt,
    required String avatarAsset,
    required String presetId,
    CharacterTraitVector? traits,
    this.isLegacyPlaceholder = false,
    required this.onChanged,
  })  : _instanceId = instanceId,
        _name = name,
        _summary = summary,
        _lore = lore,
        _systemPrompt = systemPrompt,
        _avatarAsset = avatarAsset,
        _presetId = presetId,
        _traits = traits,
        _initialName = name,
        _initialSummary = summary,
        _initialLore = lore,
        _initialSystemPrompt = systemPrompt,
        _initialAvatarAsset = avatarAsset,
        _initialPresetId = presetId,
        _initialTraits = traits;

  String? _instanceId;
  String? get instanceId => _instanceId;
  final String sourceTemplateId;
  final bool isLegacyPlaceholder;
  final VoidCallback onChanged;

  bool get isReadOnly => isLegacyPlaceholder;
  int _revision = 0;
  int get revision => _revision;

  String _name;
  String _summary;
  String _lore;
  String _systemPrompt;
  String _avatarAsset;
  String _presetId;
  CharacterTraitVector? _traits;

  String _initialName;
  String _initialSummary;
  String _initialLore;
  String _initialSystemPrompt;
  String _initialAvatarAsset;
  String _initialPresetId;
  CharacterTraitVector? _initialTraits;

  bool get isNew => _instanceId == null;
  String get name => _name;
  String get summary => _summary;
  String get lore => _lore;
  String get systemPrompt => _systemPrompt;
  String get avatarAsset => _avatarAsset;
  String get presetId => _presetId;
  CharacterTraitVector? get traits => _traits;

  bool get isDirty =>
      _name != _initialName ||
      _summary != _initialSummary ||
      _lore != _initialLore ||
      _systemPrompt != _initialSystemPrompt ||
      _avatarAsset != _initialAvatarAsset ||
      _presetId != _initialPresetId ||
      _traits != _initialTraits;

  void updateName(String val) {
    if (isReadOnly) return;
    if (_name != val) {
      _name = val;
      _revision++;
      onChanged();
    }
  }

  void updateSummary(String val) {
    if (isReadOnly) return;
    if (_summary != val) {
      _summary = val;
      _revision++;
      onChanged();
    }
  }

  void updateLore(String val) {
    if (isReadOnly) return;
    if (_lore != val) {
      _lore = val;
      _revision++;
      onChanged();
    }
  }

  void updateSystemPrompt(String val) {
    if (isReadOnly) return;
    if (_systemPrompt != val) {
      _systemPrompt = val;
      _revision++;
      onChanged();
    }
  }

  void updateAvatar(String val) {
    if (isReadOnly) return;
    if (_avatarAsset != val) {
      _avatarAsset = val;
      _revision++;
      onChanged();
    }
  }

  void updatePreset(String newPresetId, CharacterTraitVector presetTraits) {
    if (isReadOnly) return;
    _presetId = newPresetId;
    _traits = presetTraits;
    _revision++;
    onChanged();
  }

  void updateTrait(String traitName, int val) {
    if (isReadOnly) return;
    final clamped = val.clamp(0, 100);
    final cur = _traits ?? const CharacterTraitVector(
      warmth: 50, teasing: 50, guardedness: 50, directness: 50,
      expressiveness: 50, affection: 50, formality: 50, verbosity: 50,
    );
    _traits = CharacterTraitVector(
      warmth: traitName == 'warmth' ? clamped : cur.warmth,
      teasing: traitName == 'teasing' ? clamped : cur.teasing,
      guardedness: traitName == 'guardedness' ? clamped : cur.guardedness,
      directness: traitName == 'directness' ? clamped : cur.directness,
      expressiveness: traitName == 'expressiveness' ? clamped : cur.expressiveness,
      affection: traitName == 'affection' ? clamped : cur.affection,
      formality: traitName == 'formality' ? clamped : cur.formality,
      verbosity: traitName == 'verbosity' ? clamped : cur.verbosity,
    );
    // Diverging from named preset switches presetId to 'custom'
    _presetId = 'custom';
    _revision++;
    onChanged();
  }

  void resetTraitToTemplate(String traitName, CharacterTraitVector tmplTraits) {
    if (isReadOnly) return;
    int resetVal;
    switch (traitName) {
      case 'warmth': resetVal = tmplTraits.warmth; break;
      case 'teasing': resetVal = tmplTraits.teasing; break;
      case 'guardedness': resetVal = tmplTraits.guardedness; break;
      case 'directness': resetVal = tmplTraits.directness; break;
      case 'expressiveness': resetVal = tmplTraits.expressiveness; break;
      case 'affection': resetVal = tmplTraits.affection; break;
      case 'formality': resetVal = tmplTraits.formality; break;
      case 'verbosity': resetVal = tmplTraits.verbosity; break;
      default: return;
    }
    updateTrait(traitName, resetVal);
  }

  void resetAllTraitsToTemplate(CharacterTraitVector tmplTraits, String? tmplPresetId) {
    if (isReadOnly) return;
    _traits = tmplTraits;
    _presetId = tmplPresetId ?? 'custom';
    _revision++;
    onChanged();
  }

  /// Reconciles draft with a committed server instance while strictly preserving
  /// user edits that occurred after the request snapshot was taken.
  void reconcileSavedInstance(CharacterInstanceOut saved, int snapshotRevision) {
    _instanceId = saved.id;
    _initialName = saved.name;
    _initialSummary = saved.summary;
    _initialLore = saved.lore;
    _initialSystemPrompt = saved.systemPrompt;
    _initialAvatarAsset = saved.avatarAsset;
    _initialPresetId = saved.presetId ?? 'custom';
    _initialTraits = saved.traits;

    if (_revision == snapshotRevision) {
      _name = saved.name;
      _summary = saved.summary;
      _lore = saved.lore;
      _systemPrompt = saved.systemPrompt;
      _avatarAsset = saved.avatarAsset;
      _presetId = saved.presetId ?? 'custom';
      _traits = saved.traits;
    }
    onChanged();
  }
}

/// Controller managing Character Studio catalog, session fencing, and mutation locks.
class DesktopStudioController extends ChangeNotifier {
  DesktopStudioController({required this.chat}) {
    _boundProfileEpoch = chat.profileEpoch;
    _boundProfileId = chat.authenticatedProfileId;
    chat.addListener(_onChatChanged);
    _classifySession(
      status: chat.connectionStatus,
      authProfileId: chat.authenticatedProfileId,
      epoch: chat.profileEpoch,
    );
  }

  final DesktopChatController chat;

  int _sessionFenceId = 0;
  int _readGeneration = 0;
  bool _isMutating = false;
  bool _isDisposed = false;

  String? _boundProfileId;
  int _boundProfileEpoch = -1;

  StudioSessionStatus _sessionStatus = StudioSessionStatus.runtimeOffline;

  List<CharacterTemplateOut> _templates = [];
  List<CharacterPresetOut> _presets = [];
  NeutralAssistantOut? _neutral;
  List<CharacterInstanceOut> _instances = [];
  ActiveCharacterStateOut? _activeState;

  CharacterStudioDraft? _draft;
  bool _isNeutralSelected = false;
  bool _isLoading = false;
  String? _error;
  bool _uncertainWriteWarning = false;
  bool _uncertainCreateWarning = false;

  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;
  StudioBackdropPreset _backdropPreset = StudioBackdropPreset.cozyStudio;
  bool _showArchived = false;

  // Getters
  StudioSessionStatus get sessionStatus => _sessionStatus;
  int get sessionFenceId => _sessionFenceId;
  String? get boundProfileId => _boundProfileId;
  bool get isMutating => _isMutating;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get uncertainWriteWarning => _uncertainWriteWarning;
  bool get uncertainCreateWarning => _uncertainCreateWarning;
  double get zoomLevel => _zoomLevel;
  Offset get panOffset => _panOffset;
  StudioBackdropPreset get backdropPreset => _backdropPreset;
  bool get showArchived => _showArchived;

  List<CharacterTemplateOut> get templates => _templates;
  List<CharacterPresetOut> get presets => _presets;
  NeutralAssistantOut? get neutral => _neutral;
  List<CharacterInstanceOut> get instances => _instances;
  ActiveCharacterStateOut? get activeState => _activeState;
  CharacterStudioDraft? get draft => _draft;
  bool get isNeutralSelected => _isNeutralSelected;
  bool get isNeutralActive => _activeState?.isNeutralFallback ?? true;
  String? get activeInstanceId => _activeState?.activeCharacterInstanceId;

  CharacterStageVisualSpec get visualSpec {
    if (_isNeutralSelected || (_draft == null && isNeutralActive)) {
      return CharacterStageVisualSpec(
        avatarAsset: _neutral?.avatarAsset ?? 'avatar_neutral',
        displayName: _neutral?.name ?? 'Neutral Assistant',
        badgeText: isNeutralActive ? 'Active in Chat' : '',
        zoomLevel: _zoomLevel,
        panOffset: _panOffset,
        backdropPreset: _backdropPreset,
      );
    }
    if (_draft != null) {
      final isActive = _draft!.instanceId != null && _draft!.instanceId == activeInstanceId;
      final badge = _draft!.isLegacyPlaceholder
          ? 'Legacy (Read-Only)'
          : (isActive ? 'Active in Chat' : (_draft!.isNew ? 'New Draft' : 'Customizing'));
      return CharacterStageVisualSpec(
        avatarAsset: _draft!.avatarAsset,
        displayName: _draft!.name.isNotEmpty ? _draft!.name : 'Custom Character',
        badgeText: badge,
        zoomLevel: _zoomLevel,
        panOffset: _panOffset,
        backdropPreset: _backdropPreset,
      );
    }
    return CharacterStageVisualSpec(
      avatarAsset: 'default_avatar',
      displayName: 'Character Studio',
      zoomLevel: _zoomLevel,
      panOffset: _panOffset,
      backdropPreset: _backdropPreset,
    );
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  bool _isSessionValid(int fenceSession, String? fenceProfile) {
    return !_isDisposed &&
        _sessionFenceId == fenceSession &&
        _boundProfileId == fenceProfile &&
        _sessionStatus != StudioSessionStatus.sessionExpiredOrRevoked;
  }

  bool _isAuthFailure(dynamic e) {
    if (e is CompanionApiException && (e.statusCode == 401 || e.statusCode == 403)) {
      return true;
    }
    final msg = e.toString();
    return msg.contains('401') ||
        msg.contains('403') ||
        msg.contains('Unauthorized') ||
        msg.contains('Forbidden');
  }

  void _handleAuthorizationLoss() {
    _sessionFenceId++;
    _readGeneration++;
    _isMutating = false;
    _boundProfileId = null;
    _instances = [];
    _activeState = null;
    _draft = null;
    _isNeutralSelected = false;
    _sessionStatus = StudioSessionStatus.sessionExpiredOrRevoked;
    _error = 'Profile authorization lost. Select or authenticate a Profile in Settings.';
    _notify();
    unawaited(chat.invalidateProfileSession(clearStoredToken: false));
  }

  void _onChatChanged() {
    _classifySession(
      status: chat.connectionStatus,
      authProfileId: chat.authenticatedProfileId,
      epoch: chat.profileEpoch,
    );
  }

  /// Public test helper to simulate chat controller state transitions directly.
  void simulateChatState({
    required RuntimeConnectionStatus connectionStatus,
    String? authenticatedProfileId,
    int? profileEpoch,
  }) {
    _classifySession(
      status: connectionStatus,
      authProfileId: authenticatedProfileId,
      epoch: profileEpoch ?? _boundProfileEpoch,
    );
  }

  void _classifySession({
    required RuntimeConnectionStatus status,
    required String? authProfileId,
    required int epoch,
  }) {
    // 1. Confirmed Unauthorized (Highest priority; even with unchanged profileEpoch)
    if (status == RuntimeConnectionStatus.unauthorized) {
      _sessionFenceId++;
      _readGeneration++;
      _isMutating = false;
      _boundProfileId = null;
      _instances = [];
      _activeState = null;
      _draft = null;
      _isNeutralSelected = false;
      _sessionStatus = StudioSessionStatus.sessionExpiredOrRevoked;
      _notify();
      return;
    }

    // 2. Confirmed Profile Switch
    if (authProfileId != null &&
        _boundProfileId != null &&
        (authProfileId != _boundProfileId || epoch != _boundProfileEpoch)) {
      _sessionFenceId++;
      _readGeneration++;
      _isMutating = false;
      _instances = [];
      _activeState = null;
      _draft = null;
      _isNeutralSelected = false;
      _boundProfileId = authProfileId;
      _boundProfileEpoch = epoch;
      _sessionStatus = StudioSessionStatus.confirmedProfileSwitch;
      _notify();
      loadStudioCatalog();
      return;
    }

    // 3. Transient probe (connecting / reconnecting with same profile)
    if (status == RuntimeConnectionStatus.connecting ||
        status == RuntimeConnectionStatus.reconnecting) {
      _sessionStatus = StudioSessionStatus.validatingConnection;
      _notify();
      return;
    }

    // 4. Runtime Offline (unconnected / error with same profile)
    if (status == RuntimeConnectionStatus.unconnected ||
        status == RuntimeConnectionStatus.error) {
      _sessionStatus = StudioSessionStatus.runtimeOffline;
      _notify();
      return;
    }

    // 5. Authenticated Ready
    if (status == RuntimeConnectionStatus.connected && authProfileId != null) {
      final wasNull = _boundProfileId == null;
      _boundProfileId = authProfileId;
      _boundProfileEpoch = epoch;
      _sessionStatus = StudioSessionStatus.authenticatedReady;
      _notify();
      if (wasNull) {
        loadStudioCatalog();
      }
    }
  }

  Future<void> loadStudioCatalog({bool reconcileUncertainWrite = false}) async {
    final fenceSession = _sessionFenceId;
    final fenceProfile = _boundProfileId;
    final readGen = ++_readGeneration;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final futures = await Future.wait([
        chat.client.listCharacterPresets(),
        chat.client.listCharacterTemplates(),
        chat.client.getNeutralAssistant(),
        chat.client.listCharacterInstances(includeArchived: true, includeLegacy: true),
        chat.client.getActiveCharacterState(),
      ]);

      if (!_isSessionValid(fenceSession, fenceProfile) || _readGeneration != readGen) {
        return; // Drop stale or superseded read
      }

      _presets = futures[0] as List<CharacterPresetOut>;
      _templates = futures[1] as List<CharacterTemplateOut>;
      _neutral = futures[2] as NeutralAssistantOut;
      _instances = futures[3] as List<CharacterInstanceOut>;
      _activeState = futures[4] as ActiveCharacterStateOut;

      if (reconcileUncertainWrite && _draft != null) {
        if (!_draft!.isNew && _draft!.instanceId != null) {
          // Reconcile uncertain update by exact instance ID only
          final matching = _instances.where((i) => i.id == _draft!.instanceId);
          if (matching.isNotEmpty) {
            _draft!.reconcileSavedInstance(matching.first, _draft!.revision);
            _uncertainWriteWarning = false;
          }
        }
        // If _draft.isNew: do NOT auto-confirm by matching editable fields.
        // The catalog refresh is read-only investigation; draft stays dirty.
      }
    } catch (e) {
      if (_isSessionValid(fenceSession, fenceProfile)) {
        if (_isAuthFailure(e)) {
          _handleAuthorizationLoss();
          return;
        }
        _error = 'Failed to load Character Studio: $e';
      }
    } finally {
      if (_isSessionValid(fenceSession, fenceProfile) && _readGeneration == readGen) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void selectTemplate(CharacterTemplateOut tmpl) {
    _isNeutralSelected = false;
    final defaultPreset = tmpl.defaultPresetId ?? 'custom';
    final initialTraits = tmpl.traits ??
        const CharacterTraitVector(
          warmth: 50, teasing: 50, guardedness: 50, directness: 50,
          expressiveness: 50, affection: 50, formality: 50, verbosity: 50,
        );

    _draft = CharacterStudioDraft(
      instanceId: null,
      sourceTemplateId: tmpl.id,
      isLegacyPlaceholder: false,
      name: tmpl.name,
      summary: tmpl.summary,
      lore: tmpl.lore,
      systemPrompt: tmpl.systemPrompt,
      avatarAsset: tmpl.avatarAsset,
      presetId: defaultPreset,
      traits: initialTraits,
      onChanged: _notify,
    );
    _uncertainCreateWarning = false;
    _uncertainWriteWarning = false;
    _notify();
  }

  void selectInstance(CharacterInstanceOut inst) {
    _isNeutralSelected = false;
    _selectInstanceDirect(inst);
    _notify();
  }

  void _selectInstanceDirect(CharacterInstanceOut inst) {
    _draft = CharacterStudioDraft(
      instanceId: inst.id,
      sourceTemplateId: inst.templateId ?? '',
      isLegacyPlaceholder: inst.isLegacyPlaceholder,
      name: inst.name,
      summary: inst.summary,
      lore: inst.lore,
      systemPrompt: inst.systemPrompt,
      avatarAsset: inst.avatarAsset,
      presetId: inst.presetId ?? 'custom',
      traits: inst.traits,
      onChanged: _notify,
    );
    _uncertainCreateWarning = false;
    _uncertainWriteWarning = false;
  }

  void selectNeutral() {
    _isNeutralSelected = true;
    _draft = null;
    _notify();
  }

  Future<bool> saveDraft({bool forceRetryCreate = false}) async {
    if (_isMutating || _draft == null || _draft!.isReadOnly) return false;

    // Guard against silent duplicate creation after uncertain outcome
    if (_draft!.isNew && _uncertainCreateWarning && !forceRetryCreate) {
      _error = 'Previous creation attempt timed out. Confirm retry to attempt creation again.';
      _notify();
      return false;
    }

    _isMutating = true;
    _error = null;
    _notify();

    final fenceSession = _sessionFenceId;
    final fenceProfile = _boundProfileId;
    final snapshotRevision = _draft!.revision;

    try {
      CharacterInstanceOut saved;
      if (_draft!.isNew) {
        saved = await chat.client.createCharacterInstance(
          CharacterInstanceCreate(
            templateId: _draft!.sourceTemplateId,
            name: _draft!.name,
            summary: _draft!.summary.isNotEmpty ? _draft!.summary : null,
            lore: _draft!.lore.isNotEmpty ? _draft!.lore : null,
            systemPrompt: _draft!.systemPrompt.isNotEmpty ? _draft!.systemPrompt : null,
            avatarAsset: _draft!.avatarAsset,
            presetId: _draft!.presetId,
            traits: _draft!.traits ??
                const CharacterTraitVector(
                  warmth: 50, teasing: 50, guardedness: 50, directness: 50,
                  expressiveness: 50, affection: 50, formality: 50, verbosity: 50,
                ),
          ),
        );
      } else {
        saved = await chat.client.updateCharacterInstance(
          _draft!.instanceId!,
          CharacterInstanceUpdate(
            name: _draft!.name,
            summary: _draft!.summary,
            lore: _draft!.lore,
            systemPrompt: _draft!.systemPrompt,
            avatarAsset: _draft!.avatarAsset,
            presetId: _draft!.presetId,
            traits: _draft!.traits,
          ),
        );
      }

      if (!_isSessionValid(fenceSession, fenceProfile)) {
        _isMutating = false;
        return false; // Dropped cross-session response
      }

      _readGeneration++;
      _draft!.reconcileSavedInstance(saved, snapshotRevision);
      _uncertainWriteWarning = false;
      _uncertainCreateWarning = false;
      _isMutating = false;
      _notify();

      // Trigger fresh post-mutation catalog reload
      await loadStudioCatalog();
      return true;
    } catch (e) {
      if (!_isSessionValid(fenceSession, fenceProfile)) {
        _isMutating = false;
        return false;
      }
      _isMutating = false;
      if (_isAuthFailure(e)) {
        _handleAuthorizationLoss();
        return false;
      }

      if (e.toString().contains('408') || e.toString().contains('Timeout') || e.toString().contains('SocketException')) {
        _uncertainWriteWarning = true;
        if (_draft!.isNew) {
          _uncertainCreateWarning = true;
          _error = 'Character creation timed out. The server outcome is uncertain; the character may have been created.';
          _notify();
          unawaited(loadStudioCatalog(reconcileUncertainWrite: false));
        } else {
          _error = 'Character update timed out. Investigating server state...';
          _notify();
          unawaited(loadStudioCatalog(reconcileUncertainWrite: true));
        }
      } else {
        _error = 'Failed to save changes: $e';
        _notify();
      }
      return false;
    }
  }

  Future<bool> retryCreateDraft() => saveDraft(forceRetryCreate: true);

  Future<bool> activateCharacter(String instanceId) async {
    if (_isMutating) return false;
    final inst = _instances.where((i) => i.id == instanceId).firstOrNull;
    if (inst?.isLegacyPlaceholder == true) {
      _error = 'Legacy placeholders cannot be activated.';
      _notify();
      return false;
    }
    _isMutating = true;
    _error = null;
    _notify();

    final fenceSession = _sessionFenceId;
    final fenceProfile = _boundProfileId;

    try {
      final updated = await chat.client.selectActiveCharacter(instanceId);
      if (!_isSessionValid(fenceSession, fenceProfile)) {
        _isMutating = false;
        return false;
      }
      _readGeneration++;
      _activeState = updated;
      _isMutating = false;
      _notify();
      return true;
    } catch (e) {
      if (!_isSessionValid(fenceSession, fenceProfile)) {
        _isMutating = false;
        return false;
      }
      _isMutating = false;
      if (_isAuthFailure(e)) {
        _handleAuthorizationLoss();
        return false;
      }
      _error = 'Failed to activate character: $e';
      _notify();
      return false;
    }
  }

  Future<bool> resetProfileToNeutral() async {
    if (_isMutating) return false;
    _isMutating = true;
    _error = null;
    _notify();

    final fenceSession = _sessionFenceId;
    final fenceProfile = _boundProfileId;

    try {
      final updated = await chat.client.resetActiveCharacterToNeutral();
      if (!_isSessionValid(fenceSession, fenceProfile)) {
        _isMutating = false;
        return false;
      }
      _readGeneration++;
      _activeState = updated;
      _isMutating = false;
      _notify();
      return true;
    } catch (e) {
      if (!_isSessionValid(fenceSession, fenceProfile)) {
        _isMutating = false;
        return false;
      }
      _isMutating = false;
      if (_isAuthFailure(e)) {
        _handleAuthorizationLoss();
        return false;
      }
      _error = 'Failed to reset to neutral: $e';
      _notify();
      return false;
    }
  }

  Future<bool> archiveInstance(String instanceId) async {
    if (_isMutating) return false;
    final inst = _instances.where((i) => i.id == instanceId).firstOrNull;
    if (inst?.isLegacyPlaceholder == true) {
      _error = 'Legacy placeholders cannot be archived.';
      _notify();
      return false;
    }
    _isMutating = true;
    _error = null;
    _notify();

    final fenceSession = _sessionFenceId;
    final fenceProfile = _boundProfileId;

    try {
      await chat.client.deleteCharacterInstance(instanceId);
      if (!_isSessionValid(fenceSession, fenceProfile)) {
        _isMutating = false;
        return false;
      }
      _readGeneration++;
      if (_draft?.instanceId == instanceId) {
        _draft = null;
        _isNeutralSelected = true;
      }
      _isMutating = false;
      _notify();
      await loadStudioCatalog();
      return true;
    } catch (e) {
      if (!_isSessionValid(fenceSession, fenceProfile)) {
        _isMutating = false;
        return false;
      }
      _isMutating = false;
      if (_isAuthFailure(e)) {
        _handleAuthorizationLoss();
        return false;
      }
      _error = 'Failed to archive character: $e';
      _notify();
      return false;
    }
  }

  void setBackdropPreset(StudioBackdropPreset preset) {
    if (_backdropPreset != preset) {
      _backdropPreset = preset;
      _notify();
    }
  }

  void updatePan(Offset delta) {
    if (_zoomLevel <= 1.0) {
      if (_panOffset != Offset.zero) {
        _panOffset = Offset.zero;
        _notify();
      }
      return;
    }
    final maxPanX = 180.0 * (_zoomLevel - 1.0);
    final maxPanY = 240.0 * (_zoomLevel - 1.0);
    final nextX = (_panOffset.dx + delta.dx).clamp(-maxPanX, maxPanX);
    final nextY = (_panOffset.dy + delta.dy).clamp(-maxPanY, maxPanY);
    _panOffset = Offset(nextX, nextY);
    _notify();
  }

  void zoomIn() {
    _zoomLevel = double.parse((_zoomLevel + 0.1).clamp(1.0, 2.0).toStringAsFixed(1));
    _notify();
  }

  void zoomOut() {
    _zoomLevel = double.parse((_zoomLevel - 0.1).clamp(1.0, 2.0).toStringAsFixed(1));
    if (_zoomLevel <= 1.0) {
      _panOffset = Offset.zero;
    }
    _notify();
  }

  void resetZoom() {
    _zoomLevel = 1.0;
    _panOffset = Offset.zero;
    _notify();
  }

  void toggleShowArchived() {
    _showArchived = !_showArchived;
    _notify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionFenceId++;
    chat.removeListener(_onChatChanged);
    super.dispose();
  }
}
