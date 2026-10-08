import 'dart:io';

import 'package:companion_design/companion_design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

import 'controllers/desktop_settings_controller.dart';
import 'harness/visual_evidence_runner.dart';
import 'lifecycle/desktop_lifecycle_coordinator.dart';
import 'lifecycle/live_desktop_adapters.dart';
import 'shell/desktop_shell.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  ThemeMode initialThemeMode = ThemeMode.system;
  AccentPreset initialPreset = AccentPreset.oceanSky;
  bool initialRailCollapsed = false;
  DesktopNavDestination initialDestination = DesktopNavDestination.chat;
  bool initialScrollDiagnostics = false;
  Size? initialSize;

  if (kDebugMode) {
    if (args.contains('--theme-light')) {
      initialThemeMode = ThemeMode.light;
    } else if (args.contains('--theme-dark')) {
      initialThemeMode = ThemeMode.dark;
    }
    if (args.contains('--accent-amethyst')) {
      initialPreset = AccentPreset.amethystViolet;
    } else if (args.contains('--accent-oceansky')) {
      initialPreset = AccentPreset.oceanSky;
    }
    if (args.contains('--rail-collapsed')) {
      initialRailCollapsed = true;
    }
    if (args.contains('--nav-settings')) {
      initialDestination = DesktopNavDestination.settings;
    }
    if (args.contains('--scroll-diagnostics')) {
      initialScrollDiagnostics = true;
    }
    if (args.contains('--size-1024x640')) {
      initialSize = const Size(1024, 640);
    }
  }

  final coordinator = DesktopLifecycleCoordinator(
    windowAdapter: const LiveDesktopWindowAdapter(),
    trayAdapter: const LiveDesktopTrayAdapter(),
    onExitRequested: () async {
      exit(0);
    },
  );

  await coordinator.initialize(initialWindowSize: initialSize);

  if (kDebugMode && args.contains('--capture-visual-evidence')) {
    final outputDirArg = args.firstWhere(
      (a) => a.startsWith('--output-dir='),
      orElse: () => '--output-dir=${Platform.environment['TEMP']}\\ai_companion_visual_review',
    );
    final outputDir = outputDirArg.substring('--output-dir='.length);
    Directory(outputDir).createSync(recursive: true);

    runApp(
      VisualEvidenceCaptureApp(
        outputDirectory: outputDir,
        coordinator: coordinator,
      ),
    );
    return;
  }

  final settingsController = DesktopSettingsController(
    initialThemeMode: initialThemeMode,
    initialAccentPreset: initialPreset,
    initialRailCollapsed: initialRailCollapsed,
    initialDestination: initialDestination,
    initialScrollToDiagnostics: initialScrollDiagnostics,
  );

  runApp(
    AiCompanionDesktopApp(
      coordinator: coordinator,
      settingsController: settingsController,
    ),
  );

  // Automated native test harness restricted strictly to debug mode
  if (kDebugMode) {
    if (args.contains('--test-graceful-exit')) {
      Future<void>.delayed(const Duration(milliseconds: 1500), () async {
        await coordinator.handleExitRequested();
      });
    } else if (args.contains('--test-tray-exit')) {
      Future<void>.delayed(const Duration(milliseconds: 1500), () async {
        coordinator.onTrayMenuItemClick(MenuItem(key: 'exit'));
      });
    }
  }
}

class AiCompanionDesktopApp extends StatefulWidget {
  const AiCompanionDesktopApp({
    super.key,
    this.coordinator,
    this.settingsController,
  });

  final DesktopLifecycleCoordinator? coordinator;
  final DesktopSettingsController? settingsController;

  @override
  State<AiCompanionDesktopApp> createState() => _AiCompanionDesktopAppState();
}

class _AiCompanionDesktopAppState extends State<AiCompanionDesktopApp> {
  late final DesktopSettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.settingsController ?? DesktopSettingsController();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'AI Companion',
          debugShowCheckedModeBanner: false,
          theme: CompanionTheme.light(preset: _controller.accentPreset),
          darkTheme: CompanionTheme.dark(preset: _controller.accentPreset),
          themeMode: _controller.themeMode,
          home: DesktopShell(
            controller: _controller,
            coordinator: widget.coordinator,
          ),
        );
      },
    );
  }
}
