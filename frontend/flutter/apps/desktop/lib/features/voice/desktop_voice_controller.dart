import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:companion_api/companion_api.dart';
import 'package:flutter/foundation.dart';

import '../../platform/desktop_audio_adapter.dart';
import '../../platform/desktop_client_settings.dart';

/// Maximum decoded audio bytes accepted by `POST /api/v1/voice/transcribe` (~1.4 MiB).
const int kMaxTranscribePcmBytes = 1468006;

enum VoiceSessionPhase {
  idle,
  recordingDictation,
  transcribing,
  connectingWs,
  listening,
  thinking,
  speaking,
  errored,
}

/// Manages Desktop speech state: WASAPI capture/playback, Dictation, Live Duplex WS,
/// Read Aloud / Auto-Read, generation-fenced barge-in, hotkeys, and Profile isolation.
class DesktopVoiceController extends ChangeNotifier {
  DesktopVoiceController({
    required CompanionClient Function() clientProvider,
    DesktopAudioAdapter? audioAdapter,
    DesktopClientSettings? clientSettings,
    VoiceSessionClient Function()? voiceSessionClientFactory,
    Future<String?> Function()? ensureActiveConversationId,
    Future<void> Function(String conversationId)? onConversationMessagesUpdated,
    ValueChanged<bool>? onAudioMutedChanged,
    Future<void> Function()? onGlobalHotkeyTriggered,
  })  : _clientProvider = clientProvider,
        _audioAdapter = audioAdapter ??
            (NoOpDesktopAudioAdapter.shouldUseNoOp
                ? NoOpDesktopAudioAdapter()
                : WindowsWasapiAudioAdapter()),
        _ownsAudioAdapter = audioAdapter == null,
        _clientSettings = clientSettings,
        _voiceSessionClientFactory =
            voiceSessionClientFactory ?? (() => VoiceSessionClient()),
        _ensureActiveConversationId = ensureActiveConversationId,
        _onConversationMessagesUpdated = onConversationMessagesUpdated,
        _onAudioMutedChanged = onAudioMutedChanged,
        _onGlobalHotkeyTriggered = onGlobalHotkeyTriggered {
    _captureSub = _audioAdapter.captureFrames.listen(_handleCaptureFrame);
    _hotkeySub = _audioAdapter.globalHotkeyEvents.listen((_) {
      if (_isDisposed) return;
      final cb = _onGlobalHotkeyTriggered;
      if (cb != null) {
        unawaited(cb());
      }
    });
  }

  final CompanionClient Function() _clientProvider;
  final DesktopAudioAdapter _audioAdapter;
  final bool _ownsAudioAdapter;
  final DesktopClientSettings? _clientSettings;
  final VoiceSessionClient Function() _voiceSessionClientFactory;
  final Future<String?> Function()? _ensureActiveConversationId;
  final Future<void> Function(String conversationId)?
      _onConversationMessagesUpdated;
  final ValueChanged<bool>? _onAudioMutedChanged;
  final Future<void> Function()? _onGlobalHotkeyTriggered;

  StreamSubscription<CapturedAudioFrame>? _captureSub;
  StreamSubscription<void>? _hotkeySub;
  StreamSubscription<VoiceWsEvent>? _wsEventsSub;
  VoiceSessionClient? _voiceSession;

  VoiceSessionPhase _phase = VoiceSessionPhase.idle;
  VoiceStatusOut? _voiceStatus;
  VoiceCatalogOut? _voiceCatalog;
  VoiceSettingsOut? _voiceSettings;
  VoiceHardwarePrefs _hardwarePrefs = const VoiceHardwarePrefs();
  VoiceShortcutConfig _shortcuts = VoiceShortcutConfig.defaults();
  List<AudioDeviceInfo> _inputDevices = const [
    AudioDeviceInfo(id: '', name: 'Default Windows Microphone', isDefault: true),
  ];
  List<AudioDeviceInfo> _outputDevices = const [
    AudioDeviceInfo(id: '', name: 'Default Windows Speaker', isDefault: true),
  ];

