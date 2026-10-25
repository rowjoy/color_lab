import 'dart:math' as math;

import '../bubble_shooter_game.dart';
import '../deterministic_random.dart';
import '../game_id.dart';
import '../game_level.dart';
import '../game_level_adapter.dart';

typedef BubbleLayoutValidator = bool Function(BubbleShooterLevelLayout layout);

final class BubbleShooterOutcome implements GameLevelOutcome {
  const BubbleShooterOutcome({
    required this.rawScore,
    required this.shotsFired,
    required this.parShots,
  });

  final int rawScore;
  final int shotsFired;
  final int parShots;
}

final class BubbleShooterLevelAdapter implements GameLevelAdapter {
  BubbleShooterLevelAdapter({BubbleLayoutValidator? validateCandidate})
    : _validateCandidate = validateCandidate ?? _playsToCompletion;

  static const int _candidateLimit = 64;
  final BubbleLayoutValidator _validateCandidate;

  @override
  GameId get gameId => GameId.bubbleShooter;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  BubbleShooterLevelLayout build(GameLevelDescriptor descriptor) {
    if (descriptor.gameId != gameId ||
        !supportsVersion(descriptor.generatorVersion)) {
      throw ArgumentError.value(descriptor, 'descriptor');
    }
    for (var attempt = 0; attempt < _candidateLimit; attempt++) {
      final candidate = _buildLayout(
        descriptor,
        candidateSeed:
            (descriptor.seed ^ ((attempt + 1) * 0x9e3779b9)) & 0xffffffff,
        usedFallback: false,
        shuffleColors: true,
      );
      if (_validateCandidate(candidate)) return candidate;
    }
    return _buildLayout(
      descriptor,
      candidateSeed: (descriptor.seed ^ 0xa5a5a5a5) & 0xffffffff,
      usedFallback: true,
      shuffleColors: false,
    );
  }

  BubbleShooterLevelLayout _buildLayout(
    GameLevelDescriptor descriptor, {
    required int candidateSeed,
    required bool usedFallback,
    required bool shuffleColors,
  }) {
    final pressure = descriptor.levelPressure;
    final colorCount = math.min(6, 3 + (pressure / 2).floor());
    final occupiedRows = math.min(8, 4 + (pressure / 2).floor());
    final dropEvery = math.max(4, 8 - (pressure / 2).floor());
    final random = StableRandom(candidateSeed);
    final colors = shuffleColors
        ? stableShuffle(
            List<int>.generate(colorCount, (color) => color),
            random,
          )
        : List<int>.generate(colorCount, (color) => color);
    final groupCount = math.min(3, colorCount);
    final activeWidth = groupCount * 3;
    final grid = List.generate(
      9,
      (_) => List<int?>.filled(BubbleShooterGame.columns, null),
    );
    final certificate = <BubbleShooterPlacement>[];
    for (var group = 0; group < groupCount; group++) {
      final color = colors[group];
      final column = group * 3;
      grid[0][column] = color;
      grid[0][column + 1] = color;
      certificate.add(
        BubbleShooterPlacement(row: 0, column: column + 2, color: color),
      );
    }
    for (var row = 1; row < occupiedRows; row++) {
      for (var column = 0; column < activeWidth; column++) {
        grid[row][column] =
            colors[(row + column + random.nextInt(colorCount)) % colorCount];
      }
    }
    final initialCount = grid.expand((row) => row).whereType<int>().length;
    return BubbleShooterLevelLayout(
      level: descriptor.level,
      colorCount: colorCount,
      occupiedRows: occupiedRows,
      dropEvery: dropEvery,
      currentColor: certificate.first.color,
      nextColor: certificate.length > 1
          ? certificate[1].color
          : certificate.first.color,
      runtimeSeed: random.nextUint32(),
      grid: grid,
      placementCertificate: certificate,
      parShots: math.max(1, (initialCount / 3).ceil()),
      usedFallback: usedFallback,
    );
  }

  static bool _playsToCompletion(BubbleShooterLevelLayout layout) {
    final game = BubbleShooterGame.fromLayout(layout);
    for (final placement in layout.placementCertificate) {
      final result = game.landBubble(
        placement.row,
        placement.column,
        placement.color,
      );
      if (result.lost) return false;
    }
    return game.isWon;
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) {
    if (outcome is! BubbleShooterOutcome ||
        outcome.shotsFired < 0 ||
        outcome.parShots < 1) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    final actual = math.max(1, outcome.shotsFired);
    final denominator = math.max(outcome.parShots, actual);
    return (100 * outcome.parShots / denominator).round().clamp(0, 100);
  }
}
