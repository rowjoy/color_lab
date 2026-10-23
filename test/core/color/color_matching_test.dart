import 'dart:math';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchingScore', () {
    // Catches reversing the distance scale, rounding early, or omitting clamps.
    for (final (distance, points) in <(double, int)>[
      (0, 100),
      (.49, 100),
      (.51, 99),
      (20, 80),
      (100, 0),
      (150, 0),
    ]) {
      test('distance $distance earns $points points', () {
        expect(matchingScore(distance), points);
      });
    }

    test('rejects negative and nonfinite distances', () {
      for (final distance in [
        -.01,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(() => matchingScore(distance), throwsArgumentError);
      }
    });
  });

  group('generateMatchingTargets', () {
    test('replays a seed and returns an immutable display-color snapshot', () {
      final targets = generateMatchingTargets(random: Random(42));
      expect(targets, generateMatchingTargets(random: Random(42)));
      expect(targets.length, 5);
      expect(targets.toSet().length, 5);
      expect(() => targets[0] = RgbColor(0, 0, 0), throwsUnsupportedError);
      expect(() => targets.add(RgbColor(0, 0, 0)), throwsUnsupportedError);
    });

    // Catches collapsed hue bins, low-contrast endpoints, and duplicate targets.
    test(
      'seeded games keep five separated hues in the intended HSL bounds',
      () {
        for (var seed = 0; seed < 100; seed++) {
          final targets = generateMatchingTargets(random: Random(seed));
          expect(targets.length, 5);
          expect(targets.toSet().length, 5);
          final hues = <double>[];
          for (final color in targets) {
            final hsl = color.toHsl();
            // RGB quantization slightly shifts the original HSL coordinates.
            expect(hsl.saturation, inInclusiveRange(.34, .91));
            expect(hsl.lightness, inInclusiveRange(.248, .752));
            hues.add(hsl.hue);
          }
          hues.sort();
          for (var index = 0; index < 5; index++) {
            final gap = (hues[(index + 1) % 5] - hues[index]) % 360;
            expect(gap, inInclusiveRange(33, 111));
          }
        }
      },
    );

    test(
      'a constant zero random stream terminates with distinct literal colors',
      () {
        final random = _ConstantRandom(0);
        final targets = generateMatchingTargets(random: random);
        expect(targets.map((color) => color.hex).toSet(), {
          '#562929',
          '#4D5629',
          '#29563B',
          '#293B56',
          '#4D2956',
        });
        expect(random.calls, lessThanOrEqualTo(20));
      },
    );

    test('a constant upper-bound stream wraps hue and remains bounded', () {
      final random = _ConstantRandom(.9999999999999999);
      final targets = generateMatchingTargets(random: random);
      expect(targets.length, 5);
      expect(targets.toSet().length, 5);
      expect(random.calls, lessThanOrEqualTo(20));
      for (final color in targets) {
        expect(color.toHsl().saturation, inInclusiveRange(.89, .91));
        expect(color.toHsl().lightness, closeTo(.75, .002));
      }
    });
  });
}

// Controls only randomness; conversion and target generation remain real.
class _ConstantRandom implements Random {
  _ConstantRandom(this.value);
  final double value;
  int calls = 0;

  @override
  double nextDouble() {
    calls++;
    return value;
  }

  @override
  int nextInt(int max) {
    calls++;
    return value == 0 ? 0 : max - 1;
  }

  @override
  bool nextBool() {
    calls++;
    return value != 0;
  }
}
