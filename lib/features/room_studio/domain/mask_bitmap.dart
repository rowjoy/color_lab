import 'dart:typed_data';

import 'room_layer.dart';

/// Detached, discrete ownership. Feathered display alpha is derived separately.
final class MaskBitmap {
  MaskBitmap({
    required this.width,
    required this.height,
    required Uint8List labels,
  }) : labels = Uint8List.fromList(labels).asUnmodifiableView() {
    if (width <= 0 || height <= 0 || labels.length != width * height) {
      throw ArgumentError('Positive dimensions and matching labels required');
    }
    for (final label in this.labels) {
      if (label > RoomLayer.values.length) {
        throw ArgumentError('Ownership labels must be in 0–4');
      }
      _counts[label]++;
    }
  }

  final int width;
  final int height;
  final Uint8List labels;
  final _counts = List<int>.filled(5, 0);

  int get pixelCount => width * height;
  int count(RoomLayer layer) => _counts[layer.label];
}
