import 'dart:math' as math;
import 'dart:typed_data';

import '../../picker/domain/prepared_photo.dart';
import '../domain/mask_bitmap.dart';
import '../domain/room_layer.dart';
import 'raw_segmentation.dart';
import 'room_input.dart';
import 'room_model_descriptor.dart';

/// Consumes PreparedPhoto pixels directly: EXIF has already been baked once.
RoomInput prepareRoomInput(
  PreparedPhoto photo,
  RoomModelDescriptor descriptor,
) {
  // Keep the limiting axis exact; floating scale multiplication can floor a
  // mathematically exact 512 to 511 (for example, a 49×49 source).
  final widthLimited =
      photo.width * descriptor.inputHeight >=
      photo.height * descriptor.inputWidth;
  final width = widthLimited
      ? descriptor.inputWidth
      : (photo.width * descriptor.inputHeight ~/ photo.height).clamp(
          1,
          descriptor.inputWidth,
        );
  final height = widthLimited
      ? (photo.height * descriptor.inputWidth ~/ photo.width).clamp(
          1,
          descriptor.inputHeight,
        )
      : descriptor.inputHeight;
  final transform = RoomInputTransform(
    sourceWidth: photo.width,
    sourceHeight: photo.height,
    inputWidth: descriptor.inputWidth,
    inputHeight: descriptor.inputHeight,
    contentWidth: width,
    contentHeight: height,
    paddingLeft: 0,
    paddingTop: 0,
  );
  final tensor = Uint8List(descriptor.inputWidth * descriptor.inputHeight * 3);
  for (var offset = 0; offset < tensor.length; offset += 3) {
    tensor.setRange(offset, offset + 3, const [123, 115, 103]);
  }
  final rgba = photo.rgbaBytes;
  for (var y = 0; y < height; y++) {
    final sy = height == 1 ? 0.0 : y * (photo.height - 1) / (height - 1);
    final y0 = sy.floor();
    final y1 = math.min(y0 + 1, photo.height - 1);
    final dy = sy - y0;
    for (var x = 0; x < width; x++) {
      final sx = width == 1 ? 0.0 : x * (photo.width - 1) / (width - 1);
      final x0 = sx.floor();
      final x1 = math.min(x0 + 1, photo.width - 1);
      final dx = sx - x0;
      for (var channel = 0; channel < 3; channel++) {
        final a = rgba[(y0 * photo.width + x0) * 4 + channel];
        final b = rgba[(y0 * photo.width + x1) * 4 + channel];
        final c = rgba[(y1 * photo.width + x0) * 4 + channel];
        final d = rgba[(y1 * photo.width + x1) * 4 + channel];
        // Preserve the independent Task1 fixture's double operation order.
        tensor[(y * descriptor.inputWidth + x) * 3 +
            channel] = ((a + (b - a) * dx) * (1 - dy) + (c + (d - c) * dx) * dy)
            .toInt()
            .clamp(0, 255);
      }
    }
  }
  return RoomInput(tensorBytes: tensor, transform: transform);
}

