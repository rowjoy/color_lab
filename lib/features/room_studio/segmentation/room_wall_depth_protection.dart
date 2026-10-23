import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/mask_bitmap.dart';
import '../domain/room_layer.dart';

/// Relative inverse depth covering the whole prepared photo, without padding.
/// Larger values indicate nearer surfaces; values are not metric distances.
final class RoomDepthFrame {
  RoomDepthFrame({
    required this.width,
    required this.height,
    required Float32List inverseDepth,
  }) : inverseDepth = Float32List.fromList(inverseDepth).asUnmodifiableView() {
    if (width <= 0 || height <= 0 || inverseDepth.length != width * height) {
      throw ArgumentError(
        'Positive depth dimensions and matching values required',
      );
    }
    if (this.inverseDepth.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Depth values must be finite and nonnegative');
    }
  }

  final int width;
  final int height;
  final Float32List inverseDepth;
}

/// Removes Wall ownership for surfaces clearly in front of a dominant wall.
///
/// A planar wall has approximately affine inverse depth in image coordinates.
/// Deterministic RANSAC tolerates foreground pixels mislabeled as Wall. A weak
/// fit leaves the semantic mask untouched. Other owners are never reassigned.
MaskBitmap protectRoomWallsWithDepth(MaskBitmap masks, RoomDepthFrame depth) {
  if (masks.count(RoomLayer.wall) < 64 ||
      masks.width < 2 ||
      masks.height < 2 ||
      depth.width < 2 ||
      depth.height < 2) {
    return masks;
  }
  final sorted = depth.inverseDepth.toList()..sort();
  var span = _percentile(sorted, .95) - _percentile(sorted, .05);
  final minimumSpan = math.max(1e-5, _percentile(sorted, .5) * 1e-6);
  if (span <= minimumSpan) {
    // A small object can disappear from both trimmed percentiles. Recover only
    // variation supported by a full 2×2 block, not isolated depth spikes.
    span = _supportedDepthSpan(depth);
    if (span <= minimumSpan) return masks;
  }

  final candidates = <_DepthSample>[];
  for (var y = 0; y < depth.height; y++) {
    final sourceY = ((y + .5) * masks.height / depth.height).floor().clamp(
      0,
      masks.height - 1,
    );
    for (var x = 0; x < depth.width; x++) {
      final sourceX = ((x + .5) * masks.width / depth.width).floor().clamp(
        0,
        masks.width - 1,
      );
      if (masks.labels[sourceY * masks.width + sourceX] !=
          RoomLayer.wall.label) {
        continue;
      }
      candidates.add(
        _DepthSample(
          (x + .5) / depth.width,
          (y + .5) / depth.height,
          depth.inverseDepth[y * depth.width + x],
        ),
      );
    }
  }
  if (candidates.length < 64) return masks;
  // Bound fitting work independently of photo/depth dimensions. Sampling stays
  // uniform across the entire semantic Wall region and has no position prior.
  final stride = (candidates.length / 4096).ceil();
  final samples = [
    for (var i = 0; i < candidates.length; i += stride) candidates[i],
  ];
  final tolerance = span * .035;
  final random = math.Random(42);
  _DepthPlane? best;
  var bestCount = 0;
  var bestError = double.infinity;
  for (var trial = 0; trial < 800; trial++) {
    final i = random.nextInt(samples.length);
    var j = random.nextInt(samples.length);
    while (j == i) {
      j = random.nextInt(samples.length);
    }
    var k = random.nextInt(samples.length);
    while (k == i || k == j) {
      k = random.nextInt(samples.length);
    }
    final plane = _DepthPlane.through(samples[i], samples[j], samples[k]);
    if (plane == null) continue;
    var count = 0;
    var errorSum = 0.0;
    for (final sample in samples) {
      final error = (sample.z - plane.at(sample.u, sample.v)).abs();
      if (error < tolerance) {
        count++;
        errorSum += error;
      }
    }
    if (count > bestCount || (count == bestCount && errorSum < bestError)) {
      best = plane;
      bestCount = count;
      bestError = errorSum;
    }
  }
  if (best == null || bestCount < samples.length * .60) return masks;
  var plane = best;
  for (var refinement = 0; refinement < 5; refinement++) {
    final inliers = [
      for (final sample in samples)
        if ((sample.z - plane.at(sample.u, sample.v)).abs() < tolerance) sample,
    ];
    if (inliers.length < 64 || inliers.length < samples.length * .60) {
      return masks;
    }
    final refined = _DepthPlane.fit(inliers);
    if (refined == null) return masks;
    plane = refined;
  }
  var consensus = 0;
  // Confirm confidence against every candidate, avoiding subsampling aliases.
  for (final sample in candidates) {
    if ((sample.z - plane.at(sample.u, sample.v)).abs() < tolerance) {
      consensus++;
    }
  }
  if (consensus < 64 || consensus < candidates.length * .60) return masks;

  final labels = Uint8List.fromList(masks.labels);
  var changed = false;
  for (var y = 0; y < masks.height; y++) {
    final dy = ((y + .5) * depth.height / masks.height).floor().clamp(
      0,
      depth.height - 1,
    );
    final v = (dy + .5) / depth.height;
    for (var x = 0; x < masks.width; x++) {
      final index = y * masks.width + x;
      if (labels[index] != RoomLayer.wall.label) continue;
      final dx = ((x + .5) * depth.width / masks.width).floor().clamp(
        0,
        depth.width - 1,
      );
      final value = depth.inverseDepth[dy * depth.width + dx];
      if (value - plane.at((dx + .5) / depth.width, v) > span * .08) {
        labels[index] = 0;
        changed = true;
      }
    }
  }
  return changed
      ? MaskBitmap(width: masks.width, height: masks.height, labels: labels)
      : masks;
}

