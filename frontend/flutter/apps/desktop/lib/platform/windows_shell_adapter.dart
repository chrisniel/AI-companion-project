import 'dart:io';

import 'package:flutter/services.dart';

/// Abstraction over native Windows folder/file pickers and Explorer launch.
abstract class DesktopShellAdapter {
  Future<String?> pickFolder({
    String? title,
    String? initialDirectory,
  });

  Future<List<String>> pickModelFiles({
    String? title,
    bool allowMultiple = true,
    String? initialDirectory,
  });

  Future<List<String>> pickExecutableFiles({
    String? title,
    bool allowMultiple = true,
    String? initialDirectory,
  });

  Future<void> openFolder(
    String path, {
    bool createIfMissing = false,
  });

  Future<int> stageFilesToInbox({
    required List<String> sourcePaths,
    required String inboxDir,
    required bool moveFiles,
  });
}

/// Zero-plugin Windows COM shell implementation over ai_companion/windows_shell.
class WindowsShellAdapter implements DesktopShellAdapter {
  static const MethodChannel _channel =
      MethodChannel('ai_companion/windows_shell');

  @override
  Future<String?> pickFolder({
    String? title,
    String? initialDirectory,
  }) async {
    if (!Platform.isWindows || Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<String>('pickFolder', {
        if (title != null && title.isNotEmpty) 'title': title,
        if (initialDirectory != null && initialDirectory.isNotEmpty)
          'initialDirectory': initialDirectory,
      });
      if (result == null || result.trim().isEmpty) {
        return null;
      }
      return result.trim();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<List<String>> pickModelFiles({
    String? title,
    bool allowMultiple = true,
    String? initialDirectory,
  }) async {
    return _pickFilesWithPreset(
      title: title,
      allowMultiple: allowMultiple,
      initialDirectory: initialDirectory,
    );
  }

  @override
  Future<List<String>> pickExecutableFiles({
    String? title,
    bool allowMultiple = true,
    String? initialDirectory,
  }) async {
    return _pickFilesWithPreset(
      title: title,
      allowMultiple: allowMultiple,
      initialDirectory: initialDirectory,
      filterPreset: 'executables',
    );
  }

  Future<List<String>> _pickFilesWithPreset({
    String? title,
    bool allowMultiple = true,
    String? initialDirectory,
    String? filterPreset,
  }) async {
    if (!Platform.isWindows || Platform.environment.containsKey('FLUTTER_TEST')) {
      return const [];
    }
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('pickFiles', {
        'allowMultiple': allowMultiple,
        if (title != null && title.isNotEmpty) 'title': title,
        if (initialDirectory != null && initialDirectory.isNotEmpty)
          'initialDirectory': initialDirectory,
        if (filterPreset != null && filterPreset.isNotEmpty)
          'filterPreset': filterPreset,
      });
      if (result == null) return const [];
      return result
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> openFolder(
    String path, {
    bool createIfMissing = false,
  }) async {
    if (!Platform.isWindows || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    if (createIfMissing) {
      final dir = Directory(trimmed);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
    }
    try {
      await Process.run('explorer.exe', [trimmed]);
    } catch (_) {}
  }

  @override
  Future<int> stageFilesToInbox({
    required List<String> sourcePaths,
    required String inboxDir,
    required bool moveFiles,
  }) async {
    final destDir = Directory(inboxDir);
    if (!destDir.existsSync()) {
      await destDir.create(recursive: true);
    }
    int staged = 0;
    for (final rawPath in sourcePaths) {
      final srcFile = File(rawPath);
      if (!srcFile.existsSync()) continue;
      final fileName = srcFile.uri.pathSegments.lastWhere(
        (s) => s.isNotEmpty,
        orElse: () => 'model.gguf',
      );
      final destPath = '${destDir.path}${Platform.pathSeparator}$fileName';
      if (File(destPath).existsSync()) continue;
      if (moveFiles) {
        try {
          await srcFile.rename(destPath);
        } on FileSystemException {
          await srcFile.copy(destPath);
          await srcFile.delete();
        }
      } else {
        await srcFile.copy(destPath);
      }
      staged++;
    }
    return staged;
  }
}
