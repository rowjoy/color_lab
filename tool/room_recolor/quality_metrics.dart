import 'dart:math' as math;
import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';

/// Counts are per class and image. Recall matches are deliberately independent
/// of precision matches: boundary matching does not consume opposite pixels.
final class RoomLayerQuality {
  const RoomLayerQuality({
    required this.intersectionPixels,
    required this.unionPixels,
    required this.predictedBoundaryPixels,
    required this.groundTruthBoundaryPixels,
    required this.boundaryTruePositive,
    required this.boundaryRecallMatches,
  });
  final int intersectionPixels;
  final int unionPixels;
  final int predictedBoundaryPixels;
  final int groundTruthBoundaryPixels;
  final int boundaryTruePositive;
  final int boundaryRecallMatches;
  int get boundaryFalsePositive =>
      predictedBoundaryPixels - boundaryTruePositive;
  int get boundaryFalseNegative =>
      groundTruthBoundaryPixels - boundaryRecallMatches;
  double? get iou => unionPixels == 0 ? null : intersectionPixels / unionPixels;
  double? get boundaryPrecision => predictedBoundaryPixels == 0
      ? null
      : boundaryTruePositive / predictedBoundaryPixels;
  double? get boundaryRecall => groundTruthBoundaryPixels == 0
      ? null
      : boundaryRecallMatches / groundTruthBoundaryPixels;
  double? get boundaryF1 {
    if (unionPixels == 0) return null;
    final precision = boundaryPrecision ?? 0;
    final recall = boundaryRecall ?? 0;
    return precision + recall == 0
        ? 0
        : 2 * precision * recall / (precision + recall);
  }
}

final class RoomQualityMetrics {
  RoomQualityMetrics._(
    Map<RoomLayer, RoomLayerQuality> layers,
    this.protectedPixels,
    this.protectedColoredPixels,
  ) : layers = Map.unmodifiable(layers);
  final Map<RoomLayer, RoomLayerQuality> layers;
  final int protectedPixels;
  final int protectedColoredPixels;
  double? get protectedLeakage =>
      protectedPixels == 0 ? null : protectedColoredPixels / protectedPixels;
  double? get macroIou => _mean(layers.values.map((v) => v.iou));
  double? get macroBoundaryF1 => _mean(layers.values.map((v) => v.boundaryF1));
}

final class RoomLayerMacroQuality {
  const RoomLayerMacroQuality(this.iou, this.boundaryF1);
  final double? iou;
  final double? boundaryF1;
}

final class RoomQualityAggregate {
  RoomQualityAggregate._(List<RoomQualityMetrics> images)
    : layers = Map.unmodifiable({
        for (final layer in RoomLayer.values)
          layer: RoomLayerMacroQuality(
            _mean(images.map((i) => i.layers[layer]!.iou)),
            _mean(images.map((i) => i.layers[layer]!.boundaryF1)),
          ),
      }),
      macroIou = _mean(images.expand((i) => i.layers.values.map((l) => l.iou))),
      macroBoundaryF1 = _mean(
        images.expand((i) => i.layers.values.map((l) => l.boundaryF1)),
      ),
      macroProtectedLeakage = _mean(images.map((i) => i.protectedLeakage)),
      protectedPixels = images.fold(0, (sum, i) => sum + i.protectedPixels),
      protectedColoredPixels = images.fold(
        0,
        (sum, i) => sum + i.protectedColoredPixels,
      );
  final Map<RoomLayer, RoomLayerMacroQuality> layers;
  final double? macroIou;
  final double? macroBoundaryF1;
  final double? macroProtectedLeakage;
  final int protectedPixels;
  final int protectedColoredPixels;
}

RoomQualityAggregate aggregateRoomQuality(Iterable<RoomQualityMetrics> images) {
  final snapshot = images.toList();
  if (snapshot.isEmpty) {
    throw ArgumentError('At least one scored image required');
  }
  return RoomQualityAggregate._(snapshot);
}

