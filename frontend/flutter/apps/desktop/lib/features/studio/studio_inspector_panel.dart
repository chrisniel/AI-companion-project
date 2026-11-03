import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'character_stage_presenter.dart';
import 'desktop_studio_controller.dart';

enum StudioInspectorTab {
  personality,
  identity,
  visual,
}

/// Right translucent SoftGlass dock containing Personality tuning, Identity editing, and Action footer.
class StudioInspectorPanel extends StatefulWidget {
  const StudioInspectorPanel({
    super.key,
    required this.controller,
    required this.onSave,
    required this.onActivate,
    required this.onResetNeutral,
    required this.onArchive,
  });

  final DesktopStudioController controller;
  final VoidCallback onSave;
  final ValueChanged<String> onActivate;
  final VoidCallback onResetNeutral;
  final ValueChanged<String> onArchive;

  @override
  State<StudioInspectorPanel> createState() => _StudioInspectorPanelState();
}

class _StudioInspectorPanelState extends State<StudioInspectorPanel> {
  StudioInspectorTab _currentTab = StudioInspectorTab.personality;

  late final TextEditingController _nameController;
  late final TextEditingController _summaryController;
  late final TextEditingController _promptController;
  late final TextEditingController _loreController;

  @override
  void initState() {
    super.initState();
    _initTextControllers();
  }

  void _initTextControllers() {
    final draft = widget.controller.draft;
    _nameController = TextEditingController(text: draft?.name ?? '');
    _summaryController = TextEditingController(text: draft?.summary ?? '');
    _promptController = TextEditingController(text: draft?.systemPrompt ?? '');
    _loreController = TextEditingController(text: draft?.lore ?? '');
  }

