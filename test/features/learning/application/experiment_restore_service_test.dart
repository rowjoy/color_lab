import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/color_test/application/matching_game_controller.dart';
import 'package:color_lab/features/color_test/domain/matching_game.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/lab/application/lab_controller.dart';
import 'package:color_lab/features/lab/domain/lab_draft.dart';
import 'package:color_lab/features/learning/application/experiment_restore_service.dart';
import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/mixer/domain/mixer_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late ExperimentRestoreService service;
  final now = DateTime.utc(2026, 10, 28);

  ExperimentRecord record(String id, ExperimentSnapshot snapshot) =>
      ExperimentRecord(
        id: id,
        title: id,
        lessonId: null,
        inputHexes: const ['#112233'],
        resultHexes: const ['#445566'],
        snapshot: snapshot,
        observation: '',
        createdAt: now,
        updatedAt: now,
      );

  setUp(() {
    container = ProviderContainer();
    service = container.read(experimentRestoreServiceProvider);
  });
  tearDown(() => container.dispose());

  test('restores exact Lab HSL and canonical route', () async {
    const snapshot = LabExperimentSnapshot(
      hue: 275,
      saturation: .25,
      lightness: .74,
    );
    expect(
      await service.restore(record('lab-note', snapshot)),
      '/learn/experiment/lab',
    );
    expect(
      container.read(labProvider),
      const LabDraft(hue: 275, saturation: .25, lightness: .74),
    );
  });

  test('restores Mixer stops and keeps future ingredient IDs unique', () async {
    final snapshot = MixerExperimentSnapshot(
      space: MixerExperimentSpace.rgb,
      stops: [
        MixerExperimentStop(id: 'color-7', hex: '#112233', weight: 30),
        MixerExperimentStop(id: 'color-8', hex: '#AABBCC', weight: 70),
      ],
    );
    expect(
      await service.restore(record('mixer-note', snapshot)),
      '/learn/experiment/mixer',
    );
    final restored = container.read(mixerProvider);
    expect(restored.space, MixingSpace.rgb);
    expect(restored.ingredients.map((item) => item.id), ['color-7', 'color-8']);
    expect(restored.ingredients.map((item) => item.color.hex), [
      '#112233',
      '#AABBCC',
    ]);
    expect(restored.ingredients.map((item) => item.weight), [30, 70]);
    container.read(mixerProvider.notifier).addColor(RgbColor(1, 2, 3));
    expect(container.read(mixerProvider).ingredients.last.id, 'color-9');
  });

  test('restores Harmony and Formula through existing controllers', () async {
    const harmony = HarmonyExperimentSnapshot(
      baseHex: '#123456',
      mode: HarmonyExperimentMode.splitComplementary,
    );
    expect(
      await service.restore(record('harmony-note', harmony)),
      '/learn/experiment/harmonies',
    );
    expect(container.read(harmonyDraftProvider).base.hex, '#123456');
    expect(
      container.read(harmonyDraftProvider).mode,
      HarmonyMode.splitComplementary,
    );

    const formula = FormulaExperimentSnapshot(targetHex: '#ABCDEF');
    expect(
      await service.restore(record('formula-note', formula)),
      '/learn/experiment/formula',
    );
    expect(container.read(formulaTargetProvider).hex, '#ABCDEF');
  });

  test(
    'restores Matching target guess and delta only into practice state',
    () async {
      final target = RgbColor.fromHex('#FF0000');
      final guess = RgbColor.fromHex('#0000FF');
      final delta = deltaE76(target.toLab(), guess.toLab());
      final snapshot = MatchingExperimentSnapshot(
        targetHex: target.hex,
        guessHex: guess.hex,
        hue: 240,
        saturation: 1,
        lightness: .5,
        deltaE: delta,
      );
      expect(
        await service.restore(record('matching-note', snapshot)),
        '/learn/experiment/matching',
      );
      final game = container.read(matchingGameProvider);
      expect(game.phase, MatchingPhase.feedback);
      expect(game.target, target);
      expect(game.guess, guess);
      expect(game.currentAttempt!.deltaE, closeTo(delta, 1e-12));
      expect(game.rewardCoins, 0);
    },
  );

  test(
    'restore rejects unknown versions without changing unrelated drafts',
    () async {
      container.read(historyFilterProvider.notifier).setQuery('keep-me');
      final raw = record(
        'future-note',
        const FormulaExperimentSnapshot(targetHex: '#112233'),
      ).toMap();
      final futureMap = Map<String, Object?>.from(raw)
        ..['snapshot'] = {
          'schemaVersion': 9,
          'tool': 'formula',
          'futureTarget': 'oklch',
        };
      final future = ExperimentRecord.fromMap(futureMap);
      final beforeFormula = container.read(formulaTargetProvider);

      await expectLater(
        service.restore(future),
        throwsA(isA<ExperimentRestoreException>()),
      );
      expect(container.read(formulaTargetProvider), beforeFormula);
      expect(container.read(historyFilterProvider).query, 'keep-me');
    },
  );

  test(
    'inconsistent Matching payload is rejected without publishing a draft',
    () async {
      final before = container.read(matchingGameProvider);
      const snapshot = MatchingExperimentSnapshot(
        targetHex: '#FF0000',
        guessHex: '#00FF00',
        hue: 240,
        saturation: 1,
        lightness: .5,
        deltaE: 1,
      );
      await expectLater(
        service.restore(record('bad-match', snapshot)),
        throwsA(isA<ExperimentRestoreException>()),
      );
      expect(container.read(matchingGameProvider), same(before));
    },
  );
}
