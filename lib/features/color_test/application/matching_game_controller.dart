import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../games/application/game_adapter_registry.dart';
import '../../games/domain/game_difficulty.dart';
import '../../games/domain/game_id.dart';
import '../../games/domain/game_launch.dart';
import '../../games/domain/game_level.dart';
import '../domain/color_match_level_adapter.dart';
import '../domain/matching_game.dart';

typedef MatchingTargetGenerator = List<RgbColor> Function();

final matchingTargetGeneratorProvider = Provider<MatchingTargetGenerator>(
  (ref) =>
      () => generateMatchingTargets(),
);

typedef MatchingLevelTargetGenerator = List<RgbColor> Function(int count);

final matchingLevelTargetGeneratorProvider =
    Provider<MatchingLevelTargetGenerator>(
      (ref) =>
          (count) => generateMatchingTargets(count: count),
    );

/// Retains a game for the application container's lifetime.
final matchingGameProvider =
    NotifierProvider<MatchingGameController, MatchingGame>(
      MatchingGameController.new,
    );

/// Immutable profile-session identity. Equality is intentionally anchored to
/// the durable attempt ID so one route attempt owns exactly one auto-disposed
/// matching-game provider.
final class MatchingProfileSessionKey {
  factory MatchingProfileSessionKey(GameLaunch launch) {
    if (launch.gameId != GameId.colorMatch) {
      throw ArgumentError.value(
        launch.gameId,
        'launch',
        'Color Match requires a Color Match launch',
      );
    }
    return MatchingProfileSessionKey._(launch);
  }

  const MatchingProfileSessionKey._(this.launch);

  final GameLaunch launch;

  String get attemptId => launch.attemptId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchingProfileSessionKey && other.attemptId == attemptId;

  @override
  int get hashCode => attemptId.hashCode;
}

final profileMatchingGameProvider = NotifierProvider.autoDispose
    .family<
      ProfileMatchingGameController,
      MatchingGame,
      MatchingProfileSessionKey
    >(ProfileMatchingGameController.new);

mixin _MatchingGameEdits on Notifier<MatchingGame> {
  void setHue(double value) => state = state.setHue(value);
  void setSaturation(double value) => state = state.setSaturation(value);
  void setLightness(double value) => state = state.setLightness(value);
  void submit() => state = state.submit();
  void nextRound() => state = state.advance();
}

class MatchingGameController extends Notifier<MatchingGame>
    with _MatchingGameEdits {
  @override
  MatchingGame build() =>
      MatchingGame.start(ref.read(matchingTargetGeneratorProvider)());

  void restart() {
    state = _newGame(state.difficulty, rules: state.rules);
  }

  void start(GameDifficulty difficulty) {
    state = _newGame(difficulty);
  }

  void restorePractice({
    required RgbColor target,
    required RgbColor guess,
    required double hue,
    required double saturation,
    required double lightness,
    required double expectedDeltaE,
  }) {
    final restored = MatchingGame.restorePractice(
      target: target,
      guess: guess,
      hue: hue,
      saturation: saturation,
      lightness: lightness,
      expectedDeltaE: expectedDeltaE,
    );
    state = restored;
  }

  MatchingGame _newGame(GameDifficulty difficulty, {MatchingRules? rules}) {
    final effectiveRules = rules ?? MatchingRules.fromDifficulty(difficulty);
    final targets =
        difficulty == GameDifficulty.medium &&
            effectiveRules == MatchingRules.fromDifficulty(difficulty)
        ? ref.read(matchingTargetGeneratorProvider)()
        : ref.read(matchingLevelTargetGeneratorProvider)(
            effectiveRules.roundCount,
          );
    return MatchingGame.start(
      targets,
      difficulty: difficulty,
      rules: effectiveRules,
    );
  }
}

final class ProfileMatchingGameController extends Notifier<MatchingGame>
    with _MatchingGameEdits {
  ProfileMatchingGameController(this.sessionKey);

  final MatchingProfileSessionKey sessionKey;
  late final ColorMatchLevelLayout _layout;

  @override
  MatchingGame build() {
    final launch = sessionKey.launch;
    final built = ref
        .read(gameAdapterRegistryProvider)
        .adapterFor(GameId.colorMatch)
        .build(launch.descriptor);
    if (built is! ColorMatchLevelLayout ||
        built.level != launch.descriptor.level) {
      throw StateError('Color Match adapter returned an invalid layout.');
    }
    _layout = built;
    return _newGame();
  }

  MatchingGame _newGame() => MatchingGame.start(
    _layout.targets,
    difficulty: switch (sessionKey.launch.descriptor.tier) {
      GameTier.easy => GameDifficulty.easy,
      GameTier.medium => GameDifficulty.medium,
      GameTier.hard => GameDifficulty.hard,
    },
    rules: _layout.rules,
  );
}
