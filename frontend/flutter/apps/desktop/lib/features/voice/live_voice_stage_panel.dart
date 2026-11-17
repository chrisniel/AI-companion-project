import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_voice_controller.dart';

/// Compact Glass/Neumorphic live duplex voice stage embedded above ChatScreen messages.
class LiveVoiceStagePanel extends StatelessWidget {
  const LiveVoiceStagePanel({
    super.key,
    required this.controller,
    this.companionName,
  });

  final DesktopVoiceController controller;
  final String? companionName;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        final muted = controller.isAudioMuted;
        final rms = muted ? 0.0 : controller.micRmsLevel.clamp(0.0, 1.0);
        final phaseColor = _phaseColor(ext, phase, muted);
        final phaseLabel = _phaseLabel(phase, muted);

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            CompanionSpacing.lg,
            CompanionSpacing.sm,
            CompanionSpacing.lg,
            CompanionSpacing.xs,
          ),
          child: SoftGlassPanel(
            key: const ValueKey('live_voice_stage_panel'),
            padding: const EdgeInsets.all(CompanionSpacing.md),
            borderRadius: CompanionRadius.borderLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Reactive Companion Voice Orb
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 44 + (rms * 10),
                      height: 44 + (rms * 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            phaseColor.withValues(alpha: 0.9),
                            phaseColor.withValues(alpha: 0.25),
                          ],
                        ),
                        border: Border.all(
                          color: phaseColor.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: phaseColor.withValues(alpha: 0.28 + rms * 0.25),
                            blurRadius: 12 + (rms * 10),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _phaseIcon(phase, muted),
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: CompanionSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  companionName?.trim().isNotEmpty == true
                                      ? '${companionName!.trim()} · Live Voice'
                                      : 'Live Voice Session',
                                  style: CompanionTypography.titleSmall.copyWith(
                                    color: ext?.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: CompanionSpacing.sm),
                              Container(
                                key: const ValueKey('live_voice_phase_badge'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: phaseColor.withValues(alpha: 0.16),
                                  borderRadius: CompanionRadius.borderFull,
                                  border: Border.all(
                                    color: phaseColor.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Text(
                                  phaseLabel,
                                  style: CompanionTypography.caption.copyWith(
                                    color: phaseColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                muted ? Icons.mic_off_rounded : Icons.graphic_eq_rounded,
                                size: 14,
                                color: ext?.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: CompanionRadius.borderFull,
                                  child: LinearProgressIndicator(
                                    key: const ValueKey('live_voice_rms_meter'),
                                    value: rms,
                                    minHeight: 5,
                                    backgroundColor:
                                        (ext?.surfaceElevated ?? Colors.black26)
                                            .withValues(alpha: 0.55),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      muted
                                          ? (ext?.warning ?? Colors.amber)
                                          : phaseColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    Wrap(
                      spacing: CompanionSpacing.xs,
                      runSpacing: CompanionSpacing.xs,
                      children: [
                        NeumorphicButton(
                          key: const ValueKey('live_voice_mute_button'),
                          size: NeumorphicButtonSize.sm,
                          selected: muted,
                          icon: Icon(
                            muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: muted ? ext?.warning : null,
                          ),
                          tooltip:
                              '${muted ? 'Unmute' : 'Mute'} microphone (${controller.shortcuts.muteToggle.label})',
                          onPressed: () => controller.setMuted(!muted),
                          child: Text(muted ? 'Unmute Mic' : 'Mute Mic'),
                        ),
                        NeumorphicButton(
                          key: const ValueKey('live_voice_interrupt_button'),
                          size: NeumorphicButtonSize.sm,
                          icon: const Icon(Icons.pan_tool_alt_rounded),
                          tooltip: 'Interrupt reply (Space when composer unfocused)',
                          onPressed: phase == VoiceSessionPhase.speaking ||
                                  phase == VoiceSessionPhase.thinking
                              ? controller.interruptBargeIn
                              : null,
                          child: const Text('Interrupt'),
                        ),
                        NeumorphicButton(
                          key: const ValueKey('live_voice_end_button'),
                          size: NeumorphicButtonSize.sm,
                          icon: Icon(
                            Icons.call_end_rounded,
                            color: ext?.danger ?? Colors.redAccent,
                          ),
                          tooltip:
                              'End Live Voice session (${controller.shortcuts.inAppToggle.label})',
                          onPressed: controller.stopLiveVoice,
                          child: Text(
                            'End Voice',
                            style: TextStyle(
                              color: ext?.danger ?? Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (controller.activeToolHint != null) ...[
                  const SizedBox(height: CompanionSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.build_circle_outlined,
                        size: 14,
                        color: ext?.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Using tool: ${controller.activeToolHint}',
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.accent,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if ((controller.liveUserTranscript?.isNotEmpty ?? false) ||
                    (controller.liveAssistantTranscript?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: CompanionSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CompanionSpacing.sm,
                      vertical: CompanionSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: (ext?.surfaceElevated ?? Colors.black12)
                          .withValues(alpha: 0.45),
                      borderRadius: CompanionRadius.borderMd,
                      border: Border.all(
                        color: ext?.borderSubtle ?? Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (controller.liveUserTranscript?.isNotEmpty ?? false)
                          Text(
                            'You: ${controller.liveUserTranscript}',
                            style: CompanionTypography.bodySmall.copyWith(
                              color: ext?.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (controller.liveAssistantTranscript?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Assistant: ${controller.liveAssistantTranscript}',
                              style: CompanionTypography.bodySmall.copyWith(
                                color: ext?.textPrimary,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: CompanionSpacing.xs),
                  Text(
                    controller.errorMessage!,
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.danger ?? Colors.redAccent,
                    ),
                  ),
                ],
                const SizedBox(height: CompanionSpacing.xs),
                Text(
                  'Push-to-Talk: Hold ${controller.shortcuts.pushToTalk.label}  ·  Spacebar: Interrupt when text box is unfocused',
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textMuted ?? ext?.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _phaseColor(
    CompanionThemeExtension? ext,
    VoiceSessionPhase phase,
    bool muted,
  ) {
    if (muted) return ext?.warning ?? Colors.amber;
    return switch (phase) {
      VoiceSessionPhase.listening => ext?.success ?? Colors.teal,
      VoiceSessionPhase.thinking => ext?.accent ?? Colors.indigoAccent,
      VoiceSessionPhase.speaking => ext?.accent ?? Colors.cyan,
      VoiceSessionPhase.connectingWs => ext?.textSecondary ?? Colors.blueGrey,
      VoiceSessionPhase.errored => ext?.danger ?? Colors.redAccent,
      _ => ext?.accent ?? Colors.teal,
    };
  }

  String _phaseLabel(VoiceSessionPhase phase, bool muted) {
    if (muted) return 'Mic Muted';
    return switch (phase) {
      VoiceSessionPhase.connectingWs => 'Connecting...',
      VoiceSessionPhase.listening => 'Listening',
      VoiceSessionPhase.thinking => 'Thinking...',
      VoiceSessionPhase.speaking => 'Speaking',
      VoiceSessionPhase.errored => 'Voice Error',
      _ => 'Live',
    };
  }

  IconData _phaseIcon(VoiceSessionPhase phase, bool muted) {
    if (muted) return Icons.mic_off_rounded;
    return switch (phase) {
      VoiceSessionPhase.listening => Icons.mic_rounded,
      VoiceSessionPhase.thinking => Icons.auto_awesome_rounded,
      VoiceSessionPhase.speaking => Icons.graphic_eq_rounded,
      VoiceSessionPhase.connectingWs => Icons.sync_rounded,
      VoiceSessionPhase.errored => Icons.error_outline_rounded,
      _ => Icons.mic_rounded,
    };
  }
}
