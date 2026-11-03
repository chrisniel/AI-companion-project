import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'desktop_studio_controller.dart';

/// Left translucent SoftGlass dock containing starter templates, neutral fallback, and instances.
class StudioLibraryPanel extends StatelessWidget {
  const StudioLibraryPanel({
    super.key,
    required this.controller,
    required this.onSelectTemplate,
    required this.onSelectInstance,
    required this.onSelectNeutral,
  });

  final DesktopStudioController controller;
  final ValueChanged<CharacterTemplateOut> onSelectTemplate;
  final ValueChanged<CharacterInstanceOut> onSelectInstance;
  final VoidCallback onSelectNeutral;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    final activeInstances = controller.instances.where((i) => i.status == 'active' && !i.isLegacyPlaceholder).toList();
    final archivedInstances = controller.instances.where((i) => i.status == 'archived' || i.isLegacyPlaceholder).toList();

    return SoftGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      borderRadius: CompanionRadius.borderXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: ext?.accent),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'Character Library',
                  style: CompanionTypography.titleMedium.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Scrollable list of templates, neutral assistant, and instances
          Expanded(
            child: ListView(
              children: [
                // 1. STARTER TEMPLATES
                _buildSectionHeader(context, 'Starter Templates'),
                const SizedBox(height: 6.0),
                ...controller.templates.map((tmpl) {
                  final isSelected = !controller.isNeutralSelected &&
                      controller.draft != null &&
                      controller.draft!.isNew &&
                      controller.draft!.sourceTemplateId == tmpl.id;
                  return _buildItemCard(
                    context: context,
                    title: tmpl.name,
                    subtitle: tmpl.summary,
                    badge: tmpl.defaultPresetId != null ? _formatPresetLabel(tmpl.defaultPresetId!) : null,
                    icon: Icons.person_outline_rounded,
                    isSelected: isSelected,
                    onTap: () => onSelectTemplate(tmpl),
                  );
                }),

                const SizedBox(height: 14.0),

                // 2. NEUTRAL ASSISTANT FALLBACK
                _buildSectionHeader(context, 'System Fallback'),
                const SizedBox(height: 6.0),
                _buildItemCard(
                  context: context,
                  title: controller.neutral?.name ?? 'Neutral Assistant',
                  subtitle: controller.neutral?.summary ?? 'Unmodulated impartial assistant',
                  badge: controller.isNeutralActive ? 'Active in Chat' : null,
                  badgeIsSuccess: controller.isNeutralActive,
                  icon: Icons.shield_outlined,
                  isSelected: controller.isNeutralSelected,
                  onTap: onSelectNeutral,
                ),

                const SizedBox(height: 14.0),

                // 3. PROFILE CHARACTERS (INSTANCES)
                _buildSectionHeader(context, 'My Characters (${activeInstances.length})'),
                const SizedBox(height: 6.0),
                if (activeInstances.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Text(
                      'No custom characters created yet. Select a template above to create one.',
                      style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
                    ),
                  )
                else
                  ...activeInstances.map((inst) {
                    final isSelected = !controller.isNeutralSelected &&
                        controller.draft != null &&
                        !controller.draft!.isNew &&
                        controller.draft!.instanceId == inst.id;
                    final isActive = controller.activeInstanceId == inst.id;
                    return _buildItemCard(
                      context: context,
                      title: inst.name,
                      subtitle: inst.summary.isNotEmpty ? inst.summary : (inst.presetId ?? 'Custom'),
                      badge: isActive ? 'Active in Chat' : (inst.presetId != null ? _formatPresetLabel(inst.presetId!) : null),
                      badgeIsSuccess: isActive,
                      icon: Icons.face_rounded,
                      isSelected: isSelected,
                      onTap: () => onSelectInstance(inst),
                    );
                  }),

                const SizedBox(height: 14.0),

                // 4. ARCHIVED / LEGACY SECTION
                InkWell(
                  onTap: controller.toggleShowArchived,
                  borderRadius: CompanionRadius.borderMd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Archived / Legacy (${archivedInstances.length})',
                            style: CompanionTypography.caption.copyWith(
                              color: ext?.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          controller.showArchived ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 16,
                          color: ext?.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (controller.showArchived) ...[
                  const SizedBox(height: 6.0),
                  if (archivedInstances.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No archived characters.',
                        style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
                      ),
                    )
                  else
                    ...archivedInstances.map((inst) {
                      final isSelected = !controller.isNeutralSelected &&
                          controller.draft != null &&
                          !controller.draft!.isNew &&
                          controller.draft!.instanceId == inst.id;
                      return _buildItemCard(
                        context: context,
                        title: inst.name,
                        subtitle: inst.isLegacyPlaceholder ? 'Historical placeholder' : 'Archived',
                        badge: inst.isLegacyPlaceholder ? 'Legacy' : 'Archived',
                        icon: Icons.archive_outlined,
                        isSelected: isSelected,
                        onTap: () => onSelectInstance(inst),
                      );
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    return Text(
      title,
      style: CompanionTypography.caption.copyWith(
        color: ext?.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildItemCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    String? badge,
    bool badgeIsSuccess = false,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseBg = isDark
        ? (ext?.surfaceElevated ?? const Color(0xFF1E293B)).withValues(alpha: 0.85)
        : (ext?.surfaceRecessed ?? const Color(0xFFF1F5F9)).withValues(alpha: 0.90);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Material(
        color: isSelected ? (ext?.accent ?? Colors.blue).withValues(alpha: 0.18) : baseBg,
        borderRadius: CompanionRadius.borderMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: CompanionRadius.borderMd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              borderRadius: CompanionRadius.borderMd,
              border: Border.all(
                color: isSelected ? (ext?.accent ?? Colors.blue) : (ext?.borderSubtle ?? Colors.transparent),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? (ext?.accent ?? Colors.blue) : ext?.textSecondary,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: CompanionTypography.bodyMedium.copyWith(
                                color: ext?.textPrimary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6.0),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: badgeIsSuccess
                                      ? (ext?.success ?? Colors.green).withValues(alpha: 0.15)
                                      : (ext?.accent ?? Colors.blue).withValues(alpha: 0.15),
                                  borderRadius: CompanionRadius.borderFull,
                                ),
                                child: Text(
                                  badge,
                                  style: CompanionTypography.caption.copyWith(
                                    color: badgeIsSuccess ? (ext?.success ?? Colors.green) : (ext?.accent ?? Colors.blue),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.textSecondary,
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
        ),
      ),
    );
  }

  static String _formatPresetLabel(String id) {
    switch (id) {
      case 'warm_companion': return 'Warm';
      case 'playful': return 'Playful';
      case 'formal_advisor': return 'Advisor';
      case 'tsundere': return 'Tsundere';
      case 'kuudere': return 'Kuudere';
      case 'dandere': return 'Dandere';
      case 'yandere': return 'Yandere';
      case 'custom': return 'Custom';
      default: return id;
    }
  }
}
