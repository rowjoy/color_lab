import 'dart:math';

import 'color_models.dart';

/// Game points from display-RGB CIE76 distance, rather than a percentage.
int matchingScore(double deltaE) {
  if (!deltaE.isFinite || deltaE < 0) {
    throw ArgumentError.value(
      deltaE,
      'deltaE',
      'Must be finite and nonnegative',
    );
  }
  return (100 - deltaE).clamp(0, 100).round();
}

/// Distinct display colors from separated hue bins, with bounded work.
List<RgbColor> generateMatchingTargets({
  Random? random,
  int count = 5,
  double minimumSaturation = .35,
  double? minimumHueSeparation,
}) {
  if (count < 3 || count > 12) {
    throw ArgumentError.value(count, 'count', 'Expected 3–12 targets');
  }
  if (!minimumSaturation.isFinite ||
      minimumSaturation < 0 ||
      minimumSaturation > .9) {
    throw ArgumentError.value(
      minimumSaturation,
      'minimumSaturation',
      'Must be finite and in [0, .9]',
    );
  }
  final step = 360 / count;
  if (minimumHueSeparation != null &&
      (!minimumHueSeparation.isFinite ||
          minimumHueSeparation < 0 ||
          minimumHueSeparation > step)) {
    throw ArgumentError.value(
      minimumHueSeparation,
      'minimumHueSeparation',
      'Must be finite and no greater than 360 / count',
    );
  }
  final source = random ?? Random();
  final offset = source.nextDouble() * 360;
  final jitter = minimumHueSeparation == null
      ? step / 2
      : step - minimumHueSeparation;
  final targets = <RgbColor>[
    for (var index = 0; index < count; index++)
      HslColor(
        (offset + index * step + source.nextDouble() * jitter) % 360,
        minimumSaturation + (.9 - minimumSaturation) * source.nextDouble(),
        .25 + .50 * source.nextDouble(),
      ).toRgb(),
  ];
  for (var index = targets.length - 1; index > 0; index--) {
    final other = source.nextInt(index + 1);
    final value = targets[index];
    targets[index] = targets[other];
    targets[other] = value;
  }
  return List<RgbColor>.unmodifiable(targets);
}
