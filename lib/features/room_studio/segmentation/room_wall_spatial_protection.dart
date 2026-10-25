part of 'room_wall_depth_protection.dart';

final class _WallPlaneEvidence {
  const _WallPlaneEvidence(this.plane, this.support);
  final _DepthPlane plane;
  final Uint8List support;
}

/// Null retains the legacy no-ceiling path. An uncertain anchored scene abstains.
MaskBitmap? _protectSpatialRoomWalls(
  MaskBitmap masks,
  RoomDepthFrame depth,
  List<_DepthSample> candidates,
  double span,
) {
  final width = depth.width, height = depth.height;
  final axis = math.max(width, height);
  final owners = Uint8List(width * height);
  var ceilingCount = 0;
  for (var y = 0; y < height; y++) {
    final sy = ((y + .5) * masks.height / height).floor().clamp(
      0,
      masks.height - 1,
    );
    for (var x = 0; x < width; x++) {
      final sx = ((x + .5) * masks.width / width).floor().clamp(
        0,
        masks.width - 1,
      );
      final owner = masks.labels[sy * masks.width + sx];
      owners[y * width + x] = owner;
      if (owner == RoomLayer.ceiling.label) ceilingCount++;
    }
  }
  if (ceilingCount < 64) return null;
  final wall = Uint8List(owners.length);
  final border = Uint8List(owners.length);
  for (var i = 0; i < owners.length; i++) {
    if (owners[i] != RoomLayer.wall.label) continue;
    wall[i] = 1;
    for (final n in _wallNeighbors(i, width, height)) {
      if (owners[n] == RoomLayer.ceiling.label) {
        border[i] = 1;
        break;
      }
    }
  }
  final ceilingDistance = _wallDistances(border, width, height, allowed: wall);
  final anchors = Uint8List(owners.length);
  var anchorCount = 0;
  final gap = math.max(1, axis ~/ 50), band = axis * 3 ~/ 16;
  for (var i = 0; i < anchors.length; i++) {
    if (wall[i] == 1 &&
        ceilingDistance[i] >= gap &&
        ceilingDistance[i] <= band) {
      anchors[i] = 1;
      anchorCount++;
    }
  }
  final minimumAnchors = math.max(16, axis ~/ 2);
  if (anchorCount < minimumAnchors) return masks;

  final tolerance = span * .035;
  var remaining = candidates;
  final evidence = <_WallPlaneEvidence>[];
  for (var attempt = 0; attempt < 4 && remaining.length >= 64; attempt++) {
    final plane = _spatialCandidatePlane(remaining, tolerance, 42 + attempt);
    if (plane == null) break;
    final support = _anchoredWallSupport(
      plane,
      candidates,
      anchors,
      width,
      height,
      tolerance,
      minimumAnchors,
    );
    if (support != null) evidence.add(_WallPlaneEvidence(plane, support));
    // Peel even rejected foreground planes so they cannot hide a real wall.
    remaining = [
      for (final s in remaining)
        if ((s.z - plane.at(s.u, s.v)).abs() >= tolerance) s,
    ];
  }
  if (evidence.isEmpty) return masks;
  final unexplained = Uint8List(anchors.length);
  var explained = 0;
  for (var i = 0; i < anchors.length; i++) {
    if (anchors[i] == 0) continue;
    final u = (i % width + .5) / width, v = (i ~/ width + .5) / height;
    if (evidence.any(
      (e) => (depth.inverseDepth[i] - e.plane.at(u, v)).abs() < tolerance,
    )) {
      explained++;
    } else {
      unexplained[i] = 1;
    }
  }
  if (explained < anchorCount * .85) return masks;

  final distances = [
    for (final e in evidence) _wallDistances(e.support, width, height),
  ];
  final unknownDistance = _wallDistances(unexplained, width, height);
  final labels = Uint8List.fromList(masks.labels);
  var changed = false;
  for (var y = 0; y < masks.height; y++) {
    final dy = ((y + .5) * height / masks.height).floor().clamp(0, height - 1);
    for (var x = 0; x < masks.width; x++) {
      final i = y * masks.width + x;
      if (labels[i] != RoomLayer.wall.label) continue;
      final dx = ((x + .5) * width / masks.width).floor().clamp(0, width - 1);
      final cell = dy * width + dx;
      var nearest = 1 << 29;
      for (final d in distances) {
        nearest = math.min(nearest, d[cell]);
      }
      if (nearest > axis ~/ 4 || unknownDistance[cell] <= nearest) continue;
      var reference = double.negativeInfinity;
      for (var p = 0; p < evidence.length; p++) {
        if (distances[p][cell] > nearest + 2) continue;
        final predicted = evidence[p].plane.at(
          (dx + .5) / width,
          (dy + .5) / height,
        );
        if (predicted > 0) reference = math.max(reference, predicted);
      }
      if (reference.isFinite &&
          depth.inverseDepth[cell] - reference > span * .08) {
        labels[i] = 0;
        changed = true;
      }
    }
  }
  return changed
      ? MaskBitmap(width: masks.width, height: masks.height, labels: labels)
      : masks;
}

