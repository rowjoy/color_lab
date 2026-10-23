import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/color_test/application/matching_game_controller.dart';
import 'package:color_lab/features/color_test/domain/matching_game.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<RgbColor> _firstTargets() => [
  RgbColor(255, 0, 0),
  RgbColor(0, 255, 0),
  RgbColor(0, 0, 255),
  RgbColor(0, 0, 0),
  RgbColor(255, 255, 255),
];
List<RgbColor> _nextTargets() => [
  RgbColor(255, 255, 0),
  RgbColor(0, 255, 255),
  RgbColor(255, 0, 255),
  RgbColor(128, 128, 128),
  RgbColor(1, 2, 3),
];

void main() {
  ProviderContainer containerFor(MatchingTargetGenerator generator) {
    final container = ProviderContainer(
      overrides: [matchingTargetGeneratorProvider.overrideWithValue(generator)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('default generator starts a valid five-target game', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final game = container.read(matchingGameProvider);
    expect(game.targets.length, 5);
    expect(game.targets.toSet().length, 5);
    expect(game.guess.hex, '#808080');
  });

  test(
    'controller delegates edits, frozen submission, all rounds and restart',
    () {
      var calls = 0;
      final container = containerFor(
        () => ++calls == 1 ? _firstTargets() : _nextTargets(),
      );
      final controller = container.read(matchingGameProvider.notifier);
      expect(calls, 1);
      controller.setHue(240);
      controller.setSaturation(1);
      controller.setLightness(.5);
      expect(container.read(matchingGameProvider).guess.hex, '#0000FF');
      controller.submit();
      final feedback = container.read(matchingGameProvider);
      expect(feedback.phase, MatchingPhase.feedback);
      expect(feedback.currentAttempt!.target.hex, '#FF0000');
      expect(feedback.currentAttempt!.guess.hex, '#0000FF');
      controller.setHue(0);
      controller.submit();
      expect(container.read(matchingGameProvider), same(feedback));
      controller.nextRound();
      expect(container.read(matchingGameProvider).roundNumber, 2);
      expect(container.read(matchingGameProvider).guess.hex, '#808080');
      for (var round = 1; round < 5; round++) {
        controller.submit();
        controller.nextRound();
      }
      expect(
        container.read(matchingGameProvider).phase,
        MatchingPhase.complete,
      );
      controller.restart();
      final restarted = container.read(matchingGameProvider);
      expect(restarted.phase, MatchingPhase.editing);
      expect(restarted.target.hex, '#FFFF00');
      expect(restarted.roundNumber, 1);
      expect(restarted.attempts, isEmpty);
      expect(restarted.guess.hex, '#808080');
      expect(calls, 2);
      expect(feedback.currentAttempt!.guess.hex, '#0000FF');
    },
  );

  test(
    'retains feedback after all listeners leave without regenerating',
    () async {
      var calls = 0;
      final container = containerFor(() {
        calls++;
        return _firstTargets();
      });
      final listener = container.listen(matchingGameProvider, (_, _) {});
      final controller = container.read(matchingGameProvider.notifier);
      controller.setSaturation(1);
      controller.submit();
      final submitted = listener.read();
      listener.close();
      await container.pump();
      final reopened = container.listen(matchingGameProvider, (_, _) {});
      addTearDown(reopened.close);
      expect(reopened.read(), same(submitted));
      expect(container.read(matchingGameProvider.notifier), same(controller));
      expect(calls, 1);
    },
  );

  test('containers keep independent games and guesses', () {
    final first = containerFor(_firstTargets);
    final second = containerFor(_nextTargets);
    first.read(matchingGameProvider.notifier).setSaturation(1);
    first.read(matchingGameProvider.notifier).submit();
    expect(
      first.read(matchingGameProvider).currentAttempt!.guess.hex,
      '#FF0000',
    );
    expect(second.read(matchingGameProvider).phase, MatchingPhase.editing);
    expect(second.read(matchingGameProvider).target.hex, '#FFFF00');
    expect(second.read(matchingGameProvider).guess.hex, '#808080');
  });

  test('invalid restart targets preserve the full existing feedback', () {
    var calls = 0;
    final container = containerFor(() => ++calls == 1 ? _firstTargets() : []);
    final controller = container.read(matchingGameProvider.notifier);
    controller.setSaturation(1);
    controller.submit();
    final before = container.read(matchingGameProvider);
    expect(controller.restart, throwsArgumentError);
    expect(container.read(matchingGameProvider), same(before));
    expect(container.read(matchingGameProvider).currentAttempt!.score, 100);
  });

  test(
    'generator failure and invalid edits do not publish replacement state',
    () {
      var calls = 0;
      final container = containerFor(() {
        if (++calls > 1) throw StateError('generation failed');
        return _firstTargets();
      });
      final controller = container.read(matchingGameProvider.notifier);
      final before = container.read(matchingGameProvider);
      expect(() => controller.setHue(360), throwsArgumentError);
      expect(() => controller.setSaturation(double.nan), throwsArgumentError);
      expect(() => controller.setLightness(-1), throwsArgumentError);
      expect(controller.restart, throwsStateError);
      expect(container.read(matchingGameProvider), same(before));
    },
  );

  // Catches watching the generator and silently resetting the active game.
  test(
    'changing the injected generator only affects the next explicit restart',
    () async {
      final container = containerFor(_firstTargets);
      final controller = container.read(matchingGameProvider.notifier);
      controller.setSaturation(1);
      controller.submit();
      final before = container.read(matchingGameProvider);
      container.updateOverrides([
        matchingTargetGeneratorProvider.overrideWithValue(_nextTargets),
      ]);
      await container.pump();
      expect(container.read(matchingGameProvider), same(before));
      controller.restart();
      expect(container.read(matchingGameProvider).target.hex, '#FFFF00');
    },
  );

  test(
    'restart leaves independent Lab drafts and history selection intact',
    () {
      final container = containerFor(_firstTargets);
      final blue = RgbColor(0, 0, 255);
      container.read(mixerProvider.notifier).addColor(blue);
      container.read(harmonyDraftProvider.notifier).setBase(blue);
      container.read(formulaTargetProvider.notifier).setColor(blue);
      container.read(historyFilterProvider.notifier).setQuery('blue');
      final mixer = container.read(mixerProvider);
      final harmony = container.read(harmonyDraftProvider);
      final formula = container.read(formulaTargetProvider);
      final history = container.read(historyFilterProvider);
      container.read(roomColorProvider.notifier).setColor(blue);
      final controller = container.read(matchingGameProvider.notifier);
      controller.submit();
      controller.restart();
      expect(container.read(mixerProvider), same(mixer));
      expect(container.read(harmonyDraftProvider), harmony);
      expect(container.read(formulaTargetProvider), formula);
      expect(container.read(historyFilterProvider), history);
      expect(container.read(roomColorProvider), blue);
    },
  );
}
