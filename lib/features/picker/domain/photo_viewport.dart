import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// One transform drives both the displayed image and sampling coordinates.
/// [pan] is in viewport pixels and zoom is centered on the viewport center.
class PhotoViewport {
  const PhotoViewport({
    required this.imageSize,
    required this.size,
    this.zoom = 1,
    this.pan = Offset.zero,
  });

  final Size imageSize;
  final Size size;
  final double zoom;
  final Offset pan;

  Rect get imageRect {
    final fit = math.min(
      size.width / imageSize.width,
      size.height / imageSize.height,
    );
    final displayed = imageSize * (fit * zoom);
    return Rect.fromCenter(
      center: size.center(Offset.zero) + pan,
      width: displayed.width,
      height: displayed.height,
    );
  }

  Offset? normalizedAt(Offset point) {
    final rect = imageRect;
    if (point.dx < rect.left ||
        point.dx > rect.right ||
        point.dy < rect.top ||
        point.dy > rect.bottom) {
      return null;
    }
    return Offset(
      (point.dx - rect.left) / rect.width,
      (point.dy - rect.top) / rect.height,
    );
  }

  /// Source pixels and screen positions share the same contain/pan/zoom map.
  double get scale => imageRect.width / imageSize.width;

  Offset? sourceAt(Offset point) {
    if (!(Offset.zero & size).contains(point)) return null;
    final normalized = normalizedAt(point);
    if (normalized == null) return null;
    return Offset(
      (normalized.dx * imageSize.width).clamp(0.0, imageSize.width - .000001),
      (normalized.dy * imageSize.height).clamp(0.0, imageSize.height - .000001),
    );
  }

  Offset sourcePositionOf(Offset source) => positionOf(Offset(
    source.dx / imageSize.width,
    source.dy / imageSize.height,
  ));

  double brushRadius(double fraction) =>
      math.min(imageSize.width, imageSize.height) * fraction * scale / 2;

  Offset positionOf(Offset normalized) => Offset(
    imageRect.left + normalized.dx * imageRect.width,
    imageRect.top + normalized.dy * imageRect.height,
  );
}
