import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/mixer/domain/mixer_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReorderedMixerController extends MixerController {
  @override
  MixerState build() => MixerState.initial().copyWith(
    ingredients: MixerState.initial().ingredients.reversed,
  );
}

void main() {
  late ProviderContainer container;
  late MixerController controller;
  final red = RgbColor(255, 0, 0);
  final blue = RgbColor(0, 0, 255);

  setUp(() {
    container = ProviderContainer();
    controller = container.read(mixerProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('starts in a usable LAB draft', () {
    expect(container.read(mixerProvider), MixerState.initial());
    expect(container.read(mixerProvider).selectedResult, isNotNull);
  });

  test('adding colors snapshots the draft with distinct stable IDs', () {
    final initial = container.read(mixerProvider);
    controller.addColor(red);
    final first = container.read(mixerProvider);
    final addedId = first.ingredients.last.id;
    controller.addColor(blue);
    final second = container.read(mixerProvider);
    expect(initial.ingredients.length, 2);
    expect(first.ingredients.length, 3);
    expect(second.ingredients.length, 4);
    expect(first.ingredients.last.color, red);
    expect(first.ingredients.last.weight, 50);
    expect(second.ingredients[2].id, addedId);
    expect(second.ingredients.last.color, blue);
    expect(second.ingredients.map((item) => item.id).toSet().length, 4);
  });

  test('edits target stable IDs after an earlier ingredient is removed', () {
    controller.addColor(red);
    controller.addColor(blue);
    final original = container.read(mixerProvider);
    final redId = original.ingredients[2].id;
    final blueId = original.ingredients[3].id;
    controller.removeColor('color-0');
    controller.setWeight(blueId, 100);
    controller.setColor(redId, RgbColor(0, 255, 0));
    final state = container.read(mixerProvider);
    expect(state.ingredients.map((item) => item.id), [
      'color-1',
      redId,
      blueId,
    ]);
    expect(state.ingredients[1].color.hex, '#00FF00');
    expect(state.ingredients[1].weight, 50);
    expect(state.ingredients[2].color, blue);
    expect(state.ingredients[2].weight, 100);
    expect(original.ingredients[2].color, red);
    expect(original.ingredients[3].weight, 50);
  });

  test('edits target IDs rather than positions in reordered drafts', () {
    final reordered = ProviderContainer(
      overrides: [mixerProvider.overrideWith(_ReorderedMixerController.new)],
    );
    addTearDown(reordered.dispose);
    final editor = reordered.read(mixerProvider.notifier);
    editor.setColor('color-0', red);
    editor.setWeight('color-1', 0);
    final state = reordered.read(mixerProvider);
    expect(state.ingredients.map((item) => item.id), ['color-1', 'color-0']);
    expect(state.ingredients.first.weight, 0);
    expect(state.ingredients.last.color, red);
    expect(state.rgbResult, red);
  });

  test('minimum-two removal is a no-op and third entries can be removed', () {
    final initial = container.read(mixerProvider);
    controller.removeColor('color-0');
    expect(container.read(mixerProvider), same(initial));
    controller.addColor(red);
    controller.removeColor('color-0');
    expect(container.read(mixerProvider).ingredients.length, 2);
    final minimum = container.read(mixerProvider);
    controller.removeColor(minimum.ingredients.last.id);
    expect(container.read(mixerProvider), same(minimum));
  });

  test('unknown and removed IDs do not mutate or validate weights', () {
    controller.addColor(red);
    final removedId = container.read(mixerProvider).ingredients.last.id;
    controller.removeColor(removedId);
    final before = container.read(mixerProvider);
    for (final id in ['missing', removedId]) {
      controller.setColor(id, blue);
      controller.setWeight(id, double.nan);
      controller.removeColor(id);
    }
    expect(container.read(mixerProvider), same(before));
  });

  test('invalid known weights throw without changing the draft', () {
    final before = container.read(mixerProvider);
    for (final weight in [
      -1.0,
      100.01,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        () => controller.setWeight('color-0', weight),
        throwsArgumentError,
      );
      expect(container.read(mixerProvider), same(before));
    }
  });

  test('weight endpoints make invalid totals recover to an exact result', () {
    controller.setWeight('color-0', 0);
    controller.setWeight('color-1', 0);
    final zero = container.read(mixerProvider);
    expect(zero.hasActiveColors, isFalse);
    expect(zero.fractions, [0, 0]);
    expect(zero.labResult, isNull);
    expect(zero.rgbResult, isNull);
    controller.setColor('color-1', red);
    controller.setWeight('color-1', 100);
    expect(container.read(mixerProvider).selectedResult, red);
    expect(container.read(mixerProvider).fractions, [0, 1]);
    expect(zero.selectedResult, isNull);
  });

  test('mode changes select comparisons while retaining ingredients', () {
    controller.setColor('color-0', RgbColor(0, 0, 0));
    controller.setColor('color-1', RgbColor(255, 255, 255));
    final lab = container.read(mixerProvider);
    controller.setSpace(MixingSpace.rgb);
    final rgb = container.read(mixerProvider);
    expect(lab.selectedResult!.hex, '#777777');
    expect(rgb.selectedResult!.hex, '#808080');
    expect(rgb.ingredients, lab.ingredients);
    expect(rgb.fractions, lab.fractions);
    controller.setSpace(MixingSpace.lab);
    expect(container.read(mixerProvider), lab);
  });

  test('reset restores values and never reuses previously added IDs', () {
    controller.addColor(red);
    final oldId = container.read(mixerProvider).ingredients.last.id;
    controller.removeColor(oldId);
    controller.addColor(blue);
    final secondId = container.read(mixerProvider).ingredients.last.id;
    controller.setWeight('color-0', 0);
    controller.setColor('color-1', red);
    controller.setSpace(MixingSpace.rgb);
    controller.reset();
    expect(container.read(mixerProvider), MixerState.initial());
    controller.addColor(red);
    final newId = container.read(mixerProvider).ingredients.last.id;
    expect({oldId, secondId, newId}.length, 3);
    final before = container.read(mixerProvider);
    controller.setColor(oldId, blue);
    controller.setWeight(secondId, 1);
    expect(container.read(mixerProvider), same(before));
  });

  test(
    'retains draft after all listeners leave until its container ends',
    () async {
      final first = container.listen(mixerProvider, (_, _) {});
      controller.addColor(red);
      controller.setWeight('color-0', 25);
      controller.setSpace(MixingSpace.rgb);
      final edited = container.read(mixerProvider);
      first.close();
      await container.pump();
      final reopened = container.listen(mixerProvider, (_, _) {});
      expect(reopened.read(), edited);
      expect(container.read(mixerProvider.notifier), same(controller));
      reopened.close();
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      expect(fresh.read(mixerProvider), MixerState.initial());
    },
  );

  test('supports many ingredient additions without a color-count cap', () {
    for (var i = 0; i < 100; i++) {
      controller.addColor(red);
    }
    final ingredients = container.read(mixerProvider).ingredients;
    expect(ingredients.length, 102);
    expect(ingredients.map((item) => item.id).toSet().length, 102);
  });
}
