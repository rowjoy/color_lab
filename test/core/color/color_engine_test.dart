import 'dart:math';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('opaque RGB', () {
    test('expands shorthand and normalizes HEX', () {
      for (final input in ['abc', '#aBc', 'aabbcc', '#AABBCC']) {
        expect(RgbColor.fromHex(input), RgbColor(170, 187, 204));
        expect(RgbColor.fromHex(input).hex, '#AABBCC');
      }
    });

    test('rejects malformed and alpha HEX', () {
      for (final input in [
        '',
        '#',
        '#12',
        '1234',
        '#12345',
        '#12345678',
        '##fff',
        'ggg',
        ' #fff',
        '#fff ',
      ]) {
        expect(() => RgbColor.fromHex(input), throwsFormatException);
      }
    });

    test('rejects channels outside the display range', () {
      expect(() => RgbColor(-1, 0, 0), throwsArgumentError);
      expect(() => RgbColor(0, 256, 0), throwsArgumentError);
      expect(() => RgbColor(0, 0, -1), throwsArgumentError);
    });

    test('has stable value equality and immutable partial copies', () {
      final color = RgbColor(12, 34, 56);
      expect({color}.contains(RgbColor(12, 34, 56)), isTrue);
      expect(color.copyWith(green: 90), RgbColor(12, 90, 56));
      expect(color.green, 34);
    });
  });

  group('color-space conversions', () {
    test('red has the expected HSL and HSV coordinates', () {
      expect(RgbColor(255, 0, 0).toHsl(), HslColor(0, 1, .5));
      expect(RgbColor(255, 0, 0).toHsv(), HsvColor(0, 1, 1));
    });

    test('achromatic coordinates normalize their hue', () {
      expect(RgbColor(128, 128, 128).toHsl().hue, 0);
      expect(RgbColor(0, 0, 0).toHsv().hue, 0);
      expect(HslColor(270, 0, .5).hue, 0);
      expect(HsvColor(200, 0, .5).hue, 0);
      expect(HslColor(120, 1, 0).hue, 0);
      expect(HslColor(120, 1, 1).hue, 0);
      expect(HsvColor(120, 1, 0).hue, 0);
    });

    test('primary and secondary references cover all six hue sectors', () {
      final references = <(RgbColor, double)>[
        (RgbColor(255, 0, 0), 0),
        (RgbColor(255, 255, 0), 60),
        (RgbColor(0, 255, 0), 120),
        (RgbColor(0, 255, 255), 180),
        (RgbColor(0, 0, 255), 240),
        (RgbColor(255, 0, 255), 300),
      ];
      for (final (rgb, hue) in references) {
        expect(rgb.toHsl(), HslColor(hue, 1, .5));
        expect(rgb.toHsv(), HsvColor(hue, 1, 1));
        expect(HslColor(hue, 1, .5).toRgb(), rgb);
        expect(HsvColor(hue, 1, 1).toRgb(), rgb);
      }
      expect(RgbColor(255, 0, 0).toCmyk(), CmykColor(0, 1, 1, 0));
      expect(RgbColor(0, 255, 255).toCmyk(), CmykColor(1, 0, 0, 0));
    });

    test('black CMYK avoids division by zero', () {
      expect(RgbColor(0, 0, 0).toCmyk(), CmykColor(0, 0, 0, 1));
      expect(CmykColor(0, 0, 0, 1).toRgb(), RgbColor(0, 0, 0));
    });

    test('D65 LAB matches independent reference values', () {
      final red = RgbColor(255, 0, 0).toLab();
      expect(red.lightness, closeTo(53.2408, .001));
      expect(red.a, closeTo(80.0925, .001));
      expect(red.b, closeTo(67.2032, .001));
      final white = RgbColor(255, 255, 255).toLab();
      expect(white.lightness, closeTo(100, .0001));
      expect(white.a, closeTo(0, .0001));
      expect(white.b, closeTo(0, .0001));
      expect(RgbColor(0, 0, 0).toLab(), LabColor(0, 0, 0));
    });

    test('all color spaces round trip the RGB cube and seeded samples', () {
      final random = Random(37);
      final samples = [
        for (final r in [0, 128, 255])
          for (final g in [0, 128, 255])
            for (final b in [0, 128, 255]) RgbColor(r, g, b),
        for (var i = 0; i < 200; i++)
          RgbColor(
            random.nextInt(256),
            random.nextInt(256),
            random.nextInt(256),
          ),
      ];
      for (final source in samples) {
        for (final actual in [
          source.toHsl().toRgb(),
          source.toHsv().toRgb(),
          source.toCmyk().toRgb(),
          source.toLab().toRgb(),
        ]) {
          expect(actual.red, closeTo(source.red, 1));
          expect(actual.green, closeTo(source.green, 1));
          expect(actual.blue, closeTo(source.blue, 1));
        }
      }
    });

    test(
      'LAB allows finite out-of-gamut coordinates and clamps display RGB',
      () {
        final color = LabColor(50, 220, -220).toRgb();
        expect(color.red, inInclusiveRange(0, 255));
        expect(color.green, inInclusiveRange(0, 255));
        expect(color.blue, inInclusiveRange(0, 255));
      },
    );

    test('rejects invalid ranges and all nonfinite coordinates', () {
      for (final invalid in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        for (final make in <Object Function()>[
          () => HslColor(invalid, 1, .5),
          () => HslColor(0, invalid, .5),
          () => HslColor(0, 1, invalid),
          () => HsvColor(invalid, 1, 1),
          () => HsvColor(0, invalid, 1),
          () => HsvColor(0, 1, invalid),
          () => CmykColor(invalid, 0, 0, 0),
          () => CmykColor(0, invalid, 0, 0),
          () => CmykColor(0, 0, invalid, 0),
          () => CmykColor(0, 0, 0, invalid),
          () => LabColor(invalid, 0, 0),
          () => LabColor(50, invalid, 0),
          () => LabColor(50, 0, invalid),
        ]) {
          expect(make, throwsArgumentError);
        }
      }
      for (final make in <Object Function()>[
        () => HslColor(-1, 1, .5),
        () => HslColor(360, 1, .5),
        () => HslColor(0, -.1, .5),
        () => HslColor(0, 1, 1.1),
        () => HsvColor(360, 1, 1),
        () => HsvColor(0, 1.1, 1),
        () => HsvColor(0, 1, -.1),
        () => CmykColor(0, 0, 0, 1.1),
        () => LabColor(-1, 0, 0),
        () => LabColor(101, 0, 0),
      ]) {
        expect(make, throwsArgumentError);
      }
    });

    test('CIE76 has identity, symmetry and known Euclidean distance', () {
      final a = LabColor(50, 2, 3);
      final b = LabColor(50, 5, 7);
      expect(deltaE76(a, a), 0);
      expect(deltaE76(a, b), 5);
      expect(deltaE76(b, a), 5);
    });

    test('CIE76 avoids overflow for representable large LAB distances', () {
      expect(deltaE76(LabColor(50, 1e200, 0), LabColor(50, 0, 0)), 1e200);
    });
  });

  group('local color naming', () {
    test('parses upstream entries and returns stable nearest LAB names', () {
      final namer = ColorNamer.fromJson(
        '[{"name":"Red","hex":"#ff0000"},{"name":"Blue","hex":"#0000ff"}]',
      );
      final nearest = namer.nearest(RgbColor(250, 3, 2));
      expect(nearest.name, 'Red');
      expect(nearest.color.hex, '#FF0000');
      expect(identical(nearest, namer.nearest(RgbColor(250, 3, 2))), isTrue);
      expect(() => namer.colors.clear(), throwsUnsupportedError);
    });

    test('name search uses LAB distance instead of raw RGB distance', () {
      final namer = ColorNamer([
        NamedColor('Black', RgbColor(0, 0, 0)),
        NamedColor('Blue', RgbColor(0, 0, 255)),
      ]);
      expect(namer.nearest(RgbColor(0, 0, 120)).name, 'Blue');
    });

    test('rejects empty and malformed datasets explicitly', () {
      expect(() => ColorNamer([]), throwsArgumentError);
      for (final json in [
        '{}',
        '[]',
        '[{}]',
        '[{"name":"","hex":"#fff"}]',
        '[{"name":"Bad","hex":"#zzzzzz"}]',
        'not json',
      ]) {
        expect(() => ColorNamer.fromJson(json), throwsFormatException);
      }
    });
  });

  group('LAB palette extraction', () {
    test(
      'preserves exact populations and descending order of distinct samples',
      () {
        final pixels = [
          for (var i = 0; i < 6; i++) RgbColor(255, 0, 0),
          for (var i = 0; i < 3; i++) RgbColor(0, 255, 0),
          RgbColor(0, 0, 255),
        ];
        final before = List<RgbColor>.of(pixels);
        final palette = extractPalette(pixels);
        expect(palette.map((entry) => entry.color), [
          RgbColor(255, 0, 0),
          RgbColor(0, 255, 0),
          RgbColor(0, 0, 255),
        ]);
        expect(palette.map((entry) => entry.population), [.6, .3, .1]);
        expect(pixels, before);
        expect(() => palette.clear(), throwsUnsupportedError);
      },
    );

    test('repeated samples yield one finite cluster with full population', () {
      final palette = extractPalette(
        List.filled(40, RgbColor(33, 44, 55)),
        k: 8,
      );
      expect(palette, [PaletteColor(RgbColor(33, 44, 55), 1)]);
    });

    test(
      'merges neighboring centers with weighted population conservation',
      () {
        final palette = extractPalette([
          for (var i = 0; i < 9; i++) RgbColor(255, 0, 0),
          RgbColor(250, 0, 0),
          for (var i = 0; i < 10; i++) RgbColor(0, 0, 255),
        ], k: 3);
        expect(palette, hasLength(2));
        expect(palette.map((entry) => entry.population), [.5, .5]);
        final red = palette.firstWhere((entry) => entry.color.red > 200);
        // The 9:1 LAB centroid lies near display red 254.5; rounding the
        // nonlinear conversion may select either adjacent integer channel.
        expect(red.color.red, closeTo(254.5, .5));
        expect(
          palette.fold<double>(0, (sum, entry) => sum + entry.population),
          closeTo(1, 1e-12),
        );
      },
    );

    test('seeded k-means is deterministic for varied pixels', () {
      final random = Random(17);
      final pixels = List.generate(
        150,
        (_) => RgbColor(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        ),
      );
      final first = extractPalette(pixels, k: 5, seed: 91, mergeThreshold: 0);
      expect(extractPalette(pixels, k: 5, seed: 91, mergeThreshold: 0), first);
      expect(first, hasLength(5));
      expect(first.every((entry) => entry.population > 0), isTrue);
      expect(
        first.fold<double>(0, (sum, entry) => sum + entry.population),
        closeTo(1, 1e-12),
      );
      for (var i = 1; i < first.length; i++) {
        expect(first[i].population, lessThanOrEqualTo(first[i - 1].population));
      }
    });

    test(
      'one cluster returns LAB centroid rather than an arbitrary sample',
      () {
        final palette = extractPalette([
          RgbColor(0, 0, 0),
          RgbColor(255, 255, 255),
        ], k: 1);
        expect(palette.single.color, RgbColor(119, 119, 119));
        expect(palette.single.population, 1);
      },
    );

    test('rejects invalid extraction inputs and invalid population', () {
      expect(() => extractPalette([]), throwsArgumentError);
      for (final k in [0, -1]) {
        expect(
          () => extractPalette([RgbColor(0, 0, 0)], k: k),
          throwsArgumentError,
        );
      }
      for (final threshold in [-1.0, double.nan, double.infinity]) {
        expect(
          () => extractPalette([RgbColor(0, 0, 0)], mergeThreshold: threshold),
          throwsArgumentError,
        );
      }
      expect(
        () => PaletteColor(RgbColor(0, 0, 0), double.nan),
        throwsArgumentError,
      );
      expect(() => PaletteColor(RgbColor(0, 0, 0), 1.1), throwsArgumentError);
    });
  });
}
