import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/coloring/application/coloring_export_service.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/room_studio/application/room_export_metadata_verifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports clean intrinsic artwork pixels without workspace UI', () async {
    final drawing = await AssetDrawingCatalogLoader().loadById(
      'fruit_red_apple',
    );
    var project = ColoringProject.create(
      drawingId: drawing.id,
      drawingRevision: drawing.revision,
      mode: ColoringMode.free,
    );
    for (final region in drawing.artwork.regions) {
      final rule = drawing.regionRules[region.id]!;
      project = project.fill(
        region.id,
        drawing.slotById(rule.targetSlotId!).color,
      );
    }

    final bytes = await const VectorColoringExportService().encodePng(
      drawing,
      project,
      scale: 1,
    );
    const RoomExportMetadataVerifier().verify(bytes);
    final decoded = image.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 600);
    expect(decoded.height, 400);
    final appleCenter = decoded.getPixel(300, 250);
    expect(appleCenter.r.toInt(), RgbColor.fromHex('#D94B45').red);
    expect(appleCenter.g.toInt(), RgbColor.fromHex('#D94B45').green);
    expect(appleCenter.b.toInt(), RgbColor.fromHex('#D94B45').blue);
  });

  test('clean export retains the canonical artwork outline pass', () async {
    final drawing = await AssetDrawingCatalogLoader().loadById(
      'room_cozy_living',
    );
    final project = ColoringProject.create(
      drawingId: drawing.id,
      drawingRevision: drawing.revision,
      mode: ColoringMode.free,
    );

    final bytes = await const VectorColoringExportService().encodePng(
      drawing,
      project,
      scale: 1,
    );
    final decoded = image.decodePng(bytes)!;
    final wallEdge = decoded.getPixel(22, 80);
    // The 1.5 px canonical outline is antialiased against the unassigned fill.
    // A channel below 128 proves the dark pass survived PNG export without
    // coupling the test to one rasterizer's exact edge blend.
    expect(wallEdge.r.toInt(), lessThan(128));
    expect(wallEdge.g.toInt(), lessThan(128));
    expect(wallEdge.b.toInt(), lessThan(128));
  });
}
