import 'package:companion_api/companion_api.dart';
import 'package:flutter/material.dart';
import 'desktop_profile_controller.dart';

/// Opens the modal dialog to create a new local Profile.
Future<ProfileMetadata?> showCreateProfileDialog(
  BuildContext context,
  DesktopProfileController controller,
) async {
  return showDialog<ProfileMetadata>(
    context: context,
    builder: (ctx) => _CreateProfileDialog(controller: controller),
  );
}

/// Opens the modal dialog to rename an existing Profile.
Future<ProfileMetadata?> showRenameProfileDialog(
  BuildContext context,
  DesktopProfileController controller, {
  required String profileId,
  required String currentName,
  bool isDefault = false,
}) async {
  return showDialog<ProfileMetadata>(
    context: context,
    builder: (ctx) => _RenameProfileDialog(
      controller: controller,
      profileId: profileId,
      currentName: currentName,
      isDefault: isDefault,
    ),
  );
}

/// Opens the modal dialog to confirm moving a Profile to Recently Deleted.
Future<ProfileMetadata?> showMoveToRecentlyDeletedDialog(
  BuildContext context,
  DesktopProfileController controller, {
  required String profileId,
  required String profileName,
}) async {
  return showDialog<ProfileMetadata>(
    context: context,
    builder: (ctx) => _MoveToRecentlyDeletedDialog(
      controller: controller,
      profileId: profileId,
      profileName: profileName,
    ),
  );
}

/// Opens the modal dialog to permanently purge a Profile immediately.
Future<bool?> showPermanentDeleteProfileDialog(
  BuildContext context,
  DesktopProfileController controller, {
  required String profileId,
  required String profileName,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _PermanentDeleteProfileDialog(
      controller: controller,
      profileId: profileId,
      profileName: profileName,
    ),
  );
}


class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog({required this.controller});
  final DesktopProfileController controller;

  @override
  State<_CreateProfileDialog> createState() => _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  late final TextEditingController _textController;
  bool _switchImmediately = true;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String? _validateName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Profile name cannot be empty.';
    if (trimmed.length > 32) return 'Profile name must be 32 characters or fewer.';
    if (trimmed.codeUnits.any((c) => c < 32 || c == 127)) {
      return 'Profile name cannot contain control characters.';
    }
    final duplicate = widget.controller.profiles.any(
      (p) => (p['name'] as String).trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) return 'A Profile with this name already exists.';
    return null;
  }

  Future<void> _submit() async {
    final validation = _validateName(_textController.text);
    if (validation != null) {
      setState(() => _errorText = validation);
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    final created = await widget.controller.createProfile(
      name: _textController.text.trim(),
      switchImmediately: _switchImmediately,
    );

    if (!mounted) return;

    if (created != null) {
      Navigator.of(context).pop(created);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorText = widget.controller.error ?? 'Failed to create Profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Profile'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a separate local profile with its own isolated conversations, memories, and character preferences.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              autofocus: true,
              maxLength: 32,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: 'Profile Name',
                hintText: 'e.g. Work, Research, Personal',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _switchImmediately,
                  onChanged: _isSubmitting
                      ? null
                      : (v) => setState(() => _switchImmediately = v ?? true),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Switch to this Profile immediately',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Profile'),
        ),
      ],
    );
  }
}

class _RenameProfileDialog extends StatefulWidget {
  const _RenameProfileDialog({
    required this.controller,
    required this.profileId,
    required this.currentName,
    this.isDefault = false,
  });

  final DesktopProfileController controller;
  final String profileId;
  final String currentName;
  final bool isDefault;

  @override
  State<_RenameProfileDialog> createState() => _RenameProfileDialogState();
}

