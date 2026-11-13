import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_memory_controller.dart';
import 'memory_edit_dialog.dart';

/// Top bar hosting search input, filter chips, and "+ Add Memory" CTA.
class MemoryFilterBar extends StatelessWidget {
  const MemoryFilterBar({
    super.key,
    required this.controller,
  });

  final DesktopMemoryController controller;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Search Input
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search memories by keyword...',
                    hintStyle: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: ext?.textSecondary),
                    suffixIcon: controller.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => controller.setSearchQuery(''),
                            splashRadius: 16,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: CompanionRadius.borderMd,
                      borderSide: BorderSide(color: ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: CompanionRadius.borderMd,
                      borderSide: BorderSide(color: ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                  onChanged: (val) => controller.setSearchQuery(val),
                ),
              ),
            ),
            const SizedBox(width: CompanionSpacing.md),

            // Context-aware Add Button
            FilledButton.icon(
              key: const Key('add_memory_cta'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_addButtonLabel(controller.selectedTier)),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                final result = await showDialog<dynamic>(
                  context: context,
                  builder: (ctx) => MemoryEditDialog(
                    activeCharacterInstanceId: controller.activeCharacterInstanceId,
                    initialTier: controller.selectedTier,
                  ),
                );
                if (result is MemoryCreate) {
                  await controller.createMemory(result);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: CompanionSpacing.sm),

        // Filter Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Status Filters
              _buildFilterChipGroup(
                context,
                title: 'Status',
                selectedValue: controller.selectedStatusFilter,
                options: const [
                  ('all', 'All Status'),
                  ('verified', 'Verified'),
                  ('pending', 'Pending Review'),
                  ('conflicts', 'Conflicts'),
                ],
                onSelected: controller.setStatusFilter,
              ),
              const SizedBox(width: CompanionSpacing.md),

              // Scope Filters
              _buildFilterChipGroup(
                context,
                title: 'Scope',
                selectedValue: controller.selectedScopeFilter,
                options: [
                  ('all', 'All Scopes'),
                  ('profile', 'Profile'),
                  if (controller.activeCharacterInstanceId != null) ('character', 'Character'),
                ],
                onSelected: controller.setScopeFilter,
              ),
              const SizedBox(width: CompanionSpacing.md),

              // Category Filters
              _buildFilterChipGroup(
                context,
                title: 'Category',
                selectedValue: controller.selectedCategoryFilter,
                options: [
                  const ('all', 'All Categories'),
                  if (controller.selectedTier != 'short_term') ...[
                    const ('fact', 'Facts'),
                    const ('preference', 'Preferences'),
                  ],
                  if (controller.selectedTier == 'short_term') const ('context', 'Context'),
                ],
                onSelected: controller.setCategoryFilter,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _addButtonLabel(String tier) {
    switch (tier) {
      case 'knowledge':
        return 'Add Knowledge';
      case 'short_term':
        return 'Add Context';
      default:
        return 'Add Memory';
    }
  }

  Widget _buildFilterChipGroup(
    BuildContext context, {
    required String title,
    required String selectedValue,
    required List<(String, String)> options,
    required void Function(String) onSelected,
  }) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final isSelected = selectedValue == opt.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(opt.$2),
            selected: isSelected,
            visualDensity: VisualDensity.compact,
            labelStyle: CompanionTypography.caption.copyWith(
              color: isSelected ? Colors.white : ext?.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            selectedColor: ext?.accent ?? CompanionColors.lightAccent,
            onSelected: (_) => onSelected(opt.$1),
          ),
        );
      }).toList(),
    );
  }
}
