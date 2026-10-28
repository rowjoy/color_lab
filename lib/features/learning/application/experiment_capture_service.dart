import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../color_test/application/matching_game_controller.dart';
import '../../formula/application/formula_providers.dart';
import '../../harmonies/application/harmony_controller.dart';
import '../../lab/application/lab_controller.dart';
import '../../mixer/application/mixer_controller.dart';
import '../domain/experiment_snapshot.dart';

final class ExperimentCaptureException implements Exception {
  const ExperimentCaptureException();
}

final class CapturedExperiment {
  CapturedExperiment({
    required this.snapshot,
    required Iterable<RgbColor> results,
  }) : results = List.unmodifiable(
         results.map((color) => RgbColor(color.red, color.green, color.blue)),
       ) {
    if (this.results.isEmpty) throw const ExperimentCaptureException();
  }

  final ExperimentSnapshot snapshot;
  final List<RgbColor> results;
}

abstract interface class ExperimentCaptureService {
  CapturedExperiment capture(ExperimentTool tool);
}

final experimentCaptureServiceProvider = Provider<ExperimentCaptureService>(
  _RiverpodExperimentCaptureService.new,
);

final class _RiverpodExperimentCaptureService
    implements ExperimentCaptureService {
  const _RiverpodExperimentCaptureService(this._ref);

  final Ref _ref;

  @override
  CapturedExperiment capture(ExperimentTool tool) {
    try {
      return switch (tool) {
        ExperimentTool.lab => _lab(),
        ExperimentTool.mixer => _mixer(),
        ExperimentTool.harmonies => _harmonies(),
        ExperimentTool.formula => _formula(),
        ExperimentTool.matching => _matching(),
      };
    } on ExperimentCaptureException {
      rethrow;
    } on Object {
      throw const ExperimentCaptureException();
    }
  }

  CapturedExperiment _lab() {
    final draft = _ref.read(labProvider);
    return CapturedExperiment(
      snapshot: LabExperimentSnapshot(
        hue: draft.hue,
        saturation: draft.saturation,
        lightness: draft.lightness,
      ),
      results: [draft.color],
    );
  }

  CapturedExperiment _mixer() {
    final draft = _ref.read(mixerProvider);
    final result = draft.selectedResult;
    if (result == null) throw const ExperimentCaptureException();
    return CapturedExperiment(
      snapshot: MixerExperimentSnapshot(
        space: MixerExperimentSpace.values.byName(draft.space.name),
        stops: [
          for (final ingredient in draft.ingredients)
            MixerExperimentStop(
              id: ingredient.id,
              hex: ingredient.color.hex,
              weight: ingredient.weight,
            ),
        ],
      ),
      results: [result],
    );
  }

  CapturedExperiment _harmonies() {
    final draft = _ref.read(harmonyDraftProvider);
    return CapturedExperiment(
      snapshot: HarmonyExperimentSnapshot(
        baseHex: draft.base.hex,
        mode: HarmonyExperimentMode.values.byName(draft.mode.name),
      ),
      results: generateHarmony(draft.base, mode: draft.mode),
    );
  }

  CapturedExperiment _formula() {
    final target = _ref.read(formulaTargetProvider);
    return CapturedExperiment(
      snapshot: FormulaExperimentSnapshot(targetHex: target.hex),
      results: [target],
    );
  }

  CapturedExperiment _matching() {
    final game = _ref.read(matchingGameProvider);
    final guess = game.guess;
    return CapturedExperiment(
      snapshot: MatchingExperimentSnapshot(
        targetHex: game.target.hex,
        guessHex: guess.hex,
        hue: game.hue,
        saturation: game.saturation,
        lightness: game.lightness,
        deltaE: deltaE76(game.target.toLab(), guess.toLab()),
      ),
      results: [guess],
    );
  }
}
