import 'package:color_lab/core/color/color_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final red = RgbColor(255, 0, 0);

  group('HSL harmony rotations', () {
    // Catch an incorrect angle, rotation order, or RGB/HSV approximation.
    final fixtures = <HarmonyMode, List<String>>{
      HarmonyMode.complementary: ['#FF0000', '#00FFFF'],
      HarmonyMode.analogous: ['#FF0000', '#FF0080', '#FF8000'],
      HarmonyMode.triadic: ['#FF0000', '#00FF00', '#0000FF'],
      HarmonyMode.tetradic: ['#FF0000', '#80FF00', '#00FFFF', '#8000FF'],
      HarmonyMode.splitComplementary: ['#FF0000', '#00FF80', '#0080FF'],
    };
    for (final entry in fixtures.entries) {
      test('${entry.key.name} matches independent pure-red fixtures', () {
        final result = generateHarmony(red, mode: entry.key);
        expect(result.map((color) => color.hex), entry.value);
      });
    }

    test('defaults to a complementary pair', () {
      expect(generateHarmony(red).map((color) => color.hex), [
        '#FF0000',
        '#00FFFF',
      ]);
    });

    test('wraps positive and negative rotations near the hue boundary', () {
      final result = generateHarmony(
        RgbColor(255, 0, 51), // HSL hue 348 degrees.
        mode: HarmonyMode.analogous,
      );
      expect(result.map((color) => color.hex), [
        '#FF0033',
        '#FF00B3',
        '#FF4D00',
      ]);
    });

    test('neutral rotations collapse to the exact anchor', () {
      for (final base in [
        RgbColor(0, 0, 0),
        RgbColor(128, 128, 128),
        RgbColor(255, 255, 255),
      ]) {
        for (final mode in fixtures.keys) {
          final result = generateHarmony(base, mode: mode);
          expect(result, [base], reason: mode.name);
          expect(result.single, same(base));
        }
      }
    });
  });

  group('monochromatic lightness', () {
    test(
      'uses fixed lightness offsets while preserving hue and saturation',
      () {
        // Pure-red L=.5 gives L=.2, .35, .65, .8 after the anchor.
        expect(
          generateHarmony(
            red,
            mode: HarmonyMode.monochromatic,
          ).map((color) => color.hex),
          ['#FF0000', '#660000', '#B30000', '#FF4D4D', '#FF9999'],
        );
      },
    );

    test('black clamps negative offsets and removes duplicate endpoints', () {
      expect(
        generateHarmony(
          RgbColor(0, 0, 0),
          mode: HarmonyMode.monochromatic,
        ).map((color) => color.hex),
        ['#000000', '#262626', '#4D4D4D'],
      );
    });

    test('white clamps positive offsets and preserves first-seen order', () {
      expect(
        generateHarmony(
          RgbColor(255, 255, 255),
          mode: HarmonyMode.monochromatic,
        ).map((color) => color.hex),
        ['#FFFFFF', '#B3B3B3', '#D9D9D9'],
      );
    });

    test(
      'dark chromatic shades deduplicate clamped black after the anchor',
      () {
        expect(
          generateHarmony(
            RgbColor(51, 0, 0),
            mode: HarmonyMode.monochromatic,
          ).map((color) => color.hex),
          ['#330000', '#000000', '#800000', '#CC0000'],
        );
      },
    );
  });

  test('every mode preserves the exact anchor without mutating the result', () {
    final base = RgbColor(178, 164, 212);
    for (final mode in HarmonyMode.values) {
      final result = generateHarmony(base, mode: mode);
      expect(result.first, same(base), reason: mode.name);
      expect(() => result.add(red), throwsUnsupportedError);
      expect(() => result[0] = red, throwsUnsupportedError);
      expect(result.first, same(base));
    }
  });

  test('all modes produce unique opaque display colors at RGB boundaries', () {
    for (final base in [
      RgbColor(0, 0, 1),
      RgbColor(254, 255, 255),
      RgbColor(255, 0, 255),
      RgbColor(12, 34, 56),
    ]) {
      for (final mode in HarmonyMode.values) {
        final result = generateHarmony(base, mode: mode);
        expect(result.toSet().length, result.length);
        for (final color in result) {
          expect(color.red, inInclusiveRange(0, 255));
          expect(color.green, inInclusiveRange(0, 255));
          expect(color.blue, inInclusiveRange(0, 255));
          expect(color.hex, matches(r'^#[0-9A-F]{6}$'));
        }
      }
    }
  });
}
