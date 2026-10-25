import 'dart:math';

import 'package:color_lab/features/games/domain/adapters/fruit_pop_level_adapter.dart';
import 'package:color_lab/features/games/domain/fruit_pop_game.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generates an 8 by 8 board with no initial matches and at least one move',
    () {
      final game = FruitPopGame.generate(level: 1, random: Random(7));

      expect(game.board, hasLength(8));
      expect(game.board.every((row) => row.length == 8), isTrue);
      expect(game.findMatches(), isEmpty);
      expect(game.hasPossibleMove, isTrue);
    },
  );

  test('level scaling transitions from easy through medium to hard', () {
    expect(FruitPopGame.difficultyForLevel(1).name, 'easy');
    expect(FruitPopGame.difficultyForLevel(4).name, 'medium');
    expect(FruitPopGame.difficultyForLevel(8).name, 'hard');
  });

  test('blockers reject swaps and remain empty through stable cascades', () {
    final level = GameLevelDescriptor(
      gameId: GameId.fruitPop,
      level: 100,
      seed: 12345,
      generatorVersion: 1,
      retrySalt: 0,
      fingerprint: '0' * 64,
      tier: GameTier.hard,
      levelPressure: levelPressureFor(100),
    );
    final layout = FruitPopLevelAdapter().build(level);
    final blocker = layout.blockers.first;
    final blockerRow = blocker ~/ FruitPopGame.size;
    final blockerCol = blocker % FruitPopGame.size;
    final neighborCol = blockerCol == 0 ? 1 : blockerCol - 1;
    final game = FruitPopGame.fromLayout(layout);

    expect(game.swap(blockerRow, blockerCol, blockerRow, neighborCol), isFalse);
    final move = firstAcceptedMove(layout);
    expect(move, isNotNull);
    final first = FruitPopGame.fromLayout(layout);
    final second = FruitPopGame.fromLayout(layout);
    expect(first.swap(move!.$1, move.$2, move.$3, move.$4), isTrue);
    expect(second.swap(move.$1, move.$2, move.$3, move.$4), isTrue);
    expect(first.board, second.board);
    expect(first.score, second.score);
    expect(first.findMatches(), isEmpty);
    for (final index in layout.blockers) {
      expect(
        first.board[index ~/ FruitPopGame.size][index % FruitPopGame.size],
        isNull,
      );
    }
    for (
      var index = 0;
      index < FruitPopGame.size * FruitPopGame.size;
      index++
    ) {
      if (layout.blockers.contains(index)) continue;
      expect(
        first.board[index ~/ FruitPopGame.size][index % FruitPopGame.size],
        isNotNull,
      );
    }
  });

  test(
    'deterministic simulation copy preserves state without mutating source',
    () {
      final level = GameLevelDescriptor(
        gameId: GameId.fruitPop,
        level: 20,
        seed: 67890,
        generatorVersion: 1,
        retrySalt: 0,
        fingerprint: '0' * 64,
        tier: GameTier.hard,
        levelPressure: levelPressureFor(20),
      );
      final layout = FruitPopLevelAdapter().build(level);
      final move = firstAcceptedMove(layout)!;
      final source = FruitPopGame.fromLayout(layout);
      final sourceBoard = source.board.map(List<int?>.of).toList();
      final copy = source.copyForSimulation();

      expect(copy.swap(move.$1, move.$2, move.$3, move.$4), isTrue);
      expect(source.board, sourceBoard);
      expect(source.score, 0);

      final replay = FruitPopGame.fromLayout(layout);
      expect(replay.swap(move.$1, move.$2, move.$3, move.$4), isTrue);
      expect(copy.board, replay.board);
      expect(copy.score, replay.score);
      expect(copy.movesLeft, replay.movesLeft);
    },
  );
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