class _RenameProfileDialogState extends State<_RenameProfileDialog> {
  late final TextEditingController _textController;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentName);
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentName.length,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String? _validateName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Profile name cannot be empty.';
    if (trimmed.length > 32) return 'Profile name must be 32 characters or fewer.';
    if (trimmed.codeUnits.any((c) => c < 32 || c == 127)) {
      return 'Profile name cannot contain control characters.';
    }
    final duplicate = widget.controller.profiles.any(
      (p) =>
          p['id'] != widget.profileId &&
          (p['name'] as String).trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) return 'A Profile with this name already exists.';
    return null;
  }

  Future<void> _submit() async {
    final trimmed = _textController.text.trim();
    if (trimmed == widget.currentName.trim()) {
      Navigator.of(context).pop();
      return;
    }

    final validation = _validateName(trimmed);
    if (validation != null) {
      setState(() => _errorText = validation);
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    final updated = await widget.controller.renameProfile(
      profileId: widget.profileId,
      newName: trimmed,
    );

    if (!mounted) return;

    if (updated != null) {
      Navigator.of(context).pop(updated);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorText = widget.controller.error ?? 'Failed to rename Profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Profile'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isDefault) ...[
              const Text(
                'Tip: You can rename Default Profile to Personal while preserving your default profile privileges.',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _textController,
              autofocus: true,
              maxLength: 32,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: 'Profile Name',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Rename'),
        ),
      ],
    );
  }
}


class _MoveToRecentlyDeletedDialog extends StatefulWidget {
  const _MoveToRecentlyDeletedDialog({
    required this.controller,
    required this.profileId,
    required this.profileName,
  });

  final DesktopProfileController controller;
  final String profileId;
  final String profileName;

  @override
  State<_MoveToRecentlyDeletedDialog> createState() =>
      _MoveToRecentlyDeletedDialogState();
}

class _MoveToRecentlyDeletedDialogState
    extends State<_MoveToRecentlyDeletedDialog> {
  late final TextEditingController _textController;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _isConfirmed =>
      _textController.text.trim() == widget.profileName.trim();

  Future<void> _submit() async {
    if (!_isConfirmed) return;

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    final deleted = await widget.controller.deleteProfile(widget.profileId);

    if (!mounted) return;

    if (deleted != null) {
      Navigator.of(context).pop(deleted);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorText = widget.controller.error ?? 'Failed to delete Profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Move to Recently Deleted'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 380, maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moving "${widget.profileName}" to Recently Deleted will immediately disconnect its active session.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'The profile and its data will remain recoverable for 30 days before being permanently purged.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Text(
              'Type "${widget.profileName}" to confirm:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              autofocus: true,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: widget.profileName,
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_isConfirmed && !_isSubmitting) _submit();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isConfirmed && !_isSubmitting ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber.shade900,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Move to Recently Deleted'),
        ),
      ],
    );
  }
}

class _PermanentDeleteProfileDialog extends StatefulWidget {
  const _PermanentDeleteProfileDialog({
    required this.controller,
    required this.profileId,
    required this.profileName,
  });

  final DesktopProfileController controller;
  final String profileId;
  final String profileName;

  @override
  State<_PermanentDeleteProfileDialog> createState() =>
      _PermanentDeleteProfileDialogState();
}

class _PermanentDeleteProfileDialogState
    extends State<_PermanentDeleteProfileDialog> {
  late final TextEditingController _textController;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _isConfirmed =>
      _textController.text.trim() == widget.profileName.trim();

  Future<void> _submit() async {
    if (!_isConfirmed) return;

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    final success =
        await widget.controller.purgeProfileImmediately(widget.profileId);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorText =
            widget.controller.error ?? 'Failed to permanently delete Profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permanently Delete Profile'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 380, maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This action is irreversible.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'All conversations, messages, attachments, memories, and character settings for "${widget.profileName}" will be permanently erased.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              'Type "${widget.profileName}" to confirm permanent deletion:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              autofocus: true,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: widget.profileName,
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_isConfirmed && !_isSubmitting) _submit();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isConfirmed && !_isSubmitting ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Permanently Delete'),
        ),
      ],
    );
  }
}
