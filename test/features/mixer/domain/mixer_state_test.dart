import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/mixer/domain/mixer_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final black = RgbColor(0, 0, 0);
  final white = RgbColor(255, 255, 255);

  MixerState blackAndWhite({double first = 50, double second = 50}) =>
      MixerState(
        ingredients: [
          MixerIngredient(id: 'black', color: black, weight: first),
          MixerIngredient(id: 'white', color: white, weight: second),
        ],
      );

  group('MixerIngredient', () {
    test('rejects blank IDs', () {
      for (final id in ['', ' ', '\n\t']) {
        expect(
          () => MixerIngredient(id: id, color: black),
          throwsArgumentError,
        );
      }
    });

    test('rejects weights outside finite zero through 100', () {
      for (final weight in [
        -1.0,
        100.01,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => MixerIngredient(id: 'black', color: black, weight: weight),
          throwsArgumentError,
        );
      }
    });

    test('copies independently and compares all ingredient values', () {
      final original = MixerIngredient(id: 'black', color: black);
      final equal = MixerIngredient(id: 'black', color: RgbColor(0, 0, 0));
      final edited = original.copyWith(id: 'white', color: white, weight: 100);
      expect(original, equal);
      expect(original.hashCode, equal.hashCode);
      expect(original.weight, 50);
      expect(edited.id, 'white');
      expect(edited.color, white);
      expect(edited.weight, 100);
      expect(edited, isNot(original));
      expect(original.copyWith(), original);
      expect(original.copyWith(weight: 0).weight, 0);
      expect(() => original.copyWith(weight: -1), throwsArgumentError);
      expect(original.copyWith(id: 'different'), isNot(original));
      expect(original.copyWith(color: white), isNot(original));
      expect(original.copyWith(weight: 1), isNot(original));
    });
  });

  group('MixerState', () {
    test('initial colors make a ready, equal LAB draft', () {
      final state = MixerState.initial();
      expect(state.ingredients.map((item) => item.id), ['color-0', 'color-1']);
      expect(state.ingredients.map((item) => item.color.hex), [
        '#B2A4D4',
        '#E8DAA9',
      ]);
      expect(state.ingredients.map((item) => item.weight), [50, 50]);
      expect(state.space, MixingSpace.lab);
      expect(state.hasActiveColors, isTrue);
      expect(state.fractions, [0.5, 0.5]);
      expect(state.selectedResult, state.labResult);
      expect(state, MixerState.initial());
      expect(state.hashCode, MixerState.initial().hashCode);
    });

    test('requires at least two ingredients with unique IDs', () {
      final item = MixerIngredient(id: 'black', color: black);
      expect(() => MixerState(ingredients: []), throwsArgumentError);
      expect(() => MixerState(ingredients: [item]), throwsArgumentError);
      expect(() => MixerState(ingredients: [item, item]), throwsArgumentError);
    });

    test('snapshots input collections and exposes immutable collections', () {
      final source = [
        MixerIngredient(id: 'black', color: black, weight: 25),
        MixerIngredient(id: 'white', color: white, weight: 75),
      ];
      final state = MixerState(ingredients: source);
      source[0] = source[0].copyWith(color: white, weight: 100);
      source.clear();
      expect(state.ingredients.first.color, black);
      expect(state.ingredients.first.weight, 25);
      expect(state.fractions, [0.25, 0.75]);
      expect(() => state.ingredients.clear(), throwsUnsupportedError);
      expect(
        () => state.ingredients[0] = state.ingredients.last,
        throwsUnsupportedError,
      );
      expect(() => state.fractions[0] = 1, throwsUnsupportedError);
      final copy = state.copyWith();
      expect(copy, state);
      expect(copy.hashCode, state.hashCode);
      expect(
        () => copy.ingredients.add(state.ingredients.first),
        throwsUnsupportedError,
      );
    });

    test('consumes source iterables only once', () {
      var iterations = 0;
      Iterable<MixerIngredient> entries() sync* {
        iterations++;
        yield MixerIngredient(id: 'black', color: black);
        yield MixerIngredient(id: 'white', color: white);
      }

      final state = MixerState(ingredients: entries());
      expect(state.fractions, [0.5, 0.5]);
      expect(state.rgbResult!.hex, '#808080');
      expect(iterations, 1);
    });

    test('normalizes parts and omits zero weights from blending', () {
      final state = MixerState(
        ingredients: [
          MixerIngredient(id: 'black', color: black, weight: 25),
          MixerIngredient(id: 'white', color: white, weight: 75),
          MixerIngredient(id: 'red', color: RgbColor(255, 0, 0), weight: 0),
        ],
      );
      expect(state.fractions, [0.25, 0.75, 0]);
      expect(state.rgbResult!.hex, '#BFBFBF');
    });

    test(
      'zero total has immutable zero fractions and no results in either mode',
      () {
        final state = blackAndWhite(first: 0, second: 0);
        expect(state.hasActiveColors, isFalse);
        expect(state.fractions, [0, 0]);
        expect(() => state.fractions[0] = 1, throwsUnsupportedError);
        expect(state.labResult, isNull);
        expect(state.rgbResult, isNull);
        expect(state.selectedResult, isNull);
        expect(state.copyWith(space: MixingSpace.rgb).selectedResult, isNull);
      },
    );

    test('mode chooses the correct comparison without changing inputs', () {
      final lab = blackAndWhite();
      final rgb = lab.copyWith(space: MixingSpace.rgb);
      expect(lab.labResult!.hex, '#777777');
      expect(lab.rgbResult!.hex, '#808080');
      expect(lab.selectedResult!.hex, '#777777');
      expect(rgb.selectedResult!.hex, '#808080');
      expect(rgb.ingredients, lab.ingredients);
      expect(rgb.fractions, lab.fractions);
      expect(rgb.labResult, lab.labResult);
      expect(rgb.rgbResult, lab.rgbResult);
      expect(rgb, isNot(lab));
    });

    test('one positive endpoint preserves exact color in both modes', () {
      final state = blackAndWhite(first: 0, second: 100);
      expect(state.fractions, [0, 1]);
      expect(state.labResult, white);
      expect(state.rgbResult, white);
    });

    test(
      'copyWith snapshots replacement entries and equality preserves order',
      () {
        final original = blackAndWhite();
        final reordered = original.ingredients.reversed.toList();
        final copy = original.copyWith(ingredients: reordered);
        reordered.clear();
        expect(copy.ingredients.map((item) => item.id), ['white', 'black']);
        expect(original.ingredients.map((item) => item.id), ['black', 'white']);
        expect(copy, isNot(original));
        expect(
          copy,
          original.copyWith(ingredients: original.ingredients.reversed),
        );
        expect(() => original.copyWith(ingredients: []), throwsArgumentError);
      },
    );
  });
}
