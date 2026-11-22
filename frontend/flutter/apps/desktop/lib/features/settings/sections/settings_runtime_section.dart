import 'dart:async';
import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:companion_core/companion_core.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import '../../../controllers/desktop_settings_controller.dart';
import '../../../coordinator/desktop_runtime_coordinator.dart';
import '../../../platform/desktop_client_settings.dart';
import '../../../platform/host_admin_secret_store.dart';
import '../../../platform/windows_dpapi_credential_store.dart';
import '../../../platform/windows_shell_adapter.dart';
import '../../chat/desktop_chat_controller.dart';
import '../settings_section.dart';

/// Consumer-first AI & Local Models section with top Refresh, PC-aware model
/// recommendations, experimental >8K context override, native model file picker,
/// and collapsible Advanced Connection & Process Diagnostics.
class SettingsRuntimeSection extends StatefulWidget {
  const SettingsRuntimeSection({
    super.key,
    required this.controller,
    this.chatController,
    this.runtimeCoordinator,
    this.clientSettings,
    this.credentialStore,
    this.client,
    this.shellAdapter,
  });

  final DesktopSettingsController controller;
  final DesktopChatController? chatController;
  final DesktopRuntimeCoordinator? runtimeCoordinator;
  final DesktopClientSettings? clientSettings;
  final CredentialStore? credentialStore;
  final CompanionClient? client;
  final DesktopShellAdapter? shellAdapter;

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
  DesktopShellAdapter get _shell =>
      widget.shellAdapter ?? WindowsShellAdapter();

  List<ModelRegistryEntry>? _registryEntries;
  ModelStatusResponse? _modelStatus;
  bool _isLoadingModelCatalog = false;
  bool _isExecutingModelAction = false;
  bool _isStillLoading = false;
  String? _selectedModelId;
  String? _modelActionMessage;
  bool _isUpdatingProfile = false;
  bool _contextOptionsExpanded = false;
  bool _isScanningInbox = false;
  bool _movePickedFiles = false;
  String? _installingRelativePath;
  String? _deletingModelId;
  String? _libraryRoot;
  String? _importInboxDir;
  ModelImportScanOut? _inboxScanResult;
  final Map<String, TextEditingController> _candidateNameControllers = {};

  DesktopNavDestination _lastDestination = DesktopNavDestination.chat;
  SettingsSectionId _lastSection = SettingsSectionId.appearance;
  int _lastStorageRevision = 0;

  bool _advancedUserToggled = false;
  bool _advancedExpanded = false;

