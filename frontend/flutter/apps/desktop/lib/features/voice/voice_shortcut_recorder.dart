import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/desktop_audio_adapter.dart';

/// Maps between Flutter keyboard events/activators and Win32 virtual-key bindings.
abstract final class VoiceShortcutKeyMapper {
  static bool isCaptureModalOpen = false;

  static LogicalKeyboardKey? virtualKeyToLogical(int vk) {
    if (vk >= 0x41 && vk <= 0x5A) {
      return LogicalKeyboardKey(LogicalKeyboardKey.keyA.keyId + (vk - 0x41));
    }
    if (vk >= 0x30 && vk <= 0x39) {
      return LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + (vk - 0x30));
    }
    if (vk >= 0x70 && vk <= 0x7B) {
      return LogicalKeyboardKey(LogicalKeyboardKey.f1.keyId + (vk - 0x70));
    }
    return switch (vk) {
      0x20 => LogicalKeyboardKey.space,
      0xA1 => LogicalKeyboardKey.shiftRight,
      0xA3 => LogicalKeyboardKey.controlRight,
      0xA4 => LogicalKeyboardKey.altLeft,
      0xA5 => LogicalKeyboardKey.altRight,
      _ => null,
    };
  }

  static int? logicalToVirtualKey(LogicalKeyboardKey key) {
    final id = key.keyId;
    if (id >= LogicalKeyboardKey.keyA.keyId &&
        id <= LogicalKeyboardKey.keyZ.keyId) {
      return 0x41 + (id - LogicalKeyboardKey.keyA.keyId);
    }
    if (id >= LogicalKeyboardKey.digit0.keyId &&
        id <= LogicalKeyboardKey.digit9.keyId) {
      return 0x30 + (id - LogicalKeyboardKey.digit0.keyId);
    }
    if (id >= LogicalKeyboardKey.f1.keyId &&
        id <= LogicalKeyboardKey.f12.keyId) {
      return 0x70 + (id - LogicalKeyboardKey.f1.keyId);
    }
    if (key == LogicalKeyboardKey.space) return 0x20;
    if (key == LogicalKeyboardKey.shiftRight) return 0xA1;
    if (key == LogicalKeyboardKey.controlRight) return 0xA3;
    if (key == LogicalKeyboardKey.altLeft) return 0xA4;
    if (key == LogicalKeyboardKey.altRight) return 0xA5;
    return null;
  }

  static bool isStandaloneModifierVk(int vk) =>
      vk == 0xA1 || vk == 0xA3 || vk == 0xA4 || vk == 0xA5;

  static SingleActivator? toSingleActivator(VoiceShortcutBinding binding) {
    if (isStandaloneModifierVk(binding.virtualKey)) return null;
    final logical = virtualKeyToLogical(binding.virtualKey);
    if (logical == null) return null;
    return SingleActivator(
      logical,
      control: binding.ctrl,
      alt: binding.alt,
      shift: binding.shift,
    );
  }

  static bool matchesKeyEvent(KeyEvent event, VoiceShortcutBinding binding) {
    final expectedKey = virtualKeyToLogical(binding.virtualKey);
    if (expectedKey == null || event.logicalKey != expectedKey) return false;
    if (isStandaloneModifierVk(binding.virtualKey)) {
      return true;
    }
    final hw = HardwareKeyboard.instance;
    return hw.isControlPressed == binding.ctrl &&
        hw.isAltPressed == binding.alt &&
        hw.isShiftPressed == binding.shift;
  }

  /// Converts a [KeyDownEvent] into a [VoiceShortcutBinding], or returns null
  /// when the key press is unsupported or lacks a modifier for typing safety.
  static VoiceShortcutBinding? fromKeyEvent(
    KeyEvent event, {
    bool allowStandaloneModifier = false,
  }) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;

    if (allowStandaloneModifier) {
      if (key == LogicalKeyboardKey.altRight) {
        return const VoiceShortcutBinding(
          ctrl: false,
          alt: false,
          shift: false,
          virtualKey: 0xA5,
          label: 'Right Alt',
        );
      }
      if (key == LogicalKeyboardKey.altLeft) {
        return const VoiceShortcutBinding(
          ctrl: false,
          alt: false,
          shift: false,
          virtualKey: 0xA4,
          label: 'Left Alt',
        );
      }
      if (key == LogicalKeyboardKey.controlRight) {
        return const VoiceShortcutBinding(
          ctrl: false,
          alt: false,
          shift: false,
          virtualKey: 0xA3,
          label: 'Right Ctrl',
        );
      }
      if (key == LogicalKeyboardKey.shiftRight) {
        return const VoiceShortcutBinding(
          ctrl: false,
          alt: false,
          shift: false,
          virtualKey: 0xA1,
          label: 'Right Shift',
        );
      }
    }

    if (_isModifierKey(key)) return null;
    final vk = logicalToVirtualKey(key);
    if (vk == null) return null;

    final hw = HardwareKeyboard.instance;
    final ctrl = hw.isControlPressed;
    final alt = hw.isAltPressed;
    final shift = hw.isShiftPressed;
    final isFunctionKey = vk >= 0x70 && vk <= 0x7B;

    if (!ctrl && !alt && !shift && !isFunctionKey) {
      // Prevent bare letter/digit/space bindings that steal normal typing.
      return null;
    }

    final keyLabel = _keyLabel(vk);
    final parts = <String>[
      if (ctrl) 'Ctrl',
      if (alt) 'Alt',
      if (shift) 'Shift',
      keyLabel,
    ];
    return VoiceShortcutBinding(
      ctrl: ctrl,
      alt: alt,
      shift: shift,
      virtualKey: vk,
      label: parts.join('+'),
    );
  }

  static bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  static String _keyLabel(int vk) {
    if (vk >= 0x41 && vk <= 0x5A) return String.fromCharCode(vk);
    if (vk >= 0x30 && vk <= 0x39) return String.fromCharCode(vk);
    if (vk >= 0x70 && vk <= 0x7B) return 'F${vk - 0x70 + 1}';
    if (vk == 0x20) return 'Space';
    return '0x${vk.toRadixString(16).toUpperCase()}';
  }
}

