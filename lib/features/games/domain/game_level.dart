import 'dart:math' as math;

import 'game_id.dart';

enum GameTier {
  easy(rewardCoins: 10, label: 'Easy'),
  medium(rewardCoins: 25, label: 'Medium'),
  hard(rewardCoins: 50, label: 'Hard');

  const GameTier({required this.rewardCoins, required this.label});

  final int rewardCoins;
  final String label;

  static GameTier forLevel(int level) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'Must be positive');
    }
    return switch (level) {
      < 10 => GameTier.easy,
      < 20 => GameTier.medium,
      _ => GameTier.hard,
    };
  }

  static GameTier parse(String value) {
    for (final tier in values) {
      if (tier.name == value) return tier;
    }
    throw FormatException('Unknown game tier: $value');
  }
}

double levelPressureFor(int level) {
  if (level < 1) {
    throw ArgumentError.value(level, 'level', 'Must be positive');
  }
  return math.log(level) / math.ln2;
}

final class GameLevelDescriptor {
  factory GameLevelDescriptor({
    required GameId gameId,
    required int level,
    required int seed,
    required int generatorVersion,
    required int retrySalt,
    required String fingerprint,
    required GameTier tier,
    required double levelPressure,
  }) {
    _validate(
      level: level,
      seed: seed,
      generatorVersion: generatorVersion,
      retrySalt: retrySalt,
      fingerprint: fingerprint,
      tier: tier,
      levelPressure: levelPressure,
    );
    return GameLevelDescriptor._(
      gameId: gameId,
      level: level,
      seed: seed,
      generatorVersion: generatorVersion,
      retrySalt: retrySalt,
      fingerprint: fingerprint,
      tier: tier,
      levelPressure: levelPressure,
    );
  }

  const GameLevelDescriptor._({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.generatorVersion,
    required this.retrySalt,
    required this.fingerprint,
    required this.tier,
    required this.levelPressure,
  });

  static const schemaVersion = 1;
  static final RegExp _fingerprintPattern = RegExp(r'^[0-9a-f]{64}$');

  final GameId gameId;
  final int level;
  final int seed;
  final int generatorVersion;
  final int retrySalt;
  final String fingerprint;
  final GameTier tier;
  final double levelPressure;

  Map<String, Object?> toMap() => {
    'schemaVersion': schemaVersion,
    'gameId': gameId.storageId,
    'level': level,
    'seed': seed,
    'generatorVersion': generatorVersion,
    'retrySalt': retrySalt,
    'fingerprint': fingerprint,
    'tier': tier.name,
    'levelPressure': levelPressure,
  };

  factory GameLevelDescriptor.fromMap(Map<Object?, Object?> map) {
    if (map['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported level descriptor version');
    }

    int readInt(String key) {
      final value = map[key];
      if (value is! int) {
        throw FormatException('Invalid level descriptor $key');
      }
      return value;
    }

    String readString(String key) {
      final value = map[key];
      if (value is! String) {
        throw FormatException('Invalid level descriptor $key');
      }
      return value;
    }

    final pressureValue = map['levelPressure'];
    if (pressureValue is! num) {
      throw const FormatException('Invalid level descriptor levelPressure');
    }
    try {
      return GameLevelDescriptor(
        gameId: GameId.parse(readString('gameId')),
        level: readInt('level'),
        seed: readInt('seed'),
        generatorVersion: readInt('generatorVersion'),
        retrySalt: readInt('retrySalt'),
        fingerprint: readString('fingerprint'),
        tier: GameTier.parse(readString('tier')),
        levelPressure: pressureValue.toDouble(),
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid level descriptor', error);
    }
  }

  static void _validate({
    required int level,
    required int seed,
    required int generatorVersion,
    required int retrySalt,
    required String fingerprint,
    required GameTier tier,
    required double levelPressure,
  }) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'Must be positive');
    }
    if (seed < 0 || seed > 0xffffffff) {
      throw ArgumentError.value(seed, 'seed', 'Must be an unsigned 32-bit int');
    }
    if (generatorVersion < 1) {
      throw ArgumentError.value(
        generatorVersion,
        'generatorVersion',
        'Must be positive',
      );
    }
    if (retrySalt < 0) {
      throw ArgumentError.value(retrySalt, 'retrySalt', 'Must not be negative');
    }
    if (!_fingerprintPattern.hasMatch(fingerprint)) {
      throw ArgumentError.value(
        fingerprint,
        'fingerprint',
        'Must be a lowercase SHA-256 hex digest',
      );
    }
    if (tier != GameTier.forLevel(level)) {
      throw ArgumentError.value(tier, 'tier', 'Does not match level');
    }
    final expectedPressure = levelPressureFor(level);
    if (!levelPressure.isFinite ||
        levelPressure < 0 ||
        (levelPressure - expectedPressure).abs() > 1e-12) {
      throw ArgumentError.value(
        levelPressure,
        'levelPressure',
        'Does not match level',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameLevelDescriptor &&
          other.gameId == gameId &&
          other.level == level &&
          other.seed == seed &&
          other.generatorVersion == generatorVersion &&
          other.retrySalt == retrySalt &&
          other.fingerprint == fingerprint &&
          other.tier == tier &&
          other.levelPressure == levelPressure;

  @override
  int get hashCode => Object.hash(
    gameId,
    level,
    seed,
    generatorVersion,
    retrySalt,
    fingerprint,
    tier,
    levelPressure,
  );
}
