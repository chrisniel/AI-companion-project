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

/// Elevation and SoftGlass physical shadow definitions.
abstract final class CompanionShadows {
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

  static const List<BoxShadow> lightElevated = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.10),
      blurRadius: 36,
      offset: Offset(0, 16),
    ),
  ];

  static const List<BoxShadow> darkRaised = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.62),
      blurRadius: 14,
      offset: Offset(4, 4),
    ),
  ];

  static const List<BoxShadow> darkElevated = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.75),
      blurRadius: 32,
      offset: Offset(0, 14),
    ),
  ];
}
