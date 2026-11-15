import 'dart:async';

import 'package:companion_api/companion_api.dart';
import 'package:flutter/foundation.dart';

import '../../platform/windows_toast_adapter.dart';

enum ScheduleSection { tasks, reminders, alarms, routines, notifications }

enum ToastNavigationTarget { chat, schedule, backlogDrawer }

/// Curated canonical timezone identifiers accepted by backend
/// `SchedulerService.resolve_timezone()` (`_BUILTIN_IANA_ZONES` + UTC),
/// alongside free-form `UTC+HH:MM` / `UTC-HH:MM` fixed offset support.
const List<String> kSupportedScheduleTimezones = <String>[
  'UTC',
  'Asia/Manila',
  'Asia/Tokyo',
  'Asia/Seoul',
  'Asia/Singapore',
  'Asia/Shanghai',
  'Asia/Hong_Kong',
  'Asia/Taipei',
  'Asia/Bangkok',
  'Asia/Jakarta',
  'Asia/Kolkata',
  'Asia/Dubai',
  'Australia/Sydney',
  'Australia/Melbourne',
  'Pacific/Auckland',
  'Europe/London',
  'Europe/Dublin',
  'Europe/Paris',
  'Europe/Berlin',
  'Europe/Amsterdam',
  'Europe/Madrid',
  'Europe/Rome',
  'Europe/Zurich',
  'Europe/Warsaw',
  'Europe/Athens',
  'America/New_York',
  'America/Toronto',
  'America/Chicago',
  'America/Denver',
  'America/Phoenix',
  'America/Los_Angeles',
  'America/Vancouver',
  'America/Anchorage',
  'Pacific/Honolulu',
  'America/Sao_Paulo',
  'America/Mexico_City',
  'Africa/Johannesburg',
  'Africa/Cairo',
];

const List<String> _kMonthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

final RegExp _kTrailingOffsetPattern = RegExp(
  r'(?:[zZ]|[+-]\d{2}:?\d{2})$',
);
final RegExp _kFixedOffsetTimezonePattern = RegExp(
  r'^(?:UTC|GMT)?([+-])(\d{1,2})(?::?(\d{2}))?$',
);

/// Computes a canonical fixed-offset timezone string accepted by backend
/// `SchedulerService.resolve_timezone()` from a local offset (for example
/// `UTC+08:00` or `UTC`).
String computeDeviceOffsetTimezone([Duration? offset]) {
  final effective = offset ?? DateTime.now().timeZoneOffset;
  final totalMinutes = effective.inMinutes;
  if (totalMinutes == 0) {
    return 'UTC';
  }
  final sign = totalMinutes >= 0 ? '+' : '-';
  final absMinutes = totalMinutes.abs();
  final hours = (absMinutes ~/ 60).toString().padLeft(2, '0');
  final mins = (absMinutes % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$mins';
}

/// Returns true when [tz] is either in [kSupportedScheduleTimezones] or matches
/// the backend fixed-offset pattern (`UTC+HH:MM` / `UTC-HH:MM`).
bool isSupportedScheduleTimezone(String tz) {
  final trimmed = tz.trim();
  if (trimmed.isEmpty) return false;
  return kSupportedScheduleTimezones.contains(trimmed) ||
      _kFixedOffsetTimezonePattern.hasMatch(trimmed);
}

/// Parses a server ISO-8601 timestamp into local [DateTime].
///
/// Naive ISO strings without an explicit trailing `Z` or numeric offset are
/// treated as UTC before converting to `.toLocal()` so SQLite naive UTC
/// datetimes never shift by the local timezone offset.
DateTime? parseServerUtcDateTime(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final normalized =
      _kTrailingOffsetPattern.hasMatch(trimmed) ? trimmed : '${trimmed}Z';
  return DateTime.tryParse(normalized)?.toLocal();
}

/// Formats an hour/minute pair in crisp 12-hour AM/PM clock form (e.g. `7:00 AM`, `10:30 PM`).
String formatTimeOfDay12h(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final minStr = minute.toString().padLeft(2, '0');
  return '$hour12:$minStr $period';
}

/// Formats a wire `HH:MM` 24-hour clock string for 12-hour AM/PM display.
String formatHhMm12h(String? hhmm) {
  if (hhmm == null || hhmm.trim().isEmpty) return '';
  final parts = hhmm.trim().split(':');
  if (parts.length != 2) return hhmm.trim();
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return hhmm.trim();
  }
  return formatTimeOfDay12h(h, m);
}

