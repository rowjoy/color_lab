import 'dart:math';

import 'color_models.dart';

final class _Sample {
  _Sample(this.lab, this.count);
  final LabColor lab;
  final int count;
}

final class _Cluster {
  _Cluster(this.center, this.count);
  final LabColor center;
  final int count;
}

double _distanceSquared(LabColor a, LabColor b) {
  final dl = a.lightness - b.lightness;
  final da = a.a - b.a;
  final db = a.b - b.b;
  return dl * dl + da * da + db * db;
}

LabColor _weighted(LabColor a, int ac, LabColor b, int bc) {
  final total = ac + bc;
  return LabColor(
    (a.lightness * ac + b.lightness * bc) / total,
    (a.a * ac + b.a * bc) / total,
    (a.b * ac + b.b * bc) / total,
  );
}

/// Seeded k-means++ in D65 LAB, bounded to 100 Lloyd iterations.
///
/// Repeated samples are weighted without losing their population. Clusters
/// closer than [mergeThreshold] CIE76 units are merged by weighted centroid.
/// Returns an immutable list ordered by descending population, then RGB value.
/// Throws [ArgumentError] for empty [pixels], nonpositive [k], or a negative or
/// nonfinite [mergeThreshold]. Caller input is never mutated.
List<PaletteColor> extractPalette(
  List<RgbColor> pixels, {
  int k = 8,
  int seed = 42,
  double mergeThreshold = 8,
}) {
  if (pixels.isEmpty) {
    throw ArgumentError.value(pixels, 'pixels', 'Must not be empty');
  }
  if (k <= 0) throw ArgumentError.value(k, 'k', 'Must be positive');
  if (!mergeThreshold.isFinite || mergeThreshold < 0) {
    throw ArgumentError.value(
      mergeThreshold,
      'mergeThreshold',
      'Must be finite and nonnegative',
    );
  }
  final counts = <RgbColor, int>{};
  for (final pixel in pixels) {
    counts.update(pixel, (count) => count + 1, ifAbsent: () => 1);
  }
  final samples = [
    for (final entry in counts.entries) _Sample(entry.key.toLab(), entry.value),
  ];
  final random = Random(seed);
  // Weighted selection of the first center is equivalent to sampling a pixel.
  var firstOffset = random.nextInt(pixels.length);
  var firstIndex = 0;
  for (var i = 0; i < samples.length; i++) {
    firstOffset -= samples[i].count;
    if (firstOffset < 0) {
      firstIndex = i;
      break;
    }
  }
  var centers = <LabColor>[samples[firstIndex].lab];
  final nearest = List<double>.filled(samples.length, double.infinity);
  while (centers.length < min(k, samples.length)) {
    var total = 0.0;
    for (var i = 0; i < samples.length; i++) {
      nearest[i] = min(
        nearest[i],
        _distanceSquared(samples[i].lab, centers.last),
      );
      total += nearest[i] * samples[i].count;
    }
    if (total <= 0) break;
    var offset = random.nextDouble() * total;
    var selected = -1;
    for (var i = 0; i < samples.length; i++) {
      final weight = nearest[i] * samples[i].count;
      if (weight == 0) continue;
      selected = i;
      offset -= weight;
      if (offset < 0) break;
    }
    if (selected < 0) break;
    centers.add(samples[selected].lab);
  }

  var clusters = <_Cluster>[];
  for (var iteration = 0; iteration < 100; iteration++) {
    final populations = List<int>.filled(centers.length, 0);
    final ls = List<double>.filled(centers.length, 0);
    final as = List<double>.filled(centers.length, 0);
    final bs = List<double>.filled(centers.length, 0);
    for (final sample in samples) {
      var best = 0;
      var bestDistance = double.infinity;
      for (var i = 0; i < centers.length; i++) {
        final distance = _distanceSquared(sample.lab, centers[i]);
        if (distance < bestDistance) {
          best = i;
          bestDistance = distance;
        }
      }
      populations[best] += sample.count;
      ls[best] += sample.lab.lightness * sample.count;
      as[best] += sample.lab.a * sample.count;
      bs[best] += sample.lab.b * sample.count;
    }
    clusters = [
      for (var i = 0; i < centers.length; i++)
        if (populations[i] > 0)
          _Cluster(
            LabColor(
              (ls[i] / populations[i]).clamp(0, 100),
              as[i] / populations[i],
              bs[i] / populations[i],
            ),
            populations[i],
          ),
    ];
    final converged =
        clusters.length == centers.length &&
        List.generate(
          centers.length,
          (i) => _distanceSquared(centers[i], clusters[i].center),
        ).every((distance) => distance < 1e-12);
    centers = clusters.map((cluster) => cluster.center).toList();
    if (converged) break;
  }

  while (clusters.length > 1) {
    var bestDistance = mergeThreshold;
    var first = -1;
    var second = -1;
    for (var i = 0; i < clusters.length; i++) {
      for (var j = i + 1; j < clusters.length; j++) {
        final distance = deltaE76(clusters[i].center, clusters[j].center);
        if (distance < bestDistance) {
          bestDistance = distance;
          first = i;
          second = j;
        }
      }
    }
    if (first < 0) break;
    final a = clusters[first];
    final b = clusters[second];
    clusters[first] = _Cluster(
      _weighted(a.center, a.count, b.center, b.count),
      a.count + b.count,
    );
    clusters.removeAt(second);
  }

  final palette = [
    for (final cluster in clusters)
      PaletteColor(cluster.center.toRgb(), cluster.count / pixels.length),
  ];
  palette.sort((a, b) {
    final byPopulation = b.population.compareTo(a.population);
    return byPopulation != 0
        ? byPopulation
        : a.color.value.compareTo(b.color.value);
  });
  return List.unmodifiable(palette);
}
