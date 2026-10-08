import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AiCompanionDesktopApp());
}

class AiCompanionDesktopApp extends StatelessWidget {
  const AiCompanionDesktopApp({super.key});

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
      home: const DesktopFoundationScreen(),
    );
  }
}

class DesktopFoundationScreen extends StatelessWidget {
  const DesktopFoundationScreen({super.key});

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

    return Scaffold(
      body: Center(
        child: Container(
          width: 540,
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
                'Desktop Client Foundation (M1 Batch 1)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
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
                    Text(
                      'Windows Native Scaffolding Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
