import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/color_test/application/matching_game_controller.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/lab/application/lab_controller.dart';
import 'package:color_lab/features/lab/domain/lab_draft.dart';
import 'package:color_lab/features/learning/application/experiment_capture_service.dart';
import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/mixer/domain/mixer_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures exact typed state for all five experiment tools', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(labProvider.notifier)
        .restore(const LabDraft(hue: 120, saturation: .4, lightness: .6));
    container
        .read(mixerProvider.notifier)
        .restore(
          MixerState.restored(
            ingredients: [
              MixerIngredient(
                id: 'color-4',
                color: RgbColor.fromHex('#112233'),
                weight: 25,
              ),
              MixerIngredient(
                id: 'color-5',
                color: RgbColor.fromHex('#AABBCC'),
                weight: 75,
              ),
            ],
            space: MixingSpace.rgb,
          ),
        );
    container
        .read(harmonyDraftProvider.notifier)
        .setSelection(
          base: RgbColor.fromHex('#336699'),
          mode: HarmonyMode.triadic,
        );
    container
        .read(formulaTargetProvider.notifier)
        .setColor(RgbColor.fromHex('#ABCDEF'));
    final guess = HslColor(0, 0, .5).toRgb();
    final target = RgbColor.fromHex('#112233');
    container
        .read(matchingGameProvider.notifier)
        .restorePractice(
          target: target,
          guess: guess,
          hue: 0,
          saturation: 0,
          lightness: .5,
          expectedDeltaE: deltaE76(target.toLab(), guess.toLab()),
        );

    final service = container.read(experimentCaptureServiceProvider);
    expect(
      service.capture(ExperimentTool.lab).snapshot,
      const LabExperimentSnapshot(hue: 120, saturation: .4, lightness: .6),
    );
    final mixer = service.capture(ExperimentTool.mixer);
    expect(mixer.snapshot, isA<MixerExperimentSnapshot>());
    expect(
      (mixer.snapshot as MixerExperimentSnapshot).space,
      MixerExperimentSpace.rgb,
    );
    expect((mixer.snapshot as MixerExperimentSnapshot).stops.map((e) => e.id), [
      'color-4',
      'color-5',
    ]);
    final harmony = service.capture(ExperimentTool.harmonies);
    expect(
      harmony.snapshot,
      const HarmonyExperimentSnapshot(
        baseHex: '#336699',
        mode: HarmonyExperimentMode.triadic,
      ),
    );
    expect(
      harmony.results,
      generateHarmony(RgbColor.fromHex('#336699'), mode: HarmonyMode.triadic),
    );
    expect(
      service.capture(ExperimentTool.formula).snapshot,
      const FormulaExperimentSnapshot(targetHex: '#ABCDEF'),
    );
    final matching = service.capture(ExperimentTool.matching).snapshot;
    expect(matching, isA<MatchingExperimentSnapshot>());
    expect((matching as MatchingExperimentSnapshot).targetHex, '#112233');
    expect(matching.guessHex, guess.hex);
  });
}
