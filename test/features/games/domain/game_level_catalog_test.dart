import 'dart:convert';

import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_level_catalog.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeLayout implements GameLevelLayout {
  const _FakeLayout(this.canonicalSignature);

  @override
  final String canonicalSignature;
}

final class _FakeAdapter implements GameLevelAdapter {
  _FakeAdapter({this.signatureFor, this.supported = true, this.throwAtLevel});

  final String Function(GameLevelDescriptor descriptor)? signatureFor;
  final bool supported;
  final int? throwAtLevel;
  final List<GameLevelDescriptor> builds = [];

  @override
  GameId get gameId => GameId.waterSort;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => supported && version == 1;

  @override
  GameLevelLayout build(GameLevelDescriptor descriptor) {
    builds.add(descriptor);
    if (descriptor.level == throwAtLevel) throw StateError('injected');
    return _FakeLayout(
      signatureFor?.call(descriptor) ??
          '${descriptor.level}:${descriptor.seed}:${descriptor.retrySalt}',
    );
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) => 50;
}

final class _Registry implements GameLevelAdapterRegistry {
  const _Registry(this.adapter);

  final GameLevelAdapter adapter;

  @override
  GameLevelAdapter adapterFor(GameId gameId) {
    if (gameId != adapter.gameId) {
      throw StateError('No adapter for ${gameId.storageId}');
    }
    return adapter;
  }
}

void main() {
  GameLevelCatalog catalogFor(_FakeAdapter adapter) =>
      GameLevelCatalog(registry: _Registry(adapter));

  test(
    'prepares an ordered initial catalog of exactly levels 1 through 15',
    () {
      final descriptors = catalogFor(_FakeAdapter()).generateBatch(
        profileId: 'profile-a',
        gameId: GameId.waterSort,
        startLevel: 1,
        count: GameLevelCatalog.initialBatchSize,
        existingByLevel: const {},
        existingFingerprints: const {},
      );

      expect(
        descriptors.map((descriptor) => descriptor.level),
        List<int>.generate(15, (index) => index + 1),
      );
      expect(
        descriptors.every(
          (descriptor) =>
              descriptor.fingerprint.length == 64 &&
              descriptor.tier == GameTier.forLevel(descriptor.level) &&
              descriptor.levelPressure == levelPressureFor(descriptor.level),
        ),
        isTrue,
      );
    },
  );

  test('refill threshold appends fifteen levels through 30', () {
    final catalog = catalogFor(_FakeAdapter());
    final initial = catalog.generateBatch(
      profileId: 'profile-a',
      gameId: GameId.waterSort,
      startLevel: 1,
      count: 15,
      existingByLevel: const {},
      existingFingerprints: const {},
    );
    final existing = {
      for (final descriptor in initial) descriptor.level: descriptor,
    };
    final fingerprints = initial
        .map((descriptor) => descriptor.fingerprint)
        .toSet();

    expect(catalog.needsRefill(currentLevel: 5, generatedThrough: 15), isFalse);
    expect(catalog.needsRefill(currentLevel: 6, generatedThrough: 15), isTrue);
    final refill = catalog.generateBatch(
      profileId: 'profile-a',
      gameId: GameId.waterSort,
      startLevel: 16,
      count: GameLevelCatalog.refillBatchSize,
      existingByLevel: existing,
      existingFingerprints: fingerprints,
    );

    expect(refill.map((descriptor) => descriptor.level), range(16, 30));
    final all = {
      ...existing,
      for (final descriptor in refill) descriptor.level: descriptor,
    };
    final retry = catalog.generateBatch(
      profileId: 'profile-a',
      gameId: GameId.waterSort,
      startLevel: 16,
      count: 15,
      existingByLevel: all,
      existingFingerprints: {
        ...fingerprints,
        ...refill.map((descriptor) => descriptor.fingerprint),
      },
    );
    expect(retry, isEmpty);
  });

  test('fingerprint collision changes retry salt and derived seed', () {
    final adapter = _FakeAdapter(
      signatureFor: (descriptor) => descriptor.retrySalt == 0
          ? 'shared-layout'
          : '${descriptor.level}:${descriptor.retrySalt}:${descriptor.seed}',
    );

    final descriptors = catalogFor(adapter).generateBatch(
      profileId: 'profile-a',
      gameId: GameId.waterSort,
      startLevel: 1,
      count: 2,
      existingByLevel: const {},
      existingFingerprints: const {},
    );

    expect(descriptors[0].retrySalt, 0);
    expect(descriptors[1].retrySalt, 1);
    final secondBuilds = adapter.builds
        .where((build) => build.level == 2)
        .toList();
    expect(secondBuilds.map((build) => build.retrySalt), [0, 1]);
    expect(secondBuilds[0].seed, isNot(secondBuilds[1].seed));
    expect(
      descriptors.map((descriptor) => descriptor.fingerprint).toSet(),
      hasLength(2),
    );
  });

  test('historical fingerprints remain input-only and force retry', () {
    final historical = sha256.convert(utf8.encode('shared-layout')).toString();
    final inputFingerprints = <String>{historical};
    final adapter = _FakeAdapter(
      signatureFor: (descriptor) => descriptor.retrySalt == 0
          ? 'shared-layout'
          : 'new-layout-${descriptor.retrySalt}',
    );

    final descriptor = catalogFor(adapter)
        .generateBatch(
          profileId: 'profile-a',
          gameId: GameId.waterSort,
          startLevel: 1,
          count: 1,
          existingByLevel: const {},
          existingFingerprints: inputFingerprints,
        )
        .single;

    expect(descriptor.retrySalt, 1);
    expect(inputFingerprints, {historical});
    expect(descriptor.fingerprint, isNot(historical));
  });

  test('bounded collisions fail atomically with a typed error', () {
    final shared = sha256.convert(utf8.encode('always-shared')).toString();
    final existingByLevel = <int, GameLevelDescriptor>{};
    final fingerprints = <String>{shared};
    final adapter = _FakeAdapter(signatureFor: (_) => 'always-shared');

    expect(
      () => catalogFor(adapter).generateBatch(
        profileId: 'profile-a',
        gameId: GameId.waterSort,
        startLevel: 1,
        count: 2,
        existingByLevel: existingByLevel,
        existingFingerprints: fingerprints,
      ),
      throwsA(
        isA<GameLevelGenerationException>()
            .having((error) => error.gameId, 'gameId', GameId.waterSort)
            .having((error) => error.level, 'level', 1),
      ),
    );
    expect(adapter.builds, hasLength(GameLevelCatalog.maxCollisionRetries));
    expect(existingByLevel, isEmpty);
    expect(fingerprints, {shared});
  });

  test('adapter errors and unsupported versions expose no partial batch', () {
    for (final adapter in [
      _FakeAdapter(throwAtLevel: 2),
      _FakeAdapter(supported: false),
    ]) {
      final existing = <int, GameLevelDescriptor>{};
      final fingerprints = <String>{};
      expect(
        () => catalogFor(adapter).generateBatch(
          profileId: 'profile-a',
          gameId: GameId.waterSort,
          startLevel: 1,
          count: 3,
          existingByLevel: existing,
          existingFingerprints: fingerprints,
        ),
        throwsA(isA<GameLevelGenerationException>()),
      );
      expect(existing, isEmpty);
      expect(fingerprints, isEmpty);
    }
  });
}

Matcher range(int start, int end) =>
    orderedEquals([for (var value = start; value <= end; value++) value]);
