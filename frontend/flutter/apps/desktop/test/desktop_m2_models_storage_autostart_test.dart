import 'dart:io';

import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/diagnostics/windows_storage_diagnostic_reader.dart';
import 'package:ai_companion_desktop/features/settings/settings_section.dart';
import 'package:ai_companion_desktop/platform/desktop_client_settings.dart';
import 'package:ai_companion_desktop/platform/windows_shell_adapter.dart';
import 'package:ai_companion_desktop/screens/settings_screen.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryDesktopClientSettings extends DesktopClientSettings {
  String _hostUrl = 'http://127.0.0.1:8000';
  String? _selectedModel;

  @override
  Future<String> readHostUrl({
    String defaultValue = 'http://127.0.0.1:8000',
  }) async =>
      _hostUrl;

  @override
  Future<void> writeHostUrl(String hostUrl) async {
    _hostUrl = hostUrl;
  }

  @override
  Future<String?> readSelectedModel() async => _selectedModel;

  @override
  Future<void> writeSelectedModel(String? modelId) async {
    _selectedModel = modelId;
  }
}

class FakeM2DesktopClient extends CompanionClient {
  String currentProfile = 'balanced';
  String currentContextMode = 'profile';
  bool libraryRelocated = false;
  bool autostartEnabled = false;
  bool autostartMinimized = true;
  String? deletedModelId;
  String? installedModelId;
  int scanCalls = 0;
  List<String> scanWarnings = const [];

  FakeM2DesktopClient()
      : super(
          credentialStore: InMemoryCredentialStore('test-token'),
          hostAdminStore: InMemoryCredentialStore('admin-secret'),
        );

  final List<ModelRegistryEntry> _entries = [
    const ModelRegistryEntry(
      id: 'qwen3-vl-2b-instruct',
      displayName: 'Qwen3-VL 2B Instruct',
      primaryFile: 'vision/qwen3-vl-2b-instruct/Qwen.gguf',
      runtimeModelId: 'qwen3-vl-2b-instruct',
      primaryFileExists: true,
      validationStatus: 'verified',
      capabilities: ['chat', 'vision'],
      availableCapabilities: ['chat', 'vision'],
      architecture: 'qwen3vl',
      quantization: 'Q4_K_M',
      parameters: '2B',
      recommendedProfiles: ['maximum'],
      registrySource: 'factory',
    ),
    const ModelRegistryEntry(
      id: 'gemma-3-4b-custom',
      displayName: 'My Gemma 3 4B',
      primaryFile: 'gemma-3-4b-custom/gemma.gguf',
      runtimeModelId: 'gemma-3-4b-custom',
      primaryFileExists: true,
      validationStatus: 'verified',
      capabilities: ['chat', 'vision'],
      availableCapabilities: ['chat', 'vision'],
      architecture: 'gemma3',
      quantization: 'Q4_K_M',
      parameters: '4B',
      recommendedProfiles: ['eco'],
      registrySource: 'installed',
    ),
  ];

  @override
  Future<List<ModelRegistryEntry>> getModelRegistry() async =>
      _entries.where((e) => e.id != deletedModelId).toList();

