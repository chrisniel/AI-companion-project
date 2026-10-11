import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../controllers/desktop_settings_controller.dart';
import '../coordinator/desktop_runtime_coordinator.dart';
import '../features/chat/desktop_chat_controller.dart';
import '../lifecycle/desktop_lifecycle_coordinator.dart';
import '../platform/desktop_client_settings.dart';
import '../platform/windows_dpapi_credential_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.coordinator,
    this.chatController,
    this.runtimeCoordinator,
    this.clientSettings,
    this.credentialStore,
    this.client,
  });

  final DesktopSettingsController controller;
  final DesktopLifecycleCoordinator? coordinator;
  final DesktopChatController? chatController;
  final DesktopRuntimeCoordinator? runtimeCoordinator;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;
  final CompanionClient? client;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _obscureToken = true;
  String? _testConnectionResult;
  bool _isTesting = false;

  DesktopSettingsController get controller => widget.controller;
  DesktopLifecycleCoordinator? get coordinator => widget.coordinator;
  DesktopClientSettings get _clientSettings => widget.clientSettings ?? DesktopClientSettings();
  CredentialStore get _credentialStore => widget.credentialStore ?? WindowsDpapiCredentialStore();

  List<ModelRegistryEntry>? _registryEntries;
  ModelStatusResponse? _modelStatus;
  bool _isLoadingModelCatalog = false;
  bool _isExecutingModelAction = false;
  String? _selectedModelId;
  String? _modelActionMessage;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _urlController = TextEditingController(
      text: const String.fromEnvironment('COMPANION_HOST_URL', defaultValue: 'http://127.0.0.1:8000'),
    );
    _tokenController = TextEditingController();

    _clientSettings.readHostUrl().then((saved) {
      if (mounted && saved.isNotEmpty) {
        setState(() {
          _urlController.text = saved;
        });
      }
    });

    try {
      _credentialStore.readToken().then((t) {
        if (mounted && t != null) {
          setState(() {
            _tokenController.text = t;
          });
        }
      });
    } catch (_) {}

    if (widget.controller.scrollToDiagnostics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            320,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    _loadModelData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      controller: _scrollController,
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

          // 2. Runtime Connection & Pairing Section
          _buildRuntimeConnectionCard(context, ext, isDark),
          const SizedBox(height: CompanionSpacing.lg),

          // 2B. Runtime Process Supervision Section
          _buildRuntimeSupervisionCard(context, ext, isDark),
          const SizedBox(height: CompanionSpacing.lg),

          // 2C. Local LLM Model Selection Section
          _buildModelSelectionCard(context, ext, isDark),
          const SizedBox(height: CompanionSpacing.lg),

          // 3. Storage Diagnostics Section
          _buildStorageDiagnosticsCard(context, ext, isDark),
          const SizedBox(height: CompanionSpacing.lg),

          // 4. Window & Tray Lifecycle Section
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
          NeumorphicSegmentedControl<ThemeMode>(
            selected: controller.themeMode,
            onChanged: (mode) => controller.setThemeMode(mode),
            segments: const [
              NeumorphicSegment(
                value: ThemeMode.system,
                label: 'System',
                icon: Icons.brightness_auto_rounded,
              ),
              NeumorphicSegment(
                value: ThemeMode.light,
                label: 'Light',
                icon: Icons.light_mode_rounded,
              ),
              NeumorphicSegment(
                value: ThemeMode.dark,
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
              ),
            ],
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
                child: NeumorphicSurface(
                  surfaceType: isSelected
                      ? NeumorphicSurfaceType.raised
                      : NeumorphicSurfaceType.flat,
                  outerShadows: isSelected
                      ? (isDark
                          ? CompanionShadows.darkNavEmbossed
                          : CompanionShadows.lightNavEmbossed)
                      : const [],
                  borderColor: isSelected
                      ? (isDark
                          ? CompanionColors.darkBorderHighlight
                          : CompanionColors.lightBorderHighlight)
                      : (ext?.borderSubtle ?? Colors.transparent),
                  borderRadius: CompanionRadius.borderMd,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                'Backend storage telemetry is not available in M1 standalone mode.',
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
                if (locatorInfo.resolvedPath != null) ...[
                  _buildDiagnosticItem(
                    ext: ext,
                    isDark: isDark,
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
                  isDark: isDark,
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
    );
  }

  String _labelForRootType(StorageRootType type, {bool isConfigured = false}) {
    switch (type) {
      case StorageRootType.appInstall:
        return 'Application Install (APP_INSTALL)';
      case StorageRootType.data:
        return isConfigured
            ? 'Configured Storage Root (DATA)'
            : 'Default Storage Root (DATA)';
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
    required bool isDark,
    required String label,
    required String? path,
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

    final displayPath = _sanitizePathForDisplay(path);

    return NeumorphicSurface(
      surfaceType: NeumorphicSurfaceType.recessed,
      borderRadius: CompanionRadius.borderMd,
      padding: const EdgeInsets.all(CompanionSpacing.md),
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

  Widget _buildRuntimeSupervisionCard(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final runtime = widget.controller.runtimeProcessState;
    final lockfile = widget.controller.runtimeLockfileData;

    final isLoopback = runtime?.isLocalSupervised ?? true;
    final modeLabel = isLoopback ? 'Local Loopback (Supervised)' : 'Remote Host (Unmanaged)';
    final statusLabel = runtime?.status.name ?? 'Dormant / Standalone';
    final pidLabel = !isLoopback
        ? 'N/A (Remote Host)'
        : (runtime?.pid != null
            ? '${runtime!.pid}'
            : (lockfile?.pid != null ? '${lockfile!.pid}' : 'None'));
    final portLabel = '${runtime?.port ?? 8000}';

    final localAppData = Platform.environment['LOCALAPPDATA'] ?? r'C:\Users\<user>\AppData\Local';
    final lockPath = !isLoopback ? 'N/A (Remote Host - Unmanaged)' : '$localAppData\\AI Companion\\runtime.lock';
    final logPath = !isLoopback ? 'N/A (Remote Host - Unmanaged)' : '$localAppData\\AI Companion\\Logs\\runtime.log';

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.developer_board_rounded, size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Text(
                'Runtime Process Supervision',
                style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Local process lifecycle, kernel file lock synchronization, and process provenance',
            style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.lg),
          NeumorphicSurface(
            surfaceType: NeumorphicSurfaceType.recessed,
            borderRadius: CompanionRadius.borderMd,
            padding: const EdgeInsets.all(CompanionSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDiagnosticRow('Supervision Mode', modeLabel, ext),
                const Divider(height: CompanionSpacing.md),
                _buildDiagnosticRow('Supervision Status', statusLabel, ext),
                const Divider(height: CompanionSpacing.md),
                _buildDiagnosticRow('Process ID (PID)', pidLabel, ext),
                const Divider(height: CompanionSpacing.md),
                _buildDiagnosticRow('Bound Port', portLabel, ext),
                const Divider(height: CompanionSpacing.md),
                _buildDiagnosticRow('Kernel Lockfile', lockPath, ext),
                const Divider(height: CompanionSpacing.md),
                _buildDiagnosticRow('Detached Logfile', logPath, ext),
              ],
            ),
          ),
          const SizedBox(height: CompanionSpacing.sm),
          Text(
            'Lifecycle Invariant: Closing or exiting the Flutter UI client leaves the detached background runtime process running.',
            style: CompanionTypography.caption.copyWith(
              color: ext?.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(String label, String value, CompanionThemeExtension? ext) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: CompanionTypography.bodySmall.copyWith(
            color: ext?.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRuntimeConnectionCard(
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
              Icon(Icons.link_rounded, size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Text(
                'Runtime Connection & Pairing',
                style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Configure Local AI Runtime endpoint URL and DPAPI-protected pairing secret',
            style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.lg),

          Text(
            'Runtime Host URL',
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: CompanionSpacing.xs),
          NeumorphicSurface(
            surfaceType: NeumorphicSurfaceType.recessed,
            borderRadius: CompanionRadius.borderMd,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _urlController,
              style: CompanionTypography.bodyMedium.copyWith(color: ext?.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'http://127.0.0.1:8000',
                hintStyle: CompanionTypography.bodyMedium.copyWith(color: ext?.textMuted),
              ),
            ),
          ),
          const SizedBox(height: CompanionSpacing.md),

          Text(
            'Pairing Token (Protected by Windows DPAPI)',
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: CompanionSpacing.xs),
          NeumorphicSurface(
            surfaceType: NeumorphicSurfaceType.recessed,
            borderRadius: CompanionRadius.borderMd,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tokenController,
                    obscureText: _obscureToken,
                    style: CompanionTypography.bodyMedium.copyWith(color: ext?.textPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Enter pairing token...',
                      hintStyle: CompanionTypography.bodyMedium.copyWith(color: ext?.textMuted),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18,
                    color: ext?.textSecondary,
                  ),
                  tooltip: _obscureToken ? 'Show token' : 'Hide token',
                  onPressed: () {
                    setState(() {
                      _obscureToken = !_obscureToken;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: CompanionSpacing.md),

          Wrap(
            spacing: CompanionSpacing.md,
            runSpacing: CompanionSpacing.sm,
            children: [
              NeumorphicButton(
                child: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                icon: const Icon(Icons.network_check_rounded, size: 16),
                size: NeumorphicButtonSize.sm,
                onPressed: _isTesting
                    ? null
                    : () async {
                        setState(() {
                          _isTesting = true;
                          _testConnectionResult = null;
                        });
                        final candidateUrl = _urlController.text.trim();
                        final candidateToken = _tokenController.text.trim();
                        try {
                          CompanionClient.validateBaseUrl(candidateUrl);
                          final probeStore = InMemoryCredentialStore(candidateToken);
                          final probeClient = CompanionClient(
                            baseUrl: candidateUrl,
                            credentialStore: probeStore,
                          );
                          final health = await probeClient.getHealth();
                          if (health.status == 'healthy') {
                            if (candidateToken.isEmpty) {
                              setState(() {
                                _testConnectionResult =
                                    'Reachable: Health OK (200), but pairing token is missing.';
                              });
                            } else {
                              try {
                                final auth = await probeClient.verifyAuth();
                                setState(() {
                                  _testConnectionResult =
                                      'Verified: Health OK (200), pairing token verified (${auth.tokenType}).';
                                });
                              } catch (authErr) {
                                setState(() {
                                  _testConnectionResult =
                                      'Reachable: Health OK (200), but authentication verification failed: $authErr';
                                });
                              }
                            }
                          } else {
                            setState(() {
                              _testConnectionResult = 'Runtime reported unhealthy status: ${health.status}';
                            });
                          }
                        } catch (e) {
                          setState(() {
                            _testConnectionResult = 'Connection failed: $e';
                          });
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isTesting = false;
                            });
                          }
                        }
                      },
              ),
              NeumorphicButton(
                child: const Text('Apply & Save'),
                icon: const Icon(Icons.save_rounded, size: 16),
                size: NeumorphicButtonSize.sm,
                onPressed: () async {
                  final candidateUrl = _urlController.text.trim();
                  final candidateToken = _tokenController.text.trim();
                  try {
                    CompanionClient.validateBaseUrl(candidateUrl);
                    await _clientSettings.writeHostUrl(candidateUrl);
                    if (candidateToken.isNotEmpty) {
                      await _credentialStore.writeToken(candidateToken);
                    }
                    if (widget.chatController != null) {
                      try {
                        await widget.chatController!.updateConfiguration(
                          baseUrl: candidateUrl,
                          pairingToken: candidateToken,
                        );
                      } catch (_) {}
                    }
                    if (widget.runtimeCoordinator != null) {
                      setState(() {
                        _testConnectionResult = 'Settings persisted. Verifying connection to runtime...';
                      });
                      widget.runtimeCoordinator!.updateConfiguration(
                        newBaseUrl: candidateUrl,
                        credentialStore: _credentialStore,
                      );
                      final runtimeState = await widget.runtimeCoordinator!.ensureRuntimeReady(
                        timeout: const Duration(seconds: 10),
                      );
                      if (mounted) {
                        setState(() {
                          switch (runtimeState.status) {
                            case RuntimeStatus.readyAndAuthenticated:
                              _testConnectionResult = 'Configuration saved: Connected and authenticated.';
                              break;
                            case RuntimeStatus.reachableUnauthenticated:
                              _testConnectionResult = 'Configuration saved: Connected, but authentication failed.';
                              break;
                            case RuntimeStatus.alienPortConflict:
                              _testConnectionResult = 'Configuration saved: Port conflict detected on ${runtimeState.port}.';
                              break;
                            default:
                              final diag = runtimeState.diagnosticMessage;
                              final suffix = (diag != null && diag.isNotEmpty) ? ': $diag' : '';
                              _testConnectionResult =
                                  'Configuration saved, but could not connect to runtime (${runtimeState.status.name})$suffix';
                              break;
                          }
                        });
                      }
                    } else {
                      if (mounted) {
                        setState(() {
                          _testConnectionResult = 'Configuration saved.';
                        });
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _testConnectionResult = 'Failed to apply configuration: $e';
                      });
                    }
                  }
                },
              ),
            ],
          ),

          if (_testConnectionResult != null) ...[
            const SizedBox(height: CompanionSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CompanionSpacing.md,
                vertical: CompanionSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                borderRadius: CompanionRadius.borderMd,
                border: Border.all(
                  color: ext?.borderSubtle ?? Colors.transparent,
                ),
              ),
              child: Text(
                _testConnectionResult!,
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  CompanionClient _resolveClient() {
    if (widget.client != null) {
      return widget.client!;
    }
    if (widget.chatController != null) {
      return widget.chatController!.client;
    }
    final rawUrl = _urlController.text.trim();
    final uri = CompanionClient.validateBaseUrl(rawUrl.isNotEmpty ? rawUrl : 'http://127.0.0.1:8000');
    return CompanionClient(
      baseUrl: uri.toString(),
      credentialStore: _credentialStore,
    );
  }

  Future<void> _loadModelData() async {
    if (_isLoadingModelCatalog) return;
    if (widget.client == null && Platform.environment.containsKey('FLUTTER_TEST')) {
      final savedModel = await _clientSettings.readSelectedModel();
      if (mounted) {
        setState(() {
          _selectedModelId = savedModel ?? _selectedModelId;
        });
      }
      return;
    }

    setState(() {
      _isLoadingModelCatalog = true;
      _modelActionMessage = null;
    });

    try {
      final client = _resolveClient();
      final results = await Future.wait([
        client.getModelRegistry().catchError((_) => <ModelRegistryEntry>[]),
        client.getModelStatus().catchError((_) => const ModelStatusResponse(provider: 'unknown')),
        _clientSettings.readSelectedModel(),
      ]);

      if (!mounted) return;
      setState(() {
        _registryEntries = results[0] as List<ModelRegistryEntry>;
        _modelStatus = results[1] as ModelStatusResponse;
        final savedModel = results[2] as String?;
        _selectedModelId = _modelStatus?.selectedModel ?? savedModel ?? _selectedModelId;
        _isLoadingModelCatalog = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingModelCatalog = false;
        _modelActionMessage = 'Failed to load model catalog: $e';
      });
    }
  }

  Future<void> _selectModel(String modelId, {bool loadImmediately = false}) async {
    if (_isExecutingModelAction) return;
    setState(() {
      _isExecutingModelAction = true;
      _modelActionMessage = loadImmediately ? 'Loading model into memory...' : 'Saving model selection...';
    });

    try {
      final client = _resolveClient();
      final updatedStatus = await client.selectModel(modelId, loadImmediately: loadImmediately);
      await _clientSettings.writeSelectedModel(modelId);
      if (!mounted) return;
      setState(() {
        _modelStatus = updatedStatus;
        _selectedModelId = modelId;
        _isExecutingModelAction = false;
        final isActivated = updatedStatus.runtimeState == 'MODEL_READY' &&
            (updatedStatus.activeModel == modelId ||
                _registryEntries?.any((e) => e.id == modelId && e.runtimeModelId == updatedStatus.activeModel) == true);
        if (loadImmediately) {
          _modelActionMessage = isActivated
              ? 'Model selected and loaded: ${updatedStatus.activeModel ?? modelId}'
              : 'Model selection saved (${updatedStatus.selectedModel ?? modelId}), but activation did not complete (${updatedStatus.runtimeState}). Model is NOT active.';
        } else {
          _modelActionMessage = 'Model selected: $modelId (not loaded into memory)';
        }
      });
    } catch (e) {
      if (!mounted) return;
      try {
        final client = _resolveClient();
        final refreshedStatus = await client.getModelStatus();
        if (mounted) {
          setState(() {
            _modelStatus = refreshedStatus;
            if (refreshedStatus.selectedModel != null) {
              _selectedModelId = refreshedStatus.selectedModel;
            }
          });
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isExecutingModelAction = false;
        _modelActionMessage = loadImmediately
            ? 'Model selection saved, but activation failed: $e. Model is NOT active.'
            : 'Model selection failed: $e';
      });
    }
  }

  Widget _buildModelSelectionCard(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final status = _modelStatus;
    final stateName = status?.runtimeState ?? 'UNKNOWN';

    Color stateColor;
    IconData stateIcon;
    String stateDescription;

    switch (stateName) {
      case 'MODEL_READY':
        stateColor = ext?.success ?? CompanionColors.success;
        stateIcon = Icons.check_circle_rounded;
        stateDescription = 'Ready (Active: ${status?.activeModel ?? "None"})';
        break;
      case 'MODEL_LOADING':
        stateColor = Colors.orange;
        stateIcon = Icons.sync_rounded;
        stateDescription = 'Loading weights into memory...';
        break;
      case 'MODEL_SELECTION_REQUIRED':
        stateColor = Colors.amber;
        stateIcon = Icons.warning_amber_rounded;
        stateDescription = 'Selection Required: Choose a model below';
        break;
      case 'MODEL_SLEEPING':
        stateColor = Colors.purple;
        stateIcon = Icons.bedtime_rounded;
        stateDescription = 'Sleeping (VRAM released)';
        break;
      case 'MODEL_ERROR':
      case 'SERVER_ERROR':
        stateColor = ext?.danger ?? CompanionColors.danger;
        stateIcon = Icons.error_outline_rounded;
        stateDescription = 'Error: ${status?.lastRuntimeError ?? "Failed to load model. Model is NOT active."}';
        break;
      case 'SERVER_STOPPED':
        stateColor = ext?.textMuted ?? Colors.grey;
        stateIcon = Icons.stop_circle_outlined;
        stateDescription = 'Server Stopped';
        break;
      default:
        stateColor = ext?.accent ?? Colors.blue;
        stateIcon = Icons.info_outline_rounded;
        stateDescription = 'Unloaded (Selected: ${status?.selectedModel ?? _selectedModelId ?? "None"})';
    }

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.memory_rounded, size: 20, color: ext?.accent),
                  const SizedBox(width: CompanionSpacing.sm),
                  Text(
                    'Local LLM Model Selection',
                    style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: _isLoadingModelCatalog
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Models',
                onPressed: _isLoadingModelCatalog ? null : _loadModelData,
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Dynamic model selection, verified capability badges, and persistent host configuration',
            style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.md),

          // Current Runtime Status Pill
          NeumorphicSurface(
            surfaceType: NeumorphicSurfaceType.recessed,
            borderRadius: CompanionRadius.borderMd,
            padding: const EdgeInsets.all(CompanionSpacing.md),
            child: Row(
              children: [
                Icon(stateIcon, size: 18, color: stateColor),
                const SizedBox(width: CompanionSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Runtime Status: $stateName',
                        style: CompanionTypography.bodySmall.copyWith(
                          color: stateColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        stateDescription,
                        style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (status?.appliedProfile != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: CompanionRadius.borderSm,
                    ),
                    child: Text(
                      'Profile: ${status!.appliedProfile}',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: CompanionSpacing.lg),

          // Model List Header
          Text(
            'Available Models in Registry',
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: CompanionSpacing.sm),

          if (_isLoadingModelCatalog && (_registryEntries == null || _registryEntries!.isEmpty))
            const Center(
              child: Padding(
                padding: EdgeInsets.all(CompanionSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_registryEntries == null || _registryEntries!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CompanionSpacing.md),
              child: Text(
                'No models registered. Check models directory or verify runtime connection.',
                style: CompanionTypography.bodySmall.copyWith(color: ext?.textMuted),
              ),
            )
          else
            ..._registryEntries!.map((entry) => _buildModelEntryCard(entry, ext, isDark)),

          if (_modelActionMessage != null) ...[
            const SizedBox(height: CompanionSpacing.md),
            Container(
              padding: const EdgeInsets.all(CompanionSpacing.sm),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                borderRadius: CompanionRadius.borderSm,
                border: Border.all(color: ext?.borderSubtle ?? Colors.transparent),
              ),
              child: Text(
                _modelActionMessage!,
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelEntryCard(
    ModelRegistryEntry entry,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final isSelected = (_selectedModelId == entry.id) ||
        (_selectedModelId == entry.runtimeModelId) ||
        (_modelStatus?.selectedModel == entry.id) ||
        (_modelStatus?.selectedModel == entry.runtimeModelId);
    final isReady = _modelStatus?.runtimeState == 'MODEL_READY' &&
        (_modelStatus?.activeModel == entry.id || _modelStatus?.activeModel == entry.runtimeModelId);

    return Container(
      margin: const EdgeInsets.only(bottom: CompanionSpacing.md),
      padding: const EdgeInsets.all(CompanionSpacing.md),
      decoration: BoxDecoration(
        color: isSelected
            ? (ext?.accent.withValues(alpha: isDark ? 0.12 : 0.06) ?? Colors.blue.withValues(alpha: 0.08))
            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(
          color: isSelected ? (ext?.accent ?? Colors.blue) : (ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.displayName,
                            style: CompanionTypography.bodyMedium.copyWith(
                              color: ext?.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isReady || isSelected) ...[
                          const SizedBox(width: CompanionSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isReady
                                  ? (ext?.success ?? CompanionColors.success)
                                  : (ext?.accent ?? Colors.blue),
                              borderRadius: CompanionRadius.borderSm,
                            ),
                            child: Text(
                              isReady ? 'ACTIVE' : 'SELECTED (NOT LOADED)',
                              style: CompanionTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${entry.id} | File: ${entry.primaryFile}',
                      style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.sm),

          // Badges: Capabilities & Validation Status
          Wrap(
            spacing: CompanionSpacing.xs,
            runSpacing: CompanionSpacing.xs,
            children: [
              // Chat capability badge
              _buildBadge(
                label: 'Text',
                icon: Icons.chat_bubble_outline_rounded,
                active: entry.hasChat,
                ext: ext,
              ),
              // Vision capability badge
              _buildBadge(
                label: 'Vision',
                icon: Icons.image_outlined,
                active: entry.hasVision,
                ext: ext,
              ),
              // Reasoning capability badge
              _buildBadge(
                label: 'Reasoning',
                icon: Icons.psychology_outlined,
                active: entry.hasReasoning,
                ext: ext,
              ),
              // Validation status badge
              _buildValidationBadge(entry, ext),
            ],
          ),
          const SizedBox(height: CompanionSpacing.sm),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _isExecutingModelAction
                    ? null
                    : () => _selectModel(entry.id, loadImmediately: false),
                icon: const Icon(Icons.bookmark_outline_rounded, size: 14),
                label: Text(isSelected ? 'Selected' : 'Select'),
              ),
              const SizedBox(width: CompanionSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: (_isExecutingModelAction || !entry.primaryFileExists)
                    ? null
                    : () => _selectModel(entry.id, loadImmediately: true),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(isReady ? 'Reload' : 'Load Model'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required IconData icon,
    required bool active,
    required CompanionThemeExtension? ext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? (ext?.accent.withValues(alpha: 0.15) ?? Colors.blue.withValues(alpha: 0.15))
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: CompanionRadius.borderSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: active ? (ext?.accent ?? Colors.blue) : (ext?.textMuted ?? Colors.grey),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: CompanionTypography.caption.copyWith(
              color: active ? (ext?.accent ?? Colors.blue) : (ext?.textMuted ?? Colors.grey),
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationBadge(ModelRegistryEntry entry, CompanionThemeExtension? ext) {
    Color color;
    String text;
    if (entry.isVerified) {
      color = ext?.success ?? CompanionColors.success;
      text = 'Verified';
    } else if (entry.validationStatus == 'missing_companion') {
      color = Colors.amber;
      text = 'Text-Only (Companion Missing)';
    } else if (!entry.primaryFileExists || entry.validationStatus == 'missing_primary') {
      color = ext?.danger ?? CompanionColors.danger;
      text = 'Missing GGUF';
    } else {
      color = ext?.danger ?? CompanionColors.danger;
      text = entry.validationStatus;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: CompanionRadius.borderSm,
      ),
      child: Text(
        text,
        style: CompanionTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