/// Formats a local [DateTime] date portion as `Nov 15, 2026`.
String formatDate12h(DateTime local) {
  final dt = local.toLocal();
  final month = _kMonthAbbreviations[dt.month - 1];
  return '$month ${dt.day}, ${dt.year}';
}

/// Formats a local [DateTime] as `Nov 15, 2026 · 6:30 PM`.
String formatDateTime12h(DateTime local) {
  final dt = local.toLocal();
  return '${formatDate12h(dt)} · ${formatTimeOfDay12h(dt.hour, dt.minute)}';
}

/// Profile-scoped, epoch-fenced state controller for Tasks, Reminders, Alarms,
/// Routines, Notification Backlog, Quiet Hours, and native Windows Toasts.
class DesktopScheduleController extends ChangeNotifier {
  DesktopScheduleController({
    CompanionClient? client,
    CompanionClient Function()? clientProvider,
    DesktopToastAdapter? toastAdapter,
    String? profileId,
    bool isConnected = true,
    Duration pollInterval = const Duration(seconds: 15),
    this.onNavigateRequested,
  })  : assert(
          client != null || clientProvider != null,
          'Either client or clientProvider must be provided.',
        ),
        _clientProvider = clientProvider ?? (() => client!),
        _toastAdapter = toastAdapter ?? NoOpDesktopToastAdapter(),
        _profileId = profileId,
        _isConnected = isConnected,
        _pollInterval = pollInterval,
        _deviceTimezone = computeDeviceOffsetTimezone() {
    _toastActivationSub = _toastAdapter.activations.listen(_handleToastActivation);
    unawaited(_resolveDeviceTimezone());
  }

  final CompanionClient Function() _clientProvider;
  final DesktopToastAdapter _toastAdapter;
  final Duration _pollInterval;
  void Function(ToastNavigationTarget target)? onNavigateRequested;

  StreamSubscription<ToastActivationEvent>? _toastActivationSub;
  Timer? _pollTimer;

  String? _profileId;
  bool _isConnected;
  int _scopeEpoch = 0;
  bool _disposed = false;

  String _deviceTimezone;
  bool _alertSoundEnabled = true;

  ScheduleSection _selectedSection = ScheduleSection.tasks;
  bool _showTrashTasks = false;
  bool _unreadOnlyFilter = false;
  bool _isLoading = false;
  bool _isMutating = false;
  bool _isPolling = false;
  String? _errorMessage;

  List<TaskResponse> _tasks = const [];
  List<TrashTaskResponse> _trashTasks = const [];
  List<ReminderOut> _reminders = const [];
  List<AlarmOut> _alarms = const [];
  List<RoutineOut> _routines = const [];
  List<NotificationEventOut> _notifications = const [];
  List<NotificationEventOut> _unreadNotifications = const [];
  int _unreadCount = 0;
  int _missedCount = 0;
  QuietHoursOut _quietHours = const QuietHoursOut();

  final Set<String> _dispatchedToastEventIds = <String>{};

  CompanionClient get client => _clientProvider();
  DesktopToastAdapter get toastAdapter => _toastAdapter;
  String? get profileId => _profileId;
  bool get isConnected => _isConnected;

  /// Windows/device timezone string (IANA zone from OS when available, else
  /// deterministic `UTC+HH:MM` offset) used as the automatic default across
  /// scheduling dialogs and Quiet Hours.
  String get deviceTimezone => _deviceTimezone;

