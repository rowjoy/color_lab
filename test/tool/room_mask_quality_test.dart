import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/room_mask/quality_metrics.dart';
import '../../tool/verify_room_mask_quality.dart';

void main() {
  Map<String, Object?> evaluate(List<int> predicted, List<int> truth) =>
      evaluateRoomMaskQuality(
        predicted: Uint8List.fromList(predicted),
        truth: Uint8List.fromList(truth),
        width: truth.length,
        height: 1,
      );

  test('hand-derived per-layer confusion distinguishes spill and misses', () {
    final result = evaluate(
      [1, 4, 2, 0, 3, 3, 4, 1, 0, 1],
      [1, 1, 2, 2, 3, 3, 4, 4, 0, 255],
    );
    expect(result['annotatedPixels'], 9);
    expect(result['ignoredPixels'], 1);
    expect(result['pixelAccuracy'], closeTo(2 / 3, 1e-10));
    expect(result['meanIoU'], closeTo(13 / 24, 1e-10));
    final layers = result['layers'] as Map;
    expect(layers['wall'], {
      'truthPixels': 2,
      'predictedPixels': 2,
      'intersectionPixels': 1,
      'unionPixels': 3,
      'iou': 1 / 3,
      'precision': .5,
      'recall': .5,
      'dice': .5,
    });
    expect((layers['ceiling'] as Map)['iou'], .5);
    expect((layers['floor'] as Map)['iou'], 1);
    expect(result['meets95PerLayer'], isFalse);
  });

  test('large correct background never hides missing supported surfaces', () {
    final truth = [...List<int>.filled(1000, 0), 1, 2, 3, 4];
    final result = evaluate(List<int>.filled(1004, 0), truth);
    expect(result['pixelAccuracy'], greaterThan(.99));
    expect(result['meanIoU'], 0);
    expect(result['meets95PerLayer'], isFalse);
  });

  test(
    'only fully annotated all-four-layer success meets per-layer target',
    () {
      expect(
        evaluate([0, 1, 2, 3, 4], [0, 1, 2, 3, 4])['meets95PerLayer'],
        isTrue,
      );
      expect(evaluate([1, 1], [1, 1])['meets95PerLayer'], isFalse);
      final sparse = evaluate([1, 2, 3, 4, 0], [1, 2, 3, 4, 255]);
      expect(sparse['meanIoU'], 1);
      expect(sparse['meets95PerLayer'], isFalse);
      final empty = evaluate([0, 0], [255, 255]);
      expect(empty['pixelAccuracy'], isNull);
      expect(empty['meanIoU'], isNull);
      expect(empty['meets95PerLayer'], isFalse);
    },
  );

  test('invalid domains and geometry are rejected instead of scored', () {
    for (final pair in [
      ([5], [1]),
      ([255], [255]),
      ([1], [5]),
    ]) {
      expect(() => evaluate(pair.$1, pair.$2), throwsArgumentError);
    }
    for (final dimensions in [(0, 1), (-1, 1), (1, 0), (2, 1)]) {
      expect(
        () => evaluateRoomMaskQuality(
          predicted: Uint8List.fromList([1]),
          truth: Uint8List.fromList([1]),
          width: dimensions.$1,
          height: dimensions.$2,
        ),
        throwsArgumentError,
      );
    }
    expect(() => evaluate([1], [1, 2]), throwsArgumentError);
  });

  group('CLI', () {
    late Directory root;
    late File predicted;
    late File truth;
    late StringBuffer out, err;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('room-mask-quality-test-');
      predicted = File('${root.path}/predicted.bin');
      truth = File('${root.path}/truth.bin');
      await predicted.writeAsBytes([0, 1, 2, 3, 4]);
      await truth.writeAsBytes([0, 1, 2, 3, 4]);
      out = StringBuffer();
      err = StringBuffer();
    });
    tearDown(() => root.delete(recursive: true));
    List<String> args() => [
      '--prediction',
      predicted.path,
      '--truth',
      truth.path,
      '--width',
      '5',
      '--height',
      '1',
    ];

    test('reads real raw files and emits auditable sample-only evidence', () {
      expect(verifyRoomMaskQuality(args(), out: out, err: err), 0);
      final report = jsonDecode(out.toString()) as Map;
      expect(report['meets95PerLayer'], isTrue);
      expect(report['modelWideAccuracyEstablished'], isFalse);
      expect(report['truthSha256'], hasLength(64));
      expect(report['width'], 5);
      expect(err.toString(), isEmpty);
    });

    test('unmet target and missing/invalid inputs return nonzero', () async {
      await predicted.writeAsBytes([0, 0, 0, 0, 0]);
      expect(verifyRoomMaskQuality(args(), out: out, err: err), 1);
      expect((jsonDecode(out.toString()) as Map)['meets95PerLayer'], isFalse);
      expect(verifyRoomMaskQuality([], out: out, err: err), 64);
      expect(
        verifyRoomMaskQuality([...args(), '--width', '5'], out: out, err: err),
        64,
      );
      await truth.delete();
      expect(verifyRoomMaskQuality(args(), out: out, err: err), 1);
    });

    test('does not accept a prediction file as its own annotation', () {
      final arguments = args();
      arguments[3] = predicted.path;
      expect(verifyRoomMaskQuality(arguments, out: out, err: err), 1);
    });
  });
}
