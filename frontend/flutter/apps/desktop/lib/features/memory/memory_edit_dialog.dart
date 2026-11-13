import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

/// Modal dialog for creating a new memory record or editing an existing one.
class MemoryEditDialog extends StatefulWidget {
  const MemoryEditDialog({
    super.key,
    this.initialMemory,
    this.activeCharacterInstanceId,
    this.initialTier = 'knowledge',
  });

  final MemoryOut? initialMemory;
  final String? activeCharacterInstanceId;
  final String initialTier;

  @override
  State<MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<MemoryEditDialog> {
  late final TextEditingController _contentCtrl;
  late final TextEditingController _keywordsCtrl;
  late String _category;
  late String _scope;
  late bool _isCore;
  late String _createSourceType;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    final mem = widget.initialMemory;
    _contentCtrl = TextEditingController(text: mem?.content ?? '');
    _keywordsCtrl = TextEditingController(
      text: (mem?.triggerKeywords ?? const <String>[]).join(', '),
    );
    _scope = mem?.scope ?? 'profile';

    if (mem != null) {
      _category = mem.category;
      _isCore = mem.isCore;
      _createSourceType = mem.sourceType;
      _expiresAt = mem.expiresAt != null ? DateTime.tryParse(mem.expiresAt!) : null;
    } else {
      switch (widget.initialTier) {
        case 'short_term':
          _category = 'context';
          _isCore = false;
          _createSourceType = 'manual';
          _expiresAt = DateTime.now().toUtc().add(const Duration(hours: 72));
          break;
        case 'long_term':
          _category = 'fact';
          _isCore = false;
          _createSourceType = 'user_explicit';
          _expiresAt = null;
          break;
        default: // 'knowledge'
          _category = 'fact';
          _isCore = true;
          _createSourceType = 'manual';
          _expiresAt = null;
      }
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  String _dialogTitle(bool isEditing) {
    if (isEditing) return 'Edit Memory';
    switch (widget.initialTier) {
      case 'knowledge':
        return 'Add Knowledge';
      case 'short_term':
        return 'Add Context';
      default:
        return 'Add Memory';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isEditing = widget.initialMemory != null;

    return AlertDialog(
      title: Text(
        _dialogTitle(isEditing),
        style: CompanionTypography.titleMedium.copyWith(color: ext?.textPrimary),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('memory_content_field'),
                controller: _contentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Memory Content',
                  hintText: 'Enter enduring fact, preference, or context...',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: ext?.textSecondary),
                ),
              ),
              const SizedBox(height: CompanionSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'fact',
                          child: Text('Fact', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'preference',
                          child: Text('Preference', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'context',
                          child: Text('Context', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(width: CompanionSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _scope,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Scope',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'profile',
                            child: Text('Profile (Global)', overflow: TextOverflow.ellipsis),
                          ),
                          if (widget.activeCharacterInstanceId != null)
                            const DropdownMenuItem(
                              value: 'character',
                              child: Text('Character Only', overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _scope = val);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: CompanionSpacing.md),
              TextField(
                key: const Key('memory_keywords_field'),
                controller: _keywordsCtrl,
                decoration: InputDecoration(
                  labelText: 'Trigger Keywords (Optional Lorebook)',
                  hintText: 'e.g. sarah, cook, sourdough',
                  helperText:
                      'Comma-separated keywords activate this entry on demand when mentioned.',
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: ext?.textSecondary),
                ),
              ),
              const SizedBox(height: CompanionSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Core Memory (Always Retrieved)',
                  style: CompanionTypography.bodyMedium.copyWith(color: ext?.textPrimary),
                ),
                subtitle: Text(
                  'Core memories are pinned and prioritized during conversation context assembly.',
                  style: CompanionTypography.caption.copyWith(color: ext?.textSecondary),
                ),
                value: _isCore,
                onChanged: (val) => setState(() => _isCore = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _contentCtrl.text.trim();
            if (text.isEmpty) return;

            final keywords = _keywordsCtrl.text
                .split(',')
                .map((k) => k.trim())
                .where((k) => k.isNotEmpty)
                .toList();

            if (isEditing) {
              final update = MemoryUpdate(
                content: text,
                category: _category,
                isCore: _isCore,
                expiresAt: _expiresAt?.toUtc().toIso8601String(),
                triggerKeywords: keywords,
              );
              Navigator.of(context).pop(update);
            } else {
              final create = MemoryCreate(
                content: text,
                category: _category,
                scope: _scope,
                characterInstanceId: _scope == 'character' ? widget.activeCharacterInstanceId : null,
                isCore: _isCore,
                expiresAt: _expiresAt?.toUtc().toIso8601String(),
                triggerKeywords: keywords.isEmpty ? null : keywords,
                sourceType: _createSourceType,
              );
              Navigator.of(context).pop(create);
            }
          },
          child: Text(isEditing ? 'Save Changes' : 'Create Memory'),
        ),
      ],
    );
  }
}
