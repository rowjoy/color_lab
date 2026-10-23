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

/// Five distinct display colors from separated hue bins, with bounded work.
List<RgbColor> generateMatchingTargets({Random? random}) {
  final source = random ?? Random();
  final offset = source.nextDouble() * 360;
  final targets = <RgbColor>[
    for (var index = 0; index < 5; index++)
      HslColor(
        (offset + index * 72 + source.nextDouble() * 36) % 360,
        .35 + .55 * source.nextDouble(),
        .25 + .50 * source.nextDouble(),
      ).toRgb(),
  ];
  targets.shuffle(source);
  return List<RgbColor>.unmodifiable(targets);
}
