import 'package:color_lab/features/games/domain/adapters/bubble_shooter_level_adapter.dart';
import 'package:color_lab/features/games/domain/bubble_shooter_game.dart';
import 'package:color_lab/features/games/domain/deterministic_random.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GameLevelDescriptor descriptor(int level, {int retrySalt = 0}) =>
      GameLevelDescriptor(
        gameId: GameId.bubbleShooter,
        level: level,
        seed: deriveLevelSeed(
          profileId: 'profile-a',
          gameId: GameId.bubbleShooter,
          level: level,
          retrySalt: retrySalt,
        ),
        generatorVersion: 1,
        retrySalt: retrySalt,
        fingerprint: '0' * 64,
        tier: GameTier.forLevel(level),
        levelPressure: levelPressureFor(level),
      );

  test('generator-v1 freezes bounded parameters at boundary levels', () {
    final adapter = BubbleShooterLevelAdapter();
    const fixtures = [
      (1, 3, 4, 8),
      (9, 4, 5, 7),
      (10, 4, 5, 7),
      (19, 5, 6, 6),
      (20, 5, 6, 6),
      (30, 5, 6, 6),
      (100, 6, 7, 5),
      (1000000, 6, 8, 4),
    ];

    for (final (level, colors, rows, dropEvery) in fixtures) {
      final layout = adapter.build(descriptor(level));
      expect(layout.colorCount, colors, reason: 'Level $level colors');
      expect(layout.occupiedRows, rows, reason: 'Level $level rows');
      expect(layout.dropEvery, dropEvery, reason: 'Level $level drop');
      expect(layout.grid, hasLength(9));
      expect(
        layout.grid.every((row) => row.length == BubbleShooterGame.columns),
        isTrue,
      );
    }
  });

  test('same descriptor regenerates exactly and retry salt changes layout', () {
    final adapter = BubbleShooterLevelAdapter();
    final first = adapter.build(descriptor(30));
    final repeated = adapter.build(descriptor(30));
    final retried = adapter.build(descriptor(30, retrySalt: 1));

    expect(repeated.canonicalSignature, first.canonicalSignature);
    expect(repeated.grid, first.grid);
    expect(retried.canonicalSignature, isNot(first.canonicalSignature));
  });

  test(
    'every boundary candidate carries a certificate that clears real rules',
    () {
      final adapter = BubbleShooterLevelAdapter();
      for (final level in const [1, 9, 10, 19, 20, 30, 100, 1000000]) {
        final layout = adapter.build(descriptor(level));
        final game = BubbleShooterGame.fromLayout(layout);
        expect(layout.placementCertificate, isNotEmpty);
        final first = layout.placementCertificate.first;
        final firstResult = game.landBubble(
          first.row,
          first.column,
          first.color,
        );
        expect(firstResult.popped, greaterThanOrEqualTo(3));
        for (final placement in layout.placementCertificate.skip(1)) {
          game.landBubble(placement.row, placement.column, placement.color);
        }
        expect(game.isWon, isTrue, reason: 'Level $level did not clear');
      }
    },
  );

  test('candidate search is bounded at 64 before deterministic fallback', () {
    var validations = 0;
    final adapter = BubbleShooterLevelAdapter(
      validateCandidate: (layout) {
        validations++;
        return false;
      },
    );

    final first = adapter.build(descriptor(20));
    final second = adapter.build(descriptor(20));

    expect(validations, 128);
    expect(first.usedFallback, isTrue);
    expect(second.usedFallback, isTrue);
    expect(second.canonicalSignature, first.canonicalSignature);
    final game = BubbleShooterGame.fromLayout(first);
    for (final placement in first.placementCertificate) {
      game.landBubble(placement.row, placement.column, placement.color);
    }
    expect(game.isWon, isTrue);
  });

  test('runtime row stream is part of the canonical layout', () {
    final adapter = BubbleShooterLevelAdapter();
    final layout = adapter.build(descriptor(10));

    expect(
      layout.canonicalSignature,
      contains('|stream=${layout.runtimeSeed}|'),
    );
    final first = BubbleShooterGame.fromLayout(layout);
    final second = BubbleShooterGame.fromLayout(layout);
    expect(first.currentColor, second.currentColor);
    expect(first.nextColor, second.nextColor);
  });

  test('normalization uses efficiency and never leaks raw score', () {
    final adapter = BubbleShooterLevelAdapter();

    expect(
      adapter.normalizeScore(
        const BubbleShooterOutcome(rawScore: 500, shotsFired: 3, parShots: 4),
      ),
      100,
    );
    expect(
      adapter.normalizeScore(
        const BubbleShooterOutcome(rawScore: 900, shotsFired: 8, parShots: 4),
      ),
      50,
    );
    expect(
      adapter.normalizeScore(
        const BubbleShooterOutcome(
          rawScore: 100000,
          shotsFired: 1000,
          parShots: 1,
        ),
      ),
      inInclusiveRange(0, 100),
    );
  });
}
