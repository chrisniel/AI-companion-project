import 'package:meta/meta.dart';

/// Metadata describing one locally discoverable TTS voice.
@immutable
class VoiceDescriptorOut {
  final String voiceId;
  final String name;
  final String provider;
  final String language;
  final int sampleRate;

  const VoiceDescriptorOut({
    required this.voiceId,
    required this.name,
    required this.provider,
    required this.language,
    required this.sampleRate,
  });

  factory VoiceDescriptorOut.fromJson(Map<String, dynamic> json) {
    return VoiceDescriptorOut(
      voiceId: json['voice_id'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String,
      language: json['language'] as String,
      sampleRate: (json['sample_rate'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'voice_id': voiceId,
        'name': name,
        'provider': provider,
        'language': language,
        'sample_rate': sampleRate,
      };
}

/// List of available local TTS voices returned by GET /api/v1/voice/voices.
@immutable
class VoiceCatalogOut {
  final List<VoiceDescriptorOut> voices;

  const VoiceCatalogOut({required this.voices});

  factory VoiceCatalogOut.fromJson(Map<String, dynamic> json) {
    final rawList = json['voices'] as List<dynamic>? ?? const [];
    return VoiceCatalogOut(
      voices: rawList
          .map((e) => VoiceDescriptorOut.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'voices': voices.map((v) => v.toJson()).toList(),
      };
}

/// Truthful runtime readiness status across STT, VAD, and TTS subsystems.
@immutable
class VoiceStatusOut {
  final bool sttAvailable;
  final String sttProvider;
  final String? sttModel;
  final String? sttUnavailableReason;
  final bool vadAvailable;
  final String vadProvider;
  final bool ttsAvailable;
  final String ttsProvider;
  final String? ttsUnavailableReason;
  final bool cpuFirst;
  final int activeVoiceSessions;

  const VoiceStatusOut({
    required this.sttAvailable,
    required this.sttProvider,
    this.sttModel,
    this.sttUnavailableReason,
    required this.vadAvailable,
    required this.vadProvider,
    required this.ttsAvailable,
    required this.ttsProvider,
    this.ttsUnavailableReason,
    this.cpuFirst = true,
    this.activeVoiceSessions = 0,
  });

  factory VoiceStatusOut.fromJson(Map<String, dynamic> json) {
    return VoiceStatusOut(
      sttAvailable: json['stt_available'] as bool? ?? false,
      sttProvider: json['stt_provider'] as String? ?? 'unavailable',
      sttModel: json['stt_model'] as String?,
      sttUnavailableReason: json['stt_unavailable_reason'] as String?,
      vadAvailable: json['vad_available'] as bool? ?? false,
      vadProvider: json['vad_provider'] as String? ?? 'unavailable',
      ttsAvailable: json['tts_available'] as bool? ?? false,
      ttsProvider: json['tts_provider'] as String? ?? 'unavailable',
      ttsUnavailableReason: json['tts_unavailable_reason'] as String?,
      cpuFirst: json['cpu_first'] as bool? ?? true,
      activeVoiceSessions: (json['active_voice_sessions'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'stt_available': sttAvailable,
        'stt_provider': sttProvider,
        if (sttModel != null) 'stt_model': sttModel,
        if (sttUnavailableReason != null) 'stt_unavailable_reason': sttUnavailableReason,
        'vad_available': vadAvailable,
        'vad_provider': vadProvider,
        'tts_available': ttsAvailable,
        'tts_provider': ttsProvider,
        if (ttsUnavailableReason != null) 'tts_unavailable_reason': ttsUnavailableReason,
        'cpu_first': cpuFirst,
        'active_voice_sessions': activeVoiceSessions,
      };
}

/// Per-Profile voice behavior, barge-in, and privacy preferences.
@immutable
class VoiceSettingsOut {
  final String profileId;
  final String bargeInPolicy;
  final String vadSensitivity;
  final String sttLanguage;
  final double ttsSpeed;
  final String defaultVoiceId;
  final bool autoReadReplies;
  final bool proactiveSpeechEnabled;
  final bool cloudSttEnabled;
  final bool cloudTtsEnabled;
  final DateTime updatedAt;

  const VoiceSettingsOut({
    required this.profileId,
    required this.bargeInPolicy,
    required this.vadSensitivity,
    required this.sttLanguage,
    required this.ttsSpeed,
    required this.defaultVoiceId,
    required this.autoReadReplies,
    required this.proactiveSpeechEnabled,
    required this.cloudSttEnabled,
    required this.cloudTtsEnabled,
    required this.updatedAt,
  });

  factory VoiceSettingsOut.fromJson(Map<String, dynamic> json) {
    return VoiceSettingsOut(
      profileId: json['profile_id'] as String,
      bargeInPolicy: json['barge_in_policy'] as String? ?? 'smart_auto',
      vadSensitivity: json['vad_sensitivity'] as String? ?? 'medium',
      sttLanguage: json['stt_language'] as String? ?? 'en',
      ttsSpeed: (json['tts_speed'] as num?)?.toDouble() ?? 1.0,
      defaultVoiceId: json['default_voice_id'] as String? ?? 'af_nicole',
      autoReadReplies: json['auto_read_replies'] as bool? ?? false,
      proactiveSpeechEnabled: json['proactive_speech_enabled'] as bool? ?? false,
      cloudSttEnabled: json['cloud_stt_enabled'] as bool? ?? false,
      cloudTtsEnabled: json['cloud_tts_enabled'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'barge_in_policy': bargeInPolicy,
        'vad_sensitivity': vadSensitivity,
        'stt_language': sttLanguage,
        'tts_speed': ttsSpeed,
        'default_voice_id': defaultVoiceId,
        'auto_read_replies': autoReadReplies,
        'proactive_speech_enabled': proactiveSpeechEnabled,
        'cloud_stt_enabled': cloudSttEnabled,
        'cloud_tts_enabled': cloudTtsEnabled,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Partial update payload for PATCH /api/v1/voice/settings.
@immutable
class VoiceSettingsUpdate {
  final String? bargeInPolicy;
  final String? vadSensitivity;
  final String? sttLanguage;
  final double? ttsSpeed;
  final String? defaultVoiceId;
  final bool? autoReadReplies;
  final bool? proactiveSpeechEnabled;
  final bool? cloudSttEnabled;
  final bool? cloudTtsEnabled;

  const VoiceSettingsUpdate({
    this.bargeInPolicy,
    this.vadSensitivity,
    this.sttLanguage,
    this.ttsSpeed,
    this.defaultVoiceId,
    this.autoReadReplies,
    this.proactiveSpeechEnabled,
    this.cloudSttEnabled,
    this.cloudTtsEnabled,
  });

  factory VoiceSettingsUpdate.fromJson(Map<String, dynamic> json) {
    return VoiceSettingsUpdate(
      bargeInPolicy: json['barge_in_policy'] as String?,
      vadSensitivity: json['vad_sensitivity'] as String?,
      sttLanguage: json['stt_language'] as String?,
      ttsSpeed: (json['tts_speed'] as num?)?.toDouble(),
      defaultVoiceId: json['default_voice_id'] as String?,
      autoReadReplies: json['auto_read_replies'] as bool?,
      proactiveSpeechEnabled: json['proactive_speech_enabled'] as bool?,
      cloudSttEnabled: json['cloud_stt_enabled'] as bool?,
      cloudTtsEnabled: json['cloud_tts_enabled'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (bargeInPolicy != null) 'barge_in_policy': bargeInPolicy,
        if (vadSensitivity != null) 'vad_sensitivity': vadSensitivity,
        if (sttLanguage != null) 'stt_language': sttLanguage,
        if (ttsSpeed != null) 'tts_speed': ttsSpeed,
        if (defaultVoiceId != null) 'default_voice_id': defaultVoiceId,
        if (autoReadReplies != null) 'auto_read_replies': autoReadReplies,
        if (proactiveSpeechEnabled != null) 'proactive_speech_enabled': proactiveSpeechEnabled,
        if (cloudSttEnabled != null) 'cloud_stt_enabled': cloudSttEnabled,
        if (cloudTtsEnabled != null) 'cloud_tts_enabled': cloudTtsEnabled,
      };
}

/// Bounded ephemeral audio transcription request (never persisted to disk).
@immutable
class VoiceTranscribeRequest {
  final String audioBase64;
  final String format;
  final int sampleRate;
  final String? language;

  const VoiceTranscribeRequest({
    required this.audioBase64,
    this.format = 'wav',
    this.sampleRate = 16000,
    this.language,
  });

  factory VoiceTranscribeRequest.fromJson(Map<String, dynamic> json) {
    return VoiceTranscribeRequest(
      audioBase64: json['audio_base64'] as String,
      format: json['format'] as String? ?? 'wav',
      sampleRate: (json['sample_rate'] as num?)?.toInt() ?? 16000,
      language: json['language'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'audio_base64': audioBase64,
        'format': format,
        'sample_rate': sampleRate,
        if (language != null) 'language': language,
      };
}

/// Ephemeral STT transcription response.
@immutable
class VoiceTranscribeOut {
  final String text;
  final String language;
  final int durationMs;
  final String provider;

  const VoiceTranscribeOut({
    required this.text,
    required this.language,
    required this.durationMs,
    required this.provider,
  });

  factory VoiceTranscribeOut.fromJson(Map<String, dynamic> json) {
    return VoiceTranscribeOut(
      text: json['text'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? 'unavailable',
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'language': language,
        'duration_ms': durationMs,
        'provider': provider,
      };
}

/// Bounded speech synthesis request for Read Aloud and Auto-Read replies.
@immutable
class VoiceSynthesizeRequest {
  final String text;
  final String? voiceId;
  final double? speed;

  const VoiceSynthesizeRequest({
    required this.text,
    this.voiceId,
    this.speed,
  });

  factory VoiceSynthesizeRequest.fromJson(Map<String, dynamic> json) {
    return VoiceSynthesizeRequest(
      text: json['text'] as String,
      voiceId: json['voice_id'] as String?,
      speed: (json['speed'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        if (voiceId != null) 'voice_id': voiceId,
        if (speed != null) 'speed': speed,
      };
}

/// In-memory synthesized WAV audio payload.
@immutable
class VoiceSynthesizeOut {
  final String audioBase64;
  final String mimeType;
  final int sampleRate;
  final int durationMs;
  final String voiceId;
  final String provider;

  const VoiceSynthesizeOut({
    required this.audioBase64,
    this.mimeType = 'audio/wav',
    required this.sampleRate,
    required this.durationMs,
    required this.voiceId,
    required this.provider,
  });

  factory VoiceSynthesizeOut.fromJson(Map<String, dynamic> json) {
    return VoiceSynthesizeOut(
      audioBase64: json['audio_base64'] as String,
      mimeType: json['mime_type'] as String? ?? 'audio/wav',
      sampleRate: (json['sample_rate'] as num).toInt(),
      durationMs: (json['duration_ms'] as num).toInt(),
      voiceId: json['voice_id'] as String,
      provider: json['provider'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'audio_base64': audioBase64,
        'mime_type': mimeType,
        'sample_rate': sampleRate,
        'duration_ms': durationMs,
        'voice_id': voiceId,
        'provider': provider,
      };
}

/// Typed envelope for inbound events on WS /api/v1/voice/ws.
@immutable
class VoiceWsEvent {
  final String type;
  final String? voiceSessionId;
  final int? turnId;
  final Map<String, dynamic> raw;

  const VoiceWsEvent({
    required this.type,
    this.voiceSessionId,
    this.turnId,
    required this.raw,
  });

  factory VoiceWsEvent.fromJson(Map<String, dynamic> json) {
    final rawTurnId = json['turn_id'];
    return VoiceWsEvent(
      type: json['type'] as String? ?? 'unknown',
      voiceSessionId: json['voice_session_id'] as String?,
      turnId: rawTurnId is num ? rawTurnId.toInt() : null,
      raw: Map<String, dynamic>.from(json),
    );
  }

  String? get conversationId => raw['conversation_id'] as String?;
  String? get state => raw['state'] as String?;
  bool get isSpeech => raw['is_speech'] as bool? ?? false;
  double? get probability => (raw['probability'] as num?)?.toDouble();
  String? get text => raw['text'] as String?;
  String? get token => raw['token'] as String?;
  String? get voiceId => raw['voice_id'] as String?;
  int? get seq => (raw['seq'] as num?)?.toInt();
  int? get sampleRate => (raw['sample_rate'] as num?)?.toInt();
  int? get durationMs => (raw['duration_ms'] as num?)?.toInt();
  String? get wavBase64 => raw['wav_base64'] as String?;
  String? get reason => raw['reason'] as String?;
  String? get code => raw['code'] as String?;
  String? get message => raw['message'] as String?;
}
