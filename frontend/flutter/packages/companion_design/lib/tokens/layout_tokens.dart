import 'package:flutter/material.dart';

/// Standard spacing scale matching design system rhythm.
abstract final class CompanionSpacing {
  static const double none = 0.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Standard corner radiuses for surfaces, cards, buttons, and chips.
abstract final class CompanionRadius {
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 18.0;
  static const double full = 999.0;

  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderFull = BorderRadius.all(Radius.circular(full));
}

/// Elevation and SoftGlass physical shadow definitions strictly matched to frontend index.css.
abstract final class CompanionShadows {
  // Light Mode Outer Shadows
  static const List<BoxShadow> lightRaised = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.06),
      blurRadius: 14,
      offset: Offset(2, 4),
    ),
    BoxShadow(
      color: Color.fromRGBO(255, 255, 255, 0.95),
      blurRadius: 10,
      offset: Offset(-2, -2),
    ),
  ];

  static const List<BoxShadow> lightRaisedHover = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.10),
      blurRadius: 20,
      offset: Offset(3, 8),
    ),
    BoxShadow(
      color: Color(0xFFFFFFFF),
      blurRadius: 14,
      offset: Offset(-3, -3),
    ),
  ];

  static const List<BoxShadow> lightNavEmbossed = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.08),
      blurRadius: 6,
      offset: Offset(1, 2),
    ),
    BoxShadow(
      color: Color.fromRGBO(255, 255, 255, 0.90),
      blurRadius: 4,
      offset: Offset(-1, -1),
    ),
  ];

  static const List<BoxShadow> lightNavEmbossedHover = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.12),
      blurRadius: 10,
      offset: Offset(2, 4),
    ),
    BoxShadow(
      color: Color(0xFFFFFFFF),
      blurRadius: 6,
      offset: Offset(-2, -2),
    ),
  ];

  static const List<BoxShadow> lightGlass = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.07),
      blurRadius: 24,
      spreadRadius: -4,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.03),
      blurRadius: 6,
      spreadRadius: -1,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> lightGlassElevated = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.10),
      blurRadius: 36,
      spreadRadius: -6,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.05),
      blurRadius: 12,
      spreadRadius: -2,
      offset: Offset(0, 4),
    ),
  ];

  // Preserved alias for backwards compatibility
  static const List<BoxShadow> lightElevated = lightGlassElevated;

  // Dark Mode Outer Shadows
  static const List<BoxShadow> darkRaised = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.62),
      blurRadius: 14,
      offset: Offset(5, 5),
    ),
    BoxShadow(
      color: Color.fromRGBO(255, 255, 255, 0.035),
      blurRadius: 10,
      offset: Offset(-4, -4),
    ),
  ];

  static const List<BoxShadow> darkRaisedHover = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.75),
      blurRadius: 18,
      offset: Offset(7, 7),
    ),
    BoxShadow(
      color: Color.fromRGBO(255, 255, 255, 0.05),
      blurRadius: 12,
      offset: Offset(-5, -5),
    ),
  ];

  static const List<BoxShadow> darkNavEmbossed = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.60),
      blurRadius: 8,
      offset: Offset(2, 3),
    ),
    BoxShadow(
      color: Color.fromRGBO(255, 255, 255, 0.04),
      blurRadius: 5,
      offset: Offset(-1.5, -1.5),
    ),
  ];

  static const List<BoxShadow> darkNavEmbossedHover = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.72),
      blurRadius: 10,
      offset: Offset(3, 4),
    ),
    BoxShadow(
      color: Color.fromRGBO(255, 255, 255, 0.05),
      blurRadius: 6,
      offset: Offset(-2, -2),
    ),
  ];

  static const List<BoxShadow> darkGlass = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.48),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> darkGlassElevated = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.65),
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
  ];

  // Preserved alias for backwards compatibility
  static const List<BoxShadow> darkElevated = darkGlassElevated;
}

/// Inset shadow specification strictly reproducing CSS `box-shadow: inset ...` behavior.
@immutable
class CompanionInnerShadow {
  final Color color;
  final Offset offset;
  final double blurRadius;
  final double spreadRadius;

