import 'dart:ui';
import '../domain/vector_region_geometry.dart';
import '../application/vector_region_transform.dart';

abstract final class VectorRegionRenderer {
  /// Slots preserve authored occlusion without storing fill geometry in decoration.
  static void draw(
    Canvas canvas,
    VectorArtworkDefinition artwork,
    VectorRegionTransform transform, {
    required Color Function(VectorRegionDefinition) colorFor,
    void Function(Canvas canvas, int slot)? decoration,
  }) {
    canvas.save();
    transform.apply(canvas);
    canvas.clipRect(Offset.zero & artwork.intrinsicSize);
    decoration?.call(canvas, 0);
    final paint = Paint();
    for (final entry in artwork.paintEntries) {
      if (entry.region.fillable) {
        canvas.drawPath(entry.path, paint..color = colorFor(entry.region));
      }
      if (entry.part.whiteOverlayOpacity > 0) {
        canvas.drawPath(
          entry.path,
          Paint()
            ..color = Color.fromRGBO(
              255,
              255,
              255,
              entry.part.whiteOverlayOpacity,
            ),
        );
      }
      if (entry.part.blackOverlayOpacity > 0) {
        canvas.drawPath(
          entry.path,
          Paint()
            // Preserve the SVG compiler's original truncated 8-bit opacity.
            ..color = Color.fromARGB(
              (entry.part.blackOverlayOpacity * 255).toInt(),
              0,
              0,
              0,
            ),
        );
      }
      decoration?.call(canvas, entry.slot + 1);
    }
    canvas.restore();
  }
}
