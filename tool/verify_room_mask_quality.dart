import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'room_mask/quality_metrics.dart';

void main(List<String> arguments) {
  exitCode = verifyRoomMaskQuality(arguments, out: stdout, err: stderr);
}

int verifyRoomMaskQuality(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
}) {
  const keys = ['--prediction', '--truth', '--width', '--height'];
  final options = <String, String>{};
  for (var i = 0; i < arguments.length; i += 2) {
    if (!keys.contains(arguments[i]) ||
        options.containsKey(arguments[i]) ||
        i + 1 >= arguments.length) {
      return _usage(err);
    }
    options[arguments[i]] = arguments[i + 1];
  }
  final width = int.tryParse(options['--width'] ?? '');
  final height = int.tryParse(options['--height'] ?? '');
  if (options.length != 4 ||
      width == null ||
      height == null ||
      width <= 0 ||
      height <= 0) {
    return _usage(err);
  }
  try {
    final prediction = File(options['--prediction']!);
    final annotation = File(options['--truth']!);
    if (prediction.resolveSymbolicLinksSync() ==
        annotation.resolveSymbolicLinksSync()) {
      throw ArgumentError('Independent annotation file required');
    }
    final predicted = prediction.readAsBytesSync();
    final truth = annotation.readAsBytesSync();
    final report = evaluateRoomMaskQuality(
      predicted: predicted,
      truth: truth,
      width: width,
      height: height,
    );
    out.writeln(
      jsonEncode({
        ...report,
        'predictionSha256': sha256.convert(predicted).toString(),
        'truthSha256': sha256.convert(truth).toString(),
      }),
    );
    return report['meets95PerLayer'] == true ? 0 : 1;
  } on FileSystemException {
    err.writeln('Room mask quality check failed: could not read input files.');
    return 1;
  } on ArgumentError catch (error) {
    err.writeln('Room mask quality check failed: ${error.message}.');
    return 1;
  }
}

int _usage(StringSink err) {
  err.writeln(
    'Usage: dart run tool/verify_room_mask_quality.dart --prediction labels.bin --truth independently-annotated.bin --width W --height H',
  );
  return 64;
}
