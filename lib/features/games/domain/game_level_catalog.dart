import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'deterministic_random.dart';
import 'game_id.dart';
import 'game_level.dart';
import 'game_level_adapter.dart';

final class GameLevelCatalog {
  const GameLevelCatalog({required this.registry});

  static const int initialBatchSize = 15;
  static const int refillThreshold = 10;
  static const int refillBatchSize = 15;
  static const int maxCollisionRetries = 128;

  final GameLevelAdapterRegistry registry;

  List<GameLevelDescriptor> generateBatch({
    required String profileId,
    required GameId gameId,
    required int startLevel,
    required int count,
    required Map<int, GameLevelDescriptor> existingByLevel,
    required Set<String> existingFingerprints,
  }) {
    if (startLevel < 1) {
      throw ArgumentError.value(startLevel, 'startLevel', 'Must be positive');
    }
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Must not be negative');
    }

    final adapter = registry.adapterFor(gameId);
    final version = adapter.currentGeneratorVersion;
    if (adapter.gameId != gameId ||
        version < 1 ||
        !adapter.supportsVersion(version)) {
      throw GameLevelGenerationException(
        gameId: gameId,
        level: startLevel,
        cause: StateError('Unsupported generator version $version'),
      );
    }

    final fingerprints = <String>{
      ...existingFingerprints,
      ...existingByLevel.values.map((descriptor) => descriptor.fingerprint),
    };
    final generated = <GameLevelDescriptor>[];
    final endExclusive = startLevel + count;
    for (var level = startLevel; level < endExclusive; level++) {
      final existing = existingByLevel[level];
      if (existing != null) {
        if (existing.level != level || existing.gameId != gameId) {
          throw GameLevelGenerationException(
            gameId: gameId,
            level: level,
            cause: const FormatException('Mismatched existing descriptor'),
          );
        }
        continue;
      }

      GameLevelDescriptor? accepted;
      Object? lastFailure;
      for (var retrySalt = 0; retrySalt < maxCollisionRetries; retrySalt++) {
        try {
          final seed = deriveLevelSeed(
            profileId: profileId,
            gameId: gameId,
            level: level,
            retrySalt: retrySalt,
            generatorVersion: version,
          );
          final pressure = levelPressureFor(level);
          final candidate = GameLevelDescriptor(
            gameId: gameId,
            level: level,
            seed: seed,
            generatorVersion: version,
            retrySalt: retrySalt,
            fingerprint: '0' * 64,
            tier: GameTier.forLevel(level),
            levelPressure: pressure,
          );
          final signature = adapter.build(candidate).canonicalSignature;
          if (signature.isEmpty) {
            throw const FormatException('Empty canonical signature');
          }
          final fingerprint = sha256.convert(utf8.encode(signature)).toString();
          if (fingerprints.contains(fingerprint)) continue;
          accepted = GameLevelDescriptor(
            gameId: gameId,
            level: level,
            seed: seed,
            generatorVersion: version,
            retrySalt: retrySalt,
            fingerprint: fingerprint,
            tier: candidate.tier,
            levelPressure: pressure,
          );
          break;
        } catch (error) {
          lastFailure = error;
          break;
        }
      }
      if (accepted == null) {
        throw GameLevelGenerationException(
          gameId: gameId,
          level: level,
          cause: lastFailure ?? StateError('No unique layout found'),
        );
      }
      generated.add(accepted);
      fingerprints.add(accepted.fingerprint);
    }
    return List<GameLevelDescriptor>.unmodifiable(generated);
  }

  bool needsRefill({required int currentLevel, required int generatedThrough}) {
    if (currentLevel < 1) {
      throw ArgumentError.value(
        currentLevel,
        'currentLevel',
        'Must be positive',
      );
    }
    if (generatedThrough < 0) {
      throw ArgumentError.value(
        generatedThrough,
        'generatedThrough',
        'Must not be negative',
      );
    }
    return generatedThrough - currentLevel + 1 <= refillThreshold;
  }
}

final class GameLevelGenerationException implements Exception {
  const GameLevelGenerationException({
    required this.gameId,
    required this.level,
    required this.cause,
  });

  final GameId gameId;
  final int level;
  final Object cause;

  @override
  String toString() =>
      'GameLevelGenerationException(${gameId.storageId}, level $level)';
}
