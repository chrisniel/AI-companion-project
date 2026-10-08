import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/companion_theme_extension.dart';
import '../tokens/color_tokens.dart';
import '../tokens/layout_tokens.dart';

/// Reusable SoftGlass panel applying authentic backdrop blur and translucent physical styling.
class SoftGlassPanel extends StatelessWidget {
  const SoftGlassPanel({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.shadows,
    this.width,
    this.height,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double? blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveRadius = borderRadius ?? CompanionRadius.borderLg;
    final effectiveBlur = blur ?? ext?.glassBlur ?? CompanionColors.glassBlur;
    final effectiveBg = backgroundColor ??
        ext?.surfaceGlass ??
        (isDark ? CompanionColors.darkSurfaceGlass : CompanionColors.lightSurfaceGlass);
    final effectiveBorderColor = borderColor ??
        ext?.surfaceGlassBorder ??
        (isDark
            ? CompanionColors.darkSurfaceGlassBorder
            : CompanionColors.lightSurfaceGlassBorder);
    final effectiveShadows = shadows ??
        (isDark ? CompanionShadows.darkRaised : CompanionShadows.lightRaised);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
      ),
      child: child,
    );

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

    if (effectiveShadows.isNotEmpty) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: effectiveShadows,
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
