import 'dart:ui';
import 'package:color_lab/core/vector_regions/application/vector_region_transform.dart';
import 'package:color_lab/core/vector_regions/rendering/vector_region_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures.dart';

// Mutation: renderer ignores paint order, transform, shared paths or group color.
void main() {
  testWidgets(
    'raster uses group colors, ordered cached paths and contain transform',
    (tester) async {
      final json = artworkJson();
      json['regions'] = [
        regionJson('front', 1, commands: rectangle(50, 20, 60, 80)),
        regionJson('back', 0),
      ];
      final art = codec.decode(encodeFixture(json));
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      VectorRegionRenderer.draw(
        canvas,
        art,
        VectorRegionTransform.fit(
          intrinsicSize: art.intrinsicSize,
          viewport: const Size(600, 600),
        ),
        colorFor: (region) => region.id == 'back'
            ? const Color(0xFFFF0000)
            : const Color(0xFF0000FF),
      );
      final picture = recorder.endRecording();
      final pixels = await tester.runAsync(() async {
        final image = await picture.toImage(600, 600);
        try {
          return await image.toByteData();
        } finally {
          image.dispose();
        }
      });
      picture.dispose();
      List<int> rgb(int x, int y) => pixels!.buffer.asUint8List().sublist(
        (y * 600 + x) * 4,
        (y * 600 + x) * 4 + 4,
      );
      expect(rgb(10, 120), [255, 0, 0, 255]);
      expect(rgb(30, 120), [0, 0, 255, 255]);
      expect(rgb(10, 20), [0, 0, 0, 0]);
      expect(
        art.paintEntries.last.path,
        same(art.regions.first.geometry.parts.single.toPath()),
      );
    },
  );
}