MaskBitmap postprocessRoomOutput(
  RawSegmentation output,
  RoomInputTransform transform,
  RoomModelDescriptor descriptor,
) {
  if (output.width != descriptor.outputWidth ||
      output.height != descriptor.outputHeight ||
      transform.inputWidth != descriptor.inputWidth ||
      transform.inputHeight != descriptor.inputHeight) {
    throw ArgumentError('Output and transform must match verified model sizes');
  }
  final lookup = Uint8List(descriptor.classCount);
  lookup[descriptor.idForName('wall')] = RoomLayer.wall.label;
  lookup[descriptor.idForName('ceiling')] = RoomLayer.ceiling.label;
  lookup[descriptor.idForName('floor')] = RoomLayer.floor.label;
  for (final name in const [
    'bed',
    'sofa',
    'chair',
    'table',
    'cabinet',
    'shelf',
    'armchair',
  ]) {
    lookup[descriptor.idForName(name)] = RoomLayer.furniture.label;
  }
  final original = Uint8List(output.classIds.length);
  for (var i = 0; i < original.length; i++) {
    original[i] = lookup[output.classIds[i]];
  }
  final owned = Uint8List.fromList(original);
  // Every layer closes the original map, so earlier fills cannot propagate.
  // Only ignored ADE0 is eligible; all other nonzero IDs remain protected.
  for (final layer in RoomLayer.values) {
    final dilated = Uint8List(original.length);
    for (var y = 0; y < output.height; y++) {
      for (var x = 0; x < output.width; x++) {
        if (original[y * output.width + x] != layer.label) continue;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= output.height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx >= 0 && nx < output.width) {
              dilated[ny * output.width + nx] = 1;
            }
          }
        }
      }
    }
    for (var y = 1; y < output.height - 1; y++) {
      for (var x = 1; x < output.width - 1; x++) {
        final index = y * output.width + x;
        if (output.classIds[index] != descriptor.ignoredLabel ||
            owned[index] != 0) {
          continue;
        }
        var closed = true;
        for (var dy = -1; dy <= 1 && closed; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dilated[(y + dy) * output.width + x + dx] == 0) {
              closed = false;
              break;
            }
          }
        }
        if (closed) owned[index] = layer.label;
      }
    }
  }
  int nearest(int position, int sourceSize, int contentSize) => sourceSize == 1
      ? 0
      : (position * (contentSize - 1) / (sourceSize - 1)).round().clamp(
          0,
          contentSize - 1,
        );
  final labels = Uint8List(transform.sourceWidth * transform.sourceHeight);
  for (var y = 0; y < transform.sourceHeight; y++) {
    final sy =
        transform.paddingTop +
        nearest(y, transform.sourceHeight, transform.contentHeight);
    for (var x = 0; x < transform.sourceWidth; x++) {
      final sx =
          transform.paddingLeft +
          nearest(x, transform.sourceWidth, transform.contentWidth);
      labels[y * transform.sourceWidth + x] = owned[sy * output.width + sx];
    }
  }
  return MaskBitmap(
    width: transform.sourceWidth,
    height: transform.sourceHeight,
    labels: labels,
  );
}

/// Zero outside the bitmap; round once after both integer convolution passes.
/// Radius zero produces binary alpha; radii one/two use binomial kernels.
Uint8List buildLayerAlpha(
  MaskBitmap masks,
  RoomLayer layer, {
  int featherRadius = 2,
}) {
  if (featherRadius < 0 || featherRadius > 2) {
    throw ArgumentError.value(featherRadius, 'featherRadius', 'Expected 0–2');
  }
  final kernel = switch (featherRadius) {
    0 => const [1],
    1 => const [1, 2, 1],
    _ => const [1, 4, 6, 4, 1],
  };
  final denominator = switch (featherRadius) {
    0 => 1,
    1 => 4,
    _ => 16,
  };
  final horizontal = Uint16List(masks.pixelCount);
  for (var y = 0; y < masks.height; y++) {
    for (var x = 0; x < masks.width; x++) {
      var sum = 0;
      for (var k = 0; k < kernel.length; k++) {
        final sx = x + k - featherRadius;
        if (sx >= 0 &&
            sx < masks.width &&
            masks.labels[y * masks.width + sx] == layer.label) {
          sum += 255 * kernel[k];
        }
      }
      horizontal[y * masks.width + x] = sum;
    }
  }
  final alpha = Uint8List(masks.pixelCount);
  for (var y = 0; y < masks.height; y++) {
    for (var x = 0; x < masks.width; x++) {
      var sum = 0;
      for (var k = 0; k < kernel.length; k++) {
        final sy = y + k - featherRadius;
        if (sy >= 0 && sy < masks.height) {
          sum += horizontal[sy * masks.width + x] * kernel[k];
        }
      }
      alpha[y * masks.width + x] = (sum / (denominator * denominator)).round();
    }
  }
  return alpha;
}