double _percentile(List<double> values, double quantile) {
  final position = (values.length - 1) * quantile;
  final low = position.floor();
  final high = position.ceil();
  return values[low] + (values[high] - values[low]) * (position - low);
}

double _supportedDepthSpan(RoomDepthFrame depth) {
  var low = double.infinity;
  var high = double.negativeInfinity;
  final values = depth.inverseDepth;
  for (var y = 0; y < depth.height - 1; y++) {
    for (var x = 0; x < depth.width - 1; x++) {
      final i = y * depth.width + x;
      final a = values[i], b = values[i + 1];
      final c = values[i + depth.width], d = values[i + depth.width + 1];
      low = math.min(low, math.max(math.max(a, b), math.max(c, d)));
      high = math.max(high, math.min(math.min(a, b), math.min(c, d)));
    }
  }
  return math.max(0, high - low);
}

final class _DepthSample {
  const _DepthSample(this.u, this.v, this.z);
  final double u;
  final double v;
  final double z;
}

final class _DepthPlane {
  const _DepthPlane(this.a, this.b, this.c);
  final double a;
  final double b;
  final double c;

  double at(double u, double v) => a * u + b * v + c;

  static _DepthPlane? through(_DepthSample p, _DepthSample q, _DepthSample r) {
    final du1 = q.u - p.u, dv1 = q.v - p.v, dz1 = q.z - p.z;
    final du2 = r.u - p.u, dv2 = r.v - p.v, dz2 = r.z - p.z;
    final determinant = du1 * dv2 - du2 * dv1;
    // Nearby/collinear points cannot establish a reliable two-dimensional fit.
    if (determinant.abs() < .003) return null;
    final a = (dz1 * dv2 - dz2 * dv1) / determinant;
    final b = (du1 * dz2 - du2 * dz1) / determinant;
    final c = p.z - a * p.u - b * p.v;
    return a.isFinite && b.isFinite && c.isFinite ? _DepthPlane(a, b, c) : null;
  }

  static _DepthPlane? fit(List<_DepthSample> samples) {
    var meanU = 0.0, meanV = 0.0, meanZ = 0.0;
    for (final sample in samples) {
      meanU += sample.u;
      meanV += sample.v;
      meanZ += sample.z;
    }
    meanU /= samples.length;
    meanV /= samples.length;
    meanZ /= samples.length;
    var uu = 0.0, uv = 0.0, vv = 0.0, uz = 0.0, vz = 0.0;
    for (final sample in samples) {
      final u = sample.u - meanU, v = sample.v - meanV, z = sample.z - meanZ;
      uu += u * u;
      uv += u * v;
      vv += v * v;
      uz += u * z;
      vz += v * z;
    }
    final determinant = uu * vv - uv * uv;
    if (determinant <= samples.length * samples.length * 1e-8) return null;
    final a = (uz * vv - vz * uv) / determinant;
    final b = (vz * uu - uz * uv) / determinant;
    final c = meanZ - a * meanU - b * meanV;
    return a.isFinite && b.isFinite && c.isFinite ? _DepthPlane(a, b, c) : null;
  }
}
