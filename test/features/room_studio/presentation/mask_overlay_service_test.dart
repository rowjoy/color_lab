import 'dart:typed_data';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/application/mask_overlay_service.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('manual overlay patterns distinguish all surfaces without changing ownership', () {
    final marks = [for (final layer in RoomLayer.values)
      [for (var y = 0; y < 13; y++) for (var x = 0; x < 13; x++) roomMaskPatternAt(layer, x, y)]];
    expect(marks.map((mark) => mark.join()).toSet(), hasLength(4));
  });

  for (final radius in [1, 2]) {
    test(
      'preview radius$radius never tints another owner or an erased pixel',
      () async {
        final labels = Uint8List.fromList([
          for (var y = 0; y < 7; y++)
            for (var x = 0; x < 9; x++) x < 5 ? 1 : (y % 5),
        ]);
        final png = await const IsolateMaskOverlayService().render(
          masks: MaskBitmap(width: 9, height: 7, labels: labels),
          layer: RoomLayer.wall,
          tint: RgbColor(17, 99, 201),
          featherRadius: radius,
        );
        final decoded = img.decodePng(png)!;
        for (var i = 0; i < labels.length; i++) {
          if (labels[i] != 1) {
            expect(
              decoded.getPixel(i % 9, i ~/ 9).a,
              0,
              reason: 'non-Wall pixel$i',
            );
          }
        }
        expect(decoded.getPixel(4, 2).a, inExclusiveRange(0, 255));
        expect(decoded.getPixel(2, 3).a, 255);
      },
    );
  }

  test(
    'worker PNG preserves tint and binomial alpha at known pixels',
    () async {
      final labels = Uint8List(49);
      for (var y = 2; y <= 4; y++) {
        for (var x = 2; x <= 4; x++) {
          labels[y * 7 + x] = RoomLayer.wall.label;
        }
      }
      labels[0] = RoomLayer.floor.label;
      final masks = MaskBitmap(width: 7, height: 7, labels: labels);
      final before = masks.labels.toList();
      final png = await IsolateMaskOverlayService().render(
        masks: masks,
        layer: RoomLayer.wall,
        tint: RgbColor(17, 99, 201),
        featherRadius: 1,
      );
      final decoded = img.decodePng(png)!;
      expect([decoded.width, decoded.height, decoded.numChannels], [7, 7, 4]);
      final center = decoded.getPixel(3, 3);
      expect([center.r, center.g, center.b, center.a], [17, 99, 201, 255]);
      expect(decoded.getPixel(0, 0).a, 0);
      expect(decoded.getPixel(1, 3).a, 0);
      expect(decoded.getPixel(2, 2).a, 143);
      expect(masks.labels, before);
    },
  );

  test(
    'non-square PNG includes only selected ownership and defaults radius2',
    () async {
      final masks = MaskBitmap(
        width: 9,
        height: 5,
        labels: Uint8List.fromList(List.generate(45, (i) => i % 9 < 5 ? 1 : 3)),
      );
      final png = await IsolateMaskOverlayService().render(
        masks: masks,
        layer: RoomLayer.wall,
        tint: RgbColor(20, 30, 40),
      );
      final decoded = img.decodePng(png)!;
      expect([decoded.width, decoded.height], [9, 5]);
      expect(decoded.getPixel(2, 2).a, 255);
      expect(decoded.getPixel(4, 2).a, 175);
      expect(decoded.getPixel(8, 2).a, 0);
      await expectLater(
        IsolateMaskOverlayService().render(
          masks: masks,
          layer: RoomLayer.wall,
          tint: RgbColor(0, 0, 0),
          featherRadius: 3,
        ),
        throwsArgumentError,
      );
    },
  );
}
