import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../../../lifecycle/desktop_lifecycle_coordinator.dart';
import '../../../platform/desktop_client_settings.dart';
import '../../../platform/host_admin_secret_store.dart';
import '../../../platform/windows_dpapi_credential_store.dart';

/// General window bounds, system tray status, and standard-user startup lifecycle section.
class SettingsGeneralSection extends StatefulWidget {
  const SettingsGeneralSection({
    super.key,
    this.coordinator,
    this.client,
    this.clientSettings,
    this.credentialStore,
  });

  final DesktopLifecycleCoordinator? coordinator;
  final CompanionClient? client;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;

  @override
  State<SettingsGeneralSection> createState() => _SettingsGeneralSectionState();
}

class _SettingsGeneralSectionState extends State<SettingsGeneralSection> {
  AutostartStatusOut? _autostartStatus;
  bool _isLoadingAutostart = false;
  bool _isUpdatingAutostart = false;
  String? _autostartMessage;

  @override
  void initState() {
    super.initState();
    if (widget.client != null ||
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      _loadAutostartStatus();
    }
  }

  @override
  void didUpdateWidget(covariant SettingsGeneralSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.client != oldWidget.client && widget.client != null) {
      _loadAutostartStatus();
    }
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

  Future<void> _loadAutostartStatus() async {
    if (_isLoadingAutostart) return;
    setState(() {
      _isLoadingAutostart = true;
    });
    try {
      final client = await _resolveClient();
      final status = await client.getAutostartStatus();
      if (!mounted) return;
      setState(() {
        _autostartStatus = status;
        _isLoadingAutostart = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAutostart = false;
        _autostartMessage = 'Unable to query autostart status: $e';
      });
    }
  }

  Future<void> _updateAutostart({
    required bool enabled,
    required bool minimizedToTray,
  }) async {
    if (_isUpdatingAutostart) return;
    setState(() {
      _isUpdatingAutostart = true;
      _autostartMessage = 'Updating Windows Task Scheduler entry...';
    });
    try {
      final client = await _resolveClient();
      final updated = await client.updateAutostart(
        AutostartUpdateRequest(
          enabled: enabled,
          minimizedToTray: minimizedToTray,
        ),
      );
      if (!mounted) return;
      setState(() {
        _autostartStatus = updated;
        _isUpdatingAutostart = false;
        _autostartMessage = updated.statusDetail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingAutostart = false;
        _autostartMessage = 'Failed to update autostart: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isTrayAvailable = widget.coordinator?.isTrayAvailable ?? false;
    final autostart = _autostartStatus;
    final supported = autostart?.supported ?? Platform.isWindows;
    final enabled = autostart?.enabled ?? false;
    final minimized = autostart?.minimizedToTray ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.desktop_windows_outlined, size: 20, color: ext?.accent),
                  const SizedBox(width: CompanionSpacing.sm),
                  Expanded(
                    child: Text(
                      'Window & Tray Lifecycle',
                      style: CompanionTypography.titleMedium
                          .copyWith(color: ext?.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.md),
              Text(
                'Window Constraints: 1280x800 (1024x640 min)',
                style: CompanionTypography.bodySmall
                    .copyWith(color: ext?.textSecondary),
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                isTrayAvailable
                    ? 'System Tray: Active (Close-to-Tray Active)'
                    : 'System Tray: Unavailable (Close Exits App)',
                style: CompanionTypography.bodySmall.copyWith(
                  color: isTrayAvailable
                      ? (ext?.success ?? CompanionColors.success)
                      : ext?.textSecondary,
                ),
              ),
              const SizedBox(height: CompanionSpacing.lg),
              NeumorphicSurface(
                surfaceType: NeumorphicSurfaceType.recessed,
                borderRadius: CompanionRadius.borderMd,
                padding: const EdgeInsets.all(CompanionSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 18,
                      color: ext?.accent,
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    Expanded(
                      child: Text(
                        'Quick Tray & Exit Actions: Use the power button in the bottom-left navigation rail or the Windows System Tray menu to minimize to tray or shut down AI Companion from any screen.',
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CompanionSpacing.lg),
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch_outlined, size: 18, color: ext?.accent),
                  const SizedBox(width: CompanionSpacing.sm),
                  Expanded(
                    child: Text(
                      'Windows Startup & Autostart',
                      style: CompanionTypography.bodyMedium.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (enabled
                              ? (ext?.success ?? CompanionColors.success)
                              : ext?.accent ?? Colors.blue)
                          .withValues(alpha: 0.14),
                      borderRadius: CompanionRadius.borderSm,
                    ),
                    child: Text(
                      enabled ? 'ACTIVE (LEAST PRIVILEGE)' : 'PC-HOST-002',
                      style: CompanionTypography.caption.copyWith(
                        color: enabled
                            ? (ext?.success ?? CompanionColors.success)
                            : ext?.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                'Registers a standard-user Task Scheduler logon trigger (no UAC prompt). Explicit Exit Companion stays stopped.',
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textSecondary,
                ),
              ),
              const SizedBox(height: CompanionSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Launch AI Companion at Windows Login',
                      style: CompanionTypography.bodySmall.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    key: const Key('autostart_enabled_switch'),
                    value: enabled,
                    onChanged: (!supported || _isUpdatingAutostart)
                        ? null
                        : (v) => _updateAutostart(
                              enabled: v,
                              minimizedToTray: minimized,
                            ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Start Minimized to System Tray (--minimized-to-tray)',
                      style: CompanionTypography.bodySmall.copyWith(
                        color: ext?.textSecondary,
                      ),
                    ),
                  ),
                  Switch(
                    key: const Key('autostart_minimized_switch'),
                    value: minimized,
                    onChanged: (!supported || _isUpdatingAutostart || !enabled)
                        ? null
                        : (v) => _updateAutostart(
                              enabled: enabled,
                              minimizedToTray: v,
                            ),
                  ),
                ],
              ),
              if (autostart?.command != null) ...[
                const SizedBox(height: CompanionSpacing.xs),
                SelectableText(
                  'Command: ${autostart!.command}',
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              if (_autostartMessage != null) ...[
                const SizedBox(height: CompanionSpacing.xs),
                Text(
                  _autostartMessage!,
                  style: CompanionTypography.caption
                      .copyWith(color: ext?.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
