import 'dart:async';
import 'dart:io';

import 'package:companion_api/companion_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Parsed user interaction callback emitted when clicking a Windows toast
/// body or action button in Action Center.
@immutable
class ToastActivationEvent {
  const ToastActivationEvent({
    required this.action,
    this.eventId,
    this.rawArguments = '',
  });

  factory ToastActivationEvent.fromQueryString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const ToastActivationEvent(action: 'open_schedule', rawArguments: '');
    }
    final params = Uri.splitQueryString(trimmed);
    return ToastActivationEvent(
      action: params['action'] ?? 'open_schedule',
      eventId: params['event_id'],
      rawArguments: raw,
    );
  }

  final String action;
  final String? eventId;
  final String rawArguments;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToastActivationEvent &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          eventId == other.eventId &&
          rawArguments == other.rawArguments;

  @override
  int get hashCode => Object.hash(action, eventId, rawArguments);
}

/// Abstract platform adapter for desktop OS toast notifications and two-way
/// Action Center callbacks.
abstract class DesktopToastAdapter {
  Stream<ToastActivationEvent> get activations;

  Future<bool> showNotificationToast(
    NotificationEventOut event, {
    bool hasLinkedTask = false,
  });

  Future<bool> showMissedCatchupSummaryToast({
    required int missedCount,
    required List<NotificationEventOut> events,
  });

  Future<bool> removeNotificationToast(String eventId);

  Future<bool> clearAllNotificationToasts();

  void dispose() {}
}

/// Safe no-op adapter used on non-Windows platforms and automated widget tests.
class NoOpDesktopToastAdapter implements DesktopToastAdapter {
  final StreamController<ToastActivationEvent> _controller =
      StreamController<ToastActivationEvent>.broadcast();

  @override
  Stream<ToastActivationEvent> get activations => _controller.stream;

  @override
  Future<bool> showNotificationToast(
    NotificationEventOut event, {
    bool hasLinkedTask = false,
  }) async =>
      false;

  @override
  Future<bool> showMissedCatchupSummaryToast({
    required int missedCount,
    required List<NotificationEventOut> events,
  }) async =>
      false;

  @override
  Future<bool> removeNotificationToast(String eventId) async => false;

  @override
  Future<bool> clearAllNotificationToasts() async => false;

  @override
  void dispose() {
    _controller.close();
  }
}

/// Native in-process Windows 10/11 C++/WinRT Action Center toast adapter
/// communicating over [MethodChannel('ai_companion/windows_notifications')].
class WindowsWinRtToastAdapter implements DesktopToastAdapter {
  WindowsWinRtToastAdapter({
    MethodChannel? channel,
    bool? isWindowsOverride,
  })  : _channel = channel ?? const MethodChannel(defaultChannelName),
        _isWindowsOverride = isWindowsOverride {
    if (_isWindowsPlatform) {
      _channel.setMethodCallHandler(_handlePlatformMethodCall);
    }
  }

  static const String defaultChannelName = 'ai_companion/windows_notifications';
  static const String defaultToastGroup = 'ai_companion_alerts';
  static const String catchupSummaryTag = 'catchup_summary';

  final MethodChannel _channel;
  final bool? _isWindowsOverride;
  final StreamController<ToastActivationEvent> _activationsController =
      StreamController<ToastActivationEvent>.broadcast();

  bool get _isWindowsPlatform => _isWindowsOverride ?? Platform.isWindows;

  @override
  Stream<ToastActivationEvent> get activations => _activationsController.stream;

  Future<dynamic> _handlePlatformMethodCall(MethodCall call) async {
    if (call.method == 'onToastActivated' && !_activationsController.isClosed) {
      String raw = '';
      if (call.arguments is Map) {
        final argsMap = Map<String, dynamic>.from(call.arguments as Map);
        raw = argsMap['arguments']?.toString() ?? '';
      } else if (call.arguments is String) {
        raw = call.arguments as String;
      }
      _activationsController.add(ToastActivationEvent.fromQueryString(raw));
    }
    return null;
  }

