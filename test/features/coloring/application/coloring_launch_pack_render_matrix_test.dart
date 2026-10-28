import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/vector_regions/application/vector_region_transform.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/domain/drawing_geometry.dart';
import 'package:color_lab/features/coloring/rendering/coloring_artwork_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Dropped assignments, invisible required regions, stale render caches and
  // paint/hit disagreement must fail on real catalog pixels at both sizes.
  test(
    'all 12 drawings render empty partial complete Guided and arbitrary Free at compact and tablet sizes',
    () async {
      final drawings = await AssetDrawingCatalogLoader().load();
      expect(drawings, hasLength(12));
      const viewports = [ui.Size(320, 240), ui.Size(1024, 768)];
      const stateNames = [
        'Empty Guided',
        'Partial Guided',
        'Complete Guided',
        'Arbitrary Free',
      ];
      final sheet = image.Image(width: 1920, height: 2550, numChannels: 3);
      image.fill(sheet, color: image.ColorRgb8(255, 255, 255));
      for (var column = 0; column < 8; column++) {
        image.drawString(
          sheet,
          '${column < 4 ? 'Compact' : 'Tablet'}: ${stateNames[column % 4]}',
          font: image.arial14,
          x: column * 240 + 4,
          y: 6,
          color: image.ColorRgb8(0, 0, 0),
        );
      }

      var renderCount = 0;
      for (
        var drawingIndex = 0;
        drawingIndex < drawings.length;
        drawingIndex++
      ) {
        final drawing = drawings[drawingIndex];
        final states = _states(drawing);
        image.drawString(
          sheet,
          drawing.id,
          font: image.arial14,
          x: 4,
          y: 30 + drawingIndex * 210,
          color: image.ColorRgb8(0, 0, 0),
        );
        for (var sizeIndex = 0; sizeIndex < viewports.length; sizeIndex++) {
          final viewport = viewports[sizeIndex];
          final transform = VectorRegionTransform.fit(
            intrinsicSize: drawing.artwork.intrinsicSize,
            viewport: viewport,
          );
          for (var stateIndex = 0; stateIndex < states.length; stateIndex++) {
            final project = states[stateIndex];
            final context =
                '${drawing.id}, ${viewport.width}x${viewport.height}, ${stateNames[stateIndex]}';
            final width = viewport.width.toInt();
            final height = viewport.height.toInt();
            final pixels = await _render(
              drawing,
              project,
              transform,
              width,
              height,
            );
            final counts = <int, int>{};
            final witnesses = <int, ui.Offset>{};
            var opaque = true;
            for (var offset = 0; offset < pixels.length; offset += 4) {
              final rgb =
                  (pixels[offset] << 16) |
                  (pixels[offset + 1] << 8) |
                  pixels[offset + 2];
              counts.update(rgb, (count) => count + 1, ifAbsent: () => 1);
              if (pixels[offset + 3] != 255) opaque = false;
              // Keep one pixel per visible fill. Exact interior colors distinguish
              // each Free region, even where authored slots are shared.
              witnesses.putIfAbsent(
                rgb,
                () => ui.Offset(
                  (offset ~/ 4 % width) + 0.5,
                  (offset ~/ 4 ~/ width) + 0.5,
                ),
              );
            }
            expect(opaque, isTrue, reason: '$context opaque canvas');
            expect(
              counts[0x263238] ?? 0,
              greaterThan(0),
              reason: '$context outlines',
            );
            if (stateIndex < 2) {
              expect(
                counts[0xECEFF1] ?? 0,
                greaterThan(0),
                reason: '$context unfilled regions',
              );
            }
            if (stateIndex == 2) {
              expect(project.completed, isTrue);
              expect(
                project.guidedFilledRegionIds,
                hasLength(drawing.artwork.regions.length),
              );
            }
            for (final color in project.assignments.values) {
              expect(
                counts[_rgb(color)] ?? 0,
                greaterThan(0),
                reason: '$context ${color.hex} visible',
              );
            }
            if (stateIndex == 3) {
              expect(project.mode, ColoringMode.free);
              expect(project.guidedFilledRegionIds, isEmpty);
              for (final entry in project.assignments.entries) {
                expect(
                  DrawingGeometry.hitTest(
                    drawing,
                    witnesses[_rgb(entry.value)]!,
                    transform,
                  )?.id,
                  entry.key,
                  reason: '$context visible region must be reachable',
                );
              }
            }

            // Explicitly requested review artifact. Assertions depend solely on
            // rendered pixels above, never on the contact sheet or its contents.
            final decoded = image.Image.fromBytes(
              width: width,
              height: height,
              bytes: pixels.buffer,
              numChannels: 4,
              order: image.ChannelOrder.rgba,
            );
            image.compositeImage(
              sheet,
              image.copyResize(decoded, width: 240, height: 180),
              dstX: (sizeIndex * 4 + stateIndex) * 240,
              dstY: 54 + drawingIndex * 210,
            );
            renderCount++;
          }
        }
      }
      expect(renderCount, 96);
      await File(
        '/tmp/plan07-coloring-render-matrix.png',
      ).writeAsBytes(image.encodePng(sheet));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

List<ColoringProject> _states(DrawingDefinition drawing) {
  final empty = ColoringProject.create(
    drawingId: drawing.id,
    drawingRevision: drawing.revision,
    mode: ColoringMode.guided,
  );
  var partial = empty;
  var complete = empty;
  var free = ColoringProject.create(
    drawingId: drawing.id,
    drawingRevision: drawing.revision,
    mode: ColoringMode.free,
  );
  final arbitrary = [
    '#1274A9',
    '#A62B73',
    '#6A8F21',
    '#D95826',
    '#5547BB',
  ].map(RgbColor.fromHex).toList();
  for (var index = 0; index < drawing.artwork.regions.length; index++) {
    final id = drawing.artwork.regions[index].id;
    final target = drawing
        .slotById(drawing.regionRules[id]!.targetSlotId!)
        .color;
    complete = complete.fill(id, target, guided: true);
    if (index < drawing.artwork.regions.length ~/ 2) {
      partial = partial.fill(id, target, guided: true);
    }
    free = free.fill(id, arbitrary[index]);
  }
  return [empty, partial, complete.copyWith(completed: true), free];
}

int _rgb(RgbColor color) => (color.red << 16) | (color.green << 8) | color.blue;

Future<Uint8List> _render(
  DrawingDefinition drawing,
  ColoringProject project,
  VectorRegionTransform transform,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  ColoringArtworkRenderer.draw(
    ui.Canvas(recorder),
    drawing,
    project.assignments,
    transform,
  );
  final picture = recorder.endRecording();
  final raster = await picture.toImage(width, height);
  try {
    return (await raster.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
  } finally {
    raster.dispose();
    picture.dispose();
  }
}
