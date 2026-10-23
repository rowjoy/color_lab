import 'package:color_lab/core/color/color_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final red = RgbColor(255, 0, 0);
  final green = RgbColor(0, 255, 0);
  final blue = RgbColor(0, 0, 255);
  final black = RgbColor(0, 0, 0);
  final white = RgbColor(255, 255, 255);

  group('WeightedColor', () {
    test('accepts zero and compares color and weight by value', () {
      final first = WeightedColor(color: red, weight: 0);
      expect(first, WeightedColor(color: RgbColor(255, 0, 0), weight: 0));
      expect({first}.contains(WeightedColor(color: red, weight: 0)), isTrue);
      expect(first, isNot(WeightedColor(color: blue, weight: 0)));
      expect(first, isNot(WeightedColor(color: red, weight: 1)));
    });

    for (final invalid in [
      -1.0,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      test('rejects invalid weight $invalid', () {
        expect(
          () => WeightedColor(color: red, weight: invalid),
          throwsArgumentError,
        );
      });
    }
  });

  group('normalizedMixWeights', () {
    test('preserves zero positions and normalizes unequal parts', () {
      expect(normalizedMixWeights([0, 3, 1, 0]), [0, .75, .25, 0]);
    });

    test('returns an immutable snapshot independent of the source', () {
      final source = [1.0, 3.0];
      final result = normalizedMixWeights(source);
      source[0] = 9;
      expect(result, [.25, .75]);
      expect(() => result[0] = 1, throwsUnsupportedError);
      expect(() => result.add(1), throwsUnsupportedError);
    });

    test('enumerates a single-use source once', () {
      var reads = 0;
      final source = Iterable<double>.generate(2, (index) {
        if (++reads > 2) throw StateError('Weights were consumed twice');
        return index == 0 ? 3 : 1;
      });
      expect(normalizedMixWeights(source), [.75, .25]);
      expect(reads, 2);
    });

    for (final invalid in <List<double>>[
      [],
      [0],
      [0, 0],
      [1, -1],
      [1, double.nan],
      [1, double.infinity],
      [1, double.negativeInfinity],
    ]) {
      test('rejects invalid input $invalid', () {
        expect(() => normalizedMixWeights(invalid), throwsArgumentError);
      });
    }

    test('normalizes huge finite weights without overflowing their sum', () {
      expect(normalizedMixWeights([1e308, 1e308]), [.5, .5]);
      final result = normalizedMixWeights([1e308, 5e307, 5e307]);
      expect(result, [.5, .25, .25]);
    });

    test('preserves ratios for tiny finite and subnormal weights', () {
      expect(normalizedMixWeights([3e-300, 1e-300]), [.75, .25]);
      expect(normalizedMixWeights([double.minPositive]), [1]);
      expect(normalizedMixWeights([double.minPositive, double.minPositive]), [
        .5,
        .5,
      ]);
    });

    test('common rescaling preserves normalized fractions', () {
      for (final scale in [1e-300, 1.0, 1e300]) {
        expect(normalizedMixWeights([scale, 3 * scale]), [.25, .75]);
      }
    });

    test('small contributions survive summation regardless of order', () {
      // 1 + 20 * 1e-16 = 1.000000000000002, so the largest fraction
      // is 0.999999999999998. Naive summation after 1 discards every part.
      final tiny = List<double>.filled(20, 1e-16);
      expect(
        normalizedMixWeights([1, ...tiny]).first,
        closeTo(.999999999999998, 5e-17),
      );
      expect(
        normalizedMixWeights([...tiny, 1]).last,
        closeTo(.999999999999998, 5e-17),
      );
    });
  });

  group('mixColors', () {
    test('RGB averages encoded sRGB channels for equal red and blue', () {
      expect(
        mixColors([
          WeightedColor(color: red, weight: 1),
          WeightedColor(color: blue, weight: 1),
        ], space: MixingSpace.rgb).hex,
        '#800080',
      );
    });

    test('RGB respects a three-to-one ratio', () {
      expect(
        mixColors([
          WeightedColor(color: red, weight: 3),
          WeightedColor(color: blue, weight: 1),
        ], space: MixingSpace.rgb).hex,
        '#BF0040',
      );
    });

    test('RGB rounds once after accumulating every ingredient', () {
      expect(
        mixColors([
          WeightedColor(color: black, weight: 1),
          WeightedColor(color: RgbColor(1, 1, 1), weight: 1),
          WeightedColor(color: RgbColor(1, 1, 1), weight: 1),
        ], space: MixingSpace.rgb).hex,
        '#010101',
      );
    });

    test('RGB preserves a half-channel midpoint across many ingredients', () {
      // 18 black and 18 white contributions are still an exact 50:50 mix.
      // Losing accumulation precision rounds 127.5 down to 127 incorrectly.
      final colors = [
        for (var index = 0; index < 18; index++) ...[
          WeightedColor(color: black, weight: 1),
          WeightedColor(color: white, weight: 1),
        ],
      ];
      expect(mixColors(colors, space: MixingSpace.rgb).hex, '#808080');
    });

    test('defaults to D65 LAB with a perceptual black-white midpoint', () {
      final colors = [
        WeightedColor(color: black, weight: 1),
        WeightedColor(color: white, weight: 1),
      ];
      expect(mixColors(colors).hex, '#777777');
      expect(mixColors(colors, space: MixingSpace.lab).hex, '#777777');
      expect(mixColors(colors, space: MixingSpace.rgb).hex, '#808080');
    });

    test('LAB matches an independent D65 three-color weighted fixture', () {
      // W3C CSS Color 4 rational sRGB matrices, D65 reference white,
      // and CIELAB formulas, evaluated separately in JavaScript:
      // mean LAB = [54.2684620878, 24.2187884441, -14.9983154267].
      // Encoded RGB = [159.5623643163, 115.5957208174, 156.0342599129].
      // https://www.w3.org/TR/css-color-4/#color-conversion-code
      // CSS's D50 adaptation is deliberately omitted for this D65 model.
      expect(
        mixColors([
          WeightedColor(color: red, weight: 1),
          WeightedColor(color: green, weight: 2),
          WeightedColor(color: blue, weight: 3),
        ]).hex,
        '#A0749C',
      );
    });

    test('LAB matches an independently evaluated starting recipe', () {
      // Same independent W3C/D65 calculation as the fixture above:
      // mean LAB = [78.5456162338, 5.9936706407, 1.6888343951].
      // Encoded RGB = [207.1771242124, 190.5660745719, 191.4183055623].
      expect(
        mixColors([
          WeightedColor(color: RgbColor.fromHex('#B2A4D4'), weight: 50),
          WeightedColor(color: RgbColor.fromHex('#E8DAA9'), weight: 50),
        ]).hex,
        '#CFBFBF',
      );
    });

    for (final space in MixingSpace.values) {
      test('$space returns the exact single effective input', () {
        final endpoint = RgbColor(17, 83, 149);
        final result = mixColors([
          WeightedColor(color: red, weight: 0),
          WeightedColor(color: endpoint, weight: double.minPositive),
          WeightedColor(color: blue, weight: 0),
        ], space: space);
        expect(identical(result, endpoint), isTrue);
        expect(
          identical(
            mixColors([
              WeightedColor(color: endpoint, weight: 7),
            ], space: space),
            endpoint,
          ),
          isTrue,
        );
      });

      test('$space preserves duplicate colors', () {
        final color = RgbColor(17, 83, 149);
        expect(
          mixColors([
            WeightedColor(color: color, weight: 1),
            WeightedColor(color: color, weight: 3),
          ], space: space),
          color,
        );
      });

      test('$space excludes zero contributions', () {
        expect(
          mixColors([
            WeightedColor(color: red, weight: 0),
            WeightedColor(color: black, weight: 1),
            WeightedColor(color: green, weight: 0),
            WeightedColor(color: white, weight: 1),
          ], space: space).hex,
          space == MixingSpace.lab ? '#777777' : '#808080',
        );
      });

      test('$space rejects empty and all-zero mixes', () {
        expect(() => mixColors([], space: space), throwsArgumentError);
        expect(
          () => mixColors([
            WeightedColor(color: red, weight: 0),
            WeightedColor(color: blue, weight: 0),
          ], space: space),
          throwsArgumentError,
        );
      });

      test('$space consumes the input once', () {
        var reads = 0;
        final colors = Iterable<WeightedColor>.generate(2, (index) {
          if (++reads > 2) throw StateError('Colors were consumed twice');
          return WeightedColor(color: index == 0 ? black : white, weight: 1);
        });
        expect(
          mixColors(colors, space: space).hex,
          space == MixingSpace.lab ? '#777777' : '#808080',
        );
        expect(reads, 2);
      });

      test('$space remains valid with huge, tiny, or rescaled weights', () {
        for (final weight in [double.minPositive, 1e-300, 1.0, 1e308]) {
          expect(
            mixColors([
              WeightedColor(color: black, weight: weight),
              WeightedColor(color: white, weight: weight),
            ], space: space).hex,
            space == MixingSpace.lab ? '#777777' : '#808080',
          );
        }
      });

      test(
        '$space preserves unequal ratios across scales and permutations',
        () {
          for (final scale in [1e-300, 1.0, 1e300]) {
            final colors = [
              WeightedColor(color: red, weight: scale),
              WeightedColor(color: green, weight: 2 * scale),
              WeightedColor(color: blue, weight: 3 * scale),
            ];
            for (final order in [
              [0, 1, 2],
              [0, 2, 1],
              [1, 0, 2],
              [1, 2, 0],
              [2, 0, 1],
              [2, 1, 0],
            ]) {
              expect(
                mixColors(
                  order.map((index) => colors[index]),
                  space: space,
                ).hex,
                space == MixingSpace.lab ? '#A0749C' : '#2B5580',
              );
            }
          }
        },
      );
    }
  });
}
