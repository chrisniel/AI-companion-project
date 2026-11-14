import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_desktop/features/schedule/desktop_schedule_controller.dart';
import 'package:ai_companion_desktop/features/schedule/notification_backlog_drawer.dart';
import 'package:ai_companion_desktop/platform/windows_toast_adapter.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TrackingToastAdapter implements DesktopToastAdapter {
  final StreamController<ToastActivationEvent> _ctrl =
      StreamController<ToastActivationEvent>.broadcast();
  final List<String> removedIds = [];
  int clearCalls = 0;

  @override
  Stream<ToastActivationEvent> get activations => _ctrl.stream;

  @override
  Future<bool> showNotificationToast(
    NotificationEventOut event, {
    bool hasLinkedTask = false,
  }) async =>
      true;

  @override
  Future<bool> showMissedCatchupSummaryToast({
    required int missedCount,
    required List<NotificationEventOut> events,
  }) async =>
      true;

  @override
  Future<bool> removeNotificationToast(String eventId) async {
    removedIds.add(eventId);
    return true;
  }

  @override
  Future<bool> clearAllNotificationToasts() async {
    clearCalls++;
    return true;
  }

  @override
  void dispose() {
    _ctrl.close();
  }
}

void main() {
  testWidgets(
    'NotificationBacklogDrawer surfaces sleep catch-up, unread filter, actions, Open Chat, and Clear All sync',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final apiCalls = <String>[];
      final queriedParams = <String>[];
      var notificationsList = <Map<String, dynamic>>[
        {
          'id': 'evt-task-1',
          'profile_id': 'prof-1',
          'source_type': 'task_reminder',
          'source_id': 'rem-1',
          'urgency': 'standard',
          'title': 'Finish report',
          'body': 'Task deadline soon',
          'status': 'unread',
          'delivery_policy': 'immediate',
          'is_missed_catchup': false,
          'triggered_at': '2026-11-15T09:00:00Z',
          'read_at': null,
          'resolved_at': null,
          'created_at': '2026-11-15T09:00:00Z',
          'updated_at': '2026-11-15T09:00:00Z',
        },
        {
          'id': 'evt-rout-1',
          'profile_id': 'prof-1',
          'source_type': 'routine',
          'source_id': 'rout-1',
          'urgency': 'informational',
          'title': 'Morning check-in',
          'body': 'Ready to review today?',
          'status': 'missed_catchup',
          'delivery_policy': 'sleep_catchup',
          'is_missed_catchup': true,
          'triggered_at': '2026-11-15T08:00:00Z',
          'read_at': null,
          'resolved_at': null,
          'created_at': '2026-11-15T08:00:00Z',
          'updated_at': '2026-11-15T08:00:00Z',
        },
      ];

      final mockClient = MockClient((req) async {
        apiCalls.add('${req.method} ${req.url.path}');
        if (req.url.path == '/api/v1/notifications') {
          queriedParams.add(req.url.query);
          return http.Response(
            jsonEncode({
              'items': notificationsList,
              'total': notificationsList.length,
              'unread_count': 1,
              'missed_count': 1,
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/notifications/evt-task-1/acknowledge') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['complete_task'], isTrue);
          return http.Response(
            jsonEncode({
              ...notificationsList.first,
              'status': 'acknowledged',
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/notifications/evt-rout-1/read') {
          return http.Response(
            jsonEncode({
              ...notificationsList[1],
              'status': 'read',
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/notifications/clear-all') {
          notificationsList = [];
          return http.Response(jsonEncode({'cleared_count': 2}), 200);
        }
        return http.Response(jsonEncode({'items': <dynamic>[], 'total': 0}), 200);
      });

      final client = CompanionClient(
        baseUrl: 'http://127.0.0.1:8000',
        httpClient: mockClient,
      );
      final toastAdapter = _TrackingToastAdapter();
      final controller = DesktopScheduleController(
        client: client,
        toastAdapter: toastAdapter,
        profileId: 'prof-1',
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);

      await controller.refreshAll();

      var closed = false;
      var openedChat = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompanionTheme.dark(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: NotificationBacklogDrawer(
                controller: controller,
                activeProfileName: 'Chris',
                onClose: () => closed = true,
                onOpenChat: () => openedChat = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile Scope: Chris'), findsOneWidget);
      expect(find.byKey(const Key('backlog_missed_catchup_banner')), findsOneWidget);
      expect(find.text('Finish report'), findsOneWidget);
      expect(find.text('Morning check-in'), findsOneWidget);

      // Mark Done on task reminder event
      await tester.tap(find.text('Mark Done'));
      await tester.pumpAndSettle();
      expect(
        apiCalls,
        contains('POST /api/v1/notifications/evt-task-1/acknowledge'),
      );
      expect(toastAdapter.removedIds, contains('evt-task-1'));

      // Open Chat on routine event
      await tester.tap(find.text('Open Chat'));
      await tester.pumpAndSettle();
      expect(apiCalls, contains('POST /api/v1/notifications/evt-rout-1/read'));
      expect(openedChat, isTrue);
      expect(closed, isTrue);

      // Filter Unread Only
      await tester.tap(find.byKey(const Key('backlog_unread_only_chip')));
      await tester.pumpAndSettle();
      expect(queriedParams.any((q) => q.contains('unread_only=true')), isTrue);

      // Clear All removes backend + Action Center toast group
      await tester.tap(find.byKey(const Key('backlog_clear_all_button')));
      await tester.pumpAndSettle();
      expect(apiCalls, contains('POST /api/v1/notifications/clear-all'));
      expect(toastAdapter.clearCalls, greaterThanOrEqualTo(1));
    },
  );
}
