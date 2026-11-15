import 'dart:io';

import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

/// Fail-closed Windows storage root inspection and diagnostics section.
class SettingsStorageSection extends StatefulWidget {
  const SettingsStorageSection({
    super.key,
    required this.diagnosticReader,
  });

  final StorageDiagnosticReader diagnosticReader;

  @override
  State<SettingsStorageSection> createState() => _SettingsStorageSectionState();
}

class _SettingsStorageSectionState extends State<SettingsStorageSection> {
  late Future<List<StorageDiagnosticInfo>> _rootsFuture;

  @override
  void initState() {
    super.initState();
    _rootsFuture = widget.diagnosticReader.readDiagnosticRoots();
  }

  @override
  void didUpdateWidget(covariant SettingsStorageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.diagnosticReader != oldWidget.diagnosticReader) {
      _rootsFuture = widget.diagnosticReader.readDiagnosticRoots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<List<StorageDiagnosticInfo>>(
          future: _rootsFuture,
          builder: (context, snapshot) {
            final roots = snapshot.data ?? [];
            final locatorInfo = roots.isNotEmpty ? roots.first : null;

            return SoftGlassPanel(
              padding: const EdgeInsets.all(CompanionSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: CompanionSpacing.sm,
                    runSpacing: CompanionSpacing.xs,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_special_outlined,
                            size: 20,
                            color: ext?.accent,
                          ),
                          const SizedBox(width: CompanionSpacing.sm),
                          Flexible(
                            child: Text(
                              'Storage Diagnostics',
                              style: CompanionTypography.titleMedium
                                  .copyWith(color: ext?.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: CompanionRadius.borderSm,
                        ),
                        child: Text(
                          'Client Fail-Closed Inspection',
                          style: CompanionTypography.caption
                              .copyWith(color: ext?.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CompanionSpacing.md),
                  Text(
                    'Inspecting canonical Windows persistent storage roots. '
                    'Backend storage telemetry is not available in M1 standalone mode.',
                    style: CompanionTypography.bodySmall
                        .copyWith(color: ext?.textSecondary),
                  ),
                  const SizedBox(height: CompanionSpacing.lg),
                  if (locatorInfo != null) ...[
                    _buildDiagnosticItem(
                      ext: ext,
                      label: 'Bootstrap Locator',
                      path: r'%LOCALAPPDATA%\AI Companion\bootstrap.json',
                      status: locatorInfo.locatorStatus,
                      details: locatorInfo.details ?? 'Evaluated',
                    ),
                    const SizedBox(height: CompanionSpacing.md),
                    if (locatorInfo.resolvedPath != null) ...[
                      _buildDiagnosticItem(
                        ext: ext,
                        label: 'Configured Storage Root (DATA)',
                        path: locatorInfo.resolvedPath,
                        status: locatorInfo.locatorStatus,
                        details: locatorInfo.details ?? '',
                      ),
                      const SizedBox(height: CompanionSpacing.md),
                    ],
                  ],
                  for (final root in roots.skip(1)) ...[
                    _buildDiagnosticItem(
                      ext: ext,
                      label: _labelForRootType(root.rootType),
                      path: root.resolvedPath,
                      status: root.locatorStatus,
                      details: root.details ?? '',
                    ),
                    const SizedBox(height: CompanionSpacing.md),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: CompanionSpacing.lg),
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.drive_file_move_outlined, size: 18, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relocatable Model & Data Roots (Planned — PC-HOST-004)',
                      style: CompanionTypography.bodySmall.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Interactive storage root relocation across drives is planned under PC-HOST-004.',
                      style: CompanionTypography.caption
                          .copyWith(color: ext?.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _labelForRootType(StorageRootType type) {
    switch (type) {
      case StorageRootType.appInstall:
        return 'Application Install (APP_INSTALL)';
      case StorageRootType.data:
        return 'Default Storage Root (DATA)';
      case StorageRootType.library:
        return 'Model & Library Root (LIBRARY)';
      case StorageRootType.cache:
        return 'Cache Root (CACHE)';
      case StorageRootType.log:
        return 'Log Root (LOG)';
    }
  }

  String _sanitizePathForDisplay(String? path) {
    if (path == null || path.isEmpty) {
      return 'Not reported by backend';
    }
    var sanitized = path;
    try {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        if (sanitized.toLowerCase().startsWith(localAppData.toLowerCase())) {
          sanitized = '%LOCALAPPDATA%${sanitized.substring(localAppData.length)}';
        }
      }
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        if (sanitized.toLowerCase().startsWith(userProfile.toLowerCase())) {
          sanitized = '%USERPROFILE%${sanitized.substring(userProfile.length)}';
        }
      }
    } catch (_) {}
    return sanitized;
  }

  Widget _buildDiagnosticItem({
    required CompanionThemeExtension? ext,
    required String label,
    required String? path,
    required LocatorStatus status,
    required String details,
  }) {
    final Color statusColor;
    final String statusLabel;

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

    final displayPath = _sanitizePathForDisplay(path);

    return NeumorphicSurface(
      surfaceType: NeumorphicSurfaceType.recessed,
      borderRadius: CompanionRadius.borderMd,
      padding: const EdgeInsets.all(CompanionSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: CompanionSpacing.sm,
            runSpacing: CompanionSpacing.xs,
            children: [
              Text(
                label,
                style: CompanionTypography.bodyMedium.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
            displayPath,
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
          if (details.isNotEmpty && details != displayPath) ...[
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
}
