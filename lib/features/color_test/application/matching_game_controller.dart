import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../domain/matching_game.dart';

typedef MatchingTargetGenerator = List<RgbColor> Function();

final matchingTargetGeneratorProvider = Provider<MatchingTargetGenerator>(
  (ref) =>
      () => generateMatchingTargets(),
);

/// Retains a game for the application container's lifetime.
final matchingGameProvider =
    NotifierProvider<MatchingGameController, MatchingGame>(
      MatchingGameController.new,
    );

class MatchingGameController extends Notifier<MatchingGame> {
  @override
  MatchingGame build() =>
      MatchingGame.start(ref.read(matchingTargetGeneratorProvider)());

  void setHue(double value) => state = state.setHue(value);
  void setSaturation(double value) => state = state.setSaturation(value);
  void setLightness(double value) => state = state.setLightness(value);
  void submit() => state = state.submit();
  void nextRound() => state = state.advance();

  void restart() {
    final replacement = MatchingGame.start(
      ref.read(matchingTargetGeneratorProvider)(),
    );
    state = replacement;
  }
}
