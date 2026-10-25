import 'dart:math' as math;

import '../deterministic_random.dart';
import '../game_id.dart';
import '../game_level.dart';
import '../game_level_adapter.dart';
import '../water_sort_game.dart';

typedef WaterLayoutValidator = bool Function(WaterSortLevelLayout layout);

final class WaterSortOutcome implements GameLevelOutcome {
  const WaterSortOutcome({required this.actualMoves, required this.parMoves});

  final int actualMoves;
  final int parMoves;
}

final class WaterSortLevelAdapter implements GameLevelAdapter {
  WaterSortLevelAdapter({WaterLayoutValidator? validateCandidate})
    : _validateCandidate = validateCandidate ?? _replaysToWin;

  static const int _candidateLimit = 64;
  final WaterLayoutValidator _validateCandidate;

  @override
  GameId get gameId => GameId.waterSort;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  WaterSortLevelLayout build(GameLevelDescriptor descriptor) {
    if (descriptor.gameId != gameId ||
        !supportsVersion(descriptor.generatorVersion)) {
      throw ArgumentError.value(descriptor, 'descriptor');
    }
    for (var attempt = 0; attempt < _candidateLimit; attempt++) {
      final layout = _buildLayout(
        descriptor,
        candidateSeed:
            (descriptor.seed ^
                ((attempt + 1) * 0x9e3779b9) ^
                (descriptor.retrySalt * 0x85ebca6b)) &
            0xffffffff,
        candidateAttempts: attempt + 1,
        usedFallback: false,
        shuffleOrder: true,
      );
      if (_validateCandidate(layout)) return layout;
    }
    final fallback = _buildLayout(
      descriptor,
      candidateSeed: (descriptor.seed ^ 0xa5a5a5a5) & 0xffffffff,
      candidateAttempts: _candidateLimit,
      usedFallback: true,
      shuffleOrder: false,
    );
    if (!_replaysToWin(fallback)) {
      throw StateError('Water Sort fallback certificate is invalid');
    }
    return fallback;
  }

  static WaterSortLevelLayout _buildLayout(
    GameLevelDescriptor descriptor, {
    required int candidateSeed,
    required int candidateAttempts,
    required bool usedFallback,
    required bool shuffleOrder,
  }) {
    final pressure = descriptor.levelPressure;
    final colorCount = math.min(9, 3 + pressure.floor());
    final minimumMixDepth = (colorCount - 1) * 4;
    final scrambleDepth = math.min(
      80,
      math.max(
        minimumMixDepth,
        math.max(8, colorCount * 2 + (pressure * 3).floor()),
      ),
    );
    final random = StableRandom(candidateSeed);
    final order = shuffleOrder
        ? stableShuffle(
            List<int>.generate(colorCount, (index) => index),
            random,
          )
        : List<int>.generate(colorCount, (index) => index);
    final scramble = _reverseScramble(
      colorCount: colorCount,
      depth: scrambleDepth,
      order: order,
      random: random,
    );
    return WaterSortLevelLayout(
      level: descriptor.level,
      colorCount: colorCount,
      scrambleDepth: scrambleDepth,
      tubes: scramble.tubes,
      inverseSolution: scramble.inverseSolution,
      parMoves: scramble.inverseSolution.length,
      candidateAttempts: candidateAttempts,
      usedFallback: usedFallback,
    );
  }

  static _WaterScramble _reverseScramble({
    required int colorCount,
    required int depth,
    required List<int> order,
    required StableRandom random,
  }) {
    final tubes = <List<WaterSegment>>[
      for (var color = 0; color < colorCount; color++)
        [WaterSegment(color, WaterSortGame.tubeCapacity)],
      [],
      [],
    ];
    final recordedInverseMoves = <WaterSortMove>[];
    final macroCount = colorCount - 1;
    final bounceCount = depth - macroCount * 4;
    final firstRoundCount = colorCount ~/ 2;
    var macro = 0;

    for (; macro < firstRoundCount; macro++) {
      _applyMixMacro(
        tubes,
        order[macro * 2],
        order[macro * 2 + 1],
        extraBounces: macro == 0 ? bounceCount : 0,
        recordedInverseMoves: recordedInverseMoves,
      );
    }

    if (colorCount.isOdd && macro < macroCount) {
      _applyMixMacro(
        tubes,
        order.last,
        order.first,
        extraBounces: macro == 0 ? bounceCount : 0,
        recordedInverseMoves: recordedInverseMoves,
      );
      macro++;
    }

    while (macro < macroCount) {
      final eligible = <int>[
        for (var index = 0; index < colorCount; index++)
          if (tubes[index].last.amount >= 2) index,
      ];
      final shuffled = stableShuffle(eligible, random);
      if (shuffled.length < 2) {
        throw StateError('Water Sort reverse scramble exhausted split pairs');
      }
      _applyMixMacro(
        tubes,
        shuffled[0],
        shuffled[1],
        extraBounces: macro == 0 ? bounceCount : 0,
        recordedInverseMoves: recordedInverseMoves,
      );
      macro++;
    }

    if (recordedInverseMoves.length != depth) {
      throw StateError('Water Sort reverse scramble depth mismatch');
    }
    return _WaterScramble(
      tubes: tubes,
      inverseSolution: recordedInverseMoves.reversed.toList(),
    );
  }

