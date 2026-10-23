import 'dart:typed_data';

import '../../../core/color/color_models.dart';

/// An opaque, oriented preview and the identical pixels used for sampling.
final class PreparedPhoto {
  PreparedPhoto({
    required this.width,
    required this.height,
    required Uint8List rgbaBytes,
    required Uint8List previewBytes,
    required List<PaletteColor> palette,
  }) : rgbaBytes = Uint8List.fromList(rgbaBytes).asUnmodifiableView(),
       previewBytes = Uint8List.fromList(previewBytes).asUnmodifiableView(),
       palette = List.unmodifiable(palette) {
    if (width < 1 || height < 1 || rgbaBytes.length != width * height * 4) {
      throw ArgumentError('Positive dimensions and matching RGBA are required');
    }
  }

  final int width;
  final int height;
  final Uint8List rgbaBytes;
  final Uint8List previewBytes;
  final List<PaletteColor> palette;

  /// Samples floor(x * width), floor(y * height), clipping at image edges.
  RgbColor sample(double x, double y) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Sample coordinates must be finite');
    }
    final column = (x.clamp(0, 1) * width).floor().clamp(0, width - 1);
    final row = (y.clamp(0, 1) * height).floor().clamp(0, height - 1);
    final offset = (row * width + column) * 4;
    return RgbColor(
      rgbaBytes[offset],
      rgbaBytes[offset + 1],
      rgbaBytes[offset + 2],
    );
  }
}
