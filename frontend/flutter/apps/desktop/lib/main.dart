import 'dart:io';

import 'package:companion_design/companion_design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

import 'lifecycle/desktop_lifecycle_coordinator.dart';
import 'lifecycle/live_desktop_adapters.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final coordinator = DesktopLifecycleCoordinator(
    windowAdapter: const LiveDesktopWindowAdapter(),
    trayAdapter: const LiveDesktopTrayAdapter(),
    onExitRequested: () async {
      exit(0);
    },
  );

  await coordinator.initialize();

  runApp(AiCompanionDesktopApp(coordinator: coordinator));

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

class AiCompanionDesktopApp extends StatelessWidget {
  const AiCompanionDesktopApp({
    super.key,
    this.coordinator,
  });

  final DesktopLifecycleCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: CompanionColors.lightAppBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: CompanionColors.lightAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CompanionColors.darkAppBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: CompanionColors.darkAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: DesktopFoundationScreen(coordinator: coordinator),
    );
  }
}

class DesktopFoundationScreen extends StatelessWidget {
  const DesktopFoundationScreen({
    super.key,
    this.coordinator,
  });

  final DesktopLifecycleCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? CompanionColors.darkSurfacePrimary
        : CompanionColors.lightSurfacePrimary;
    final textColor = isDark
        ? CompanionColors.darkTextPrimary
        : CompanionColors.lightTextPrimary;
    final subtitleColor = isDark
        ? CompanionColors.darkTextSecondary
        : CompanionColors.lightTextSecondary;

    final isTrayAvailable = coordinator?.isTrayAvailable ?? false;

    return Scaffold(
      body: Center(
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark
                      ? CompanionColors.darkAccent.withValues(alpha: 0.15)
                      : CompanionColors.lightAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.desktop_windows_rounded,
                  size: 32,
                  color: isDark
                      ? CompanionColors.darkAccent
                      : CompanionColors.lightAccent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'AI Companion',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Windows Window & Tray Lifecycle (M1 Batch 2)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: CompanionColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Window Constraints: 1280x800 (1024x640 min)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isTrayAvailable
                          ? 'System Tray: Active (Close-to-Tray Active)'
                          : 'System Tray: Unavailable (Close Exits App)',
                      style: TextStyle(
                        fontSize: 11,
                        color: subtitleColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const SizedBox(width: 12),
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
        ),
      ),
    );
  }
}