/// Run on the frozen MOSAIC baseline before any candidate tuning. The benchmark
/// loader cannot make this judgment: baseline coverage is separate evidence.
void validateRoomBaselineSuitability(Iterable<RoomQualityMetrics> baseline) {
  final images = baseline.toList();
  if (images.isEmpty ||
      images.any((i) => i.protectedPixels == 0) ||
      images.every((i) => i.protectedColoredPixels == 0)) {
    throw const FormatException(
      'Baseline requires protected GT in every image and nonzero aggregate leakage',
    );
  }
}

RoomQualityMetrics scoreRoomQuality({
  required MaskBitmap predictedOwnership,
  required Uint8List effectiveCoverage,
  required MaskBitmap groundTruthOwnership,
  required Uint8List groundTruthProtection,
  int boundaryTolerancePixels = 5,
}) {
  final count = groundTruthOwnership.pixelCount;
  if (predictedOwnership.width != groundTruthOwnership.width ||
      predictedOwnership.height != groundTruthOwnership.height ||
      effectiveCoverage.length != count ||
      groundTruthProtection.length != count ||
      boundaryTolerancePixels < 0 ||
      groundTruthProtection.any((v) => v != 0 && v != 255)) {
    throw ArgumentError(
      'Aligned dimensions, binary protection and nonnegative tolerance required',
    );
  }
  var protected = 0;
  var colored = 0;
  for (var i = 0; i < count; i++) {
    if (groundTruthProtection[i] == 255) {
      protected++;
      if (effectiveCoverage[i] >= 1) colored++;
    }
  }
  final layers = <RoomLayer, RoomLayerQuality>{};
  for (final layer in RoomLayer.values) {
    var intersection = 0;
    var union = 0;
    for (var i = 0; i < count; i++) {
      final p = predictedOwnership.labels[i] == layer.label;
      final g = groundTruthOwnership.labels[i] == layer.label;
      if (p && g) intersection++;
      if (p || g) union++;
    }
    final pBoundary = _boundary(predictedOwnership, layer.label);
    final gBoundary = _boundary(groundTruthOwnership, layer.label);
    layers[layer] = RoomLayerQuality(
      intersectionPixels: intersection,
      unionPixels: union,
      predictedBoundaryPixels: pBoundary.where((b) => b).length,
      groundTruthBoundaryPixels: gBoundary.where((b) => b).length,
      boundaryTruePositive: _matches(
        pBoundary,
        gBoundary,
        groundTruthOwnership.width,
        groundTruthOwnership.height,
        boundaryTolerancePixels,
      ),
      boundaryRecallMatches: _matches(
        gBoundary,
        pBoundary,
        groundTruthOwnership.width,
        groundTruthOwnership.height,
        boundaryTolerancePixels,
      ),
    );
  }
  return RoomQualityMetrics._(layers, protected, colored);
}

List<bool> _boundary(MaskBitmap mask, int label) {
  final boundary = List.filled(mask.pixelCount, false);
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      final index = y * mask.width + x;
      if (mask.labels[index] != label) continue;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 ||
              ny < 0 ||
              nx >= mask.width ||
              ny >= mask.height ||
              mask.labels[ny * mask.width + nx] != label) {
            boundary[index] = true;
          }
        }
      }
    }
  }
  return boundary;
}

int _matches(
  List<bool> from,
  List<bool> to,
  int width,
  int height,
  int tolerance,
) {
  var matches = 0;
  for (var i = 0; i < from.length; i++) {
    if (!from[i]) continue;
    final x = i % width;
    final y = i ~/ width;
    var found = false;
    for (
      var ny = math.max(0, y - tolerance);
      ny <= math.min(height - 1, y + tolerance) && !found;
      ny++
    ) {
      for (
        var nx = math.max(0, x - tolerance);
        nx <= math.min(width - 1, x + tolerance);
        nx++
      ) {
        if ((nx - x) * (nx - x) + (ny - y) * (ny - y) <=
                tolerance * tolerance &&
            to[ny * width + nx]) {
          found = true;
          break;
        }
      }
    }
    if (found) matches++;
  }
  return matches;
}

double? _mean(Iterable<double?> values) {
  var sum = 0.0;
  var count = 0;
  for (final value in values) {
    if (value == null) continue;
    sum += value;
    count++;
  }
  return count == 0 ? null : sum / count;
}
