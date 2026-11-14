import 'package:companion_api/companion_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion_desktop/platform/windows_toast_adapter.dart';

NotificationEventOut _makeEvent({
  String id = 'evt-1',
  String sourceType = 'reminder',
  String sourceId = 'rem-1',
  String urgency = 'standard',
  String title = 'Drink Water',
  String? body = 'Take a 2-minute stretch',
  String status = 'unread',
  String deliveryPolicy = 'immediate',
  bool isMissedCatchup = false,
}) {
  return NotificationEventOut(
    id: id,
    profileId: 'prof-1',
    sourceType: sourceType,
    sourceId: sourceId,
    urgency: urgency,
    title: title,
    body: body,
    status: status,
    deliveryPolicy: deliveryPolicy,
    isMissedCatchup: isMissedCatchup,
    triggeredAt: '2026-11-15T08:00:00Z',
    createdAt: '2026-11-15T08:00:00Z',
    updatedAt: '2026-11-15T08:00:00Z',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowsWinRtToastAdapter XML & Actions', () {
    test('sanitizes control chars and escapes XML entities safely', () {
      const dirty = 'A & B <tag> "quote" \'single\' \x00\x07\x1F ok';
      final clean = WindowsWinRtToastAdapter.sanitizeXmlText(dirty);
      expect(clean.contains('\x00'), isFalse);
      expect(clean.contains('\x07'), isFalse);
      expect(clean.contains('\x1F'), isFalse);

      final escaped = WindowsWinRtToastAdapter.escapeXml(clean);
      expect(escaped, 'A &amp; B &lt;tag&gt; &quot;quote&quot; &apos;single&apos;  ok');
    });

    test('builds live alarm XML with scenario=alarm, looping chime, and interactive buttons', () {
      final event = _makeEvent(
        id: 'alarm-evt-1',
        sourceType: 'alarm',
        urgency: 'high',
        title: 'Wake Up <6:30>',
        body: 'Morning alarm & commute',
        deliveryPolicy: 'immediate',
        isMissedCatchup: false,
      );

      final xml = WindowsWinRtToastAdapter.buildToastXml(event);
      expect(xml, contains('scenario="alarm"'));
      expect(xml, contains('ms-winsoundevent:Notification.Looping.Alarm'));
      expect(xml, contains('loop="true"'));
      expect(xml, contains('Wake Up &lt;6:30&gt;'));
      expect(xml, contains('Morning alarm &amp; commute'));
      expect(xml, contains('content="Acknowledge"'));
      expect(xml, contains('content="Snooze 10m"'));
      expect(xml, contains('content="Dismiss"'));
      expect(xml, contains('action=snooze_10m&amp;event_id=alarm-evt-1'));
    });

    test('builds task-linked reminder XML with Mark Done button instead of Acknowledge', () {
      final event = _makeEvent(
        id: 'task-evt-1',
        sourceType: 'task_reminder',
        title: 'Submit expense report',
      );

      final xml = WindowsWinRtToastAdapter.buildToastXml(event, hasLinkedTask: true);
      expect(xml, contains('scenario="reminder"'));
      expect(xml, contains('ms-winsoundevent:Notification.Reminder'));
      expect(xml, contains('content="Mark Done"'));
      expect(xml, contains('action=mark_done&amp;event_id=task-evt-1'));
      expect(xml, contains('content="Snooze 10m"'));
      expect(xml, contains('content="Dismiss"'));
    });

    test('builds routine XML with Open Chat button and default chime', () {
      final event = _makeEvent(
        id: 'rout-evt-1',
        sourceType: 'routine',
        urgency: 'informational',
        title: 'Evening Reflection',
        body: 'How did your focus blocks go?',
      );

      final xml = WindowsWinRtToastAdapter.buildToastXml(event);
      expect(xml.contains('scenario="alarm"'), isFalse);
      expect(xml, contains('ms-winsoundevent:Notification.Default'));
      expect(xml, contains('content="Open Chat"'));
      expect(xml, contains('action=open_chat&amp;event_id=rout-evt-1'));
      expect(xml, contains('content="Acknowledge"'));
    });

    test('suppressed alarm or missed catch-up never emits scenario=alarm and uses silent audio', () {
      final suppressedAlarm = _makeEvent(
        id: 'alarm-sup-1',
        sourceType: 'alarm',
        urgency: 'high',
        deliveryPolicy: 'quiet_hours_suppressed',
        status: 'suppressed_quiet_hours',
      );
      final suppressedXml = WindowsWinRtToastAdapter.buildToastXml(suppressedAlarm);
      expect(suppressedXml.contains('scenario="alarm"'), isFalse);
      expect(suppressedXml, contains('<audio silent="true"/>'));

      final catchupAlarm = _makeEvent(
        id: 'alarm-catchup-1',
        sourceType: 'alarm',
        urgency: 'high',
        status: 'missed_catchup',
        deliveryPolicy: 'missed_catchup',
        isMissedCatchup: true,
      );
      final catchupXml = WindowsWinRtToastAdapter.buildToastXml(catchupAlarm);
      expect(catchupXml.contains('scenario="alarm"'), isFalse);
      expect(catchupXml, contains('<audio silent="true"/>'));
    });

    test('builds consolidated catch-up summary XML with Review Backlog action', () {
      final events = [
        _makeEvent(id: 'e1', title: 'Standup', isMissedCatchup: true, status: 'missed_catchup'),
        _makeEvent(id: 'e2', title: 'Pay rent', isMissedCatchup: true, status: 'missed_catchup'),
      ];
      final xml = WindowsWinRtToastAdapter.buildCatchupSummaryToastXml(
        missedCount: 2,
        events: events,
      );
      expect(xml.contains('scenario="alarm"'), isFalse);
      expect(xml, contains('<audio silent="true"/>'));
      expect(xml, contains('Missed Notifications (2)'));
      expect(xml, contains('content="Review Backlog"'));
      expect(xml, contains('arguments="action=open_backlog"'));
    });
  });

  group('WindowsWinRtToastAdapter MethodChannel & Callbacks', () {
    const channelName = WindowsWinRtToastAdapter.defaultChannelName;
    const channel = MethodChannel(channelName);

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('invokes showToast, removeToast, and clearToasts with expected args', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      final adapter = WindowsWinRtToastAdapter(isWindowsOverride: true);
      addTearDown(adapter.dispose);

      final suppressedReminder = _makeEvent(
        id: 'rem-quiet-1',
        deliveryPolicy: 'quiet_hours_suppressed',
        status: 'suppressed_quiet_hours',
      );
      final shown = await adapter.showNotificationToast(suppressedReminder);
      expect(shown, isTrue);
      expect(calls.length, 1);
      expect(calls[0].method, 'showToast');
      final showArgs = Map<String, dynamic>.from(calls[0].arguments as Map);
      expect(showArgs['tag'], 'evt_rem-quiet-1');
      expect(showArgs['group'], WindowsWinRtToastAdapter.defaultToastGroup);
      expect(showArgs['suppressPopup'], isTrue);
      expect(showArgs['xml'] as String, contains('<audio silent="true"/>'));

      final removed = await adapter.removeNotificationToast('rem-quiet-1');
      expect(removed, isTrue);
      expect(calls[1].method, 'removeToast');
      expect(Map<String, dynamic>.from(calls[1].arguments as Map)['tag'], 'evt_rem-quiet-1');

      final cleared = await adapter.clearAllNotificationToasts();
      expect(cleared, isTrue);
      expect(calls[2].method, 'clearToasts');
      expect(
        Map<String, dynamic>.from(calls[2].arguments as Map)['group'],
        WindowsWinRtToastAdapter.defaultToastGroup,
      );
    });

    test('emits ToastActivationEvent when native runner invokes onToastActivated', () async {
      final adapter = WindowsWinRtToastAdapter(isWindowsOverride: true);
      addTearDown(adapter.dispose);

      final received = <ToastActivationEvent>[];
      final sub = adapter.activations.listen(received.add);
      addTearDown(sub.cancel);

      const codec = StandardMethodCodec();
      final byteData = codec.encodeMethodCall(
        const MethodCall('onToastActivated', {'arguments': 'action=mark_done&event_id=evt-42'}),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(channelName, byteData, (_) {});

      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1);
      expect(received.first.action, 'mark_done');
      expect(received.first.eventId, 'evt-42');
    });

    test('fails gracefully returning false when platform channel throws MissingPluginException', () async {
      final adapter = WindowsWinRtToastAdapter(isWindowsOverride: true);
      addTearDown(adapter.dispose);

      final ok = await adapter.showNotificationToast(_makeEvent());
      expect(ok, isFalse);
      expect(await adapter.removeNotificationToast('evt-1'), isFalse);
      expect(await adapter.clearAllNotificationToasts(), isFalse);
    });
  });
}
