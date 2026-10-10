import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/companion_theme_extension.dart';
import '../tokens/color_tokens.dart';
import '../tokens/layout_tokens.dart';

/// Distinct semantic neumorphic and glass surface types matching the web specification.
enum NeumorphicSurfaceType {
  flat,
  raised,
  recessed,
  pressed,
  glass,
  glassElevated,
}

/// Internal custom painter that paints authentic directional inner shadows
/// onto a clipped rounded rectangle canvas.
class _InnerShadowPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final List<CompanionInnerShadow> shadows;

  _InnerShadowPainter({
    required this.borderRadius,
    required this.shadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty || size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    for (final shadow in shadows) {
      if (shadow.color.a == 0.0) continue;

      canvas.save();
      canvas.clipRRect(rrect);

      final sigma = shadow.blurRadius > 0
          ? shadow.blurRadius * 0.57735 + 0.5
          : 0.0;

      final paint = Paint()
        ..color = shadow.color
        ..style = PaintingStyle.fill;

      if (sigma > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
      }

      final extra = shadow.blurRadius * 2 + shadow.offset.distance + 40.0;
      final outerRect = rect.inflate(extra);

      var holeRRect = rrect;
      if (shadow.spreadRadius != 0.0) {
        holeRRect = RRect.fromRectAndCorners(
          rect.deflate(shadow.spreadRadius),
          topLeft: Radius.circular(
            (borderRadius.topLeft.x - shadow.spreadRadius).clamp(0.0, double.infinity),
          ),
          topRight: Radius.circular(
            (borderRadius.topRight.x - shadow.spreadRadius).clamp(0.0, double.infinity),
          ),
          bottomLeft: Radius.circular(
            (borderRadius.bottomLeft.x - shadow.spreadRadius).clamp(0.0, double.infinity),
          ),
          bottomRight: Radius.circular(
            (borderRadius.bottomRight.x - shadow.spreadRadius).clamp(0.0, double.infinity),
          ),
        );
      }
      final shiftedHole = holeRRect.shift(shadow.offset);

      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(outerRect)
        ..addRRect(shiftedHole);

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_InnerShadowPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.shadows != shadows;
  }
}

/// A physical surface container providing directional outer/inner depth,
/// translucent glass backdrop blur, and tactile response states.
class NeumorphicSurface extends StatelessWidget {
  const NeumorphicSurface({
    super.key,
    this.surfaceType = NeumorphicSurfaceType.raised,
    this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.outerShadows,
    this.innerShadows,
    this.width,
    this.height,
  });

  final NeumorphicSurfaceType surfaceType;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? outerShadows;
  final List<CompanionInnerShadow>? innerShadows;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveRadius = borderRadius ?? CompanionRadius.borderLg;
    final effectiveBorderWidth = borderWidth;

    // Resolve surface tokens based on semantic surface type
    Color effectiveBg;
    Color effectiveBorderColor;
    List<BoxShadow> effectiveOuterShadows;
    List<CompanionInnerShadow> effectiveInnerShadows;
    double effectiveBlur;

    switch (surfaceType) {
      case NeumorphicSurfaceType.raised:
        effectiveBg = backgroundColor ??
            ext?.surfaceElevated ??
            (isDark ? CompanionColors.darkSurfaceElevated : CompanionColors.lightSurfaceElevated);
        effectiveBorderColor = borderColor ??
            ext?.borderSubtle ??
            (isDark ? CompanionColors.darkBorderSubtle : CompanionColors.lightBorderSubtle);
        effectiveOuterShadows = outerShadows ??
            (isDark ? CompanionShadows.darkRaised : CompanionShadows.lightRaised);
        effectiveInnerShadows = innerShadows ?? const [];
        effectiveBlur = blur ?? 0.0;
        break;

      case NeumorphicSurfaceType.recessed:
        effectiveBg = backgroundColor ??
            ext?.surfaceRecessed ??
            (isDark ? CompanionColors.darkSurfaceRecessed : CompanionColors.lightSurfaceRecessed);
        effectiveBorderColor = borderColor ??
            ext?.borderSubtle ??
            (isDark ? CompanionColors.darkBorderSubtle : CompanionColors.lightBorderSubtle);
        effectiveOuterShadows = outerShadows ?? const [];
        effectiveInnerShadows = innerShadows ??
            (isDark ? CompanionInnerShadows.darkRecessed : CompanionInnerShadows.lightRecessed);
        effectiveBlur = blur ?? 0.0;
        break;

      case NeumorphicSurfaceType.pressed:
        effectiveBg = backgroundColor ??
            ext?.surfaceRecessed ??
            (isDark ? CompanionColors.darkSurfaceRecessed : CompanionColors.lightSurfaceRecessed);
        effectiveBorderColor = borderColor ??
            ext?.borderSubtle ??
            (isDark ? CompanionColors.darkBorderSubtle : CompanionColors.lightBorderSubtle);
        effectiveOuterShadows = outerShadows ?? const [];
        effectiveInnerShadows = innerShadows ??
            (isDark ? CompanionInnerShadows.darkPressed : CompanionInnerShadows.lightPressed);
        effectiveBlur = blur ?? 0.0;
        break;

      case NeumorphicSurfaceType.glass:
        effectiveBg = backgroundColor ??
            ext?.surfaceGlass ??
            (isDark ? CompanionColors.darkSurfaceGlass : CompanionColors.lightSurfaceGlass);
        effectiveBorderColor = borderColor ??
            ext?.surfaceGlassBorder ??
            (isDark
                ? CompanionColors.darkSurfaceGlassBorder
                : CompanionColors.lightSurfaceGlassBorder);
        effectiveOuterShadows = outerShadows ??
            (isDark ? CompanionShadows.darkGlass : CompanionShadows.lightGlass);
        effectiveInnerShadows = innerShadows ?? const [];
        effectiveBlur = blur ?? ext?.glassBlur ?? CompanionColors.glassBlur;
        break;

      case NeumorphicSurfaceType.glassElevated:
        effectiveBg = backgroundColor ??
            ext?.surfaceGlass ??
            (isDark ? CompanionColors.darkSurfaceGlass : CompanionColors.lightSurfaceGlass);
        effectiveBorderColor = borderColor ??
            ext?.surfaceGlassBorder ??
            (isDark
                ? CompanionColors.darkSurfaceGlassBorder
                : CompanionColors.lightSurfaceGlassBorder);
        effectiveOuterShadows = outerShadows ??
            (isDark ? CompanionShadows.darkGlassElevated : CompanionShadows.lightGlassElevated);
        effectiveInnerShadows = innerShadows ?? const [];
        effectiveBlur = blur ?? (ext != null ? ext.glassBlur * 1.25 : 20.0);
        break;

      case NeumorphicSurfaceType.flat:
        effectiveBg = backgroundColor ??
            ext?.surfacePrimary ??
            (isDark ? CompanionColors.darkSurfacePrimary : CompanionColors.lightSurfacePrimary);
        effectiveBorderColor = borderColor ??
            ext?.borderSubtle ??
            (isDark ? CompanionColors.darkBorderSubtle : CompanionColors.lightBorderSubtle);
        effectiveOuterShadows = outerShadows ?? const [];
        effectiveInnerShadows = innerShadows ?? const [];
        effectiveBlur = blur ?? 0.0;
        break;
    }

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      child: child,
    );

    // Inner shadow painter (placed behind child, above background)
    if (effectiveInnerShadows.isNotEmpty) {
      content = CustomPaint(
        painter: _InnerShadowPainter(
          borderRadius: effectiveRadius,
          shadows: effectiveInnerShadows,
        ),
        child: content,
      );
    }

    // Background and border
    content = DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: effectiveBorderWidth > 0
            ? Border.all(
                color: effectiveBorderColor,
                width: effectiveBorderWidth,
              )
            : null,
      ),
      child: content,
    );

    // Backdrop filter blur for glass surfaces
    if (effectiveBlur > 0) {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur,
            sigmaY: effectiveBlur,
          ),
          child: content,
        ),
      );
    }

    // Outer physical shadows
    if (effectiveOuterShadows.isNotEmpty) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: effectiveOuterShadows,
        ),
        child: content,
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
