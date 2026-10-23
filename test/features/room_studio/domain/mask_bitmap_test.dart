import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts exclusive labels with zero unselected', () {
    final masks = MaskBitmap(
      width: 2,
      height: 2,
      labels: Uint8List.fromList([0, 1, 3, 4]),
    );
    expect(masks.pixelCount, 4);
    expect(masks.count(RoomLayer.wall), 1);
    expect(masks.count(RoomLayer.floor), 1);
    expect(masks.count(RoomLayer.ceiling), 0);
    expect(masks.count(RoomLayer.furniture), 1);
    expect(RoomLayer.values.map((layer) => layer.label), [1, 2, 3, 4]);
  });

  test('owns a detached immutable snapshot including buffer views', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final masks = MaskBitmap(width: 2, height: 2, labels: bytes);
    bytes[0] = 0;
    expect(masks.labels, [1, 2, 3, 4]);
    expect(masks.count(RoomLayer.wall), 1);
    expect(() => masks.labels[0] = 0, throwsUnsupportedError);
    expect(
      () => masks.labels.buffer.asUint8List()[0] = 0,
      throwsUnsupportedError,
    );
  });

  test('rejects zero/negative sizes, wrong lengths and invalid labels', () {
    for (final size in [(0, 1), (1, 0), (-1, 2), (2, -1), (2, 2)]) {
      expect(
        () => MaskBitmap(width: size.$1, height: size.$2, labels: Uint8List(1)),
        throwsArgumentError,
      );
    }
    for (final label in [5, 255]) {
      expect(
        () => MaskBitmap(
          width: 1,
          height: 1,
          labels: Uint8List.fromList([label]),
        ),
        throwsArgumentError,
      );
    }
  });
}
