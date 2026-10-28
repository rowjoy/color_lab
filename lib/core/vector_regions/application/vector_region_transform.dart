import 'package:flutter/painting.dart';

/// One contain/cover/fill transform shared by paint, hits, bounds and export.
final class VectorRegionTransform {
  const VectorRegionTransform._(this.scaleX, this.scaleY, this.offset);
  final double scaleX;
  final double scaleY;
  final Offset offset;
  factory VectorRegionTransform.fit({
    required Size intrinsicSize,
    required Size viewport,
    double zoom = 1,
    Offset pan = Offset.zero,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
  }) {
    if (![
          intrinsicSize.width,
          intrinsicSize.height,
          viewport.width,
          viewport.height,
          zoom,
        ].every((v) => v.isFinite && v > 0) ||
        !pan.dx.isFinite ||
        !pan.dy.isFinite) {
      throw ArgumentError('Finite positive sizes/zoom and finite pan required');
    }
    final fitted = applyBoxFit(fit, intrinsicSize, viewport);
    final sx = fitted.destination.width / fitted.source.width;
    final sy = fitted.destination.height / fitted.source.height;
    final base = alignment
        .inscribe(
          Size(intrinsicSize.width * sx, intrinsicSize.height * sy),
          Offset.zero & viewport,
        )
        .topLeft;
    final center = viewport.center(Offset.zero);
    return VectorRegionTransform._(
      sx * zoom,
      sy * zoom,
      center + (base - center) * zoom + pan,
    );
  }
  Offset artworkToScreen(Offset p) =>
      Offset(p.dx * scaleX, p.dy * scaleY) + offset;
  Offset screenToArtwork(Offset p) =>
      Offset((p.dx - offset.dx) / scaleX, (p.dy - offset.dy) / scaleY);
  Rect screenBounds(Rect bounds) => Rect.fromPoints(
    artworkToScreen(bounds.topLeft),
    artworkToScreen(bounds.bottomRight),
  );
  void apply(Canvas canvas) {
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scaleX, scaleY);
  }
}