  static void _applyMixMacro(
    List<List<WaterSegment>> tubes,
    int firstTube,
    int secondTube, {
    required int extraBounces,
    required List<WaterSortMove> recordedInverseMoves,
  }) {
    final emptyTubes = <int>[
      for (var index = 0; index < tubes.length; index++)
        if (tubes[index].isEmpty) index,
    ];
    if (emptyTubes.length != 2 ||
        firstTube == secondTube ||
        tubes[firstTube].last.color == tubes[secondTube].last.color) {
      throw StateError('Invalid Water Sort mix macro');
    }
    final minimumTopAmount = math.min(
      tubes[firstTube].last.amount,
      tubes[secondTube].last.amount,
    );
    if (minimumTopAmount < 2) {
      throw StateError('Water Sort mix macro cannot split a unit segment');
    }
    final splitAmount = minimumTopAmount > 2 ? 2 : 1;
    var carrier = emptyTubes[0];
    var available = emptyTubes[1];

    _reverseTransfer(
      tubes,
      from: firstTube,
      to: carrier,
      amount: splitAmount,
      recordedInverseMoves: recordedInverseMoves,
    );
    for (var bounce = 0; bounce < extraBounces; bounce++) {
      _reverseTransfer(
        tubes,
        from: carrier,
        to: available,
        amount: splitAmount,
        recordedInverseMoves: recordedInverseMoves,
      );
      final previousCarrier = carrier;
      carrier = available;
      available = previousCarrier;
    }
    _reverseTransfer(
      tubes,
      from: secondTube,
      to: available,
      amount: splitAmount,
      recordedInverseMoves: recordedInverseMoves,
    );
    _reverseTransfer(
      tubes,
      from: carrier,
      to: secondTube,
      amount: splitAmount,
      recordedInverseMoves: recordedInverseMoves,
    );
    _reverseTransfer(
      tubes,
      from: available,
      to: firstTube,
      amount: splitAmount,
      recordedInverseMoves: recordedInverseMoves,
    );
  }

  static void _reverseTransfer(
    List<List<WaterSegment>> tubes, {
    required int from,
    required int to,
    required int amount,
    required List<WaterSortMove> recordedInverseMoves,
  }) {
    final source = tubes[from];
    final target = tubes[to];
    if (source.isEmpty || amount < 1 || source.last.amount < amount) {
      throw StateError('Invalid Water Sort reverse source');
    }
    final targetVolume = target.fold<int>(
      0,
      (sum, segment) => sum + segment.amount,
    );
    final color = source.last.color;
    if (targetVolume + amount > WaterSortGame.tubeCapacity ||
        (target.isNotEmpty && target.last.color == color)) {
      throw StateError('Invalid Water Sort reverse target');
    }
    final top = source.removeLast();
    if (top.amount > amount) {
      source.add(WaterSegment(top.color, top.amount - amount));
    }
    target.add(WaterSegment(color, amount));
    recordedInverseMoves.add(WaterSortMove(source: to, target: from));
  }

  static bool _replaysToWin(WaterSortLevelLayout layout) {
    final game = WaterSortGame.fromLayout(layout);
    if (game.isWon) return false;
    for (final move in layout.inverseSolution) {
      if (!game.pour(move.source, move.target)) return false;
    }
    return game.isWon && game.moves == layout.inverseSolution.length;
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) {
    if (outcome is! WaterSortOutcome ||
        outcome.actualMoves < 0 ||
        outcome.parMoves < 1) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    final actualMoves = math.max(1, outcome.actualMoves);
    final denominator = math.max(outcome.parMoves, actualMoves);
    return (100 * outcome.parMoves / denominator).round().clamp(0, 100);
  }
}

final class _WaterScramble {
  const _WaterScramble({required this.tubes, required this.inverseSolution});

  final List<List<WaterSegment>> tubes;
  final List<WaterSortMove> inverseSolution;
}