/// Interactive settings row that lets the user inspect and re-record a voice shortcut.
class VoiceShortcutRecorderTile extends StatelessWidget {
  const VoiceShortcutRecorderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.binding,
    required this.onCapture,
    this.allowStandaloneModifier = false,
    this.buttonKey,
  });

  final String title;
  final String subtitle;
  final VoiceShortcutBinding binding;
  final Future<String?> Function(VoiceShortcutBinding next) onCapture;
  final bool allowStandaloneModifier;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CompanionTypography.bodyMedium.copyWith(
                  color: ext?.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: CompanionTypography.caption.copyWith(
                  color: ext?.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: CompanionSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (ext?.surfaceElevated ?? Colors.black26).withValues(alpha: 0.7),
            borderRadius: CompanionRadius.borderSm,
            border: Border.all(
              color: ext?.borderSubtle ?? Colors.transparent,
            ),
          ),
          child: Text(
            binding.label,
            style: CompanionTypography.caption.copyWith(
              color: ext?.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: CompanionSpacing.sm),
        NeumorphicButton(
          key: buttonKey,
          size: NeumorphicButtonSize.sm,
          onPressed: () => _openRecorderDialog(context),
          child: const Text('Change'),
        ),
      ],
    );
  }

  Future<void> _openRecorderDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ShortcutCaptureDialog(
        title: title,
        initialBinding: binding,
        allowStandaloneModifier: allowStandaloneModifier,
        onCommit: onCapture,
      ),
    );
  }
}

class _ShortcutCaptureDialog extends StatefulWidget {
  const _ShortcutCaptureDialog({
    required this.title,
    required this.initialBinding,
    required this.allowStandaloneModifier,
    required this.onCommit,
  });

  final String title;
  final VoiceShortcutBinding initialBinding;
  final bool allowStandaloneModifier;
  final Future<String?> Function(VoiceShortcutBinding next) onCommit;

  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  final FocusNode _focusNode = FocusNode();
  late VoiceShortcutBinding _captured;
  String? _validationError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    VoiceShortcutKeyMapper.isCaptureModalOpen = true;
    _captured = widget.initialBinding;
  }

  @override
  void dispose() {
    VoiceShortcutKeyMapper.isCaptureModalOpen = false;
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();

    return AlertDialog(
      title: Text('Shortcut: ${widget.title}'),
      content: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return;
          }
          final next = VoiceShortcutKeyMapper.fromKeyEvent(
            event,
            allowStandaloneModifier: widget.allowStandaloneModifier,
          );
          if (next != null) {
            setState(() {
              _captured = next;
              _validationError = null;
            });
          } else if (event is KeyDownEvent &&
              !VoiceShortcutKeyMapper._isModifierKey(event.logicalKey)) {
            setState(() {
              _validationError =
                  'Include Ctrl, Alt, Shift, or a Function key (F1–F12).';
            });
          }
        },
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.allowStandaloneModifier
                    ? 'Press any modifier combo, function key, or Right Alt / Left Alt.'
                    : 'Press a shortcut combo such as Ctrl+Shift+V or F8 (Escape to cancel).',
                style: CompanionTypography.bodySmall.copyWith(
                  color: ext?.textSecondary,
                ),
              ),
              const SizedBox(height: CompanionSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CompanionSpacing.md,
                  vertical: CompanionSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: (ext?.surfaceElevated ?? Colors.black26)
                      .withValues(alpha: 0.6),
                  borderRadius: CompanionRadius.borderMd,
                  border: Border.all(
                    color: ext?.accent ?? Colors.blueAccent,
                  ),
                ),
                child: Text(
                  _captured.label,
                  textAlign: TextAlign.center,
                  style: CompanionTypography.titleMedium.copyWith(
                    color: ext?.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: CompanionSpacing.sm),
                Text(
                  _validationError!,
                  style: CompanionTypography.caption.copyWith(
                    color: ext?.danger ?? Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _validationError = null;
                  });
                  final err = await widget.onCommit(_captured);
                  if (!context.mounted) return;
                  if (err != null) {
                    setState(() {
                      _saving = false;
                      _validationError = err;
                    });
                  } else {
                    Navigator.of(context).pop();
                  }
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
