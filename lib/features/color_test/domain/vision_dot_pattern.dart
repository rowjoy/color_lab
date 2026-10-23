import 'dart:math';

import '../../../core/color/color_models.dart';
import 'vision_plate.dart';

/// One opaque dot in normalized drawing coordinates.
final class VisionDot {
  VisionDot({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
  }) {
    _validateUnit(x, 'x');
    _validateUnit(y, 'y');
    _validateUnit(radius, 'radius');
    if (radius == 0) {
      throw ArgumentError.value(radius, 'radius', 'Must be positive');
    }
  }

  final double x;
  final double y;
  final double radius;
  final RgbColor color;

  @override
  bool operator ==(Object other) =>
      other is VisionDot &&
      x == other.x &&
      y == other.y &&
      radius == other.radius &&
      color == other.color;

  @override
  int get hashCode => Object.hash(x, y, radius, color);
}

void _validateUnit(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, name, 'Must be finite and in [0, 1]');
  }
}

/// Original compact block digits; these are not clinical plate masks.
const _glyphs = [
  ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
  ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  ['11111', '10000', '10000', '11110', '00001', '00001', '11110'],
  ['01110', '10000', '10000', '11110', '10001', '10001', '01110'],
  ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  ['01110', '10001', '10001', '01111', '00001', '00001', '01110'],
];

bool _isFigure(int number, double x, double y) {
  if (x < .29 || x >= .71 || y < .18 || y >= .82) return false;
  final column = ((x - .29) / .42 * 5).floor();
  final row = ((y - .18) / .64 * 7).floor();
  return _glyphs[number][row][column] == '1';
}

/// Geometry depends on the seed alone; the glyph only chooses a shade group.
List<VisionDot> generateVisionDots(VisionPlate plate) {
  final geometry = Random(plate.seed);
  final shades = Random(plate.seed + 1);
  final dots = <VisionDot>[];
  for (var row = 0; row < 32; row++) {
    for (var column = 0; column < 32; column++) {
      final x = (column + .5) / 32 + (geometry.nextDouble() * 2 - 1) * .002;
      final y = (row + .5) / 32 + (geometry.nextDouble() * 2 - 1) * .002;
      final radius = .009 + .004 * geometry.nextDouble();
      if (sqrt((x - .5) * (x - .5) + (y - .5) * (y - .5)) + radius > .48) {
        continue;
      }
      final colors = _isFigure(plate.number, x, y)
          ? plate.palette.figureColors
          : plate.palette.fieldColors;
      dots.add(
        VisionDot(x: x, y: y, radius: radius, color: colors[shades.nextInt(3)]),
      );
    }
  }
  return List<VisionDot>.unmodifiable(dots);
}
