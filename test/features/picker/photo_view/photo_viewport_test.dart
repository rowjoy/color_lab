import 'package:color_lab/features/picker/domain/photo_viewport.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contain fitting rejects letterbox and maps real image pixels', () {
    const viewport = PhotoViewport(
      imageSize: Size(400, 200),
      size: Size(300, 300),
    );
    expect(viewport.normalizedAt(const Offset(150, 20)), isNull);
    expect(viewport.normalizedAt(const Offset(75, 150)), const Offset(.25, .5));
    expect(viewport.imageRect, const Rect.fromLTWH(0, 75, 300, 150));
  });

  test('zoom and pan are inverted before normalized sampling', () {
    const viewport = PhotoViewport(
      imageSize: Size(400, 200),
      size: Size(300, 300),
      zoom: 2,
      pan: Offset(30, -20),
    );
    expect(viewport.normalizedAt(const Offset(30, 130)), const Offset(.25, .5));
    expect(viewport.positionOf(const Offset(.25, .5)), const Offset(30, 130));
    expect(viewport.normalizedAt(const Offset(150, 295)), isNull);
  });
}
