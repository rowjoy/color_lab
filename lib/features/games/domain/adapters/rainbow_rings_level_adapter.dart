import 'dart:math' as math;

import '../deterministic_random.dart';
import '../game_id.dart';
import '../game_level.dart';
import '../game_level_adapter.dart';
import '../rainbow_rings_game.dart';

typedef RainbowLayoutValidator = bool Function(RainbowRingsLevelLayout layout);

final class RainbowRingsMoveOutcome implements GameLevelOutcome {
  const RainbowRingsMoveOutcome({
    required this.actualMoves,
    required this.parMoves,
  });

  final int actualMoves;
  final int parMoves;
}

final class RainbowRingsLevelAdapter implements GameLevelAdapter {
  RainbowRingsLevelAdapter({RainbowLayoutValidator? validateCandidate})
    : _validateCandidate = validateCandidate ?? _replaysToWin;

  static const int _candidateLimit = 64;
  final RainbowLayoutValidator _validateCandidate;

  @override
  GameId get gameId => GameId.rainbowRings;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  RainbowRingsLevelLayout build(GameLevelDescriptor descriptor) {
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
      throw StateError('Rainbow Rings fallback certificate is invalid');
    }
    return fallback;
  }

  static RainbowRingsLevelLayout _buildLayout(
    GameLevelDescriptor descriptor, {
    required int candidateSeed,
    required int candidateAttempts,
    required bool usedFallback,
    required bool shuffleOrder,
  }) {
    final pressure = descriptor.levelPressure;
    final colorCount = math.min(6, 3 + (pressure / 2).floor());
    final capacity = math.min(8, 4 + (pressure / 3).floor());
    final scrambleDepth = math.min(
      120,
      math.max(colorCount * capacity, 10) + (pressure * 3).floor(),
    );
    final parMoves = (colorCount * capacity * .9 + colorCount).round();
    final random = StableRandom(candidateSeed);
    final order = shuffleOrder
        ? stableShuffle(
            List<int>.generate(colorCount, (index) => index),
            random,
          )
        : List<int>.generate(colorCount, (index) => index);
    final ringColors = <int>[
      for (var color = 0; color < colorCount; color++)
        for (var ring = 0; ring < capacity; ring++) color,
    ];
    final stacks = <List<int>>[
      for (var color = 0; color < colorCount; color++)
        [for (var ring = 0; ring < capacity; ring++) color * capacity + ring],
      [],
      [],
    ];
    final inverseSolution = _reverseCycle(
      stacks: stacks,
      order: order,
      capacity: capacity,
      depth: scrambleDepth,
    );
    return RainbowRingsLevelLayout(
      level: descriptor.level,
      colorCount: colorCount,
      capacity: capacity,
      scrambleDepth: scrambleDepth,
      ringColors: ringColors,
      stacks: stacks,
      inverseSolution: inverseSolution,
      parMoves: parMoves,
      candidateAttempts: candidateAttempts,
      usedFallback: usedFallback,
    );
  }

  static List<RainbowRingsMove> _reverseCycle({
    required List<List<int>> stacks,
    required List<int> order,
    required int capacity,
    required int depth,
  }) {
    final recordedInverseMoves = <RainbowRingsMove>[];
    final groupSize = capacity - 1;
    final baseDepth = groupSize * (order.length + 1);
    final bounceCount = depth - baseDepth;
    if (bounceCount < 0) {
      throw StateError('Rainbow Rings depth is too small for reverse cycle');
    }
    var carrier = order.length;
    var available = order.length + 1;
    final firstPeg = order.first;

    _reverseOneRing(
      stacks,
      from: firstPeg,
      to: carrier,
      capacity: capacity,
      recordedInverseMoves: recordedInverseMoves,
    );
    for (var bounce = 0; bounce < bounceCount; bounce++) {
      _reverseOneRing(
        stacks,
        from: carrier,
        to: available,
        capacity: capacity,
        recordedInverseMoves: recordedInverseMoves,
      );
      final previousCarrier = carrier;
      carrier = available;
      available = previousCarrier;
    }
    for (var ring = 1; ring < groupSize; ring++) {
      _reverseOneRing(
        stacks,
        from: firstPeg,
        to: carrier,
        capacity: capacity,
        recordedInverseMoves: recordedInverseMoves,
      );
    }
    for (var index = 1; index < order.length; index++) {
      for (var ring = 0; ring < groupSize; ring++) {
        _reverseOneRing(
          stacks,
          from: order[index],
          to: order[index - 1],
          capacity: capacity,
          recordedInverseMoves: recordedInverseMoves,
        );
      }
    }
    for (var ring = 0; ring < groupSize; ring++) {
      _reverseOneRing(
        stacks,
        from: carrier,
        to: order.last,
        capacity: capacity,
        recordedInverseMoves: recordedInverseMoves,
      );
    }
    if (recordedInverseMoves.length != depth ||
        stacks.where((stack) => stack.isEmpty).length != 2) {
      throw StateError('Rainbow Rings reverse cycle depth mismatch');
    }
    return recordedInverseMoves.reversed.toList();
  }

  static void _reverseOneRing(
    List<List<int>> stacks, {
    required int from,
    required int to,
    required int capacity,
    required List<RainbowRingsMove> recordedInverseMoves,
  }) {
    final source = stacks[from];
    final target = stacks[to];
    if (source.isEmpty || target.length >= capacity) {
      throw StateError('Invalid Rainbow Rings reverse move');
    }
    final sourceSlot = source.length - 1;
    final destinationSlot = target.length;
    final ringId = source.removeLast();
    target.add(ringId);
    recordedInverseMoves.add(
      RainbowRingsMove(
        ringId: ringId,
        sourcePeg: to,
        sourceSlot: destinationSlot,
        destinationPeg: from,
        destinationSlot: sourceSlot,
      ),
    );
  }

  static bool _replaysToWin(RainbowRingsLevelLayout layout) {
    final game = RainbowRingsGame.fromLayout(layout);
    if (game.isWon) return false;
    for (final move in layout.inverseSolution) {
      final source = game.stacks[move.sourcePeg];
      final target = game.stacks[move.destinationPeg];
      if (source.length - 1 != move.sourceSlot ||
          source.last != move.ringId ||
          target.length != move.destinationSlot ||
          !game.tapPeg(move.sourcePeg).changed ||
          !game.tapPeg(move.destinationPeg).changed) {
        return false;
      }
    }
    return game.isWon && game.moves == layout.inverseSolution.length;
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) {
    if (outcome is! RainbowRingsMoveOutcome ||
        outcome.actualMoves < 0 ||
        outcome.parMoves < 1) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    final actualMoves = math.max(1, outcome.actualMoves);
    final denominator = math.max(outcome.parMoves, actualMoves);
    return (100 * outcome.parMoves / denominator).round().clamp(0, 100);
  }
}
