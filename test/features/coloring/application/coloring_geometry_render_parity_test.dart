import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/vector_regions/application/vector_region_transform.dart';
import 'package:color_lab/core/vector_regions/domain/vector_region_geometry.dart';
import 'package:color_lab/features/coloring/application/coloring_export_service.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/domain/drawing_geometry.dart';
import 'package:color_lab/features/coloring/rendering/coloring_artwork_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A renderer using region-list order, filling holes, dropping tiny regions,
  // or applying a different transform than hit/focus/export fails these pixels.
  test(
    'paint hit focus and clean export agree through fit pan zoom and resize',
    () async {
      final drawing = _drawing();
      final colors = {
        'background': RgbColor.fromHex('#123456'),
        'foreground': RgbColor.fromHex('#9A2468'),
        'tiny': RgbColor.fromHex('#14B83F'),
      };
      var project = ColoringProject.create(
        drawingId: drawing.id,
        drawingRevision: drawing.revision,
        mode: ColoringMode.free,
      );
      for (final entry in colors.entries) {
        project = project.fill(entry.key, entry.value);
      }
      final exported = image.decodePng(
        await const VectorColoringExportService().encodePng(
          drawing,
          project,
          scale: 1,
        ),
      )!;
      expect((exported.width, exported.height), (100, 100));
      final witnesses = <({ui.Offset point, String region, List<int> rgb})>[
        (
          point: const ui.Offset(10, 10),
          region: 'background',
          rgb: [18, 52, 86],
        ),
        (
          point: const ui.Offset(30, 30),
          region: 'foreground',
          rgb: [154, 36, 104],
        ),
        // The foreground's hole exposes the lower region, never a white patch.
        (
          point: const ui.Offset(50, 50),
          region: 'background',
          rgb: [18, 52, 86],
        ),
        (point: const ui.Offset(92, 92), region: 'tiny', rgb: [20, 184, 63]),
      ];
      for (final witness in witnesses) {
        final pixel = exported.getPixel(
          witness.point.dx.toInt(),
          witness.point.dy.toInt(),
        );
        expect(
          [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), pixel.a.toInt()],
          [...witness.rgb, 255],
        );
      }

      // Expected screen points and bounds are hand-derived contain transforms,
      // so a shared but incorrect transform cannot make both sides pass.
      final scenarios =
          <
            ({
              ui.Size viewport,
              double zoom,
              ui.Offset pan,
              List<ui.Offset> points,
              ui.Rect focus,
              ui.Offset? margin,
            })
          >[
            (
              viewport: const ui.Size(200, 200),
              zoom: 1,
              pan: ui.Offset.zero,
              points: const [
                ui.Offset(20, 20),
                ui.Offset(60, 60),
                ui.Offset(100, 100),
                ui.Offset(184, 184),
              ],
              focus: const ui.Rect.fromLTRB(40, 40, 160, 160),
              margin: null,
            ),
            (
              viewport: const ui.Size(360, 240),
              zoom: 1.1,
              pan: const ui.Offset(8, 0),
              points: const [
                ui.Offset(82.4, 14.4),
                ui.Offset(135.2, 67.2),
                ui.Offset(188, 120),
                ui.Offset(298.88, 230.88),
              ],
              focus: const ui.Rect.fromLTRB(108.8, 40.8, 267.2, 199.2),
              margin: const ui.Offset(4, 120),
            ),
            (
              viewport: const ui.Size(240, 360),
              zoom: 1.1,
              pan: const ui.Offset(0, 8),
              points: const [
                ui.Offset(14.4, 82.4),
                ui.Offset(67.2, 135.2),
                ui.Offset(120, 188),
                ui.Offset(230.88, 298.88),
              ],
              focus: const ui.Rect.fromLTRB(40.8, 108.8, 199.2, 267.2),
              margin: const ui.Offset(120, 4),
            ),
            (
              viewport: const ui.Size(1024, 768),
              zoom: 1,
              pan: ui.Offset.zero,
              points: const [
                ui.Offset(204.8, 76.8),
                ui.Offset(358.4, 230.4),
                ui.Offset(512, 384),
                ui.Offset(834.56, 706.56),
              ],
              focus: const ui.Rect.fromLTRB(281.6, 153.6, 742.4, 614.4),
              margin: const ui.Offset(4, 384),
            ),
          ];
      for (final scenario in scenarios) {
        final transform = VectorRegionTransform.fit(
          intrinsicSize: drawing.artwork.intrinsicSize,
          viewport: scenario.viewport,
          zoom: scenario.zoom,
          pan: scenario.pan,
        );
        final raster = await _render(
          drawing,
          project.assignments,
          transform,
          scenario.viewport,
        );
        for (var index = 0; index < witnesses.length; index++) {
          final witness = witnesses[index];
          final point = scenario.points[index];
          expect(
            (transform.artworkToScreen(witness.point) - point).distance,
            lessThan(0.00001),
          );
          expect(
            (transform.screenToArtwork(point) - witness.point).distance,
            lessThan(0.00001),
          );
          expect(
            DrawingGeometry.hitTest(drawing, point, transform)?.id,
            witness.region,
          );
          expect(_rgba(raster, scenario.viewport.width.toInt(), point), [
            ...witness.rgb,
            255,
          ]);
        }
        final focus = transform.screenBounds(
          DrawingGeometry.pathFor(drawing, 'foreground').getBounds(),
        );
        expect(focus.left, closeTo(scenario.focus.left, 0.00001));
        expect(focus.top, closeTo(scenario.focus.top, 0.00001));
        expect(focus.right, closeTo(scenario.focus.right, 0.00001));
        expect(focus.bottom, closeTo(scenario.focus.bottom, 0.00001));
        expect(
          DrawingGeometry.hitTest(
            drawing,
            transform.artworkToScreen(const ui.Offset(-2, 50)),
            transform,
          ),
          isNull,
        );
        if (scenario.margin case final margin?) {
          expect(_rgba(raster, scenario.viewport.width.toInt(), margin), [
            255,
            255,
            255,
            255,
          ]);
          expect(DrawingGeometry.hitTest(drawing, margin, transform), isNull);
        }
      }
    },
  );
}

