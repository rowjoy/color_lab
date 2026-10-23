import 'dart:math';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/color_test/domain/vision_dot_pattern.dart';
import 'package:color_lab/features/color_test/domain/vision_plate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dot validates finite normalized coordinates and positive radius', () {
    final color = RgbColor(20, 30, 40);
    final dot = VisionDot(x: 0, y: 1, radius: 1, color: color);
    final equal = VisionDot(x: 0, y: 1, radius: 1, color: color);
    expect(dot, equal);
    expect(dot.hashCode, equal.hashCode);
    expect(dot, isNot(VisionDot(x: 1, y: 1, radius: 1, color: color)));
    expect(dot, isNot(VisionDot(x: 0, y: 0, radius: 1, color: color)));
    expect(dot, isNot(VisionDot(x: 0, y: 1, radius: .1, color: color)));
    expect(
      dot,
      isNot(VisionDot(x: 0, y: 1, radius: 1, color: RgbColor(1, 2, 3))),
    );
    for (final invalid in [-.01, 1.01, double.nan, double.infinity]) {
      expect(
        () => VisionDot(x: invalid, y: .5, radius: .01, color: color),
        throwsArgumentError,
      );
      expect(
        () => VisionDot(x: .5, y: invalid, radius: .01, color: color),
        throwsArgumentError,
      );
      expect(
        () => VisionDot(x: .5, y: .5, radius: invalid, color: color),
        throwsArgumentError,
      );
    }
    expect(
      () => VisionDot(x: .5, y: .5, radius: 0, color: color),
      throwsArgumentError,
    );
  });

  test('same seed repeats read-only dots while a new seed changes them', () {
    final plate = VisionPlate(number: 2, seed: 91);
    final dots = generateVisionDots(plate);
    expect(generateVisionDots(plate), dots);
    expect(generateVisionDots(VisionPlate(number: 2, seed: 92)), isNot(dots));
    expect(() => dots.clear(), throwsUnsupportedError);
  });

  test(
    'grid dots fit the circular paper with finite non-overlapping geometry',
    () {
      final dots = generateVisionDots(VisionPlate(number: 8, seed: 123));
      expect(dots.length, inInclusiveRange(650, 750));
      for (var i = 0; i < dots.length; i++) {
        final dot = dots[i];
        expect(dot.x.isFinite && dot.y.isFinite && dot.radius.isFinite, isTrue);
        expect(dot.radius, inInclusiveRange(.009, .013));
        expect(
          sqrt(pow(dot.x - .5, 2) + pow(dot.y - .5, 2)) + dot.radius,
          lessThanOrEqualTo(.48),
        );
        for (var j = i + 1; j < dots.length; j++) {
          final next = dots[j];
          expect(
            sqrt(pow(dot.x - next.x, 2) + pow(dot.y - next.y, 2)),
            greaterThan(dot.radius + next.radius),
          );
        }
      }
    },
  );

  test('digit and palette change only colors, never dot density or size', () {
    final two = generateVisionDots(VisionPlate(number: 2, seed: 44));
    final eight = generateVisionDots(VisionPlate(number: 8, seed: 44));
    final otherPalette = generateVisionDots(
      VisionPlate(number: 2, seed: 44, palette: VisionPalette.blueSand),
    );
    List<(double, double, double)> geometry(List<VisionDot> dots) =>
        dots.map((dot) => (dot.x, dot.y, dot.radius)).toList();
    expect(geometry(eight), geometry(two));
    expect(geometry(otherPalette), geometry(two));
    expect(eight, isNot(two));
    expect(otherPalette, isNot(two));
    // Independently hand-checked center: row 3, column 2 is off in 2, on in 8.
    expect(
      VisionPalette.roseOlive.fieldColors,
      contains(_nearest(two, .5, .5).color),
    );
    expect(
      VisionPalette.roseOlive.figureColors,
      contains(_nearest(eight, .5, .5).color),
    );
  });

  test(
    'original two and eight masks match independent literal cell fixtures',
    () {
      const masks = {
        2: ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
        8: ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
      };
      // Cell centers computed independently from the specified glyph bounds.
      const xs = [.332, .416, .5, .584, .668];
      const ys = [.225714, .317143, .408571, .5, .591429, .682857, .774286];
      for (final entry in masks.entries) {
        final dots = generateVisionDots(
          VisionPlate(number: entry.key, seed: 18),
        );
        for (var row = 0; row < 7; row++) {
          for (var col = 0; col < 5; col++) {
            final colors = entry.value[row][col] == '1'
                ? VisionPalette.roseOlive.figureColors
                : VisionPalette.roseOlive.fieldColors;
            expect(
              colors,
              contains(_nearest(dots, xs[col], ys[row]).color),
              reason: 'Digit ${entry.key}, row $row, column $col',
            );
          }
        }
      }
    },
  );

  test(
    'all supported digits and palettes render both color groups and only their shades',
    () {
      for (final palette in VisionPalette.values) {
        for (var number = 0; number < 10; number++) {
          final dots = generateVisionDots(
            VisionPlate(number: number, seed: 9, palette: palette),
          );
          final colors = dots.map((dot) => dot.color).toSet();
          expect(colors.intersection(palette.figureColors.toSet()), isNotEmpty);
          expect(colors.intersection(palette.fieldColors.toSet()), isNotEmpty);
          expect(
            colors.difference({
              ...palette.figureColors,
              ...palette.fieldColors,
            }),
            isEmpty,
          );
          expect(palette.fieldColors, contains(_nearest(dots, .1, .5).color));
          expect(palette.fieldColors, contains(_nearest(dots, .5, .1).color));
        }
      }
    },
  );
}

VisionDot _nearest(List<VisionDot> dots, double x, double y) =>
    dots.reduce((a, b) {
      double distance(VisionDot dot) =>
          pow(dot.x - x, 2).toDouble() + pow(dot.y - y, 2).toDouble();
      return distance(a) < distance(b) ? a : b;
    });
