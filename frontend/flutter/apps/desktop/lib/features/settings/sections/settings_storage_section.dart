import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../platform/desktop_client_settings.dart';
import '../../../platform/host_admin_secret_store.dart';
import '../../../platform/windows_dpapi_credential_store.dart';

/// Fail-closed Windows storage root inspection, live 5-root telemetry & LIBRARY_ROOT relocation.
class SettingsStorageSection extends StatefulWidget {
  const SettingsStorageSection({
    super.key,
    required this.diagnosticReader,
    this.client,
    this.clientSettings,
    this.credentialStore,
  });

  final StorageDiagnosticReader diagnosticReader;
  final CompanionClient? client;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;

  @override
  State<SettingsStorageSection> createState() => _SettingsStorageSectionState();
}

class _SettingsStorageSectionState extends State<SettingsStorageSection> {
  late Future<List<StorageDiagnosticInfo>> _rootsFuture;
  final TextEditingController _relocateController = TextEditingController();

  StorageRootsResponse? _backendRoots;
  bool _isLoadingBackend = false;
  bool _isRelocating = false;
  bool _migrateAssets = true;
  String? _backendMessage;

  @override
  void initState() {
    super.initState();
    _rootsFuture = widget.diagnosticReader.readDiagnosticRoots();
    if (widget.client != null ||
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      _loadBackendStorage();
    }
  }

