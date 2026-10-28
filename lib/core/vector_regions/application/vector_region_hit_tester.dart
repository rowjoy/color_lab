import 'dart:math' as math;
import 'dart:ui';
import '../domain/vector_region_geometry.dart';
import 'vector_region_transform.dart';

/// Screen epsilon is measured in logical pixels, including under pan/zoom.
VectorRegionDefinition? hitTestVectorRegion(
  VectorArtworkDefinition artwork,
  Offset screenPoint,
  VectorRegionTransform transform, {
  double epsilon = .5,
}) {
  if (!epsilon.isFinite || epsilon < 0) {
    throw ArgumentError.value(epsilon, 'epsilon');
  }
  final point = transform.screenToArtwork(screenPoint);
  final regions = artwork.regions.toList()
    ..sort((a, b) => b.paintOrder.compareTo(a.paintOrder));
  for (final region in regions) {
    if (!region.fillable) continue;
    for (final part in region.geometry.parts) {
      final path = part.toPath();
      if (path.contains(point)) return region;
      final tolerance = math.max(epsilon, 1e-7);
      final bounds = transform
          .screenBounds(path.getBounds())
          .inflate(tolerance);
      if (!bounds.contains(screenPoint) &&
          !bounds.inflate(1e-7).contains(screenPoint)) {
        continue;
      }
      for (final metric in path.computeMetrics()) {
        final steps = math.max(
          1,
          (metric.length * math.max(transform.scaleX, transform.scaleY) / .25)
              .ceil(),
        );
        Offset? previous;
        for (var i = 0; i <= steps; i++) {
          final tangent = metric.getTangentForOffset(metric.length * i / steps);
          if (tangent == null) continue;
          final current = transform.artworkToScreen(tangent.position);
          if (previous != null &&
              _distance(screenPoint, previous, current) <= tolerance) {
            return region;
          }
          previous = current;
        }
      }
    }
  }
  return null;
}

double _distance(Offset p, Offset a, Offset b) {
  final delta = b - a;
  final length = delta.distanceSquared;
  if (length == 0) return (p - a).distance;
  final t = (((p - a).dx * delta.dx + (p - a).dy * delta.dy) / length).clamp(
    0.0,
    1.0,
  );
  return (p - (a + delta * t)).distance;
}
