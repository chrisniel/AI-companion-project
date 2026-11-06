import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_memory_controller.dart';

/// Prominent Conflict Action Banner displayed at the top of the Memory Control Center.
class MemoryConflictBanner extends StatelessWidget {
  const MemoryConflictBanner({
    super.key,
    required this.controller,
  });

  final DesktopMemoryController controller;

  @override
  Widget build(BuildContext context) {
    final conflicts = controller.activeConflicts;
    if (conflicts.isEmpty) return const SizedBox.shrink();

    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: CompanionSpacing.lg),
      padding: const EdgeInsets.all(CompanionSpacing.md),
      decoration: BoxDecoration(
        color: (Colors.amber).withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: CompanionRadius.borderLg,
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 22,
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Text(
                'Memory Contradiction Detected (${conflicts.length})',
                style: CompanionTypography.titleSmall.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'The companion noticed statements that contradict existing beliefs. Choose which fact to establish or combine them into a single truth.',
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textSecondary,
            ),
          ),
          const SizedBox(height: CompanionSpacing.md),
          ...conflicts.map((conflict) => _ConflictItemCard(
                conflict: conflict,
                controller: controller,
              )),
        ],
      ),
    );
  }
}

class _ConflictItemCard extends StatelessWidget {
  const _ConflictItemCard({
    required this.conflict,
    required this.controller,
  });

  final MemoryOut conflict;
  final DesktopMemoryController controller;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: CompanionSpacing.xs),
      padding: const EdgeInsets.all(CompanionSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(
          color: ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: CompanionRadius.borderSm,
                ),
                child: Text(
                  'NEW STATEMENT',
                  style: CompanionTypography.caption.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  conflict.content,
                  style: CompanionTypography.bodyMedium.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.sm),
          Wrap(
            spacing: CompanionSpacing.sm,
            runSpacing: CompanionSpacing.xs,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Keep New'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ext?.accent ?? CompanionColors.lightAccent,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => controller.resolveConflictKeepNew(conflictMemory: conflict),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Keep Old (Discard New)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ext?.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => controller.resolveConflictKeepOld(conflictMemory: conflict),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit & Merge'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ext?.textPrimary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  final merged = await showDialog<String>(
                    context: context,
                    builder: (ctx) => _MergeConflictDialog(
                      initialContent: conflict.content,
                    ),
                  );
                  if (merged != null && merged.trim().isNotEmpty) {
                    await controller.resolveConflictMerge(
                      conflictMemory: conflict,
                      mergedContent: merged.trim(),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MergeConflictDialog extends StatefulWidget {
  const _MergeConflictDialog({required this.initialContent});
  final String initialContent;

  @override
  State<_MergeConflictDialog> createState() => _MergeConflictDialogState();
}

class _MergeConflictDialogState extends State<_MergeConflictDialog> {
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return AlertDialog(
      title: Text('Edit & Reconcile Memory', style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary)),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rewrite the conflicting statement to reflect your current preference or fact:',
              style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
            ),
            const SizedBox(height: CompanionSpacing.md),
            TextField(
              controller: _textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter reconciled memory...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_textCtrl.text),
          child: const Text('Save Reconciled Fact'),
        ),
      ],
    );
  }
}
