import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import '../features/studio/character_showcase_stage.dart';
import '../features/studio/desktop_studio_controller.dart';
import '../features/studio/studio_backdrop_layer.dart';
import '../features/studio/studio_inspector_panel.dart';
import '../features/studio/studio_library_panel.dart';

/// Immersive, game-inspired Windows Desktop Character Studio V1 (PC-CLIENT-007).
class StudioScreen extends StatefulWidget {
  const StudioScreen({
    super.key,
    required this.controller,
    this.onNavigateToSettings,
  });

  final DesktopStudioController controller;
  final VoidCallback? onNavigateToSettings;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  bool _isDrawerOpen = false;

  void _toggleDrawer() {
    setState(() => _isDrawerOpen = !_isDrawerOpen);
  }

  void _closeDrawer() {
    if (_isDrawerOpen) {
      setState(() => _isDrawerOpen = false);
    }
  }

  Future<bool> _handleItemSwitchGuarded(VoidCallback performSwitch) async {
    final draft = widget.controller.draft;
    if (draft == null || !draft.isDirty) {
      performSwitch();
      _closeDrawer();
      return true;
    }

    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Studio Customizations'),
        content: Text('You have unsaved changes to "${draft.name}". What would you like to do before switching characters?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('stay'),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('Discard Changes'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Save & Continue'),
          ),
        ],
      ),
    );

    if (decision == 'save') {
      final success = await widget.controller.saveDraft();
      if (success) {
        performSwitch();
        _closeDrawer();
        return true;
      }
      return false;
    } else if (decision == 'discard') {
      performSwitch();
      _closeDrawer();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final sessionStatus = widget.controller.sessionStatus;

        // 1. Session Revoked / Unauthorized: Fail closed and require Profile authorization
        if (sessionStatus == StudioSessionStatus.sessionExpiredOrRevoked) {
          return _buildUnauthorizedGate(context);
        }

        // 2. Active Studio Experience
        return Stack(
          fit: StackFit.expand,
          children: [
            // Layer 0: Thematic Full-Content Backdrop
            StudioBackdropLayer(preset: widget.controller.backdropPreset),

            // Layer 1 & 2: Responsive 3-Zone Workspace
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = constraints.maxWidth;

                  // Mode 1: Wide 3-Column Studio (>= 1120px)
                  if (contentWidth >= 1120) {
                    return _buildWideLayout(context, contentWidth);
                  }

                  // Mode 2: Standard 3-Column Studio (920px .. 1119px)
                  if (contentWidth >= 920) {
                    return _buildStandardLayout(context, contentWidth);
                  }

                  // Mode 3: Compact 2-Column Studio + Slide-over Drawer (< 920px)
                  return _buildCompactLayout(context, contentWidth);
                },
              ),
            ),

            // Transient probe banner
            if (sessionStatus == StudioSessionStatus.validatingConnection)
              _buildTransientProbeBanner(context, 'Verifying connection with local runtime...'),

            // Runtime offline banner
            if (sessionStatus == StudioSessionStatus.runtimeOffline)
              _buildRuntimeOfflineBanner(context),
          ],
        );
      },
    );
  }

  Widget _buildWideLayout(BuildContext context, double contentWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Dock: Library
          SizedBox(
            width: 272,
            child: StudioLibraryPanel(
              controller: widget.controller,
              onSelectTemplate: (t) => _handleItemSwitchGuarded(() => widget.controller.selectTemplate(t)),
              onSelectInstance: (i) => _handleItemSwitchGuarded(() => widget.controller.selectInstance(i)),
              onSelectNeutral: () => _handleItemSwitchGuarded(widget.controller.selectNeutral),
            ),
          ),
          const SizedBox(width: 16.0),

          // Center Stage: Character Showcase
          Expanded(
            child: CharacterShowcaseStage(
              spec: widget.controller.visualSpec,
              onZoomIn: widget.controller.zoomIn,
              onZoomOut: widget.controller.zoomOut,
              onResetZoom: widget.controller.resetZoom,
              onSelectBackdrop: widget.controller.setBackdropPreset,
            ),
          ),
          const SizedBox(width: 16.0),

          // Right Dock: Customization Inspector
          SizedBox(
            width: 384,
            child: StudioInspectorPanel(
              controller: widget.controller,
              onSave: widget.controller.saveDraft,
              onActivate: widget.controller.activateCharacter,
              onResetNeutral: widget.controller.resetProfileToNeutral,
              onArchive: widget.controller.archiveInstance,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(BuildContext context, double contentWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Dock: Library
          SizedBox(
            width: 228,
            child: StudioLibraryPanel(
              controller: widget.controller,
              onSelectTemplate: (t) => _handleItemSwitchGuarded(() => widget.controller.selectTemplate(t)),
              onSelectInstance: (i) => _handleItemSwitchGuarded(() => widget.controller.selectInstance(i)),
              onSelectNeutral: () => _handleItemSwitchGuarded(widget.controller.selectNeutral),
            ),
          ),
          const SizedBox(width: 12.0),

          // Center Stage: Character Showcase
          Expanded(
            child: CharacterShowcaseStage(
              spec: widget.controller.visualSpec,
              onZoomIn: widget.controller.zoomIn,
              onZoomOut: widget.controller.zoomOut,
              onResetZoom: widget.controller.resetZoom,
              onSelectBackdrop: widget.controller.setBackdropPreset,
            ),
          ),
          const SizedBox(width: 12.0),

          // Right Dock: Customization Inspector
          SizedBox(
            width: 336,
            child: StudioInspectorPanel(
              controller: widget.controller,
              onSave: widget.controller.saveDraft,
              onActivate: widget.controller.activateCharacter,
              onResetNeutral: widget.controller.resetProfileToNeutral,
              onArchive: widget.controller.archiveInstance,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context, double contentWidth) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Center Stage with Library button
              Expanded(
                child: CharacterShowcaseStage(
                  spec: widget.controller.visualSpec,
                  onZoomIn: widget.controller.zoomIn,
                  onZoomOut: widget.controller.zoomOut,
                  onResetZoom: widget.controller.resetZoom,
                  onSelectBackdrop: widget.controller.setBackdropPreset,
                  isCompactMode: true,
                  onToggleDrawer: _toggleDrawer,
                ),
              ),
              const SizedBox(width: 12.0),

              // Right Dock: Customization Inspector
              SizedBox(
                width: 328,
                child: StudioInspectorPanel(
                  controller: widget.controller,
                  onSave: widget.controller.saveDraft,
                  onActivate: widget.controller.activateCharacter,
                  onResetNeutral: widget.controller.resetProfileToNeutral,
                  onArchive: widget.controller.archiveInstance,
                ),
              ),
            ],
          ),
        ),

        // Slide-over Library Drawer with backdrop dismissal
        if (_isDrawerOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDrawer,
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          Positioned(
            top: 10.0,
            bottom: 10.0,
            left: 12.0,
            width: 268,
            child: StudioLibraryPanel(
              controller: widget.controller,
              onSelectTemplate: (t) => _handleItemSwitchGuarded(() => widget.controller.selectTemplate(t)),
              onSelectInstance: (i) => _handleItemSwitchGuarded(() => widget.controller.selectInstance(i)),
              onSelectNeutral: () => _handleItemSwitchGuarded(widget.controller.selectNeutral),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUnauthorizedGate(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SoftGlassPanel(
          padding: const EdgeInsets.all(24.0),
          borderRadius: CompanionRadius.borderXl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_person_outlined, size: 54, color: ext?.accent),
              const SizedBox(height: 16.0),
              Text(
                'Profile Access Required',
                style: CompanionTypography.titleLarge.copyWith(color: ext?.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10.0),
              Text(
                'Character Studio customization requires an active Profile session. Select a Profile in Settings to access and customize your characters.',
                style: CompanionTypography.bodyMedium.copyWith(color: ext?.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24.0),
              if (widget.onNavigateToSettings != null)
                NeumorphicButton(
                  onPressed: widget.onNavigateToSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  child: const Text('Go to Settings'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransientProbeBanner(BuildContext context, String text) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return Positioned(
      top: 12.0,
      left: 0,
      right: 0,
      child: Center(
        child: SoftGlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
          borderRadius: CompanionRadius.borderFull,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: ext?.accent),
              ),
              const SizedBox(width: 8.0),
              Text(
                text,
                style: CompanionTypography.caption.copyWith(color: ext?.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuntimeOfflineBanner(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return Positioned(
      top: 12.0,
      left: 0,
      right: 0,
      child: Center(
        child: SoftGlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
          borderRadius: CompanionRadius.borderFull,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 14, color: ext?.warning),
              const SizedBox(width: 8.0),
              Text(
                'Local AI Runtime unreachable — draft preserved locally',
                style: CompanionTypography.caption.copyWith(color: ext?.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
