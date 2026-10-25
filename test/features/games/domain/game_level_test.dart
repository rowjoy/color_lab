import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameId', () {
    test('uses permanent storage IDs and round-trips every game', () {
      const expected = {
        GameId.bubbleShooter: 'bubbleShooter',
        GameId.fruitPop: 'fruitPop',
        GameId.waterSort: 'waterSort',
        GameId.rainbowRings: 'rainbowRings',
        GameId.colorMatch: 'colorMatch',
      };

      expect({
        for (final gameId in GameId.values) gameId: gameId.storageId,
      }, expected);
      for (final entry in expected.entries) {
        expect(GameId.parse(entry.value), entry.key);
      }
    });

    test('rejects an unknown serialized ID', () {
      expect(() => GameId.parse('water-sort'), throwsFormatException);
    });
  });

  group('GameTier', () {
    test('derives exact level boundaries and rewards', () {
      for (final (level, tier, coins) in const [
        (1, GameTier.easy, 10),
        (9, GameTier.easy, 10),
        (10, GameTier.medium, 25),
        (19, GameTier.medium, 25),
        (20, GameTier.hard, 50),
        (1000000000, GameTier.hard, 50),
      ]) {
        expect(GameTier.forLevel(level), tier);
        expect(tier.rewardCoins, coins);
      }
    });

    test('rejects non-positive levels', () {
      expect(() => GameTier.forLevel(0), throwsArgumentError);
      expect(() => levelPressureFor(-1), throwsArgumentError);
    });

    test('level pressure is finite, literal, and monotonic', () {
      expect(levelPressureFor(1), 0);
      expect(levelPressureFor(2), 1);
      expect(levelPressureFor(4), 2);

      var previous = levelPressureFor(1);
      for (final level in const [2, 9, 10, 19, 20, 30, 100, 1000000000]) {
        final pressure = levelPressureFor(level);
        expect(pressure.isFinite, isTrue);
        expect(pressure, greaterThan(previous));
        previous = pressure;
      }
    });
  });

  group('GameLevelDescriptor', () {
    final descriptor = GameLevelDescriptor(
      gameId: GameId.waterSort,
      level: 10,
      seed: 3628656079,
      generatorVersion: 1,
      retrySalt: 2,
      fingerprint: 'a' * 64,
      tier: GameTier.medium,
      levelPressure: levelPressureFor(10),
    );

    test('round-trips its strict versioned map with value equality', () {
      final encoded = descriptor.toMap();

      expect(encoded, {
        'schemaVersion': 1,
        'gameId': 'waterSort',
        'level': 10,
        'seed': 3628656079,
        'generatorVersion': 1,
        'retrySalt': 2,
        'fingerprint': 'a' * 64,
        'tier': 'medium',
        'levelPressure': levelPressureFor(10),
      });
      expect(GameLevelDescriptor.fromMap(encoded), descriptor);
      expect(
        GameLevelDescriptor.fromMap(encoded).hashCode,
        descriptor.hashCode,
      );
    });

    test('constructor rejects invalid scalar and derived values', () {
      GameLevelDescriptor build({
        int level = 1,
        int seed = 1,
        int generatorVersion = 1,
        int retrySalt = 0,
        String? fingerprint,
        GameTier tier = GameTier.easy,
        double? pressure,
      }) => GameLevelDescriptor(
        gameId: GameId.waterSort,
        level: level,
        seed: seed,
        generatorVersion: generatorVersion,
        retrySalt: retrySalt,
        fingerprint: fingerprint ?? 'b' * 64,
        tier: tier,
        levelPressure: pressure ?? levelPressureFor(level > 0 ? level : 1),
      );

      expect(() => build(level: 0), throwsArgumentError);
      expect(() => build(seed: -1), throwsArgumentError);
      expect(() => build(seed: 0x100000000), throwsArgumentError);
      expect(() => build(generatorVersion: 0), throwsArgumentError);
      expect(() => build(retrySalt: -1), throwsArgumentError);
      expect(() => build(fingerprint: 'short'), throwsArgumentError);
      expect(() => build(fingerprint: 'A' * 64), throwsArgumentError);
      expect(() => build(tier: GameTier.hard), throwsArgumentError);
      expect(() => build(pressure: double.nan), throwsArgumentError);
      expect(() => build(pressure: double.infinity), throwsArgumentError);
      expect(() => build(pressure: 99), throwsArgumentError);
    });

    test('map parser rejects malformed and unsupported data', () {
      final valid = descriptor.toMap();
      final corrupt = <Map<String, Object?>>[
        {...valid, 'schemaVersion': 2},
        {...valid, 'gameId': 'unknown'},
        {...valid, 'level': 0},
        {...valid, 'seed': -1},
        {...valid, 'generatorVersion': 0},
        {...valid, 'retrySalt': -1},
        {...valid, 'fingerprint': 'nope'},
        {...valid, 'tier': 'hard'},
        {...valid, 'levelPressure': double.nan},
        {...valid, 'levelPressure': '3.3'},
      ];

      for (final map in corrupt) {
        expect(
          () => GameLevelDescriptor.fromMap(map),
          throwsFormatException,
          reason: '$map',
        );
      }
    });
  });
}
