import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../color_test/application/matching_game_controller.dart';
import '../../formula/application/formula_providers.dart';
import '../../harmonies/application/harmony_controller.dart';
import '../../lab/application/lab_controller.dart';
import '../../lab/domain/lab_draft.dart';
import '../../mixer/application/mixer_controller.dart';
import '../../mixer/domain/mixer_state.dart';
import '../domain/experiment_snapshot.dart';

final class ExperimentRestoreException implements Exception {
  const ExperimentRestoreException();
}

abstract interface class ExperimentRestoreService {
  Future<String> restore(ExperimentRecord record);
}

final experimentRestoreServiceProvider = Provider<ExperimentRestoreService>(
  _RiverpodExperimentRestoreService.new,
);

final class _RiverpodExperimentRestoreService
    implements ExperimentRestoreService {
  const _RiverpodExperimentRestoreService(this._ref);

  final Ref _ref;

  @override
  Future<String> restore(ExperimentRecord record) async {
    final snapshot = record.snapshot;
    try {
      switch (snapshot) {
        case LabExperimentSnapshot():
          final draft = LabDraft(
            hue: snapshot.hue,
            saturation: snapshot.saturation,
            lightness: snapshot.lightness,
          );
          _ref.read(labProvider.notifier).restore(draft);
        case MixerExperimentSnapshot():
          final draft = MixerState.restored(
            ingredients: [
              for (final stop in snapshot.stops)
                MixerIngredient(
                  id: stop.id,
                  color: RgbColor.fromHex(stop.hex),
                  weight: stop.weight,
                ),
            ],
            space: MixingSpace.values.byName(snapshot.space.name),
          );
          _ref.read(mixerProvider.notifier).restore(draft);
        case HarmonyExperimentSnapshot():
          final base = RgbColor.fromHex(snapshot.baseHex);
          final mode = HarmonyMode.values.byName(snapshot.mode.name);
          _ref
              .read(harmonyDraftProvider.notifier)
              .setSelection(base: base, mode: mode);
        case FormulaExperimentSnapshot():
          final target = RgbColor.fromHex(snapshot.targetHex);
          _ref.read(formulaTargetProvider.notifier).setColor(target);
        case MatchingExperimentSnapshot():
          final target = RgbColor.fromHex(snapshot.targetHex);
          final guess = RgbColor.fromHex(snapshot.guessHex);
          _ref
              .read(matchingGameProvider.notifier)
              .restorePractice(
                target: target,
                guess: guess,
                hue: snapshot.hue,
                saturation: snapshot.saturation,
                lightness: snapshot.lightness,
                expectedDeltaE: snapshot.deltaE,
              );
        case UnknownExperimentSnapshot():
          throw const ExperimentRestoreException();
      }
      return '/learn/experiment/${snapshot.tool.name}';
    } on ExperimentRestoreException {
      rethrow;
    } on Object {
      throw const ExperimentRestoreException();
    }
  }
}
