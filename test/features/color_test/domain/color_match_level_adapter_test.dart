import 'package:color_lab/features/color_test/domain/color_match_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GameLevelDescriptor descriptor(
    int level, {
    int retrySalt = 0,
    int version = 1,
  }) => GameLevelDescriptor(
    gameId: GameId.colorMatch,
    level: level,
    seed: (level * 6271 + retrySalt * 131071) & 0xffffffff,
    generatorVersion: version,
    retrySalt: retrySalt,
    fingerprint: '0' * 64,
    tier: GameTier.forLevel(level),
    levelPressure: levelPressureFor(level),
  );

  test('generator-v1 freezes rules and feasible target constraints', () {
    final adapter = ColorMatchLevelAdapter();
    const fixtures = [
      (1, 3, 55, 60, 60.0),
      (9, 6, 67, 51, 51.0),
      (10, 6, 68, 51, 51.0),
      (19, 7, 71, 48, 48.0),
      (20, 7, 72, 48, 48.0),
      (30, 7, 74, 46, 46.0),
      (100, 9, 81, 41, 40.0),
      (1000000, 12, 90, 18, 18.0),
    ];

    for (final (level, rounds, winningAverage, requestedHue, effectiveHue)
        in fixtures) {
      final layout = adapter.build(descriptor(level));
      expect(layout.rules.roundCount, rounds, reason: 'Level $level rounds');
      expect(
        layout.rules.winningAverage,
        winningAverage,
        reason: 'Level $level winning average',
      );
      expect(
        layout.requestedMinimumHueSeparation,
        requestedHue,
        reason: 'Level $level requested hue separation',
      );
      expect(
        layout.minimumHueSeparation,
        effectiveHue,
        reason: 'Level $level effective hue separation',
      );
      expect(layout.targets, hasLength(rounds));
      expect(layout.targets.toSet(), hasLength(rounds));
      final hues = layout.targets.map((target) {
        final hsl = target.toHsl();
        expect(
          hsl.saturation,
          greaterThanOrEqualTo(layout.minimumSaturation - .015),
          reason: 'Level $level saturation',
        );
        expect(hsl.lightness, inInclusiveRange(.248, .752));
        return hsl.hue;
      }).toList()..sort();
      for (var index = 0; index < hues.length; index++) {
        final gap = (hues[(index + 1) % hues.length] - hues[index]) % 360;
        expect(
          gap,
          greaterThanOrEqualTo(effectiveHue - 1.5),
          reason: 'Level $level hue gap $index',
        );
      }
    }
  });

  test(
    'same descriptor regenerates exactly and retry salt changes targets',
    () {
      final adapter = ColorMatchLevelAdapter();
      final first = adapter.build(descriptor(100));
      final repeated = adapter.build(descriptor(100));
      final retried = adapter.build(descriptor(100, retrySalt: 1));

      expect(repeated.targets, first.targets);
      expect(repeated.canonicalSignature, first.canonicalSignature);
      expect(retried.canonicalSignature, isNot(first.canonicalSignature));
    },
  );

  test('rejects descriptors for another game or generator version', () {
    final adapter = ColorMatchLevelAdapter();
    final wrongGame = GameLevelDescriptor(
      gameId: GameId.fruitPop,
      level: 1,
      seed: 1,
      generatorVersion: 1,
      retrySalt: 0,
      fingerprint: '0' * 64,
      tier: GameTier.easy,
      levelPressure: levelPressureFor(1),
    );

    expect(() => adapter.build(wrongGame), throwsArgumentError);
    expect(() => adapter.build(descriptor(1, version: 2)), throwsArgumentError);
    expect(adapter.supportsVersion(1), isTrue);
    expect(adapter.supportsVersion(2), isFalse);
  });

  test('normalization rounds the bounded average score', () {
    final adapter = ColorMatchLevelAdapter();

    expect(
      adapter.normalizeScore(const ColorMatchOutcome(averageScore: 83.5)),
      84,
    );
    expect(adapter.normalizeScore(const ColorMatchOutcome(averageScore: 0)), 0);
    expect(
      adapter.normalizeScore(const ColorMatchOutcome(averageScore: 100)),
      100,
    );
    expect(
      () => adapter.normalizeScore(
        const ColorMatchOutcome(averageScore: double.nan),
      ),
      throwsArgumentError,
    );
  });
}
