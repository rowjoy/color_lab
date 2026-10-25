import 'dart:math';

import 'package:color_lab/features/games/domain/adapters/rainbow_rings_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/rainbow_rings_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates a mixed board and a different next layout', () {
    final first = RainbowRingsGame.generate(level: 1, random: Random(4));
    final next = RainbowRingsGame.generate(
      level: 1,
      random: Random(4),
      previousSignature: first.signature,
    );

    expect(first.signature, isNot(next.signature));
    expect(first.isWon, isFalse);
    expect(first.stacks, hasLength(first.colorCount + 2));
    expect(
      first.stacks
          .take(first.colorCount)
          .every((peg) => peg.length == first.capacity),
      isTrue,
    );
  });

  group('structured actions', () {
    test('selects a resting top ring into hover and deselects it back', () {
      final game = _twoColorGame();
      final before = game.signature;

      expect(
        game.tapPeg(0),
        const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.select,
          ringId: 1,
          source: RainbowRingsPosition(peg: 0, slot: 1),
          destination: RainbowRingsPosition.hover(0),
        ),
      );
      expect(game.selectedPeg, 0);
      expect(game.signature, before);
      expect(game.moves, 0);

      expect(
        game.tapPeg(0),
        const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.deselect,
          ringId: 1,
          source: RainbowRingsPosition.hover(0),
          destination: RainbowRingsPosition(peg: 0, slot: 1),
        ),
      );
      expect(game.selectedPeg, isNull);
      expect(game.signature, before);
      expect(game.moves, 0);
    });

    test('move and undo report exact slots and mutate exactly once', () {
      final game = _twoColorGame();
      final initial = game.signature;
      game.tapPeg(0);

      const forward = RainbowRingsMove(
        ringId: 1,
        sourcePeg: 0,
        sourceSlot: 1,
        destinationPeg: 2,
        destinationSlot: 0,
      );
      expect(
        game.tapPeg(2),
        const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.move,
          ringId: 1,
          source: RainbowRingsPosition.hover(0),
          destination: RainbowRingsPosition(peg: 2, slot: 0),
          move: forward,
        ),
      );
      expect(game.stacks, [
        [0],
        [2, 3],
        [1],
        [],
      ]);
      expect(game.moves, 1);
      expect(game.canUndo, isTrue);

      expect(
        game.undo(),
        const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.undo,
          ringId: 1,
          source: RainbowRingsPosition(peg: 2, slot: 0),
          destination: RainbowRingsPosition(peg: 0, slot: 1),
          move: RainbowRingsMove(
            ringId: 1,
            sourcePeg: 2,
            sourceSlot: 0,
            destinationPeg: 0,
            destinationSlot: 1,
          ),
        ),
      );
      expect(game.signature, initial);
      expect(game.moves, 0);
      expect(game.canUndo, isFalse);
    });

    test('invalid destination retains selection without mutation', () {
      final game = RainbowRingsGame.fromBoard(
        level: 1,
        capacity: 3,
        ringColors: const [0, 1, 1, 0],
        stacks: const [
          [0, 1],
          [3],
          [],
          [],
        ],
      );
      game.tapPeg(0);
      final before = game.signature;

      expect(
        game.tapPeg(1),
        const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.invalid,
          ringId: 1,
          source: RainbowRingsPosition.hover(0),
          destination: RainbowRingsPosition(peg: 1, slot: 1),
        ),
      );
      expect(game.selectedPeg, 0);
      expect(game.signature, before);
      expect(game.moves, 0);
      expect(game.canUndo, isFalse);
    });

    test('empty and completed sources return exact invalid results', () {
      final game = RainbowRingsGame.fromBoard(
        level: 1,
        capacity: 2,
        ringColors: const [0, 0, 1, 0],
        stacks: const [
          [0, 1],
          [2, 3],
          [],
          [],
        ],
      );
      final before = game.signature;

      expect(
        game.tapPeg(2),
        const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.invalid,
          destination: RainbowRingsPosition(peg: 2, slot: 0),
        ),
      );
      expect(game.isPegComplete(0), isTrue);
      expect(
        game.tapPeg(0),
        const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.invalid,
          ringId: 1,
          source: RainbowRingsPosition(peg: 0, slot: 1),
          destination: RainbowRingsPosition(peg: 0, slot: 1),
        ),
      );
      expect(game.selectedPeg, isNull);
      expect(game.signature, before);
      expect(game.moves, 0);
      expect(game.canUndo, isFalse);
    });

    test('full and mismatched destinations retain the selected ring', () {
      final game = RainbowRingsGame.fromBoard(
        level: 1,
        capacity: 3,
        ringColors: const [0, 1, 1, 1, 1, 2],
        stacks: const [
          [0, 1],
          [2, 3, 4],
          [5],
          [],
        ],
      );
      game.tapPeg(0);
      final before = game.signature;

      expect(
        game.tapPeg(1),
        const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.invalid,
          ringId: 1,
          source: RainbowRingsPosition.hover(0),
          destination: RainbowRingsPosition(peg: 1, slot: 3),
        ),
      );
      expect(game.selectedPeg, 0);
      expect(
        game.tapPeg(2),
        const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.invalid,
          ringId: 1,
          source: RainbowRingsPosition.hover(0),
          destination: RainbowRingsPosition(peg: 2, slot: 1),
        ),
      );
      expect(game.selectedPeg, 0);
      expect(game.signature, before);
      expect(game.moves, 0);
      expect(game.canUndo, isFalse);
    });

    test('won and out-of-range actions are ignored', () {
      final game = _twoColorGame();
      expect(
        game.tapPeg(-1),
        const RainbowRingsActionResult(kind: RainbowRingsActionKind.ignored),
      );
      expect(
        game.tapPeg(99),
        const RainbowRingsActionResult(kind: RainbowRingsActionKind.ignored),
      );

      final winning = RainbowRingsGame.fromBoard(
        level: 1,
        capacity: 2,
        ringColors: const [0, 1, 0, 1],
        stacks: const [
          [0, 1],
          [2],
          [3],
          [],
        ],
      );
      winning.tapPeg(0);
      expect(winning.tapPeg(2).kind, RainbowRingsActionKind.move);
      winning.tapPeg(0);
      expect(winning.tapPeg(1).kind, RainbowRingsActionKind.move);
      expect(winning.isWon, isTrue);
      expect(
        winning.tapPeg(0),
        const RainbowRingsActionResult(kind: RainbowRingsActionKind.ignored),
      );
      expect(
        winning.undo(),
        const RainbowRingsActionResult(kind: RainbowRingsActionKind.ignored),
      );
    });
  });

  group('hint heuristic', () {
    test('prefers the fullest matching destination with stable traversal', () {
      final game = RainbowRingsGame.fromBoard(
        level: 1,
        capacity: 3,
        ringColors: const [0, 1, 1, 1, 1],
        stacks: const [
          [0, 1],
          [2],
          [3, 4],
          [],
        ],
      );
      final before = game.signature;

      expect(
        game.suggestMove(),
        const RainbowRingsMove(
          ringId: 1,
          sourcePeg: 0,
          sourceSlot: 1,
          destinationPeg: 2,
          destinationSlot: 2,
        ),
      );
      expect(game.signature, before);
      expect(game.selectedPeg, isNull);
      expect(game.moves, 0);
    });

    test('breaks equal-size matching-destination ties by lower peg', () {
      final game = RainbowRingsGame.fromBoard(
        level: 1,
        capacity: 3,
        ringColors: const [0, 1, 1, 1, 1, 1],
        stacks: const [
          [0, 1],
          [2, 3],
          [4, 5],
          [],
        ],
      );
      final before = game.signature;

      expect(
        game.suggestMove(),
        const RainbowRingsMove(
          ringId: 1,
          sourcePeg: 0,
          sourceSlot: 1,
          destinationPeg: 1,
          destinationSlot: 2,
        ),
      );
      expect(game.signature, before);
      expect(game.selectedPeg, isNull);
      expect(game.moves, 0);
    });

    test('otherwise chooses the first mixed source and first empty target', () {
      final game = RainbowRingsGame.fromBoard(
        level: 1,
        capacity: 3,
        ringColors: const [0, 1, 2],
        stacks: const [
          [0, 1],
          [2],
          [],
          [],
        ],
      );

      expect(
        game.suggestMove(),
        const RainbowRingsMove(
          ringId: 1,
          sourcePeg: 0,
          sourceSlot: 1,
          destinationPeg: 2,
          destinationSlot: 0,
        ),
      );
    });

    test('returns null when no matching or mixed source move exists', () {
      final game = RainbowRingsGame.fromBoard(
        level: 1,
        capacity: 2,
        ringColors: const [0, 0, 1, 1],
        stacks: const [
          [0, 1],
          [2, 3],
          [],
          [],
        ],
      );

      expect(game.suggestMove(), isNull);
    });
  });

  test('par formula matches literal color and capacity fixtures', () {
    expect(_gameForPar(colorCount: 3, capacity: 4).parMoves, 14);
    expect(_gameForPar(colorCount: 4, capacity: 5).parMoves, 22);
    expect(_gameForPar(colorCount: 6, capacity: 8).parMoves, 49);
  });

  test(
    'descriptor layout keeps undo and restart on the exact initial board',
    () {
      final descriptor = GameLevelDescriptor(
        gameId: GameId.rainbowRings,
        level: 20,
        seed: 13579,
        generatorVersion: 1,
        retrySalt: 0,
        fingerprint: '0' * 64,
        tier: GameTier.hard,
        levelPressure: levelPressureFor(20),
      );
      final layout = RainbowRingsLevelAdapter().build(descriptor);
      final game = RainbowRingsGame.fromLayout(layout);
      final initialSignature = game.signature;
      final firstMove = layout.inverseSolution.first;

      expect(game.tapPeg(firstMove.source).changed, isTrue);
      expect(game.tapPeg(firstMove.target).kind, RainbowRingsActionKind.move);
      expect(game.undo().kind, RainbowRingsActionKind.undo);
      expect(game.signature, initialSignature);
      expect(game.tapPeg(firstMove.source).changed, isTrue);
      expect(game.tapPeg(firstMove.target).kind, RainbowRingsActionKind.move);
      game.restart();
      expect(game.signature, initialSignature);
      expect(game.moves, 0);
      expect(game.selectedPeg, isNull);
    },
  );
}

RainbowRingsGame _twoColorGame() => RainbowRingsGame.fromBoard(
  level: 1,
  capacity: 2,
  ringColors: const [0, 1, 1, 0],
  stacks: const [
    [0, 1],
    [2, 3],
    [],
    [],
  ],
);

RainbowRingsGame _gameForPar({
  required int colorCount,
  required int capacity,
}) => RainbowRingsGame.fromBoard(
  level: 1,
  capacity: capacity,
  ringColors: [
    for (var color = 0; color < colorCount; color++)
      for (var slot = 0; slot < capacity; slot++) color,
  ],
  stacks: const [[], []],
);
