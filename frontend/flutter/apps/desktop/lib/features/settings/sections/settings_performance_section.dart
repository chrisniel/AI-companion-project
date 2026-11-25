import 'dart:async';
import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../platform/desktop_client_settings.dart';
import '../../../platform/host_admin_secret_store.dart';
import '../../../platform/windows_dpapi_credential_store.dart';
import '../../../platform/windows_shell_adapter.dart';

/// Settings -> Performance & Gaming (`SettingsSectionId.health`, PC-RESOURCE-001..004).
class SettingsPerformanceSection extends StatefulWidget {
  const SettingsPerformanceSection({
    super.key,
    this.client,
    this.clientSettings,
    this.credentialStore,
    this.shellAdapter,
    this.externalStatus,
    this.onResourcePolicyChanged,
    this.isActiveTab = true,
    this.windowFocusedListenable,
    this.enableLivePolling,
    this.pollInterval = const Duration(milliseconds: 1500),
    this.activeTransitionPollInterval = const Duration(milliseconds: 1000),
    this.activationDebounce = const Duration(milliseconds: 200),
  });

  final CompanionClient? client;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;
  final DesktopShellAdapter? shellAdapter;
  final ValueListenable<ResourcePolicyStatusOut?>? externalStatus;
  final ValueChanged<ResourcePolicyStatusOut>? onResourcePolicyChanged;
  final bool isActiveTab;
  final ValueListenable<bool>? windowFocusedListenable;
  final bool? enableLivePolling;
  final Duration pollInterval;
  final Duration activeTransitionPollInterval;
  final Duration activationDebounce;

  @override
  State<SettingsPerformanceSection> createState() =>
      _SettingsPerformanceSectionState();
}