  /// Effective default timezone for new items: follows device timezone unless
  /// Quiet Hours has been explicitly customized away from `'UTC'`.
  String get effectiveDefaultTimezone {
    final qhTz = _quietHours.quietHoursTimezone.trim();
    if (qhTz.isNotEmpty && qhTz != 'UTC') {
      return qhTz;
    }
    return _deviceTimezone;
  }

  bool get alertSoundEnabled => _alertSoundEnabled;

  ScheduleSection get selectedSection => _selectedSection;
  bool get showTrashTasks => _showTrashTasks;
  bool get unreadOnlyFilter => _unreadOnlyFilter;
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  bool get isPollingActive => _pollTimer != null;
  String? get errorMessage => _errorMessage;

  List<TaskResponse> get tasks => List.unmodifiable(_tasks);
  List<TrashTaskResponse> get trashTasks => List.unmodifiable(_trashTasks);
  List<ReminderOut> get reminders => List.unmodifiable(_reminders);
  List<AlarmOut> get alarms => List.unmodifiable(_alarms);
  List<RoutineOut> get routines => List.unmodifiable(_routines);
  List<NotificationEventOut> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  int get missedCount => _missedCount;
  QuietHoursOut get quietHours => _quietHours;

  /// Active in-app alert banner items: strictly status == 'unread' (excludes
  /// `suppressed_quiet_hours` so Quiet Hours are honored and excludes
  /// `missed_catchup` which surfaces via the Sleep Catch-up summary).
  List<NotificationEventOut> get activeAlerts {
    final source =
        _unreadNotifications.isNotEmpty ? _unreadNotifications : _notifications;
    final active = source.where((e) => e.status == 'unread').toList();
    active.sort((a, b) {
      final aHigh = (a.urgency == 'high' || a.sourceType == 'alarm') ? 0 : 1;
      final bHigh = (b.urgency == 'high' || b.sourceType == 'alarm') ? 0 : 1;
      if (aHigh != bHigh) return aHigh.compareTo(bHigh);
      return b.triggeredAt.compareTo(a.triggeredAt);
    });
    return List.unmodifiable(active);
  }

  bool get _hasActiveScope =>
      !_disposed && _isConnected && _profileId != null && _profileId!.isNotEmpty;

  bool _isCurrentEpoch(int epoch) => !_disposed && epoch == _scopeEpoch;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void selectSection(ScheduleSection section) {
    if (_selectedSection == section) return;
    _selectedSection = section;
    _safeNotify();
  }

  void setShowTrashTasks(bool value) {
    if (_showTrashTasks == value) return;
    _showTrashTasks = value;
    _safeNotify();
  }

  Future<void> setUnreadOnlyFilter(bool value) async {
    if (_unreadOnlyFilter == value) return;
    _unreadOnlyFilter = value;
    _safeNotify();
    await loadNotifications();
  }

  /// Updates active Profile / connection scope, cancelling older in-flight
  /// calls and clearing cached entities + Action Center toasts on switch/disconnect.
  void updateProfileScope({
    required String? profileId,
    required bool isConnected,
  }) {
    final scopeChanged =
        _profileId != profileId || _isConnected != isConnected;
    if (!scopeChanged) return;

    _profileId = profileId;
    _isConnected = isConnected;
    _scopeEpoch++;
    _clearInMemoryState();
    unawaited(_toastAdapter.clearAllNotificationToasts());

    if (!isConnected || profileId == null || profileId.isEmpty) {
      stopPolling();
    }
    _safeNotify();
  }

  /// Clears all profile-owned state, active alerts, and Action Center toasts
  /// immediately on disconnect, session expiry, or profile switch.
  void clearForDisconnect() {
    updateProfileScope(profileId: null, isConnected: false);
  }

  void _clearInMemoryState() {
    _errorMessage = null;
    _tasks = const [];
    _trashTasks = const [];
    _reminders = const [];
    _alarms = const [];
    _routines = const [];
    _notifications = const [];
    _unreadNotifications = const [];
    _unreadCount = 0;
    _missedCount = 0;
    _quietHours = const QuietHoursOut();
    _dispatchedToastEventIds.clear();
  }

