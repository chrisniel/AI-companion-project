import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../features/memory/desktop_memory_controller.dart';
import '../features/memory/memory_conflict_banner.dart';
import '../features/memory/memory_filter_bar.dart';
import '../features/memory/memory_item_card.dart';

/// Full Desktop Memory Control Center Screen (PC-CLIENT-009).
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({
    super.key,
    this.controller,
  });

  final DesktopMemoryController? controller;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller != null && widget.controller!.memories.isEmpty) {
      widget.controller!.loadMemories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final controller = widget.controller;

    if (controller == null) {
      return Padding(
        padding: const EdgeInsets.all(CompanionSpacing.xl),
        child: Center(
          child: Text(
            'Memory service is initializing...',
            style: CompanionTypography.bodyMedium.copyWith(color: ext?.textSecondary),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Screen Header with Per-Profile Auto-Extraction Switch
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Memory & Knowledge',
                          style: CompanionTypography.titleLarge.copyWith(color: ext?.textPrimary),
                        ),
                        const SizedBox(height: CompanionSpacing.xs),
                        Text(
                          'Personalized facts, verified profile knowledge, and companion memories',
                          style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Per-Profile Extraction Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.08),
                      borderRadius: CompanionRadius.borderMd,
                      border: Border.all(
                        color: ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: ext?.accent ?? CompanionColors.lightAccent,
                        ),
                        const SizedBox(width: CompanionSpacing.xs),
                        Text(
                          'Auto-Extract Facts',
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: CompanionSpacing.sm),
                        Switch(
                          value: controller.memoryExtractionEnabled,
                          onChanged: (val) => controller.toggleProfileExtraction(val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.lg),

              // Active Conflicts Warning Banner
              MemoryConflictBanner(controller: controller),

              // Filter & Search Bar
              MemoryFilterBar(controller: controller),
              const SizedBox(height: CompanionSpacing.md),

              // Memory List / Status View
              Expanded(
                child: _buildListContent(context, ext, controller),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListContent(
    BuildContext context,
    CompanionThemeExtension? ext,
    DesktopMemoryController controller,
  ) {
    if (controller.isLoading && controller.memories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null && controller.memories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              'Failed to load memories',
              style: CompanionTypography.bodyMedium.copyWith(color: ext?.textPrimary),
            ),
            const SizedBox(height: CompanionSpacing.xs),
            Text(
              controller.errorMessage!,
              style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CompanionSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              onPressed: () => controller.loadMemories(),
            ),
          ],
        ),
      );
    }

    if (controller.memories.isEmpty) {
      return SoftGlassPanel(
        padding: const EdgeInsets.all(CompanionSpacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 48,
                color: ext?.textSecondary,
              ),
              const SizedBox(height: CompanionSpacing.md),
              Text(
                'No memories found',
                style: CompanionTypography.titleSmall.copyWith(color: ext?.textPrimary),
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                controller.searchQuery.isNotEmpty
                    ? 'No memories match your search filter.'
                    : 'Add a new memory manually or chat with your companion to automatically extract facts.',
                style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: controller.memories.length,
      itemBuilder: (context, index) {
        final memory = controller.memories[index];
        return MemoryItemCard(
          key: ValueKey(memory.id),
          memory: memory,
          controller: controller,
        );
      },
    );
  }
}
