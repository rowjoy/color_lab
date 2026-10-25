import 'dart:math';

import 'package:color_lab/features/games/domain/adapters/water_sort_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/water_sort_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates four units per color and two empty tubes', () {
    final game = WaterSortGame.generate(level: 1, random: Random(8));

    expect(game.colorCount, 3);
    expect(game.tubes, hasLength(5));
    expect(game.tubes.where((tube) => tube.isEmpty), hasLength(2));
    for (var color = 0; color < game.colorCount; color++) {
      final amount = game.tubes
          .expand((tube) => tube)
          .where((segment) => segment.color == color)
          .fold<int>(0, (sum, segment) => sum + segment.amount);
      expect(amount, 4);
    }
    expect(game.tubes.take(game.colorCount).any(game.isTubeComplete), isFalse);
  });

  test('avoids repeating the previous randomized board', () {
    final first = WaterSortGame.generate(level: 2, random: Random(81));
    final next = WaterSortGame.generate(
      level: 2,
      random: Random(81),
      previousSignature: first.signature,
    );

    expect(next.signature, isNot(first.signature));
    expect(next.tubes.take(next.colorCount).any(next.isTubeComplete), isFalse);
  });

  test(
    'pours only the matching top layer and undo restores the exact board',
    () {
      final game = WaterSortGame.fromTubes([
        const [WaterSegment(0, 2), WaterSegment(1, 2)],
        const [WaterSegment(1, 2)],
        const [],
      ]);
      final before = game.signature;

      expect(game.canPour(0, 1), isTrue);
      expect(game.pour(0, 1), isTrue);
      expect(game.tubes[0], const [WaterSegment(0, 2)]);
      expect(game.tubes[1], const [WaterSegment(1, 4)]);
      expect(game.moves, 1);
      expect(game.undo(), isTrue);
      expect(game.signature, before);
      expect(game.moves, 0);
    },
  );

  test('rejects a pour onto a different color', () {
    final game = WaterSortGame.fromTubes([
      const [WaterSegment(0, 2)],
      const [WaterSegment(1, 1)],
    ]);
    expect(game.canPour(0, 1), isFalse);
    expect(game.pour(0, 1), isFalse);
    expect(game.moves, 0);
  });

  test(
    'descriptor layout keeps undo and restart on the exact initial board',
    () {
      final descriptor = GameLevelDescriptor(
        gameId: GameId.waterSort,
        level: 20,
        seed: 24680,
        generatorVersion: 1,
        retrySalt: 0,
        fingerprint: '0' * 64,
        tier: GameTier.hard,
        levelPressure: levelPressureFor(20),
      );
      final layout = WaterSortLevelAdapter().build(descriptor);
      final game = WaterSortGame.fromLayout(layout);
      final initialSignature = game.signature;
      final firstMove = layout.inverseSolution.first;

      expect(game.pour(firstMove.source, firstMove.target), isTrue);
      expect(game.undo(), isTrue);
      expect(game.signature, initialSignature);
      expect(game.pour(firstMove.source, firstMove.target), isTrue);
      game.restart();
      expect(game.signature, initialSignature);
      expect(game.moves, 0);
    },
  );
}
