import 'dart:typed_data';

import 'mask_bitmap.dart';
import 'room_project.dart' show RoomProjectLimits;

/// Explicit user choices, independent of both the AI baseline and ownership.
/// 0 is untouched; 1 is unowned; 2–5 select RoomLayer indices 0–3.
final class MaskIntentBitmap {
  factory MaskIntentBitmap.untouched({
    required int width,
    required int height,
  }) {
    _dimensions(width, height);
    return MaskIntentBitmap._(width, height, Uint8List(width * height));
  }

  factory MaskIntentBitmap.fromBytes({
    required int width,
    required int height,
    required Uint8List bytes,
  }) {
    _dimensions(width, height);
    if (bytes.length != width * height || bytes.any((value) => value > 5)) {
      throw ArgumentError('Aligned intent bytes in 0–5 are required.');
    }
    return MaskIntentBitmap._(width, height, Uint8List.fromList(bytes));
  }

  MaskIntentBitmap._(this.width, this.height, Uint8List bytes)
    : bytes = bytes.asUnmodifiableView();

  final int width;
  final int height;
  final Uint8List bytes;

  static void _dimensions(int width, int height) {
    // Bound each axis before multiplying, including on fixed-width runtimes.
    if (width < 1 ||
        height < 1 ||
        width > RoomProjectLimits.maxDimension ||
        height > RoomProjectLimits.maxDimension ||
        width * height > RoomProjectLimits.maxPixels) {
      throw ArgumentError('Positive bounded intent dimensions are required.');
    }
  }

  int intentAt(int index) => bytes[index];

  MaskIntentBitmap apply(Uint32List indices, Uint8List intents) {
    if (indices.length != intents.length) {
      throw ArgumentError('Intent updates must have equal lengths.');
    }
    var previous = -1;
    for (var i = 0; i < indices.length; i++) {
      final index = indices[i];
      if (index <= previous || index >= bytes.length || intents[i] > 5) {
        throw ArgumentError('Intent updates must be sorted, unique and valid.');
      }
      previous = index;
    }
    final updated = Uint8List.fromList(bytes);
    for (var i = 0; i < indices.length; i++) {
      updated[indices[i]] = intents[i];
    }
    return MaskIntentBitmap._(width, height, updated);
  }
}

MaskBitmap mergeAiWithIntent({
  required MaskBitmap refreshedAi,
  required MaskIntentBitmap intent,
}) {
  if (refreshedAi.width != intent.width ||
      refreshedAi.height != intent.height) {
    throw ArgumentError('AI and intent dimensions must match.');
  }
  final labels = Uint8List.fromList(refreshedAi.labels);
  for (var i = 0; i < labels.length; i++) {
    final value = intent.intentAt(i);
    if (value != 0) labels[i] = value - 1;
  }
  return MaskBitmap(
    width: refreshedAi.width,
    height: refreshedAi.height,
    labels: labels,
  );
}
