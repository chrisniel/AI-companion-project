import 'dart:convert';

import 'package:ai_companion_desktop/features/schedule/desktop_schedule_controller.dart';
import 'package:ai_companion_desktop/platform/windows_toast_adapter.dart';
import 'package:ai_companion_desktop/screens/schedule_screen.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  void setupViewport(WidgetTester tester, [Size size = const Size(1280, 800)]) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('ScheduleScreen', () {
    testWidgets(
      'navigates all 5 sections, executes Trash restore, Reminder snooze, Alarm acknowledge, and Routine Run Now',
      (tester) async {
        setupViewport(tester);
        final recordedCalls = <String>[];

        final mockClient = MockClient((req) async {
          recordedCalls.add('${req.method} ${req.url.path}');
          switch (req.url.path) {
            case '/api/v1/tasks':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 'task-1',
                      'owner_id': 'prof-1',
                      'title': 'Write release notes',
                      'notes': 'Draft M3 summary',
                      'category': 'work',
                      'status': 'pending',
                      'priority': 'high',
                      'due_date': '2026-11-16T10:00:00Z',
                      'reminder_minutes_before': null,
                      'reminder_at': null,
                      'is_deleted': false,
                      'deleted_at': null,
                      'created_at': '2026-11-15T08:00:00Z',
                      'updated_at': '2026-11-15T08:00:00Z',
                    },
                  ],
                  'total': 1,
                }),
                200,
              );
            case '/api/v1/tasks/trash':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 'trash-1',
                      'owner_id': 'prof-1',
                      'title': 'Deleted draft',
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
                    },
                  ],
                  'total': 1,
                }),
                200,
              );
            case '/api/v1/tasks/trash-1/restore':
              return http.Response(
                jsonEncode({
                  'id': 'trash-1',
                  'owner_id': 'prof-1',
                  'title': 'Deleted draft',
                  'notes': null,
                  'category': 'general',
                  'status': 'pending',
                  'priority': 'low',
                  'due_date': null,
                  'reminder_minutes_before': null,
                  'reminder_at': null,
                  'is_deleted': false,
                  'deleted_at': null,
                  'created_at': '2026-11-10T08:00:00Z',
                  'updated_at': '2026-11-15T09:00:00Z',
                }),
                200,
              );
            case '/api/v1/reminders':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 'rem-1',
                      'profile_id': 'prof-1',
                      'task_id': 'task-1',
                      'title': 'Review task',
                      'notes': 'Linked reminder',
                      'scheduled_at': '2026-11-15T12:00:00Z',
                      'timezone': 'UTC',
                      'status': 'fired',
                      'snoozed_until': null,
                      'bypass_quiet_hours': false,
                      'origin': 'host',
                      'fired_at': '2026-11-15T12:00:01Z',
                      'acknowledged_at': null,
                      'created_at': '2026-11-15T08:00:00Z',
                      'updated_at': '2026-11-15T12:00:01Z',
                    },
                  ],
                  'total': 1,
                }),
                200,
              );
            case '/api/v1/reminders/rem-1/snooze':
              return http.Response(
                jsonEncode({
                  'id': 'rem-1',
                  'profile_id': 'prof-1',
                  'task_id': 'task-1',
                  'title': 'Review task',
                  'notes': 'Linked reminder',
                  'scheduled_at': '2026-11-15T12:10:00Z',
                  'timezone': 'UTC',
                  'status': 'snoozed',
                  'snoozed_until': '2026-11-15T12:10:00Z',
                  'bypass_quiet_hours': false,
                  'origin': 'host',
                  'fired_at': '2026-11-15T12:00:01Z',
                  'acknowledged_at': null,
                  'created_at': '2026-11-15T08:00:00Z',
                  'updated_at': '2026-11-15T12:00:05Z',
                }),
                200,
              );
            case '/api/v1/alarms':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 'alarm-1',
                      'profile_id': 'prof-1',
                      'label': 'Morning Wakeup',
                      'scheduled_at': '2026-11-16T06:30:00Z',
                      'time_of_day': '06:30',
                      'recurrence_days': [0, 1, 2, 3, 4],
                      'timezone': 'UTC',
                      'enabled': true,
                      'status': 'ringing',
                      'snoozed_until': null,
                      'bypass_quiet_hours': true,
                      'origin': 'host',
                      'last_fired_at': '2026-11-15T06:30:00Z',
                      'acknowledged_at': null,
                      'created_at': '2026-11-15T06:00:00Z',
                      'updated_at': '2026-11-15T06:30:00Z',
                    },
                  ],
                  'total': 1,
                }),
                200,
              );
            case '/api/v1/alarms/alarm-1/acknowledge':
              return http.Response(
                jsonEncode({
                  'id': 'alarm-1',
                  'profile_id': 'prof-1',
                  'label': 'Morning Wakeup',
                  'scheduled_at': '2026-11-16T06:30:00Z',
                  'time_of_day': '06:30',
                  'recurrence_days': [0, 1, 2, 3, 4],
                  'timezone': 'UTC',
                  'enabled': true,
                  'status': 'acknowledged',
                  'snoozed_until': null,
                  'bypass_quiet_hours': true,
                  'origin': 'host',
                  'last_fired_at': '2026-11-15T06:30:00Z',
                  'acknowledged_at': '2026-11-15T06:31:00Z',
                  'created_at': '2026-11-15T06:00:00Z',
                  'updated_at': '2026-11-15T06:31:00Z',
                }),
                200,
              );
            case '/api/v1/routines':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 'rout-1',
                      'profile_id': 'prof-1',
                      'title': 'Evening Check-in',
                      'prompt_template': null,
                      'fallback_message': 'How did today go?',
                      'time_of_day': '20:00',
                      'recurrence_days': [0, 1, 2, 3, 4, 5, 6],
                      'timezone': 'UTC',
                      'enabled': true,
                      'bypass_quiet_hours': false,
                      'next_run_at': '2026-11-15T20:00:00Z',
                      'last_run_at': null,
                      'last_status': null,
                      'created_at': '2026-11-15T08:00:00Z',
                      'updated_at': '2026-11-15T08:00:00Z',
                    },
                  ],
                  'total': 1,
                }),
                200,
              );
            case '/api/v1/routines/rout-1/run':
              return http.Response(
                jsonEncode({
                  'id': 'evt-rout-1',
                  'profile_id': 'prof-1',
                  'source_type': 'routine',
                  'source_id': 'rout-1',
                  'urgency': 'informational',
                  'title': 'Evening Check-in',
                  'body': 'How did today go?',
                  'status': 'unread',
                  'delivery_policy': 'immediate',
                  'is_missed_catchup': false,
                  'triggered_at': '2026-11-15T10:00:00Z',
                  'read_at': null,
                  'resolved_at': null,
                  'created_at': '2026-11-15T10:00:00Z',
                  'updated_at': '2026-11-15T10:00:00Z',
                }),
                201,
              );
            case '/api/v1/notifications':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 'evt-1',
                      'profile_id': 'prof-1',
                      'source_type': 'task_reminder',
                      'source_id': 'rem-1',
                      'urgency': 'standard',
                      'title': 'Review task',
                      'body': 'Time to review your task',
                      'status': 'unread',
                      'delivery_policy': 'immediate',
                      'is_missed_catchup': false,
                      'triggered_at': '2026-11-15T12:00:01Z',
                      'read_at': null,
                      'resolved_at': null,
                      'created_at': '2026-11-15T12:00:01Z',
                      'updated_at': '2026-11-15T12:00:01Z',
                    },
                  ],
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
                  'quiet_hours_start': '22:00',
                  'quiet_hours_end': '07:00',
                  'quiet_hours_timezone': 'UTC',
                }),
                200,
              );
            default:
              return http.Response('{"detail":"Not found"}', 404);
          }
        });

        final client = CompanionClient(
          baseUrl: 'http://127.0.0.1:8000',
          httpClient: mockClient,
        );
        final controller = DesktopScheduleController(
          client: client,
          toastAdapter: NoOpDesktopToastAdapter(),
          profileId: 'prof-1',
        );
        addTearDown(controller.dispose);
        addTearDown(client.close);

        await controller.refreshAll();

        await tester.pumpWidget(
          MaterialApp(
            theme: CompanionTheme.dark(),
            home: Scaffold(
              body: ScheduleScreen(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Tasks + Trash Restore
        expect(find.text('Write release notes'), findsOneWidget);
        await tester.tap(find.text('Trash (1)'));
        await tester.pumpAndSettle();
        expect(find.text('Deleted draft'), findsOneWidget);
        await tester.tap(find.byKey(const Key('trash_restore_button_trash-1')));
        await tester.pumpAndSettle();
        expect(recordedCalls, contains('POST /api/v1/tasks/trash-1/restore'));

        // 2. Reminders + Snooze 10m
        await tester.tap(find.byKey(const Key('schedule_nav_reminders')));
        await tester.pumpAndSettle();
        expect(find.text('Review task'), findsOneWidget);
        await tester.tap(find.byKey(const Key('reminder_snooze_button_rem-1')));
        await tester.pumpAndSettle();
        expect(recordedCalls, contains('POST /api/v1/reminders/rem-1/snooze'));

        // 3. Alarms + Acknowledge (12-hour AM/PM formatting)
        await tester.tap(find.byKey(const Key('schedule_nav_alarms')));
        await tester.pumpAndSettle();
        expect(find.text('Morning Wakeup'), findsOneWidget);
        expect(find.textContaining('6:30 AM'), findsOneWidget);
        expect(find.text('BYPASS QUIET'), findsOneWidget);
        await tester.tap(find.byKey(const Key('alarm_ack_button_alarm-1')));
        await tester.pumpAndSettle();
        expect(recordedCalls, contains('POST /api/v1/alarms/alarm-1/acknowledge'));

        // 4. Routines + Run Now (12-hour AM/PM formatting)
        await tester.tap(find.byKey(const Key('schedule_nav_routines')));
        await tester.pumpAndSettle();
        expect(find.text('Evening Check-in'), findsOneWidget);
        expect(find.textContaining('8:00 PM'), findsOneWidget);
        expect(find.text('How did today go?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('routine_run_now_rout-1')));
        await tester.pumpAndSettle();
        expect(recordedCalls, contains('POST /api/v1/routines/rout-1/run'));

        // 5. Notifications section
        await tester.tap(find.byKey(const Key('schedule_nav_notifications')));
        await tester.pumpAndSettle();
        expect(find.text('Notification History (1 unread)'), findsOneWidget);
        expect(find.text('Review task'), findsOneWidget);
      },
    );

    testWidgets(
      'creates a new task via ScheduleEditDialogs with inline validation',
      (tester) async {
        setupViewport(tester);
        Map<String, dynamic>? postedBody;

        final mockClient = MockClient((req) async {
          if (req.method == 'POST' && req.url.path == '/api/v1/tasks') {
            postedBody = Map<String, dynamic>.from(jsonDecode(req.body) as Map);
            return http.Response(
              jsonEncode({
                'id': 'task-new',
                'owner_id': 'prof-1',
                'title': postedBody!['title'],
                'notes': null,
                'category': postedBody!['category'] ?? 'general',
                'status': 'pending',
                'priority': postedBody!['priority'] ?? 'medium',
                'due_date': null,
                'reminder_minutes_before': null,
                'reminder_at': null,
                'is_deleted': false,
                'deleted_at': null,
                'created_at': '2026-11-15T10:00:00Z',
                'updated_at': '2026-11-15T10:00:00Z',
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({'items': <dynamic>[], 'total': 0}),
            200,
          );
        });

        final client = CompanionClient(
          baseUrl: 'http://127.0.0.1:8000',
          httpClient: mockClient,
        );
        final controller = DesktopScheduleController(
          client: client,
          toastAdapter: NoOpDesktopToastAdapter(),
          profileId: 'prof-1',
        );
        addTearDown(controller.dispose);
        addTearDown(client.close);

        await tester.pumpWidget(
          MaterialApp(
            theme: CompanionTheme.dark(),
            home: Scaffold(
              body: ScheduleScreen(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('schedule_create_button')));
        await tester.pumpAndSettle();

        // Validate empty title blocked locally
        await tester.tap(find.byKey(const Key('task_dialog_save_button')));
        await tester.pump();
        expect(find.text('Title is required.'), findsOneWidget);
        expect(postedBody, isNull);

        await tester.enterText(
          find.byKey(const Key('task_dialog_title_field')),
          'Ship Batch G2',
        );
        await tester.tap(find.byKey(const Key('task_dialog_save_button')));
        await tester.pumpAndSettle();

        expect(postedBody, isNotNull);
        expect(postedBody!['title'], 'Ship Batch G2');
      },
    );

    testWidgets('shows graceful offline notice when profile scope is disconnected',
        (tester) async {
      setupViewport(tester);
      final mockClient = MockClient(
        (_) async => http.Response('{"detail":"offline"}', 503),
      );
      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockClient,
      );
      final controller = DesktopScheduleController(
        client: client,
        toastAdapter: NoOpDesktopToastAdapter(),
        profileId: null,
        isConnected: false,
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);

      var settingsClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: ScheduleScreen(
              controller: controller,
              onNavigateToSettings: () => settingsClicked = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Connect & Select Profile to Manage Schedule'),
        findsOneWidget,
      );
      await tester.tap(find.text('Open Connection & Profile Settings'));
      await tester.pump();
      expect(settingsClicked, isTrue);
    });

    testWidgets(
      'revamped Task and Alarm dialogs support 12-hour AM/PM quick presets and device timezone default',
      (tester) async {
        setupViewport(tester);
        Map<String, dynamic>? postedTask;
        Map<String, dynamic>? postedAlarm;

        final mockClient = MockClient((req) async {
          if (req.method == 'POST' && req.url.path == '/api/v1/tasks') {
            postedTask = Map<String, dynamic>.from(jsonDecode(req.body) as Map);
            return http.Response(
              jsonEncode({
                'id': 'task-q1',
                'owner_id': 'prof-1',
                'title': postedTask!['title'],
                'notes': null,
                'category': postedTask!['category'] ?? 'general',
                'status': 'pending',
                'priority': postedTask!['priority'] ?? 'medium',
                'due_date': postedTask!['due_date'],
                'reminder_minutes_before': postedTask!['reminder_minutes_before'],
                'reminder_at': null,
                'is_deleted': false,
                'deleted_at': null,
                'created_at': '2026-11-15T10:00:00Z',
                'updated_at': '2026-11-15T10:00:00Z',
              }),
              201,
            );
          }
          if (req.method == 'POST' && req.url.path == '/api/v1/alarms') {
            postedAlarm = Map<String, dynamic>.from(jsonDecode(req.body) as Map);
            return http.Response(
              jsonEncode({
                'id': 'alarm-q1',
                'profile_id': 'prof-1',
                'label': postedAlarm!['label'],
                'scheduled_at': null,
                'time_of_day': postedAlarm!['time_of_day'],
                'recurrence_days': postedAlarm!['recurrence_days'] ?? [0, 1, 2, 3, 4],
                'timezone': postedAlarm!['timezone'],
                'enabled': true,
                'status': 'armed',
                'snoozed_until': null,
                'bypass_quiet_hours': true,
                'origin': 'host',
                'last_fired_at': null,
                'acknowledged_at': null,
                'created_at': '2026-11-15T10:00:00Z',
                'updated_at': '2026-11-15T10:00:00Z',
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({'items': <dynamic>[], 'total': 0}),
            200,
          );
        });

        final client = CompanionClient(
          baseUrl: 'http://127.0.0.1:8000',
          httpClient: mockClient,
        );
        final controller = DesktopScheduleController(
          client: client,
          toastAdapter: NoOpDesktopToastAdapter(),
          profileId: 'prof-1',
        );
        addTearDown(controller.dispose);
        addTearDown(client.close);

        await tester.pumpWidget(
          MaterialApp(
            theme: CompanionTheme.dark(),
            home: Scaffold(
              body: ScheduleScreen(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Create Task using quick due + 15m before chips
        await tester.tap(find.byKey(const Key('schedule_create_button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('task_dialog_title_field')),
          'Take vitamins',
        );
        await tester.tap(find.text('Today 6:00 PM'));
        await tester.pump();
        await tester.tap(find.text('15m before'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('task_dialog_save_button')));
        await tester.pumpAndSettle();

        expect(postedTask, isNotNull);
        expect(postedTask!['due_date'], isNotNull);
        expect(postedTask!['due_date'] as String, endsWith('Z'));
        expect(postedTask!['reminder_minutes_before'], 15);

        // Switch to Alarms and create Alarm with 12h 9:00 PM preset + PC timezone
        await tester.tap(find.byKey(const Key('schedule_nav_alarms')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('schedule_create_button')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Using PC timezone: ${controller.deviceTimezone}'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('alarm_dialog_label_field')),
          'Wind Down',
        );
        await tester.tap(find.text('9:00 PM'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('alarm_dialog_save_button')));
        await tester.pumpAndSettle();

        expect(postedAlarm, isNotNull);
        expect(postedAlarm!['time_of_day'], '21:00');
        expect(postedAlarm!['timezone'], controller.deviceTimezone);
      },
    );
  });
}
