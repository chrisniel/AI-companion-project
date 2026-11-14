import 'dart:async';
import 'dart:convert';

import 'package:companion_api/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_companion_desktop/features/schedule/desktop_schedule_controller.dart';
import 'package:ai_companion_desktop/platform/windows_toast_adapter.dart';

class _FakeToastAdapter implements DesktopToastAdapter {
  final StreamController<ToastActivationEvent> _controller =
      StreamController<ToastActivationEvent>.broadcast();

  final List<({NotificationEventOut event, bool hasLinkedTask})> shownToasts =
      [];
  final List<({int missedCount, List<NotificationEventOut> events})>
      shownCatchups = [];
  final List<String> removedTags = [];
  int clearCount = 0;

  @override
  Stream<ToastActivationEvent> get activations => _controller.stream;

  void emitActivation(ToastActivationEvent event) {
    _controller.add(event);
  }

  @override
  Future<bool> showNotificationToast(
    NotificationEventOut event, {
    bool hasLinkedTask = false,
  }) async {
    shownToasts.add((event: event, hasLinkedTask: hasLinkedTask));
    return true;
  }

  @override
  Future<bool> showMissedCatchupSummaryToast({
    required int missedCount,
    required List<NotificationEventOut> events,
  }) async {
    shownCatchups.add((missedCount: missedCount, events: events));
    return true;
  }

  @override
  Future<bool> removeNotificationToast(String eventId) async {
    removedTags.add(eventId);
    return true;
  }

