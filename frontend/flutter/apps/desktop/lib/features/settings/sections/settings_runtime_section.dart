import 'dart:async';
import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../controllers/desktop_settings_controller.dart';
import '../../../coordinator/desktop_runtime_coordinator.dart';
import '../../../platform/desktop_client_settings.dart';
import '../../../platform/host_admin_secret_store.dart';
import '../../../platform/windows_dpapi_credential_store.dart';
import '../../chat/desktop_chat_controller.dart';
import '../settings_section.dart';

/// Settings category section for Local AI Runtime connection, DPAPI pairing,
/// Windows process supervision diagnostics, and local LLM model selection.
class SettingsRuntimeSection extends StatefulWidget {
  const SettingsRuntimeSection({
    super.key,
    required this.controller,
    this.chatController,
    this.runtimeCoordinator,
    this.clientSettings,
    this.credentialStore,
    this.client,
  });

  final DesktopSettingsController controller;
  final DesktopChatController? chatController;
  final DesktopRuntimeCoordinator? runtimeCoordinator;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;
  final CompanionClient? client;

  @override
  State<SettingsRuntimeSection> createState() => _SettingsRuntimeSectionState();
}

class _SettingsRuntimeSectionState extends State<SettingsRuntimeSection> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _obscureToken = true;
  bool _urlDirty = false;
  bool _tokenDirty = false;
  String? _testConnectionResult;
  bool _isTesting = false;

  DesktopClientSettings get _clientSettings =>
      widget.clientSettings ?? DesktopClientSettings();
  CredentialStore get _credentialStore =>
      widget.credentialStore ?? WindowsDpapiCredentialStore();

  List<ModelRegistryEntry>? _registryEntries;
  ModelStatusResponse? _modelStatus;
  bool _isLoadingModelCatalog = false;
  bool _isExecutingModelAction = false;
  bool _isStillLoading = false;
  String? _selectedModelId;
  String? _modelActionMessage;
  bool _isUpdatingProfile = false;
  bool _isScanningInbox = false;
  String? _installingRelativePath;
  String? _deletingModelId;
  String? _importInboxDir;
  ModelImportScanOut? _inboxScanResult;
  final Map<String, TextEditingController> _candidateNameControllers = {};
  DesktopNavDestination _lastDestination = DesktopNavDestination.chat;
  SettingsSectionId _lastSection = SettingsSectionId.appearance;

  void _handleControllerChange() {
    final dest = widget.controller.currentDestination;
    final section = widget.controller.selectedSettingsSection;
    final enteredSettings = dest == DesktopNavDestination.settings &&
        _lastDestination != DesktopNavDestination.settings;
    final enteredRuntimeSection =
        section == SettingsSectionId.runtime &&
        _lastSection != SettingsSectionId.runtime;
    if (enteredSettings || enteredRuntimeSection) {
      _loadModelData();
    }
    _lastDestination = dest;
    _lastSection = section;
  }

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: const String.fromEnvironment(
        'COMPANION_HOST_URL',
        defaultValue: 'http://127.0.0.1:8000',
      ),
    );
    _tokenController = TextEditingController();
    _lastDestination = widget.controller.currentDestination;
    _lastSection = widget.controller.selectedSettingsSection;

    _clientSettings.readHostUrl().then((saved) {
      if (mounted && !_urlDirty && saved.isNotEmpty) {
        setState(() {
          _urlController.text = saved;
        });
      }
    });

    try {
      _credentialStore.readToken().then((t) {
        if (mounted && !_tokenDirty && t != null) {
          setState(() {
            _tokenController.text = t;
          });
        }
      });
    } catch (_) {}

    widget.controller.addListener(_handleControllerChange);
    _loadModelData();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _urlController.dispose();
    _tokenController.dispose();
    for (final c in _candidateNameControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRuntimeConnectionCard(context, ext, isDark),
        const SizedBox(height: CompanionSpacing.lg),
        _buildRuntimeSupervisionCard(context, ext, isDark),
        const SizedBox(height: CompanionSpacing.lg),
        _buildModelSelectionCard(context, ext, isDark),
        const SizedBox(height: CompanionSpacing.lg),
        _buildD6ImportInboxCard(context, ext, isDark),
      ],
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
    final modeLabel =
        isLoopback ? 'Local Loopback (Supervised)' : 'Remote Host (Unmanaged)';
    final statusLabel = runtime?.status.name ?? 'Dormant / Standalone';
    final pidLabel = !isLoopback
        ? 'N/A (Remote Host)'
        : (runtime?.pid != null
            ? '${runtime!.pid}'
            : (lockfile?.pid != null ? '${lockfile!.pid}' : 'None'));
    final portLabel = '${runtime?.port ?? 8000}';

    final localAppData =
        Platform.environment['LOCALAPPDATA'] ?? r'C:\Users\<user>\AppData\Local';
    final lockPath = !isLoopback
        ? 'N/A (Remote Host - Unmanaged)'
        : '$localAppData\\AI Companion\\runtime.lock';
    final logPath = !isLoopback
        ? 'N/A (Remote Host - Unmanaged)'
        : '$localAppData\\AI Companion\\Logs\\runtime.log';

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.developer_board_rounded, size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Runtime Process Supervision',
                  style: CompanionTypography.titleMedium
                      .copyWith(color: ext?.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Local process lifecycle, kernel file lock synchronization, and process provenance',
            style: CompanionTypography.caption
                .copyWith(color: ext?.textSecondary),
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
            'Lifecycle Invariant: Closing the window (×) hides to system tray and leaves the background runtime running. Exiting Companion performs authenticated cooperative shutdown of the host runtime.',
            style: CompanionTypography.caption.copyWith(
              color: ext?.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(
    String label,
    String value,
    CompanionThemeExtension? ext,
  ) {
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
              Expanded(
                child: Text(
                  'Runtime Connection & Pairing',
                  style: CompanionTypography.titleMedium
                      .copyWith(color: ext?.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Configure Local AI Runtime endpoint URL and DPAPI-protected pairing secret',
            style: CompanionTypography.caption
                .copyWith(color: ext?.textSecondary),
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
              key: const Key('runtime_host_url_input'),
              controller: _urlController,
              onChanged: (_) => _urlDirty = true,
              style: CompanionTypography.bodyMedium
                  .copyWith(color: ext?.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'http://127.0.0.1:8000',
                hintStyle:
                    CompanionTypography.bodyMedium.copyWith(color: ext?.textMuted),
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
                    key: const Key('runtime_pairing_token_input'),
                    controller: _tokenController,
                    onChanged: (_) => _tokenDirty = true,
                    obscureText: _obscureToken,
                    style: CompanionTypography.bodyMedium
                        .copyWith(color: ext?.textPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Enter pairing token...',
                      hintStyle: CompanionTypography.bodyMedium
                          .copyWith(color: ext?.textMuted),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _obscureToken
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
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
                          final probeStore =
                              InMemoryCredentialStore(candidateToken);
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
                              _testConnectionResult =
                                  'Runtime reported unhealthy status: ${health.status}';
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
                        _testConnectionResult =
                            'Settings persisted. Verifying connection to runtime...';
                      });
                      widget.runtimeCoordinator!.updateConfiguration(
                        newBaseUrl: candidateUrl,
                        credentialStore: _credentialStore,
                      );
                      final runtimeState =
                          await widget.runtimeCoordinator!.ensureRuntimeReady(
                        timeout: const Duration(seconds: 10),
                      );
                      if (mounted) {
                        setState(() {
                          switch (runtimeState.status) {
                            case RuntimeStatus.readyAndAuthenticated:
                              _testConnectionResult =
                                  'Configuration saved: Connected and authenticated.';
                              break;
                            case RuntimeStatus.reachableUnauthenticated:
                              _testConnectionResult =
                                  'Configuration saved: Connected, but authentication failed.';
                              break;
                            case RuntimeStatus.alienPortConflict:
                              _testConnectionResult =
                                  'Configuration saved: Port conflict detected on ${runtimeState.port}.';
                              break;
                            default:
                              final diag = runtimeState.diagnosticMessage;
                              final suffix = (diag != null && diag.isNotEmpty)
                                  ? ': $diag'
                                  : '';
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
                        _testConnectionResult =
                            'Failed to apply configuration: $e';
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
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
    final uri = CompanionClient.validateBaseUrl(
      rawUrl.isNotEmpty ? rawUrl : 'http://127.0.0.1:8000',
    );
    return CompanionClient(
      baseUrl: uri.toString(),
      credentialStore: _credentialStore,
      hostAdminStore: HostAdminSecretStore(),
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
      if (!_tokenDirty && _tokenController.text.isEmpty) {
        try {
          final t = await _credentialStore.readToken();
          if (mounted &&
              !_tokenDirty &&
              t != null &&
              _tokenController.text.isEmpty) {
            _tokenController.text = t;
          }
        } catch (_) {}
      }
      final client = _resolveClient();
      final results = await Future.wait([
        client.getModelRegistry().catchError((_) => <ModelRegistryEntry>[]),
        client
            .getModelStatus()
            .catchError((_) => const ModelStatusResponse(provider: 'unknown')),
        _clientSettings.readSelectedModel(),
        client
            .getStorageRoots()
            .then<StorageRootsResponse?>((v) => v)
            .catchError((_) => null),
      ]);

      if (!mounted) return;
      final storageResp = results[3] as StorageRootsResponse?;
      setState(() {
        _registryEntries = results[0] as List<ModelRegistryEntry>;
        _modelStatus = results[1] as ModelStatusResponse;
        final savedModel = results[2] as String?;
        _selectedModelId =
            _modelStatus?.selectedModel ?? savedModel ?? _selectedModelId;
        if (storageResp != null && storageResp.importInboxDir.isNotEmpty) {
          _importInboxDir = storageResp.importInboxDir;
        }
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

  bool _isTargetModelActive(ModelRegistryEntry? entry, String? activeModel) {
    if (entry == null || activeModel == null || activeModel.isEmpty) {
      return false;
    }
    if (activeModel == entry.id || activeModel == entry.runtimeModelId) {
      return true;
    }
    if (entry.primaryFile.isNotEmpty) {
      if (activeModel == entry.primaryFile) return true;
      final normActive = activeModel.replaceAll('\\', '/');
      final normPrimary = entry.primaryFile.replaceAll('\\', '/');
      if (normActive.endsWith(normPrimary)) return true;
    }
    return false;
  }

  Future<void> _selectModel(
    String modelId, {
    bool loadImmediately = false,
  }) async {
    if (_isExecutingModelAction || _isStillLoading) return;
    setState(() {
      _isExecutingModelAction = true;
      _modelActionMessage = loadImmediately
          ? 'Loading model into memory...'
          : 'Saving model selection...';
    });

    try {
      final client = _resolveClient();
      final updatedStatus = await client.selectModel(
        modelId,
        loadImmediately: loadImmediately,
      );
      if (!mounted) return;

      final targetEntry = _registryEntries?.firstWhere(
        (e) => e.id == modelId || e.runtimeModelId == modelId,
        orElse: () => ModelRegistryEntry(
          id: modelId,
          displayName: modelId,
          capabilities: const [],
          availableCapabilities: const [],
          primaryFile: '',
          primaryFileExists: false,
          validationStatus: 'unknown',
        ),
      );

      final isActivated = updatedStatus.runtimeState == 'MODEL_READY' &&
          _isTargetModelActive(targetEntry, updatedStatus.activeModel);

      if (loadImmediately &&
          !isActivated &&
          (updatedStatus.runtimeState == 'MODEL_LOADING' ||
              updatedStatus.runtimeState == 'SERVER_STARTING')) {
        _modelStatus = updatedStatus;
        _selectedModelId = modelId;
        _isExecutingModelAction = false;
        _isStillLoading = true;
        _modelActionMessage = 'Model is still loading in the background...';
        setState(() {});

        unawaited(_clientSettings.writeSelectedModel(modelId));
        unawaited(_pollModelStatusUntilReady(modelId, targetEntry));
        return;
      }

      await _clientSettings.writeSelectedModel(modelId);
      if (!mounted) return;

      setState(() {
        _modelStatus = updatedStatus;
        _selectedModelId = modelId;
        _isExecutingModelAction = false;
        _isStillLoading = false;
        if (loadImmediately) {
          _modelActionMessage = isActivated
              ? 'Model selected and loaded: ${updatedStatus.activeModel ?? modelId}'
              : 'Model selection saved (${updatedStatus.selectedModel ?? modelId}), but activation did not complete (${updatedStatus.runtimeState}). Model is NOT active.';
        } else {
          _modelActionMessage =
              'Model selected: $modelId (not loaded into memory)';
        }
      });
      if (isActivated && widget.chatController != null) {
        widget.chatController!.updateModelStatus(updatedStatus);
      }
    } on TimeoutException {
      if (!mounted) return;
      final targetEntry = _registryEntries?.firstWhere(
        (e) => e.id == modelId || e.runtimeModelId == modelId,
        orElse: () => ModelRegistryEntry(
          id: modelId,
          displayName: modelId,
          capabilities: const [],
          availableCapabilities: const [],
          primaryFile: '',
          primaryFileExists: false,
          validationStatus: 'unknown',
        ),
      );
      setState(() {
        _isExecutingModelAction = false;
        _isStillLoading = true;
        _modelActionMessage = 'Model is still loading in the background...';
      });
      await _pollModelStatusUntilReady(modelId, targetEntry);
    } catch (e) {
      if (!mounted) return;
      try {
        final client = _resolveClient();
        final refreshedStatus = await client.getModelStatus();
        if (mounted) {
          final targetEntry = _registryEntries?.firstWhere(
            (e) => e.id == modelId || e.runtimeModelId == modelId,
            orElse: () => ModelRegistryEntry(
              id: modelId,
              displayName: modelId,
              capabilities: const [],
              availableCapabilities: const [],
              primaryFile: '',
              primaryFileExists: false,
              validationStatus: 'unknown',
            ),
          );
          if (refreshedStatus.runtimeState == 'MODEL_LOADING' ||
              refreshedStatus.runtimeState == 'SERVER_STARTING') {
            setState(() {
              _modelStatus = refreshedStatus;
              _isExecutingModelAction = false;
              _isStillLoading = true;
              _modelActionMessage = 'Model is still loading in the background...';
            });
            await _pollModelStatusUntilReady(modelId, targetEntry);
            return;
          }
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
        _isStillLoading = false;
        _modelActionMessage = loadImmediately
            ? 'Model selection saved, but activation failed: $e. Model is NOT active.'
            : 'Model selection failed: $e';
      });
    }
  }

  Future<void> _pollModelStatusUntilReady(
    String modelId,
    ModelRegistryEntry? targetEntry,
  ) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    final client = _resolveClient();
    final stopwatch = Stopwatch()..start();
    const pollTimeout = Duration(seconds: 60);

    while (stopwatch.elapsed < pollTimeout) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || !_isStillLoading) return;

      try {
        final status = await client.getModelStatus();
        if (!mounted) return;

        if (status.runtimeState == 'MODEL_READY') {
          final isActivated =
              _isTargetModelActive(targetEntry, status.activeModel);
          setState(() {
            _modelStatus = status;
            _isStillLoading = false;
            _modelActionMessage = isActivated
                ? 'Model selected and loaded: ${status.activeModel ?? modelId}'
                : 'Model is ready: ${status.activeModel}';
          });
          widget.chatController?.updateModelStatus(status);
          return;
        }

        if (status.runtimeState == 'MODEL_ERROR' ||
            status.runtimeState == 'SERVER_ERROR' ||
            status.runtimeState == 'LOAD_FAILED') {
          setState(() {
            _modelStatus = status;
            _isStillLoading = false;
            _modelActionMessage =
                'Model load failed: ${status.lastRuntimeError ?? status.runtimeState}';
          });
          return;
        }

        setState(() {
          _modelStatus = status;
        });
      } on TimeoutException {
        if (!mounted) return;
        setState(() {
          _isStillLoading = false;
          _modelActionMessage =
              'Model load status could not be confirmed: status check timed out.';
        });
        return;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _isStillLoading = false;
      _modelActionMessage =
          'Model is still loading in the background. Click Refresh Model Status to re-check.';
    });
  }

  Future<void> _refreshModelStatusOnly() async {
    try {
      final client = _resolveClient();
      final fresh = await client.getModelStatus();
      if (!mounted) return;
      setState(() {
        _modelStatus = fresh;
        if (fresh.runtimeState == 'MODEL_READY') {
          _isStillLoading = false;
          _modelActionMessage = 'Model is ready: ${fresh.activeModel}';
        } else if (fresh.runtimeState == 'MODEL_LOADING' ||
            fresh.runtimeState == 'SERVER_STARTING') {
          _isStillLoading = true;
          _modelActionMessage = 'Model is still loading in the background...';
        } else {
          _isStillLoading = false;
          _modelActionMessage =
              'Current model runtime state: ${fresh.runtimeState}';
        }
      });
      widget.chatController?.updateModelStatus(fresh);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _modelActionMessage = 'Model load status could not be confirmed: $e';
      });
    }
  }

  Future<void> _unloadModel() async {
    if (_isExecutingModelAction) return;
    if (widget.chatController?.isGenerating == true) {
      setState(() {
        _modelActionMessage =
            'Cannot unload model while turn generation is active.';
      });
      return;
    }

    setState(() {
      _isExecutingModelAction = true;
      _modelActionMessage = 'Unloading model...';
    });

    try {
      final client = _resolveClient();
      final updatedStatus = await client.unloadModel();
      if (!mounted) return;
      if (updatedStatus.modelLoaded) {
        setState(() {
          _modelStatus = updatedStatus;
          _isExecutingModelAction = false;
          _modelActionMessage =
              'Model unload refused or incomplete: model remains loaded.';
        });
      } else {
        setState(() {
          _modelStatus = updatedStatus;
          _isExecutingModelAction = false;
          _modelActionMessage = 'Model unloaded successfully.';
        });
      }
      if (widget.chatController != null) {
        try {
          await widget.chatController!.checkConnection();
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExecutingModelAction = false;
        _modelActionMessage = 'Failed to unload model: $e';
      });
    }
  }

  Future<void> _updateHardwareProfile(String profile) async {
    if (_isUpdatingProfile || _isExecutingModelAction) return;
    setState(() {
      _isUpdatingProfile = true;
      _modelActionMessage = 'Updating hardware profile to ${profile.toUpperCase()}...';
    });
    try {
      final client = _resolveClient();
      final updatedStatus = await client.updateModelProfile(profile);
      if (!mounted) return;
      setState(() {
        _modelStatus = updatedStatus;
        _isUpdatingProfile = false;
        _modelActionMessage =
            'Hardware profile set to ${updatedStatus.requestedProfile.toUpperCase()}. '
            '${updatedStatus.routerRunning ? 'Applies on next model reload.' : 'Ready for next load.'}';
      });
      widget.chatController?.updateModelStatus(updatedStatus);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingProfile = false;
        _modelActionMessage = 'Failed to update hardware profile: $e';
      });
    }
  }

  Future<void> _scanInbox() async {
    if (_isScanningInbox) return;
    setState(() {
      _isScanningInbox = true;
      _modelActionMessage = 'Scanning Decision D6 model import inbox...';
    });
    try {
      final client = _resolveClient();
      final scanOut = await client.scanModelImportInbox();
      if (!mounted) return;
      for (final c in scanOut.candidates) {
        _candidateNameControllers.putIfAbsent(
          c.relativePath,
          () => TextEditingController(text: c.displayName),
        );
      }
      setState(() {
        _inboxScanResult = scanOut;
        if (scanOut.inboxDir.isNotEmpty) {
          _importInboxDir = scanOut.inboxDir;
        }
        _isScanningInbox = false;
        _modelActionMessage = scanOut.candidates.isEmpty
            ? 'Inbox scanned: no .gguf candidates found.'
            : 'Found ${scanOut.candidates.length} GGUF candidate(s) in inbox.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanningInbox = false;
        _modelActionMessage = 'Failed to scan model inbox: $e';
      });
    }
  }

  Future<void> _installCandidate(ModelImportCandidateOut cand) async {
    if (_installingRelativePath != null) return;
    setState(() {
      _installingRelativePath = cand.relativePath;
      _modelActionMessage = 'Staging and verifying ${cand.primaryFilename}...';
    });
    try {
      final client = _resolveClient();
      final customName = _candidateNameControllers[cand.relativePath]?.text.trim();
      final res = await client.installModelFromInbox(
        ModelImportInstallRequest(
          relativePath: cand.relativePath,
          companionRelativePath: cand.companionMmprojRelativePath,
          modelId: cand.suggestedModelId,
          displayName: (customName != null && customName.isNotEmpty)
              ? customName
              : cand.displayName,
          variant: cand.variant,
          family: cand.family,
          license: cand.license,
        ),
      );
      if (!mounted) return;
      setState(() {
        _installingRelativePath = null;
        _modelActionMessage = 'Installed ${res.displayName} (${res.installedId}) cleanly.';
      });
      await Future.wait([
        _loadModelData(),
        _scanInbox(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installingRelativePath = null;
        _modelActionMessage = 'Model installation failed: $e';
      });
    }
  }

  Future<void> _deleteInstalledModel(ModelRegistryEntry entry) async {
    if (_deletingModelId != null || _isExecutingModelAction) return;
    setState(() {
      _deletingModelId = entry.id;
      _modelActionMessage = 'Removing installed model ${entry.displayName}...';
    });
    try {
      final client = _resolveClient();
      final out = await client.deleteInstalledModel(entry.id);
      if (!mounted) return;
      setState(() {
        _deletingModelId = null;
        _modelActionMessage = out.message;
      });
      await _loadModelData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deletingModelId = null;
        _modelActionMessage = 'Failed to uninstall model: $e';
      });
    }
  }

  Future<void> _copyInboxPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    setState(() {
      _modelActionMessage = 'Copied inbox path to clipboard.';
    });
  }

  Future<void> _openInboxInExplorer(String path) async {
    if (!Platform.isWindows || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      await Process.run('explorer.exe', [path]);
    } catch (_) {}
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
        stateDescription =
            'Error: ${status?.lastRuntimeError ?? "Failed to load model. Model is NOT active."}';
        break;
      case 'SERVER_STOPPED':
        stateColor = ext?.textMuted ?? Colors.grey;
        stateIcon = Icons.stop_circle_outlined;
        stateDescription = 'Server Stopped';
        break;
      default:
        stateColor = ext?.accent ?? Colors.blue;
        stateIcon = Icons.info_outline_rounded;
        stateDescription =
            'Unloaded (Selected: ${status?.selectedModel ?? _selectedModelId ?? "None"})';
    }

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
                    Icon(Icons.memory_rounded, size: 20, color: ext?.accent),
                    const SizedBox(width: CompanionSpacing.sm),
                    Flexible(
                      child: Text(
                        'Local LLM Model Selection',
                        style: CompanionTypography.titleMedium
                            .copyWith(color: ext?.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
            style: CompanionTypography.caption
                .copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.md),

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
                        style: CompanionTypography.caption
                            .copyWith(color: ext?.textSecondary),
                      ),
                      if (status != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Profile: ${(status.appliedProfile ?? status.requestedProfile).toUpperCase()} '
                          '· ${status.appliedContextSize ?? status.contextSize} ctx '
                          '· ${status.appliedGpuLayers ?? status.gpuLayers} GPU layers '
                          '· mmproj ${(status.appliedMmprojOffload ?? status.requestedMmprojOffload) ? 'GPU' : 'CPU'}',
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status?.appliedProfile != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
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
          const SizedBox(height: CompanionSpacing.md),
          Text(
            'Hardware Performance Profile (Persisted)',
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Wrap(
            spacing: CompanionSpacing.sm,
            runSpacing: CompanionSpacing.xs,
            children: [
              for (final option in const [
                ('eco', 'Eco · 2,048 ctx · CPU'),
                ('balanced', 'Balanced · 4,096 ctx · 28 GPU'),
                ('maximum', 'Maximum · 8,192 ctx · 33 GPU'),
              ])
                ChoiceChip(
                  key: Key('profile_chip_${option.$1}'),
                  label: Text(option.$2),
                  selected: (status?.requestedProfile ?? 'balanced') == option.$1,
                  onSelected: (_isUpdatingProfile || _isExecutingModelAction)
                      ? null
                      : (_) => _updateHardwareProfile(option.$1),
                ),
            ],
          ),
          if (status?.modelLoaded == true ||
              status?.activeModel != null ||
              status?.runtimeState == 'MODEL_READY') ...[
            const SizedBox(height: CompanionSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: const Key('unload_model_status_button'),
                onPressed: (_isExecutingModelAction ||
                        widget.chatController?.isGenerating == true)
                    ? null
                    : _unloadModel,
                icon: const Icon(Icons.eject_rounded, size: 14),
                label: const Text('Unload Model / Free VRAM'),
              ),
            ),
          ],
          const SizedBox(height: CompanionSpacing.lg),

          Text(
            'Available Models in Registry',
            style: CompanionTypography.bodySmall.copyWith(
              color: ext?.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: CompanionSpacing.sm),

          if (_isLoadingModelCatalog &&
              (_registryEntries == null || _registryEntries!.isEmpty))
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
                style:
                    CompanionTypography.bodySmall.copyWith(color: ext?.textMuted),
              ),
            )
          else
            ..._registryEntries!
                .map((entry) => _buildModelEntryCard(entry, ext, isDark)),

          if (_modelActionMessage != null) ...[
            const SizedBox(height: CompanionSpacing.md),
            Container(
              padding: const EdgeInsets.all(CompanionSpacing.sm),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: CompanionRadius.borderSm,
                border:
                    Border.all(color: ext?.borderSubtle ?? Colors.transparent),
              ),
              child: Row(
                children: [
                  if (_isStillLoading) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      _modelActionMessage!,
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_isStillLoading ||
                      (_modelActionMessage?.contains('still loading') == true) ||
                      (_modelActionMessage?.contains('could not be confirmed') ==
                          true)) ...[
                    const SizedBox(width: CompanionSpacing.sm),
                    TextButton.icon(
                      onPressed: _refreshModelStatusOnly,
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Refresh Model Status'),
                    ),
                  ],
                ],
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
        _isTargetModelActive(entry, _modelStatus?.activeModel);

    return Container(
      margin: const EdgeInsets.only(bottom: CompanionSpacing.md),
      padding: const EdgeInsets.all(CompanionSpacing.md),
      decoration: BoxDecoration(
        color: isSelected
            ? (ext?.accent.withValues(alpha: isDark ? 0.12 : 0.06) ??
                Colors.blue.withValues(alpha: 0.08))
            : (isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02)),
        borderRadius: CompanionRadius.borderMd,
        border: Border.all(
          color: isSelected
              ? (ext?.accent ?? Colors.blue)
              : (ext?.borderSubtle ?? Colors.grey.withValues(alpha: 0.2)),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                      style: CompanionTypography.caption
                          .copyWith(color: ext?.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.sm),

          Wrap(
            spacing: CompanionSpacing.xs,
            runSpacing: CompanionSpacing.xs,
            children: [
              _buildBadge(
                label: 'Text',
                icon: Icons.chat_bubble_outline_rounded,
                active: entry.hasChat,
                ext: ext,
              ),
              _buildBadge(
                label: 'Vision',
                icon: Icons.image_outlined,
                active: entry.hasVision,
                ext: ext,
              ),
              _buildBadge(
                label: 'Reasoning',
                icon: Icons.psychology_outlined,
                active: entry.hasReasoning,
                ext: ext,
              ),
              if (entry.architecture.isNotEmpty)
                _buildInfoChip('${entry.architecture} ${entry.parameters}'.trim(), ext),
              if (entry.quantization.isNotEmpty)
                _buildInfoChip(entry.quantization, ext),
              if (entry.sizeGb != null)
                _buildInfoChip('${entry.sizeGb!.toStringAsFixed(1)} GB disk', ext),
              if (entry.isInstalled)
                _buildInfoChip('User Imported', ext, highlight: true),
              _buildValidationBadge(entry, ext),
            ],
          ),
          const SizedBox(height: CompanionSpacing.sm),

          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: CompanionSpacing.sm,
              runSpacing: CompanionSpacing.xs,
              children: [
                if (entry.recommendedProfiles.isNotEmpty)
                  OutlinedButton.icon(
                    key: Key('apply_recommended_profile_${entry.id}'),
                    onPressed: _isUpdatingProfile
                        ? null
                        : () => _updateHardwareProfile(entry.recommendedProfiles.first),
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: Text('Apply Recommended (${entry.recommendedProfiles.first})'),
                  ),
                if (entry.isInstalled)
                  OutlinedButton.icon(
                    key: Key('delete_model_${entry.id}'),
                    onPressed: (isReady || _deletingModelId == entry.id || _isExecutingModelAction)
                        ? null
                        : () => _deleteInstalledModel(entry),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: const Text('Uninstall'),
                  ),
                if (isReady)
                  OutlinedButton.icon(
                    key: Key('unload_model_entry_${entry.id}'),
                    onPressed: (_isExecutingModelAction ||
                            _isStillLoading ||
                            widget.chatController?.isGenerating == true)
                        ? null
                        : _unloadModel,
                    icon: const Icon(Icons.eject_rounded, size: 14),
                    label: const Text('Unload Model / Free VRAM'),
                  ),
                OutlinedButton.icon(
                  onPressed: (_isExecutingModelAction || _isStillLoading)
                      ? null
                      : () => _selectModel(entry.id, loadImmediately: false),
                  icon: const Icon(Icons.bookmark_outline_rounded, size: 14),
                  label: Text(isSelected ? 'Selected' : 'Select'),
                ),
                FilledButton.tonalIcon(
                  onPressed: (_isExecutingModelAction ||
                          _isStillLoading ||
                          !entry.primaryFileExists)
                      ? null
                      : () => _selectModel(entry.id, loadImmediately: true),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: Text(isReady ? 'Reload' : 'Load Model'),
                ),
              ],
            ),
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
            ? (ext?.accent.withValues(alpha: 0.15) ??
                Colors.blue.withValues(alpha: 0.15))
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: CompanionRadius.borderSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: active
                ? (ext?.accent ?? Colors.blue)
                : (ext?.textMuted ?? Colors.grey),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: CompanionTypography.caption.copyWith(
              color: active
                  ? (ext?.accent ?? Colors.blue)
                  : (ext?.textMuted ?? Colors.grey),
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationBadge(
    ModelRegistryEntry entry,
    CompanionThemeExtension? ext,
  ) {
    Color color;
    String text;
    if (entry.isVerified) {
      color = ext?.success ?? CompanionColors.success;
      text = 'Verified';
    } else if (entry.validationStatus == 'missing_companion') {
      color = Colors.amber;
      text = 'Text-Only (Companion Missing)';
    } else if (!entry.primaryFileExists ||
        entry.validationStatus == 'missing_primary') {
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

  Widget _buildInfoChip(
    String text,
    CompanionThemeExtension? ext, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? (ext?.accent.withValues(alpha: 0.14) ?? Colors.blue.withValues(alpha: 0.14))
            : Colors.grey.withValues(alpha: 0.10),
        borderRadius: CompanionRadius.borderSm,
      ),
      child: Text(
        text,
        style: CompanionTypography.caption.copyWith(
          color: highlight ? (ext?.accent ?? Colors.blue) : (ext?.textSecondary),
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildD6ImportInboxCard(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final inboxPath = _inboxScanResult?.inboxDir ?? _importInboxDir;
    final candidates = _inboxScanResult?.candidates ?? const <ModelImportCandidateOut>[];

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Controlled Local Model Import (Decision D6)',
                  style: CompanionTypography.titleMedium
                      .copyWith(color: ext?.textPrimary),
                ),
              ),
              FilledButton.icon(
                key: const Key('d6_scan_inbox_button'),
                onPressed: _isScanningInbox ? null : _scanInbox,
                icon: _isScanningInbox
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, size: 16),
                label: const Text('Scan Inbox'),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Place .gguf models (and optional companion mmproj-*.gguf files) in your inbox folder, then click Scan Inbox to inspect metadata and verify installation.',
            style: CompanionTypography.caption
                .copyWith(color: ext?.textSecondary),
          ),
          if (inboxPath != null && inboxPath.isNotEmpty) ...[
            const SizedBox(height: CompanionSpacing.sm),
            NeumorphicSurface(
              surfaceType: NeumorphicSurfaceType.recessed,
              borderRadius: CompanionRadius.borderMd,
              padding: const EdgeInsets.symmetric(
                horizontal: CompanionSpacing.md,
                vertical: CompanionSpacing.sm,
              ),
              child: Wrap(
                spacing: CompanionSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SelectableText(
                    inboxPath,
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _copyInboxPath(inboxPath),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy Path'),
                  ),
                  if (Platform.isWindows)
                    TextButton.icon(
                      onPressed: () => _openInboxInExplorer(inboxPath),
                      icon: const Icon(Icons.folder_open_rounded, size: 14),
                      label: const Text('Open in Explorer'),
                    ),
                ],
              ),
            ),
          ],
          if (_inboxScanResult != null) ...[
            const SizedBox(height: CompanionSpacing.md),
            if (candidates.isEmpty)
              Text(
                'Inbox is empty. Drop a .gguf file into the inbox folder above and click Scan Inbox.',
                style: CompanionTypography.bodySmall
                    .copyWith(color: ext?.textMuted),
              )
            else
              for (final cand in candidates) ...[
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
                              cand.primaryFilename,
                              style: CompanionTypography.bodyMedium.copyWith(
                                color: ext?.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (cand.artifactValid
                                      ? (cand.preflight.status == 'recommended'
                                          ? (ext?.success ?? CompanionColors.success)
                                          : (ext?.warning ?? CompanionColors.warning))
                                      : (ext?.danger ?? CompanionColors.danger))
                                  .withValues(alpha: 0.15),
                              borderRadius: CompanionRadius.borderSm,
                            ),
                            child: Text(
                              cand.artifactValid
                                  ? '${cand.preflight.status.toUpperCase()} (~${cand.preflight.estimatedVramGb.toStringAsFixed(1)} GB VRAM)'
                                  : 'INVALID GGUF',
                              style: CompanionTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: CompanionSpacing.xs,
                        runSpacing: CompanionSpacing.xs,
                        children: [
                          _buildInfoChip('${cand.sizeGb.toStringAsFixed(2)} GB', ext),
                          if (cand.architecture.isNotEmpty)
                            _buildInfoChip(cand.architecture, ext),
                          if (cand.quantization.isNotEmpty)
                            _buildInfoChip(cand.quantization, ext),
                          if (cand.companionMmprojFilename != null)
                            _buildInfoChip('mmproj: ${cand.companionMmprojFilename}', ext, highlight: true),
                        ],
                      ),
                      const SizedBox(height: CompanionSpacing.xs),
                      Text(
                        cand.validationError ?? cand.preflight.message,
                        style: CompanionTypography.caption
                            .copyWith(color: ext?.textSecondary),
                      ),
                      if (cand.artifactValid) ...[
                        const SizedBox(height: CompanionSpacing.sm),
                        Wrap(
                          spacing: CompanionSpacing.sm,
                          runSpacing: CompanionSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 180,
                                maxWidth: 280,
                              ),
                              child: TextField(
                                controller: _candidateNameControllers[cand.relativePath],
                                decoration: const InputDecoration(
                                  labelText: 'Display Name',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  _updateHardwareProfile(cand.preflight.recommendedProfile),
                              child: Text(
                                'Use ${cand.preflight.recommendedProfile}',
                              ),
                            ),
                            FilledButton.tonalIcon(
                              key: Key('d6_install_candidate_${cand.suggestedModelId}'),
                              onPressed: _installingRelativePath != null
                                  ? null
                                  : () => _installCandidate(cand),
                              icon: _installingRelativePath == cand.relativePath
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download_done_rounded, size: 16),
                              label: const Text('Install Bundle'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: CompanionSpacing.sm),
              ],
          ],
        ],
      ),
    );
  }
}
