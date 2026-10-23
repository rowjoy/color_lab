import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/room_recolor/quality_metrics.dart';

MaskBitmap mask(List<int> labels, {int? width}) => MaskBitmap(
  width: width ?? labels.length,
  height: labels.length ~/ (width ?? labels.length),
  labels: Uint8List.fromList(labels),
);

RoomQualityMetrics score(
  List<int> predicted,
  List<int> truth, {
  List<int>? protection,
  List<int>? coverage,
  int? width,
  int tolerance = 5,
}) => scoreRoomQuality(
  predictedOwnership: mask(predicted, width: width),
  groundTruthOwnership: mask(truth, width: width),
  effectiveCoverage: Uint8List.fromList(
    coverage ?? List.filled(truth.length, 0),
  ),
  groundTruthProtection: Uint8List.fromList(
    protection ?? List.filled(truth.length, 0),
  ),
  boundaryTolerancePixels: tolerance,
);

void main() {
  // Catches an exclusive (<5), squared-distance, or Manhattan match rule.
  test(
    'boundary match includes exactly five Euclidean pixels but excludes six',
    () {
      final truth = List.filled(8, 0)..[0] = 1;
      final atFive = score(
        List.filled(8, 0)..[5] = 1,
        truth,
      ).layers[RoomLayer.wall]!;
      final atSix = score(
        List.filled(8, 0)..[6] = 1,
        truth,
      ).layers[RoomLayer.wall]!;
      expect(atFive.boundaryTruePositive, 1);
      expect(atFive.boundaryRecallMatches, 1);
      expect(atFive.boundaryF1, 1);
      expect(atSix.boundaryTruePositive, 0);
      expect(atSix.boundaryFalsePositive, 1);
      expect(atSix.boundaryFalseNegative, 1);
      final diagonalTruth = List.filled(49, 0)..[0] = 1;
      final diagonal = score(
        List.filled(49, 0)..[4 * 7 + 3] = 1,
        diagonalTruth,
        width: 7,
      );
      expect(diagonal.layers[RoomLayer.wall]!.boundaryF1, 1);
    },
  );

  // Catches 4-neighbor boundaries, omitted image edges, and consumed matches.
  test(
    'boundaries use eight neighbors and outside background without consuming matches',
    () {
      final allWall = List.filled(9, 1);
      final full = score(
        allWall,
        allWall,
        width: 3,
        tolerance: 0,
      ).layers[RoomLayer.wall]!;
      expect(full.predictedBoundaryPixels, 8);
      final withCornerHole = List<int>.from(allWall)..[0] = 0;
      expect(
        score(
          withCornerHole,
          withCornerHole,
          width: 3,
          tolerance: 0,
        ).layers[RoomLayer.wall]!.predictedBoundaryPixels,
        8,
      );
      final manyToOne = score([1, 1, 0], [0, 0, 1]).layers[RoomLayer.wall]!;
      expect(manyToOne.boundaryTruePositive, 2);
      expect(manyToOne.boundaryRecallMatches, 1);
      expect(manyToOne.boundaryF1, 1);
    },
  );

  test('boundaries never match a different layer', () {
    final result = score([2, 0], [1, 0]);
    expect(result.layers[RoomLayer.wall]!.boundaryF1, 0);
    expect(result.layers[RoomLayer.ceiling]!.boundaryF1, 0);
  });

  // Catches treating absent truth as an excluded false positive or perfect IoU.
  test(
    'false-positive absent layers count while jointly absent layers are excluded',
    () {
      final result = score([1, 2, 0], [1, 0, 0], tolerance: 0);
      expect(result.layers[RoomLayer.wall]!.iou, 1);
      expect(result.layers[RoomLayer.ceiling]!.iou, 0);
      expect(result.layers[RoomLayer.ceiling]!.boundaryF1, 0);
      expect(result.layers[RoomLayer.floor]!.iou, isNull);
      expect(result.layers[RoomLayer.floor]!.boundaryF1, isNull);
      expect(result.macroIou, .5);
      expect(result.macroBoundaryF1, .5);
      expect(score([0], [0]).macroIou, isNull);
      expect(score([0], [0]).macroBoundaryF1, isNull);
    },
  );

  test('IoU exposes literal intersection and union per layer', () {
    final wall = score([1, 1, 0, 0], [0, 1, 1, 0]).layers[RoomLayer.wall]!;
    expect(wall.intersectionPixels, 1);
    expect(wall.unionPixels, 3);
    expect(wall.iou, closeTo(1 / 3, 1e-12));
  });

  // Catches an alpha>1 threshold or using all pixels as leakage denominator.
  test(
    'coverage zero stays uncolored and byte one counts in protected denominator',
    () {
      final result = score(
        [1, 1, 1, 1],
        [0, 0, 0, 0],
        protection: [255, 255, 0, 0],
        coverage: [0, 1, 255, 0],
      );
      expect(result.protectedPixels, 2);
      expect(result.protectedColoredPixels, 1);
      expect(result.protectedLeakage, .5);
      expect(score([0], [0]).protectedLeakage, isNull);
    },
  );

  // Catches micro-averaging leakage or averaging each image's already-macro score.
  test('aggregation uses per-image leakage and eligible layer-image pairs', () {
    final first = score([1, 0], [1, 0], protection: [255, 0], coverage: [1, 0]);
    final second = score(
      [1, 2, 0, 0],
      [1, 0, 0, 0],
      protection: [255, 255, 255, 0],
      coverage: [0, 0, 0, 0],
      tolerance: 0,
    );
    final aggregate = aggregateRoomQuality([first, second]);
    expect(aggregate.macroProtectedLeakage, .5);
    expect(aggregate.protectedPixels, 4);
    expect(aggregate.protectedColoredPixels, 1);
    expect(aggregate.macroIou, closeTo(2 / 3, 1e-12));
    expect(aggregate.macroBoundaryF1, closeTo(2 / 3, 1e-12));
    expect(aggregate.layers[RoomLayer.wall]!.iou, 1);
    expect(aggregate.layers[RoomLayer.ceiling]!.iou, 0);
    expect(aggregate.layers[RoomLayer.floor]!.iou, isNull);
    expect(
      () => validateRoomBaselineSuitability([second]),
      throwsFormatException,
    );
    expect(
      () => validateRoomBaselineSuitability([
        score([0], [0]),
      ]),
      throwsFormatException,
    );
    expect(
      () => validateRoomBaselineSuitability([first, second]),
      returnsNormally,
    );
  });

  test(
    'rejects shape mismatches, malformed protection, and negative tolerance',
    () {
      expect(
        () => scoreRoomQuality(
          predictedOwnership: mask([1, 0], width: 1),
          groundTruthOwnership: mask([1, 0]),
          effectiveCoverage: Uint8List(2),
          groundTruthProtection: Uint8List(2),
        ),
        throwsArgumentError,
      );
      expect(() => score([1, 0], [1, 0], coverage: [0]), throwsArgumentError);
      expect(
        () => score([1, 0], [1, 0], protection: [255]),
        throwsArgumentError,
      );
      expect(() => score([1], [1], protection: [1]), throwsArgumentError);
      expect(() => score([1], [1], tolerance: -1), throwsArgumentError);
      expect(() => aggregateRoomQuality([]), throwsArgumentError);
    },
  );
}
