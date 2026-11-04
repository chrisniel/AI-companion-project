import 'package:ai_companion_desktop/dialogs/desktop_shutdown_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopShutdownDialogs', () {
    testWidgets('showExitConfirmationDialog returns true on confirm and false on cancel', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await DesktopShutdownDialogs.showExitConfirmationDialog(context);
              },
              child: const Text('Open Confirm'),
            ),
          ),
        ),
      );

      // Open dialog and Cancel
      await tester.tap(find.text('Open Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Exit AI Companion?'), findsOneWidget);
      expect(find.textContaining('stop the local companion runtime'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Open dialog and Confirm
      await tester.tap(find.text('Open Confirm'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Exit Companion'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('showIncompleteShutdownDialog exposes all 4 recovery actions', (tester) async {
      IncompleteShutdownAction? action;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                action = await DesktopShutdownDialogs.showIncompleteShutdownDialog(context);
              },
              child: const Text('Open Incomplete'),
            ),
          ),
        ),
      );

      // 1. Cancel
      await tester.tap(find.text('Open Incomplete'));
      await tester.pumpAndSettle();

      expect(find.text('Incomplete Shutdown'), findsOneWidget);
      expect(find.textContaining('quiescence deadline'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(action, equals(IncompleteShutdownAction.cancel));

      // 2. Quit UI Only
      await tester.tap(find.text('Open Incomplete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quit Desktop UI Only'));
      await tester.pumpAndSettle();
      expect(action, equals(IncompleteShutdownAction.quitUiOnly));

      // 3. Retry Graceful
      await tester.tap(find.text('Open Incomplete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wait / Retry Graceful Shutdown'));
      await tester.pumpAndSettle();
      expect(action, equals(IncompleteShutdownAction.retryGraceful));

      // 4. Force Stop
      await tester.tap(find.text('Open Incomplete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Force Stop Local Runtime'));
      await tester.pumpAndSettle();
      expect(action, equals(IncompleteShutdownAction.forceStop));
    });

    testWidgets('showUnresponsiveShutdownDialog exposes all 3 actions', (tester) async {
      UnresponsiveShutdownAction? action;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                action = await DesktopShutdownDialogs.showUnresponsiveShutdownDialog(context);
              },
              child: const Text('Open Unresponsive'),
            ),
          ),
        ),
      );

      // 1. Force Stop
      await tester.tap(find.text('Open Unresponsive'));
      await tester.pumpAndSettle();

      expect(find.text('Runtime Unresponsive'), findsOneWidget);

      await tester.tap(find.text('Force Stop Local Runtime'));
      await tester.pumpAndSettle();
      expect(action, equals(UnresponsiveShutdownAction.forceStop));
    });
  });
}