_DepthPlane? _spatialCandidatePlane(
  List<_DepthSample> points,
  double tolerance,
  int seed,
) {
  final stride = (points.length / 1500).ceil();
  final samples = [for (var i = 0; i < points.length; i += stride) points[i]];
  final random = math.Random(seed);
  _DepthPlane? best;
  var bestCount = 0;
  var bestError = double.infinity;
  for (var trial = 0; trial < 1500; trial++) {
    final plane = _DepthPlane.through(
      samples[random.nextInt(samples.length)],
      samples[random.nextInt(samples.length)],
      samples[random.nextInt(samples.length)],
    );
    if (plane == null) continue;
    var count = 0;
    var error = 0.0;
    for (final s in samples) {
      final residual = (s.z - plane.at(s.u, s.v)).abs();
      if (residual < tolerance) {
        count++;
        error += residual;
      }
    }
    if (count > bestCount || count == bestCount && error < bestError) {
      best = plane;
      bestCount = count;
      bestError = error;
    }
  }
  return best;
}

Uint8List? _anchoredWallSupport(
  _DepthPlane plane,
  List<_DepthSample> points,
  Uint8List anchors,
  int width,
  int height,
  double tolerance,
  int minimumAnchors,
) {
  final inliers = Uint8List(width * height);
  for (final s in points) {
    if ((s.z - plane.at(s.u, s.v)).abs() < tolerance) {
      inliers[(s.v * height).floor() * width + (s.u * width).floor()] = 1;
    }
  }
  final support = Uint8List(inliers.length);
  var total = 0, anchored = 0;
  for (var start = 0; start < inliers.length; start++) {
    if (inliers[start] != 1) continue;
    final component = <int>[start];
    inliers[start] = 2;
    var anchorCount = 0;
    for (var q = 0; q < component.length; q++) {
      final cell = component[q];
      anchorCount += anchors[cell];
      for (final n in _wallNeighbors(cell, width, height)) {
        if (inliers[n] == 1) {
          inliers[n] = 2;
          component.add(n);
        }
      }
    }
    if (anchorCount < 16 || component.length < 64) continue;
    // A narrow intersection stripe is not independent 2D wall support.
    var u = 0.0, v = 0.0;
    for (final i in component) {
      u += (i % width + .5) / width;
      v += (i ~/ width + .5) / height;
    }
    u /= component.length;
    v /= component.length;
    var uu = 0.0, vv = 0.0, uv = 0.0;
    for (final i in component) {
      final du = (i % width + .5) / width - u,
          dv = (i ~/ width + .5) / height - v;
      uu += du * du;
      vv += dv * dv;
      uv += du * dv;
    }
    if ((uu * vv - uv * uv) / (component.length * component.length) < 1e-5) {
      continue;
    }
    total += component.length;
    anchored += anchorCount;
    for (final i in component) {
      support[i] = 1;
    }
  }
  return total >= math.max(64, points.length * .10) &&
          anchored >= minimumAnchors
      ? support
      : null;
}

Iterable<int> _wallNeighbors(int i, int width, int height) sync* {
  final x = i % width, y = i ~/ width;
  if (x > 0) yield i - 1;
  if (x + 1 < width) yield i + 1;
  if (y > 0) yield i - width;
  if (y + 1 < height) yield i + width;
}

Int32List _wallDistances(
  Uint8List seeds,
  int width,
  int height, {
  Uint8List? allowed,
}) {
  final distances = Int32List(seeds.length)
    ..fillRange(0, seeds.length, 1 << 29);
  final queue = Int32List(seeds.length);
  var head = 0, tail = 0;
  for (var i = 0; i < seeds.length; i++) {
    if (seeds[i] != 0) {
      distances[i] = 0;
      queue[tail++] = i;
    }
  }
  while (head < tail) {
    final cell = queue[head++];
    for (final n in _wallNeighbors(cell, width, height)) {
      if (distances[n] != 1 << 29 || allowed != null && allowed[n] == 0) {
        continue;
      }
      distances[n] = distances[cell] + 1;
      queue[tail++] = n;
    }
  }
  return distances;
}