  final List<int> _dictationPcmBuffer = <int>[];
  final ValueNotifier<double> _micRmsNotifier = ValueNotifier<double>(0.0);
  double _micRmsLevel = 0.0;
  bool _isTestingMic = false;
  Timer? _speakCompletionTimer;
  int _playbackGeneration = 0;
  int _profileEpoch = 0;
  int? _activeTurnId;
  String? _activeConversationId;
  String? _speakingMessageId;
  String? _liveUserTranscript;
  String? _liveAssistantTranscript;
  String? _activeToolHint;
  String? _globalHotkeyWarning;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _initialized = false;
  bool _isDisposed = false;

  VoiceSessionPhase get phase => _phase;
  bool get isLiveVoiceActive =>
      _phase == VoiceSessionPhase.connectingWs ||
      _phase == VoiceSessionPhase.listening ||
      _phase == VoiceSessionPhase.thinking ||
      _phase == VoiceSessionPhase.speaking;
  bool get isDictating => _phase == VoiceSessionPhase.recordingDictation;
  bool get isTranscribing => _phase == VoiceSessionPhase.transcribing;
  bool get isSpeaking => _phase == VoiceSessionPhase.speaking;
  bool get isMicCapturing =>
      _audioAdapter.isCapturing && !_hardwarePrefs.audioMuted;
  bool get isAudioMuted => _hardwarePrefs.audioMuted;
  bool get isTestingMic => _isTestingMic;
  double get micRmsLevel => _micRmsLevel;
  ValueListenable<double> get micRmsListenable => _micRmsNotifier;
  int get playbackGeneration => _playbackGeneration;
  int get profileEpoch => _profileEpoch;
  int? get activeTurnId => _activeTurnId;
  String? get speakingMessageId => _speakingMessageId;
  VoiceStatusOut? get voiceStatus => _voiceStatus;
  VoiceCatalogOut? get voiceCatalog => _voiceCatalog;
  VoiceSettingsOut? get voiceSettings => _voiceSettings;
  VoiceHardwarePrefs get hardwarePrefs => _hardwarePrefs;
  VoiceShortcutConfig get shortcuts => _shortcuts;
  List<AudioDeviceInfo> get inputDevices => List.unmodifiable(_inputDevices);
  List<AudioDeviceInfo> get outputDevices => List.unmodifiable(_outputDevices);
  String? get liveUserTranscript => _liveUserTranscript;
  String? get liveAssistantTranscript => _liveAssistantTranscript;
  String? get activeToolHint => _activeToolHint;
  String? get globalHotkeyWarning => _globalHotkeyWarning;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get initialized => _initialized;

  DesktopClientSettings? get _effectiveSettingsForDisk => _clientSettings ??
      (NoOpDesktopAudioAdapter.shouldUseNoOp ? null : DesktopClientSettings());

  Future<void> initialize() async {
    if (_isDisposed || _initialized) return;
    _initialized = true;
    final store = _effectiveSettingsForDisk;
    if (store != null) {
      _hardwarePrefs = await store.readVoiceHardwarePrefs();
      _shortcuts = await store.readVoiceShortcuts();
    }
    if (!NoOpDesktopAudioAdapter.shouldUseNoOp) {
      final reg = await _audioAdapter.registerGlobalHotkey(_shortcuts.globalToggle);
      _globalHotkeyWarning = reg.registered ? null : reg.errorMessage;
    }
    await refreshDevices();
    final tok = await _clientProvider().sessionStore.readToken();
    if (tok != null && tok.isNotEmpty) {
      await refreshBackendState();
    }
    if (!_isDisposed) notifyListeners();
  }

