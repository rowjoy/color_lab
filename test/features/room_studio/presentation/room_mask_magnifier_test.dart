import 'package:color_lab/features/picker/domain/photo_viewport.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_magnifier.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual transform outline and magnifier share source coordinates across zoom resize and DPR', () {
    for (final image in [const Size(1600, 900), const Size(900, 1600)]) {
      for (final size in [const Size(320, 568), const Size(568, 320), const Size(840, 600)]) {
        for (final zoom in [1.0, 4.0, 8.0]) {
          for (final dpr in [1.0, 2.0, 3.0]) {
            final viewport = PhotoViewport(imageSize: image, size: size, zoom: zoom, pan: const Offset(3, 5));
            final source = Offset(image.width / 2, image.height / 2);
            final physical = viewport.sourcePositionOf(source) * dpr;
            final sampled = viewport.sourceAt(physical / dpr)!;
            expect((sampled - source).distance, lessThan(.00001));
            final sample = RoomMaskSample(viewport: viewport, source: sampled, brushFraction: .005);
            expect(sample.source, sampled);
            expect(sample.screenRadius, closeTo(sample.sourceRadius * viewport.scale, .00001));
            expect(viewport.sourceAt(const Offset(-1, 5)), isNull);
          }
        }
      }
    }
    const contain = PhotoViewport(imageSize: Size(100, 100), size: Size(400, 200));
    expect(contain.sourceAt(const Offset(5, 100)), isNull);
    expect(contain.sourceAt(const Offset(100, 0)), Offset.zero);
  });
}
