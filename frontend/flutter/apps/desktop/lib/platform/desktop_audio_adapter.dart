import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Metadata describing an OS audio input or output endpoint.
class AudioDeviceInfo {
  const AudioDeviceInfo({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final bool isDefault;

  factory AudioDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return AudioDeviceInfo(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unknown Audio Device',
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isDefault': isDefault,
      };
}

/// Device-local hardware selections and hard mute flag stored on Windows host.
class VoiceHardwarePrefs {
  const VoiceHardwarePrefs({
    this.selectedMicDeviceId = '',
    this.selectedSpeakerDeviceId = '',
    this.audioMuted = false,
  });

  final String selectedMicDeviceId;
  final String selectedSpeakerDeviceId;
  final bool audioMuted;

  VoiceHardwarePrefs copyWith({
    String? selectedMicDeviceId,
    String? selectedSpeakerDeviceId,
    bool? audioMuted,
  }) {
    return VoiceHardwarePrefs(
      selectedMicDeviceId: selectedMicDeviceId ?? this.selectedMicDeviceId,
      selectedSpeakerDeviceId: selectedSpeakerDeviceId ?? this.selectedSpeakerDeviceId,
      audioMuted: audioMuted ?? this.audioMuted,
    );
  }

  factory VoiceHardwarePrefs.fromJson(Map<String, dynamic> json) {
    return VoiceHardwarePrefs(
      selectedMicDeviceId: (json['selectedMicDeviceId'] as String?) ?? '',
      selectedSpeakerDeviceId: (json['selectedSpeakerDeviceId'] as String?) ?? '',
      audioMuted: json['audioMuted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'selectedMicDeviceId': selectedMicDeviceId,
        'selectedSpeakerDeviceId': selectedSpeakerDeviceId,
        'audioMuted': audioMuted,
      };
}

/// Customizable keyboard binding for in-app or Win32 global hotkeys.
class VoiceShortcutBinding {
  const VoiceShortcutBinding({
    required this.ctrl,
    required this.alt,
    required this.shift,
    required this.virtualKey,
    required this.label,
  });

  final bool ctrl;
  final bool alt;
  final bool shift;
  final int virtualKey;
  final String label;

  /// Win32 RegisterHotKey MOD_* bitmask (`MOD_ALT=1`, `MOD_CONTROL=2`, `MOD_SHIFT=4`).
  int get win32Modifiers {
    var mask = 0;
    if (alt) mask |= 0x0001;
    if (ctrl) mask |= 0x0002;
    if (shift) mask |= 0x0004;
    return mask;
  }

  String get normalizedSignature =>
      '${ctrl ? 'C' : ''}${alt ? 'A' : ''}${shift ? 'S' : ''}:$virtualKey';

  factory VoiceShortcutBinding.fromJson(
    Map<String, dynamic> json,
    VoiceShortcutBinding fallback,
  ) {
    final vk = (json['virtualKey'] as num?)?.toInt();
    final lbl = (json['label'] as String?)?.trim();
    if (vk == null || vk <= 0 || lbl == null || lbl.isEmpty) {
      return fallback;
    }
    return VoiceShortcutBinding(
      ctrl: json['ctrl'] as bool? ?? false,
      alt: json['alt'] as bool? ?? false,
      shift: json['shift'] as bool? ?? false,
      virtualKey: vk,
      label: lbl,
    );
  }

  Map<String, dynamic> toJson() => {
        'ctrl': ctrl,
        'alt': alt,
        'shift': shift,
        'virtualKey': virtualKey,
        'label': label,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceShortcutBinding &&
          ctrl == other.ctrl &&
          alt == other.alt &&
          shift == other.shift &&
          virtualKey == other.virtualKey;

  @override
  int get hashCode => Object.hash(ctrl, alt, shift, virtualKey);
}

/// Complete customizable shortcut configuration for Desktop voice controls.
class VoiceShortcutConfig {
  const VoiceShortcutConfig({
    required this.inAppToggle,
    required this.globalToggle,
    required this.muteToggle,
    required this.pushToTalk,
  });

  final VoiceShortcutBinding inAppToggle;
  final VoiceShortcutBinding globalToggle;
  final VoiceShortcutBinding muteToggle;
  final VoiceShortcutBinding pushToTalk;

  factory VoiceShortcutConfig.defaults() {
    return const VoiceShortcutConfig(
      inAppToggle: VoiceShortcutBinding(
        ctrl: true,
        alt: false,
        shift: true,
        virtualKey: 0x56, // V
        label: 'Ctrl+Shift+V',
      ),
      globalToggle: VoiceShortcutBinding(
        ctrl: true,
        alt: true,
        shift: false,
        virtualKey: 0x56, // V
        label: 'Ctrl+Alt+V',
      ),
      muteToggle: VoiceShortcutBinding(
        ctrl: true,
        alt: false,
        shift: true,
        virtualKey: 0x4D, // M
        label: 'Ctrl+Shift+M',
      ),
      pushToTalk: VoiceShortcutBinding(
        ctrl: false,
        alt: false,
        shift: false,
        virtualKey: 0xA5, // VK_RMENU (Right Alt)
        label: 'Right Alt',
      ),
    );
  }

  VoiceShortcutConfig copyWith({
    VoiceShortcutBinding? inAppToggle,
    VoiceShortcutBinding? globalToggle,
    VoiceShortcutBinding? muteToggle,
    VoiceShortcutBinding? pushToTalk,
  }) {
    return VoiceShortcutConfig(
      inAppToggle: inAppToggle ?? this.inAppToggle,
      globalToggle: globalToggle ?? this.globalToggle,
      muteToggle: muteToggle ?? this.muteToggle,
      pushToTalk: pushToTalk ?? this.pushToTalk,
    );
  }

  /// Validates against duplicate bindings and reserved Windows shortcuts (Alt+Space).
  String? validateConflict() {
    final all = [
      ('In-App Voice', inAppToggle),
      ('Global Windows Hotkey', globalToggle),
      ('Mute Microphone', muteToggle),
      ('Push-to-Talk', pushToTalk),
    ];

    for (final (name, binding) in all) {
      if (binding.alt &&
          !binding.ctrl &&
          !binding.shift &&
          binding.virtualKey == 0x20) {
        return '$name cannot use Alt+Space (reserved by Windows window menu).';
      }
    }

    final seen = <String, String>{};
    for (final (name, binding) in all) {
      final sig = binding.normalizedSignature;
      if (seen.containsKey(sig)) {
        return 'Duplicate shortcut conflict between ${seen[sig]} and $name (${binding.label}).';
      }
      seen[sig] = name;
    }
    return null;
  }

  factory VoiceShortcutConfig.fromJson(Map<String, dynamic> json) {
    final def = VoiceShortcutConfig.defaults();
    VoiceShortcutBinding readKey(String key, VoiceShortcutBinding fallback) {
      final raw = json[key];
      if (raw is Map<String, dynamic>) {
        return VoiceShortcutBinding.fromJson(raw, fallback);
      }
      if (raw is Map) {
        return VoiceShortcutBinding.fromJson(Map<String, dynamic>.from(raw), fallback);
      }
      return fallback;
    }

    return VoiceShortcutConfig(
      inAppToggle: readKey('inAppToggle', def.inAppToggle),
      globalToggle: readKey('globalToggle', def.globalToggle),
      muteToggle: readKey('muteToggle', def.muteToggle),
      pushToTalk: readKey('pushToTalk', def.pushToTalk),
    );
  }

  Map<String, dynamic> toJson() => {
        'inAppToggle': inAppToggle.toJson(),
        'globalToggle': globalToggle.toJson(),
        'muteToggle': muteToggle.toJson(),
        'pushToTalk': pushToTalk.toJson(),
      };
}

class HotkeyRegistrationResult {
  const HotkeyRegistrationResult({
    required this.registered,
    this.errorMessage,
  });

  final bool registered;
  final String? errorMessage;
}

class CapturedAudioFrame {
  const CapturedAudioFrame({
    required this.pcm16Bytes,
    required this.rms,
  });

  final Uint8List pcm16Bytes;
  final double rms;
}

/// Platform-neutral Windows audio hardware + global hotkey contract (`PC-VOICE-001`).
abstract class DesktopAudioAdapter {
  bool get isCapturing;

  Stream<CapturedAudioFrame> get captureFrames;

  Stream<void> get globalHotkeyEvents;

  Future<List<AudioDeviceInfo>> listInputDevices();

  Future<List<AudioDeviceInfo>> listOutputDevices();

  Future<void> startCapture({String? deviceId});

  Future<void> stopCapture();

  Future<void> playAudio(
    Uint8List wavOrPcmBytes, {
    String? deviceId,
    int sampleRate = 24000,
    int generation = 0,
  });

  Future<void> flushPlayback(int minGeneration);

  Future<void> playTestTone({String? deviceId});

  Future<HotkeyRegistrationResult> registerGlobalHotkey(
    VoiceShortcutBinding binding,
  );

  Future<void> unregisterGlobalHotkey();

  Future<void> dispose();
}

/// Native Windows WASAPI + Win32 `RegisterHotKey` implementation via MethodChannel.
class WindowsWasapiAudioAdapter implements DesktopAudioAdapter {
  static const String channelName = 'ai_companion/windows_audio';

  final MethodChannel _channel;
  final StreamController<CapturedAudioFrame> _captureController =
      StreamController<CapturedAudioFrame>.broadcast();
  final StreamController<void> _hotkeyController =
      StreamController<void>.broadcast();
  bool _isCapturing = false;
  bool _disposed = false;

  WindowsWasapiAudioAdapter({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  @override
  bool get isCapturing => _isCapturing;

  @override
  Stream<CapturedAudioFrame> get captureFrames => _captureController.stream;

  @override
  Stream<void> get globalHotkeyEvents => _hotkeyController.stream;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (_disposed) return null;
    if (call.method == 'onCaptureFrame') {
      final args = call.arguments as Map?;
      if (args == null) return null;
      final bytes = args['pcm16'] as Uint8List?;
      final rms = (args['rms'] as num?)?.toDouble() ?? 0.0;
      if (bytes != null && bytes.isNotEmpty && !_captureController.isClosed) {
        _captureController.add(CapturedAudioFrame(pcm16Bytes: bytes, rms: rms));
      }
    } else if (call.method == 'onGlobalHotkey') {
      if (!_hotkeyController.isClosed) {
        _hotkeyController.add(null);
      }
    }
    return null;
  }

  @override
  Future<List<AudioDeviceInfo>> listInputDevices() async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'enumerateDevices',
      {'kind': 'capture'},
    );
    if (result == null) return const [AudioDeviceInfo(id: '', name: 'Default Windows Microphone', isDefault: true)];
    return result
        .whereType<Map<dynamic, dynamic>>()
        .map(AudioDeviceInfo.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<AudioDeviceInfo>> listOutputDevices() async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'enumerateDevices',
      {'kind': 'render'},
    );
    if (result == null) return const [AudioDeviceInfo(id: '', name: 'Default Windows Speaker', isDefault: true)];
    return result
        .whereType<Map<dynamic, dynamic>>()
        .map(AudioDeviceInfo.fromMap)
        .toList(growable: false);
  }

  @override
  Future<void> startCapture({String? deviceId}) async {
    await _channel.invokeMethod<void>('startCapture', {
      'deviceId': deviceId ?? '',
    });
    _isCapturing = true;
  }

  @override
  Future<void> stopCapture() async {
    try {
      await _channel.invokeMethod<void>('stopCapture');
    } finally {
      _isCapturing = false;
    }
  }

  @override
  Future<void> playAudio(
    Uint8List wavOrPcmBytes, {
    String? deviceId,
    int sampleRate = 24000,
    int generation = 0,
  }) async {
    await _channel.invokeMethod<void>('playAudio', {
      'bytes': wavOrPcmBytes,
      'deviceId': deviceId ?? '',
      'sampleRate': sampleRate,
      'generation': generation,
    });
  }

  @override
  Future<void> flushPlayback(int minGeneration) async {
    await _channel.invokeMethod<void>('flushPlayback', {
      'minGeneration': minGeneration,
    });
  }

  @override
  Future<void> playTestTone({String? deviceId}) async {
    await _channel.invokeMethod<void>('playTestTone', {
      'deviceId': deviceId ?? '',
    });
  }

  @override
  Future<HotkeyRegistrationResult> registerGlobalHotkey(
    VoiceShortcutBinding binding,
  ) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'registerGlobalHotkey',
      {
        'modifiers': binding.win32Modifiers,
        'virtualKey': binding.virtualKey,
      },
    );
    final registered = res?['registered'] as bool? ?? false;
    final errorCode = (res?['errorCode'] as num?)?.toInt();
    return HotkeyRegistrationResult(
      registered: registered,
      errorMessage: registered
          ? null
          : 'Could not register ${binding.label} globally (Win32 error ${errorCode ?? 'unknown'}). It may be claimed by another app.',
    );
  }

  @override
  Future<void> unregisterGlobalHotkey() async {
    await _channel.invokeMethod<void>('unregisterGlobalHotkey');
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _channel.setMethodCallHandler(null);
    await stopCapture();
    await unregisterGlobalHotkey();
    await _captureController.close();
    await _hotkeyController.close();
  }
}

/// Safe no-op audio adapter for headless widget tests and non-Windows platforms.
class NoOpDesktopAudioAdapter implements DesktopAudioAdapter {
  final StreamController<CapturedAudioFrame> _captureController =
      StreamController<CapturedAudioFrame>.broadcast();
  final StreamController<void> _hotkeyController =
      StreamController<void>.broadcast();
  bool _isCapturing = false;

  static bool get shouldUseNoOp =>
      Platform.environment.containsKey('FLUTTER_TEST') || !Platform.isWindows;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Stream<CapturedAudioFrame> get captureFrames => _captureController.stream;

  @override
  Stream<void> get globalHotkeyEvents => _hotkeyController.stream;

  @override
  Future<List<AudioDeviceInfo>> listInputDevices() async => const [
        AudioDeviceInfo(id: '', name: 'Default Windows Microphone', isDefault: true),
      ];

  @override
  Future<List<AudioDeviceInfo>> listOutputDevices() async => const [
        AudioDeviceInfo(id: '', name: 'Default Windows Speaker', isDefault: true),
      ];

  @override
  Future<void> startCapture({String? deviceId}) async {
    _isCapturing = true;
  }

  @override
  Future<void> stopCapture() async {
    _isCapturing = false;
  }

  @override
  Future<void> playAudio(
    Uint8List wavOrPcmBytes, {
    String? deviceId,
    int sampleRate = 24000,
    int generation = 0,
  }) async {}

  @override
  Future<void> flushPlayback(int minGeneration) async {}

  @override
  Future<void> playTestTone({String? deviceId}) async {}

  @override
  Future<HotkeyRegistrationResult> registerGlobalHotkey(
    VoiceShortcutBinding binding,
  ) async =>
      const HotkeyRegistrationResult(registered: true);

  @override
  Future<void> unregisterGlobalHotkey() async {}

  @override
  Future<void> dispose() async {
    _isCapturing = false;
    await _captureController.close();
    await _hotkeyController.close();
  }
}
