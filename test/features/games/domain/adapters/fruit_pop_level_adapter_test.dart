import 'package:color_lab/features/games/domain/adapters/fruit_pop_level_adapter.dart';
import 'package:color_lab/features/games/domain/fruit_pop_game.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GameLevelDescriptor descriptor(int level, {int retrySalt = 0}) =>
      GameLevelDescriptor(
        gameId: GameId.fruitPop,
        level: level,
        seed: (level * 7919 + retrySalt * 104729) & 0xffffffff,
        generatorVersion: 1,
        retrySalt: retrySalt,
        fingerprint: '0' * 64,
        tier: GameTier.forLevel(level),
        levelPressure: levelPressureFor(level),
      );

  test('generator-v1 freezes bounds and accepts simulated playable boards', () {
    final adapter = FruitPopLevelAdapter();
    const fixtures = [
      (1, 5, 300, 22, 0),
      (9, 5, 1092, 21, 0),
      (10, 5, 1130, 21, 0),
      (19, 6, 1362, 20, 1),
      (20, 6, 1380, 20, 1),
      (30, 6, 1527, 20, 1),
      (100, 6, 1961, 19, 3),
      (1000000, 6, 3000, 14, 8),
    ];

    for (final (level, types, target, baseMoves, blockers) in fixtures) {
      final layout = adapter.build(descriptor(level));
      final game = FruitPopGame.fromLayout(layout);
      expect(layout.typeCount, types, reason: 'Level $level types');
      expect(layout.target, target, reason: 'Level $level target');
      expect(
        layout.baseMoveBudget,
        baseMoves,
        reason: 'Level $level base moves',
      );
      expect(layout.moveBudget, inInclusiveRange(baseMoves, 30));
      expect(layout.blockers, hasLength(blockers));
      expect(
        layout.simulationWins,
        greaterThanOrEqualTo(8),
        reason: 'Level $level simulation wins',
      );
      expect(layout.simulationCount, 16);
      expect(game.findMatches(), isEmpty);
      expect(game.hasPossibleMove, isTrue);
    }
  });

  test('same descriptor freezes board, blockers, rules, and refill stream', () {
    final adapter = FruitPopLevelAdapter();
    final first = adapter.build(descriptor(20));
    final repeated = adapter.build(descriptor(20));
    final retried = adapter.build(descriptor(20, retrySalt: 1));

    expect(repeated.canonicalSignature, first.canonicalSignature);
    expect(repeated.board, first.board);
    expect(repeated.blockers, first.blockers);
    expect(retried.canonicalSignature, isNot(first.canonicalSignature));

    final move = firstAcceptedMove(first);
    expect(move, isNotNull);
    final gameA = FruitPopGame.fromLayout(first);
    final gameB = FruitPopGame.fromLayout(first);
    expect(gameA.swap(move!.$1, move.$2, move.$3, move.$4), isTrue);
    expect(gameB.swap(move.$1, move.$2, move.$3, move.$4), isTrue);
    expect(gameB.board, gameA.board);
    expect(gameB.score, gameA.score);
  });

  test('requires eight of sixteen wins before accepting a candidate', () {
    var calls = 0;
    final adapter = FruitPopLevelAdapter(
      evaluateCandidate: (layout) {
        calls++;
        return FruitSimulationSummary(
          wins: calls == 1 ? 7 : 8,
          simulations: 16,
          moveBudget: layout.baseMoveBudget,
          parMoves: layout.baseMoveBudget - 1,
        );
      },
    );

    final layout = adapter.build(descriptor(1));

    expect(calls, 2);
    expect(layout.candidateAttempts, 2);
    expect(layout.simulationWins, 8);
    expect(layout.usedFallback, isFalse);
  });

  test('candidate search stops at 64 and returns deterministic fallback', () {
    var calls = 0;
    final adapter = FruitPopLevelAdapter(
      evaluateCandidate: (layout) {
        calls++;
        return FruitSimulationSummary(
          wins: 0,
          simulations: 16,
          moveBudget: layout.baseMoveBudget,
          parMoves: layout.baseMoveBudget,
        );
      },
    );

    final first = adapter.build(descriptor(100));
    final second = adapter.build(descriptor(100));

    expect(calls, 128);
    expect(first.candidateAttempts, 64);
    expect(first.usedFallback, isTrue);
    expect(second.canonicalSignature, first.canonicalSignature);
    final game = FruitPopGame.fromLayout(first);
    expect(game.findMatches(), isEmpty);
    expect(game.hasPossibleMove, isTrue);
  });

  test('normalization is bounded efficiency instead of raw cascade score', () {
    final adapter = FruitPopLevelAdapter();

    expect(
      adapter.normalizeScore(
        const FruitPopOutcome(rawScore: 5000, movesUsed: 8, parMoves: 10),
      ),
      100,
    );
    expect(
      adapter.normalizeScore(
        const FruitPopOutcome(rawScore: 5000, movesUsed: 20, parMoves: 10),
      ),
      50,
    );
    expect(
      adapter.normalizeScore(
        const FruitPopOutcome(rawScore: 100000, movesUsed: 1000, parMoves: 1),
      ),
      inInclusiveRange(0, 100),
    );
  });
}

(int, int, int, int)? firstAcceptedMove(FruitPopLevelLayout layout) {
  for (var row = 0; row < FruitPopGame.size; row++) {
    for (var col = 0; col < FruitPopGame.size; col++) {
      for (final (dr, dc) in const [(0, 1), (1, 0)]) {
        final otherRow = row + dr;
        final otherCol = col + dc;
        if (otherRow >= FruitPopGame.size || otherCol >= FruitPopGame.size) {
          continue;
        }
        final probe = FruitPopGame.fromLayout(layout);
        if (probe.swap(row, col, otherRow, otherCol)) {
          return (row, col, otherRow, otherCol);
        }
      }
    }
  }
  return null;
}
