import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/room_layer.dart';

/// Compares independently annotated raw labels, never coverage-as-confidence.
/// Truth255 is void. Partial/missing-class annotations cannot pass the95% gate.
Map<String, Object?> evaluateRoomMaskQuality({
  required Uint8List predicted,
  required Uint8List truth,
  required int width,
  required int height,
}) {
  if (width <= 0 ||
      height <= 0 ||
      predicted.length != width * height ||
      truth.length != width * height) {
    throw ArgumentError('Positive matching mask dimensions required');
  }
  final truthCounts = List<int>.filled(5, 0);
  final predictedCounts = List<int>.filled(5, 0);
  final intersections = List<int>.filled(5, 0);
  var ignored = 0;
  var correct = 0;
  for (var i = 0; i < truth.length; i++) {
    final actual = truth[i], guess = predicted[i];
    if (guess > 4 || (actual > 4 && actual != 255)) {
      throw ArgumentError('Prediction0..4 and truth0..4/255 required');
    }
    if (actual == 255) {
      ignored++;
      continue;
    }
    truthCounts[actual]++;
    predictedCounts[guess]++;
    if (actual == guess) {
      intersections[actual]++;
      correct++;
    }
  }
  final layers = <String, Object?>{};
  final ious = <double>[];
  var meetsTarget = ignored == 0;
  for (final layer in RoomLayer.values) {
    final id = layer.label;
    final actual = truthCounts[id], guess = predictedCounts[id];
    final intersection = intersections[id];
    final union = actual + guess - intersection;
    final iou = union == 0 ? null : intersection / union;
    if (iou != null) ious.add(iou);
    if (actual == 0 || iou == null || iou < .95) meetsTarget = false;
    layers[layer.name] = {
      'truthPixels': actual,
      'predictedPixels': guess,
      'intersectionPixels': intersection,
      'unionPixels': union,
      'iou': iou,
      'precision': guess == 0 ? null : intersection / guess,
      'recall': actual == 0 ? null : intersection / actual,
      'dice': actual + guess == 0 ? null : 2 * intersection / (actual + guess),
    };
  }
  final annotated = truth.length - ignored;
  return {
    'width': width,
    'height': height,
    'annotatedPixels': annotated,
    'ignoredPixels': ignored,
    'pixelAccuracy': annotated == 0 ? null : correct / annotated,
    'meanIoU': ious.isEmpty ? null : ious.reduce((a, b) => a + b) / ious.length,
    'layers': layers,
    'meets95PerLayer': meetsTarget,
    'modelWideAccuracyEstablished': false,
    'limitation':
        'Only the supplied annotation is scored. Independent, representative dense labels are required to validate model-wide quality.',
  };
}
