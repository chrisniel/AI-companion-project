import 'dart:io';
import 'dart:ui' as ui;

import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../controllers/desktop_settings_controller.dart';
import '../lifecycle/desktop_lifecycle_coordinator.dart';
import '../shell/desktop_shell.dart';

class VisualEvidenceViewSpec {
  const VisualEvidenceViewSpec({
    required this.fileName,
    required this.width,
    required this.height,
    required this.themeMode,
    required this.accentPreset,
    required this.destination,
    this.railCollapsed = false,
    this.scrollToDiagnostics = false,
    required this.description,
  });

  final String fileName;
  final double width;
  final double height;
  final ThemeMode themeMode;
  final AccentPreset accentPreset;
  final DesktopNavDestination destination;
  final bool railCollapsed;
  final bool scrollToDiagnostics;
  final String description;
}

const List<VisualEvidenceViewSpec> kVisualReviewSpecs = [
  VisualEvidenceViewSpec(
    fileName: '01_dark_oceansky_chat_expanded_1280x800.png',
    width: 1280,
    height: 800,
    themeMode: ThemeMode.dark,
    accentPreset: AccentPreset.oceanSky,
    destination: DesktopNavDestination.chat,
    description: 'Dark theme, Ocean Sky accent, Chat view, Expanded rail, 1280x800',
  ),
  VisualEvidenceViewSpec(
    fileName: '02_light_oceansky_chat_expanded_1280x800.png',
    width: 1280,
    height: 800,
    themeMode: ThemeMode.light,
    accentPreset: AccentPreset.oceanSky,
    destination: DesktopNavDestination.chat,
    description: 'Light theme, Ocean Sky accent, Chat view, Expanded rail, 1280x800',
  ),
  VisualEvidenceViewSpec(
    fileName: '03_dark_settings_appearance_1280x800.png',
    width: 1280,
    height: 800,
    themeMode: ThemeMode.dark,
    accentPreset: AccentPreset.oceanSky,
    destination: DesktopNavDestination.settings,
    description: 'Dark theme, Settings screen showing Appearance & Theme controls, 1280x800',
  ),
  VisualEvidenceViewSpec(
    fileName: '04_dark_settings_diagnostics_1280x800.png',
    width: 1280,
    height: 800,
    themeMode: ThemeMode.dark,
    accentPreset: AccentPreset.oceanSky,
    destination: DesktopNavDestination.settings,
    scrollToDiagnostics: true,
    description: 'Dark theme, Settings screen scrolled to Storage Diagnostics card, 1280x800',
  ),
  VisualEvidenceViewSpec(
    fileName: '05_dark_chat_collapsed_1280x800.png',
    width: 1280,
    height: 800,
    themeMode: ThemeMode.dark,
    accentPreset: AccentPreset.oceanSky,
    destination: DesktopNavDestination.chat,
    railCollapsed: true,
    description: 'Dark theme, Chat view with Collapsed navigation rail, 1280x800',
  ),
  VisualEvidenceViewSpec(
    fileName: '06_dark_chat_expanded_1024x640.png',
    width: 1024,
    height: 640,
    themeMode: ThemeMode.dark,
    accentPreset: AccentPreset.oceanSky,
    destination: DesktopNavDestination.chat,
    description: 'Dark theme, Chat view at minimum window constraint 1024x640',
  ),
  VisualEvidenceViewSpec(
    fileName: '07_light_settings_1024x640.png',
    width: 1024,
    height: 640,
    themeMode: ThemeMode.light,
    accentPreset: AccentPreset.oceanSky,
    destination: DesktopNavDestination.settings,
    description: 'Light theme, Settings screen at minimum window constraint 1024x640',
  ),
  VisualEvidenceViewSpec(
    fileName: '08_dark_amethyst_chat_1280x800.png',
    width: 1280,
    height: 800,
    themeMode: ThemeMode.dark,
    accentPreset: AccentPreset.amethystViolet,
    destination: DesktopNavDestination.chat,
    description: 'Dark theme, Amethyst Violet accent (alternate preset), Chat view, 1280x800',
  ),
];

class VisualEvidenceCaptureApp extends StatefulWidget {
  const VisualEvidenceCaptureApp({
    super.key,
    required this.outputDirectory,
    this.coordinator,
  });

  final String outputDirectory;
  final DesktopLifecycleCoordinator? coordinator;

  @override
  State<VisualEvidenceCaptureApp> createState() => _VisualEvidenceCaptureAppState();
}

class _VisualEvidenceCaptureAppState extends State<VisualEvidenceCaptureApp> {
  final GlobalKey _boundaryKey = GlobalKey();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCaptureSequence();
    });
  }

  Future<void> _startCaptureSequence() async {
    for (int i = 0; i < kVisualReviewSpecs.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentIndex = i;
      });

      // Allow frames for layout, softglass backdrop filter, and scroll offset settling
      await Future<void>.delayed(const Duration(milliseconds: 700));

      final spec = kVisualReviewSpecs[i];
      try {
        final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final filePath = '${widget.outputDirectory}\\${spec.fileName}';
            final file = File(filePath);
            await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
            debugPrint('VISUAL_EVIDENCE_CAPTURED: ${spec.fileName} (${file.lengthSync()} bytes)');
          }
        }
      } catch (e) {
        debugPrint('VISUAL_EVIDENCE_ERROR: ${spec.fileName}: $e');
      }
    }

    debugPrint('VISUAL_EVIDENCE_ALL_COMPLETE');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final spec = kVisualReviewSpecs[_currentIndex];
    final controller = DesktopSettingsController(
      initialThemeMode: spec.themeMode,
      initialAccentPreset: spec.accentPreset,
      initialRailCollapsed: spec.railCollapsed,
      initialDestination: spec.destination,
      initialScrollToDiagnostics: spec.scrollToDiagnostics,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CompanionTheme.light(preset: spec.accentPreset),
      darkTheme: CompanionTheme.dark(preset: spec.accentPreset),
      themeMode: spec.themeMode,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: _boundaryKey,
            child: SizedBox(
              width: spec.width,
              height: spec.height,
              child: DesktopShell(
                key: ValueKey('shell_${spec.fileName}'),
                controller: controller,
                coordinator: widget.coordinator,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
