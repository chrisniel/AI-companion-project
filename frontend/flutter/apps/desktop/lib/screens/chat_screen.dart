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

          // Bottom Input Bar Placeholder (Batch 4 Integration Point)
          SoftGlassPanel(
            padding: const EdgeInsets.symmetric(
              horizontal: CompanionSpacing.lg,
              vertical: CompanionSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Type a message... (Awaiting runtime connection in Batch 4)',
                      hintStyle: CompanionTypography.bodyMedium.copyWith(
                        color: ext?.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 20),
                  color: ext?.textMuted,
                  onPressed: null,
                  tooltip: 'Send (Inactive in Batch 3)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