Future<Uint8List> _render(
  DrawingDefinition drawing,
  Map<String, RgbColor> assignments,
  VectorRegionTransform transform,
  ui.Size viewport,
) async {
  final recorder = ui.PictureRecorder();
  ColoringArtworkRenderer.draw(
    ui.Canvas(recorder),
    drawing,
    assignments,
    transform,
  );
  final picture = recorder.endRecording();
  final raster = await picture.toImage(
    viewport.width.toInt(),
    viewport.height.toInt(),
  );
  try {
    return (await raster.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
  } finally {
    raster.dispose();
    picture.dispose();
  }
}

List<int> _rgba(Uint8List bytes, int width, ui.Offset point) {
  final offset = (point.dy.floor() * width + point.dx.floor()) * 4;
  return bytes.sublist(offset, offset + 4);
}

DrawingDefinition _drawing() {
  VectorRegionDefinition region(
    String id,
    int order,
    List<List<Object>> commands,
  ) => VectorRegionDefinition(
    id: id,
    labelKey: 'coloring$id',
    groupId: 'drawing',
    fillable: true,
    paintOrder: order,
    geometry: VectorRegionGeometry(
      parts: [VectorRegionPart(slot: order, commands: commands)],
    ),
  );
  final background = region('background', 0, const [
    ['M', 0, 0],
    ['L', 100, 0],
    ['L', 100, 100],
    ['L', 0, 100],
    ['Z'],
  ]);
  final foreground = region('foreground', 1, const [
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
  ]);
  final tiny = region('tiny', 2, const [
    ['M', 90, 90],
    ['L', 94, 90],
    ['L', 94, 94],
    ['L', 90, 94],
    ['Z'],
  ]);
  return DrawingDefinition(
    id: 'parity_fixture',
    revision: 1,
    title: 'Parity',
    description: 'Overlap, hole and tiny region.',
    category: DrawingCategory.rooms,
    difficulty: DrawingDifficulty.hard,
    artwork: VectorArtworkDefinition(
      id: 'parity_fixture',
      revision: 1,
      intrinsicSize: const ui.Size(100, 100),
      // Deliberately differs from paint order to detect list-order painting.
      regions: [tiny, background, foreground],
    ),
    slots: [
      DrawingColorSlot(
        id: 'background',
        label: 'Background',
        color: RgbColor.fromHex('#123456'),
      ),
      DrawingColorSlot(
        id: 'foreground',
        label: 'Foreground',
        color: RgbColor.fromHex('#9A2468'),
      ),
      DrawingColorSlot(
        id: 'tiny',
        label: 'Tiny',
        color: RgbColor.fromHex('#14B83F'),
      ),
    ],
    regionRules: {
      for (final id in ['background', 'foreground', 'tiny'])
        id: DrawingRegionRule(regionId: id, targetSlotId: id, required: true),
    },
  );
}
