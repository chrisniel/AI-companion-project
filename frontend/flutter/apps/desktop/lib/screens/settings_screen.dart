import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../controllers/desktop_settings_controller.dart';
import '../lifecycle/desktop_lifecycle_coordinator.dart';
import '../platform/windows_dpapi_credential_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.coordinator,
  });

  final DesktopSettingsController controller;
  final DesktopLifecycleCoordinator? coordinator;

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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _urlController = TextEditingController(
      text: const String.fromEnvironment('COMPANION_HOST_URL', defaultValue: 'http://127.0.0.1:8000'),
    );
    _tokenController = TextEditingController();

    try {
      WindowsDpapiCredentialStore().readToken().then((t) {
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
                child: const Text('Save Token'),
                icon: const Icon(Icons.security_rounded, size: 16),
                size: NeumorphicButtonSize.sm,
                onPressed: () async {
                  final token = _tokenController.text.trim();
                  try {
                    await WindowsDpapiCredentialStore().writeToken(token);
                    setState(() {
                      _testConnectionResult = 'Token saved securely via Windows DPAPI.';
                    });
                  } catch (e) {
                    setState(() {
                      _testConnectionResult = 'Failed to save token: $e';
                    });
                  }
                },
              ),
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
                        try {
                          final store = InMemoryCredentialStore(_tokenController.text.trim());
                          final client = CompanionClient(
                            baseUrl: _urlController.text.trim(),
                            credentialStore: store,
                          );
                          final health = await client.getHealth();
                          if (health.status == 'healthy') {
                            try {
                              final auth = await client.verifyAuth();
                              setState(() {
                                _testConnectionResult =
                                    'Connected: Health OK (${health.status}), Auth verified (${auth.tokenType}).';
                              });
                            } catch (authErr) {
                              setState(() {
                                _testConnectionResult =
                                    'Health OK (${health.status}), but auth verification failed: $authErr';
                              });
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
}
