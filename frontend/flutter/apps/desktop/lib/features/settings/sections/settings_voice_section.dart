import 'dart:async';

import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../../../platform/desktop_audio_adapter.dart';
import '../../voice/desktop_voice_controller.dart';
import '../../voice/voice_shortcut_recorder.dart';

/// Settings -> Voice & Audio: Engine readiness, Windows WASAPI hardware,
/// customizable shortcuts, and per-Profile speech & privacy controls.
class SettingsVoiceSection extends StatefulWidget {
  const SettingsVoiceSection({
    super.key,
    this.voiceController,
  });

  final DesktopVoiceController? voiceController;

  @override
  State<SettingsVoiceSection> createState() => _SettingsVoiceSectionState();
}

class _SettingsVoiceSectionState extends State<SettingsVoiceSection> {
  double? _pendingTtsSpeed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = widget.voiceController;
      if (ctrl == null) return;
      if (!ctrl.initialized) {
        ctrl.initialize();
      } else {
        ctrl.refreshAll();
      }
    });
  }

  @override
  void dispose() {
    final ctrl = widget.voiceController;
    if (ctrl != null && ctrl.isTestingMic) {
      unawaited(ctrl.stopMicTest());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final ctrl = widget.voiceController;

    if (ctrl == null) {
      return SoftGlassPanel(
        padding: const EdgeInsets.all(CompanionSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice & Audio',
              style: CompanionTypography.titleMedium.copyWith(
                color: ext?.textPrimary,
              ),
            ),
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              'Connect to the Local AI Runtime to configure Windows microphone/speaker routing, customizable voice shortcuts, and per-Profile STT/TTS preferences.',
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReadinessCard(context, ctrl),
            const SizedBox(height: CompanionSpacing.md),
            _buildHardwareCard(context, ctrl),
            const SizedBox(height: CompanionSpacing.md),
            _buildShortcutsCard(context, ctrl),
            const SizedBox(height: CompanionSpacing.md),
            _buildBehaviorCard(context, ctrl),
          ],
        );
      },
    );
  }

  Widget _buildReadinessCard(BuildContext context, DesktopVoiceController ctrl) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final status = ctrl.voiceStatus;

    return SoftGlassPanel(
      key: const ValueKey('settings_voice_readiness_card'),
      padding: const EdgeInsets.all(CompanionSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.spatial_audio_off_rounded, size: 18, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Voice Engine Readiness',
                  style: CompanionTypography.titleSmall.copyWith(
                    color: ext?.textPrimary,
                  ),
                ),
              ),
              NeumorphicButton(
                key: const ValueKey('settings_voice_refresh_button'),
                size: NeumorphicButtonSize.sm,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: ctrl.isLoading ? null : ctrl.refreshAll,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.sm),
          if (status == null)
            Text(
              ctrl.isLoading
                  ? 'Checking local STT, VAD, and TTS subsystems...'
                  : 'Connect to the Local AI Runtime to inspect STT/VAD/TTS engine readiness.',
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textSecondary,
              ),
            )
          else ...[
            Wrap(
              spacing: CompanionSpacing.sm,
              runSpacing: CompanionSpacing.xs,
              children: [
                _StatusBadge(
                  label: 'STT: ${status.sttAvailable ? "Ready (${status.sttProvider}${status.sttModel != null ? " · ${status.sttModel}" : ""})" : (status.sttUnavailableReason ?? "Unavailable")}',
                  ready: status.sttAvailable,
                ),
                _StatusBadge(
                  label: 'VAD: ${status.vadAvailable ? "Ready (${status.vadProvider})" : "Energy Fallback"}',
                  ready: status.vadAvailable,
                ),
                _StatusBadge(
                  label: 'TTS: ${status.ttsAvailable ? "Ready (${status.ttsProvider})" : (status.ttsUnavailableReason ?? "Unavailable")}',
                  ready: status.ttsAvailable,
                ),
                _StatusBadge(
                  label: status.cpuFirst ? 'CPU-First Local' : 'Hardware Accelerated',
                  ready: true,
                ),
              ],
            ),
          ],
          if (ctrl.errorMessage != null) ...[
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              ctrl.errorMessage!,
              style: CompanionTypography.caption.copyWith(
                color: ext?.danger ?? Colors.redAccent,
              ),
            ),
          ],
          const SizedBox(height: CompanionSpacing.sm),
          Container(
            padding: const EdgeInsets.all(CompanionSpacing.sm),
            decoration: BoxDecoration(
              color: (ext?.surfaceElevated ?? Colors.black12)
                  .withValues(alpha: 0.45),
              borderRadius: CompanionRadius.borderMd,
              border: Border.all(
                color: ext?.borderSubtle ?? Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: ext?.accent),
                const SizedBox(width: CompanionSpacing.sm),
                Expanded(
                  child: Text(
                    'Privacy guarantee: microphone audio stays in temporary RAM only for local speech processing and is never saved to disk or used for voice biometrics.',
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareCard(BuildContext context, DesktopVoiceController ctrl) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final micId = ctrl.hardwarePrefs.selectedMicDeviceId;
    final speakerId = ctrl.hardwarePrefs.selectedSpeakerDeviceId;

    final micItems = _dedupeDeviceItems(
      ctrl.inputDevices,
      selectedId: micId,
      fallbackLabel: 'Saved Microphone ($micId)',
    );
    final speakerItems = _dedupeDeviceItems(
      ctrl.outputDevices,
      selectedId: speakerId,
      fallbackLabel: 'Saved Speaker ($speakerId)',
    );

    return SoftGlassPanel(
      key: const ValueKey('settings_voice_hardware_card'),
      padding: const EdgeInsets.all(CompanionSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.headset_mic_rounded, size: 18, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Windows Audio Devices',
                  style: CompanionTypography.titleSmall.copyWith(
                    color: ext?.textPrimary,
                  ),
                ),
              ),
              NeumorphicButton(
                key: const ValueKey('settings_voice_refresh_devices_button'),
                size: NeumorphicButtonSize.sm,
                icon: const Icon(Icons.sync_rounded),
                onPressed: ctrl.refreshDevices,
                child: const Text('Refresh Devices'),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.md),
          DropdownButtonFormField<String>(
            key: const ValueKey('settings_voice_mic_dropdown'),
            initialValue: micId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Input Microphone (WASAPI)',
            ),
            items: micItems,
            onChanged: (val) {
              if (val != null) {
                ctrl.selectInputDevice(val);
              }
            },
          ),
          const SizedBox(height: CompanionSpacing.sm),
          Row(
            children: [
              Icon(
                ctrl.isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 16,
                color: ctrl.isAudioMuted
                    ? (ext?.warning ?? Colors.amber)
                    : ext?.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: CompanionRadius.borderFull,
                  child: ValueListenableBuilder<double>(
                    valueListenable: ctrl.micRmsListenable,
                    builder: (context, rms, _) {
                      return LinearProgressIndicator(
                        value: ctrl.isAudioMuted ? 0.0 : rms.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: (ext?.surfaceElevated ?? Colors.black26)
                            .withValues(alpha: 0.55),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ctrl.isAudioMuted
                              ? (ext?.warning ?? Colors.amber)
                              : (ext?.accent ?? Colors.teal),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              NeumorphicButton(
                key: const ValueKey('settings_voice_test_mic_button'),
                size: NeumorphicButtonSize.sm,
                selected: ctrl.isTestingMic,
                icon: Icon(
                  ctrl.isTestingMic ? Icons.stop_rounded : Icons.mic_none_rounded,
                  size: 16,
                ),
                onPressed: ctrl.isAudioMuted
                    ? null
                    : () => ctrl.isTestingMic
                        ? ctrl.stopMicTest()
                        : ctrl.startMicTest(),
                child: Text(ctrl.isTestingMic ? 'Stop Test' : 'Test Mic'),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Switch(
                key: const ValueKey('settings_voice_mute_switch'),
                value: ctrl.isAudioMuted,
                onChanged: ctrl.setMuted,
              ),
              Text(
                ctrl.isAudioMuted ? 'Muted' : 'Active',
                style: CompanionTypography.caption.copyWith(
                  color: ctrl.isAudioMuted
                      ? (ext?.warning ?? Colors.amber)
                      : ext?.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('settings_voice_speaker_dropdown'),
                  initialValue: speakerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Output Speaker (WASAPI)',
                  ),
                  items: speakerItems,
                  onChanged: (val) {
                    if (val != null) {
                      ctrl.selectOutputDevice(val);
                    }
                  },
                ),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: NeumorphicButton(
                  key: const ValueKey('settings_voice_test_tone_button'),
                  size: NeumorphicButtonSize.sm,
                  icon: const Icon(Icons.volume_up_rounded),
                  onPressed: ctrl.playTestTone,
                  child: const Text('Test Sound'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsCard(BuildContext context, DesktopVoiceController ctrl) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final shortcuts = ctrl.shortcuts;

    return SoftGlassPanel(
      key: const ValueKey('settings_voice_shortcuts_card'),
      padding: const EdgeInsets.all(CompanionSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.keyboard_rounded, size: 18, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Voice Keyboard Shortcuts',
                  style: CompanionTypography.titleSmall.copyWith(
                    color: ext?.textPrimary,
                  ),
                ),
              ),
              NeumorphicButton(
                key: const ValueKey('settings_voice_reset_shortcuts_button'),
                size: NeumorphicButtonSize.sm,
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: ctrl.resetShortcutsToDefaults,
                child: const Text('Reset Defaults'),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.sm),
          if (ctrl.globalHotkeyWarning != null) ...[
            Container(
              key: const ValueKey('settings_voice_hotkey_warning'),
              padding: const EdgeInsets.all(CompanionSpacing.sm),
              margin: const EdgeInsets.only(bottom: CompanionSpacing.sm),
              decoration: BoxDecoration(
                color: (ext?.warning ?? Colors.amber).withValues(alpha: 0.14),
                borderRadius: CompanionRadius.borderMd,
                border: Border.all(
                  color: (ext?.warning ?? Colors.amber).withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: ext?.warning ?? Colors.amber,
                  ),
                  const SizedBox(width: CompanionSpacing.sm),
                  Expanded(
                    child: Text(
                      ctrl.globalHotkeyWarning!,
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          VoiceShortcutRecorderTile(
            buttonKey: const ValueKey('shortcut_in_app_edit'),
            title: 'In-App Voice Toggle',
            subtitle: 'Start or end Live Voice while Desktop window is focused.',
            binding: shortcuts.inAppToggle,
            onCapture: (next) =>
                ctrl.updateShortcuts(shortcuts.copyWith(inAppToggle: next)),
          ),
          const Divider(height: CompanionSpacing.lg),
          VoiceShortcutRecorderTile(
            buttonKey: const ValueKey('shortcut_global_edit'),
            title: 'Global Windows Hotkey',
            subtitle: 'Restore window and toggle Live Voice from anywhere on Windows.',
            binding: shortcuts.globalToggle,
            onCapture: (next) =>
                ctrl.updateShortcuts(shortcuts.copyWith(globalToggle: next)),
          ),
          const Divider(height: CompanionSpacing.lg),
          VoiceShortcutRecorderTile(
            buttonKey: const ValueKey('shortcut_mute_edit'),
            title: 'Hard Mute Audio',
            subtitle: 'Immediately silences OS capture and TTS playback.',
            binding: shortcuts.muteToggle,
            onCapture: (next) =>
                ctrl.updateShortcuts(shortcuts.copyWith(muteToggle: next)),
          ),
          const Divider(height: CompanionSpacing.lg),
          VoiceShortcutRecorderTile(
            buttonKey: const ValueKey('shortcut_ptt_edit'),
            title: 'Push-to-Talk Key',
            subtitle: 'Hold inside Chat during Live Voice or dictation.',
            binding: shortcuts.pushToTalk,
            allowStandaloneModifier: true,
            onCapture: (next) =>
                ctrl.updateShortcuts(shortcuts.copyWith(pushToTalk: next)),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorCard(BuildContext context, DesktopVoiceController ctrl) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final settings = ctrl.voiceSettings;
    final catalog = ctrl.voiceCatalog?.voices ?? const <VoiceDescriptorOut>[];

    if (settings == null) {
      return SoftGlassPanel(
        key: const ValueKey('settings_voice_behavior_card'),
        padding: const EdgeInsets.all(CompanionSpacing.lg),
        child: Text(
          'Select an active Profile to configure per-Profile barge-in, VAD sensitivity, default voice, TTS speed, and Auto-Read preferences.',
          style: CompanionTypography.bodySmall.copyWith(
            color: ext?.textSecondary,
          ),
        ),
      );
    }

    final currentSpeed =
        (_pendingTtsSpeed ?? settings.ttsSpeed).clamp(0.5, 2.0);
    final voiceItems = <DropdownMenuItem<String>>[
      for (final v in catalog)
        DropdownMenuItem<String>(
          value: v.voiceId,
          child: Text(
            '${v.name} (${v.language})',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (!catalog.any((v) => v.voiceId == settings.defaultVoiceId))
        DropdownMenuItem<String>(
          value: settings.defaultVoiceId,
          child: Text(
            settings.defaultVoiceId,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    const bargeInOptions = <(String, String)>[
      ('smart_auto', 'Smart Auto (Interrupt after sustained speech)'),
      ('strict_noisy', 'Strict Noisy Room (Higher barge-in threshold)'),
      ('manual_only', 'Manual Only (Spacebar / button interrupt)'),
    ];
    final bargeInItems = <DropdownMenuItem<String>>[
      for (final (id, label) in bargeInOptions)
        DropdownMenuItem<String>(value: id, child: Text(label)),
      if (!bargeInOptions.any((item) => item.$1 == settings.bargeInPolicy))
        DropdownMenuItem<String>(
          value: settings.bargeInPolicy,
          child: Text(settings.bargeInPolicy),
        ),
    ];

    const vadOptions = <(String, String)>[
      ('low', 'Low Sensitivity (Noisy room)'),
      ('medium', 'Medium Sensitivity (Balanced)'),
      ('high', 'High Sensitivity (Quiet room)'),
    ];
    final vadItems = <DropdownMenuItem<String>>[
      for (final (id, label) in vadOptions)
        DropdownMenuItem<String>(value: id, child: Text(label)),
      if (!vadOptions.any((item) => item.$1 == settings.vadSensitivity))
        DropdownMenuItem<String>(
          value: settings.vadSensitivity,
          child: Text(settings.vadSensitivity),
        ),
    ];

    const langOptions = <(String, String)>[
      ('en', 'English (en)'),
      ('auto', 'Auto-Detect (Multilingual)'),
    ];
    final langItems = <DropdownMenuItem<String>>[
      for (final (id, label) in langOptions)
        DropdownMenuItem<String>(value: id, child: Text(label)),
      if (!langOptions.any((item) => item.$1 == settings.sttLanguage))
        DropdownMenuItem<String>(
          value: settings.sttLanguage,
          child: Text(settings.sttLanguage),
        ),
    ];

    return SoftGlassPanel(
      key: const ValueKey('settings_voice_behavior_card'),
      padding: const EdgeInsets.all(CompanionSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Speech, Barge-In & Playback',
                  style: CompanionTypography.titleSmall.copyWith(
                    color: ext?.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.md),
          DropdownButtonFormField<String>(
            key: const ValueKey('settings_voice_barge_in_dropdown'),
            initialValue: settings.bargeInPolicy,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Barge-In Policy'),
            items: bargeInItems,
            onChanged: ctrl.isSaving
                ? null
                : (val) {
                    if (val != null) {
                      ctrl.updateBackendSettings(
                        VoiceSettingsUpdate(bargeInPolicy: val),
                      );
                    }
                  },
          ),
          const SizedBox(height: CompanionSpacing.md),
          DropdownButtonFormField<String>(
            key: const ValueKey('settings_voice_vad_dropdown'),
            initialValue: settings.vadSensitivity,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'VAD Sensitivity'),
            items: vadItems,
            onChanged: ctrl.isSaving
                ? null
                : (val) {
                    if (val != null) {
                      ctrl.updateBackendSettings(
                        VoiceSettingsUpdate(vadSensitivity: val),
                      );
                    }
                  },
          ),
          const SizedBox(height: CompanionSpacing.md),
          DropdownButtonFormField<String>(
            key: const ValueKey('settings_voice_language_dropdown'),
            initialValue: settings.sttLanguage,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Recognition Language'),
            items: langItems,
            onChanged: ctrl.isSaving
                ? null
                : (val) {
                    if (val != null) {
                      ctrl.updateBackendSettings(
                        VoiceSettingsUpdate(sttLanguage: val),
                      );
                    }
                  },
          ),
          const SizedBox(height: CompanionSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('settings_voice_default_voice_dropdown'),
                  initialValue: settings.defaultVoiceId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Default TTS Voice'),
                  items: voiceItems,
                  onChanged: ctrl.isSaving
                      ? null
                      : (val) {
                          if (val != null) {
                            ctrl.updateBackendSettings(
                              VoiceSettingsUpdate(defaultVoiceId: val),
                            );
                          }
                        },
                ),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: NeumorphicButton(
                  key: const ValueKey('settings_voice_preview_default_button'),
                  size: NeumorphicButtonSize.sm,
                  icon: const Icon(Icons.volume_up_rounded),
                  onPressed: () => ctrl.previewVoice(settings.defaultVoiceId),
                  child: const Text('Preview'),
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Speech Speed',
                style: CompanionTypography.bodyMedium.copyWith(
                  color: ext?.textPrimary,
                ),
              ),
              Text(
                '${currentSpeed.toStringAsFixed(2)}x',
                style: CompanionTypography.caption.copyWith(
                  color: ext?.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('settings_voice_speed_slider'),
            value: currentSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '${currentSpeed.toStringAsFixed(2)}x',
            onChanged: ctrl.isSaving
                ? null
                : (val) => setState(() => _pendingTtsSpeed = val),
            onChangeEnd: ctrl.isSaving
                ? null
                : (val) {
                    setState(() => _pendingTtsSpeed = null);
                    ctrl.updateBackendSettings(
                      VoiceSettingsUpdate(ttsSpeed: val),
                    );
                  },
          ),
          const Divider(height: CompanionSpacing.lg),
          _SwitchSettingRow(
            switchKey: const ValueKey('settings_voice_auto_read_switch'),
            title: 'Auto-Read Assistant Replies',
            subtitle:
                'Automatically read new completed chat replies aloud in this Profile.',
            value: settings.autoReadReplies,
            onChanged: ctrl.isSaving
                ? null
                : (val) => ctrl.updateBackendSettings(
                      VoiceSettingsUpdate(autoReadReplies: val),
                    ),
          ),
          const SizedBox(height: CompanionSpacing.sm),
          _SwitchSettingRow(
            switchKey: const ValueKey('settings_voice_proactive_switch'),
            title: 'Proactive Speech Opt-In',
            subtitle:
                'Off by default. Allow reminder announcements when Audio is unmuted.',
            value: settings.proactiveSpeechEnabled,
            onChanged: ctrl.isSaving
                ? null
                : (val) => ctrl.updateBackendSettings(
                      VoiceSettingsUpdate(proactiveSpeechEnabled: val),
                    ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _dedupeDeviceItems(
    List<AudioDeviceInfo> devices, {
    required String selectedId,
    required String fallbackLabel,
  }) {
    final seen = <String>{};
    final items = <DropdownMenuItem<String>>[];
    for (final dev in devices) {
      if (seen.add(dev.id)) {
        items.add(
          DropdownMenuItem<String>(
            value: dev.id,
            child: Text(dev.name, overflow: TextOverflow.ellipsis),
          ),
        );
      }
    }
    if (!seen.contains(selectedId)) {
      items.add(
        DropdownMenuItem<String>(
          value: selectedId,
          child: Text(
            selectedId.isEmpty ? 'System Default' : fallbackLabel,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return items;
  }
}

class _SwitchSettingRow extends StatelessWidget {
  const _SwitchSettingRow({
    required this.switchKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CompanionTypography.bodyMedium.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: CompanionSpacing.md),
        Switch(
          key: switchKey,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.ready,
  });

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final color = ready
        ? (ext?.success ?? Colors.teal)
        : (ext?.warning ?? Colors.amber);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: CompanionRadius.borderFull,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: CompanionTypography.caption.copyWith(
              color: ext?.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
