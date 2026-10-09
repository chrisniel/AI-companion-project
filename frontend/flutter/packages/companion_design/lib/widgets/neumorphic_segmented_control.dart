import 'package:flutter/material.dart';

import '../theme/companion_theme_extension.dart';
import '../tokens/color_tokens.dart';
import '../tokens/layout_tokens.dart';
import '../tokens/typography.dart';
import 'neumorphic_surface.dart';

/// Specification for a single segment within [NeumorphicSegmentedControl].
@immutable
class NeumorphicSegment<T> {
  const NeumorphicSegment({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// A segmented control matching the web `.segmented-control-item` specifications:
/// recessed tray outer container with embossed active item and inset hover responses.
class NeumorphicSegmentedControl<T> extends StatelessWidget {
  const NeumorphicSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.borderRadius,
  });

  final List<NeumorphicSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? CompanionRadius.borderLg;

    return NeumorphicSurface(
      surfaceType: NeumorphicSurfaceType.recessed,
      borderRadius: effectiveRadius,
      padding: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((segment) {
          final isSelected = segment.value == selected;
          return Expanded(
            child: _SegmentItem<T>(
              segment: segment,
              isSelected: isSelected,
              onTap: () => onChanged(segment.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SegmentItem<T> extends StatefulWidget {
  const _SegmentItem({
    super.key,
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final NeumorphicSegment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SegmentItem<T>> createState() => _SegmentItemState<T>();
}

class _SegmentItemState<T> extends State<_SegmentItem<T>> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSelected = widget.isSelected;

    // Determine visual decoration matching web index.css .segmented-control-item
    Widget itemSurface;
    Color contentColor;

    if (isSelected) {
      final outerShadows = isDark
          ? (_isHovered
              ? CompanionShadows.darkNavEmbossedHover
              : CompanionShadows.darkNavEmbossed)
          : (_isHovered
              ? CompanionShadows.lightNavEmbossedHover
              : CompanionShadows.lightNavEmbossed);
      final borderColor = isDark
          ? CompanionColors.darkBorderHighlight
          : CompanionColors.lightBorderHighlight;

      contentColor = ext?.accent ?? CompanionColors.lightAccent;

      itemSurface = NeumorphicSurface(
        surfaceType: NeumorphicSurfaceType.raised,
        borderRadius: CompanionRadius.borderMd,
        borderColor: borderColor,
        outerShadows: outerShadows,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: _buildContent(contentColor, FontWeight.w600),
      );
    } else if (_isPressed) {
      contentColor = ext?.textPrimary ?? CompanionColors.lightTextPrimary;

      itemSurface = NeumorphicSurface(
        surfaceType: NeumorphicSurfaceType.pressed,
        borderRadius: CompanionRadius.borderMd,
        innerShadows: isDark
            ? CompanionInnerShadows.darkNavPressed
            : CompanionInnerShadows.lightNavPressed,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: _buildContent(contentColor, FontWeight.w500),
      );
    } else if (_isHovered) {
      contentColor = ext?.textPrimary ?? CompanionColors.lightTextPrimary;

      itemSurface = NeumorphicSurface(
        surfaceType: NeumorphicSurfaceType.recessed,
        borderRadius: CompanionRadius.borderMd,
        borderColor: ext?.borderSubtle,
        innerShadows: isDark
            ? CompanionInnerShadows.darkNavInset
            : CompanionInnerShadows.lightNavInset,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: _buildContent(contentColor, FontWeight.w500),
      );
    } else {
      contentColor = ext?.textSecondary ?? CompanionColors.lightTextSecondary;

      itemSurface = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          borderRadius: CompanionRadius.borderMd,
          color: Colors.transparent,
        ),
        child: _buildContent(contentColor, FontWeight.w400),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _isPressed = true),
        onPointerUp: (_) => setState(() => _isPressed = false),
        onPointerCancel: (_) => setState(() => _isPressed = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: itemSurface,
        ),
      ),
    );
  }

  Widget _buildContent(Color color, FontWeight fontWeight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.segment.icon != null) ...[
          Icon(widget.segment.icon, size: 16, color: color),
          const SizedBox(width: CompanionSpacing.xs),
        ],
        Text(
          widget.segment.label,
          style: CompanionTypography.bodySmall.copyWith(
            color: color,
            fontWeight: fontWeight,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
