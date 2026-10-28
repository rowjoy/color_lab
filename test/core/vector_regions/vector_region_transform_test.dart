import 'dart:ui';
import 'package:color_lab/core/vector_regions/application/vector_region_transform.dart';
import 'package:flutter_test/flutter_test.dart';

// Mutation: omitting contain offsets, pan/zoom or using a stale viewport.
void main() {
  test('contain letterboxing, zoom, pan and resized round trip', () {
    final fit = VectorRegionTransform.fit(
      intrinsicSize: const Size(1200, 800),
      viewport: const Size(400, 400),
    );
    expect(fit.artworkToScreen(Offset.zero).dx, closeTo(0, .001));
    expect(fit.artworkToScreen(Offset.zero).dy, closeTo(66.6667, .001));
    expect(
      (fit.screenToArtwork(const Offset(200, 200)) - const Offset(600, 400))
          .distance,
      lessThan(.5),
    );
    expect(
      fit.screenBounds(const Rect.fromLTWH(0, 0, 1200, 800)).height,
      closeTo(266.6667, .001),
    );
    for (final viewport in [const Size(360, 640), const Size(1024, 768)]) {
      final transform = VectorRegionTransform.fit(
        intrinsicSize: const Size(1200, 800),
        viewport: viewport,
        zoom: 2.3,
        pan: const Offset(37, -24),
      );
      final center = viewport.center(Offset.zero) + const Offset(37, -24);
      expect(
        (transform.artworkToScreen(const Offset(600, 400)) - center).distance,
        lessThan(.5),
      );
      for (final point in [
        Offset.zero,
        const Offset(601, 422),
        const Offset(1200, 800),
      ]) {
        final screen = transform.artworkToScreen(point);
        expect(
          (transform.artworkToScreen(transform.screenToArtwork(screen)) -
                  screen)
              .distance,
          lessThan(.5),
        );
      }
    }
  });
  test('rejects invalid transform dimensions and zoom', () {
    expect(
      () => VectorRegionTransform.fit(
        intrinsicSize: Size.zero,
        viewport: const Size(20, 20),
      ),
      throwsArgumentError,
    );
    expect(
      () => VectorRegionTransform.fit(
        intrinsicSize: const Size(1200, 800),
        viewport: const Size(20, 20),
        zoom: 0,
      ),
      throwsArgumentError,
    );
  });
}
