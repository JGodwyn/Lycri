// Runs the app with automatic hot reload on file changes.
//
//   dart run tool/dev.dart            # macOS (default)
//   dart run tool/dev.dart -d windows # any extra args go to `flutter run`
//
// Works like `flutter run` (r / R / q still work in the terminal), plus:
//   • a change under lib/ (.dart)  → hot reload   (SIGUSR1)
//   • a change under assets/       → hot restart  (SIGUSR2)
// Edits are debounced, so a burst of saves triggers a single reload.
//
// Changes to pubspec.yaml, native code, new fonts/asset folders, or the
// database schema (Drift tables / schemaVersion — migrations only run when
// the app opens the database) still need a full restart: press q and run
// this again.
//
// Auto-reload uses POSIX signals, so it works on macOS (and Linux); on Windows
// this behaves like plain `flutter run`.
import 'dart:async';
import 'dart:io';

const _debounce = Duration(milliseconds: 300);

Future<void> main(List<String> args) async {
  // Run from the project root (where pubspec.yaml lives).
  final root = Directory.current;
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Run this from the project root: dart run tool/dev.dart');
    exit(64);
  }
  final pidFile = File(
    '${Directory.systemTemp.path}/lycri_flutter_run_$pid.pid',
  );
  if (pidFile.existsSync()) pidFile.deleteSync();

  final deviceArgs = args.contains('-d') ? <String>[] : ['-d', 'macos'];
  final flutter = await Process.start(
    'flutter',
    ['run', ...deviceArgs, ...args, '--pid-file', pidFile.path],
    workingDirectory: root.path,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );

  Timer? pending;
  var restartNeeded = false;

  void schedule({required bool restart}) {
    restartNeeded |= restart;
    pending?.cancel();
    pending = Timer(_debounce, () {
      final signal =
          restartNeeded ? ProcessSignal.sigusr2 : ProcessSignal.sigusr1;
      restartNeeded = false;
      if (!pidFile.existsSync()) return; // app still building
      final toolPid = int.tryParse(pidFile.readAsStringSync().trim());
      if (toolPid == null) return;
      stdout.writeln(
        '\n[dev] ${signal == ProcessSignal.sigusr2 ? 'Hot restart' : 'Hot reload'}'
        ' (file change)',
      );
      Process.killPid(toolPid, signal);
    });
  }

  final subscriptions = <StreamSubscription<FileSystemEvent>>[
    if (!Platform.isWindows) ...[
      Directory('${root.path}/lib')
          .watch(recursive: true)
          .where((e) => e.path.endsWith('.dart'))
          .listen((_) => schedule(restart: false)),
      Directory(
        '${root.path}/assets',
      ).watch(recursive: true).listen((_) => schedule(restart: true)),
    ],
  ];

  final code = await flutter.exitCode;
  for (final s in subscriptions) {
    await s.cancel();
  }
  pending?.cancel();
  if (pidFile.existsSync()) pidFile.deleteSync();
  exit(code);
}