  /// Deterministic Windows toast tag (<= 60 chars) for an event ID.
  static String toastTagForEvent(String eventId) {
    final sanitized = eventId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final prefixed = 'evt_$sanitized';
    if (prefixed.length <= 60) {
      return prefixed;
    }
    final hash = eventId.hashCode.toUnsigned(32).toRadixString(16);
    return 'evt_${hash}_${sanitized.substring(0, 44)}';
  }

  /// Removes XML 1.0 illegal control characters while preserving tab/LF/CR
  /// and UTF-16 surrogate pairs.
  static String sanitizeXmlText(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      final isIllegal = (codeUnit >= 0x00 && codeUnit <= 0x08) ||
          codeUnit == 0x0B ||
          codeUnit == 0x0C ||
          (codeUnit >= 0x0E && codeUnit <= 0x1F) ||
          codeUnit == 0xFFFE ||
          codeUnit == 0xFFFF;
      if (!isIllegal) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  /// Escapes XML special characters after stripping invalid control codes.
  static String escapeXml(String input) {
    return sanitizeXmlText(input)
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _buildQueryArgs(String action, {String? eventId}) {
    return Uri(
      queryParameters: {
        'action': action,
        if (eventId != null) 'event_id': eventId,
      },
    ).query;
  }

  static String _actionButtonXml(String content, String arguments) {
    return '<action content="${escapeXml(content)}" '
        'arguments="${escapeXml(arguments)}" '
        'activationType="foreground"/>';
  }

  /// Builds WinRT `ToastGeneric` XML payload for an individual notification.
  static String buildToastXml(
    NotificationEventOut event, {
    bool hasLinkedTask = false,
  }) {
    final isSuppressed = event.deliveryPolicy == 'quiet_hours_suppressed' ||
        event.status == 'suppressed_quiet_hours';
    final isCatchup =
        event.isMissedCatchup || event.status == 'missed_catchup';
    final isAlarm = event.sourceType == 'alarm' || event.urgency == 'high';
    final isLiveAlarm = isAlarm && !isSuppressed && !isCatchup;
    final isReminder =
        event.sourceType == 'reminder' || event.sourceType == 'task_reminder';
    final isRoutine = event.sourceType == 'routine';
    final taskLinked = hasLinkedTask || event.sourceType == 'task_reminder';

    final launchAction = isRoutine ? 'open_chat' : 'open_schedule';
    final launchAttr =
        'launch="${escapeXml(_buildQueryArgs(launchAction, eventId: event.id))}"';
    final scenarioAttr = isLiveAlarm
        ? ' scenario="alarm"'
        : (isReminder ? ' scenario="reminder"' : '');

    final audioXml = (isSuppressed || isCatchup)
        ? '<audio silent="true"/>'
        : isLiveAlarm
            ? '<audio src="ms-winsoundevent:Notification.Looping.Alarm" loop="true"/>'
            : isReminder
                ? '<audio src="ms-winsoundevent:Notification.Reminder"/>'
                : '<audio src="ms-winsoundevent:Notification.Default"/>';

    final attribution = switch (event.sourceType) {
      'alarm' => isSuppressed ? 'Alarm (Silent)' : 'Alarm',
      'routine' => 'Companion Routine',
      'task_reminder' => 'Task Reminder',
      _ => isSuppressed ? 'Quiet Hours' : 'Reminder',
    };

    final titleEscaped = escapeXml(event.title);
    final bodyEscaped = escapeXml(event.body ?? '');

    final actions = StringBuffer('<actions>');
    if (isRoutine) {
      actions.write(
        _actionButtonXml(
          'Open Chat',
          _buildQueryArgs('open_chat', eventId: event.id),
        ),
      );
      actions.write(
        _actionButtonXml(
          'Acknowledge',
          _buildQueryArgs('acknowledge', eventId: event.id),
        ),
      );
      actions.write(
        _actionButtonXml(
          'Dismiss',
          _buildQueryArgs('dismiss', eventId: event.id),
        ),
      );
    } else {
      if (taskLinked) {
        actions.write(
          _actionButtonXml(
            'Mark Done',
            _buildQueryArgs('mark_done', eventId: event.id),
          ),
        );
      } else {
        actions.write(
          _actionButtonXml(
            'Acknowledge',
            _buildQueryArgs('acknowledge', eventId: event.id),
          ),
        );
      }
      actions.write(
        _actionButtonXml(
          'Snooze 10m',
          _buildQueryArgs('snooze_10m', eventId: event.id),
        ),
      );
      actions.write(
        _actionButtonXml(
          'Dismiss',
          _buildQueryArgs('dismiss', eventId: event.id),
        ),
      );
    }
    actions.write('</actions>');

    final bodyLine =
        bodyEscaped.isNotEmpty ? '<text>$bodyEscaped</text>' : '';
    return '<toast $launchAttr$scenarioAttr>'
        '<visual>'
        '<binding template="ToastGeneric">'
        '<text>$titleEscaped</text>'
        '$bodyLine'
        '<text placement="attribution">${escapeXml(attribution)}</text>'
        '</binding>'
        '</visual>'
        '$audioXml'
        '${actions.toString()}'
        '</toast>';
  }

  /// Builds a single silent consolidated ToastGeneric summary for sleep/offline catch-up.
  static String buildCatchupSummaryToastXml({
    required int missedCount,
    required List<NotificationEventOut> events,
  }) {
    final previewTitles = events
        .take(3)
        .map((e) => sanitizeXmlText(e.title).trim())
        .where((t) => t.isNotEmpty)
        .join(', ');
    final summaryBody = previewTitles.isNotEmpty
        ? '$previewTitles${events.length > 3 ? ' (+${events.length - 3} more)' : ''}'
        : 'Open the Notification Backlog Drawer to review missed items.';
    final launchArg = _buildQueryArgs('open_backlog');

    return '<toast launch="${escapeXml(launchArg)}">'
        '<visual>'
        '<binding template="ToastGeneric">'
        '<text>${escapeXml('Missed Notifications ($missedCount)')}</text>'
        '<text>${escapeXml(summaryBody)}</text>'
        '<text placement="attribution">Sleep &amp; Offline Catch-up</text>'
        '</binding>'
        '</visual>'
        '<audio silent="true"/>'
        '<actions>'
        '${_actionButtonXml('Review Backlog', launchArg)}'
        '</actions>'
        '</toast>';
  }

  Future<bool> _invokeBool(String method, Map<String, Object?> args) async {
    if (!_isWindowsPlatform) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>(method, args);
      return result ?? false;
    } catch (e) {
      debugPrint('WindowsWinRtToastAdapter.$method skipped/failed: $e');
      return false;
    }
  }

  @override
  Future<bool> showNotificationToast(
    NotificationEventOut event, {
    bool hasLinkedTask = false,
  }) {
    final isSuppressed = event.deliveryPolicy == 'quiet_hours_suppressed' ||
        event.status == 'suppressed_quiet_hours';
    return _invokeBool('showToast', {
      'tag': toastTagForEvent(event.id),
      'group': defaultToastGroup,
      'xml': buildToastXml(event, hasLinkedTask: hasLinkedTask),
      'suppressPopup': isSuppressed,
    });
  }

  @override
  Future<bool> showMissedCatchupSummaryToast({
    required int missedCount,
    required List<NotificationEventOut> events,
  }) {
    return _invokeBool('showToast', {
      'tag': catchupSummaryTag,
      'group': defaultToastGroup,
      'xml': buildCatchupSummaryToastXml(
        missedCount: missedCount,
        events: events,
      ),
      'suppressPopup': false,
    });
  }

  @override
  Future<bool> removeNotificationToast(String eventId) {
    return _invokeBool('removeToast', {
      'tag': toastTagForEvent(eventId),
      'group': defaultToastGroup,
    });
  }

  @override
  Future<bool> clearAllNotificationToasts() {
    return _invokeBool('clearToasts', {
      'group': defaultToastGroup,
    });
  }

  @override
  void dispose() {
    if (_isWindowsPlatform) {
      _channel.setMethodCallHandler(null);
    }
    _activationsController.close();
  }
}
