import 'dart:math';

import '../../../core/color/color_models.dart';

/// Original illustrative swatches, with no clinical calibration.
enum VisionPalette {
  roseOlive,
  tealRose,
  blueSand;

  List<RgbColor> get figureColors => _figures[index];
  List<RgbColor> get fieldColors => _fields[index];

  static final _figures = [
    _colors(['CA766F', 'D7857B', 'B96B67']),
    _colors(['55988D', '6AA99B', '49887F']),
    _colors(['6F8FBE', '819FC9', '627FAA']),
  ];
  static final _fields = [
    _colors(['8C9563', '9EA773', '7E8859']),
    _colors(['BD827F', 'CE9490', 'AB7374']),
    _colors(['C1A878', 'D0B98B', 'AF986B']),
  ];
}

List<RgbColor> _colors(List<String> hexes) =>
    List<RgbColor>.unmodifiable(hexes.map(RgbColor.fromHex));

final RgbColor visionPlatePaper = RgbColor.fromHex('F4EFE5');

/// A generated digit, its illustrative palette, and the geometry seed.
final class VisionPlate {
  VisionPlate({
    required this.number,
    required this.seed,
    this.palette = VisionPalette.roseOlive,
  }) {
    if (number < 0 || number > 9) {
      throw ArgumentError.value(number, 'number', 'Must be a digit in [0, 9]');
    }
    if (seed < 0 || seed > 0x7fffffff) {
      throw ArgumentError.value(seed, 'seed', 'Must be in [0, 0x7fffffff]');
    }
  }

  final int number;
  final int seed;
  final VisionPalette palette;

  String get id => '$number-${palette.name}-$seed';

  @override
  bool operator ==(Object other) =>
      other is VisionPlate &&
      number == other.number &&
      seed == other.seed &&
      palette == other.palette;

  @override
  int get hashCode => Object.hash(number, seed, palette);
}

/// Six different digits in bounded work, even for a constant random source.
List<VisionPlate> generateVisionPlates({Random? random}) {
  final rng = random ?? Random();
  final numbers = [2, 3, 4, 5, 6, 8]..shuffle(rng);
  return List<VisionPlate>.unmodifiable([
    for (var index = 0; index < numbers.length; index++)
      VisionPlate(
        number: numbers[index],
        seed: rng.nextInt(0x7fffffff),
        palette: VisionPalette.values[index % VisionPalette.values.length],
      ),
  ]);
}
