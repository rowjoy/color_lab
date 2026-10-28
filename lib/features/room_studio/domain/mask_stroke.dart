import 'room_layer.dart';

/// A point inside the image, with coordinates normalized to its outer edges.
final class MaskPoint {
  MaskPoint(this.x, this.y) {
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      throw ArgumentError('Finite normalized coordinates in 0–1 required');
    }
  }

  final double x;
  final double y;
}

enum MaskEditMode { add, erase }

/// Separate segments retain breaks caused by leaving the image bounds.
final class MaskStroke {
  MaskStroke({
    required this.layer,
    required this.mode,
    required List<List<MaskPoint>> segments,
    this.diameterFraction = .05,
  }) : segments = _snapshot(segments) {
    if (!diameterFraction.isFinite ||
        diameterFraction < .005 ||
        diameterFraction > .20) {
      throw ArgumentError('Brush diameter must be 0.5–20% of the shorter side');
    }
  }

  final RoomLayer layer;
  final MaskEditMode mode;
  final List<List<MaskPoint>> segments;
  final double diameterFraction;

  static List<List<MaskPoint>> _snapshot(List<List<MaskPoint>> segments) {
    if (segments.isEmpty || segments.any((points) => points.isEmpty)) {
      throw ArgumentError('Nonempty stroke segments required');
    }
    return List.unmodifiable(
      segments.map((points) => List<MaskPoint>.unmodifiable(points)),
    );
  }
}