  Future<void> refreshDevices() async {
    try {
      final results = await Future.wait([
        _audioAdapter.listInputDevices(),
        _audioAdapter.listOutputDevices(),
      ]);
      if (_isDisposed) return;
      _inputDevices = results[0];
      _outputDevices = results[1];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshBackendState() async {
    if (_isDisposed) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final c = _clientProvider();
      final token = await c.sessionStore.readToken();
      if (token == null || token.isEmpty) {
        return;
      }
      final results = await Future.wait<dynamic>([
        c.getVoiceStatus(),
        c.listVoices(),
        c.getVoiceSettings(),
      ]);
      if (_isDisposed) return;
      _voiceStatus = results[0] as VoiceStatusOut;
      _voiceCatalog = results[1] as VoiceCatalogOut;
      _voiceSettings = results[2] as VoiceSettingsOut;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
      }
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshAll() async {
    await refreshDevices();
    await refreshBackendState();
  }

  Future<void> updateBackendSettings(VoiceSettingsUpdate update) async {
    if (_isDisposed) return;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await _clientProvider().updateVoiceSettings(update);
      if (_isDisposed) return;
      _voiceSettings = updated;
      if (isLiveVoiceActive && _voiceSession != null) {
        _voiceSession!.updateConfig(
          bargeInPolicy: update.bargeInPolicy,
          vadSensitivity: update.vadSensitivity,
          voiceId: update.defaultVoiceId,
          ttsSpeed: update.ttsSpeed,
          sttLanguage: update.sttLanguage,
        );
      }
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
      }
    } finally {
      if (!_isDisposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectInputDevice(String deviceId) async {
    _hardwarePrefs = _hardwarePrefs.copyWith(selectedMicDeviceId: deviceId);
    await _effectiveSettingsForDisk?.writeVoiceHardwarePrefs(_hardwarePrefs);
    if ((_isTestingMic || _phase == VoiceSessionPhase.recordingDictation || isLiveVoiceActive) &&
        !isAudioMuted) {
      await _audioAdapter.startCapture(deviceId: deviceId);
    }
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> startMicTest() async {
    if (_isDisposed || _isTestingMic) return;
    if (isAudioMuted) {
      _errorMessage = 'Audio/Mic is muted. Unmute first to test microphone.';
      notifyListeners();
      return;
    }
    if (_phase != VoiceSessionPhase.idle) return;
    _isTestingMic = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _audioAdapter.startCapture(
        deviceId: _hardwarePrefs.selectedMicDeviceId,
      );
    } catch (e) {
      _isTestingMic = false;
      _errorMessage = 'Failed to open Windows microphone: $e';
      notifyListeners();
    }
  }

  Future<void> stopMicTest() async {
    if (!_isTestingMic) return;
    _isTestingMic = false;
    _micRmsLevel = 0.0;
    _micRmsNotifier.value = 0.0;
    await _audioAdapter.stopCapture();
    if (!_isDisposed) notifyListeners();
  }

  Future<void> selectOutputDevice(String deviceId) async {
    _hardwarePrefs = _hardwarePrefs.copyWith(selectedSpeakerDeviceId: deviceId);
    await _effectiveSettingsForDisk?.writeVoiceHardwarePrefs(_hardwarePrefs);
    notifyListeners();
  }

  Future<void> playTestTone() async {
    if (isAudioMuted) {
      _errorMessage = 'Audio is muted. Unmute first to test speaker output.';
      notifyListeners();
      return;
    }
    await _audioAdapter.playTestTone(
      deviceId: _hardwarePrefs.selectedSpeakerDeviceId,
    );
  }

  Future<String?> updateShortcuts(VoiceShortcutConfig next) async {
    final conflict = next.validateConflict();
    if (conflict != null) {
      _globalHotkeyWarning = conflict;
      notifyListeners();
      return conflict;
    }
    _shortcuts = next;
    await _effectiveSettingsForDisk?.writeVoiceShortcuts(next);
    final reg = await _audioAdapter.registerGlobalHotkey(next.globalToggle);
    _globalHotkeyWarning = reg.registered ? null : reg.errorMessage;
    notifyListeners();
    return _globalHotkeyWarning;
  }

  Future<String?> resetShortcutsToDefaults() {
    return updateShortcuts(VoiceShortcutConfig.defaults());
  }

  /// Toggles hard mute: stops OS mic capture, tears down live voice session,
  /// bumps playback generation, and flushes queued WASAPI audio immediately.
  Future<void> setMuted(bool muted) async {
    if (_isDisposed) return;
    _hardwarePrefs = _hardwarePrefs.copyWith(audioMuted: muted);
    await _effectiveSettingsForDisk?.writeVoiceHardwarePrefs(_hardwarePrefs);
    _onAudioMutedChanged?.call(muted);

    if (muted) {
      _speakCompletionTimer?.cancel();
      _speakCompletionTimer = null;
      _playbackGeneration++;
      await _audioAdapter.flushPlayback(_playbackGeneration);
      _speakingMessageId = null;
      if (_isTestingMic) {
        _isTestingMic = false;
        await _audioAdapter.stopCapture();
        _micRmsLevel = 0.0;
        _micRmsNotifier.value = 0.0;
      } else if (isLiveVoiceActive) {
        await stopLiveVoice();
      } else if (_phase == VoiceSessionPhase.recordingDictation) {
        await _audioAdapter.stopCapture();
        _dictationPcmBuffer.clear();
        _micRmsLevel = 0.0;
        _micRmsNotifier.value = 0.0;
        _phase = VoiceSessionPhase.idle;
      }
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Starts single-shot ephemeral mic dictation into RAM.
  Future<bool> startDictation() async {
    if (_isDisposed) return false;
    if (isAudioMuted) {
      _errorMessage = 'Audio/Mic is muted. Unmute first to dictate.';
      notifyListeners();
      return false;
    }
    if (_isTestingMic) {
      await stopMicTest();
    }
    if (isLiveVoiceActive) {
      await stopLiveVoice();
    }
    if (_isTestingMic) {
      await stopMicTest();
    }
    await stopSpeaking();
    _errorMessage = null;
    _dictationPcmBuffer.clear();
    _micRmsLevel = 0.0;
    _micRmsNotifier.value = 0.0;
    _phase = VoiceSessionPhase.recordingDictation;
    notifyListeners();
    try {
      await _audioAdapter.startCapture(
        deviceId: _hardwarePrefs.selectedMicDeviceId,
      );
      return true;
    } catch (e) {
      _phase = VoiceSessionPhase.errored;
      _errorMessage = 'Failed to open Windows microphone: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stops dictation capture immediately and transcribes RAM buffer via POST /api/v1/voice/transcribe.
  Future<String?> stopDictationAndTranscribe() async {
    if (_phase != VoiceSessionPhase.recordingDictation) return null;
    await _audioAdapter.stopCapture();
    _micRmsLevel = 0.0;
    _micRmsNotifier.value = 0.0;
    final bytes = Uint8List.fromList(_dictationPcmBuffer);
    _dictationPcmBuffer.clear();

    if (bytes.isEmpty) {
      _phase = VoiceSessionPhase.idle;
      notifyListeners();
      return null;
    }

    _phase = VoiceSessionPhase.transcribing;
    notifyListeners();
    try {
      final res = await _clientProvider().transcribeAudio(
        VoiceTranscribeRequest(
          audioBase64: base64Encode(bytes),
          format: 'pcm16',
          sampleRate: 16000,
          language: _voiceSettings?.sttLanguage,
        ),
      );
      if (!_isDisposed) {
        _phase = VoiceSessionPhase.idle;
        notifyListeners();
      }
      final text = res.text.trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      if (!_isDisposed) {
        _phase = VoiceSessionPhase.idle;
        _errorMessage = e.toString();
        notifyListeners();
      }
      return null;
    }
  }

  static List<String> _splitSpeakSentences(String rawText) {
    final trimmed = rawText.trim();
    final bounded = trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed;
    final parts = bounded
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length <= 1) return parts.isEmpty ? [bounded] : parts;

    final merged = <String>[];
    for (final part in parts) {
      if (merged.isNotEmpty && merged.last.length < 24) {
        merged[merged.length - 1] = '${merged.last} $part';
      } else {
        merged.add(part);
      }
    }
    return merged;
  }

  /// Reads aloud a specific chat message (or toggles stop if already speaking it).
  Future<void> speakMessage({
    required String messageId,
    required String text,
    String? overrideVoiceId,
  }) async {
    if (_isDisposed || text.trim().isEmpty) return;
    if (_speakingMessageId == messageId) {
      await stopSpeaking();
      return;
    }
    if (isAudioMuted) {
      _errorMessage = 'Audio is muted. Unmute first to play speech.';
      notifyListeners();
      return;
    }

    _speakCompletionTimer?.cancel();
    _speakCompletionTimer = null;
    final gen = ++_playbackGeneration;
    await _audioAdapter.flushPlayback(gen);
    _speakingMessageId = messageId;
    _errorMessage = null;
    notifyListeners();

    final epochAtStart = _profileEpoch;
    final chunks = _splitSpeakSentences(text);
    int remainingPlaybackMs = 0;
    try {
      for (final chunk in chunks) {
        if (_isDisposed ||
            epochAtStart != _profileEpoch ||
            gen != _playbackGeneration ||
            isAudioMuted ||
            _speakingMessageId != messageId) {
          return;
        }
        final synthSw = Stopwatch()..start();
        final res = await _clientProvider().synthesizeSpeech(
          VoiceSynthesizeRequest(
            text: chunk,
            voiceId: overrideVoiceId,
            speed: _voiceSettings?.ttsSpeed,
          ),
        );
        synthSw.stop();
        if (_isDisposed ||
            epochAtStart != _profileEpoch ||
            gen != _playbackGeneration ||
            isAudioMuted ||
            _speakingMessageId != messageId) {
          return;
        }
        remainingPlaybackMs =
            math.max(0, remainingPlaybackMs - synthSw.elapsedMilliseconds) +
                math.max(0, res.durationMs);
        final wavBytes = base64Decode(res.audioBase64);
        await _audioAdapter.playAudio(
          wavBytes,
          deviceId: _hardwarePrefs.selectedSpeakerDeviceId,
          sampleRate: res.sampleRate,
          generation: gen,
        );
      }
      if (!_isDisposed &&
          gen == _playbackGeneration &&
          _speakingMessageId == messageId) {
        final clearDelayMs = math.max(1200, remainingPlaybackMs + 400);
        _speakCompletionTimer = Timer(Duration(milliseconds: clearDelayMs), () {
          if (!_isDisposed &&
              _playbackGeneration == gen &&
              _speakingMessageId == messageId) {
            _speakingMessageId = null;
            notifyListeners();
          }
        });
      }
    } catch (e) {
      if (!_isDisposed && gen == _playbackGeneration) {
        _speakingMessageId = null;
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  /// Previews a Studio voice sample on the currently selected speaker.
  Future<void> previewVoice(String? voiceId) async {
    await speakMessage(
      messageId: 'studio-preview-${voiceId ?? 'default'}',
      text: 'Hello, this is how your companion voice sounds.',
      overrideVoiceId: voiceId,
    );
  }

  Future<void> stopSpeaking() async {
    _speakCompletionTimer?.cancel();
    _speakCompletionTimer = null;
    _playbackGeneration++;
    _speakingMessageId = null;
    await _audioAdapter.flushPlayback(_playbackGeneration);
    if (!_isDisposed) notifyListeners();
  }

  /// Speaks newly completed text replies when Auto-Read is enabled and Live Voice isn't running.
  Future<void> handleChatCompletionForAutoRead(MessageOut? latestAssistantMessage) async {
    if (_isDisposed || isLiveVoiceActive || isAudioMuted) return;
    if (!(_voiceSettings?.autoReadReplies ?? false)) return;
    if (latestAssistantMessage == null ||
        latestAssistantMessage.sender != 'assistant') {
      return;
    }
    if (latestAssistantMessage.status != 'completed' &&
        latestAssistantMessage.status != 'length') {
      return;
    }
    if (latestAssistantMessage.content.trim().isEmpty) return;

    await speakMessage(
      messageId: latestAssistantMessage.id,
      text: latestAssistantMessage.content,
    );
  }

  /// Starts full-duplex `WS /api/v1/voice/ws` session + continuous WASAPI mic capture.
  Future<void> startLiveVoice() async {
    if (_isDisposed) return;
    if (isAudioMuted) {
      _errorMessage = 'Audio/Mic is muted. Unmute first to start Live Voice.';
      notifyListeners();
      return;
    }
    if (isLiveVoiceActive) return;

    if (_isTestingMic) {
      await stopMicTest();
    }
    await stopSpeaking();
    _errorMessage = null;
    _liveUserTranscript = null;
    _liveAssistantTranscript = null;
    _activeToolHint = null;
    _activeTurnId = null;
    _phase = VoiceSessionPhase.connectingWs;
    notifyListeners();

    final epochAtStart = _profileEpoch;
    try {
      String? convId;
      if (_ensureActiveConversationId != null) {
        convId = await _ensureActiveConversationId();
      }
      if (_isDisposed || epochAtStart != _profileEpoch) return;
      if (convId == null || convId.isEmpty) {
        _phase = VoiceSessionPhase.idle;
        _errorMessage = 'Select or create a conversation first to use Live Voice.';
        notifyListeners();
        return;
      }

      _activeConversationId = convId;
      final sessionClient = _voiceSessionClientFactory();
      _voiceSession = sessionClient;
      await _wsEventsSub?.cancel();
      _wsEventsSub = sessionClient.events.listen(
        _handleWsEvent,
        onError: (Object error) {
          if (_isDisposed) return;
          _errorMessage = error.toString();
          notifyListeners();
        },
      );

      final client = _clientProvider();
      await sessionClient.connect(
        baseUri: client.baseUri,
        sessionStore: client.sessionStore,
        conversationId: convId,
      );
      if (_isDisposed || epochAtStart != _profileEpoch) {
        await sessionClient.dispose();
        return;
      }

      await _audioAdapter.startCapture(
        deviceId: _hardwarePrefs.selectedMicDeviceId,
      );
      if (_isDisposed || epochAtStart != _profileEpoch) {
        await stopLiveVoice();
        return;
      }
      _phase = VoiceSessionPhase.listening;
      notifyListeners();
    } catch (e) {
      await _teardownLiveSessionOnly();
      if (!_isDisposed) {
        _phase = VoiceSessionPhase.idle;
        _errorMessage = 'Failed to start Live Voice session: $e';
        notifyListeners();
      }
    }
  }

  Future<void> commitLiveUtterance() async {
    if (!isLiveVoiceActive) return;
    _voiceSession?.commitAudio();
  }

  /// Immediate barge-in cut: bumps local playback generation, flushes C++ mixer (<50ms),
  /// and transmits `barge_in` frame over WS.
  Future<void> interruptBargeIn({String reason = 'user_interrupt'}) async {
    _playbackGeneration++;
    await _audioAdapter.flushPlayback(_playbackGeneration);
    if (isLiveVoiceActive) {
      _voiceSession?.sendBargeIn(reason: reason);
      _phase = VoiceSessionPhase.listening;
    }
    if (!_isDisposed) notifyListeners();
  }

  Future<void> stopLiveVoice() async {
    _phase = VoiceSessionPhase.idle;
    _micRmsLevel = 0.0;
    _micRmsNotifier.value = 0.0;
    if (!_isDisposed) notifyListeners();
    await _teardownLiveSessionOnly();
    if (!_isDisposed) notifyListeners();
  }

  /// Handles Profile switching, lock, or sign-out cleanly by tearing down mic/playback/WS.
  Future<void> handleProfileEpochChanged(int newEpoch) async {
    if (_isDisposed || newEpoch == _profileEpoch) return;
    _profileEpoch = newEpoch;
    _speakCompletionTimer?.cancel();
    _speakCompletionTimer = null;
    _playbackGeneration++;
    _isTestingMic = false;
    await _teardownLiveSessionOnly();
    _dictationPcmBuffer.clear();
    _speakingMessageId = null;
    _liveUserTranscript = null;
    _liveAssistantTranscript = null;
    _activeToolHint = null;
    _activeConversationId = null;
    _voiceSettings = null;
    _voiceCatalog = null;
    _micRmsLevel = 0.0;
    _micRmsNotifier.value = 0.0;
    _phase = VoiceSessionPhase.idle;
    notifyListeners();

    final token = await _clientProvider().sessionStore.readToken();
    if (token != null && token.isNotEmpty) {
      await refreshBackendState();
    }
  }

  Future<void> _teardownLiveSessionOnly() async {
    _playbackGeneration++;
    await _audioAdapter.stopCapture();
    await _audioAdapter.flushPlayback(_playbackGeneration);
    await _wsEventsSub?.cancel();
    _wsEventsSub = null;
    final ws = _voiceSession;
    _voiceSession = null;
    if (ws != null) {
      try {
        ws.stopSession();
      } catch (_) {}
      await ws.dispose();
    }
  }

  void _handleCaptureFrame(CapturedAudioFrame frame) {
    if (_isDisposed || _hardwarePrefs.audioMuted) return;
    _micRmsLevel = frame.rms;
    _micRmsNotifier.value = frame.rms;

    if (_phase == VoiceSessionPhase.recordingDictation) {
      if (_dictationPcmBuffer.length + frame.pcm16Bytes.length <=
          kMaxTranscribePcmBytes) {
        _dictationPcmBuffer.addAll(frame.pcm16Bytes);
      }
      return;
    }

    if (isLiveVoiceActive && _voiceSession != null) {
      _voiceSession!.sendAudioChunk(frame.pcm16Bytes, sampleRate: 16000);
    }
  }

  void _handleWsEvent(VoiceWsEvent event) {
    if (_isDisposed) return;
    if (event.turnId != null) {
      _activeTurnId = event.turnId;
    }

    switch (event.type) {
      case 'session.ready':
        _phase = VoiceSessionPhase.listening;
        break;
      case 'vad.state':
        if (event.state == 'barge_in_triggered') {
          final gen = ++_playbackGeneration;
          unawaited(_audioAdapter.flushPlayback(gen));
          _liveAssistantTranscript = '';
          _phase = VoiceSessionPhase.listening;
        }
        break;
      case 'turn.cancelled':
        final gen = ++_playbackGeneration;
        unawaited(_audioAdapter.flushPlayback(gen));
        _phase = VoiceSessionPhase.listening;
        break;
      case 'stt.final':
        _liveUserTranscript = event.text ?? _liveUserTranscript;
        _liveAssistantTranscript = '';
        _activeToolHint = null;
        _phase = VoiceSessionPhase.thinking;
        final cid = _activeConversationId;
        if (cid != null && _onConversationMessagesUpdated != null) {
          unawaited(_onConversationMessagesUpdated(cid));
        }
        break;
      case 'llm.delta':
        final chunk = event.content ?? '';
        if (chunk.isNotEmpty) {
          _liveAssistantTranscript = '${_liveAssistantTranscript ?? ''}$chunk';
          _phase = VoiceSessionPhase.speaking;
        }
        break;
      case 'tool.intent':
        _activeToolHint = 'Running ${event.toolName ?? 'tool'}...';
        break;
      case 'tool.confirmation_required':
        _activeToolHint = 'Confirmation required for ${event.toolName ?? 'action'}';
        final cidConf = _activeConversationId;
        if (cidConf != null && _onConversationMessagesUpdated != null) {
          unawaited(_onConversationMessagesUpdated(cidConf));
        }
        break;
      case 'tool.result':
        _activeToolHint = null;
        break;
      case 'tts.audio.chunk':
        final b64 = event.wavBase64;
        if (!isAudioMuted && b64 != null && b64.isNotEmpty) {
          _phase = VoiceSessionPhase.speaking;
          final bytes = base64Decode(b64);
          unawaited(
            _audioAdapter.playAudio(
              bytes,
              deviceId: _hardwarePrefs.selectedSpeakerDeviceId,
              sampleRate: event.sampleRate ?? 24000,
              generation: _playbackGeneration,
            ),
          );
        }
        break;
      case 'tts.end':
        _phase = VoiceSessionPhase.listening;
        _activeToolHint = null;
        final cidEnd = _activeConversationId;
        if (cidEnd != null && _onConversationMessagesUpdated != null) {
          unawaited(_onConversationMessagesUpdated(cidEnd));
        }
        break;
      case 'error':
        _errorMessage = event.message ?? event.code ?? 'Voice turn error';
        break;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _speakCompletionTimer?.cancel();
    _speakCompletionTimer = null;
    _micRmsNotifier.dispose();
    unawaited(_captureSub?.cancel());
    unawaited(_hotkeySub?.cancel());
    unawaited(_teardownLiveSessionOnly());
    if (_ownsAudioAdapter) {
      unawaited(_audioAdapter.dispose());
    }
    super.dispose();
  }
}
