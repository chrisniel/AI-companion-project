import 'package:flutter/material.dart';

/// User action choices when shutdown encounters incomplete cleanup.
enum IncompleteShutdownAction {
  /// Wait and retry cooperative graceful shutdown.
  retryGraceful,

  /// Terminate the verified runtime process immediately via OS fallback.
  forceStop,

  /// Terminate only the Flutter desktop client, leaving the runtime alive.
  quitUiOnly,

  /// Cancel and return to the application.
  cancel,
}

/// User action choices when the runtime is unresponsive.
enum UnresponsiveShutdownAction {
  /// Terminate the verified runtime process immediately via OS fallback.
  forceStop,

  /// Terminate only the Flutter desktop client.
  quitUiOnly,

  /// Cancel and return to the application.
  cancel,
}

/// Modal dialogs for desktop shutdown confirmation and failure recovery.
class DesktopShutdownDialogs {
  const DesktopShutdownDialogs._();

  /// Prompts the user to confirm exiting the application.
  static Future<bool> showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit AI Companion?'),
        content: const Text(
          'Exiting will stop the local companion runtime and any active sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit Companion'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Prompts the user with recovery actions when in-flight persistence
  /// or provider cleanup did not complete within the quiescence deadline.
  static Future<IncompleteShutdownAction?> showIncompleteShutdownDialog(
    BuildContext context, {
    String? diagnostic,
  }) async {
    return showDialog<IncompleteShutdownAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Incomplete Shutdown'),
        content: Text(
          diagnostic ??
              'In-flight database operations or model operations did not complete within the quiescence deadline. Forcing shutdown now may result in unsaved work or data corruption.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(IncompleteShutdownAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(IncompleteShutdownAction.quitUiOnly),
            child: const Text('Quit Desktop UI Only'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(IncompleteShutdownAction.retryGraceful),
            child: const Text('Wait / Retry Graceful Shutdown'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(IncompleteShutdownAction.forceStop),
            child: const Text('Force Stop Local Runtime'),
          ),
        ],
      ),
    );
  }

  /// Prompts the user when the runtime is unresponsive.
  static Future<UnresponsiveShutdownAction?> showUnresponsiveShutdownDialog(
    BuildContext context, {
    String? diagnostic,
  }) async {
    return showDialog<UnresponsiveShutdownAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Runtime Unresponsive'),
        content: Text(
          diagnostic ??
              'The local runtime could not be terminated cooperatively and process fallback could not be verified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(UnresponsiveShutdownAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(UnresponsiveShutdownAction.quitUiOnly),
            child: const Text('Quit Desktop UI Only'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(UnresponsiveShutdownAction.forceStop),
            child: const Text('Force Stop Local Runtime'),
          ),
        ],
      ),
    );
  }
}