  void startPolling() {
    if (_disposed || !_hasActiveScope || _pollTimer != null) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(pollNotifications());
    });
    _safeNotify();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _resolveDeviceTimezone() async {
    try {
      final nativeTz = await _toastAdapter.getDeviceTimezone();
      if (_disposed || nativeTz == null) return;
      final trimmed = nativeTz.trim();
      if (isSupportedScheduleTimezone(trimmed) && _deviceTimezone != trimmed) {
        _deviceTimezone = trimmed;
        _safeNotify();
      }
    } catch (e) {
      debugPrint('DesktopScheduleController._resolveDeviceTimezone failed: $e');
    }
  }

  void setAlertSoundEnabled(bool enabled) {
    if (_alertSoundEnabled == enabled) return;
    _alertSoundEnabled = enabled;
    _safeNotify();
  }

  Future<bool> playTestAlertSound({bool isAlarm = false}) {
    return _toastAdapter.playAlertSound(isAlarm: isAlarm);
  }

  Future<void> refreshAll() async {
    if (!_hasActiveScope) return;
    final epoch = _scopeEpoch;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await Future.wait([
        _loadTasksInternal(epoch),
        _loadRemindersInternal(epoch),
        _loadAlarmsInternal(epoch),
        _loadRoutinesInternal(epoch),
        _loadNotificationsInternal(epoch),
        _loadQuietHoursInternal(epoch),
      ]);
      if (_isCurrentEpoch(epoch)) {
        _unreadNotifications = _notifications
            .where(
              (e) =>
                  e.status == 'unread' ||
                  e.status == 'suppressed_quiet_hours' ||
                  e.status == 'missed_catchup',
            )
            .toList();
        await _dispatchPendingToasts(_unreadNotifications, epoch);
      }
    } catch (e) {
      if (_isCurrentEpoch(epoch)) {
        _errorMessage = _formatError(e);
      }
    } finally {
      if (_isCurrentEpoch(epoch)) {
        _isLoading = false;
        _safeNotify();
      }
    }
  }

  Future<void> loadTasks() async {
    if (!_hasActiveScope) return;
    final epoch = _scopeEpoch;
    try {
      await _loadTasksInternal(epoch);
      if (_isCurrentEpoch(epoch)) _safeNotify();
    } catch (e) {
      if (_isCurrentEpoch(epoch)) {
        _errorMessage = _formatError(e);
        _safeNotify();
      }
    }
  }

  Future<void> _loadTasksInternal(int epoch) async {
    final activeRes = await client.listTasks(limit: 100);
    final trashRes = await client.listTrashTasks(limit: 100);
    if (!_isCurrentEpoch(epoch)) return;
    _tasks = activeRes.items;
    _trashTasks = trashRes.items;
  }

  Future<void> loadReminders() async {
    if (!_hasActiveScope) return;
    final epoch = _scopeEpoch;
    try {
      await _loadRemindersInternal(epoch);
      if (_isCurrentEpoch(epoch)) _safeNotify();
    } catch (e) {
      if (_isCurrentEpoch(epoch)) {
        _errorMessage = _formatError(e);
        _safeNotify();
      }
    }
  }

  Future<void> _loadRemindersInternal(int epoch) async {
    final res = await client.listReminders(limit: 100);
    if (!_isCurrentEpoch(epoch)) return;
    _reminders = res.items;
  }

  Future<void> loadAlarms() async {
    if (!_hasActiveScope) return;
    final epoch = _scopeEpoch;
    try {
      await _loadAlarmsInternal(epoch);
      if (_isCurrentEpoch(epoch)) _safeNotify();
    } catch (e) {
      if (_isCurrentEpoch(epoch)) {
        _errorMessage = _formatError(e);
        _safeNotify();
      }
    }
  }

  Future<void> _loadAlarmsInternal(int epoch) async {
    final res = await client.listAlarms(limit: 100);
    if (!_isCurrentEpoch(epoch)) return;
    _alarms = res.items;
  }

  Future<void> loadRoutines() async {
    if (!_hasActiveScope) return;
    final epoch = _scopeEpoch;
    try {
      await _loadRoutinesInternal(epoch);
      if (_isCurrentEpoch(epoch)) _safeNotify();
    } catch (e) {
      if (_isCurrentEpoch(epoch)) {
        _errorMessage = _formatError(e);
        _safeNotify();
      }
    }
  }

  Future<void> _loadRoutinesInternal(int epoch) async {
    final res = await client.listRoutines(limit: 100);
    if (!_isCurrentEpoch(epoch)) return;
    _routines = res.items;
  }

  Future<void> loadNotifications() async {
    if (!_hasActiveScope) return;
    final epoch = _scopeEpoch;
    try {
      await _loadNotificationsInternal(epoch);
      if (_isCurrentEpoch(epoch)) _safeNotify();
    } catch (e) {
      if (_isCurrentEpoch(epoch)) {
        _errorMessage = _formatError(e);
        _safeNotify();
      }
    }
  }

  Future<void> _loadNotificationsInternal(int epoch) async {
    final res = await client.listNotifications(
      unreadOnly: _unreadOnlyFilter,
      limit: 50,
    );
    if (!_isCurrentEpoch(epoch)) return;
    _notifications = res.items;
    _unreadCount = res.unreadCount;
    _missedCount = res.missedCount;
  }

  Future<void> loadQuietHours() async {
    if (!_hasActiveScope) return;
    final epoch = _scopeEpoch;
    try {
      await _loadQuietHoursInternal(epoch);
      if (_isCurrentEpoch(epoch)) _safeNotify();
    } catch (e) {
      if (_isCurrentEpoch(epoch)) {
        _errorMessage = _formatError(e);
        _safeNotify();
      }
    }
  }

  Future<void> _loadQuietHoursInternal(int epoch) async {
    final res = await client.getQuietHours();
    if (!_isCurrentEpoch(epoch)) return;
    _quietHours = res;
  }

  /// Polls `unread_only=true` notifications so historical resolved entries
  /// never crowd out active or missed catch-up alerts, and dispatches native
  /// Windows Action Center toasts once per unseen event per session.
  Future<void> pollNotifications() async {
    if (!_hasActiveScope || _isPolling) return;
    _isPolling = true;
    final epoch = _scopeEpoch;
    try {
      final res = await client.listNotifications(unreadOnly: true, limit: 50);
      if (!_isCurrentEpoch(epoch)) return;

      _unreadNotifications = res.items;
      _unreadCount = res.unreadCount;
      _missedCount = res.missedCount;

      if (_unreadOnlyFilter || _notifications.isEmpty) {
        _notifications = res.items;
      } else {
        _mergeUnreadIntoNotifications(res.items);
      }

      await _dispatchPendingToasts(res.items, epoch);
      if (_isCurrentEpoch(epoch)) {
        _safeNotify();
      }
    } catch (e) {
      debugPrint('DesktopScheduleController.pollNotifications failed: $e');
    } finally {
      _isPolling = false;
    }
  }

  void _mergeUnreadIntoNotifications(List<NotificationEventOut> freshUnread) {
    final byId = <String, NotificationEventOut>{
      for (final item in freshUnread) item.id: item,
    };
    final merged = <NotificationEventOut>[...freshUnread];
    for (final existing in _notifications) {
      if (!byId.containsKey(existing.id)) {
        merged.add(existing);
      }
    }
    _notifications = merged;
  }

  Future<void> _dispatchPendingToasts(
    List<NotificationEventOut> items,
    int epoch,
  ) async {
    if (!_isCurrentEpoch(epoch)) return;
    const candidateStatuses = <String>{
      'unread',
      'suppressed_quiet_hours',
      'missed_catchup',
    };
    final unseen = items
        .where(
          (e) =>
              candidateStatuses.contains(e.status) &&
              !_dispatchedToastEventIds.contains(e.id),
        )
        .toList();
    if (unseen.isEmpty) return;

    final catchups = unseen
        .where((e) => e.isMissedCatchup || e.status == 'missed_catchup')
        .toList();
    final live = unseen
        .where((e) => !e.isMissedCatchup && e.status != 'missed_catchup')
        .toList();

    for (final item in unseen) {
      _dispatchedToastEventIds.add(item.id);
    }

    if (catchups.isNotEmpty) {
      await _toastAdapter.showMissedCatchupSummaryToast(
        missedCount: _missedCount > catchups.length ? _missedCount : catchups.length,
        events: catchups,
      );
    }

    for (final event in live) {
      if (!_isCurrentEpoch(epoch)) return;
      final isSuppressedRoutine = event.sourceType == 'routine' &&
          (event.deliveryPolicy == 'quiet_hours_suppressed' ||
              event.status == 'suppressed_quiet_hours');
      if (isSuppressedRoutine) {
        continue;
      }
      final hasLinkedTask = event.sourceType == 'task_reminder' ||
          _reminders.any((r) => r.id == event.sourceId && r.taskId != null);
      await _toastAdapter.showNotificationToast(
        event,
        hasLinkedTask: hasLinkedTask,
        playSound: _alertSoundEnabled,
      );
    }
  }

  Future<T?> _runMutation<T>(Future<T> Function() op) async {
    if (!_hasActiveScope) return null;
    final epoch = _scopeEpoch;
    _isMutating = true;
    _errorMessage = null;
    _safeNotify();
    try {
      final res = await op();
      return _isCurrentEpoch(epoch) ? res : null;
    } catch (e) {
      if (_isCurrentEpoch(epoch)) {
        _errorMessage = _formatError(e);
      }
      return null;
    } finally {
      if (_isCurrentEpoch(epoch)) {
        _isMutating = false;
        _safeNotify();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  Future<bool> createTask(TaskCreate payload) async {
    final created = await _runMutation(() => client.createTask(payload));
    if (created == null) return false;
    await Future.wait([loadTasks(), loadReminders()]);
    return true;
  }

  Future<bool> updateTask(
    String taskId,
    TaskUpdate payload, {
    bool clearNotes = false,
    bool clearDueDate = false,
    bool clearReminderMinutesBefore = false,
    bool clearReminderAt = false,
  }) async {
    final updated = await _runMutation(
      () => client.updateTask(
        taskId,
        payload,
        clearNotes: clearNotes,
        clearDueDate: clearDueDate,
        clearReminderMinutesBefore: clearReminderMinutesBefore,
        clearReminderAt: clearReminderAt,
      ),
    );
    if (updated == null) return false;
    await Future.wait([loadTasks(), loadReminders(), loadNotifications()]);
    return true;
  }

  Future<bool> toggleTaskCompletion(TaskResponse task) async {
    final nextStatus = task.status == 'completed' ? 'pending' : 'completed';
    return updateTask(task.id, TaskUpdate(status: nextStatus));
  }

  Future<bool> deleteTask(String taskId) async {
    final ok = await _runMutation(() async {
      await client.deleteTask(taskId);
      return true;
    });
    if (ok != true) return false;
    await Future.wait([loadTasks(), loadReminders(), loadNotifications()]);
    return true;
  }

  Future<bool> restoreTask(String taskId) async {
    final restored = await _runMutation(() => client.restoreTask(taskId));
    if (restored == null) return false;
    await loadTasks();
    return true;
  }

  Future<bool> permanentDeleteTask(String taskId) async {
    final ok = await _runMutation(() async {
      await client.permanentDeleteTask(taskId);
      return true;
    });
    if (ok != true) return false;
    await loadTasks();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Reminders
  // ---------------------------------------------------------------------------

  Future<bool> createReminder(ReminderCreate payload) async {
    final created = await _runMutation(() => client.createReminder(payload));
    if (created == null) return false;
    await loadReminders();
    return true;
  }

  Future<bool> updateReminder(String reminderId, ReminderUpdate payload) async {
    final updated =
        await _runMutation(() => client.updateReminder(reminderId, payload));
    if (updated == null) return false;
    await loadReminders();
    return true;
  }

  Future<bool> deleteReminder(String reminderId) async {
    final ok = await _runMutation(() async {
      await client.deleteReminder(reminderId);
      return true;
    });
    if (ok != true) return false;
    await Future.wait([loadReminders(), loadNotifications()]);
    return true;
  }

  Future<bool> snoozeReminder(String reminderId, {int minutes = 10}) async {
    final res = await _runMutation(
      () => client.snoozeReminder(
        reminderId,
        payload: SnoozeRequest(minutes: minutes),
      ),
    );
    if (res == null) return false;
    await Future.wait([loadReminders(), pollNotifications()]);
    return true;
  }

  Future<bool> acknowledgeReminder(
    String reminderId, {
    bool completeTask = true,
  }) async {
    final res = await _runMutation(
      () => client.acknowledgeReminder(
        reminderId,
        payload: AcknowledgeRequest(completeTask: completeTask),
      ),
    );
    if (res == null) return false;
    await Future.wait([loadReminders(), loadTasks(), pollNotifications()]);
    return true;
  }

  Future<bool> dismissReminder(String reminderId) async {
    final res = await _runMutation(() => client.dismissReminder(reminderId));
    if (res == null) return false;
    await Future.wait([loadReminders(), pollNotifications()]);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Alarms
  // ---------------------------------------------------------------------------

  Future<bool> createAlarm(AlarmCreate payload) async {
    final created = await _runMutation(() => client.createAlarm(payload));
    if (created == null) return false;
    await loadAlarms();
    return true;
  }

  Future<bool> updateAlarm(String alarmId, AlarmUpdate payload) async {
    final updated =
        await _runMutation(() => client.updateAlarm(alarmId, payload));
    if (updated == null) return false;
    await loadAlarms();
    return true;
  }

  Future<bool> toggleAlarmEnabled(AlarmOut alarm, bool enabled) {
    return updateAlarm(alarm.id, AlarmUpdate(enabled: enabled));
  }

  Future<bool> deleteAlarm(String alarmId) async {
    final ok = await _runMutation(() async {
      await client.deleteAlarm(alarmId);
      return true;
    });
    if (ok != true) return false;
    await Future.wait([loadAlarms(), loadNotifications()]);
    return true;
  }

  Future<bool> snoozeAlarm(String alarmId, {int minutes = 10}) async {
    final res = await _runMutation(
      () => client.snoozeAlarm(
        alarmId,
        payload: SnoozeRequest(minutes: minutes),
      ),
    );
    if (res == null) return false;
    await Future.wait([loadAlarms(), pollNotifications()]);
    return true;
  }

  Future<bool> acknowledgeAlarm(String alarmId) async {
    final res = await _runMutation(() => client.acknowledgeAlarm(alarmId));
    if (res == null) return false;
    await Future.wait([loadAlarms(), pollNotifications()]);
    return true;
  }

  Future<bool> dismissAlarm(String alarmId) async {
    final res = await _runMutation(() => client.dismissAlarm(alarmId));
    if (res == null) return false;
    await Future.wait([loadAlarms(), pollNotifications()]);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Routines
  // ---------------------------------------------------------------------------

  Future<bool> createRoutine(RoutineCreate payload) async {
    final created = await _runMutation(() => client.createRoutine(payload));
    if (created == null) return false;
    await loadRoutines();
    return true;
  }

  Future<bool> updateRoutine(String routineId, RoutineUpdate payload) async {
    final updated =
        await _runMutation(() => client.updateRoutine(routineId, payload));
    if (updated == null) return false;
    await loadRoutines();
    return true;
  }

  Future<bool> toggleRoutineEnabled(RoutineOut routine, bool enabled) {
    return updateRoutine(routine.id, RoutineUpdate(enabled: enabled));
  }

  Future<bool> deleteRoutine(String routineId) async {
    final ok = await _runMutation(() async {
      await client.deleteRoutine(routineId);
      return true;
    });
    if (ok != true) return false;
    await Future.wait([loadRoutines(), loadNotifications()]);
    return true;
  }

  Future<NotificationEventOut?> runRoutineNow(String routineId) async {
    final ev = await _runMutation(() => client.runRoutineNow(routineId));
    if (ev == null) return null;
    await Future.wait([loadRoutines(), pollNotifications()]);
    return ev;
  }

  // ---------------------------------------------------------------------------
  // Notification Backlog & Action Center Sync
  // ---------------------------------------------------------------------------

  Future<bool> markNotificationRead(String eventId) async {
    final updated =
        await _runMutation(() => client.markNotificationRead(eventId));
    if (updated == null) return false;
    await pollNotifications();
    return true;
  }

  Future<bool> acknowledgeNotification(
    String eventId, {
    bool completeTask = false,
  }) async {
    final updated = await _runMutation(
      () => client.acknowledgeNotification(
        eventId,
        payload: AcknowledgeRequest(completeTask: completeTask),
      ),
    );
    if (updated == null) return false;
    await _toastAdapter.removeNotificationToast(eventId);
    final refreshes = <Future<void>>[
      loadNotifications(),
      pollNotifications(),
      loadReminders(),
      loadAlarms(),
    ];
    if (completeTask) {
      refreshes.add(loadTasks());
    }
    await Future.wait(refreshes);
    return true;
  }

  Future<bool> snoozeNotification(String eventId, {int minutes = 10}) async {
    final updated = await _runMutation(
      () => client.snoozeNotification(
        eventId,
        payload: SnoozeRequest(minutes: minutes),
      ),
    );
    if (updated == null) return false;
    await _toastAdapter.removeNotificationToast(eventId);
    await Future.wait([
      loadNotifications(),
      pollNotifications(),
      loadReminders(),
      loadAlarms(),
    ]);
    return true;
  }

  Future<bool> dismissNotification(String eventId) async {
    final updated =
        await _runMutation(() => client.dismissNotification(eventId));
    if (updated == null) return false;
    await _toastAdapter.removeNotificationToast(eventId);
    await Future.wait([
      loadNotifications(),
      pollNotifications(),
      loadReminders(),
      loadAlarms(),
    ]);
    return true;
  }

  Future<bool> clearAllNotifications() async {
    final cleared = await _runMutation(() => client.clearAllNotifications());
    if (cleared == null) return false;
    await _toastAdapter.clearAllNotificationToasts();
    await Future.wait([
      loadNotifications(),
      pollNotifications(),
    ]);
    return true;
  }

  Future<bool> updateQuietHours(QuietHoursUpdate payload) async {
    final updated = await _runMutation(() => client.updateQuietHours(payload));
    if (updated == null) return false;
    _quietHours = updated;
    _safeNotify();
    return true;
  }

  Future<void> _handleToastActivation(ToastActivationEvent activation) async {
    if (!_hasActiveScope) return;
    final eventId = activation.eventId;

    switch (activation.action) {
      case 'mark_done':
        if (eventId != null && eventId.isNotEmpty) {
          await acknowledgeNotification(eventId, completeTask: true);
        }
        break;
      case 'acknowledge':
        if (eventId != null && eventId.isNotEmpty) {
          await acknowledgeNotification(eventId, completeTask: false);
        }
        break;
      case 'snooze_10m':
        if (eventId != null && eventId.isNotEmpty) {
          await snoozeNotification(eventId, minutes: 10);
        }
        break;
      case 'dismiss':
        if (eventId != null && eventId.isNotEmpty) {
          await dismissNotification(eventId);
        }
        break;
      case 'open_chat':
        if (eventId != null && eventId.isNotEmpty) {
          await markNotificationRead(eventId);
        }
        onNavigateRequested?.call(ToastNavigationTarget.chat);
        break;
      case 'open_backlog':
        onNavigateRequested?.call(ToastNavigationTarget.backlogDrawer);
        break;
      case 'open_schedule':
      default:
        selectSection(ScheduleSection.notifications);
        onNavigateRequested?.call(ToastNavigationTarget.schedule);
        break;
    }
  }

  String _formatError(Object error) {
    if (error is CompanionApiException) {
      return error.message;
    }
    return error.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    _toastActivationSub?.cancel();
    super.dispose();
  }
}
