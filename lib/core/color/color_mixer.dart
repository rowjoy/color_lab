import 'color_models.dart';

/// The coordinate system used for digital weighted color averages.
enum MixingSpace { lab, rgb }

/// An immutable color contribution; zero parts are valid and contribute nothing.
final class WeightedColor {
  WeightedColor({required this.color, required this.weight}) {
    _validateWeight(weight);
  }

  final RgbColor color;
  final double weight;

  @override
  bool operator ==(Object other) =>
      other is WeightedColor && color == other.color && weight == other.weight;

  @override
  int get hashCode => Object.hash(color, weight);
}

/// Immutable fractions in input order, consuming [weights] only once.
///
/// Scaling by the largest weight before summation avoids overflowing the sum
/// of large finite weights and preserves ratios for very small finite weights.
/// Empty, all-zero, negative, or nonfinite inputs throw [ArgumentError].
List<double> normalizedMixWeights(Iterable<double> weights) {
  final snapshot = <double>[];
  var maximum = 0.0;
  for (final weight in weights) {
    _validateWeight(weight);
    snapshot.add(weight);
    if (weight > maximum) maximum = weight;
  }
  if (maximum == 0) {
    throw ArgumentError.value(
      snapshot,
      'weights',
      'Must contain at least one positive weight',
    );
  }
  final total = _CompensatedSum();
  for (var index = 0; index < snapshot.length; index++) {
    snapshot[index] /= maximum;
    total.add(snapshot[index]);
  }
  return List<double>.unmodifiable(
    snapshot.map((weight) => weight / total.value),
  );
}

/// Averages D65 L*a*b* coordinates by default, then clamps through [LabColor].
///
/// [MixingSpace.rgb] averages encoded sRGB display channels, rounding only the
/// final channels. It does not average linear-light values. Neither mode models
/// physical pigment mixing. A single effective color is returned unchanged.
RgbColor mixColors(
  Iterable<WeightedColor> colors, {
  MixingSpace space = MixingSpace.lab,
}) {
  final snapshot = colors.toList(growable: false);
  final weights = normalizedMixWeights(snapshot.map((entry) => entry.weight));
  final effective = <(RgbColor, double)>[
    for (var index = 0; index < snapshot.length; index++)
      if (weights[index] > 0) (snapshot[index].color, weights[index]),
  ];
  if (effective.length == 1) return effective.single.$1;

  final first = _CompensatedSum();
  final second = _CompensatedSum();
  final third = _CompensatedSum();
  for (final (color, weight) in effective) {
    if (space == MixingSpace.rgb) {
      first.add(color.red * weight);
      second.add(color.green * weight);
      third.add(color.blue * weight);
    } else {
      final lab = color.toLab();
      first.add(lab.lightness * weight);
      second.add(lab.a * weight);
      third.add(lab.b * weight);
    }
  }
  return space == MixingSpace.rgb
      ? RgbColor(first.value.round(), second.value.round(), third.value.round())
      : LabColor(first.value.clamp(0, 100), second.value, third.value).toRgb();
}

void _validateWeight(double weight) {
  if (!weight.isFinite || weight < 0) {
    throw ArgumentError.value(
      weight,
      'weight',
      'Must be finite and nonnegative',
    );
  }
}

// Neumaier summation retains small contributions and limits order-dependent
// rounding, including when LAB a* or b* contributions have opposing signs.
final class _CompensatedSum {
  var _sum = 0.0;
  var _correction = 0.0;

  void add(double value) {
    final next = _sum + value;
    _correction += _sum.abs() >= value.abs()
        ? (_sum - next) + value
        : (value - next) + _sum;
    _sum = next;
  }

  double get value => _sum + _correction;
}
