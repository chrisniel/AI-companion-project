import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat',
                      style: CompanionTypography.titleLarge.copyWith(
                        color: ext?.textPrimary,
                      ),
                    ),
                    const SizedBox(height: CompanionSpacing.xs),
                    Text(
                      'Conversational workspace',
                      style: CompanionTypography.bodySmall.copyWith(
                        color: ext?.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CompanionSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CompanionSpacing.md,
                  vertical: CompanionSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: CompanionRadius.borderFull,
                  border: Border.all(
                    color: ext?.borderSubtle ?? Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ext?.warning ?? CompanionColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    Text(
                      'Runtime: Standalone (Unconnected)',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.lg),

          // Central Conversational Stage
          Expanded(
            child: SoftGlassPanel(
              padding: const EdgeInsets.all(CompanionSpacing.xxl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 28,
                          color: ext?.accent ?? CompanionColors.lightAccent,
                        ),
                      ),
                      const SizedBox(height: CompanionSpacing.lg),
                      Text(
                        'AI Companion Desktop',
                        style: CompanionTypography.titleMedium.copyWith(
                          color: ext?.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: CompanionSpacing.sm),
                      Text(
                        'SoftGlass navigation shell and design system foundation are active. '
                        'Local LLM inference and SSE streaming connection will be wired in Milestone M1 Batch 4.',
                        style: CompanionTypography.bodyMedium.copyWith(
                          color: ext?.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: CompanionSpacing.lg),

          // Bottom Composer Bar (Neumorphic Liquid Glass + Recessed Input Well)
          NeumorphicSurface(
            surfaceType: NeumorphicSurfaceType.glassElevated,
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const NeumorphicButton(
                      size: NeumorphicButtonSize.sm,
                      icon: Icon(Icons.attach_file_rounded),
                      tooltip: 'Attach images or files (Batch 4)',
                      onPressed: null,
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    Expanded(
                      child: NeumorphicSurface(
                        surfaceType: NeumorphicSurfaceType.recessed,
                        borderRadius: CompanionRadius.borderMd,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            hintText: 'Message AI Companion or run slash commands... (Batch 4)',
                            hintStyle: CompanionTypography.bodyMedium.copyWith(
                              color: ext?.textMuted,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    const NeumorphicButton(
                      size: NeumorphicButtonSize.sm,
                      icon: Icon(Icons.mic_none_rounded),
                      tooltip: 'Voice input (Microphone not connected)',
                      onPressed: null,
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ext?.accent ?? CompanionColors.lightAccent,
                            ext?.accentSecondary ?? CompanionColors.lightAccentSecondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: CompanionRadius.borderMd,
                        boxShadow: [
                          BoxShadow(
                            color: (ext?.accentGlow ?? Colors.transparent).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: CompanionSpacing.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CompanionSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Press Enter to send • Shift + Enter for newline',
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: CompanionSpacing.sm),
                      Text(
                        'Context buffer: Standalone (Batch 4)',
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.textMuted,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
