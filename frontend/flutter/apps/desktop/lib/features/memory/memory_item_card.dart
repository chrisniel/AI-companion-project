import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_memory_controller.dart';
import 'memory_edit_dialog.dart';

/// Card component rendering an individual memory item with lifecycle actions.
class MemoryItemCard extends StatelessWidget {
  const MemoryItemCard({
    super.key,
    required this.memory,
    required this.controller,
  });

  final MemoryOut memory;
  final DesktopMemoryController controller;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPending = !memory.userVerified;
    final isConflict = memory.sourceType == 'conflict';
    final isShortTerm = memory.expiresAt != null || memory.category == 'context';
    final ttlLabel = _formatRemainingTtl(memory.expiresAt);
    final keywords = memory.triggerKeywords ?? const <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: CompanionSpacing.sm),
      padding: const EdgeInsets.all(CompanionSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(
          color: isPending
              ? Colors.amber.withValues(alpha: 0.4)
              : (ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2)),
          width: isPending ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: CompanionSpacing.xs,
                  runSpacing: CompanionSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Category badge
                    _buildBadge(
                      label: memory.category.toUpperCase(),
                      backgroundColor: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.12),
                      textColor: ext?.accent ?? CompanionColors.lightAccent,
                    ),

                    // Scope badge
                    _buildBadge(
                      label: memory.scope.toUpperCase(),
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      textColor: ext?.textSecondary ?? Colors.grey,
                    ),

                    // Status badge
                    if (isConflict)
                      _buildBadge(
                        label: 'CONFLICT',
                        backgroundColor: Colors.red.withValues(alpha: 0.15),
                        textColor: Colors.redAccent,
                      )
                    else if (isPending)
                      _buildBadge(
                        label: 'PENDING REVIEW',
                        backgroundColor: Colors.amber.withValues(alpha: 0.15),
                        textColor: Colors.amber,
                      )
                    else
                      _buildBadge(
                        label: 'VERIFIED',
                        backgroundColor: Colors.green.withValues(alpha: 0.12),
                        textColor: Colors.green,
                      ),

                    // Recall Frequency Counter Badge
                    if (memory.recallCount > 0)
                      _buildBadge(
                        label: 'RECALLED ${memory.recallCount}×',
                        backgroundColor: (ext?.accentSecondary ?? ext?.accent ?? CompanionColors.lightAccent)
                            .withValues(alpha: 0.14),
                        textColor: ext?.accent ?? CompanionColors.lightAccent,
                      ),

                    // Remaining TTL Badge for Short-Term Context
                    if (ttlLabel != null)
                      _buildBadge(
                        label: ttlLabel,
                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                        textColor: Colors.orangeAccent,
                      ),
                  ],
                ),
              ),

              // Core Star
              IconButton(
                icon: Icon(
                  memory.isCore ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: memory.isCore ? Colors.amber : ext?.textSecondary,
                  size: 20,
                ),
                tooltip: memory.isCore ? 'Unpin from Core' : 'Pin as Core Memory',
                visualDensity: VisualDensity.compact,
                splashRadius: 16,
                onPressed: () {
                  controller.updateMemory(
                    memory.id,
                    MemoryUpdate(isCore: !memory.isCore),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.sm),

          // Content
          Text(
            memory.content,
            style: CompanionTypography.bodyMedium.copyWith(
              color: ext?.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Trigger Keyword Pills (Lorebook Activation Triggers)
          if (keywords.isNotEmpty) ...[
            const SizedBox(height: CompanionSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: keywords
                  .map(
                    (kw) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.08),
                        borderRadius: CompanionRadius.borderSm,
                        border: Border.all(
                          color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        '#$kw',
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.accent ?? CompanionColors.lightAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: CompanionSpacing.sm),

          // Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isShortTerm && !isConflict) ...[
                OutlinedButton.icon(
                  key: Key('promote_memory_${memory.id}'),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 15),
                  label: const Text('Promote'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: ext?.accent ?? CompanionColors.lightAccent,
                  ),
                  onPressed: () => controller.promoteMemory(memory),
                ),
                const SizedBox(width: CompanionSpacing.sm),
              ],
              if (isPending && !isConflict) ...[
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.green,
                  ),
                  onPressed: () => controller.approveMemory(memory.id),
                ),
                const SizedBox(width: CompanionSpacing.sm),
              ],
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: ext?.textSecondary),
                tooltip: 'Edit Memory',
                visualDensity: VisualDensity.compact,
                splashRadius: 16,
                onPressed: () async {
                  final result = await showDialog<dynamic>(
                    context: context,
                    builder: (ctx) => MemoryEditDialog(
                      initialMemory: memory,
                      activeCharacterInstanceId: controller.activeCharacterInstanceId,
                    ),
                  );
                  if (result is MemoryUpdate) {
                    await controller.updateMemory(memory.id, result);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                tooltip: 'Delete Memory',
                visualDensity: VisualDensity.compact,
                splashRadius: 16,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Memory?'),
                      content: Text('Are you sure you want to forget: "${memory.content}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await controller.deleteMemory(memory.id);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _formatRemainingTtl(String? expiresAtIso) {
    if (expiresAtIso == null || expiresAtIso.isEmpty) return null;
    final parsed = DateTime.tryParse(expiresAtIso);
    if (parsed == null) return null;
    final diff = parsed.toUtc().difference(DateTime.now().toUtc());
    if (diff <= Duration.zero) return 'EXPIRED';
    if (diff.inHours < 24) {
      final hours = diff.inHours < 1 ? 1 : diff.inHours;
      return 'TTL ${hours}H LEFT';
    }
    return 'TTL ${diff.inDays}D LEFT';
  }

  Widget _buildBadge({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: CompanionRadius.borderSm,
      ),
      child: Text(
        label,
        style: CompanionTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
