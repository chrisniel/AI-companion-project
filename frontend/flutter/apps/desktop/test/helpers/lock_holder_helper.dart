import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    exit(1);
  }
  final lockPath = args[0];
  final durationMs = args.length > 1 ? int.parse(args[1]) : 1000;

  final file = File(lockPath);
  await file.parent.create(recursive: true);
  final handle = await file.open(mode: FileMode.append);
  await handle.lock(FileLock.exclusive);

  // Inform parent process that lock is held
  stdout.writeln('LOCKED');
  await stdout.flush();

  await Future<void>.delayed(Duration(milliseconds: durationMs));
  try {
    await handle.unlock();
    await handle.close();
  } catch (_) {}
}
