import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/color/color_models.dart';
import '../domain/mask_bitmap.dart';
import '../domain/room_layer.dart';
import '../segmentation/room_mask_processing.dart';

abstract interface class MaskOverlayService {
  Future<Uint8List> render({
    required MaskBitmap masks,
    required RoomLayer layer,
    required RgbColor tint,
    int featherRadius = 2,
  });
}

final maskOverlayServiceProvider = Provider<MaskOverlayService>(
  (ref) => const IsolateMaskOverlayService(),
);

/// Owns no persistent ports or image cache. Isolate.run transfers the result
/// and closes its worker on success or failure.
final class IsolateMaskOverlayService implements MaskOverlayService {
  const IsolateMaskOverlayService();

  @override
  Future<Uint8List> render({
    required MaskBitmap masks,
    required RoomLayer layer,
    required RgbColor tint,
    int featherRadius = 2,
  }) => Isolate.run(() => _encode(masks, layer, tint, featherRadius));
}

Uint8List _encode(
  MaskBitmap masks,
  RoomLayer layer,
  RgbColor tint,
  int featherRadius,
) {
  final alpha = buildLayerAlpha(masks, layer, featherRadius: featherRadius);
  final image = img.Image(
    width: masks.width,
    height: masks.height,
    numChannels: 4,
  );
  for (var y = 0; y < masks.height; y++) {
    for (var x = 0; x < masks.width; x++) {
      image.setPixelRgba(
        x,
        y,
        tint.red,
        tint.green,
        tint.blue,
        masks.labels[y * masks.width + x] == layer.label
            ? alpha[y * masks.width + x]
            : 0,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
