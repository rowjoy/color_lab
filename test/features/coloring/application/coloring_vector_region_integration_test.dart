import 'dart:ui';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/vector_regions/application/vector_region_transform.dart';
import 'package:color_lab/core/vector_regions/domain/vector_region_geometry.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/domain/drawing_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared transform keeps overlap, hole, and tiny-region hits stable', () {
    final drawing = _fixture();
    for (final scenario in <({Size viewport, double zoom, Offset pan})>[
      (viewport: const Size(300, 200), zoom: 1, pan: Offset.zero),
      (viewport: const Size(200, 400), zoom: 2, pan: const Offset(17, -23)),
      (viewport: const Size(844, 390), zoom: 3.5, pan: const Offset(-31, 42)),
    ]) {
      final transform = VectorRegionTransform.fit(
        intrinsicSize: drawing.artwork.intrinsicSize,
        viewport: scenario.viewport,
        zoom: scenario.zoom,
        pan: scenario.pan,
      );

      String? hit(Offset artworkPoint) => DrawingGeometry.hitTest(
        drawing,
        transform.artworkToScreen(artworkPoint),
        transform,
      )?.id;

      expect(hit(const Offset(10, 10)), 'background');
      expect(hit(const Offset(30, 30)), 'foreground');
      expect(hit(const Offset(50, 50)), 'background');
      expect(hit(const Offset(92, 92)), 'tiny');
      expect(
        DrawingGeometry.hitTest(
          drawing,
          transform.artworkToScreen(const Offset(-5, -5)),
          transform,
        ),
        isNull,
      );
    }
  });
}

DrawingDefinition _fixture() {
  VectorRegionDefinition region({
    required String id,
    required int order,
    required List<List<Object>> commands,
  }) => VectorRegionDefinition(
    id: id,
    labelKey: 'coloring${id[0].toUpperCase()}${id.substring(1)}',
    groupId: 'drawing',
    fillable: true,
    paintOrder: order,
    geometry: VectorRegionGeometry(
      parts: [VectorRegionPart(slot: order, commands: commands)],
    ),
  );

  final regions = [
    region(
      id: 'background',
      order: 0,
      commands: const [
        ['M', 0, 0],
        ['L', 100, 0],
        ['L', 100, 100],
        ['L', 0, 100],
        ['Z'],
      ],
    ),
    region(
      id: 'foreground',
      order: 1,
      commands: const [
        ['M', 20, 20],
        ['L', 80, 20],
        ['L', 80, 80],
        ['L', 20, 80],
        ['Z'],
        ['M', 40, 40],
        ['L', 40, 60],
        ['L', 60, 60],
        ['L', 60, 40],
        ['Z'],
      ],
    ),
    region(
      id: 'tiny',
      order: 2,
      commands: const [
        ['M', 90, 90],
        ['L', 94, 90],
        ['L', 94, 94],
        ['L', 90, 94],
        ['Z'],
      ],
    ),
  ];
  final artwork = VectorArtworkDefinition(
    id: 'geometry_fixture',
    revision: 1,
    intrinsicSize: const Size(100, 100),
    regions: regions,
  );
  final slots = [
    DrawingColorSlot(
      id: 'background',
      label: 'Background',
      color: RgbColor(1, 2, 3),
    ),
    DrawingColorSlot(
      id: 'foreground',
      label: 'Foreground',
      color: RgbColor(4, 5, 6),
    ),
    DrawingColorSlot(id: 'tiny', label: 'Tiny', color: RgbColor(7, 8, 9)),
  ];
  return DrawingDefinition(
    id: artwork.id,
    revision: artwork.revision,
    title: 'Geometry fixture',
    description: 'Shared geometry behavior fixture.',
    category: DrawingCategory.rooms,
    difficulty: DrawingDifficulty.hard,
    artwork: artwork,
    slots: slots,
    regionRules: {
      for (final region in regions)
        region.id: DrawingRegionRule(
          regionId: region.id,
          targetSlotId: region.id,
          required: true,
        ),
    },
  );
}
