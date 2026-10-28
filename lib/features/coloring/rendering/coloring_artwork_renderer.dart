import 'dart:ui';

import '../../../core/color/color_models.dart';
import '../../../core/vector_regions/application/vector_region_transform.dart';
import '../../../core/vector_regions/rendering/vector_region_renderer.dart';
import '../domain/drawing_definition.dart';

/// Canonical artwork pass shared by workspace, thumbnails, and clean export.
abstract final class ColoringArtworkRenderer {
  static const background = Color(0xFFFFFFFF);
  static const unassigned = Color(0xFFECEFF1);
  static const outline = Color(0xFF263238);

  static void draw(
    Canvas canvas,
    DrawingDefinition definition,
    Map<String, RgbColor> assignments,
    VectorRegionTransform transform,
  ) {
    canvas.drawColor(background, BlendMode.src);
    final entriesAfterSlot = {
      for (final entry in definition.artwork.paintEntries)
        entry.slot + 1: entry,
    };
    final displayScale = (transform.scaleX + transform.scaleY) / 2;
    VectorRegionRenderer.draw(
      canvas,
      definition.artwork,
      transform,
      colorFor: (region) {
        final color = assignments[region.id];
        return color == null
            ? unassigned
            : Color.fromARGB(255, color.red, color.green, color.blue);
      },
      decoration: (canvas, slot) {
        final entry = entriesAfterSlot[slot];
        if (entry == null) return;
        canvas.drawPath(
          entry.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 / displayScale
            ..color = outline,
        );
      },
    );
  }
}
