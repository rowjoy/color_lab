import 'dart:math' as math;

import '../../../core/color/color_engine.dart';
import '../../games/domain/deterministic_random.dart';
import '../../games/domain/game_id.dart';
import '../../games/domain/game_level.dart';
import '../../games/domain/game_level_adapter.dart';
import 'matching_game.dart';

final class ColorMatchLevelLayout implements GameLevelLayout {
  factory ColorMatchLevelLayout({
    required int level,
    required MatchingRules rules,
    required List<RgbColor> targets,
    required double minimumSaturation,
    required int requestedMinimumHueSeparation,
    required double minimumHueSeparation,
  }) {
    final safeTargets = List<RgbColor>.unmodifiable(targets);
    if (level < 1 ||
        safeTargets.length != rules.roundCount ||
        safeTargets.toSet().length != safeTargets.length ||
        !minimumSaturation.isFinite ||
        minimumSaturation < .35 ||
        minimumSaturation > .65 ||
        requestedMinimumHueSeparation < 18 ||
        requestedMinimumHueSeparation > 60 ||
        !minimumHueSeparation.isFinite ||
        minimumHueSeparation < 0 ||
        minimumHueSeparation > 360 / rules.roundCount ||
        minimumHueSeparation > requestedMinimumHueSeparation) {
      throw ArgumentError('Invalid Color Match layout');
    }
    return ColorMatchLevelLayout._(
      level: level,
      rules: rules,
      targets: safeTargets,
      minimumSaturation: minimumSaturation,
      requestedMinimumHueSeparation: requestedMinimumHueSeparation,
      minimumHueSeparation: minimumHueSeparation,
    );
  }

  const ColorMatchLevelLayout._({
    required this.level,
    required this.rules,
    required this.targets,
    required this.minimumSaturation,
    required this.requestedMinimumHueSeparation,
    required this.minimumHueSeparation,
  });

  final int level;
  final MatchingRules rules;
  final List<RgbColor> targets;
  final double minimumSaturation;
  final int requestedMinimumHueSeparation;
  final double minimumHueSeparation;

  @override
  String get canonicalSignature =>
      'color-match:v1|level=$level|rounds=${rules.roundCount}|'
      'winning=${rules.winningAverage}|'
      'minimumSaturation=${minimumSaturation.toStringAsFixed(12)}|'
      'requestedHue=$requestedMinimumHueSeparation|'
      'minimumHue=${minimumHueSeparation.toStringAsFixed(12)}|'
      'targets=${targets.map((target) => target.hex).join(',')}';
}

final class ColorMatchOutcome implements GameLevelOutcome {
  const ColorMatchOutcome({required this.averageScore});

  final double averageScore;
}

final class ColorMatchLevelAdapter implements GameLevelAdapter {
  @override
  GameId get gameId => GameId.colorMatch;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  ColorMatchLevelLayout build(GameLevelDescriptor descriptor) {
    if (descriptor.gameId != gameId ||
        !supportsVersion(descriptor.generatorVersion)) {
      throw ArgumentError.value(descriptor, 'descriptor');
    }
    final pressure = descriptor.levelPressure;
    final roundCount = math.min(12, 3 + pressure.floor());
    final winningAverage = math.min(90, 55 + (pressure * 4).floor());
    final minimumSaturation = math.max(.35, .65 - pressure * .03);
    final requestedHue = math.max(18, 60 - (pressure * 3).floor());
    final effectiveHue = math.min(requestedHue.toDouble(), 360 / roundCount);
    final random = StableRandom(
      (descriptor.seed ^ (descriptor.retrySalt * 0x9e3779b9)) & 0xffffffff,
    );
    final targets = generateMatchingTargets(
      random: random,
      count: roundCount,
      minimumSaturation: minimumSaturation,
      minimumHueSeparation: effectiveHue,
    );
    return ColorMatchLevelLayout(
      level: descriptor.level,
      rules: MatchingRules(
        roundCount: roundCount,
        winningAverage: winningAverage,
      ),
      targets: targets,
      minimumSaturation: minimumSaturation,
      requestedMinimumHueSeparation: requestedHue,
      minimumHueSeparation: effectiveHue,
    );
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) {
    if (outcome is! ColorMatchOutcome ||
        !outcome.averageScore.isFinite ||
        outcome.averageScore < 0 ||
        outcome.averageScore > 100) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    return outcome.averageScore.round().clamp(0, 100);
  }
}