  @override
  Future<bool> clearAllNotificationToasts() async {
    clearCount++;
    return true;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

Map<String, dynamic> _taskJson({
  String id = 'task-1',
  String title = 'Prepare sprint notes',
  String status = 'pending',
  String priority = 'high',
}) =>
    {
      'id': id,
      'owner_id': 'prof-1',
      'title': title,
      'notes': 'Draft summary',
      'category': 'work',
      'status': status,
      'priority': priority,
      'due_date': '2026-11-16T10:00:00Z',
      'reminder_minutes_before': 15,
      'reminder_at': '2026-11-16T09:45:00Z',
      'is_deleted': false,
      'deleted_at': null,
      'created_at': '2026-11-15T08:00:00Z',
      'updated_at': '2026-11-15T08:00:00Z',
    };

Map<String, dynamic> _trashTaskJson({String id = 'trash-1'}) => {
      'id': id,
      'owner_id': 'prof-1',
      'title': 'Old cancelled task',
      'notes': null,
      'category': 'general',
      'status': 'cancelled',
      'priority': 'low',
      'due_date': null,
      'reminder_minutes_before': null,
      'reminder_at': null,
      'is_deleted': true,
      'deleted_at': '2026-11-14T08:00:00Z',
      'created_at': '2026-11-10T08:00:00Z',
      'updated_at': '2026-11-14T08:00:00Z',
      'expires_in_days': 29,
    };

Map<String, dynamic> _reminderJson({
  String id = 'rem-1',
  String? taskId,
  String title = 'Hydrate',
  String status = 'scheduled',
}) =>
    {
      'id': id,
      'profile_id': 'prof-1',
      'task_id': taskId,
      'title': title,
      'notes': null,
      'scheduled_at': '2026-11-15T12:00:00Z',
      'timezone': 'UTC',
      'status': status,
      'snoozed_until': null,
      'bypass_quiet_hours': false,
      'origin': 'host',
      'fired_at': null,
      'acknowledged_at': null,
      'created_at': '2026-11-15T08:00:00Z',
      'updated_at': '2026-11-15T08:00:00Z',
    };

Map<String, dynamic> _alarmJson({
  String id = 'alarm-1',
  String label = 'Morning Wakeup',
  String status = 'armed',
  bool enabled = true,
}) =>
    {
      'id': id,
      'profile_id': 'prof-1',
      'label': label,
      'scheduled_at': '2026-11-16T06:30:00Z',
      'time_of_day': '06:30',
      'recurrence_days': [0, 1, 2, 3, 4],
      'timezone': 'UTC',
      'enabled': enabled,
      'status': status,
      'snoozed_until': null,
      'bypass_quiet_hours': true,
      'origin': 'host',
      'last_fired_at': null,
      'acknowledged_at': null,
      'created_at': '2026-11-15T08:00:00Z',
      'updated_at': '2026-11-15T08:00:00Z',
    };

Map<String, dynamic> _routineJson({
  String id = 'rout-1',
  String title = 'Evening Check-in',
  bool enabled = true,
}) =>
    {
      'id': id,
      'profile_id': 'prof-1',
      'title': title,
      'prompt_template': null,
      'fallback_message': 'How did today go?',
      'time_of_day': '20:00',
      'recurrence_days': [0, 1, 2, 3, 4, 5, 6],
      'timezone': 'UTC',
      'enabled': enabled,
      'bypass_quiet_hours': false,
      'next_run_at': '2026-11-15T20:00:00Z',
      'last_run_at': null,
      'last_status': null,
      'created_at': '2026-11-15T08:00:00Z',
      'updated_at': '2026-11-15T08:00:00Z',
    };

Map<String, dynamic> _notificationJson({
  required String id,
  String sourceType = 'reminder',
  String sourceId = 'rem-1',
  String urgency = 'standard',
  String title = 'Alert',
  String status = 'unread',
  String deliveryPolicy = 'immediate',
  bool isMissedCatchup = false,
}) =>
    {
      'id': id,
      'profile_id': 'prof-1',
      'source_type': sourceType,
      'source_id': sourceId,
      'urgency': urgency,
      'title': title,
      'body': 'Body for $title',
      'status': status,
      'delivery_policy': deliveryPolicy,
      'is_missed_catchup': isMissedCatchup,
      'triggered_at': '2026-11-15T08:00:00Z',
      'read_at': null,
      'resolved_at': null,
      'created_at': '2026-11-15T08:00:00Z',
      'updated_at': '2026-11-15T08:00:00Z',
    };

void main() {
  group('DesktopScheduleController', () {
    test('refreshAll loads tasks, trash, reminders, alarms, routines, notifications, and quiet hours', () async {
      final recordedRequests = <String>[];
      final mockClient = MockClient((req) async {
        recordedRequests.add('${req.method} ${req.url.path}?${req.url.query}');
        switch (req.url.path) {
          case '/api/v1/tasks':
            return http.Response(jsonEncode({'items': [_taskJson()], 'total': 1}), 200);
          case '/api/v1/tasks/trash':
            return http.Response(jsonEncode({'items': [_trashTaskJson()], 'total': 1}), 200);
          case '/api/v1/reminders':
            return http.Response(jsonEncode({'items': [_reminderJson()], 'total': 1}), 200);
          case '/api/v1/alarms':
            return http.Response(jsonEncode({'items': [_alarmJson()], 'total': 1}), 200);
          case '/api/v1/routines':
            return http.Response(jsonEncode({'items': [_routineJson()], 'total': 1}), 200);
          case '/api/v1/notifications':
            return http.Response(
              jsonEncode({
                'items': [_notificationJson(id: 'n1', title: 'Due now')],
                'total': 1,
                'unread_count': 1,
                'missed_count': 0,
              }),
              200,
            );
          case '/api/v1/profiles/me/quiet-hours':
            return http.Response(
              jsonEncode({
                'quiet_hours_enabled': true,
                'quiet_hours_start': '22:30',
                'quiet_hours_end': '06:30',
                'quiet_hours_timezone': 'Asia/Manila',
              }),
              200,
            );
          default:
            return http.Response('{"detail":"Not found"}', 404);
        }
      });

      final client = CompanionClient(baseUrl: 'http://127.0.0.1:8000', httpClient: mockClient);
      final toastAdapter = _FakeToastAdapter();
      final controller = DesktopScheduleController(
        clientProvider: () => client,
        toastAdapter: toastAdapter,
        profileId: 'prof-1',
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);

      await controller.refreshAll();

      expect(controller.errorMessage, isNull);
      expect(controller.tasks.length, 1);
      expect(controller.trashTasks.length, 1);
      expect(controller.reminders.length, 1);
      expect(controller.alarms.length, 1);
      expect(controller.routines.length, 1);
      expect(controller.notifications.length, 1);
      expect(controller.unreadCount, 1);
      expect(controller.quietHours.quietHoursTimezone, 'Asia/Manila');
    });

    test('pollNotifications queries unread_only=true, skips suppressed routine toasts, consolidates catchup, and isolates activeAlerts to unread', () async {
      final queriedUrls = <Uri>[];
      final items = [
        _notificationJson(
          id: 'n-unread-alarm',
          sourceType: 'alarm',
          urgency: 'high',
          title: 'Wake up',
          status: 'unread',
          deliveryPolicy: 'immediate',
        ),
        _notificationJson(
          id: 'n-suppressed-routine',
          sourceType: 'routine',
          urgency: 'informational',
          title: 'Late reflection',
          status: 'suppressed_quiet_hours',
          deliveryPolicy: 'quiet_hours_suppressed',
        ),
        _notificationJson(
          id: 'n-suppressed-reminder',
          sourceType: 'task_reminder',
          title: 'Quiet reminder',
          status: 'suppressed_quiet_hours',
          deliveryPolicy: 'quiet_hours_suppressed',
        ),
        _notificationJson(
          id: 'n-catchup-1',
          sourceType: 'reminder',
          title: 'Missed call',
          status: 'missed_catchup',
          deliveryPolicy: 'missed_catchup',
          isMissedCatchup: true,
        ),
        _notificationJson(
          id: 'n-catchup-2',
          sourceType: 'reminder',
          title: 'Missed vitals',
          status: 'missed_catchup',
          deliveryPolicy: 'missed_catchup',
          isMissedCatchup: true,
        ),
      ];

      final mockClient = MockClient((req) async {
        queriedUrls.add(req.url);
        if (req.url.path == '/api/v1/notifications') {
          return http.Response(
            jsonEncode({
              'items': items,
              'total': items.length,
              'unread_count': 1,
              'missed_count': 2,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final client = CompanionClient(baseUrl: 'http://127.0.0.1:8000', httpClient: mockClient);
      final toastAdapter = _FakeToastAdapter();
      final controller = DesktopScheduleController(
        clientProvider: () => client,
        toastAdapter: toastAdapter,
        profileId: 'prof-1',
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);

      await controller.pollNotifications();

      expect(queriedUrls.any((u) => u.queryParameters['unread_only'] == 'true'), isTrue);
      // Unread alarm + suppressed task_reminder dispatched; suppressed routine skipped.
      expect(toastAdapter.shownToasts.length, 2);
      expect(toastAdapter.shownToasts.map((t) => t.event.id), containsAll(['n-unread-alarm', 'n-suppressed-reminder']));
      expect(toastAdapter.shownToasts.any((t) => t.event.id == 'n-suppressed-routine'), isFalse);
      // Task reminder sets hasLinkedTask=true
      final quietRem = toastAdapter.shownToasts.firstWhere((t) => t.event.id == 'n-suppressed-reminder');
      expect(quietRem.hasLinkedTask, isTrue);

      // Consolidated single catch-up toast
      expect(toastAdapter.shownCatchups.length, 1);
      expect(toastAdapter.shownCatchups.first.missedCount, 2);

      // Active in-app banner strictly filters to unread only
      expect(controller.activeAlerts.map((e) => e.id).toList(), ['n-unread-alarm']);

      // Re-polling does NOT duplicate already dispatched IDs
      await controller.pollNotifications();
      expect(toastAdapter.shownToasts.length, 2);
      expect(toastAdapter.shownCatchups.length, 1);
    });

    test('handles two-way toast activations (mark_done, snooze_10m, dismiss, open_chat, open_backlog) and Action Center cleanup', () async {
      final calls = <({String method, String path, Map<String, dynamic>? body})>[];
      final navigated = <ToastNavigationTarget>[];
      final mockClient = MockClient((req) async {
        Map<String, dynamic>? decodedBody;
        if (req.body.isNotEmpty) {
          decodedBody = Map<String, dynamic>.from(jsonDecode(req.body) as Map);
        }
        calls.add((method: req.method, path: req.url.path, body: decodedBody));
        if (req.url.path.startsWith('/api/v1/notifications/') &&
            req.method == 'POST') {
          return http.Response(
            jsonEncode(_notificationJson(id: 'evt-1', status: 'acknowledged')),
            200,
          );
        }
        if (req.url.path == '/api/v1/notifications') {
          return http.Response(
            jsonEncode({'items': <dynamic>[], 'total': 0, 'unread_count': 0, 'missed_count': 0}),
            200,
          );
        }
        if (req.url.path == '/api/v1/tasks') {
          return http.Response(jsonEncode({'items': <dynamic>[], 'total': 0}), 200);
        }
        if (req.url.path == '/api/v1/reminders') {
          return http.Response(jsonEncode({'items': <dynamic>[], 'total': 0}), 200);
        }
        return http.Response(jsonEncode({'items': <dynamic>[], 'total': 0}), 200);
      });

      final client = CompanionClient(baseUrl: 'http://127.0.0.1:8000', httpClient: mockClient);
      final toastAdapter = _FakeToastAdapter();
      final controller = DesktopScheduleController(
        clientProvider: () => client,
        toastAdapter: toastAdapter,
        profileId: 'prof-1',
        onNavigateRequested: navigated.add,
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);

      toastAdapter.emitActivation(const ToastActivationEvent(action: 'mark_done', eventId: 'evt-1'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        calls.any((c) =>
            c.path == '/api/v1/notifications/evt-1/acknowledge' &&
            c.body?['complete_task'] == true),
        isTrue,
      );
      expect(toastAdapter.removedTags, contains('evt-1'));

      toastAdapter.emitActivation(const ToastActivationEvent(action: 'snooze_10m', eventId: 'evt-2'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        calls.any((c) =>
            c.path == '/api/v1/notifications/evt-2/snooze' &&
            c.body?['minutes'] == 10),
        isTrue,
      );
      expect(toastAdapter.removedTags, contains('evt-2'));

      toastAdapter.emitActivation(const ToastActivationEvent(action: 'dismiss', eventId: 'evt-3'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls.any((c) => c.path == '/api/v1/notifications/evt-3/dismiss'), isTrue);
      expect(toastAdapter.removedTags, contains('evt-3'));

      toastAdapter.emitActivation(const ToastActivationEvent(action: 'open_chat', eventId: 'evt-4'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(navigated, contains(ToastNavigationTarget.chat));

      toastAdapter.emitActivation(const ToastActivationEvent(action: 'open_backlog'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(navigated, contains(ToastNavigationTarget.backlogDrawer));
    });

    test('forwards TaskUpdate clear* flags cleanly and clears state + OS toasts on disconnect/profile switch', () async {
      final patchBodies = <Map<String, dynamic>>[];
      final mockClient = MockClient((req) async {
        if (req.method == 'PATCH' && req.url.path == '/api/v1/tasks/task-1') {
          patchBodies.add(Map<String, dynamic>.from(jsonDecode(req.body) as Map));
          return http.Response(jsonEncode(_taskJson(id: 'task-1')), 200);
        }
        return http.Response(jsonEncode({'items': <dynamic>[], 'total': 0}), 200);
      });

      final client = CompanionClient(baseUrl: 'http://127.0.0.1:8000', httpClient: mockClient);
      final toastAdapter = _FakeToastAdapter();
      final controller = DesktopScheduleController(
        clientProvider: () => client,
        toastAdapter: toastAdapter,
        profileId: 'prof-1',
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);

      await controller.updateTask(
        'task-1',
        const TaskUpdate(title: 'Updated'),
        clearNotes: true,
        clearDueDate: true,
        clearReminderAt: true,
      );

      expect(patchBodies.length, 1);
      expect(patchBodies.first.containsKey('notes'), isTrue);
      expect(patchBodies.first['notes'], isNull);
      expect(patchBodies.first.containsKey('due_date'), isTrue);
      expect(patchBodies.first['due_date'], isNull);
      expect(patchBodies.first.containsKey('reminder_at'), isTrue);
      expect(patchBodies.first['reminder_at'], isNull);

      controller.clearForDisconnect();
      expect(controller.tasks, isEmpty);
      expect(controller.activeAlerts, isEmpty);
      expect(toastAdapter.clearCount, greaterThanOrEqualTo(1));
    });
  });
}
