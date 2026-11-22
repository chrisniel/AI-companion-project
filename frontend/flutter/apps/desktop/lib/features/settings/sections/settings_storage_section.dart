import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../controllers/desktop_settings_controller.dart';
import '../../../platform/desktop_client_settings.dart';
import '../../../platform/host_admin_secret_store.dart';
import '../../../platform/windows_dpapi_credential_store.dart';
import '../../../platform/windows_shell_adapter.dart';

/// Consumer-first Model & Voice Library Folder selector + collapsible
/// fail-closed five-root diagnostics.
class SettingsStorageSection extends StatefulWidget {
  const SettingsStorageSection({
    super.key,
    required this.diagnosticReader,
    this.controller,
    this.client,
    this.clientSettings,
    this.credentialStore,
    this.shellAdapter,
  });

  final StorageDiagnosticReader diagnosticReader;
  final DesktopSettingsController? controller;
  final CompanionClient? client;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;
  final DesktopShellAdapter? shellAdapter;

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
  bool _advancedUserToggled = false;
  bool _advancedExpanded = false;
  String _lastLoadedLibraryRoot = '';
  String? _backendMessage;

  DesktopShellAdapter get _shell =>
      widget.shellAdapter ?? WindowsShellAdapter();

  @override
  void initState() {
    super.initState();
    _rootsFuture = widget.diagnosticReader.readDiagnosticRoots();
    if (widget.client == null) {
      _advancedExpanded = true;
    }
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

  String _formatError(Object e) => e is CompanionApiException ? e.message : '$e';

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
        if (_relocateController.text.isEmpty ||
            _relocateController.text == _lastLoadedLibraryRoot) {
          _relocateController.text = res.libraryRoot;
        }
        _lastLoadedLibraryRoot = res.libraryRoot;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBackend = false;
        _backendMessage = 'Storage service unavailable: ${_formatError(e)}';
      });
    }
  }

  Future<void> _pickLibraryFolder() async {
    final chosen = await _shell.pickFolder(
      title: 'Choose Folder for Your AI Models & Voices',
      initialDirectory: _relocateController.text.trim(),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(() {
      _relocateController.text = chosen;
      _backendMessage = 'Selected folder: $chosen. Click Move Library to apply.';
    });
  }

  Future<void> _relocateLibrary() async {
    final target = _relocateController.text.trim();
    if (target.isEmpty || _isRelocating) return;
    setState(() {
      _isRelocating = true;
      _backendMessage = 'Moving model & voice library...';
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
        _backendMessage = 'Model & Voice Library moved to ${updated.libraryRoot}';
        _rootsFuture = widget.diagnosticReader.readDiagnosticRoots();
      });
      widget.controller?.notifyStorageChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRelocating = false;
        _backendMessage = 'Could not move library: ${_formatError(e)}';
      });
    }
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    setState(() {
      _backendMessage = 'Copied folder path to clipboard.';
    });
  }

  Future<void> _openInExplorer(String path) async {
    await _shell.openFolder(path, createIfMissing: true);
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return 'Unknown';
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1.0) return '${gb.toStringAsFixed(1)} GB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  StorageRootOut? _findLibraryRoot(StorageRootsResponse? resp) {
    if (resp == null) return null;
    for (final root in resp.roots) {
      if (root.key == 'library') return root;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLibraryFolderCard(ext),
        const SizedBox(height: CompanionSpacing.lg),
        _buildAdvancedDiagnosticsAccordion(ext, isDark),
      ],
    );
  }

  Widget _buildLibraryFolderCard(CompanionThemeExtension? ext) {
    final backend = _backendRoots;
    final libRoot = _findLibraryRoot(backend);

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_copy_outlined, size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Model & Voice Library Folder',
                  style: CompanionTypography.titleMedium
                      .copyWith(color: ext?.textPrimary),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('storage_top_refresh_button'),
                onPressed: _isLoadingBackend ? null : _loadBackendStorage,
                icon: _isLoadingBackend
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Large local AI models and voice assets are stored here. App settings, chat history, cache, and logs stay automatically organized in your app folder.',
            style: CompanionTypography.bodySmall
                .copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.md),
          if (backend != null) ...[
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
                          'Current Library Location',
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (libRoot?.freeBytes != null)
                        Text(
                          '${_formatBytes(libRoot!.freeBytes)} free of ${_formatBytes(libRoot.totalBytes)}',
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    backend.libraryRoot,
                    style: CompanionTypography.bodySmall.copyWith(
                      color: ext?.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: CompanionSpacing.sm,
                    children: [
                      if (Platform.isWindows)
                        TextButton.icon(
                          onPressed: () => _openInExplorer(backend.libraryRoot),
                          icon: const Icon(Icons.folder_open_rounded, size: 14),
                          label: const Text('Open Folder'),
                        ),
                      TextButton.icon(
                        onPressed: () => _copyPath(backend.libraryRoot),
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy Path'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: CompanionSpacing.md),
            Text(
              'Move Models to Another Drive or Folder',
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: CompanionSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('relocate_library_root_input'),
                    controller: _relocateController,
                    enabled: backend.libraryRelocatable && !_isRelocating,
                    decoration: const InputDecoration(
                      labelText: 'Destination Folder',
                      hintText: r'Choose a folder on D:\ or another drive...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: CompanionSpacing.sm),
                OutlinedButton.icon(
                  key: const Key('choose_library_folder_button'),
                  onPressed: (!backend.libraryRelocatable || _isRelocating)
                      ? null
                      : _pickLibraryFolder,
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('Choose Folder...'),
                ),
              ],
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
                        'Copy existing models, voices & inbox files to the new folder',
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
                  label: const Text('Move Library'),
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
              'Runtime storage details appear automatically once connected, or expand Advanced Storage Diagnostics below to inspect local paths.',
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

  Widget _buildAdvancedDiagnosticsAccordion(
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    return FutureBuilder<List<StorageDiagnosticInfo>>(
      future: _rootsFuture,
      builder: (context, snapshot) {
        final roots = snapshot.data ?? [];
        final hasHealthIssue = roots.any(
          (r) =>
              r.locatorStatus == LocatorStatus.corrupt ||
              r.locatorStatus == LocatorStatus.validUnavailable,
        );
        final isExpanded = _advancedUserToggled
            ? _advancedExpanded
            : (_backendRoots == null || hasHealthIssue);
        final locatorInfo = roots.isNotEmpty ? roots.first : null;
        final backend = _backendRoots;

        return SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: const Key('storage_advanced_toggle'),
                borderRadius: CompanionRadius.borderMd,
                onTap: () {
                  setState(() {
                    _advancedUserToggled = true;
                    _advancedExpanded = !isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: ext?.textSecondary,
                      ),
                      const SizedBox(width: CompanionSpacing.sm),
                      Expanded(
                        child: Text(
                          'Advanced Storage & Developer Diagnostics',
                          style: CompanionTypography.bodyMedium.copyWith(
                            color: ext?.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: ext?.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: CompanionSpacing.md),
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
                          size: 18,
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
                const SizedBox(height: CompanionSpacing.sm),
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
                if (backend != null) ...[
                  Text(
                    'All Five Canonical Storage Roots (Host Telemetry)',
                    style: CompanionTypography.bodySmall.copyWith(
                      color: ext?.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: CompanionSpacing.sm),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
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
                                root.exists
                                    ? 'On Disk'
                                    : 'Created Lazily on First Use',
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
                                  icon: const Icon(
                                      Icons.folder_open_rounded,
                                      size: 14),
                                  label: const Text('Open Folder'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CompanionSpacing.sm),
                  ],
                ],
              ],
            ],
          ),
        );
      },
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