  void _handleControllerChange() {
    final dest = widget.controller.currentDestination;
    final section = widget.controller.selectedSettingsSection;
    final storageRev = widget.controller.storageRevision;
    final enteredSettings = dest == DesktopNavDestination.settings &&
        _lastDestination != DesktopNavDestination.settings;
    final enteredRuntimeSection =
        section == SettingsSectionId.runtime &&
        _lastSection != SettingsSectionId.runtime;
    final storageChanged = storageRev != _lastStorageRevision;

    if (storageChanged) {
      _lastStorageRevision = storageRev;
      if (mounted) {
        setState(() {
          _inboxScanResult = null;
          _importInboxDir = null;
          _libraryRoot = null;
        });
      }
    }

    if (enteredSettings || enteredRuntimeSection || storageChanged) {
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
    _lastStorageRevision = widget.controller.storageRevision;
    if (widget.client == null) {
      _advancedExpanded = true;
    }

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

  String _formatError(Object e) => e is CompanionApiException ? e.message : '$e';

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopHeaderBar(ext),
        const SizedBox(height: CompanionSpacing.md),
        _buildModelSelectionCard(context, ext, isDark),
        const SizedBox(height: CompanionSpacing.lg),
        _buildAddLocalModelsCard(context, ext, isDark),
        const SizedBox(height: CompanionSpacing.lg),
        _buildModelRegistryListCard(context, ext, isDark),
        const SizedBox(height: CompanionSpacing.lg),
        _buildAdvancedDiagnosticsAccordion(context, ext, isDark),
      ],
    );
  }

  Widget _buildTopHeaderBar(CompanionThemeExtension? ext) {
    return SoftGlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: CompanionSpacing.xl,
        vertical: CompanionSpacing.md,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: CompanionSpacing.md,
        runSpacing: CompanionSpacing.sm,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI & Local Models',
                style: CompanionTypography.titleMedium
                    .copyWith(color: ext?.textPrimary),
              ),
              Text(
                'Switch models, tune speed vs quality, or add new GGUF models',
                style: CompanionTypography.caption
                    .copyWith(color: ext?.textSecondary),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonalIcon(
                key: const Key('runtime_top_refresh_button'),
                onPressed: _isLoadingModelCatalog ? null : _loadModelData,
                icon: _isLoadingModelCatalog
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_isLoadingModelCatalog ? 'Refreshing...' : 'Refresh All'),
              ),
            ],
          ),
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
      final statusResp = results[1] as ModelStatusResponse;
      setState(() {
        _registryEntries = results[0] as List<ModelRegistryEntry>;
        _modelStatus = statusResp;
        final savedModel = results[2] as String?;
        _selectedModelId =
            statusResp.selectedModel ?? savedModel ?? _selectedModelId;
        if (storageResp != null) {
          if (_importInboxDir != null &&
              storageResp.importInboxDir.isNotEmpty &&
              _importInboxDir != storageResp.importInboxDir) {
            _inboxScanResult = null;
          }
          if (storageResp.importInboxDir.isNotEmpty) {
            _importInboxDir = storageResp.importInboxDir;
          }
          if (storageResp.libraryRoot.isNotEmpty) {
            _libraryRoot = storageResp.libraryRoot;
          }
        }
        if (statusResp.requestedContextMode != 'profile') {
          _contextOptionsExpanded = true;
        }
        _isLoadingModelCatalog = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingModelCatalog = false;
        _modelActionMessage = 'Could not load models: ${_formatError(e)}';
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
              ? 'Model ready: ${targetEntry?.displayName ?? updatedStatus.activeModel ?? modelId}'
              : 'Model selected (${updatedStatus.selectedModel ?? modelId}), but activation did not finish.';
        } else {
          _modelActionMessage =
              'Selected ${targetEntry?.displayName ?? modelId} (not loaded yet).';
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
            ? 'Could not load model: ${_formatError(e)}'
            : 'Model selection failed: ${_formatError(e)}';
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
                ? 'Model ready: ${targetEntry?.displayName ?? status.activeModel ?? modelId}'
                : 'Model ready: ${status.activeModel}';
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
              'Model load status timed out. Click Refresh Model Status to re-check.';
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
              'Current model state: ${fresh.runtimeState}';
        }
      });
      widget.chatController?.updateModelStatus(fresh);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _modelActionMessage = 'Could not check model status: ${_formatError(e)}';
      });
    }
  }

  Future<void> _unloadModel() async {
    if (_isExecutingModelAction) return;
    if (widget.chatController?.isGenerating == true) {
      setState(() {
        _modelActionMessage =
            'Cannot unload model while a reply is being generated.';
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
        _modelActionMessage = 'Failed to unload model: ${_formatError(e)}';
      });
    }
  }

  Future<void> _updateHardwareProfile(
    String profile, {
    String? contextMode,
  }) async {
    if (_isUpdatingProfile || _isExecutingModelAction) return;
    setState(() {
      _isUpdatingProfile = true;
      _modelActionMessage = 'Updating performance settings...';
    });
    try {
      final client = _resolveClient();
      final updatedStatus = await client.updateModelProfile(
        profile,
        contextMode: contextMode,
      );
      if (!mounted) return;
      setState(() {
        _modelStatus = updatedStatus;
        _isUpdatingProfile = false;
        final ctxLabel = updatedStatus.requestedContextMode == 'profile'
            ? '${updatedStatus.contextSize} ctx'
            : '${updatedStatus.contextSize} ctx (${updatedStatus.requestedContextMode})';
        _modelActionMessage = updatedStatus.modelLoaded
            ? 'Performance updated (${updatedStatus.requestedProfile.toUpperCase()} · $ctxLabel).'
            : 'Performance updated (${updatedStatus.requestedProfile.toUpperCase()} · $ctxLabel). Click Load Model to apply.';
      });
      widget.chatController?.updateModelStatus(updatedStatus);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingProfile = false;
        _modelActionMessage =
            'Could not update performance setting: ${_formatError(e)}';
      });
    }
  }

  Future<void> _browseAndStageModelFiles() async {
    if (_isScanningInbox || _installingRelativePath != null) return;
    final pickedPaths = await _shell.pickModelFiles(
      title: 'Select AI Model Files (.gguf / mmproj)',
      allowMultiple: true,
    );
    if (pickedPaths.isEmpty || !mounted) return;

    setState(() {
      _isScanningInbox = true;
      _modelActionMessage = _movePickedFiles
          ? 'Moving selected file(s) to your model inbox...'
          : 'Copying selected file(s) to your model inbox...';
    });

    try {
      var inboxDir = _importInboxDir;
      if (inboxDir == null || inboxDir.isEmpty) {
        final client = _resolveClient();
        final scanFirst = await client.scanModelImportInbox();
        inboxDir = scanFirst.inboxDir;
        if (mounted) {
          setState(() {
            _importInboxDir = inboxDir;
          });
        }
      }
      if (inboxDir.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isScanningInbox = false;
          _modelActionMessage = 'Unable to resolve Model Inbox folder from runtime.';
        });
        return;
      }

      await _shell.stageFilesToInbox(
        sourcePaths: pickedPaths,
        inboxDir: inboxDir,
        moveFiles: _movePickedFiles,
      );

      if (!mounted) return;
      setState(() {
        _isScanningInbox = false;
      });
      await _scanInbox();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanningInbox = false;
        _modelActionMessage = 'Could not import selected files: ${_formatError(e)}';
      });
    }
  }

  Future<void> _scanInbox() async {
    if (_isScanningInbox) return;
    setState(() {
      _isScanningInbox = true;
      _modelActionMessage = 'Scanning inbox for local AI models...';
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
            ? (scanOut.warnings.isEmpty
                ? 'Inbox scanned: no .gguf models found yet.'
                : 'Inbox scanned: check format notes below.')
            : 'Found ${scanOut.candidates.length} model(s) ready to install.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanningInbox = false;
        _modelActionMessage = 'Could not scan inbox: ${_formatError(e)}';
      });
    }
  }

  Future<void> _installCandidate(ModelImportCandidateOut cand) async {
    if (_installingRelativePath != null) return;
    setState(() {
      _installingRelativePath = cand.relativePath;
      _modelActionMessage = 'Verifying and installing ${cand.primaryFilename}...';
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
          transferMode: 'move',
        ),
      );
      if (!mounted) return;
      setState(() {
        _installingRelativePath = null;
        _modelActionMessage = 'Installed ${res.displayName} into your library.';
      });
      await Future.wait([
        _loadModelData(),
        _scanInbox(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installingRelativePath = null;
        _modelActionMessage = 'Installation failed: ${_formatError(e)}';
      });
    }
  }

  Future<void> _deleteInstalledModel(ModelRegistryEntry entry) async {
    if (_deletingModelId != null || _isExecutingModelAction) return;
    setState(() {
      _deletingModelId = entry.id;
      _modelActionMessage = 'Removing ${entry.displayName}...';
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
        _modelActionMessage = 'Could not remove model: ${_formatError(e)}';
      });
    }
  }

  Future<void> _openInboxInExplorer(String? path) async {
    var target = path;
    if (target == null || target.isEmpty) {
      try {
        final client = _resolveClient();
        final scan = await client.scanModelImportInbox();
        target = scan.inboxDir;
        if (mounted) {
          setState(() {
            _importInboxDir = target;
          });
        }
      } catch (_) {}
    }
    if (target == null || target.isEmpty) return;
    await _shell.openFolder(target, createIfMissing: true);
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
    String stateHeadline;
    String stateDescription;

    switch (stateName) {
      case 'MODEL_READY':
        stateColor = ext?.success ?? CompanionColors.success;
        stateIcon = Icons.check_circle_rounded;
        stateHeadline = 'Ready';
        stateDescription = 'Active model: ${status?.activeModel ?? "None"}';
        break;
      case 'MODEL_LOADING':
        stateColor = Colors.orange;
        stateIcon = Icons.sync_rounded;
        stateHeadline = 'Loading';
        stateDescription = 'Loading model weights into memory...';
        break;
      case 'MODEL_SELECTION_REQUIRED':
        stateColor = Colors.amber;
        stateIcon = Icons.warning_amber_rounded;
        stateHeadline = 'Choose a Model';
        stateDescription = 'Select a model below to start chatting';
        break;
      case 'MODEL_SLEEPING':
        stateColor = Colors.purple;
        stateIcon = Icons.bedtime_rounded;
        stateHeadline = 'Sleeping';
        stateDescription = 'VRAM released while idle (wakes on next message)';
        break;
      case 'MODEL_ERROR':
      case 'SERVER_ERROR':
        stateColor = ext?.danger ?? CompanionColors.danger;
        stateIcon = Icons.error_outline_rounded;
        stateHeadline = 'Needs Attention';
        stateDescription =
            status?.lastRuntimeError ?? 'Failed to load model. Model is NOT active.';
        break;
      case 'SERVER_STOPPED':
        stateColor = ext?.textMuted ?? Colors.grey;
        stateIcon = Icons.stop_circle_outlined;
        stateHeadline = 'Standing By';
        stateDescription = _selectedModelId != null
            ? 'Selected: $_selectedModelId (click Load Model to start)'
            : 'Inference engine stopped until you load a model';
        break;
      default:
        stateColor = ext?.accent ?? Colors.blue;
        stateIcon = Icons.info_outline_rounded;
        stateHeadline = 'Unloaded';
        stateDescription =
            'Selected: ${status?.selectedModel ?? _selectedModelId ?? "None"}';
    }

    final reqCtxMode = status?.requestedContextMode ?? 'profile';

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory_rounded, size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Local LLM Model Selection',
                  style: CompanionTypography.titleMedium
                      .copyWith(color: ext?.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status?.hostVramGb != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ext?.accent.withValues(alpha: 0.12),
                    borderRadius: CompanionRadius.borderSm,
                  ),
                  child: Text(
                    '${status!.hostGpuName ?? 'GPU'} · ${status.hostVramGb!.toStringAsFixed(0)} GB VRAM'
                    '${status.hostRamGb != null ? ' · ${status.hostRamGb!.toStringAsFixed(0)} GB RAM' : ''}',
                    style: CompanionTypography.caption.copyWith(
                      color: ext?.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
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
                        stateHeadline,
                        style: CompanionTypography.bodySmall.copyWith(
                          color: stateColor,
                          fontWeight: FontWeight.w700,
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
                          '· Vision ${(status.appliedMmprojOffload ?? status.requestedMmprojOffload) ? 'GPU' : 'CPU'}',
                          style: CompanionTypography.caption.copyWith(
                            color: ext?.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status?.modelLoaded == true ||
                    status?.activeModel != null ||
                    status?.runtimeState == 'MODEL_READY')
                  OutlinedButton.icon(
                    key: const Key('unload_model_status_button'),
                    onPressed: (_isExecutingModelAction ||
                            widget.chatController?.isGenerating == true)
                        ? null
                        : _unloadModel,
                    icon: const Icon(Icons.eject_rounded, size: 14),
                    label: const Text('Unload Model / Free VRAM'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: CompanionSpacing.md),
          Text(
            'Performance Mode',
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
                ('eco', 'Eco · 2K ctx · Low VRAM / CPU'),
                ('balanced', 'Balanced · 4K ctx · GPU'),
                ('maximum', 'Maximum · 8K ctx · High VRAM'),
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
          const SizedBox(height: CompanionSpacing.sm),
          InkWell(
            key: const Key('experimental_context_toggle'),
            borderRadius: CompanionRadius.borderSm,
            onTap: () {
              setState(() {
                _contextOptionsExpanded = !_contextOptionsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _contextOptionsExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: ext?.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Advanced: Context Memory Window (>8K Experimental)',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_contextOptionsExpanded) ...[
            const SizedBox(height: CompanionSpacing.xs),
            Wrap(
              spacing: CompanionSpacing.sm,
              runSpacing: CompanionSpacing.xs,
              children: [
                ChoiceChip(
                  key: const Key('ctx_mode_profile'),
                  label: const Text('Use Profile Default (2K / 4K / 8K)'),
                  selected: reqCtxMode == 'profile',
                  onSelected: (_isUpdatingProfile || _isExecutingModelAction)
                      ? null
                      : (_) => _updateHardwareProfile(
                            status?.requestedProfile ?? 'balanced',
                            contextMode: 'profile',
                          ),
                ),
                ChoiceChip(
                  key: const Key('ctx_mode_16k'),
                  label: const Text('16K Context (Experimental)'),
                  selected: reqCtxMode == '16k',
                  onSelected: (_isUpdatingProfile || _isExecutingModelAction)
                      ? null
                      : (_) => _updateHardwareProfile(
                            status?.requestedProfile ?? 'balanced',
                            contextMode: '16k',
                          ),
                ),
                ChoiceChip(
                  key: const Key('ctx_mode_model_max'),
                  label: const Text('Model Max (Experimental)'),
                  selected: reqCtxMode == 'model_max',
                  onSelected: (_isUpdatingProfile || _isExecutingModelAction)
                      ? null
                      : (_) => _updateHardwareProfile(
                            status?.requestedProfile ?? 'balanced',
                            contextMode: 'model_max',
                          ),
                ),
              ],
            ),
            if (reqCtxMode != 'profile') ...[
              const SizedBox(height: CompanionSpacing.xs),
              Container(
                padding: const EdgeInsets.all(CompanionSpacing.sm),
                decoration: BoxDecoration(
                  color: (ext?.warning ?? CompanionColors.warning)
                      .withValues(alpha: 0.14),
                  borderRadius: CompanionRadius.borderSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: ext?.warning ?? CompanionColors.warning,
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    Expanded(
                      child: Text(
                        'Experimental Warning: Context windows above 8K sharply increase VRAM & RAM usage and may spill to slow system memory or crash on <= 8 GB GPUs. Reload the model to apply.',
                        style: CompanionTypography.caption
                            .copyWith(color: ext?.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

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
                      (_modelActionMessage?.contains('timed out') == true)) ...[
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

  Widget _buildAddLocalModelsCard(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final inboxPath = (_importInboxDir != null && _importInboxDir!.isNotEmpty)
        ? _importInboxDir
        : _inboxScanResult?.inboxDir;
    final candidates =
        _inboxScanResult?.candidates ?? const <ModelImportCandidateOut>[];
    final warnings = _inboxScanResult?.warnings ?? const <String>[];

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
                  Icon(Icons.add_box_outlined, size: 20, color: ext?.accent),
                  const SizedBox(width: CompanionSpacing.sm),
                  Flexible(
                    child: Text(
                      'Add Local Models',
                      style: CompanionTypography.titleMedium
                          .copyWith(color: ext?.textPrimary),
                    ),
                  ),
                ],
              ),
              if (_libraryRoot != null && _libraryRoot!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: CompanionRadius.borderSm,
                  ),
                  child: Text(
                    'Library: $_libraryRoot',
                    style: CompanionTypography.caption
                        .copyWith(color: ext?.textSecondary, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.xs),
          Text(
            'Pick a .gguf model (and optional mmproj-*.gguf for vision) or place files in your Model Inbox folder, then install them into your library.',
            style: CompanionTypography.caption
                .copyWith(color: ext?.textSecondary),
          ),
          const SizedBox(height: CompanionSpacing.md),
          Wrap(
            spacing: CompanionSpacing.sm,
            runSpacing: CompanionSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('browse_model_files_button'),
                onPressed: (_isScanningInbox || _installingRelativePath != null)
                    ? null
                    : _browseAndStageModelFiles,
                icon: const Icon(Icons.file_open_rounded, size: 16),
                label: const Text('Add Model Files...'),
              ),
              if (Platform.isWindows)
                OutlinedButton.icon(
                  key: const Key('open_inbox_folder_button'),
                  onPressed: () => _openInboxInExplorer(inboxPath),
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('Open Inbox Folder'),
                ),
              FilledButton.tonalIcon(
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    key: const Key('import_transfer_mode_switch'),
                    value: _movePickedFiles,
                    onChanged: (_isScanningInbox || _installingRelativePath != null)
                        ? null
                        : (v) => setState(() => _movePickedFiles = v),
                  ),
                  Flexible(
                    child: Text(
                      _movePickedFiles
                          ? 'Move picked files (save space)'
                          : 'Copy picked files (keep original)',
                      style: CompanionTypography.caption
                          .copyWith(color: ext?.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: CompanionSpacing.md),
            for (final w in warnings)
              Container(
                margin: const EdgeInsets.only(bottom: CompanionSpacing.xs),
                padding: const EdgeInsets.all(CompanionSpacing.sm),
                decoration: BoxDecoration(
                  color: (ext?.warning ?? CompanionColors.warning)
                      .withValues(alpha: 0.14),
                  borderRadius: CompanionRadius.borderSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: ext?.warning ?? CompanionColors.warning,
                    ),
                    const SizedBox(width: CompanionSpacing.sm),
                    Expanded(
                      child: Text(
                        w,
                        style: CompanionTypography.caption
                            .copyWith(color: ext?.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (_inboxScanResult != null) ...[
            const SizedBox(height: CompanionSpacing.md),
            if (candidates.isEmpty)
              Text(
                'No installable .gguf models found in your inbox yet. Use "Add Model Files..." or open the inbox folder.',
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (cand.artifactValid
                                      ? (cand.preflight.status == 'recommended'
                                          ? (ext?.success ??
                                              CompanionColors.success)
                                          : cand.preflight.status ==
                                                  'supported_with_warning'
                                              ? (ext?.warning ??
                                                  CompanionColors.warning)
                                              : (ext?.danger ??
                                                  CompanionColors.danger))
                                      : (ext?.danger ?? CompanionColors.danger))
                                  .withValues(alpha: 0.15),
                              borderRadius: CompanionRadius.borderSm,
                            ),
                            child: Text(
                              cand.artifactValid
                                  ? '${cand.preflight.status == 'recommended' ? 'GOOD FIT' : (cand.preflight.status == 'supported_with_warning' ? 'TIGHT FIT' : 'HEAVY FOR GPU')} (~${cand.preflight.estimatedVramGb.toStringAsFixed(1)} GB VRAM)'
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
                          _buildInfoChip(
                              '${cand.sizeGb.toStringAsFixed(2)} GB', ext),
                          if (cand.architecture.isNotEmpty)
                            _buildInfoChip(cand.architecture, ext),
                          if (cand.quantization.isNotEmpty)
                            _buildInfoChip(cand.quantization, ext),
                          if (cand.companionMmprojFilename != null)
                            _buildInfoChip(
                                'Vision projector: ${cand.companionMmprojFilename}',
                                ext,
                                highlight: true),
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
                                controller:
                                    _candidateNameControllers[cand.relativePath],
                                decoration: const InputDecoration(
                                  labelText: 'Display Name',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _updateHardwareProfile(
                                  cand.preflight.recommendedProfile),
                              child: Text(
                                'Use ${cand.preflight.recommendedProfile}',
                              ),
                            ),
                            FilledButton.tonalIcon(
                              key: Key(
                                  'd6_install_candidate_${cand.suggestedModelId}'),
                              onPressed: _installingRelativePath != null
                                  ? null
                                  : () => _installCandidate(cand),
                              icon: _installingRelativePath == cand.relativePath
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download_done_rounded,
                                      size: 16),
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

  Widget _buildModelRegistryListCard(
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
              Icon(Icons.auto_awesome_mosaic_outlined,
                  size: 20, color: ext?.accent),
              const SizedBox(width: CompanionSpacing.sm),
              Expanded(
                child: Text(
                  'Available Models',
                  style: CompanionTypography.titleMedium
                      .copyWith(color: ext?.textPrimary),
                ),
              ),
              Text(
                '${_registryEntries?.length ?? 0} total',
                style: CompanionTypography.caption
                    .copyWith(color: ext?.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: CompanionSpacing.md),
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
              padding:
                  const EdgeInsets.symmetric(vertical: CompanionSpacing.md),
              child: Text(
                'No models found yet. Add a model above or verify your Library folder.',
                style:
                    CompanionTypography.bodySmall.copyWith(color: ext?.textMuted),
              ),
            )
          else
            ..._registryEntries!
                .map((entry) => _buildModelEntryCard(entry, ext, isDark)),
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

    final subtitleParts = <String>[
      if (entry.architecture.isNotEmpty) entry.architecture.toUpperCase(),
      if (entry.parameters.isNotEmpty) entry.parameters,
      if (entry.quantization.isNotEmpty) entry.quantization,
      if (entry.estimatedVramGb > 0)
        '~${entry.estimatedVramGb.toStringAsFixed(1)} GB VRAM',
    ];

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
                    isReady ? 'ACTIVE' : 'SELECTED',
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
          if (subtitleParts.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitleParts.join(' · '),
              style: CompanionTypography.caption
                  .copyWith(color: ext?.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
              if (entry.sizeGb != null)
                _buildInfoChip('${entry.sizeGb!.toStringAsFixed(1)} GB disk', ext),
              if (entry.isInstalled)
                _buildInfoChip('Added by You', ext, highlight: true),
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
                        : () =>
                            _updateHardwareProfile(entry.recommendedProfiles.first),
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: Text(
                        'Apply Recommended (${entry.recommendedProfiles.first})'),
                  ),
                if (entry.isInstalled)
                  OutlinedButton.icon(
                    key: Key('delete_model_${entry.id}'),
                    onPressed: (isReady ||
                            _deletingModelId == entry.id ||
                            _isExecutingModelAction)
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

  Widget _buildAdvancedDiagnosticsAccordion(
    BuildContext context,
    CompanionThemeExtension? ext,
    bool isDark,
  ) {
    final isDisconnected = widget.client == null ||
        _modelStatus == null ||
        _modelStatus!.provider == 'unknown';
    final isExpanded =
        _advancedUserToggled ? _advancedExpanded : isDisconnected;

    return SoftGlassPanel(
      padding: const EdgeInsets.all(CompanionSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('runtime_advanced_toggle'),
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
                  Icon(Icons.developer_mode_rounded,
                      size: 18, color: ext?.textSecondary),
                  const SizedBox(width: CompanionSpacing.sm),
                  Expanded(
                    child: Text(
                      'Advanced: Runtime Connection & Process Diagnostics',
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
            const SizedBox(height: CompanionSpacing.lg),
            _buildRuntimeConnectionCard(context, ext, isDark),
            const SizedBox(height: CompanionSpacing.lg),
            _buildRuntimeSupervisionCard(context, ext, isDark),
          ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.developer_board_rounded, size: 18, color: ext?.accent),
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
        const SizedBox(height: CompanionSpacing.md),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link_rounded, size: 18, color: ext?.accent),
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
        const SizedBox(height: CompanionSpacing.md),

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
                          'Failed to apply configuration: ${_formatError(e)}';
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
          Flexible(
            child: Text(
              label,
              style: CompanionTypography.caption.copyWith(
                color: active
                    ? (ext?.accent ?? Colors.blue)
                    : (ext?.textMuted ?? Colors.grey),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                fontSize: 11,
              ),
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
            ? (ext?.accent.withValues(alpha: 0.14) ??
                Colors.blue.withValues(alpha: 0.14))
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
}
