import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../controllers/desktop_settings_controller.dart';
import '../lifecycle/desktop_lifecycle_coordinator.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.coordinator,
  });

  final DesktopSettingsController controller;
  final DesktopLifecycleCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Settings',
            style: CompanionTypography.titleLarge.copyWith(color: ext?.textPrimary),
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Appearance, storage diagnostics, and system integration',
            style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.xl),

          // 1. Appearance Section
          _buildAppearanceCard(context, ext, isDark),
          const SizedBox(height: CompanionSpacing.lg),

          // 2. Storage Diagnostics Section
          _buildStorageDiagnosticsCard(context, ext, isDark),
          const SizedBox(height: CompanionSpacing.lg),

          // 3. Window & Tray Lifecycle Section
          _buildLifecycleCard(context, ext, isDark),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Text(
                'Appearance & Theme',
                style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.lg),

          // Theme Mode (Light / Dark / System)
          Text(
            'Color Mode',
            style: CompanionTypography.bodyMedium.copyWith(
              color: ext?.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: CompanionSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_rounded, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_rounded, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_rounded, size: 16),
              ),
            ],
            selected: {controller.themeMode},
            onSelectionChanged: (selected) {
              if (selected.isNotEmpty) {
                controller.setThemeMode(selected.first);
              }
            },
          ),
          const SizedBox(height: CompanionSpacing.xl),

          // Accent Preset Selection
          Text(
            'Accent Color Preset',
            style: CompanionTypography.bodyMedium.copyWith(
              color: ext?.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: CompanionSpacing.sm),
          Wrap(
            spacing: CompanionSpacing.md,
            runSpacing: CompanionSpacing.sm,
            children: AccentPreset.values.map((preset) {
              final isSelected = controller.accentPreset == preset;
              return InkWell(
                onTap: () => controller.setAccentPreset(preset),
                borderRadius: CompanionRadius.borderMd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? preset.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                    borderRadius: CompanionRadius.borderMd,
                    border: Border.all(
                      color: isSelected ? preset.primary : (ext?.borderSubtle ?? Colors.transparent),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [preset.primary, preset.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: CompanionSpacing.sm),
                      Text(
                        preset.label,
                        style: CompanionTypography.bodySmall.copyWith(
                          color: isSelected ? ext?.textPrimary : ext?.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageDiagnosticsCard(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    return FutureBuilder<List<StorageDiagnosticInfo>>(
      future: controller.diagnosticReader.readDiagnosticRoots(),
      builder: (context, snapshot) {
        final roots = snapshot.data ?? [];
        final locatorInfo = roots.isNotEmpty ? roots.first : null;

        return SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.folder_special_outlined, size: 20, color: ext?.accent),
                        const SizedBox(width: CompanionSpacing.sm),
                        Flexible(
                          child: Text(
                            'Storage Diagnostics',
                            style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CompanionSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: CompanionRadius.borderSm,
                    ),
                    child: Text(
                      'Client Fail-Closed Inspection',
                      style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.md),
              Text(
                'Inspecting canonical Windows persistent storage roots. '
                'When the backend runtime is active, authoritative storage telemetry is reported by the server.',
                style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
              ),
              const SizedBox(height: CompanionSpacing.lg),

              if (locatorInfo != null) ...[
                _buildDiagnosticItem(
                  ext: ext,
                  isDark: isDark,
                  label: 'Bootstrap Locator',
                  path: r'%LOCALAPPDATA%\AI Companion\bootstrap.json',
                  status: locatorInfo.locatorStatus,
                  details: locatorInfo.details ?? 'Evaluated',
                ),
                const SizedBox(height: CompanionSpacing.md),
              ],

              for (final root in roots.skip(1)) ...[
                _buildDiagnosticItem(
                  ext: ext,
                  isDark: isDark,
                  label: 'Default Root (${root.rootType.name.toUpperCase()})',
                  path: root.resolvedPath ?? 'Not configured',
                  status: root.locatorStatus,
                  details: root.details ?? '',
                ),
                const SizedBox(height: CompanionSpacing.md),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticItem({
    required CompanionThemeExtension? ext,
    required bool isDark,
    required String label,
    required String path,
    required LocatorStatus status,
    required String details,
  }) {
    Color statusColor;
    String statusLabel;

    switch (status) {
      case LocatorStatus.validAvailable:
        statusColor = ext?.success ?? CompanionColors.success;
        statusLabel = 'Valid & Available';
        break;
      case LocatorStatus.validUnavailable:
        statusColor = ext?.warning ?? CompanionColors.warning;
        statusLabel = 'Valid (Target Missing)';
        break;
      case LocatorStatus.corrupt:
        statusColor = ext?.danger ?? CompanionColors.danger;
        statusLabel = 'Corrupt';
        break;
      case LocatorStatus.absent:
        statusColor = ext?.textSecondary ?? Colors.grey;
        statusLabel = 'Absent (Default OS Path)';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(CompanionSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(color: ext?.borderSubtle ?? Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: CompanionTypography.bodyMedium.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: CompanionRadius.borderFull,
                ),
                child: Text(
                  statusLabel,
                  style: CompanionTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          SelectableText(
            path,
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: CompanionSpacing.xs),
            Text(
              details,
              style: CompanionTypography.caption.copyWith(color: ext?.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLifecycleCard(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final isTrayAvailable = coordinator?.isTrayAvailable ?? false;

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.desktop_windows_outlined, size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Text(
                'Window & Tray Lifecycle',
                style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.md),
          Text(
            'Window Constraints: 1280x800 (1024x640 min)',
            style: CompanionTypography.bodySmall.copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            isTrayAvailable
                ? 'System Tray: Active (Close-to-Tray Active)'
                : 'System Tray: Unavailable (Close Exits App)',
            style: CompanionTypography.bodySmall.copyWith(
              color: isTrayAvailable ? (ext?.success ?? CompanionColors.success) : ext?.textSecondary,
            ),
          ),
          const SizedBox(height: CompanionSpacing.lg),
          Wrap(
            spacing: CompanionSpacing.md,
            runSpacing: CompanionSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: isTrayAvailable
                    ? () {
                        coordinator?.hideToTray();
                      }
                    : null,
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                label: const Text('Hide to Tray'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  coordinator?.handleExitRequested();
                },
                icon: const Icon(Icons.power_settings_new_rounded, size: 16),
                label: const Text('Exit Companion'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
