import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_schedule_controller.dart';

/// Reactive Quiet Hours configuration card rendered in SettingsScreen.
class QuietHoursSettingsCard extends StatefulWidget {
  const QuietHoursSettingsCard({
    super.key,
    required this.controller,
  });

  final DesktopScheduleController controller;

  @override
  State<QuietHoursSettingsCard> createState() => _QuietHoursSettingsCardState();
}

class _QuietHoursSettingsCardState extends State<QuietHoursSettingsCard> {
  late bool _qhEnabled;
  late TextEditingController _qhStartCtrl;
  late TextEditingController _qhEndCtrl;
  late String _qhTimezone;
  String? _qhFeedback;
  bool _qhIsError = false;
  bool _qhSaving = false;
  QuietHoursOut? _lastSyncedQuietHours;
  final GlobalKey<FormFieldState<String>> _tzFieldKey =
      GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    final qh = widget.controller.quietHours;
    _qhEnabled = qh.quietHoursEnabled;
    _qhStartCtrl = TextEditingController(text: qh.quietHoursStart);
    _qhEndCtrl = TextEditingController(text: qh.quietHoursEnd);
    _qhTimezone = qh.quietHoursTimezone;
    _lastSyncedQuietHours = qh;
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant QuietHoursSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _lastSyncedQuietHours = null;
      _qhFeedback = null;
      _qhIsError = false;
      _syncFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _qhStartCtrl.dispose();
    _qhEndCtrl.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _syncFromController();
  }

  void _syncFromController() {
    if (_qhSaving) return;
    final next = widget.controller.quietHours;
    final prev = _lastSyncedQuietHours;
    final changed = prev == null ||
        prev.quietHoursEnabled != next.quietHoursEnabled ||
        prev.quietHoursStart != next.quietHoursStart ||
        prev.quietHoursEnd != next.quietHoursEnd ||
        prev.quietHoursTimezone != next.quietHoursTimezone;
    if (!changed) return;

    setState(() {
      _qhEnabled = next.quietHoursEnabled;
      _qhStartCtrl.text = next.quietHoursStart;
      _qhEndCtrl.text = next.quietHoursEnd;
      _qhTimezone = next.quietHoursTimezone;
      _lastSyncedQuietHours = next;
    });
    _tzFieldKey.currentState?.didChange(_qhTimezone);
  }

  bool _isValidHhMm(String raw) {
    return RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').hasMatch(raw.trim());
  }

  String _normalizeHhMm(String raw) {
    final m = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(raw.trim())!;
    return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)!}';
  }

  Future<void> _saveQuietHours() async {
    final startRaw = _qhStartCtrl.text.trim();
    final endRaw = _qhEndCtrl.text.trim();
    if (!_isValidHhMm(startRaw) || !_isValidHhMm(endRaw)) {
      setState(() {
        _qhFeedback = 'Use 24-hour HH:MM format (e.g. 22:00 and 07:00).';
        _qhIsError = true;
      });
      return;
    }

    final normStart = _normalizeHhMm(startRaw);
    final normEnd = _normalizeHhMm(endRaw);
    setState(() {
      _qhSaving = true;
      _qhFeedback = null;
      _qhIsError = false;
    });

    final ok = await widget.controller.updateQuietHours(
      QuietHoursUpdate(
        quietHoursEnabled: _qhEnabled,
        quietHoursStart: normStart,
        quietHoursEnd: normEnd,
        quietHoursTimezone: _qhTimezone,
      ),
    );

    if (!mounted) return;
    setState(() {
      _qhSaving = false;
      if (ok) {
        _qhStartCtrl.text = normStart;
        _qhEndCtrl.text = normEnd;
        _lastSyncedQuietHours = widget.controller.quietHours;
        _qhFeedback = 'Quiet hours saved.';
        _qhIsError = false;
      } else {
        _qhFeedback = widget.controller.errorMessage ??
            'Unable to save quiet hours.';
        _qhIsError = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CompanionThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final canEdit = widget.controller.isConnected &&
            widget.controller.profileId != null &&
            widget.controller.profileId!.isNotEmpty;
        final timezoneOptions = kSupportedScheduleTimezones.contains(_qhTimezone)
            ? kSupportedScheduleTimezones
            : <String>[_qhTimezone, ...kSupportedScheduleTimezones];

        return SoftGlassPanel(
          key: const Key('quiet_hours_settings_card'),
          padding: const EdgeInsets.all(CompanionSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.bedtime_outlined,
                          size: 20,
                          color: ext?.accent,
                        ),
                        const SizedBox(width: CompanionSpacing.sm),
                        Flexible(
                          child: Text(
                            'Notifications & Quiet Hours',
                            style: CompanionTypography.titleMedium.copyWith(
                              color: ext?.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CompanionSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: CompanionRadius.borderSm,
                    ),
                    child: Text(
                      canEdit
                          ? (_qhEnabled ? 'Active' : 'Disabled')
                          : 'Connect Profile',
                      style: CompanionTypography.caption.copyWith(
                        color: ext?.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.sm),
              Text(
                'Alarms bypass quiet hours by default to ensure wakefulness.',
                style: CompanionTypography.bodySmall.copyWith(
                  color: ext?.textSecondary,
                ),
              ),
              const SizedBox(height: CompanionSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Quiet Hours',
                          style: CompanionTypography.bodyLarge.copyWith(
                            color: ext?.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Suppress routine check-ins and non-bypass reminders during quiet windows.',
                          style: CompanionTypography.bodySmall.copyWith(
                            color: ext?.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CompanionSpacing.md),
                  Switch(
                    key: const Key('quiet_hours_enabled_switch'),
                    value: _qhEnabled,
                    onChanged: canEdit && !_qhSaving
                        ? (v) => setState(() => _qhEnabled = v)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('quiet_hours_start_field'),
                      controller: _qhStartCtrl,
                      enabled: canEdit && !_qhSaving,
                      decoration: const InputDecoration(
                        labelText: 'Start Time (HH:MM)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: CompanionSpacing.md),
                  Expanded(
                    child: TextField(
                      key: const Key('quiet_hours_end_field'),
                      controller: _qhEndCtrl,
                      enabled: canEdit && !_qhSaving,
                      decoration: const InputDecoration(
                        labelText: 'End Time (HH:MM)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.md),
              KeyedSubtree(
                key: const Key('quiet_hours_timezone_dropdown'),
                child: DropdownButtonFormField<String>(
                  key: _tzFieldKey,
                  initialValue: _qhTimezone,
                  decoration: const InputDecoration(
                    labelText: 'Timezone',
                    border: OutlineInputBorder(),
                  ),
                  items: timezoneOptions
                      .map(
                        (tz) => DropdownMenuItem(
                          value: tz,
                          child: Text(tz),
                        ),
                      )
                      .toList(),
                  onChanged: canEdit && !_qhSaving
                      ? (v) {
                          if (v != null) {
                            setState(() => _qhTimezone = v);
                          }
                        }
                      : null,
                ),
              ),
              if (_qhFeedback != null) ...[
                const SizedBox(height: CompanionSpacing.md),
                Text(
                  _qhFeedback!,
                  key: const Key('quiet_hours_feedback_text'),
                  style: CompanionTypography.bodySmall.copyWith(
                    color: _qhIsError
                        ? (ext?.danger ?? CompanionColors.danger)
                        : (ext?.success ?? CompanionColors.success),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: CompanionSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('save_quiet_hours_button'),
                  onPressed: canEdit && !_qhSaving ? _saveQuietHours : null,
                  icon: _qhSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(_qhSaving ? 'Saving...' : 'Save Quiet Hours'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
