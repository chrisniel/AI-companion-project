import 'package:flutter/material.dart';

/// Semantic color tokens strictly matched to the canonical frontend index.css.
abstract final class CompanionColors {
  // Light Theme Tokens (Refined Soft Glass)
  static const Color lightAppBg = Color(0xFFF1F5F9);
  static const Color lightSurfacePrimary = Color(0xFFF8FAFC);
  static const Color lightSurfaceSecondary = Color(0xFFE2E8F0);
  static const Color lightSurfaceGlass = Color.fromRGBO(255, 255, 255, 0.78);
  static const Color lightSurfaceGlassBorder = Color.fromRGBO(148, 163, 184, 0.35);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceRecessed = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF334155);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightBorderHighlight = Color.fromRGBO(255, 255, 255, 0.95);
  static const Color lightBorderSubtle = Color.fromRGBO(148, 163, 184, 0.28);
  static const Color lightAccent = Color(0xFF1E40AF);
  static const Color lightAccentSecondary = Color(0xFF2563EB);

  // Dark Theme Tokens
  static const Color darkAppBg = Color(0xFF0B0F17);
  static const Color darkSurfacePrimary = Color(0xFF121824);
  static const Color darkSurfaceSecondary = Color(0xFF1A2232);
  static const Color darkSurfaceGlass = Color.fromRGBO(18, 24, 36, 0.72);
  static const Color darkSurfaceGlassBorder = Color.fromRGBO(255, 255, 255, 0.09);
  static const Color darkSurfaceElevated = Color(0xFF192130);
  static const Color darkSurfaceRecessed = Color(0xFF0C101A);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
  static const Color darkBorderHighlight = Color.fromRGBO(255, 255, 255, 0.12);
  static const Color darkBorderSubtle = Color.fromRGBO(255, 255, 255, 0.06);
  static const Color darkAccent = Color(0xFF38BDF8);
  static const Color darkAccentSecondary = Color(0xFF60A5FA);

  // Status Indicators
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color darkDanger = Color(0xFFF43F5E);

  // SoftGlass Parameters
  static const double glassBlur = 16.0;
  static const double glassOpacityLight = 0.78;
  static const double glassOpacityDark = 0.72;
}

/// Four canonical accent color presets.
enum AccentPreset {
  oceanSky(
    'Ocean Sky',
    Color(0xFF0284C7),
    Color(0xFF38BDF8),
    Color.fromRGBO(56, 189, 248, 0.25),
  ),
  cobaltIndigo(
    'Cobalt Indigo',
    Color(0xFF1D4ED8),
    Color(0xFF60A5FA),
    Color.fromRGBO(96, 165, 250, 0.25),
  ),
  emeraldTeal(
    'Emerald Teal',
    Color(0xFF047857),
    Color(0xFF34D399),
    Color.fromRGBO(52, 211, 153, 0.25),
  ),
  amethystViolet(
    'Amethyst Violet',
    Color(0xFF6D28D9),
    Color(0xFFA855F7),
    Color.fromRGBO(168, 85, 247, 0.25),
  );

  final String label;
  final Color primary;
  final Color secondary;
  final Color glow;

  const AccentPreset(this.label, this.primary, this.secondary, this.glow);
}