  @override
  Future<ModelStatusResponse> getModelStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final ctx = currentContextMode == '16k'
        ? 16384
        : (currentContextMode == 'model_max'
            ? 32768
            : (currentProfile == 'eco' ? 2048 : (currentProfile == 'maximum' ? 8192 : 4096)));
    return ModelStatusResponse(
      provider: 'llama_cpp',
      runtimeState: 'MODEL_UNLOADED',
      selectedModel: 'qwen3-vl-2b-instruct',
      requestedProfile: currentProfile,
      requestedContextMode: currentContextMode,
      activeProfile: currentProfile,
      contextSize: ctx,
      gpuLayers: currentProfile == 'eco' ? 0 : (currentProfile == 'maximum' ? 33 : 28),
      hostGpuName: 'AMD Radeon RX 580',
      hostVramGb: 8.0,
      hostRamGb: 16.0,
    );
  }

  @override
  Future<ModelStatusResponse> updateModelProfile(
    String profile, {
    String? contextMode,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    currentProfile = profile;
    if (contextMode != null) {
      currentContextMode = contextMode;
    }
    return getModelStatus();
  }

  @override
  Future<ModelImportScanOut> scanModelImportInbox({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    scanCalls++;
    final inbox = libraryRelocated
        ? r'E:\MovedLibrary\imports\inbox'
        : r'D:\CompanionLib\imports\inbox';
    return ModelImportScanOut(
      inboxDir: inbox,
      warnings: scanWarnings,
      candidates: const [
        ModelImportCandidateOut(
          relativePath: 'llama3-8b/llama3.gguf',
          primaryFilename: 'llama3.gguf',
          suggestedModelId: 'llama3-8b-q4',
          displayName: 'Llama 3 8B Q4',
          fileSizeBytes: 4200000000,
          sizeGb: 3.91,
          artifactValid: true,
          architecture: 'llama',
          quantization: 'Q4_K_M',
          parameters: '8B',
          modelMaxContext: 8192,
          detectedCapabilities: ['chat'],
          preflight: PreflightAssessmentOut(
            status: 'supported_with_warning',
            estimatedVramGb: 5.19,
            hostDedicatedVramGb: 8.0,
            recommendedProfile: 'eco',
            message: 'Close heavy GPU apps for best headroom.',
          ),
        ),
      ],
    );
  }

  @override
  Future<ModelImportInstallOut> installModelFromInbox(
    ModelImportInstallRequest request, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    installedModelId = request.modelId;
    return ModelImportInstallOut(
      installedId: request.modelId,
      displayName: request.displayName ?? request.modelId,
      primaryFile: '${request.modelId}/llama3.gguf',
      validationStatus: 'verified',
      sha256Primary: 'abc123',
    );
  }

  @override
  Future<ModelDeleteOut> deleteInstalledModel(
    String modelId, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    deletedModelId = modelId;
    return ModelDeleteOut(deletedId: modelId, message: 'Removed');
  }

  @override
  Future<StorageRootsResponse> getStorageRoots({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final libPath = libraryRelocated ? r'E:\MovedLibrary' : r'D:\CompanionLib';
    return StorageRootsResponse(
      bootstrapPath: r'C:\Users\Admin\AppData\Local\AI Companion\bootstrap.json',
      libraryRoot: libPath,
      importInboxDir: '$libPath\\imports\\inbox',
      libraryRelocatable: true,
      roots: [
        const StorageRootOut(
          key: 'app_install',
          label: 'Application Install Root',
          path: r'D:\AI-companion',
          exists: true,
          source: 'default',
        ),
        const StorageRootOut(
          key: 'data',
          label: 'Persistent Data Root (DB & Profiles)',
          path: r'C:\Users\Admin\AppData\Local\AI Companion\Data',
          exists: true,
          source: 'default',
        ),
        StorageRootOut(
          key: 'library',
          label: 'Asset & Model Library Root',
          path: libPath,
          exists: true,
          freeBytes: 50 * 1024 * 1024 * 1024,
          totalBytes: 256 * 1024 * 1024 * 1024,
          source: libraryRelocated ? 'bootstrap' : 'default',
        ),
        const StorageRootOut(
          key: 'cache',
          label: 'Disposable Cache Root',
          path: r'C:\Users\Admin\AppData\Local\AI Companion\Cache',
          exists: false,
          source: 'default',
        ),
        const StorageRootOut(
          key: 'log',
          label: 'Diagnostics & Logs Root',
          path: r'C:\Users\Admin\AppData\Local\AI Companion\Logs',
          exists: true,
          source: 'default',
        ),
      ],
    );
  }

  @override
  Future<StorageRootsResponse> relocateLibraryRoot(
    LibraryRootUpdateRequest request, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    libraryRelocated = true;
    return getStorageRoots();
  }

  @override
  Future<AutostartStatusOut> getAutostartStatus({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return AutostartStatusOut(
      supported: true,
      enabled: autostartEnabled,
      taskRegistered: autostartEnabled,
      taskName: 'AICompanionAutostart',
      minimizedToTray: autostartMinimized,
      command: autostartEnabled ? r'D:\AI-companion\ai_companion_desktop.exe --minimized-to-tray' : null,
      workingDirectory: autostartEnabled ? r'D:\AI-companion' : null,
      statusDetail: autostartEnabled
          ? 'Registered in Windows Task Scheduler (LeastPrivilege, At Logon).'
          : 'Not registered in Windows Task Scheduler.',
    );
  }

  @override
  Future<AutostartStatusOut> updateAutostart(
    AutostartUpdateRequest request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    autostartEnabled = request.enabled;
    autostartMinimized = request.minimizedToTray;
    return getAutostartStatus();
  }
}

void main() {
  testWidgets('M2 Batch E Runtime UI: hardware profile switch, recommended apply, D6 inbox scan/install & uninstall', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final client = FakeM2DesktopClient();
    final tempDir = Directory.systemTemp.createTempSync('m2_ui_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final controller = DesktopSettingsController(
      initialDestination: DesktopNavDestination.settings,
      initialSettingsSection: SettingsSectionId.runtime,
      diagnosticReader: WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Mock\Local',
        fileExistsChecker: (_) => false,
        directoryExistsChecker: (_) => false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CompanionTheme.dark(),
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            client: client,
            clientSettings: _InMemoryDesktopClientSettings(),
            credentialStore: InMemoryCredentialStore('test-token'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Hardware profile selector visible and switches profile
    final ecoChip = find.byKey(const Key('profile_chip_eco'));
    expect(ecoChip, findsOneWidget);
    await tester.ensureVisible(ecoChip);
    await tester.tap(ecoChip);
    await tester.pumpAndSettle();
    expect(client.currentProfile, equals('eco'));

    // Apply recommended profile from Qwen card ('maximum')
    final applyRecBtn = find.byKey(const Key('apply_recommended_profile_qwen3-vl-2b-instruct'));
    expect(applyRecBtn, findsOneWidget);
    await tester.ensureVisible(applyRecBtn);
    await tester.tap(applyRecBtn);
    await tester.pumpAndSettle();
    expect(client.currentProfile, equals('maximum'));

    // Uninstall button present ONLY on installed model card, NOT factory model card
    expect(find.byKey(const Key('delete_model_qwen3-vl-2b-instruct')), findsNothing);
    final deleteBtn = find.byKey(const Key('delete_model_gemma-3-4b-custom'));
    expect(deleteBtn, findsOneWidget);
    await tester.ensureVisible(deleteBtn);
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();
    expect(client.deletedModelId, equals('gemma-3-4b-custom'));

    // D6 Scan Inbox + Install Bundle
    final scanBtn = find.byKey(const Key('d6_scan_inbox_button'));
    expect(scanBtn, findsOneWidget);
    await tester.ensureVisible(scanBtn);
    await tester.tap(scanBtn);
    await tester.pumpAndSettle();
    expect(client.scanCalls, equals(1));
    expect(find.textContaining('llama3.gguf'), findsOneWidget);

    final installBtn = find.byKey(const Key('d6_install_candidate_llama3-8b-q4'));
    expect(installBtn, findsOneWidget);
    await tester.ensureVisible(installBtn);
    await tester.tap(installBtn);
    await tester.pumpAndSettle();
    expect(client.installedModelId, equals('llama3-8b-q4'));
  });

  testWidgets('M2 Batch E Storage & General UI: 5-root relocation and Windows autostart toggle', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final client = FakeM2DesktopClient();
    final controller = DesktopSettingsController(
      initialDestination: DesktopNavDestination.settings,
      initialSettingsSection: SettingsSectionId.storage,
      diagnosticReader: WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Mock\Local',
        fileExistsChecker: (_) => false,
        directoryExistsChecker: (_) => false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CompanionTheme.dark(),
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            client: client,
            clientSettings: _InMemoryDesktopClientSettings(),
            credentialStore: InMemoryCredentialStore('test-token'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Live 5-root backend card + relocation flow
    expect(find.textContaining(r'D:\CompanionLib'), findsWidgets);
    final relocInput = find.byKey(const Key('relocate_library_root_input'));
    expect(relocInput, findsOneWidget);
    await tester.ensureVisible(relocInput);
    await tester.enterText(relocInput, r'E:\MovedLibrary');
    final relocBtn = find.byKey(const Key('relocate_library_root_button'));
    await tester.ensureVisible(relocBtn);
    await tester.tap(relocBtn);
    await tester.pumpAndSettle();
    expect(client.libraryRelocated, isTrue);
    expect(find.textContaining(r'E:\MovedLibrary'), findsWidgets);

    // Switch to General & Lifecycle and toggle Windows Autostart
    await tester.tap(find.byKey(const Key('settings_nav_general')));
    await tester.pumpAndSettle();

    final autostartSwitch = find.byKey(const Key('autostart_enabled_switch'));
    expect(autostartSwitch, findsOneWidget);
    await tester.ensureVisible(autostartSwitch);
    await tester.tap(autostartSwitch);
    await tester.pumpAndSettle();
    expect(client.autostartEnabled, isTrue);
  });

  testWidgets('Slice 5 Consumer UX: native folder picker, cross-tab sync, >8K experimental context & Add Model Files copy/move', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final tempDir = Directory.systemTemp.createTempSync('m2_slice5_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final pickedFolder = '${tempDir.path}${Platform.pathSeparator}MovedLib';
    final pickedFile = File('${tempDir.path}${Platform.pathSeparator}custom.gguf');
    pickedFile.writeAsBytesSync(const [71, 71, 85, 70]);

    final fakeShell = _FakeDesktopShellAdapter(
      folderResult: pickedFolder,
      filesResult: [pickedFile.path],
    );
    final inboxDir = Directory('${tempDir.path}${Platform.pathSeparator}Inbox');
    final client = _SyncAwareFakeClient(initialInbox: inboxDir.path)
      ..scanWarnings = const [
        "Blocked unsafe Python pickle file 'unsafe.pt' for security (Safe Model Format policy). Use a safe .gguf model instead.",
      ];

    final controller = DesktopSettingsController(
      initialDestination: DesktopNavDestination.settings,
      initialSettingsSection: SettingsSectionId.storage,
      diagnosticReader: WindowsStorageDiagnosticReader(
        localAppDataOverride: r'C:\Mock\Local',
        fileExistsChecker: (_) => false,
        directoryExistsChecker: (_) => false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CompanionTheme.dark(),
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            client: client,
            shellAdapter: fakeShell,
            clientSettings: _InMemoryDesktopClientSettings(),
            credentialStore: InMemoryCredentialStore('test-token'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Native Choose Folder populates destination & Move Library syncs Runtime tab
    await tester.tap(find.byKey(const Key('choose_library_folder_button')));
    await tester.pumpAndSettle();
    expect(fakeShell.pickFolderCalls, equals(1));
    final field = tester.widget<TextField>(
      find.byKey(const Key('relocate_library_root_input')),
    );
    expect(field.controller?.text, equals(pickedFolder));

    await tester.tap(find.byKey(const Key('relocate_library_root_button')));
    await tester.pumpAndSettle();
    expect(controller.storageRevision, equals(1));

    // Switch to AI & Local Models -> updated library path synced automatically
    await tester.tap(find.byKey(const Key('settings_nav_runtime')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Library: '), findsOneWidget);

    // 2. Experimental >8K Context selector + warning
    await tester.tap(find.byKey(const Key('experimental_context_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ctx_mode_16k')));
    await tester.pumpAndSettle();
    expect(client.currentContextMode, equals('16k'));
    expect(find.textContaining('Experimental Warning:'), findsOneWidget);

    // 3. Add Model Files (with Move toggle) stages file into inbox & scans
    final moveSwitch = find.byKey(const Key('import_transfer_mode_switch'));
    await tester.ensureVisible(moveSwitch);
    await tester.tap(moveSwitch);
    await tester.pumpAndSettle();
    final browseBtn = find.byKey(const Key('browse_model_files_button'));
    await tester.ensureVisible(browseBtn);
    await tester.tap(browseBtn);
    await tester.pumpAndSettle();
    expect(fakeShell.pickFilesCalls, equals(1));
    expect(pickedFile.existsSync(), isFalse);
    expect(File('${client.currentInbox}${Platform.pathSeparator}custom.gguf').existsSync(), isTrue);
    expect(find.textContaining("Blocked unsafe Python pickle file 'unsafe.pt'"), findsOneWidget);
  });

  test('WindowsShellAdapter stageFilesToInbox copies and moves real files asynchronously', () async {
    final tempDir = Directory.systemTemp.createTempSync('m2_shell_stage_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final inbox = Directory('${tempDir.path}${Platform.pathSeparator}inbox');
    final copySrc = File('${tempDir.path}${Platform.pathSeparator}copy_me.gguf')
      ..writeAsBytesSync(const [1, 2, 3]);
    final moveSrc = File('${tempDir.path}${Platform.pathSeparator}move_me.gguf')
      ..writeAsBytesSync(const [4, 5, 6]);

    final adapter = WindowsShellAdapter();
    final copied = await adapter.stageFilesToInbox(
      sourcePaths: [copySrc.path],
      inboxDir: inbox.path,
      moveFiles: false,
    );
    expect(copied, equals(1));
    expect(copySrc.existsSync(), isTrue);
    expect(File('${inbox.path}${Platform.pathSeparator}copy_me.gguf').existsSync(), isTrue);

    final moved = await adapter.stageFilesToInbox(
      sourcePaths: [moveSrc.path],
      inboxDir: inbox.path,
      moveFiles: true,
    );
    expect(moved, equals(1));
    expect(moveSrc.existsSync(), isFalse);
    expect(File('${inbox.path}${Platform.pathSeparator}move_me.gguf').existsSync(), isTrue);
  });
}

class _FakeDesktopShellAdapter implements DesktopShellAdapter {
  _FakeDesktopShellAdapter({
    this.folderResult,
    this.filesResult = const [],
  });

  final String? folderResult;
  final List<String> filesResult;
  int pickFolderCalls = 0;
  int pickFilesCalls = 0;

  @override
  Future<String?> pickFolder({String? title, String? initialDirectory}) async {
    pickFolderCalls++;
    return folderResult;
  }

  @override
  Future<List<String>> pickModelFiles({
    String? title,
    bool allowMultiple = true,
    String? initialDirectory,
  }) async {
    pickFilesCalls++;
    return filesResult;
  }

  @override
  Future<void> openFolder(String path, {bool createIfMissing = false}) async {}

  @override
  Future<int> stageFilesToInbox({
    required List<String> sourcePaths,
    required String inboxDir,
    required bool moveFiles,
  }) async {
    final destDir = Directory(inboxDir);
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }
    int count = 0;
    for (final rawPath in sourcePaths) {
      final srcFile = File(rawPath);
      if (!srcFile.existsSync()) continue;
      final fileName = srcFile.uri.pathSegments.lastWhere(
        (s) => s.isNotEmpty,
        orElse: () => 'model.gguf',
      );
      final destPath = '${destDir.path}${Platform.pathSeparator}$fileName';
      if (moveFiles) {
        srcFile.renameSync(destPath);
      } else {
        srcFile.copySync(destPath);
      }
      count++;
    }
    return count;
  }
}

class _SyncAwareFakeClient extends FakeM2DesktopClient {
  _SyncAwareFakeClient({required this.initialInbox});
  final String initialInbox;
  String get currentInbox => libraryRelocated ? '${initialInbox}_moved' : initialInbox;

  @override
  Future<StorageRootsResponse> getStorageRoots({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final libPath = libraryRelocated ? r'E:\MovedLibrary' : r'D:\CompanionLib';
    return StorageRootsResponse(
      bootstrapPath: r'C:\Users\Admin\AppData\Local\AI Companion\bootstrap.json',
      libraryRoot: libPath,
      importInboxDir: currentInbox,
      libraryRelocatable: true,
      roots: [
        StorageRootOut(
          key: 'library',
          label: 'Asset & Model Library Root',
          path: libPath,
          exists: true,
          source: libraryRelocated ? 'bootstrap' : 'default',
        ),
      ],
    );
  }

  @override
  Future<ModelImportScanOut> scanModelImportInbox({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    scanCalls++;
    return ModelImportScanOut(
      inboxDir: currentInbox,
      warnings: scanWarnings,
      candidates: const [],
    );
  }
}