  @override
  void didUpdateWidget(covariant SettingsStorageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.diagnosticReader != oldWidget.diagnosticReader) {
      _rootsFuture = widget.diagnosticReader.readDiagnosticRoots();
    }
    if (widget.client != oldWidget.client && widget.client != null) {
      _loadBackendStorage();
    }
  }

  @override
  void dispose() {
    _relocateController.dispose();
    super.dispose();
  }

  Future<CompanionClient> _resolveClient() async {
    if (widget.client != null) return widget.client!;
    final settings = widget.clientSettings ?? DesktopClientSettings();
    final url = await settings.readHostUrl();
    return CompanionClient(
      baseUrl: url.isNotEmpty ? url : 'http://127.0.0.1:8000',
      credentialStore: widget.credentialStore ?? WindowsDpapiCredentialStore(),
      hostAdminStore: HostAdminSecretStore(),
    );
  }

  Future<void> _loadBackendStorage() async {
    if (_isLoadingBackend) return;
    setState(() {
      _isLoadingBackend = true;
    });
    try {
      final client = await _resolveClient();
      final res = await client.getStorageRoots();
      if (!mounted) return;
      setState(() {
        _backendRoots = res;
        _isLoadingBackend = false;
        if (_relocateController.text.isEmpty) {
          _relocateController.text = res.libraryRoot;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBackend = false;
        _backendMessage = 'Backend storage telemetry unavailable: $e';
      });
    }
  }

  Future<void> _relocateLibrary() async {
    final target = _relocateController.text.trim();
    if (target.isEmpty || _isRelocating) return;
    setState(() {
      _isRelocating = true;
      _backendMessage = 'Relocating LIBRARY_ROOT...';
    });
    try {
      final client = await _resolveClient();
      final updated = await client.relocateLibraryRoot(
        LibraryRootUpdateRequest(
          newLibraryRoot: target,
          migrateExistingAssets: _migrateAssets,
        ),
      );
      if (!mounted) return;
      setState(() {
        _backendRoots = updated;
        _relocateController.text = updated.libraryRoot;
        _isRelocating = false;
        _backendMessage = 'LIBRARY_ROOT relocated to ${updated.libraryRoot}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRelocating = false;
        _backendMessage = 'Relocation failed: $e';
      });
    }
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    setState(() {
      _backendMessage = 'Copied path to clipboard.';
    });
  }

  Future<void> _openInExplorer(String path) async {
    if (!Platform.isWindows || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      await Process.run('explorer.exe', [path]);
    } catch (_) {}
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return 'Unknown';
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1.0) return '${gb.toStringAsFixed(1)} GB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
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
                    'Client diagnostics verify local bootstrap configuration even when the backend is stopped.',
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
        _buildBackendStoragePanel(ext, isDark),
      ],
    );
  }

  Widget _buildBackendStoragePanel(
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final backend = _backendRoots;
    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.drive_file_move_outlined, size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Five Storage Roots & Relocatable Library (PC-HOST-004)',
                  style: CompanionTypography.titleMedium
                      .copyWith(color: ext?.textPrimary),
                ),
              ),
              IconButton(
                onPressed: _isLoadingBackend ? null : _loadBackendStorage,
                icon: _isLoadingBackend
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Backend Storage Telemetry',
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Relocate the large Model & Voice Library Root across drives while keeping the SQLite database anchored on DATA_ROOT.',
            style: CompanionTypography.caption
                .copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.md),
          if (backend != null) ...[
            for (final root in backend.roots) ...[
              NeumorphicSurface(
                surfaceType: NeumorphicSurfaceType.recessed,
                borderRadius: CompanionRadius.borderMd,
                padding: const EdgeInsets.all(CompanionSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            root.label,
                            style: CompanionTypography.bodySmall.copyWith(
                              color: ext?.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ext?.accent.withValues(alpha: 0.14),
                            borderRadius: CompanionRadius.borderSm,
                          ),
                          child: Text(
                            'Source: ${root.source}',
                            style: CompanionTypography.caption.copyWith(
                              color: ext?.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      root.path,
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: CompanionSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          root.exists ? 'On Disk' : 'Created Lazily on First Use',
                          style: CompanionTypography.caption.copyWith(
                            color: root.exists
                                ? (ext?.success ?? CompanionColors.success)
                                : ext?.textMuted,
                          ),
                        ),
                        if (root.freeBytes != null)
                          Text(
                            'Free: ${_formatBytes(root.freeBytes)} / ${_formatBytes(root.totalBytes)}',
                            style: CompanionTypography.caption
                                .copyWith(color: ext?.textSecondary),
                          ),
                        TextButton.icon(
                          onPressed: () => _copyPath(root.path),
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Copy Path'),
                        ),
                        if (Platform.isWindows)
                          TextButton.icon(
                            onPressed: () => _openInExplorer(root.path),
                            icon: const Icon(Icons.folder_open_rounded, size: 14),
                            label: const Text('Open Folder'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CompanionSpacing.sm),
            ],
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              'Relocate LIBRARY_ROOT',
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: CompanionSpacing.xs),
            TextField(
              key: const Key('relocate_library_root_input'),
              controller: _relocateController,
              enabled: backend.libraryRelocatable && !_isRelocating,
              decoration: const InputDecoration(
                labelText: 'New Absolute Library Path',
                hintText: r'E:\AI Companion Library',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: CompanionSpacing.xs),
            Wrap(
              spacing: CompanionSpacing.sm,
              runSpacing: CompanionSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _migrateAssets,
                      onChanged: backend.libraryRelocatable && !_isRelocating
                          ? (v) => setState(() => _migrateAssets = v)
                          : null,
                    ),
                    Flexible(
                      child: Text(
                        'Copy existing models, voices & inbox files to new location',
                        style: CompanionTypography.caption
                            .copyWith(color: ext?.textSecondary),
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  key: const Key('relocate_library_root_button'),
                  onPressed: (!backend.libraryRelocatable || _isRelocating)
                      ? null
                      : _relocateLibrary,
                  icon: _isRelocating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.drive_file_move_rounded, size: 16),
                  label: const Text('Relocate Library'),
                ),
              ],
            ),
            if (!backend.libraryRelocatable &&
                backend.relocationBlockedReason != null) ...[
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                backend.relocationBlockedReason!,
                style: CompanionTypography.caption.copyWith(
                  color: ext?.warning ?? CompanionColors.warning,
                ),
              ),
            ],
          ] else
            Text(
              'Connect Host Admin runtime or click Refresh to inspect live volume telemetry across all five storage roots.',
              style: CompanionTypography.caption
                  .copyWith(color: ext?.textSecondary),
            ),
          if (_backendMessage != null) ...[
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              _backendMessage!,
              style: CompanionTypography.caption
                  .copyWith(color: ext?.textPrimary),
            ),
          ],
        ],
      ),
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
