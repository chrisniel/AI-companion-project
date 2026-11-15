import 'dart:convert';

import 'package:ai_companion_desktop/controllers/desktop_settings_controller.dart';
import 'package:ai_companion_desktop/diagnostics/windows_storage_diagnostic_reader.dart';
import 'package:ai_companion_desktop/features/schedule/desktop_schedule_controller.dart';
import 'package:ai_companion_desktop/platform/windows_toast_adapter.dart';
import 'package:ai_companion_desktop/screens/schedule_screen.dart';
import 'package:ai_companion_desktop/shell/desktop_shell.dart';
import 'package:companion_api/companion_api.dart';
import 'package:companion_design/companion_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Desktop Layout Responsive Verification', () {
    void setupViewport(WidgetTester tester, Size size) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    Widget createTestApp({
      required DesktopSettingsController controller,
      ThemeMode mode = ThemeMode.dark,
      double textScaleFactor = 1.0,
    }) {
      return MaterialApp(
        theme: CompanionTheme.light(),
        darkTheme: CompanionTheme.dark(),
        themeMode: mode,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScaleFactor),
            ),
            child: child!,
          );
        },
        home: DesktopShell(controller: controller),
      );
    }

    testWidgets('Chat screen renders without overflow at default 1280x800 with expanded rail', (tester) async {
      setupViewport(tester, const Size(1280, 800));
      final controller = DesktopSettingsController();

      await tester.pumpWidget(createTestApp(controller: controller));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Conversational workspace'), findsOneWidget);
      expect(find.text('AI Companion Desktop'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Chat screen renders without overflow at minimum 1024x640 with expanded rail', (tester) async {
      setupViewport(tester, const Size(1024, 640));
      final controller = DesktopSettingsController();

      await tester.pumpWidget(createTestApp(controller: controller));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Conversational workspace'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Chat screen renders without overflow at minimum 1024x640 with collapsed rail', (tester) async {
      setupViewport(tester, const Size(1024, 640));
      final controller = DesktopSettingsController();
      controller.toggleRailCollapsed();

      await tester.pumpWidget(createTestApp(controller: controller));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.isRailCollapsed, isTrue);
      expect(find.text('Chat'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Settings appearance controls render cleanly at 1280x800 and 1024x640', (tester) async {
      for (final size in const [Size(1280, 800), Size(1024, 640)]) {
        setupViewport(tester, size);
        final controller = DesktopSettingsController();

        await tester.pumpWidget(createTestApp(controller: controller));
        await tester.pumpAndSettle();

        // Switch to Settings
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Appearance & Theme'), findsOneWidget);
        expect(find.text('Color Mode'), findsOneWidget);
        expect(find.text('Accent Color Preset'), findsOneWidget);

        // Verify all 5 accent chips are present and interactive
        for (final preset in AccentPreset.values) {
          expect(find.text(preset.label), findsOneWidget);
        }
      }
    });

    testWidgets('Settings diagnostics card renders cleanly at 1280x800 and 1024x640', (tester) async {
      for (final size in const [Size(1280, 800), Size(1024, 640)]) {
        setupViewport(tester, size);
        final mockReader = WindowsStorageDiagnosticReader(
          localAppDataOverride: r'C:\Users\Test\AppData\Local',
          appInstallDirOverride: r'C:\Program Files\AI Companion',
          fileExistsChecker: (path) => false,
          directoryExistsChecker: (path) => true,
        );
        final controller = DesktopSettingsController(diagnosticReader: mockReader);

        await tester.pumpWidget(createTestApp(controller: controller));
        await tester.pumpAndSettle();

        // Switch to Settings
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('settings_nav_storage')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Storage Diagnostics'), findsOneWidget);
        expect(find.text('Client Fail-Closed Inspection'), findsOneWidget);
        expect(find.text('Bootstrap Locator'), findsOneWidget);
        expect(find.text('Default Storage Root (DATA)'), findsOneWidget);
        expect(find.text('Application Install (APP_INSTALL)'), findsOneWidget);
        expect(find.text('Model & Library Root (LIBRARY)'), findsOneWidget);
        expect(find.text('Not reported by backend'), findsWidgets);
      }
    });

    testWidgets('Minimum 1024x640 viewport handles text scaling (1.2x and 1.3x) without overflow', (tester) async {
      for (final scale in [1.2, 1.3]) {
        setupViewport(tester, const Size(1024, 640));
        final controller = DesktopSettingsController();

        await tester.pumpWidget(createTestApp(
          controller: controller,
          textScaleFactor: scale,
        ));
        await tester.pumpAndSettle();

        // 1. Chat screen with scaled text
        expect(tester.takeException(), isNull);
        expect(find.text('Chat'), findsWidgets);

        // 2. Settings screen tabs & rail power menu with scaled text
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('rail_power_menu_button')), findsOneWidget);
        expect(find.text('Appearance & Theme'), findsOneWidget);

        await tester.tap(find.byKey(const Key('settings_nav_storage')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Storage Diagnostics'), findsOneWidget);

        await tester.tap(find.byKey(const Key('settings_nav_general')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Window & Tray Lifecycle'), findsOneWidget);

        await tester.tap(find.byKey(const Key('settings_nav_runtime')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Runtime Connection & Pairing'), findsOneWidget);
      }
    });

    testWidgets(
      'ScheduleScreen renders cleanly across sections at 1024x640 with 1.3x text scale',
      (tester) async {
        setupViewport(tester, const Size(1024, 640));

        final mockClient = MockClient((req) async {
          switch (req.url.path) {
            case '/api/v1/tasks':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 't1',
                      'owner_id': 'prof-1',
                      'title': 'Long release checklist item with scaled typography',
                      'notes': 'Confirm all desktop components',
                      'category': 'work',
                      'status': 'pending',
                      'priority': 'urgent',
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
            case '/api/v1/alarms':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 'a1',
                      'profile_id': 'prof-1',
                      'label': 'Wake up early',
                      'scheduled_at': '2026-11-16T06:00:00Z',
                      'time_of_day': '06:00',
                      'recurrence_days': [0, 1, 2, 3, 4],
                      'timezone': 'UTC',
                      'enabled': true,
                      'status': 'ringing',
                      'snoozed_until': null,
                      'bypass_quiet_hours': true,
                      'origin': 'host',
                      'last_fired_at': '2026-11-15T06:00:00Z',
                      'acknowledged_at': null,
                      'created_at': '2026-11-15T06:00:00Z',
                      'updated_at': '2026-11-15T06:00:00Z',
                    },
                  ],
                  'total': 1,
                }),
                200,
              );
            case '/api/v1/routines':
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 'r1',
                      'profile_id': 'prof-1',
                      'title': 'Evening Check-in',
                      'prompt_template': null,
                      'fallback_message': 'How did today go for you?',
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
            case '/api/v1/notifications':
              return http.Response(
                jsonEncode({
                  'items': <dynamic>[],
                  'total': 0,
                  'unread_count': 0,
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
              return http.Response(
                jsonEncode({'items': <dynamic>[], 'total': 0}),
                200,
              );
          }
        });

        final client = CompanionClient(
          baseUrl: 'http://127.0.0.1:8000',
          httpClient: mockClient,
        );
        final schedCtrl = DesktopScheduleController(
          client: client,
          toastAdapter: NoOpDesktopToastAdapter(),
          profileId: 'prof-1',
        );
        addTearDown(schedCtrl.dispose);
        addTearDown(client.close);
        await schedCtrl.refreshAll();

        await tester.pumpWidget(
          MaterialApp(
            theme: CompanionTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: ScheduleScreen(controller: schedCtrl),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final keyName in const [
          'schedule_nav_alarms',
          'schedule_nav_routines',
          'schedule_nav_notifications',
        ]) {
          await tester.tap(find.byKey(Key(keyName)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'DesktopShell renders Active Alert Banner and NotificationBacklogDrawer without overflow at 1024x640 with 1.3x text scale',
      (tester) async {
        setupViewport(tester, const Size(1024, 640));

        final mockClient = MockClient((req) async {
          if (req.url.path == '/api/v1/notifications') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'evt-1',
                    'profile_id': 'prof-1',
                    'source_type': 'alarm',
                    'source_id': 'a1',
                    'urgency': 'high',
                    'title': 'High Urgency Wakeup Alarm',
                    'body': 'Tap stop to silence alarm.',
                    'status': 'unread',
                    'delivery_policy': 'immediate',
                    'is_missed_catchup': false,
                    'triggered_at': '2026-11-15T06:30:00Z',
                    'read_at': null,
                    'resolved_at': null,
                    'created_at': '2026-11-15T06:30:00Z',
                    'updated_at': '2026-11-15T06:30:00Z',
                  },
                  {
                    'id': 'evt-2',
                    'profile_id': 'prof-1',
                    'source_type': 'routine',
                    'source_id': 'rt1',
                    'urgency': 'informational',
                    'title': 'Evening Reflection Routine',
                    'body': 'Compact top notification card at 1.3x text scale.',
                    'status': 'unread',
                    'delivery_policy': 'immediate',
                    'is_missed_catchup': false,
                    'triggered_at': '2026-11-15T20:00:00Z',
                    'read_at': null,
                    'resolved_at': null,
                    'created_at': '2026-11-15T20:00:00Z',
                    'updated_at': '2026-11-15T20:00:00Z',
                  },
                ],
                'total': 2,
                'unread_count': 2,
                'missed_count': 1,
              }),
              200,
            );
          }
          if (req.url.path == '/api/v1/profiles/me/quiet-hours') {
            return http.Response(
              jsonEncode({
                'quiet_hours_enabled': true,
                'quiet_hours_start': '22:00',
                'quiet_hours_end': '07:00',
                'quiet_hours_timezone': 'UTC',
              }),
              200,
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
        final schedCtrl = DesktopScheduleController(
          client: client,
          toastAdapter: NoOpDesktopToastAdapter(),
          profileId: 'prof-1',
        );
        addTearDown(schedCtrl.dispose);
        addTearDown(client.close);
        await schedCtrl.refreshAll();

        final settingsCtrl = DesktopSettingsController();
        await tester.pumpWidget(
          MaterialApp(
            theme: CompanionTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: DesktopShell(
              controller: settingsCtrl,
              scheduleController: schedCtrl,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('shell_center_alert_modal')), findsOneWidget);
        expect(find.byKey(const Key('shell_active_alert_banner')), findsOneWidget);

        await tester.tap(find.byKey(const Key('shell_notification_bell_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Notification Center'), findsOneWidget);
      },
    );
  });
}