class _SettingsPerformanceSectionState extends State<SettingsPerformanceSection>
    with WidgetsBindingObserver {
  final TextEditingController _exeInputController = TextEditingController();
  final TextEditingController _cooldownController = TextEditingController();
  final FocusNode _cooldownFocusNode = FocusNode();

  ResourcePolicyStatusOut? _status;
  List<ModelRegistryEntry> _registryModels = const <ModelRegistryEntry>[];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPollingSilently = false;
  bool _windowFocused = true;
  bool _appResumed = true;
  Timer? _activationDebounceTimer;
  Timer? _nextPollTimer;
  String? _errorMessage;
  String? _statusMessage;

  DesktopShellAdapter get _shell =>
      widget.shellAdapter ?? WindowsShellAdapter();

  bool get _livePollingEnabled =>
      widget.enableLivePolling ??
      !Platform.environment.containsKey('FLUTTER_TEST');

  bool get _shouldLivePoll =>
      mounted &&
      _livePollingEnabled &&
      widget.isActiveTab &&
      _windowFocused &&
      _appResumed &&
      (widget.client != null ||
          !Platform.environment.containsKey('FLUTTER_TEST'));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = widget.externalStatus?.value;
    if (_status != null) {
      _cooldownController.text = '${_status!.cooldownSeconds}';
    } else {
      _cooldownController.text = '45';
    }
    _windowFocused = widget.windowFocusedListenable?.value ?? true;
    widget.externalStatus?.addListener(_handleExternalStatusChanged);
    widget.windowFocusedListenable?.addListener(_handleWindowFocusChanged);
    if (widget.client != null ||
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      _loadStatusAndRegistry();
    }
    _syncLivePolling();
  }

  @override
  void didUpdateWidget(covariant SettingsPerformanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalStatus != oldWidget.externalStatus) {
      oldWidget.externalStatus?.removeListener(_handleExternalStatusChanged);
      widget.externalStatus?.addListener(_handleExternalStatusChanged);
      _handleExternalStatusChanged();
    }
    if (widget.windowFocusedListenable != oldWidget.windowFocusedListenable) {
      oldWidget.windowFocusedListenable
          ?.removeListener(_handleWindowFocusChanged);
      widget.windowFocusedListenable?.addListener(_handleWindowFocusChanged);
      _windowFocused = widget.windowFocusedListenable?.value ?? true;
    }
    if (widget.client != oldWidget.client && widget.client != null) {
      _loadStatusAndRegistry();
    }
    if (widget.isActiveTab != oldWidget.isActiveTab ||
        widget.enableLivePolling != oldWidget.enableLivePolling ||
        widget.windowFocusedListenable != oldWidget.windowFocusedListenable ||
        widget.client != oldWidget.client) {
      _syncLivePolling();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextResumed = state == AppLifecycleState.resumed;
    if (_appResumed == nextResumed) return;
    _appResumed = nextResumed;
    _syncLivePolling();
  }

  @override
  void dispose() {
    _cancelPollingTimers();
    WidgetsBinding.instance.removeObserver(this);
    widget.externalStatus?.removeListener(_handleExternalStatusChanged);
    widget.windowFocusedListenable?.removeListener(_handleWindowFocusChanged);
    _exeInputController.dispose();
    _cooldownController.dispose();
    _cooldownFocusNode.dispose();
    super.dispose();
  }

  void _handleWindowFocusChanged() {
    final nextFocused = widget.windowFocusedListenable?.value ?? true;
    if (_windowFocused == nextFocused) return;
    _windowFocused = nextFocused;
    _syncLivePolling();
  }

  void _cancelPollingTimers() {
    _activationDebounceTimer?.cancel();
    _activationDebounceTimer = null;
    _nextPollTimer?.cancel();
    _nextPollTimer = null;
  }

  void _syncLivePolling() {
    if (!_shouldLivePoll) {
      _cancelPollingTimers();
      return;
    }
    if (_activationDebounceTimer != null ||
        _nextPollTimer != null ||
        _isPollingSilently) {
      return;
    }
    _activationDebounceTimer = Timer(widget.activationDebounce, () {
      _activationDebounceTimer = null;
      unawaited(_pollStatusSilently());
    });
  }

  void _scheduleNextPollTimer() {
    _nextPollTimer?.cancel();
    if (!_shouldLivePoll) {
      _nextPollTimer = null;
      return;
    }
    final status = _status;
    final activeTransition = status != null &&
        (status.cooldownRemainingSeconds > 0 ||
            status.transitionState != 'idle');
    final delay = activeTransition
        ? widget.activeTransitionPollInterval
        : widget.pollInterval;
    _nextPollTimer = Timer(delay, () {
      _nextPollTimer = null;
      unawaited(_pollStatusSilently());
    });
  }

  Future<void> _pollStatusSilently() async {
    if (!_shouldLivePoll) return;
    if (_isLoading || _isSaving || _isPollingSilently) {
      _scheduleNextPollTimer();
      return;
    }
    _isPollingSilently = true;
    CompanionClient? client;
    try {
      client = await _resolveClient();
      final status = await client.getResourcePolicy();
      if (!mounted) return;
      setState(() {
        _status = status;
        if (!_cooldownFocusNode.hasFocus) {
          _cooldownController.text = '${status.cooldownSeconds}';
        }
      });
      widget.onResourcePolicyChanged?.call(status);
    } catch (_) {
      // Silent background poll preserves prior telemetry without flashing transient errors.
    } finally {
      if (widget.client == null) {
        client?.close();
      }
      _isPollingSilently = false;
      if (_shouldLivePoll) {
        _scheduleNextPollTimer();
      }
    }
  }

  void _handleExternalStatusChanged() {
    final incoming = widget.externalStatus?.value;
    if (!mounted || incoming == null) return;
    setState(() {
      _status = incoming;
      if (!_cooldownFocusNode.hasFocus) {
        _cooldownController.text = '${incoming.cooldownSeconds}';
      }
    });
  }

  String _formatError(Object e) => e is CompanionApiException ? e.message : '$e';

  Future<CompanionClient> _resolveClient() async {
    if (widget.client != null) return widget.client!;
    final settings = widget.clientSettings ?? DesktopClientSettings();
    final url = await settings.readHostUrl();
    return CompanionClient(
      baseUrl: url.isNotEmpty ? url : 'http://127.0.0.1:8000',
      credentialStore:
          widget.credentialStore ?? WindowsDpapiCredentialStore(),
      hostAdminStore: HostAdminSecretStore(),
    );
  }

  Future<void> _loadStatusAndRegistry() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    CompanionClient? client;
    try {
      client = await _resolveClient();
      final status = await client.getResourcePolicy();
      List<ModelRegistryEntry> models = _registryModels;
      try {
        models = await client.getModelRegistry();
      } catch (_) {
        // Model registry read failure should not hide resource governance controls.
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _registryModels = models;
        if (!_cooldownFocusNode.hasFocus) {
          _cooldownController.text = '${status.cooldownSeconds}';
        }
        _isLoading = false;
      });
      widget.onResourcePolicyChanged?.call(status);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Resource service unavailable: ${_formatError(e)}';
      });
    } finally {
      if (widget.client == null) {
        client?.close();
      }
    }
  }

  Future<void> _applyUpdate(ResourcePolicyUpdateRequest request) async {
    if (_isSaving) return;
    if (widget.client == null &&
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    CompanionClient? client;
    try {
      client = await _resolveClient();
      final updated = await client.updateResourcePolicy(request);
      if (!mounted) return;
      setState(() {
        _status = updated;
        _cooldownController.text = '${updated.cooldownSeconds}';
        _isSaving = false;
        _statusMessage = 'Updated host performance policy.';
      });
      widget.onResourcePolicyChanged?.call(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = _formatError(e);
      });
    } finally {
      if (widget.client == null) {
        client?.close();
      }
    }
  }

  Future<void> _addExeName(String raw) async {
    final cleaned = raw.trim().toLowerCase();
    if (cleaned.isEmpty) return;
    final current = _status;
    if (current == null) return;
    if (!cleaned.endsWith('.exe') ||
        cleaned.contains('\\') ||
        cleaned.contains('/') ||
        cleaned.contains(':')) {
      setState(() {
        _errorMessage =
            'Enter a valid executable filename ending in .exe (e.g. eldenring.exe).';
      });
      return;
    }
    if (current.gameProcessList.contains(cleaned)) {
      _exeInputController.clear();
      return;
    }
    final nextList = <String>[...current.gameProcessList, cleaned];
    _exeInputController.clear();
    await _applyUpdate(ResourcePolicyUpdateRequest(gameProcessList: nextList));
  }

  Future<void> _browseExecutableFiles() async {
    final current = _status;
    if (current == null) return;
    final paths = await _shell.pickExecutableFiles(
      title: 'Select Game or App Executable (.exe)',
    );
    if (paths.isEmpty || !mounted) return;
    final merged = <String>[...current.gameProcessList];
    for (final rawPath in paths) {
      final base =
          rawPath.split(RegExp(r'[\\/]')).last.trim().toLowerCase();
      if (base.isNotEmpty && base.endsWith('.exe') && !merged.contains(base)) {
        merged.add(base);
      }
    }
    if (merged.length == current.gameProcessList.length) return;
    await _applyUpdate(ResourcePolicyUpdateRequest(gameProcessList: merged));
  }

  Future<void> _removeExeName(String exe) async {
    final current = _status;
    if (current == null) return;
    final nextList = current.gameProcessList
        .where((item) => item != exe)
        .toList(growable: false);
    await _applyUpdate(ResourcePolicyUpdateRequest(gameProcessList: nextList));
  }

  Future<void> _applyCooldown() async {
    final parsed = int.tryParse(_cooldownController.text.trim());
    if (parsed == null || parsed < 5 || parsed > 300) {
      setState(() {
        _errorMessage = 'Cooldown must be between 5 and 300 seconds.';
      });
      return;
    }
    await _applyUpdate(ResourcePolicyUpdateRequest(cooldownSeconds: parsed));
  }

  String _formatModeLabel(String mode) {
    switch (mode) {
      case 'low_impact':
        return 'Low-Impact';
      case 'auto':
        return 'Auto Gaming';
      default:
        return 'Normal';
    }
  }

  String _formatProfileLabel(String? profile) {
    if (profile == null || profile.isEmpty) return 'Stopped (Lazy)';
    switch (profile) {
      case 'eco':
        return 'Eco';
      case 'balanced':
        return 'Balanced';
      case 'maximum':
        return 'Maximum';
      default:
        return profile;
    }
  }

  String _formatTransitionStatus(ResourcePolicyStatusOut status) {
    if (status.transitionState == 'deferred_active_turn') {
      return 'Waiting for active reply before switching...';
    }
    if (status.transitionState == 'deferred_model_load') {
      return 'Waiting for model load before switching...';
    }
    if (status.transitionState == 'switching') {
      return 'Applying policy...';
    }
    if (status.lowImpactStrategy == 'lightweight_model' &&
        status.degradationReason == null &&
        (status.lowImpactModelId ?? '').isNotEmpty) {
      return 'Active: Lightweight Model (${status.lowImpactModelId})';
    }
    if (status.lowImpactStrategy == 'unload_when_idle') {
      return 'Active: Unload When Idle (60s)';
    }
    return 'Active: CPU Eco (0 GPU Layers)';
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final status = _status;

    if (status == null) {
      return SoftGlassPanel(
        padding: const EdgeInsets.all(CompanionSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, size: 20, color: ext?.accent),
                const SizedBox(width: CompanionSpacing.sm),
                Expanded(
                  child: Text(
                    'Performance & Gaming',
                    style: CompanionTypography.titleMedium
                        .copyWith(color: ext?.textPrimary),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('resource_refresh_button'),
                  onPressed: _isLoading ? null : _loadStatusAndRegistry,
                  icon: _isLoading
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
            const SizedBox(height: CompanionSpacing.sm),
            Text(
              _errorMessage ??
                  'Connect to the Local AI Runtime to configure Low-Impact mode, Auto Gaming detection, and inspect live host memory capacity.',
              style: CompanionTypography.bodySmall.copyWith(
                color: _errorMessage != null
                    ? (ext?.danger ?? CompanionColors.danger)
                    : ext?.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final installedChoices = _registryModels
        .where((m) => m.primaryFileExists)
        .toList(growable: false);
    final selectedLightweightId = installedChoices.any(
      (m) => m.id == status.lowImpactModelId || m.primaryFile == status.lowImpactModelId,
    )
        ? status.lowImpactModelId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(CompanionSpacing.md),
            decoration: BoxDecoration(
              color: (ext?.danger ?? CompanionColors.danger)
                  .withValues(alpha: 0.12),
              borderRadius: CompanionRadius.borderSm,
              border: Border.all(
                color: (ext?.danger ?? CompanionColors.danger)
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              _errorMessage!,
              style: CompanionTypography.bodySmall.copyWith(
                color: ext?.danger ?? CompanionColors.danger,
              ),
            ),
          ),
          const SizedBox(height: CompanionSpacing.md),
        ],
        if (_statusMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(CompanionSpacing.md),
            decoration: BoxDecoration(
              color: (ext?.accent ?? CompanionColors.lightAccent)
                  .withValues(alpha: 0.12),
              borderRadius: CompanionRadius.borderSm,
            ),
            child: Text(
              _statusMessage!,
              style:
                  CompanionTypography.bodySmall.copyWith(color: ext?.accent),
            ),
          ),
          const SizedBox(height: CompanionSpacing.md),
        ],

        // 1. Live Requested vs Applied Status & Host Capacity Card
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, size: 20, color: ext?.accent),
                  const SizedBox(width: CompanionSpacing.sm),
                  Expanded(
                    child: Text(
                      'Performance & Gaming',
                      style: CompanionTypography.titleMedium
                          .copyWith(color: ext?.textPrimary),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('resource_refresh_button'),
                    onPressed: _isLoading ? null : _loadStatusAndRegistry,
                    icon: _isLoading
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
                'Conserve GPU VRAM and CPU when gaming or multitasking. Local-only policy — cloud inference is never triggered automatically.',
                style: CompanionTypography.bodySmall
                    .copyWith(color: ext?.textSecondary),
              ),
              const SizedBox(height: CompanionSpacing.md),
              NeumorphicSurface(
                surfaceType: NeumorphicSurfaceType.recessed,
                borderRadius: CompanionRadius.borderMd,
                padding: const EdgeInsets.all(CompanionSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TelemetryRow(
                      label: 'Requested vs Effective Mode',
                      value: status.cooldownRemainingSeconds > 0
                          ? '${_formatModeLabel(status.requestedMode)} -> ${_formatModeLabel(status.effectiveMode)} (Cooldown ${status.cooldownRemainingSeconds}s)'
                          : '${_formatModeLabel(status.requestedMode)} -> ${_formatModeLabel(status.effectiveMode)}',
                      ext: ext,
                    ),
                    const SizedBox(height: 6),
                    _TelemetryRow(
                      label: 'Hardware Profile (Requested / Applied)',
                      value:
                          '${_formatProfileLabel(status.requestedProfile)} / ${_formatProfileLabel(status.appliedProfile)}',
                      ext: ext,
                    ),
                    const SizedBox(height: 6),
                    _TelemetryRow(
                      label: 'Host GPU / Dedicated VRAM',
                      value: (status.hostGpuName != null &&
                              status.hostVramGb != null)
                          ? '${status.hostGpuName} (${status.hostVramGb!.toStringAsFixed(1)} GiB)'
                          : 'Unavailable',
                      ext: ext,
                    ),
                    const SizedBox(height: 6),
                    _TelemetryRow(
                      label: 'Host System RAM (Available / Total)',
                      value: (status.availableRamGb != null &&
                              status.hostRamGb != null)
                          ? '${status.availableRamGb!.toStringAsFixed(1)} / ${status.hostRamGb!.toStringAsFixed(1)} GiB'
                          : 'Unavailable',
                      ext: ext,
                    ),
                    if (status.detectedActiveGames.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _TelemetryRow(
                        label: 'Detected Watched Games',
                        value: status.detectedActiveGames.join(', '),
                        ext: ext,
                      ),
                    ],
                    if (status.transitionState != 'idle' ||
                        status.lowImpactActive) ...[
                      const SizedBox(height: 6),
                      _TelemetryRow(
                        label: 'Transition / Override Status',
                        value: _formatTransitionStatus(status),
                        ext: ext,
                      ),
                    ],
                  ],
                ),
              ),
              if (status.degradationReason != null) ...[
                const SizedBox(height: CompanionSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(CompanionSpacing.sm),
                  decoration: BoxDecoration(
                    color: (ext?.warning ?? CompanionColors.warning)
                        .withValues(alpha: 0.14),
                    borderRadius: CompanionRadius.borderSm,
                  ),
                  child: Text(
                    'Fallback active (${status.degradationReason}): using CPU Eco until a lightweight GGUF model is installed.',
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.warning ?? CompanionColors.warning,
                    ),
                  ),
                ),
              ],
              if (status.deferredBackgroundWork) ...[
                const SizedBox(height: CompanionSpacing.sm),
                Text(
                  'Low-Impact active: background memory extraction and non-bypass routines are paused; critical alarms and reminders remain active.',
                  style: CompanionTypography.caption
                      .copyWith(color: ext?.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: CompanionSpacing.lg),

        // 2. Resource Mode & Low-Impact Strategy Selector
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resource Mode',
                style: CompanionTypography.titleSmall
                    .copyWith(color: ext?.textPrimary),
              ),
              const SizedBox(height: CompanionSpacing.sm),
              Wrap(
                spacing: CompanionSpacing.sm,
                runSpacing: CompanionSpacing.sm,
                children: [
                  ChoiceChip(
                    key: const Key('resource_mode_chip_normal'),
                    label: const Text('Normal'),
                    selected: status.requestedMode == 'normal',
                    onSelected: _isSaving
                        ? null
                        : (_) => _applyUpdate(
                              const ResourcePolicyUpdateRequest(
                                  resourceMode: 'normal'),
                            ),
                  ),
                  ChoiceChip(
                    key: const Key('resource_mode_chip_low_impact'),
                    label: const Text('Low-Impact'),
                    selected: status.requestedMode == 'low_impact',
                    onSelected: _isSaving
                        ? null
                        : (_) => _applyUpdate(
                              const ResourcePolicyUpdateRequest(
                                  resourceMode: 'low_impact'),
                            ),
                  ),
                  ChoiceChip(
                    key: const Key('resource_mode_chip_auto'),
                    label: const Text('Auto Gaming'),
                    selected: status.requestedMode == 'auto',
                    onSelected: _isSaving
                        ? null
                        : (_) => _applyUpdate(
                              const ResourcePolicyUpdateRequest(
                                  resourceMode: 'auto'),
                            ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.lg),
              Text(
                'Low-Impact Strategy',
                style: CompanionTypography.titleSmall
                    .copyWith(color: ext?.textPrimary),
              ),
              const SizedBox(height: CompanionSpacing.sm),
              Wrap(
                spacing: CompanionSpacing.sm,
                runSpacing: CompanionSpacing.sm,
                children: [
                  ChoiceChip(
                    key: const Key('resource_strategy_chip_cpu_eco'),
                    label: const Text('CPU Eco (0 GPU Layers)'),
                    selected: status.lowImpactStrategy == 'cpu_eco',
                    onSelected: _isSaving
                        ? null
                        : (_) => _applyUpdate(
                              const ResourcePolicyUpdateRequest(
                                lowImpactStrategy: 'cpu_eco',
                              ),
                            ),
                  ),
                  ChoiceChip(
                    key: const Key('resource_strategy_chip_unload_when_idle'),
                    label: const Text('Unload When Idle (60s)'),
                    selected: status.lowImpactStrategy == 'unload_when_idle',
                    onSelected: _isSaving
                        ? null
                        : (_) => _applyUpdate(
                              const ResourcePolicyUpdateRequest(
                                lowImpactStrategy: 'unload_when_idle',
                              ),
                            ),
                  ),
                  ChoiceChip(
                    key: const Key('resource_strategy_chip_lightweight_model'),
                    label: const Text('Lightweight Model'),
                    selected: status.lowImpactStrategy == 'lightweight_model',
                    onSelected: _isSaving
                        ? null
                        : (_) => _applyUpdate(
                              const ResourcePolicyUpdateRequest(
                                lowImpactStrategy: 'lightweight_model',
                              ),
                            ),
                  ),
                ],
              ),
              if (status.lowImpactStrategy == 'lightweight_model') ...[
                const SizedBox(height: CompanionSpacing.md),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Temporary Lightweight Model Override',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      key: const Key('resource_lightweight_model_dropdown'),
                      isExpanded: true,
                      value: selectedLightweightId,
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None (Degrade to CPU Eco)'),
                        ),
                        ...installedChoices.map(
                          (m) => DropdownMenuItem<String?>(
                            value: m.id,
                            child: Text(m.displayName),
                          ),
                        ),
                      ],
                      onChanged: _isSaving
                          ? null
                          : (val) {
                              if (val == null) {
                                _applyUpdate(
                                  const ResourcePolicyUpdateRequest(
                                    clearLowImpactModel: true,
                                  ),
                                );
                              } else {
                                _applyUpdate(
                                  ResourcePolicyUpdateRequest(
                                    lowImpactModelId: val,
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: CompanionSpacing.lg),

        // 3. Auto Gaming Process Watchlist & Hysteresis Cooldown
        SoftGlassPanel(
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto Gaming Watchlist & Cooldown',
                style: CompanionTypography.titleSmall
                    .copyWith(color: ext?.textPrimary),
              ),
              const SizedBox(height: CompanionSpacing.xs),
              Text(
                'When Auto Gaming is active, launching any listed .exe automatically engages Low-Impact mode and holds it through the post-exit cooldown.',
                style: CompanionTypography.bodySmall
                    .copyWith(color: ext?.textSecondary),
              ),
              const SizedBox(height: CompanionSpacing.md),
              if (status.gameProcessList.isEmpty)
                Text(
                  'No watched game executables added yet.',
                  style: CompanionTypography.caption
                      .copyWith(color: ext?.textMuted),
                )
              else
                Wrap(
                  spacing: CompanionSpacing.xs,
                  runSpacing: CompanionSpacing.xs,
                  children: status.gameProcessList.map((exe) {
                    final running =
                        status.detectedActiveGames.contains(exe);
                    return InputChip(
                      label: Text(running ? '$exe (Running)' : exe),
                      onDeleted:
                          _isSaving ? null : () => _removeExeName(exe),
                    );
                  }).toList(growable: false),
                ),
              const SizedBox(height: CompanionSpacing.md),
              Wrap(
                spacing: CompanionSpacing.sm,
                runSpacing: CompanionSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      key: const Key('resource_add_exe_input'),
                      controller: _exeInputController,
                      decoration: const InputDecoration(
                        labelText: 'Game executable',
                        hintText: 'eldenring.exe',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _isSaving ? null : _addExeName,
                    ),
                  ),
                  FilledButton.tonal(
                    key: const Key('resource_add_exe_button'),
                    onPressed: _isSaving
                        ? null
                        : () => _addExeName(_exeInputController.text),
                    child: const Text('Add .exe'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('resource_browse_exe_button'),
                    onPressed: _isSaving ? null : _browseExecutableFiles,
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Browse .exe...'),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.md),
              Wrap(
                spacing: CompanionSpacing.sm,
                runSpacing: CompanionSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    child: TextField(
                      key: const Key('resource_cooldown_input'),
                      controller: _cooldownController,
                      focusNode: _cooldownFocusNode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cooldown (5-300s)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted:
                          _isSaving ? null : (_) => _applyCooldown(),
                    ),
                  ),
                  OutlinedButton(
                    key: const Key('resource_cooldown_apply_button'),
                    onPressed: _isSaving ? null : _applyCooldown,
                    child: const Text('Apply Cooldown'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  const _TelemetryRow({
    required this.label,
    required this.value,
    required this.ext,
  });

  final String label;
  final String value;
  final CompanionThemeExtension? ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: CompanionTypography.caption
                .copyWith(color: ext?.textSecondary),
          ),
        ),
        const SizedBox(width: CompanionSpacing.sm),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
