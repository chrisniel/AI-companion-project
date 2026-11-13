import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_memory_controller.dart';

class _MemoryTierNavItem {
  const _MemoryTierNavItem({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.count,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final int count;
}

/// Option 2A inner sub-menu for switching between Memory & Knowledge tiers.
class MemoryTierSidebar extends StatelessWidget {
  const MemoryTierSidebar({
    super.key,
    required this.controller,
    this.width = 224,
    this.compact = false,
  });

  final DesktopMemoryController controller;
  final double width;
  final bool compact;

  List<_MemoryTierNavItem> _items() {
    return [
      _MemoryTierNavItem(
        id: 'knowledge',
        label: 'Knowledge & Profile',
        subtitle: 'Pinned facts & lorebook',
        icon: Icons.auto_stories_rounded,
        count: controller.knowledgeCount,
      ),
      _MemoryTierNavItem(
        id: 'long_term',
        label: 'Long-Term Memories',
        subtitle: 'Learned durable facts',
        icon: Icons.psychology_rounded,
        count: controller.longTermCount,
      ),
      _MemoryTierNavItem(
        id: 'short_term',
        label: 'Short-Term Context',
        subtitle: '72h episodic buffer',
        icon: Icons.schedule_rounded,
        count: controller.shortTermCount,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final items = _items();

    if (compact) {
      return SoftGlassPanel(
        padding: const EdgeInsets.all(CompanionSpacing.xs),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items.map((item) {
              final selected = controller.selectedTier == item.id;
              return Padding(
                padding: const EdgeInsets.only(right: CompanionSpacing.xs),
                child: _buildTierTile(context, ext, item, selected, compactMode: true),
              );
            }).toList(),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: SoftGlassPanel(
        padding: const EdgeInsets.all(CompanionSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CompanionSpacing.xs,
                CompanionSpacing.xs,
                CompanionSpacing.xs,
                CompanionSpacing.sm,
              ),
              child: Text(
                'MEMORY TIERS',
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textMuted ?? ext?.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ...items.map((item) {
              final selected = controller.selectedTier == item.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: CompanionSpacing.xs),
                child: _buildTierTile(context, ext, item, selected, compactMode: false),
              );
            }),
            const Spacer(),
            Divider(
              height: CompanionSpacing.lg,
              color: ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CompanionSpacing.xs),
              child: Text(
                'Knowledge is protected from auto-overwrites. Short-Term context expires after 72h unless promoted.',
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierTile(
    BuildContext context,
    CompanionThemeExtension? ext,
    _MemoryTierNavItem item,
    bool selected, {
    required bool compactMode,
  }) {
    final accent = ext?.accent ?? CompanionColors.lightAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = selected
        ? accent
        : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02));
    final titleColor = selected ? Colors.white : (ext?.textPrimary ?? Colors.white);
    final subtitleColor =
        selected ? Colors.white.withValues(alpha: 0.85) : (ext?.textSecondary ?? Colors.grey);
    final badgeBg = selected
        ? Colors.white.withValues(alpha: 0.22)
        : accent.withValues(alpha: 0.14);
    final badgeFg = selected ? Colors.white : accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('memory_tier_${item.id}'),
        borderRadius: CompanionRadius.borderMd,
        onTap: () => controller.setTier(item.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: CompanionSpacing.sm,
            vertical: compactMode ? CompanionSpacing.xs : CompanionSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: CompanionRadius.borderMd,
            border: Border.all(
              color: selected
                  ? accent
                  : (ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.18)),
            ),
          ),
          child: Row(
            mainAxisSize: compactMode ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 18,
                color: selected ? Colors.white : accent,
              ),
              const SizedBox(width: CompanionSpacing.sm),
              if (compactMode)
                Text(
                  item.label,
                  style: CompanionTypography.caption.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CompanionTypography.bodySmall.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CompanionTypography.caption.copyWith(
                          color: subtitleColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: CompanionSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.count}',
                  style: CompanionTypography.caption.copyWith(
                    color: badgeFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
