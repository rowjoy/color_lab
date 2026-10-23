import '../../../core/color/color_engine.dart';

enum MatchingPhase { editing, feedback, complete }

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

/// Immutable five-round session retaining raw HSL even at neutral endpoints.
final class MatchingGame {
  factory MatchingGame.start(Iterable<RgbColor> targets) {
    final snapshot = List<RgbColor>.unmodifiable(targets);
    if (snapshot.length != 5 || snapshot.toSet().length != 5) {
      throw ArgumentError.value(
        targets,
        'targets',
        'Expected five distinct RGB colors',
      );
    }
    return MatchingGame._(
      targets: snapshot,
      roundIndex: 0,
      hue: 0,
      saturation: 0,
      lightness: .5,
      attempts: const [],
      phase: MatchingPhase.editing,
    );
  }

  const MatchingGame._({
    required this.targets,
    required this.roundIndex,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.attempts,
    required this.phase,
  });

  final List<RgbColor> targets;
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
    if (roundIndex == 4) return _copyWith(phase: MatchingPhase.complete);
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
