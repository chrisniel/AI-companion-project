import 'package:companion_api/companion_api.dart';
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
    CharacterInstanceOut? selectedInstance;
    if (draft != null && draft.instanceId != null) {
      for (final item in controller.instances) {
        if (item.id == draft.instanceId) {
          selectedInstance = item;
          break;
        }
      }
    }
    final moodBadge = selectedInstance?.moodBadgeText;

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
            if (moodBadge != null) ...[
              Container(
                key: const Key('studio-inspector-mood-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.12),
                  borderRadius: CompanionRadius.borderFull,
                  border: Border.all(
                    color: (ext?.accent ?? CompanionColors.lightAccent).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Mood: $moodBadge (${selectedInstance?.moodIntensity ?? 50}%)',
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
            ],
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

    // Legacy placeholder inspection: read-only banner, no fake continuous sliders
    if (draft.isLegacyPlaceholder || draft.traits == null) {
      return ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: (ext?.surfaceElevated ?? const Color(0xFF1E293B)).withValues(alpha: 0.8),
              borderRadius: CompanionRadius.borderLg,
              border: Border.all(color: ext?.borderSubtle ?? Colors.transparent),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 20, color: ext?.textSecondary),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Legacy Placeholder (Read-Only)',
                        style: CompanionTypography.bodyMedium.copyWith(
                          color: ext?.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'This character was created prior to continuous trait modulation and is preserved for historical conversation continuity. Continuous personality sliders, activation, and editing are disabled for legacy placeholders.',
                        style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final traits = draft.traits!;
    final summary = CharacterStagePresenter.buildIllustrativeStyleSummary(traits, draft.presetId);

    // Safely lookup source template for trait resets (firstOrNull avoids throw on empty catalog)
    final sourceTmpl = widget.controller.templates.where(
      (t) => t.id == draft.sourceTemplateId,
    ).firstOrNull ?? widget.controller.templates.firstOrNull;

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

        // 2. Preset Selector (no duplicate custom chip: presets from backend already includes custom)
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
              onSelected: draft.isReadOnly
                  ? null
                  : (_) => draft.updatePreset(p.presetId, p.traits),
            );
          }).toList(),
        ),

        const SizedBox(height: 16.0),

        // 3. 8 Trait Sliders with individual reset controls
        Text(
          'Continuous Traits (0–100)',
          style: CompanionTypography.caption.copyWith(color: ext?.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8.0),
        _buildTraitSlider('Warmth', 'warmth', traits.warmth, sourceTmpl),
        _buildTraitSlider('Teasing', 'teasing', traits.teasing, sourceTmpl),
        _buildTraitSlider('Guardedness', 'guardedness', traits.guardedness, sourceTmpl),
        _buildTraitSlider('Directness', 'directness', traits.directness, sourceTmpl),
        _buildTraitSlider('Expressiveness', 'expressiveness', traits.expressiveness, sourceTmpl),
        _buildTraitSlider('Affection', 'affection', traits.affection, sourceTmpl),
        _buildTraitSlider('Formality', 'formality', traits.formality, sourceTmpl),
        _buildTraitSlider('Verbosity', 'verbosity', traits.verbosity, sourceTmpl),

        const SizedBox(height: 10.0),
        OutlinedButton.icon(
          onPressed: (draft.isReadOnly || sourceTmpl?.traits == null)
              ? null
              : () => draft.resetAllTraitsToTemplate(sourceTmpl!.traits!, sourceTmpl.defaultPresetId),
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

  Widget _buildTraitSlider(String label, String key, int value, CharacterTemplateOut? sourceTmpl) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final draft = widget.controller.draft!;
    final bandLabel = CharacterStagePresenter.getTraitBandLabel(value);
    final canResetTrait = !draft.isReadOnly && sourceTmpl?.traits != null;

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
                  if (canResetTrait) ...[
                    IconButton(
                      icon: const Icon(Icons.restart_alt_rounded, size: 14),
                      tooltip: 'Reset $label to template default',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => draft.resetTraitToTemplate(key, sourceTmpl!.traits!),
                    ),
                    const SizedBox(width: 4.0),
                  ],
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
              onChanged: draft.isReadOnly ? null : (newVal) => draft.updateTrait(key, newVal.toInt()),
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
          enabled: !draft.isReadOnly,
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
          enabled: !draft.isReadOnly,
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
          enabled: !draft.isReadOnly,
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
          enabled: !draft.isReadOnly,
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
          runSpacing: 8.0,
          children: [
            ('warm_companion_avatar', 'Warm Companion'),
            ('playful_companion_avatar', 'Playful'),
            ('formal_advisor_avatar', 'Formal Advisor'),
            ('neutral_avatar', 'Neutral Assistant'),
          ].map((item) {
            final isSelected = draft.avatarAsset == item.$1 ||
                draft.avatarAsset == item.$1.replaceAll('_avatar', '') ||
                draft.avatarAsset == 'avatar_${item.$1.replaceAll('_avatar', '')}';
            return ChoiceChip(
              label: Text(item.$2),
              selected: isSelected,
              onSelected: draft.isReadOnly ? null : (_) => draft.updateAvatar(item.$1),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionFooter(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final controller = widget.controller;
    final draft = controller.draft!;
    final isActive = draft.instanceId != null && draft.instanceId == controller.activeInstanceId;
    final isReady = controller.sessionStatus == StudioSessionStatus.authenticatedReady;
    final canMutate = !controller.isMutating && isReady && !draft.isReadOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.uncertainCreateWarning && draft.isNew) ...[
          Container(
            padding: const EdgeInsets.all(8.0),
            margin: const EdgeInsets.only(bottom: 8.0),
            decoration: BoxDecoration(
              color: (Theme.of(context).extension<CompanionThemeExtension>()?.warning ?? Colors.amber).withValues(alpha: 0.15),
              borderRadius: CompanionRadius.borderMd,
              border: Border.all(
                color: (Theme.of(context).extension<CompanionThemeExtension>()?.warning ?? Colors.amber).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Theme.of(context).extension<CompanionThemeExtension>()?.warning ?? Colors.amber,
                ),
                const SizedBox(width: 6.0),
                Expanded(
                  child: Text(
                    'Creation timed out. The character may have been created on the server. Confirm retry to proceed.',
                    style: CompanionTypography.caption.copyWith(
                      color: Theme.of(context).extension<CompanionThemeExtension>()?.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            // Save / Create Button
            Expanded(
              child: NeumorphicButton(
                onPressed: canMutate
                    ? (controller.uncertainCreateWarning && draft.isNew
                        ? () => controller.retryCreateDraft()
                        : widget.onSave)
                    : null,
                child: Text(
                  draft.isReadOnly
                      ? 'Read-Only'
                      : (controller.uncertainCreateWarning && draft.isNew
                          ? 'Confirm Retry Creation'
                          : (draft.isNew ? 'Create Character' : (draft.isDirty ? 'Save Changes' : 'Saved'))),
                ),
              ),
            ),
            if (!draft.isReadOnly && !draft.isNew && draft.instanceId != null) ...[
              const SizedBox(width: 8.0),
              // Activate Button (if existing instance)
              Expanded(
                child: NeumorphicButton(
                  onPressed: isActive || !canMutate
                      ? null
                      : () async {
                          if (draft.isDirty) {
                            await controller.saveAndActivateDraft();
                          } else {
                            await controller.activateCharacter(draft.instanceId!);
                          }
                        },
                  child: Text(
                    isActive
                        ? 'Active in Chat'
                        : (draft.isDirty ? 'Save & Activate' : 'Set Active for Profile'),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!draft.isReadOnly && !draft.isNew && draft.instanceId != null && draft.isDirty) ...[
          const SizedBox(height: 6.0),
          Text(
            isActive
                ? 'Note: You have unsaved changes. Chat uses saved traits until you click "Save Changes".'
                : 'Note: Unsaved trait changes will be saved before activating for Chat.',
            style: CompanionTypography.caption.copyWith(
              color: isActive
                  ? (ext?.warning ?? CompanionColors.warning)
                  : ext?.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
        if (!draft.isReadOnly && !draft.isNew && draft.instanceId != null) ...[
          const SizedBox(height: 8.0),
          TextButton.icon(
            onPressed: canMutate
                ? () async {
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
                  }
                : null,
            icon: const Icon(Icons.archive_outlined, size: 16),
            label: const Text('Archive Character'),
          ),
        ],
      ],
    );
  }
}
