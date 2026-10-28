import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart' as vector_graphics;

import '../domain/illustrated_room_draft.dart';
import '../presentation/illustrated_room_region_artwork.dart';
import '../../../core/vector_regions/application/vector_region_transform.dart';
import 'illustrated_room_png.dart';

abstract interface class IllustratedRoomArtworkEncoder {
  Future<Uint8List> encodePng(IllustratedRoomDraft draft);
}

final class IllustratedRoomRenderException implements Exception {
  const IllustratedRoomRenderException();
}

final class IllustratedRoomLoadedPicture {
  const IllustratedRoomLoadedPicture({
    required this.picture,
    required this.size,
  });

  final ui.Picture picture;
  final ui.Size size;
}

typedef IllustratedRoomPictureLoader =
    Future<IllustratedRoomLoadedPicture> Function(IllustratedRoomDraft draft);

final illustratedRoomArtworkEncoderProvider =
    Provider<IllustratedRoomArtworkEncoder>(
      (ref) => SvgIllustratedRoomArtworkEncoder(),
    );

final class SvgIllustratedRoomArtworkEncoder
    implements IllustratedRoomArtworkEncoder {
  SvgIllustratedRoomArtworkEncoder({IllustratedRoomPictureLoader? loadPicture})
    : _loadPicture = loadPicture ?? _loadSvgPicture;

  static const _sourceSize = ui.Size(1200, 800);
  static const outputWidth = 2400;
  static const outputHeight = 1600;
  static const _outputBounds = ui.Rect.fromLTWH(0, 0, 2400, 1600);

  final IllustratedRoomPictureLoader _loadPicture;

  @override
  Future<Uint8List> encodePng(IllustratedRoomDraft draft) async {
    ui.Picture? source;
    ui.Picture? scaled;
    ui.PictureRecorder? recorder;
    ui.Image? image;
    Uint8List? output;
    StackTrace? failureStackTrace;
    var failed = false;

    try {
      final loaded = await _loadPicture(draft);
      source = loaded.picture;
      if (loaded.size != _sourceSize) {
        throw const IllustratedRoomRenderException();
      }

      recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, _outputBounds)
        ..scale(2)
        ..drawPicture(source);
      assert(canvas.getSaveCount() == 1);
      scaled = recorder.endRecording();
      recorder = null;
      image = await scaled.toImage(outputWidth, outputHeight);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const IllustratedRoomRenderException();
      output = cleanIllustratedRoomPng(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_, stackTrace) {
      failed = true;
      failureStackTrace = stackTrace;
    }

    var cleanupFailed = false;
    StackTrace? cleanupStackTrace;
    void clean(void Function() operation) {
      try {
        operation();
      } catch (_, stackTrace) {
        cleanupFailed = true;
        cleanupStackTrace ??= stackTrace;
      }
    }

    if (recorder case final activeRecorder?) {
      if (activeRecorder.isRecording) {
        clean(() => activeRecorder.endRecording().dispose());
      }
    }
    if (image case final renderedImage?) {
      clean(renderedImage.dispose);
    }
    if (scaled case final scaledPicture?) {
      clean(scaledPicture.dispose);
    }
    if (source case final sourcePicture?) {
      clean(sourcePicture.dispose);
    }

    if (failed) {
      Error.throwWithStackTrace(
        const IllustratedRoomRenderException(),
        failureStackTrace!,
      );
    }
    if (cleanupFailed) {
      Error.throwWithStackTrace(
        const IllustratedRoomRenderException(),
        cleanupStackTrace!,
      );
    }
    return output!;
  }

  static Future<IllustratedRoomLoadedPicture> _loadSvgPicture(
    IllustratedRoomDraft draft,
  ) async {
    if (draft.template.regionAssetPath != null) {
      final artwork = await StudyRoomRegionArtwork.loadFor(draft.template);
      final recorder = ui.PictureRecorder();
      artwork.draw(
        ui.Canvas(recorder),
        draft,
        VectorRegionTransform.fit(
          intrinsicSize: artwork.definition.intrinsicSize,
          viewport: _sourceSize,
        ),
      );
      return IllustratedRoomLoadedPicture(
        picture: recorder.endRecording(),
        size: artwork.definition.intrinsicSize,
      );
    }
    final info = await vector_graphics.vg.loadPicture(
      SvgAssetLoader(draft.template.assetPath),
      null,
    );
    return IllustratedRoomLoadedPicture(picture: info.picture, size: info.size);
  }
}