  const CompanionInnerShadow({
    required this.color,
    required this.offset,
    required this.blurRadius,
    this.spreadRadius = 0.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanionInnerShadow &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          offset == other.offset &&
          blurRadius == other.blurRadius &&
          spreadRadius == other.spreadRadius;

  @override
  int get hashCode => Object.hash(color, offset, blurRadius, spreadRadius);
}

/// Physical inset / recessed shadow definitions strictly matched to frontend index.css.
abstract final class CompanionInnerShadows {
  // Light Mode Inner Shadows
  static const List<CompanionInnerShadow> lightRecessed = [
    CompanionInnerShadow(
      color: Color.fromRGBO(15, 23, 42, 0.07),
      blurRadius: 6,
      offset: Offset(2, 2),
    ),
    CompanionInnerShadow(
      color: Color.fromRGBO(255, 255, 255, 0.85),
      blurRadius: 6,
      offset: Offset(-2, -2),
    ),
  ];

  static const List<CompanionInnerShadow> lightPressed = [
    CompanionInnerShadow(
      color: Color.fromRGBO(15, 23, 42, 0.10),
      blurRadius: 5,
      offset: Offset(2, 2),
    ),
    CompanionInnerShadow(
      color: Color.fromRGBO(255, 255, 255, 0.90),
      blurRadius: 5,
      offset: Offset(-2, -2),
    ),
  ];

  static const List<CompanionInnerShadow> lightNavInset = [
    CompanionInnerShadow(
      color: Color.fromRGBO(15, 23, 42, 0.08),
      blurRadius: 4,
      offset: Offset(1.5, 1.5),
    ),
    CompanionInnerShadow(
      color: Color.fromRGBO(255, 255, 255, 0.85),
      blurRadius: 4,
      offset: Offset(-1.5, -1.5),
    ),
  ];

  static const List<CompanionInnerShadow> lightNavPressed = [
    CompanionInnerShadow(
      color: Color.fromRGBO(15, 23, 42, 0.12),
      blurRadius: 5,
      offset: Offset(2, 2),
    ),
    CompanionInnerShadow(
      color: Color.fromRGBO(255, 255, 255, 0.90),
      blurRadius: 5,
      offset: Offset(-1.5, -1.5),
    ),
  ];

  // Dark Mode Inner Shadows
  static const List<CompanionInnerShadow> darkRecessed = [
    CompanionInnerShadow(
      color: Color.fromRGBO(0, 0, 0, 0.75),
      blurRadius: 8,
      offset: Offset(3, 3),
    ),
    CompanionInnerShadow(
      color: Color.fromRGBO(255, 255, 255, 0.03),
      blurRadius: 6,
      offset: Offset(-2, -2),
    ),
  ];

  static const List<CompanionInnerShadow> darkPressed = [
    CompanionInnerShadow(
      color: Color.fromRGBO(0, 0, 0, 0.80),
      blurRadius: 5,
      offset: Offset(2, 2),
    ),
    CompanionInnerShadow(
      color: Color.fromRGBO(255, 255, 255, 0.04),
      blurRadius: 5,
      offset: Offset(-2, -2),
    ),
  ];

  static const List<CompanionInnerShadow> darkNavInset = [
    CompanionInnerShadow(
      color: Color.fromRGBO(0, 0, 0, 0.65),
      blurRadius: 5,
      offset: Offset(2, 2),
    ),
    CompanionInnerShadow(
      color: Color.fromRGBO(255, 255, 255, 0.035),
      blurRadius: 4,
      offset: Offset(-1.5, -1.5),
    ),
  ];

  static const List<CompanionInnerShadow> darkNavPressed = [
    CompanionInnerShadow(
      color: Color.fromRGBO(0, 0, 0, 0.80),
      blurRadius: 6,
      offset: Offset(2.5, 2.5),
    ),
    CompanionInnerShadow(
      color: Color.fromRGBO(255, 255, 255, 0.04),
      blurRadius: 5,
      offset: Offset(-2, -2),
    ),
  ];
}
