import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/domain/adapters/water_sort_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_catalog.dart';
import 'package:color_lab/features/games/domain/water_sort_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GameLevelDescriptor descriptor(int level, {int retrySalt = 0}) =>
      GameLevelDescriptor(
        gameId: GameId.waterSort,
        level: level,
        seed: (level * 3571 + retrySalt * 65537) & 0xffffffff,
        generatorVersion: 1,
        retrySalt: retrySalt,
        fingerprint: '0' * 64,
        tier: GameTier.forLevel(level),
        levelPressure: levelPressureFor(level),
      );

  test('generator-v1 freezes color and reverse-depth bounds', () {
    final adapter = WaterSortLevelAdapter();
    const fixtures = [
      (1, 3, 8),
      (9, 6, 21),
      (10, 6, 21),
      (19, 7, 26),
      (20, 7, 26),
      (30, 7, 28),
      (100, 9, 37),
      (1000000, 9, 77),
    ];

    for (final (level, colors, depth) in fixtures) {
      final layout = adapter.build(descriptor(level));
      final game = WaterSortGame.fromLayout(layout);
      expect(layout.capacity, 4, reason: 'Level $level capacity');
      expect(layout.colorCount, colors, reason: 'Level $level colors');
      expect(layout.scrambleDepth, depth, reason: 'Level $level depth');
      expect(layout.parMoves, depth, reason: 'Level $level par');
      expect(layout.inverseSolution, hasLength(depth));
      expect(layout.tubes, hasLength(colors + 2));
      expect(
        layout.tubes.where((tube) => tube.isEmpty),
        hasLength(2),
        reason: 'Level $level empty tubes',
      );
      expect(game.isWon, isFalse, reason: 'Level $level starts unsolved');
      for (var color = 0; color < colors; color++) {
        final amount = layout.tubes
            .expand((tube) => tube)
            .where((segment) => segment.color == color)
            .fold<int>(0, (sum, segment) => sum + segment.amount);
        expect(amount, 4, reason: 'Level $level color $color amount');
      }
      expect(replaySolution(layout), isTrue, reason: 'Level $level solution');
    }
  });

  test(
    'production catalog builds deterministic level 2 with complete mix macros',
    () {
      final registry = ProductionGameAdapterRegistry();
      final catalog = GameLevelCatalog(registry: registry);

      List<GameLevelDescriptor> generate() => catalog.generateBatch(
        profileId: 'profile-level-two',
        gameId: GameId.waterSort,
        startLevel: 1,
        count: 2,
        existingByLevel: const {},
        existingFingerprints: const {},
      );

      final first = generate();
      final repeated = generate();
      final descriptor = first[1];
      final layout =
          registry.adapterFor(GameId.waterSort).build(descriptor)
              as WaterSortLevelLayout;

      expect(repeated, first);
      expect(descriptor.level, 2);
      expect(layout.colorCount, 4);
      expect(layout.scrambleDepth, 12);
      expect(layout.parMoves, 12);
      expect(layout.inverseSolution, hasLength(12));
      expect(layout.tubes.where((tube) => tube.isEmpty), hasLength(2));
      expect(replaySolution(layout), isTrue);
    },
  );

  test('same descriptor freezes initial layout and inverse certificate', () {
    final adapter = WaterSortLevelAdapter();
    final first = adapter.build(descriptor(30));
    final repeated = adapter.build(descriptor(30));
    final retried = adapter.build(descriptor(30, retrySalt: 1));

    expect(repeated.canonicalSignature, first.canonicalSignature);
    expect(repeated.tubes, first.tubes);
    expect(repeated.inverseSolution, first.inverseSolution);
    expect(
      first.canonicalSignature,
      contains(WaterSortGame.fromLayout(first).signature),
    );
    expect(retried.canonicalSignature, isNot(first.canonicalSignature));
  });

  test(
    'candidate validation is bounded and accepts the first valid replay',
    () {
      var calls = 0;
      final adapter = WaterSortLevelAdapter(
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
    },
  );

  test('candidate search stops at 64 and returns a verified fallback', () {
    var calls = 0;
    final adapter = WaterSortLevelAdapter(
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
    final adapter = WaterSortLevelAdapter();

    expect(
      adapter.normalizeScore(
        const WaterSortOutcome(actualMoves: 12, parMoves: 12),
      ),
      100,
    );
    expect(
      adapter.normalizeScore(
        const WaterSortOutcome(actualMoves: 24, parMoves: 12),
      ),
      50,
    );
    expect(
      adapter.normalizeScore(
        const WaterSortOutcome(actualMoves: 10000, parMoves: 1),
      ),
      inInclusiveRange(0, 100),
    );
  });
}

bool replaySolution(WaterSortLevelLayout layout) {
  final game = WaterSortGame.fromLayout(layout);
  for (final move in layout.inverseSolution) {
    if (!game.canPour(move.source, move.target) ||
        !game.pour(move.source, move.target)) {
      return false;
    }
  }
  return game.isWon && game.moves == layout.inverseSolution.length;
}
