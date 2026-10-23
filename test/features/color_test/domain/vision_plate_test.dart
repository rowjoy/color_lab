import 'dart:math';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/color_test/domain/vision_plate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plate identity includes validated digit, palette and seed', () {
    final plate = VisionPlate(number: 2, seed: 19);
    final equal = VisionPlate(number: 2, seed: 19);
    expect(plate.id, '2-roseOlive-19');
    expect(plate, equal);
    expect(plate.hashCode, equal.hashCode);
    expect(plate, isNot(VisionPlate(number: 8, seed: 19)));
    expect(plate, isNot(VisionPlate(number: 2, seed: 20)));
    expect(
      plate,
      isNot(VisionPlate(number: 2, seed: 19, palette: VisionPalette.tealRose)),
    );
    expect(VisionPlate(number: 0, seed: 0).number, 0);
    expect(VisionPlate(number: 9, seed: 0x7fffffff).seed, 0x7fffffff);
    for (final digit in [-1, 10]) {
      expect(() => VisionPlate(number: digit, seed: 0), throwsArgumentError);
    }
    for (final seed in [-1, 0x80000000]) {
      expect(() => VisionPlate(number: 2, seed: seed), throwsArgumentError);
    }
  });

  test('palette groups stay immutable, varied and distinct from paper', () {
    final allGroups = <List<RgbColor>>[];
    for (final palette in VisionPalette.values) {
      final figure = palette.figureColors;
      final field = palette.fieldColors;
      allGroups.addAll([figure, field]);
      expect(figure.length, 3);
      expect(field.length, 3);
      expect({...figure, ...field}.length, 6);
      expect(figure, isNot(contains(visionPlatePaper)));
      expect(field, isNot(contains(visionPlatePaper)));
      expect(() => figure.clear(), throwsUnsupportedError);
      expect(() => field.add(RgbColor(0, 0, 0)), throwsUnsupportedError);
    }
    expect(allGroups.toSet().length, 6);
    expect(visionPlatePaper.red, inInclusiveRange(200, 255));
    expect(visionPlatePaper.green, inInclusiveRange(200, 255));
    expect(visionPlatePaper.blue, inInclusiveRange(200, 255));
  });

  test(
    'seeded generation yields six shuffled unique patterns and palettes',
    () {
      final first = generateVisionPlates(random: Random(27));
      expect(first, generateVisionPlates(random: Random(27)));
      expect(first.map((plate) => plate.number).toSet(), {2, 3, 4, 5, 6, 8});
      expect(first.map((plate) => plate.id).toSet().length, 6);
      expect(first.map((plate) => plate.palette), [
        VisionPalette.roseOlive,
        VisionPalette.tealRose,
        VisionPalette.blueSand,
        VisionPalette.roseOlive,
        VisionPalette.tealRose,
        VisionPalette.blueSand,
      ]);
      expect(first, isNot(generateVisionPlates(random: Random(28))));
      expect(() => first.clear(), throwsUnsupportedError);
      expect(generateVisionPlates().length, 6);
    },
  );

  test('constant random source terminates without retrying duplicates', () {
    final random = _ConstantRandom();
    final plates = generateVisionPlates(random: random);
    expect(plates.map((plate) => plate.number).toSet(), {2, 3, 4, 5, 6, 8});
    expect(plates.every((plate) => plate.seed == 0), isTrue);
    expect(random.bounds, [6, 5, 4, 3, 2, ...List.filled(6, 0x7fffffff)]);
  });
}

class _ConstantRandom implements Random {
  final bounds = <int>[];

  @override
  int nextInt(int max) {
    bounds.add(max);
    if (bounds.length > 11) throw StateError('Unbounded random calls');
    return 0;
  }

  @override
  double nextDouble() => throw StateError('Only bounded integer work expected');

  @override
  bool nextBool() => throw StateError('Only bounded integer work expected');
}