  @override
  void didUpdateWidget(covariant StudioInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draft = widget.controller.draft;
    if (draft != null) {
      if (_nameController.text != draft.name) _nameController.text = draft.name;
      if (_summaryController.text != draft.summary) _summaryController.text = draft.summary;
      if (_promptController.text != draft.systemPrompt) _promptController.text = draft.systemPrompt;
      if (_loreController.text != draft.lore) _loreController.text = draft.lore;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _promptController.dispose();
    _loreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final controller = widget.controller;

    return SoftGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
      borderRadius: CompanionRadius.borderXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Inspector Header
          _buildHeader(context),
          const SizedBox(height: 10.0),

          // 2. Body: Neutral Assistant view OR Draft Editor tabs
          if (controller.isNeutralSelected)
            Expanded(child: _buildNeutralAssistantView(context))
          else if (controller.draft != null) ...[
            // Tab Selector
            Center(
              child: NeumorphicSegmentedControl<StudioInspectorTab>(
                selected: _currentTab,
                onChanged: (tab) => setState(() => _currentTab = tab),
                segments: const [
                  NeumorphicSegment(value: StudioInspectorTab.personality, label: 'Personality', icon: Icons.tune_rounded),
                  NeumorphicSegment(value: StudioInspectorTab.identity, label: 'Identity & Lore', icon: Icons.edit_note_rounded),
                  NeumorphicSegment(value: StudioInspectorTab.visual, label: 'Stage & Visual', icon: Icons.palette_outlined),
                ],
              ),
            ),
            const SizedBox(height: 12.0),

            // Tab Content
            Expanded(
              child: switch (_currentTab) {
                StudioInspectorTab.personality => _buildPersonalityTab(context),
                StudioInspectorTab.identity => _buildIdentityTab(context),
                StudioInspectorTab.visual => _buildVisualTab(context),
              },
            ),

            const SizedBox(height: 10.0),

            // 3. Pinned Action Footer
            _buildActionFooter(context),
          ] else
            Expanded(
              child: Center(
                child: Text(
                  'Select a template or character from the Library to begin editing.',
                  style: CompanionTypography.bodyMedium.copyWith(color: ext?.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final controller = widget.controller;
    final draft = controller.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                controller.isNeutralSelected
                    ? 'Neutral Assistant'
                    : (draft != null ? (draft.isNew ? 'Create Character' : draft.name) : 'Inspector'),
                style: CompanionTypography.titleMedium.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (draft != null && draft.isDirty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: (ext?.warning ?? Colors.amber).withValues(alpha: 0.15),
                  borderRadius: CompanionRadius.borderFull,
                  border: Border.all(color: (ext?.warning ?? Colors.amber).withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Unsaved Changes',
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.warning ?? Colors.amber,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        if (controller.uncertainWriteWarning) ...[
          const SizedBox(height: 6.0),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: (ext?.warning ?? Colors.amber).withValues(alpha: 0.15),
              borderRadius: CompanionRadius.borderMd,
              border: Border.all(color: ext?.warning ?? Colors.amber),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: ext?.warning),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'Request timed out — verifying state with local runtime. Your edits are preserved.',
                    style: CompanionTypography.caption.copyWith(color: ext?.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (controller.error != null) ...[
          const SizedBox(height: 6.0),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: (ext?.danger ?? Colors.red).withValues(alpha: 0.15),
              borderRadius: CompanionRadius.borderMd,
              border: Border.all(color: ext?.danger ?? Colors.red),
            ),
            child: Text(
              controller.error!,
              style: CompanionTypography.caption.copyWith(color: ext?.danger),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNeutralAssistantView(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final controller = widget.controller;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: (ext?.surfaceElevated ?? const Color(0xFF1E293B)).withValues(alpha: 0.8),
            borderRadius: CompanionRadius.borderLg,
            border: Border.all(color: ext?.borderSubtle ?? Colors.transparent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 24, color: ext?.accent),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      'System-Owned Neutral Assistant',
                      style: CompanionTypography.bodyMedium.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Text(
                'Neutral Assistant is the immutable system fallback. It operates strictly under DEFAULT_PERSONA with zero personality modulation or trait bias.',
                style: CompanionTypography.bodyMedium.copyWith(color: ext?.textSecondary),
              ),
              const SizedBox(height: 12.0),
              Text(
                'Traits: None (traits = null). Sliders are unavailable for system-owned assistants.',
                style: CompanionTypography.caption.copyWith(color: ext?.textSecondary, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20.0),
        NeumorphicButton(
          onPressed: controller.isNeutralActive ? null : widget.onResetNeutral,
          child: Text(controller.isNeutralActive ? 'Active in Chat' : 'Set Active for Profile'),
        ),
      ],
    );
  }

  Widget _buildPersonalityTab(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final draft = widget.controller.draft!;
    final summary = CharacterStagePresenter.buildIllustrativeStyleSummary(draft.traits, draft.presetId);

    return ListView(
      children: [
        // 1. Illustrative Style Summary Card
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: (ext?.surfaceElevated ?? const Color(0xFF1E293B)).withValues(alpha: 0.8),
            borderRadius: CompanionRadius.borderLg,
            border: Border.all(color: ext?.borderSubtle ?? Colors.transparent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: ext?.accent),
                  const SizedBox(width: 6.0),
                  Expanded(
                    child: Text(
                      'Illustrative Style Summary',
                      style: CompanionTypography.bodyMedium.copyWith(
                        color: ext?.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              _buildBadgeRow('Tone', summary.toneLabel),
              _buildBadgeRow('Expression', summary.expressionLabel),
              _buildBadgeRow('Delivery', summary.deliveryLabel),
              _buildBadgeRow('Register', summary.registerLabel),
              if (summary.dynamicLabel != null)
                _buildBadgeRow('Dynamic', summary.dynamicLabel!, isAccent: true),
              if (summary.autonomyGuardActive)
                _buildBadgeRow('Guard', summary.autonomyGuardText, isWarning: true),
              const SizedBox(height: 6.0),
              Text(
                'Illustrative local preview of slider tendencies. Authoritative prompt modulation is compiled by the local Python runtime during chat turns.',
                style: CompanionTypography.caption.copyWith(color: ext?.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14.0),

        // 2. Preset Selector
        Text(
          'Personality Presets',
          style: CompanionTypography.caption.copyWith(color: ext?.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6.0),
        Wrap(
          spacing: 6.0,
          runSpacing: 6.0,
          children: widget.controller.presets.map((p) {
            final isSelected = draft.presetId == p.presetId;
            return ChoiceChip(
              label: Text(p.label),
              selected: isSelected,
              onSelected: (_) => draft.updatePreset(p.presetId, p.traits),
            );
          }).toList()
            ..add(
              ChoiceChip(
                label: const Text('Custom'),
                selected: draft.presetId == 'custom',
                onSelected: (_) => draft.updatePreset('custom', draft.traits),
              ),
            ),
        ),

        const SizedBox(height: 16.0),

        // 3. 8 Trait Sliders
        Text(
          'Continuous Traits (0–100)',
          style: CompanionTypography.caption.copyWith(color: ext?.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8.0),
        _buildTraitSlider('Warmth', 'warmth', draft.traits.warmth),
        _buildTraitSlider('Teasing', 'teasing', draft.traits.teasing),
        _buildTraitSlider('Guardedness', 'guardedness', draft.traits.guardedness),
        _buildTraitSlider('Directness', 'directness', draft.traits.directness),
        _buildTraitSlider('Expressiveness', 'expressiveness', draft.traits.expressiveness),
        _buildTraitSlider('Affection', 'affection', draft.traits.affection),
        _buildTraitSlider('Formality', 'formality', draft.traits.formality),
        _buildTraitSlider('Verbosity', 'verbosity', draft.traits.verbosity),

        const SizedBox(height: 10.0),
        OutlinedButton.icon(
          onPressed: () {
            final tmpl = widget.controller.templates.firstWhere(
              (t) => t.id == draft.sourceTemplateId,
              orElse: () => widget.controller.templates.first,
            );
            if (tmpl.traits != null) {
              draft.resetAllTraitsToTemplate(tmpl.traits!, tmpl.defaultPresetId);
            }
          },
          icon: const Icon(Icons.restart_alt_rounded, size: 16),
          label: const Text('Reset All to Template Defaults'),
        ),
      ],
    );
  }

  Widget _buildBadgeRow(String label, String value, {bool isAccent = false, bool isWarning = false}) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: CompanionTypography.caption.copyWith(color: ext?.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: CompanionTypography.caption.copyWith(
                color: isWarning
                    ? (ext?.warning ?? Colors.amber)
                    : (isAccent ? (ext?.accent ?? Colors.blue) : ext?.textPrimary),
                fontWeight: isAccent || isWarning ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitSlider(String label, String key, int value) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final draft = widget.controller.draft!;
    final bandLabel = CharacterStagePresenter.getTraitBandLabel(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: CompanionTypography.bodyMedium.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
                    decoration: BoxDecoration(
                      color: (ext?.surfaceElevated ?? const Color(0xFF1E293B)).withValues(alpha: 0.8),
                      borderRadius: CompanionRadius.borderFull,
                      border: Border.all(color: ext?.borderSubtle ?? Colors.transparent),
                    ),
                    child: Text(
                      '$value ($bandLabel)',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Semantics(
            label: '$label trait slider',
            value: '$value of 100 ($bandLabel)',
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (newVal) => draft.updateTrait(key, newVal.toInt()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityTab(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final draft = widget.controller.draft!;

    return ListView(
      children: [
        // Name
        TextField(
          controller: _nameController,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Character Name',
            hintText: 'Enter character name...',
          ),
          onChanged: draft.updateName,
        ),
        const SizedBox(height: 12.0),

        // Summary
        TextField(
          controller: _summaryController,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Summary',
            hintText: 'Short one or two sentence summary...',
          ),
          onChanged: draft.updateSummary,
        ),
        const SizedBox(height: 12.0),

        // Persona Instructions
        TextField(
          controller: _promptController,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Persona Instructions',
            hintText: 'Stylistic instructions (e.g. tone, quirks)...',
            helperText: '${_promptController.text.length} / 1,200 recommended chars',
            helperStyle: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
          ),
          onChanged: (val) {
            draft.updateSystemPrompt(val);
            setState(() {});
          },
        ),
        const SizedBox(height: 12.0),

        // Lore
        TextField(
          controller: _loreController,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Backstory & Lore',
            hintText: 'Character backstory, memories, or world lore...',
            helperText: '${_loreController.text.length} / 1,600 recommended chars',
            helperStyle: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
          ),
          onChanged: (val) {
            draft.updateLore(val);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildVisualTab(BuildContext context) {
    final controller = widget.controller;
    final draft = controller.draft!;

    return ListView(
      children: [
        const Text('Thematic Studio Backdrop:'),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: StudioBackdropPreset.values.map((p) {
            final isSelected = controller.backdropPreset == p;
            return ChoiceChip(
              label: Text(p.label),
              selected: isSelected,
              onSelected: (_) => controller.setBackdropPreset(p),
            );
          }).toList(),
        ),
        const SizedBox(height: 16.0),
        const Text('Archetype Avatar Asset:'),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0,
          children: [
            'avatar_warm',
            'avatar_playful',
            'avatar_formal',
            'avatar_neutral',
          ].map((asset) {
            final isSelected = draft.avatarAsset == asset;
            return ChoiceChip(
              label: Text(asset.replaceAll('avatar_', '').replaceAll('_', ' ').toUpperCase()),
              selected: isSelected,
              onSelected: (_) => draft.updateAvatar(asset),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionFooter(BuildContext context) {
    final controller = widget.controller;
    final draft = controller.draft!;
    final isActive = draft.instanceId != null && draft.instanceId == controller.activeInstanceId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Save / Create Button
            Expanded(
              child: NeumorphicButton(
                onPressed: controller.isMutating ? null : widget.onSave,
                child: Text(
                  draft.isNew ? 'Create Character' : (draft.isDirty ? 'Save Changes' : 'Saved'),
                ),
              ),
            ),
            const SizedBox(width: 8.0),

            // Activate Button (if existing instance)
            if (!draft.isNew && draft.instanceId != null)
              Expanded(
                child: NeumorphicButton(
                  onPressed: isActive || controller.isMutating
                      ? null
                      : () => widget.onActivate(draft.instanceId!),
                  child: Text(isActive ? 'Active in Chat' : 'Set Active for Profile'),
                ),
              ),
          ],
        ),
        if (!draft.isNew && draft.instanceId != null) ...[
          const SizedBox(height: 8.0),
          TextButton.icon(
            onPressed: controller.isMutating
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Archive Character?'),
                        content: Text('Are you sure you want to archive "${draft.name}"? Past conversations will retain their character record.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Archive')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      widget.onArchive(draft.instanceId!);
                    }
                  },
            icon: const Icon(Icons.archive_outlined, size: 16),
            label: const Text('Archive Character'),
          ),
        ],
      ],
    );
  }
}
