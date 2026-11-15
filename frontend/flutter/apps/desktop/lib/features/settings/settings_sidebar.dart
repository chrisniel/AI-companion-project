import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'settings_section.dart';

/// Left category sidebar (or compact horizontal strip) for [SettingsScreen].
class SettingsSidebar extends StatelessWidget {
  const SettingsSidebar({
    super.key,
    required this.selectedSection,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSectionSelected,
    this.compact = false,
  });

  final SettingsSectionId selectedSection;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<SettingsSectionId> onSectionSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = filterSettingsSections(searchQuery);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CompanionSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchField(ext, isDark),
            const SizedBox(height: CompanionSpacing.sm),
            if (filtered.isEmpty)
              _buildEmptySearchCompact(ext)
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filtered
                      .map((meta) => _buildCompactChip(meta, ext, isDark))
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      );
    }

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            _buildSearchField(ext, isDark),
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              'CATEGORIES',
              style: CompanionTypography.caption.copyWith(
                color: ext?.textMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: CompanionSpacing.xs),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptySearchExpanded(ext)
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: CompanionSpacing.xs),
                      itemBuilder: (_, index) =>
                          _buildSidebarTile(filtered[index], ext, isDark),
                    ),
            ),
          ],
        ),
      );
  }

  Widget _buildSearchField(CompanionThemeExtension? ext, bool isDark) {
    return NeumorphicSurface(
      surfaceType: NeumorphicSurfaceType.recessed,
      borderRadius: CompanionRadius.borderMd,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 16,
            color: ext?.textMuted,
          ),
          const SizedBox(width: CompanionSpacing.xs),
          Expanded(
            child: TextField(
              key: const Key('settings_search_input'),
              controller: searchController,
              onChanged: onSearchChanged,
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Search settings...',
                hintStyle: CompanionTypography.bodySmall.copyWith(
                  color: ext?.textMuted,
                ),
              ),
            ),
          ),
          if (searchQuery.trim().isNotEmpty)
            IconButton(
              key: const Key('settings_search_suffix_clear'),
              icon: Icon(Icons.close_rounded, size: 15, color: ext?.textMuted),
              tooltip: 'Clear search',
              onPressed: onClearSearch,
              splashRadius: 14,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarTile(
    SettingsSectionMeta meta,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final isSelected = selectedSection == meta.id;
    final accent = ext?.accent ?? CompanionColors.lightAccent;

    return InkWell(
      key: Key('settings_nav_${meta.id.name}'),
      borderRadius: CompanionRadius.borderMd,
      onTap: () => onSectionSelected(meta.id),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CompanionSpacing.sm,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: isDark ? 0.22 : 0.14)
              : Colors.transparent,
          borderRadius: CompanionRadius.borderMd,
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.45)
                : (ext?.borderSubtle ?? Colors.transparent).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                meta.icon,
                size: 17,
                color: isSelected ? accent : ext?.textSecondary,
              ),
            ),
            const SizedBox(width: CompanionSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meta.label,
                          style: CompanionTypography.bodySmall.copyWith(
                            color: isSelected ? ext?.textPrimary : ext?.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildStatusBadge(meta, ext, isDark, isSelected),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.description,
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    SettingsSectionMeta meta,
    CompanionThemeExtension? ext,
    bool isDark,
    bool isSelected,
  ) {
    final isPlanned = meta.status == SettingsSectionStatus.planned;
    final badgeText = isPlanned ? (meta.milestoneHint ?? 'PLANNED') : 'AVAILABLE';
    final Color bgColor;
    final Color fgColor;

    if (isPlanned) {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);
      fgColor = ext?.textMuted ?? Colors.grey;
    } else {
      bgColor = (ext?.success ?? CompanionColors.success).withValues(alpha: 0.16);
      fgColor = ext?.success ?? CompanionColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: CompanionRadius.borderSm,
      ),
      child: Text(
        badgeText,
        style: CompanionTypography.caption.copyWith(
          color: fgColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCompactChip(
    SettingsSectionMeta meta,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final isSelected = selectedSection == meta.id;
    final accent = ext?.accent ?? CompanionColors.lightAccent;

    return Padding(
      padding: const EdgeInsets.only(right: CompanionSpacing.xs),
      child: InkWell(
        key: Key('settings_nav_${meta.id.name}'),
        borderRadius: CompanionRadius.borderFull,
        onTap: () => onSectionSelected(meta.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: isDark ? 0.24 : 0.14)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: CompanionRadius.borderFull,
            border: Border.all(
              color: isSelected
                  ? accent
                  : (ext?.borderSubtle ?? Colors.transparent),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                meta.icon,
                size: 14,
                color: isSelected ? accent : ext?.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                meta.label,
                style: CompanionTypography.caption.copyWith(
                  color: isSelected ? ext?.textPrimary : ext?.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (meta.status == SettingsSectionStatus.planned &&
                  meta.milestoneHint != null) ...[
                const SizedBox(width: 4),
                Text(
                  meta.milestoneHint!,
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchExpanded(CompanionThemeExtension? ext) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CompanionSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 28, color: ext?.textMuted),
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              'No matching settings categories',
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CompanionSpacing.xs),
            TextButton(
              key: const Key('settings_search_clear_button'),
              onPressed: onClearSearch,
              child: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchCompact(CompanionThemeExtension? ext) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'No matching settings categories',
            style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          key: const Key('settings_search_clear_button'),
          onPressed: onClearSearch,
          child: const Text('Clear search'),
        ),
      ],
    );
  }
}
