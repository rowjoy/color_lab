import 'package:color_lab/features/games/domain/adapters/rainbow_rings_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/rainbow_rings_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GameLevelDescriptor descriptor(int level, {int retrySalt = 0}) =>
      GameLevelDescriptor(
        gameId: GameId.rainbowRings,
        level: level,
        seed: (level * 4253 + retrySalt * 99991) & 0xffffffff,
        generatorVersion: 1,
        retrySalt: retrySalt,
        fingerprint: '0' * 64,
        tier: GameTier.forLevel(level),
        levelPressure: levelPressureFor(level),
      );

  test('generator-v1 freezes color, capacity, depth, and literal par', () {
    final adapter = RainbowRingsLevelAdapter();
    const fixtures = [
      (1, 3, 4, 12, 14),
      (9, 4, 5, 29, 22),
      (10, 4, 5, 29, 22),
      (19, 5, 5, 37, 28),
      (20, 5, 5, 37, 28),
      (30, 5, 5, 39, 28),
      (100, 6, 6, 55, 38),
      (1000000, 6, 8, 107, 49),
      (16777216, 6, 8, 120, 49),
    ];

    for (final (level, colors, capacity, depth, par) in fixtures) {
      final layout = adapter.build(descriptor(level));
      final game = RainbowRingsGame.fromLayout(layout);
      expect(layout.colorCount, colors, reason: 'Level $level colors');
      expect(layout.capacity, capacity, reason: 'Level $level capacity');
      expect(layout.scrambleDepth, depth, reason: 'Level $level depth');
      expect(layout.inverseSolution, hasLength(depth));
      expect(layout.parMoves, par, reason: 'Level $level par');
      expect(layout.stacks, hasLength(colors + 2));
      expect(
        layout.stacks.where((stack) => stack.isEmpty),
        hasLength(2),
        reason: 'Level $level empty pegs',
      );
      expect(game.isWon, isFalse, reason: 'Level $level starts unsolved');
      expect(
        layout.stacks
            .where((stack) => stack.isNotEmpty)
            .every(
              (stack) =>
                  stack.length == capacity &&
                  stack.map((ring) => layout.ringColors[ring]).toSet().length >
                      1,
            ),
        isTrue,
        reason: 'Level $level mixed full pegs',
      );
      for (var color = 0; color < colors; color++) {
        expect(
          layout.ringColors.where((ringColor) => ringColor == color),
          hasLength(capacity),
          reason: 'Level $level color $color rings',
        );
      }
      expect(replaySolution(layout), isTrue, reason: 'Level $level solution');
    }
  });

  test('same descriptor freezes ring identities, board, and certificate', () {
    final adapter = RainbowRingsLevelAdapter();
    final first = adapter.build(descriptor(30));
    final repeated = adapter.build(descriptor(30));
    final retried = adapter.build(descriptor(30, retrySalt: 1));

    expect(repeated.canonicalSignature, first.canonicalSignature);
    expect(repeated.ringColors, first.ringColors);
    expect(repeated.stacks, first.stacks);
    expect(repeated.inverseSolution, first.inverseSolution);
    expect(
      first.canonicalSignature,
      contains(RainbowRingsGame.fromLayout(first).signature),
    );
    expect(retried.canonicalSignature, isNot(first.canonicalSignature));
  });

  test(
    'pressure changes scramble depth without changing fixed par formula',
    () {
      final adapter = RainbowRingsLevelAdapter();
      final level19 = adapter.build(descriptor(19));
      final level30 = adapter.build(descriptor(30));

      expect(level19.colorCount, level30.colorCount);
      expect(level19.capacity, level30.capacity);
      expect(level19.parMoves, 28);
      expect(level30.parMoves, 28);
      expect(level19.scrambleDepth, 37);
      expect(level30.scrambleDepth, 39);
      expect(level19.canonicalSignature, isNot(level30.canonicalSignature));
    },
  );

  test('candidate validation is bounded and accepts a verified replay', () {
    var calls = 0;
    final adapter = RainbowRingsLevelAdapter(
      validateCandidate: (layout) {
        calls++;
        return calls == 2 && replaySolution(layout);
      },
    );

    final layout = adapter.build(descriptor(10));

    expect(calls, 2);
    expect(layout.candidateAttempts, 2);
    expect(layout.usedFallback, isFalse);
    expect(replaySolution(layout), isTrue);
  });

  test('candidate search stops at 64 and returns deterministic fallback', () {
    var calls = 0;
    final adapter = RainbowRingsLevelAdapter(
      validateCandidate: (layout) {
        calls++;
        return false;
      },
    );

    final first = adapter.build(descriptor(100));
    final second = adapter.build(descriptor(100));

    expect(calls, 128);
    expect(first.candidateAttempts, 64);
    expect(first.usedFallback, isTrue);
    expect(second.canonicalSignature, first.canonicalSignature);
    expect(second.inverseSolution, first.inverseSolution);
    expect(replaySolution(first), isTrue);
  });

  test('normalization awards 100 at par and 50 at twice par', () {
    final adapter = RainbowRingsLevelAdapter();

    expect(
      adapter.normalizeScore(
        const RainbowRingsMoveOutcome(actualMoves: 28, parMoves: 28),
      ),
      100,
    );
    expect(
      adapter.normalizeScore(
        const RainbowRingsMoveOutcome(actualMoves: 56, parMoves: 28),
      ),
      50,
    );
    expect(
      adapter.normalizeScore(
        const RainbowRingsMoveOutcome(actualMoves: 10000, parMoves: 1),
      ),
      inInclusiveRange(0, 100),
    );
  });
}

bool replaySolution(RainbowRingsLevelLayout layout) {
  final game = RainbowRingsGame.fromLayout(layout);
  for (final move in layout.inverseSolution) {
    if (!game.tapPeg(move.source).changed ||
        !game.tapPeg(move.target).changed) {
      return false;
    }
  }
  return game.isWon && game.moves == layout.inverseSolution.length;
}
