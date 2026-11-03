import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'character_stage_presenter.dart';

/// Layer 1: Unobstructed center Character Showcase Stage with zoom/pan and stage controls.
class CharacterShowcaseStage extends StatelessWidget {
  const CharacterShowcaseStage({
    super.key,
    required this.spec,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    this.onPanUpdate,
    required this.onSelectBackdrop,
    this.isCompactMode = false,
    this.onToggleDrawer,
  });

  final CharacterStageVisualSpec spec;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final ValueChanged<Offset>? onPanUpdate;
  final ValueChanged<StudioBackdropPreset> onSelectBackdrop;
  final bool isCompactMode;
  final VoidCallback? onToggleDrawer;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    // Resolve portrait asset path from avatarAsset string (seeded IDs or null fallback)
    final assetPath = CharacterStagePresenter.resolveAvatarPath(spec.avatarAsset);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Center Character Figure with interactive zoom scale & pan translation
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: onPanUpdate != null ? (details) => onPanUpdate!(details.delta) : null,
                child: Center(
                  child: Transform.translate(
                    offset: spec.panOffset,
                    child: Transform.scale(
                      scale: spec.zoomLevel,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
                        child: assetPath != null
                            ? Image.asset(
                                assetPath,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return ArchetypeSilhouetteStageWidget(name: spec.displayName);
                                },
                              )
                            : ArchetypeSilhouetteStageWidget(name: spec.displayName),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Top Floating Identity & Status Pills
            Positioned(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Compact mode: Library Drawer Toggle
                  if (isCompactMode && onToggleDrawer != null)
                    NeumorphicButton(
                      size: NeumorphicButtonSize.sm,
                      onPressed: onToggleDrawer,
                      icon: const Icon(Icons.view_sidebar_rounded, size: 16),
                      child: const Text('Library'),
                    )
                  else
                    const SizedBox.shrink(),

                  // Identity Pill: Name & Status
                  Flexible(
                    child: SoftGlassPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                      borderRadius: CompanionRadius.borderFull,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              spec.displayName,
                              style: CompanionTypography.titleMedium.copyWith(
                                color: ext?.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (spec.badgeText.isNotEmpty) ...[
                            const SizedBox(width: 8.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: spec.badgeText == 'Active in Chat'
                                    ? (ext?.success ?? Colors.green).withValues(alpha: 0.2)
                                    : (ext?.accent ?? Colors.blue).withValues(alpha: 0.2),
                                borderRadius: CompanionRadius.borderFull,
                                border: Border.all(
                                  color: spec.badgeText == 'Active in Chat'
                                      ? (ext?.success ?? Colors.green).withValues(alpha: 0.5)
                                      : (ext?.accent ?? Colors.blue).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (spec.badgeText == 'Active in Chat') ...[
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 12,
                                      color: ext?.success ?? Colors.green,
                                    ),
                                    const SizedBox(width: 4.0),
                                  ],
                                  Text(
                                    spec.badgeText,
                                    style: CompanionTypography.caption.copyWith(
                                      color: spec.badgeText == 'Active in Chat'
                                          ? (ext?.success ?? Colors.green)
                                          : (ext?.accent ?? Colors.blue),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Spacer to balance compact mode button
                  if (isCompactMode && onToggleDrawer != null)
                    const SizedBox(width: 40)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),

            // 3. Bottom Floating Stage Toolbar (Zoom & Backdrop)
            Positioned(
              bottom: 16.0,
              child: SoftGlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                borderRadius: CompanionRadius.borderFull,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      tooltip: 'Zoom Out',
                      onPressed: spec.zoomLevel > 1.0 ? onZoomOut : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    TextButton(
                      onPressed: onResetZoom,
                      child: Text(
                        '${(spec.zoomLevel * 100).toInt()}%',
                        style: CompanionTypography.caption.copyWith(
                          color: ext?.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      tooltip: 'Zoom In',
                      onPressed: spec.zoomLevel < 2.0 ? onZoomIn : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: SizedBox(
                        height: 20,
                        child: VerticalDivider(
                          color: ext?.borderSubtle,
                          thickness: 1,
                        ),
                      ),
                    ),
                    PopupMenuButton<StudioBackdropPreset>(
                      icon: const Icon(Icons.wallpaper_rounded, size: 18),
                      tooltip: 'Backdrop: ${spec.backdropPreset.label}',
                      initialValue: spec.backdropPreset,
                      onSelected: onSelectBackdrop,
                      itemBuilder: (context) {
                        return StudioBackdropPreset.values.map((p) {
                          return PopupMenuItem<StudioBackdropPreset>(
                            value: p,
                            child: Row(
                              children: [
                                Icon(
                                  p == spec.backdropPreset
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 16,
                                  color: ext?.accent,
                                ),
                                const SizedBox(width: 8.0),
                                Text(p.label),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Stylized silhouette avatar widget rendered when portrait raster asset is missing.
class ArchetypeSilhouetteStageWidget extends StatelessWidget {
  const ArchetypeSilhouetteStageWidget({
    super.key,
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: (ext?.surfaceElevated ?? const Color(0xFF1E293B)).withValues(alpha: 0.6),
          borderRadius: CompanionRadius.borderXl,
          border: Border.all(
            color: ext?.borderHighlight ?? const Color(0xFF334155),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_pin_rounded,
              size: 84,
              color: ext?.accent ?? Colors.blueAccent,
            ),
            const SizedBox(height: 16.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                name,
                style: CompanionTypography.titleMedium.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
