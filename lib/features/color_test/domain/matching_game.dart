import '../../../core/color/color_engine.dart';
import '../../games/domain/game_difficulty.dart';

enum MatchingPhase { editing, feedback, complete }

final class MatchingRules {
  const MatchingRules({required this.roundCount, required this.winningAverage})
    : assert(roundCount >= 3 && roundCount <= 12),
      assert(winningAverage >= 0 && winningAverage <= 100);

  factory MatchingRules.fromDifficulty(GameDifficulty difficulty) =>
      switch (difficulty) {
        GameDifficulty.easy => const MatchingRules(
          roundCount: 3,
          winningAverage: 55,
        ),
        GameDifficulty.medium => const MatchingRules(
          roundCount: 5,
          winningAverage: 65,
        ),
        GameDifficulty.hard => const MatchingRules(
          roundCount: 8,
          winningAverage: 75,
        ),
      };

  final int roundCount;
  final int winningAverage;

  @override
  bool operator ==(Object other) =>
      other is MatchingRules &&
      other.roundCount == roundCount &&
      other.winningAverage == winningAverage;

  @override
  int get hashCode => Object.hash(roundCount, winningAverage);
}

/// The exact displayed color pair frozen at submission.
final class MatchingAttempt {
  factory MatchingAttempt({required RgbColor target, required RgbColor guess}) {
    final deltaE = deltaE76(target.toLab(), guess.toLab());
    return MatchingAttempt._(target, guess, deltaE, matchingScore(deltaE));
  }

  const MatchingAttempt._(this.target, this.guess, this.deltaE, this.score);

  final RgbColor target;
  final RgbColor guess;
  final double deltaE;
  final int score;

  bool get isExact => target == guess;
}

/// Immutable color-match session retaining raw HSL at neutral endpoints.
final class MatchingGame {
  factory MatchingGame.start(
    Iterable<RgbColor> targets, {
    GameDifficulty difficulty = GameDifficulty.medium,
    MatchingRules? rules,
  }) {
    final snapshot = List<RgbColor>.unmodifiable(targets);
    final effectiveRules = rules ?? MatchingRules.fromDifficulty(difficulty);
    if (snapshot.length != effectiveRules.roundCount ||
        snapshot.toSet().length != snapshot.length) {
      throw ArgumentError.value(
        targets,
        'targets',
        'Expected ${effectiveRules.roundCount} distinct RGB colors',
      );
    }
    return MatchingGame._(
      targets: snapshot,
      difficulty: difficulty,
      rules: effectiveRules,
      roundIndex: 0,
      hue: 0,
      saturation: 0,
      lightness: .5,
      attempts: const [],
      phase: MatchingPhase.editing,
    );
  }

  factory MatchingGame.restorePractice({
    required RgbColor target,
    required RgbColor guess,
    required double hue,
    required double saturation,
    required double lightness,
    required double expectedDeltaE,
  }) {
    final reconstructed = HslColor(hue, saturation, lightness).toRgb();
    final computedDelta = deltaE76(target.toLab(), reconstructed.toLab());
    if (reconstructed != guess ||
        !expectedDeltaE.isFinite ||
        (computedDelta - expectedDeltaE).abs() > 1e-9) {
      throw ArgumentError('Inconsistent matching experiment payload.');
    }
    final fillers = [
      RgbColor(0, 0, 0),
      RgbColor(255, 255, 255),
      RgbColor(255, 0, 0),
      RgbColor(0, 255, 0),
      RgbColor(0, 0, 255),
    ].where((color) => color != target).take(2).toList(growable: false);
    return MatchingGame.start(
      [target, ...fillers],
      difficulty: GameDifficulty.easy,
      rules: const MatchingRules(roundCount: 3, winningAverage: 55),
    ).setHue(hue).setSaturation(saturation).setLightness(lightness).submit();
  }

  const MatchingGame._({
    required this.targets,
    required this.difficulty,
    required this.rules,
    required this.roundIndex,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.attempts,
    required this.phase,
  });

  final List<RgbColor> targets;
  final GameDifficulty difficulty;
  final MatchingRules rules;
  final int roundIndex;
  final double hue;
  final double saturation;
  final double lightness;
  final List<MatchingAttempt> attempts;
  final MatchingPhase phase;

  RgbColor get target => targets[roundIndex];
  RgbColor get guess => HslColor(hue, saturation, lightness).toRgb();
  int get roundNumber => roundIndex + 1;
  MatchingAttempt? get currentAttempt =>
      phase == MatchingPhase.feedback ? attempts.last : null;
  int get totalScore => attempts.fold(0, (sum, attempt) => sum + attempt.score);
  double get averageScore =>
      attempts.isEmpty ? 0 : totalScore / attempts.length;
  bool get won =>
      phase == MatchingPhase.complete && averageScore >= rules.winningAverage;
  int get rewardCoins => won ? difficulty.rewardCoins : 0;

  MatchingGame setHue(double value) {
    if (!value.isFinite || value < 0 || value >= 360) {
      throw ArgumentError.value(value, 'hue', 'Must be finite and in [0, 360)');
    }
    return phase == MatchingPhase.editing ? _copyWith(hue: value) : this;
  }

  MatchingGame setSaturation(double value) {
    _validateUnit(value, 'saturation');
    return phase == MatchingPhase.editing ? _copyWith(saturation: value) : this;
  }

  MatchingGame setLightness(double value) {
    _validateUnit(value, 'lightness');
    return phase == MatchingPhase.editing ? _copyWith(lightness: value) : this;
  }

  MatchingGame submit() {
    if (phase != MatchingPhase.editing) return this;
    return _copyWith(
      attempts: List<MatchingAttempt>.unmodifiable([
        ...attempts,
        MatchingAttempt(target: target, guess: guess),
      ]),
      phase: MatchingPhase.feedback,
    );
  }

  MatchingGame advance() {
    if (phase != MatchingPhase.feedback) return this;
    if (roundIndex == targets.length - 1) {
      return _copyWith(phase: MatchingPhase.complete);
    }
    return _copyWith(
      roundIndex: roundIndex + 1,
      hue: 0,
      saturation: 0,
      lightness: .5,
      phase: MatchingPhase.editing,
    );
  }

  MatchingGame _copyWith({
    int? roundIndex,
    double? hue,
    double? saturation,
    double? lightness,
    List<MatchingAttempt>? attempts,
    MatchingPhase? phase,
  }) => MatchingGame._(
    targets: targets,
    difficulty: difficulty,
    rules: rules,
    roundIndex: roundIndex ?? this.roundIndex,
    hue: hue ?? this.hue,
    saturation: saturation ?? this.saturation,
    lightness: lightness ?? this.lightness,
    attempts: attempts ?? this.attempts,
    phase: phase ?? this.phase,
  );
}

void _validateUnit(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, name, 'Must be finite and in [0, 1]');
  }
}
