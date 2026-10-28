import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/vector_regions/application/vector_region_transform.dart';
import '../../room_studio/application/illustrated_room_png.dart';
import '../../room_studio/application/room_image_export_service.dart';
import '../domain/coloring_project.dart';
import '../domain/drawing_definition.dart';
import '../rendering/coloring_artwork_renderer.dart';

abstract interface class ColoringExportService {
  Future<Uint8List> encodePng(
    DrawingDefinition definition,
    ColoringProject project, {
    double scale,
  });
}

final coloringExportServiceProvider = Provider<ColoringExportService>(
  (ref) => const VectorColoringExportService(),
);

final class VectorColoringExportService implements ColoringExportService {
  const VectorColoringExportService();

  @override
  Future<Uint8List> encodePng(
    DrawingDefinition definition,
    ColoringProject project, {
    double scale = 2,
  }) async {
    if (project.drawingId != definition.id ||
        project.drawingRevision != definition.revision ||
        !scale.isFinite ||
        scale <= 0 ||
        scale > 4) {
      throw const ColoringExportException();
    }
    final source = definition.artwork.intrinsicSize;
    final width = (source.width * scale).round();
    final height = (source.height * scale).round();
    if (width < 1 || height < 1 || width > 4096 || height > 4096) {
      throw const ColoringExportException();
    }
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    ColoringArtworkRenderer.draw(
      canvas,
      definition,
      project.assignments,
      VectorRegionTransform.fit(
        intrinsicSize: source,
        viewport: ui.Size(width.toDouble(), height.toDouble()),
      ),
    );
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const ColoringExportException();
      return cleanIllustratedRoomPng(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      throw const ColoringExportException();
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }
}

final class ColoringExportException implements Exception {
  const ColoringExportException();
}

Future<void> saveColoringPng({
  required ColoringExportService encoder,
  required RoomImageExportService transport,
  required DrawingDefinition definition,
  required ColoringProject project,
}) async {
  final bytes = await encoder.encodePng(definition, project);
  await transport.prepareSave(isCurrent: () => true);
  await transport.savePng(
    pngBytes: bytes,
    photoId: 'coloring-${project.id}',
    isCurrent: () => true,
  );
}

Future<RoomShareResult> shareColoringPng({
  required ColoringExportService encoder,
  required RoomImageExportService transport,
  required DrawingDefinition definition,
  required ColoringProject project,
  required ui.Rect origin,
  required String title,
}) async {
  final bytes = await encoder.encodePng(definition, project);
  return transport.sharePng(
    pngBytes: bytes,
    photoId: 'coloring-${project.id}',
    origin: origin,
    title: title,
    isCurrent: () => true,
  );
}
