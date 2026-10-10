import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

class VoiceScreen extends StatelessWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return Padding(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Voice Interaction',
            style: CompanionTypography.titleLarge.copyWith(color: ext?.textPrimary),
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Real-time voice streaming and audio conversation',
            style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.xl),
          Expanded(
            child: SoftGlassPanel(
              padding: const EdgeInsets.all(CompanionSpacing.xxl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.12),
                          borderRadius: CompanionRadius.borderFull,
                        ),
                        child: Text(
                          'PLANNED MILESTONE M4',
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.accent ?? CompanionColors.lightAccent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: CompanionSpacing.lg),
                      Icon(
                        Icons.mic_none_rounded,
                        size: 48,
                        color: ext?.textSecondary,
                      ),
                      const SizedBox(height: CompanionSpacing.md),
                      Text(
                        'Voice Companion Pipeline',
                        style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
                      ),
                      const SizedBox(height: CompanionSpacing.sm),
                      Text(
                        'Full-duplex audio capture, VAD, STT, and neural TTS voice response will be delivered in Milestone M4.',
                        style: CompanionTypography.bodyMedium.copyWith(color: ext?.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
