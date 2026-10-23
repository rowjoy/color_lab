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

  Offset positionOf(Offset normalized) => Offset(
    imageRect.left + normalized.dx * imageRect.width,
    imageRect.top + normalized.dy * imageRect.height,
  );
}
