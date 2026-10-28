import 'dart:ui';

import '../../../core/vector_regions/application/vector_region_hit_tester.dart';
import '../../../core/vector_regions/application/vector_region_transform.dart';
import '../../../core/vector_regions/domain/vector_region_geometry.dart';
import 'drawing_definition.dart';

/// Thin feature adapter: all geometry remains owned by the shared contract.
abstract final class DrawingGeometry {
  static Path pathFor(DrawingDefinition drawing, String regionId) => drawing
      .artwork
      .regions
      .firstWhere((region) => region.id == regionId)
      .geometry
      .toPath();

  static VectorRegionDefinition? hitTest(
    DrawingDefinition drawing,
    Offset screenPoint,
    VectorRegionTransform transform,
  ) => hitTestVectorRegion(drawing.artwork, screenPoint, transform);
}
