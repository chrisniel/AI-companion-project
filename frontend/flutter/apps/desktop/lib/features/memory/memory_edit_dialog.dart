import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

/// Modal dialog for creating a new memory record or editing an existing one.
class MemoryEditDialog extends StatefulWidget {
  const MemoryEditDialog({
    super.key,
    this.initialMemory,
    this.activeCharacterInstanceId,
  });

  final MemoryOut? initialMemory;
  final String? activeCharacterInstanceId;

  @override
  State<MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<MemoryEditDialog> {
  late final TextEditingController _contentCtrl;
  late String _category;
  late String _scope;
  late bool _isCore;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    final mem = widget.initialMemory;
    _contentCtrl = TextEditingController(text: mem?.content ?? '');
    _category = mem?.category ?? 'fact';
    _scope = mem?.scope ?? 'profile';
    _isCore = mem?.isCore ?? false;
    _expiresAt = mem?.expiresAt != null ? DateTime.tryParse(mem!.expiresAt!) : null;
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isEditing = widget.initialMemory != null;

    return AlertDialog(
      title: Text(
        isEditing ? 'Edit Memory' : 'Add Memory',
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
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'fact', child: Text('Fact')),
                        DropdownMenuItem(value: 'preference', child: Text('Preference')),
                        DropdownMenuItem(value: 'context', child: Text('Context')),
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
                        decoration: const InputDecoration(
                          labelText: 'Scope',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'profile', child: Text('Profile (Global)')),
                          if (widget.activeCharacterInstanceId != null)
                            const DropdownMenuItem(value: 'character', child: Text('Character Only')),
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

            if (isEditing) {
              final update = MemoryUpdate(
                content: text,
                category: _category,
                isCore: _isCore,
                expiresAt: _expiresAt?.toUtc().toIso8601String(),
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
