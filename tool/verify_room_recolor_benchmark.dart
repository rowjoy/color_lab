import 'dart:convert';
import 'dart:io';

import 'room_recolor/benchmark.dart';

void main(List<String> arguments) {
  exitCode = verifyRoomRecolorBenchmark(arguments, out: stdout, err: stderr);
}

/// Returns an exit code and writes an auditable result; no corpus is created or
/// repaired. Acquisition-only checks explicitly report that evidence is pending.
int verifyRoomRecolorBenchmark(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
}) {
  String? root;
  var adjudicated = false;
  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--root':
        if (root != null ||
            i + 1 == arguments.length ||
            arguments[i + 1].startsWith('--')) {
          return _usage(err);
        }
        root = arguments[++i];
      case '--require-adjudicated':
        if (adjudicated) return _usage(err);
        adjudicated = true;
      default:
        return _usage(err);
    }
  }
  if (root == null) return _usage(err);
  try {
    final benchmark = loadRoomRecolorBenchmark(
      Directory(root),
      requireAdjudicatedAnnotations: adjudicated,
    );
    out.writeln(
      jsonEncode({
        'status': benchmark.hasAdjudicatedAnnotations
            ? 'PASS'
            : 'PENDING ANNOTATIONS',
        'acceptedDistinctPhotos': benchmark.photos.length,
        'adjudicatedAnnotations': benchmark.hasAdjudicatedAnnotations,
        'manifestSha256': benchmark.manifestSha256,
        'protocolSha256': benchmark.protocolSha256,
        'categories': {
          for (final category
              in benchmark.photos.map((p) => p.category).toSet())
            category: benchmark.photos
                .where((p) => p.category == category)
                .length,
        },
        'baselineSuitability':
            'NOT CHECKED: requires separately scored frozen baseline coverage',
      }),
    );
    return 0;
  } on FormatException catch (error) {
    err.writeln('ROOM RECOLOR BENCHMARK FAILED: ${error.message}');
    return 1;
  }
}

int _usage(StringSink err) {
  err.writeln(
    'Usage: dartvm tool/verify_room_recolor_benchmark.dart --root <directory> [--require-adjudicated]',
  );
  return 64;
}
