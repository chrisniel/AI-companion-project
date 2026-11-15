import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';

import 'desktop_schedule_controller.dart';

/// Shared helper to launch Flutter's TimePicker consistently in 12-hour AM/PM mode.
Future<TimeOfDay?> show12HourTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String? helpText,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    helpText: helpText,
    builder: (ctx, child) {
      return MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

TimeOfDay _parseHhMmOrDefault(String raw, TimeOfDay fallback) {
  final parts = raw.trim().split(':');
  if (parts.length != 2) return fallback;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return fallback;
  }
  return TimeOfDay(hour: h, minute: m);
}

String _toWireHhMm(TimeOfDay tod) {
  final h = tod.hour.toString().padLeft(2, '0');
  final m = tod.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Reactive Quiet Hours & Alert Sound configuration card rendered in SettingsScreen.
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
  late TimeOfDay _qhStartTime;
  late TimeOfDay _qhEndTime;
  late String _qhTimezone;
  late bool _useCustomTimezone;
  String? _qhFeedback;
  bool _qhIsError = false;
  bool _qhSaving = false;
  bool _testingSound = false;
  QuietHoursOut? _lastSyncedQuietHours;
  String? _lastKnownDeviceTz;
  final GlobalKey<FormFieldState<String>> _tzFieldKey =
      GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    final qh = widget.controller.quietHours;
    final devTz = widget.controller.deviceTimezone;
    _lastKnownDeviceTz = devTz;
    _qhEnabled = qh.quietHoursEnabled;
    _qhStartTime = _parseHhMmOrDefault(
      qh.quietHoursStart,
      const TimeOfDay(hour: 22, minute: 0),
    );
    _qhEndTime = _parseHhMmOrDefault(
      qh.quietHoursEnd,
      const TimeOfDay(hour: 7, minute: 0),
    );
    final rawTz = qh.quietHoursTimezone.trim();
    final hasCustom = rawTz.isNotEmpty && rawTz != 'UTC' && rawTz != devTz;
    _useCustomTimezone = hasCustom;
    _qhTimezone = (rawTz.isEmpty || rawTz == 'UTC') ? devTz : rawTz;
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
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _syncFromController();
  }

  void _syncFromController() {
    if (_qhSaving) return;
    final next = widget.controller.quietHours;
    final devTz = widget.controller.deviceTimezone;
    final prev = _lastSyncedQuietHours;
    final qhChanged = prev == null ||
        prev.quietHoursEnabled != next.quietHoursEnabled ||
        prev.quietHoursStart != next.quietHoursStart ||
        prev.quietHoursEnd != next.quietHoursEnd ||
        prev.quietHoursTimezone != next.quietHoursTimezone;
    final devTzChanged = _lastKnownDeviceTz != devTz;
    if (!qhChanged && !devTzChanged) return;

    setState(() {
      _lastKnownDeviceTz = devTz;
      if (qhChanged) {
        _qhEnabled = next.quietHoursEnabled;
        _qhStartTime = _parseHhMmOrDefault(next.quietHoursStart, _qhStartTime);
        _qhEndTime = _parseHhMmOrDefault(next.quietHoursEnd, _qhEndTime);
        final rawTz = next.quietHoursTimezone.trim();
        final hasCustom = rawTz.isNotEmpty && rawTz != 'UTC' && rawTz != devTz;
        _useCustomTimezone = hasCustom;
        _qhTimezone = (rawTz.isEmpty || rawTz == 'UTC') ? devTz : rawTz;
        _lastSyncedQuietHours = next;
      } else if (!_useCustomTimezone) {
        _qhTimezone = devTz;
      }
    });
    _tzFieldKey.currentState?.didChange(_qhTimezone);
  }

  Future<void> _pickStartTime() async {
    final picked = await show12HourTimePicker(
      context,
      initialTime: _qhStartTime,
      helpText: 'Quiet Hours Start Time',
    );
    if (picked == null || !mounted) return;
    setState(() => _qhStartTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await show12HourTimePicker(
      context,
      initialTime: _qhEndTime,
      helpText: 'Quiet Hours End Time',
    );
    if (picked == null || !mounted) return;
    setState(() => _qhEndTime = picked);
  }

  Future<void> _playTestSound() async {
    setState(() => _testingSound = true);
    final ok = await widget.controller.playTestAlertSound(isAlarm: false);
    if (!mounted) return;
    setState(() {
      _testingSound = false;
      _qhFeedback = ok
          ? 'Played test notification chime.'
          : 'Sound playback is available on the Windows desktop app.';
      _qhIsError = false;
    });
  }

  Future<void> _saveQuietHours() async {
    final targetTz =
        _useCustomTimezone ? _qhTimezone : widget.controller.deviceTimezone;
    setState(() {
      _qhSaving = true;
      _qhFeedback = null;
      _qhIsError = false;
    });

    final ok = await widget.controller.updateQuietHours(
      QuietHoursUpdate(
        quietHoursEnabled: _qhEnabled,
        quietHoursStart: _toWireHhMm(_qhStartTime),
        quietHoursEnd: _toWireHhMm(_qhEndTime),
        quietHoursTimezone: targetTz,
      ),
    );

    if (!mounted) return;
    setState(() {
      _qhSaving = false;
      if (ok) {
        _lastSyncedQuietHours = widget.controller.quietHours;
        _qhTimezone = widget.controller.quietHours.quietHoursTimezone;
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
        final deviceTz = widget.controller.deviceTimezone;
        final timezoneOptions = kSupportedScheduleTimezones.contains(_qhTimezone)
            ? kSupportedScheduleTimezones
            : <String>[_qhTimezone, ...kSupportedScheduleTimezones];
        final startDisplay =
            formatTimeOfDay12h(_qhStartTime.hour, _qhStartTime.minute);
        final endDisplay =
            formatTimeOfDay12h(_qhEndTime.hour, _qhEndTime.minute);

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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification Alert Sound',
                          style: CompanionTypography.bodyLarge.copyWith(
                            color: ext?.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Play Windows chime on live alarms, reminders, and routine alerts.',
                          style: CompanionTypography.bodySmall.copyWith(
                            color: ext?.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CompanionSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('test_alert_sound_button'),
                    onPressed: _testingSound ? null : _playTestSound,
                    icon: const Icon(Icons.volume_up_outlined, size: 16),
                    label: Text(_testingSound ? 'Playing...' : 'Test Sound'),
                  ),
                  const SizedBox(width: CompanionSpacing.sm),
                  Switch(
                    key: const Key('alert_sound_enabled_switch'),
                    value: widget.controller.alertSoundEnabled,
                    onChanged: widget.controller.setAlertSoundEnabled,
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _TimePickerTile(
                      key: const Key('quiet_hours_start_field'),
                      label: 'Quiet Starts',
                      value: startDisplay,
                      enabled: canEdit && !_qhSaving,
                      onTap: _pickStartTime,
                      ext: ext,
                    ),
                  ),
                  const SizedBox(width: CompanionSpacing.md),
                  Expanded(
                    child: _TimePickerTile(
                      key: const Key('quiet_hours_end_field'),
                      label: 'Quiet Ends',
                      value: endDisplay,
                      enabled: canEdit && !_qhSaving,
                      onTap: _pickEndTime,
                      ext: ext,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CompanionSpacing.md),
              Row(
                children: [
                  Icon(Icons.public_rounded, size: 16, color: ext?.textMuted),
                  const SizedBox(width: CompanionSpacing.xs),
                  Expanded(
                    child: Text(
                      _useCustomTimezone
                          ? 'Custom timezone active'
                          : 'Following PC timezone: $deviceTz',
                      key: const Key('quiet_hours_device_timezone_label'),
                      style: CompanionTypography.bodySmall.copyWith(
                        color: ext?.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('quiet_hours_custom_timezone_toggle'),
                    onPressed: canEdit && !_qhSaving
                        ? () => setState(() {
                              _useCustomTimezone = !_useCustomTimezone;
                              if (!_useCustomTimezone) {
                                _qhTimezone = deviceTz;
                              }
                            })
                        : null,
                    child: Text(
                      _useCustomTimezone
                          ? 'Use PC timezone'
                          : 'Custom timezone (advanced)',
                    ),
                  ),
                ],
              ),
              if (_useCustomTimezone) ...[
                const SizedBox(height: CompanionSpacing.sm),
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
              ],
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

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.ext,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;
  final CompanionThemeExtension? ext;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: CompanionRadius.borderMd,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.schedule_rounded, size: 18),
        ),
        child: Text(
          value,
          style: CompanionTypography.bodyLarge.copyWith(
            color: enabled ? ext?.textPrimary : ext?.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
