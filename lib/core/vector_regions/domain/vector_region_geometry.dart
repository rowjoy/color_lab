import 'dart:ui';

/// Restricted, absolute path commands. The codec is the validation boundary.
final class VectorRegionGeometry {
  VectorRegionGeometry({required List<VectorRegionPart> parts})
    : parts = List.unmodifiable(parts);

  final List<VectorRegionPart> parts;
  Path? _path;

  /// A cached union keeps overlapping base planes filled while retaining holes.
  Path toPath() => _path ??= parts
      .map((part) => part.toPath())
      .reduce((a, b) => Path.combine(PathOperation.union, a, b));
  Rect get bounds => toPath().getBounds();
}

final class VectorRegionPart {
  VectorRegionPart({
    required this.slot,
    this.whiteOverlayOpacity = 0,
    this.blackOverlayOpacity = 0,
    required List<List<Object>> commands,
  }) : commands = List.unmodifiable(commands.map(List<Object>.unmodifiable));
  final int slot;
  final double whiteOverlayOpacity;
  final double blackOverlayOpacity;
  final List<List<Object>> commands;
  Path? _path;
  Path toPath() => _path ??= _build();
  Path _build() {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final command in commands) {
      double n(int i) => (command[i] as num).toDouble();
      switch (command[0]) {
        case 'M':
          path.moveTo(n(1), n(2));
        case 'L':
          path.lineTo(n(1), n(2));
        case 'Q':
          path.quadraticBezierTo(n(1), n(2), n(3), n(4));
        case 'C':
          path.cubicTo(n(1), n(2), n(3), n(4), n(5), n(6));
        case 'Z':
          path.close();
      }
    }
    return path;
  }
}

final class VectorRegionDefinition {
  const VectorRegionDefinition({
    required this.id,
    required this.labelKey,
    required this.groupId,
    required this.fillable,
    required this.paintOrder,
    required this.geometry,
  });
  final String id;
  final String labelKey;
  final String groupId;
  final bool fillable;
  final int paintOrder;
  final VectorRegionGeometry geometry;
}

final class VectorRegionPaintEntry {
  const VectorRegionPaintEntry(this.region, this.part);
  final VectorRegionDefinition region;
  final VectorRegionPart part;
  Path get path => part.toPath();
  int get slot => part.slot;
}

final class VectorArtworkDefinition {
  VectorArtworkDefinition({
    required this.id,
    required this.revision,
    required this.intrinsicSize,
    required List<VectorRegionDefinition> regions,
  }) : regions = List.unmodifiable(regions) {
    paintEntries = List.unmodifiable(
      [
        for (final region in regions)
          for (final part in region.geometry.parts)
            VectorRegionPaintEntry(region, part),
      ]..sort((a, b) => a.slot.compareTo(b.slot)),
    );
    // Region paintOrder and part slots describe the same stacking order.
    // Disallow interleaved/reversed region ranges so reverse region hit testing
    // always agrees with the paths that the renderer paints on top.
    var previousOrder = -1;
    for (final entry in paintEntries) {
      if (entry.region.paintOrder < previousOrder) {
        throw ArgumentError('Part slots contradict region paint order');
      }
      previousOrder = entry.region.paintOrder;
    }
  }
  final String id;
  final int revision;
  final Size intrinsicSize;
  final List<VectorRegionDefinition> regions;
  late final List<VectorRegionPaintEntry> paintEntries;
}
