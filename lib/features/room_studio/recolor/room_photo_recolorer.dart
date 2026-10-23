import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/color/color_models.dart';
import '../../picker/domain/prepared_photo.dart';
import '../domain/mask_bitmap.dart';
import '../domain/room_layer.dart';
import '../domain/room_layer_colors.dart';
import '../segmentation/room_mask_processing.dart';
import 'room_recolor_frame.dart';

final class _LightnessStats {
  const _LightnessStats(this.low, this.median, this.high);

  final double low;
  final double median;
  final double high;
}

RoomRecolorFrame recolorRoomPhoto({
  required RoomRecolorKey key,
  required PreparedPhoto photo,
  required MaskBitmap masks,
  required RoomLayerColors colors,
}) {
  if (masks.width != photo.width || masks.height != photo.height) {
    throw ArgumentError('Photo and masks must have matching dimensions');
  }
  final source = photo.rgbaBytes;
  final output = Uint8List.fromList(source);
  final stats = <RoomLayer, _LightnessStats>{};
  final targets = <RoomLayer, LabColor>{};
  final alphas = <RoomLayer, Uint8List>{};

  for (final layer in RoomLayer.values) {
    final target = colors.colorFor(layer);
    if (target == null) continue;
    final lightness = <double>[];
    for (var pixel = 0; pixel < masks.pixelCount; pixel++) {
      if (masks.labels[pixel] != layer.label) continue;
      final offset = pixel * 4;
      lightness.add(
        RgbColor(
          source[offset],
          source[offset + 1],
          source[offset + 2],
        ).toLab().lightness,
      );
    }
    if (lightness.isEmpty) continue;
    lightness.sort();
    double percentile(double value) =>
        lightness[(value * (lightness.length - 1)).floor()];
    stats[layer] = _LightnessStats(
      percentile(.05),
      percentile(.50),
      percentile(.95),
    );
    targets[layer] = target.toLab();
    alphas[layer] = buildLayerAlpha(masks, layer, featherRadius: 2);
  }

  for (var pixel = 0; pixel < masks.pixelCount; pixel++) {
    final label = masks.labels[pixel];
    if (label == 0) continue;
    final layer = RoomLayer.values[label - 1];
    final layerStats = stats[layer];
    final target = targets[layer];
    final alpha = alphas[layer];
    if (layerStats == null || target == null || alpha == null) continue;
    final coverage = alpha[pixel] / 255;
    if (coverage <= 0) continue;
    final offset = pixel * 4;
    final sourceColor = RgbColor(
      source[offset],
      source[offset + 1],
      source[offset + 2],
    );
    final sourceLab = sourceColor.toLab();
    final difference = sourceLab.lightness - layerStats.median;
    final darkScale = math.min(
      1.0,
      target.lightness / math.max(1, layerStats.median - layerStats.low),
    );
    final lightScale = math.min(
      1.0,
      (100 - target.lightness) /
          math.max(1, layerStats.high - layerStats.median),
    );
    final lightness =
        (target.lightness +
                difference * (difference < 0 ? darkScale : lightScale))
            .clamp(0.0, 100.0);
    final recolored = LabColor(lightness, target.a, target.b).toRgb();
    output[offset] = _blend(sourceColor.red, recolored.red, coverage);
    output[offset + 1] = _blend(sourceColor.green, recolored.green, coverage);
    output[offset + 2] = _blend(sourceColor.blue, recolored.blue, coverage);
    output[offset + 3] = 255;
  }

  final encoded = img.Image(
    width: photo.width,
    height: photo.height,
    numChannels: 4,
  );
  for (var y = 0; y < photo.height; y++) {
    for (var x = 0; x < photo.width; x++) {
      final offset = (y * photo.width + x) * 4;
      encoded.setPixelRgba(
        x,
        y,
        output[offset],
        output[offset + 1],
        output[offset + 2],
        output[offset + 3],
      );
    }
  }
  return RoomRecolorFrame(
    key: key,
    width: photo.width,
    height: photo.height,
    rgbaBytes: output,
    pngBytes: Uint8List.fromList(img.encodePng(encoded)),
  );
}

int _blend(int source, int target, double coverage) {
  final linear = _linear(source) * (1 - coverage) + _linear(target) * coverage;
  final encoded = linear <= .0031308
      ? 12.92 * linear
      : 1.055 * math.pow(linear, 1 / 2.4) - .055;
  return (encoded * 255).round().clamp(0, 255);
}

double _linear(int channel) {
  final value = channel / 255;
  return value <= .04045
      ? value / 12.92
      : math.pow((value + .055) / 1.055, 2.4).toDouble();
}
