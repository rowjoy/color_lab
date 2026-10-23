// macOS host gate: copies published prebuilts, compiles Dart kernel only.
import 'dart:convert';
import 'dart:io';

Future<int> run(String executable, List<String> arguments) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

Future<int> runVerifier(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments);
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  final result = await process.exitCode.timeout(
    const Duration(seconds: 60),
    onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return 124;
    },
  );
  final stdoutText = await output;
  stdout.write(stdoutText);
  stderr.write(await errors);
  if (result != 0) return result;
  final passed = const LineSplitter().convert(stdoutText).any((line) {
    try {
      final value = jsonDecode(line);
      return value is Map &&
          value['status'] == 'PASS' &&
          value['runtime'] is String &&
          value['histogramAll512'] is List;
    } on FormatException {
      return false;
    }
  });
  if (!passed) {
    stderr.writeln('Verifier exited without actual inference evidence');
    return 1;
  }
  return 0;
}

File requireFile(String path) {
  final file = File(path).absolute;
  if (!file.existsSync()) {
    throw FileSystemException('Required file missing', file.path);
  }
  return file;
}

Future<void> main(List<String> args) async {
  try {
    final options = <String, String>{};
    for (var i = 0; i < args.length; i += 2) {
      if (![
            '--flutter-root',
            '--model',
            '--native-library',
          ].contains(args[i]) ||
          i + 1 >= args.length ||
          options.containsKey(args[i])) {
        throw const FormatException(
          'Usage: dart run tool/run_room_model_smoke.dart --flutter-root PATH [--model PATH] [--native-library PATH]',
        );
      }
      options[args[i]] = args[i + 1];
    }
    if (!Platform.isMacOS) {
      throw UnsupportedError(
        'This prebuilt host smoke currently supports macOS only',
      );
    }
    final sdk = options['--flutter-root'];
    if (sdk == null) throw const FormatException('--flutter-root is required');
    final runtime = requireFile('$sdk/bin/cache/dart-sdk/bin/dartaotruntime');
    final frontend = requireFile(
      '$sdk/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot',
    );
    final patched = Directory(
      '$sdk/bin/cache/artifacts/engine/common/flutter_patched_sdk',
    ).absolute;
    requireFile('${patched.path}/platform_strong.dill');
    final tester = requireFile(
      '$sdk/bin/cache/artifacts/engine/darwin-x64/flutter_tester',
    );
    final icu = requireFile(
      '$sdk/bin/cache/artifacts/engine/darwin-x64/icudtl.dat',
    );
    final config = requireFile('.dart_tool/package_config.json');
    final packages = jsonDecode(config.readAsStringSync()) as Map;
    final package = (packages['packages'] as List).cast<Map>().singleWhere(
      (p) => p['name'] == 'tflite_flutter',
    );
    final packageRoot = Directory.fromUri(
      config.uri.resolve(package['rootUri'] as String),
    ).uri;
    final pubspec = requireFile(
      File.fromUri(packageRoot.resolve('pubspec.yaml')).path,
    ).readAsStringSync();
    if (!RegExp(r'^version: 0\.12\.1\s*$', multiLine: true).hasMatch(pubspec)) {
      throw const FormatException(
        'The host gate requires exact published tflite_flutter 0.12.1',
      );
    }
    final library = requireFile(
      options['--native-library'] ??
          File.fromUri(
            packageRoot.resolve('macos/libtensorflowlite_c-mac.dylib'),
          ).path,
    );
    final model = requireFile(
      options['--model'] ?? 'assets/models/room_seg.tflite',
    );
    final descriptor = requireFile('assets/models/room_seg_descriptor.json');
    final depthModel = requireFile('assets/models/room_depth.tflite');
    final source = requireFile('tool/verify_room_model.dart');
    // No binaries are added to the project, Flutter SDK or package cache.
    final stage = Directory.systemTemp.createTempSync('color-lab-room-smoke.');
    final bin = Directory('${stage.path}/host/bin')
      ..createSync(recursive: true);
    final resources = Directory('${stage.path}/host/resources')
      ..createSync(recursive: true);
    final assets = Directory('${stage.path}/flutter_assets/assets/models')
      ..createSync(recursive: true);
    final stagedTester = tester.copySync('${bin.path}/flutter_tester');
    library.copySync('${resources.path}/libtensorflowlite_c-mac.dylib');
    model.copySync('${assets.path}/room_seg.tflite');
    descriptor.copySync('${assets.path}/room_seg_descriptor.json');
    depthModel.copySync('${assets.path}/room_depth.tflite');
    final chmod = await run('/bin/chmod', ['u+x', stagedTester.path]);
    if (chmod != 0) {
      exitCode = chmod;
      return;
    }
    final kernel = '${stage.path}/verify_room_model.dill';
    stdout.writeln('Room model smoke staging: ${stage.path}');
    final compilation = await run(runtime.path, [
      frontend.path,
      '--sdk-root',
      '${patched.path}/',
      '--target=flutter',
      '--no-print-incremental-dependencies',
      '--packages',
      config.path,
      '--output-dill',
      kernel,
      source.path,
    ]);
    if (compilation != 0) {
      exitCode = compilation;
      return;
    }
    requireFile(kernel);
    exitCode = await runVerifier(stagedTester.path, [
      '--run-forever',
      '--disable-vm-service',
      '--icu-data-file-path=${icu.path}',
      '--enable-software-rendering',
      '--non-interactive',
      '--packages=${config.path}',
      '--flutter-assets-dir=${stage.path}/flutter_assets',
      kernel,
    ]);
    if (exitCode != 0) {
      stderr.writeln(
        'Room model verifier failed (exit $exitCode); staging retained at ${stage.path}',
      );
    }
  } catch (error) {
    stderr.writeln('ROOM MODEL SMOKE FAILED: $error');
    exitCode = 1;
  }
}
