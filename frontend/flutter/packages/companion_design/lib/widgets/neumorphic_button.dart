import 'package:flutter/material.dart';

import '../theme/companion_theme_extension.dart';
import '../tokens/color_tokens.dart';
import '../tokens/layout_tokens.dart';
import '../tokens/typography.dart';
import 'neumorphic_surface.dart';

/// Predefined button sizes matching the web design tokens.
enum NeumorphicButtonSize {
  sm,
  md,
  lg,
}

/// A tactile neumorphic button supporting physical raised normal, hover elevation,
/// recessed/pressed response, and active selection state.
class NeumorphicButton extends StatefulWidget {
  const NeumorphicButton({
    super.key,
    this.onPressed,
    this.selected = false,
    this.icon,
    this.child,
    this.size = NeumorphicButtonSize.md,
    this.accentOnSelected = true,
    this.tooltip,
    this.padding,
    this.borderRadius,
    this.width,
    this.height,
  });

  final VoidCallback? onPressed;
  final bool selected;
  final Widget? icon;
  final Widget? child;
  final NeumorphicButtonSize size;
  final bool accentOnSelected;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveRadius = widget.borderRadius ??
        switch (widget.size) {
          NeumorphicButtonSize.sm => CompanionRadius.borderSm,
          NeumorphicButtonSize.md => CompanionRadius.borderMd,
          NeumorphicButtonSize.lg => CompanionRadius.borderLg,
        };

    final effectivePadding = widget.padding ??
        switch (widget.size) {
          NeumorphicButtonSize.sm =>
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          NeumorphicButtonSize.md =>
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          NeumorphicButtonSize.lg =>
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        };

    final textStyle = switch (widget.size) {
      NeumorphicButtonSize.sm => CompanionTypography.caption.copyWith(
          fontWeight: FontWeight.w500,
        ),
      NeumorphicButtonSize.md => CompanionTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
      NeumorphicButtonSize.lg => CompanionTypography.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
    };

    final isSelected = widget.selected;
    final isDepressed = isSelected || (_isPressed && _isEnabled);

    // Determine surface type & shadows
    NeumorphicSurfaceType surfaceType;
    List<BoxShadow>? outerShadows;
    List<CompanionInnerShadow>? innerShadows;
    Color? borderColor;

    if (!_isEnabled) {
      surfaceType = NeumorphicSurfaceType.flat;
      outerShadows = const [];
      innerShadows = const [];
    } else if (isDepressed) {
      surfaceType = NeumorphicSurfaceType.pressed;
      innerShadows = isDark
          ? CompanionInnerShadows.darkPressed
          : CompanionInnerShadows.lightPressed;
      if (isSelected && widget.accentOnSelected) {
        borderColor = ext?.accent ?? CompanionColors.lightAccent;
      }
    } else if (_isHovered) {
      surfaceType = NeumorphicSurfaceType.raised;
      outerShadows = isDark
          ? CompanionShadows.darkRaisedHover
          : CompanionShadows.lightRaisedHover;
    } else {
      surfaceType = NeumorphicSurfaceType.raised;
      outerShadows = isDark
          ? CompanionShadows.darkRaised
          : CompanionShadows.lightRaised;
    }

    // Determine text and icon color
    Color contentColor;
    if (!_isEnabled) {
      contentColor = ext?.textMuted ?? CompanionColors.lightTextMuted;
    } else if (isSelected && widget.accentOnSelected) {
      contentColor = ext?.accent ?? CompanionColors.lightAccent;
    } else if (_isHovered) {
      contentColor = ext?.textPrimary ?? CompanionColors.lightTextPrimary;
    } else {
      contentColor = ext?.textSecondary ?? CompanionColors.lightTextSecondary;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          IconTheme(
            data: IconThemeData(
              size: widget.size == NeumorphicButtonSize.sm ? 16 : 18,
              color: contentColor,
            ),
            child: widget.icon!,
          ),
          if (widget.child != null)
            SizedBox(
              width: widget.size == NeumorphicButtonSize.sm
                  ? CompanionSpacing.xs
                  : CompanionSpacing.sm,
            ),
        ],
        if (widget.child != null)
          DefaultTextStyle(
            style: textStyle.copyWith(color: contentColor),
            child: widget.child!,
          ),
      ],
    );

    Widget button = MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (_isEnabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isEnabled) {
          setState(() {
            _isHovered = false;
            _isPressed = false;
          });
        }
      },
      child: Listener(
        onPointerDown: (_) {
          if (_isEnabled) setState(() => _isPressed = true);
        },
        onPointerUp: (_) {
          if (_isEnabled) setState(() => _isPressed = false);
        },
        onPointerCancel: (_) {
          if (_isEnabled) setState(() => _isPressed = false);
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _isEnabled ? 1.0 : 0.45,
            child: NeumorphicSurface(
              surfaceType: surfaceType,
              width: widget.width,
              height: widget.height,
              borderRadius: effectiveRadius,
              padding: effectivePadding,
              borderColor: borderColor,
              outerShadows: outerShadows,
              innerShadows: innerShadows,
              child: content,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: button,
      );
    }

    return button;
  }
}
