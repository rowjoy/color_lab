import 'dart:async';
import 'dart:io';

import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  final epoch = DateTime.utc(2026, 10, 24, 8);

  test('production registry exposes exactly one adapter for every game', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final registry = container.read(gameAdapterRegistryProvider);

    expect(
      GameId.values.map((gameId) => registry.adapterFor(gameId).gameId),
      GameId.values,
    );
  });

  test(
    'default repository opens, loads, and closes with its container',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'game-profiles-provider-',
      );
      final container = ProviderContainer(
        overrides: [
          gameProfilesDirectoryProvider.overrideWith((ref) async => directory),
        ],
      );
      var disposed = false;
      addTearDown(() async {
        if (!disposed) container.dispose();
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final repository = await container.read(
        gameProfilesRepositoryProvider.future,
      );
      final loaded = await container.read(gameProfilesProvider.future);
      expect(loaded.profiles, isEmpty);
      expect(loaded.legacyMigrationComplete, isTrue);

      container.dispose();
      disposed = true;
      await expectLater(repository.loadState(), throwsStateError);
    },
  );

  test(
    'injected IDs and UTC clock drive CRUD and all derived providers',
    () async {
      final repository = InMemoryGameProfilesRepository(
        initialState: _emptyState(),
      );
      final registry = _FakeRegistry();
      var idIndex = 0;
      var tick = 0;
      final ids = ['profile-1', 'profile-2'];
      final container = _containerFor(
        repository,
        registry: registry,
        nextId: () => ids[idIndex++],
        clock: () => epoch.add(Duration(minutes: tick++)),
      );
      addTearDown(container.dispose);
      await container.read(gameProfilesProvider.future);
      final controller = container.read(gameProfilesProvider.notifier);

      final first = await controller.createProfile(name: 'Me');
      final renamed = await controller.renameProfile(
        profileId: first.id,
        name: 'Owner',
      );
      final second = await controller.createProfile(name: 'Guest');
      await controller.setActiveProfile(profileId: first.id);
      await controller.deleteProfile(profileId: second.id);

      expect(first.id, 'profile-1');
      expect(first.createdAt, epoch);
      expect(renamed.updatedAt, epoch.add(const Duration(minutes: 1)));
      expect(second.id, 'profile-2');
      expect(second.createdAt, epoch.add(const Duration(minutes: 2)));
      expect(container.read(activePlayerProfileProvider)?.name, 'Owner');
      expect(
        container.read(activeGameProgressProvider(GameId.waterSort)),
        isNull,
      );
      expect(
        container.read(overallLeaderboardProvider).single.profileId,
        first.id,
      );
      expect(
        container
            .read(gameLeaderboardProvider(GameId.waterSort))
            .single
            .profileId,
        first.id,
      );
    },
  );

  test(
    'queued commands use newest durable state and publish after writes',
    () async {
      final repository = InMemoryGameProfilesRepository(
        initialState: _emptyState(),
      );
      final ids = ['profile-1', 'profile-2'];
      var idIndex = 0;
      final container = _containerFor(
        repository,
        nextId: () => ids[idIndex++],
        clock: () => epoch,
      );
      addTearDown(container.dispose);
      await container.read(gameProfilesProvider.future);
      repository.writeGate = Completer<void>();
      final controller = container.read(gameProfilesProvider.notifier);

      final first = controller.createProfile(name: 'First');
      final second = controller.createProfile(name: 'Second');
      await _waitUntil(() => repository.writeAttempts == 1);
      expect(repository.durableState.profiles, isEmpty);
      expect(
        container.read(gameProfilesProvider).requireValue.profiles,
        isEmpty,
      );

      repository.writeGate!.complete();
      await Future.wait([first, second]);
      expect(repository.durableState.profiles.keys, ['profile-1', 'profile-2']);
      expect(container.read(gameProfilesProvider).requireValue.profiles.keys, [
        'profile-1',
        'profile-2',
      ]);
      expect(
        container.read(gameProfilesProvider).requireValue.activeProfileId,
        'profile-2',
      );
    },
  );

  test(
    'load retry and write recovery preserve the last good AsyncData',
    () async {
      final unreadable = InMemoryGameProfilesRepository(
        initialState: _emptyState(),
      )..failLoad = true;
      final loadContainer = _containerFor(unreadable);
      addTearDown(loadContainer.dispose);
      final loadController = loadContainer.read(gameProfilesProvider.notifier);

      await expectLater(
        loadContainer.read(gameProfilesProvider.future),
        throwsA(isA<TestGameProfilesRepositoryException>()),
      );
      unreadable.failLoad = false;
      loadController.retry();
      expect(
        (await loadContainer.read(gameProfilesProvider.future)).profiles,
        isEmpty,
      );

      final repository = InMemoryGameProfilesRepository(
        initialState: _profileState(epoch),
      );
      final writeContainer = _containerFor(repository, clock: () => epoch);
      addTearDown(writeContainer.dispose);
      await writeContainer.read(gameProfilesProvider.future);
      final writeController = writeContainer.read(
        gameProfilesProvider.notifier,
      );
      repository.failWrite = true;

      await expectLater(
        writeController.renameProfile(profileId: 'profile-1', name: 'Owner'),
        throwsA(isA<TestGameProfilesRepositoryException>()),
      );
      expect(
        writeContainer
            .read(gameProfilesProvider)
            .requireValue
            .activeProfile!
            .name,
        'Player',
      );
      expect(writeContainer.read(gameProfilesProvider).hasError, isFalse);

      repository.failWrite = false;
      await writeController.renameProfile(
        profileId: 'profile-1',
        name: 'Owner',
      );
      expect(
        writeContainer
            .read(gameProfilesProvider)
            .requireValue
            .activeProfile!
            .name,
        'Owner',
      );
    },
  );

  test('disposed controller rejects queued and late commands', () async {
    final repository = InMemoryGameProfilesRepository(
      initialState: _emptyState(),
    )..loadGate = Completer<void>();
    final container = _containerFor(repository, clock: () => epoch);
    final controller = container.read(gameProfilesProvider.notifier);
    final queued = expectLater(
      controller.createProfile(name: 'Player'),
      throwsStateError,
    );

    container.dispose();
    repository.loadGate!.complete();
    await queued;
    await expectLater(
      controller.createProfile(name: 'Late Player'),
      throwsStateError,
    );
    expect(repository.writeCount, 0);
  });

  test(
    'completion normalizes through launch adapter before any transaction',
    () async {
      final repository = InMemoryGameProfilesRepository(
        initialState: _emptyState(),
      );
      final registry = _FakeRegistry();
      var tick = 0;
      final container = _containerFor(
        repository,
        registry: registry,
        clock: () => epoch.add(Duration(seconds: tick++)),
      );
      addTearDown(container.dispose);
      await container.read(gameProfilesProvider.future);
      final controller = container.read(gameProfilesProvider.notifier);
      final profile = await controller.createProfile(name: 'Player');
      await controller.prepareGame(
        profileId: profile.id,
        gameId: GameId.waterSort,
      );
      final launch = await controller.beginCurrentAttempt(
        profileId: profile.id,
        gameId: GameId.waterSort,
      );
      final transitionsBefore = repository.transitionCount;

      await expectLater(
        controller.completeLevel(
          launch,
          const _ScoreOutcome(GameId.fruitPop, 99),
        ),
        throwsArgumentError,
      );
      expect(repository.transitionCount, transitionsBefore);
      expect(
        repository
            .durableState
            .activeProfile!
            .gameProgress[GameId.waterSort]!
            .activeAttempt,
        isNotNull,
      );

      final receipt = await controller.completeLevel(
        launch,
        const _ScoreOutcome(GameId.waterSort, 83),
      );
      expect(receipt.normalizedScore, 83);
      expect(receipt.firstClear, isTrue);
      expect(repository.transitionCount, transitionsBefore + 1);
      expect(
        container
            .read(gameProfilesProvider)
            .requireValue
            .activeProfile!
            .bestScore,
        83,
      );
    },
  );

  test(
    'failed post-receipt refill keeps reward launchable and retryable',
    () async {
      final repository = InMemoryGameProfilesRepository(
        initialState: _emptyState(),
      );
      final registry = _FakeRegistry();
      var tick = 0;
      final container = _containerFor(
        repository,
        registry: registry,
        clock: () => epoch.add(Duration(minutes: tick++)),
      );
      addTearDown(container.dispose);
      await container.read(gameProfilesProvider.future);
      final controller = container.read(gameProfilesProvider.notifier);
      final profile = await controller.createProfile(name: 'Player');
      await controller.prepareGame(
        profileId: profile.id,
        gameId: GameId.waterSort,
      );

      for (var level = 1; level <= 4; level++) {
        final launch = await controller.beginCurrentAttempt(
          profileId: profile.id,
          gameId: GameId.waterSort,
        );
        await controller.completeLevel(
          launch,
          _ScoreOutcome(GameId.waterSort, 70 + level),
        );
      }
      final adapter = registry.adapter(GameId.waterSort);
      adapter.failFromLevel = 16;
      final launch = await controller.beginCurrentAttempt(
        profileId: profile.id,
        gameId: GameId.waterSort,
      );
      final writesBefore = repository.writeCount;
      final transitionsBefore = repository.transitionCount;

      final receipt = await controller.completeLevel(
        launch,
        const _ScoreOutcome(GameId.waterSort, 95),
      );

      expect(receipt.level, 5);
      expect(receipt.coinsAwarded, 10);
      expect(repository.writeCount, writesBefore + 1);
      expect(repository.transitionCount, transitionsBefore + 2);
      final durable = repository
          .durableState
          .activeProfile!
          .gameProgress[GameId.waterSort]!;
      expect(durable.currentLevel, 6);
      expect(durable.generatedThrough, 15);
      expect(durable.pendingRefillThrough, 30);
      expect(repository.durableState.activeProfile!.coins, 50);
      expect(
        container.read(gameProfilesProvider).requireValue.toMap(),
        repository.durableState.toMap(),
      );

      final available = await controller.prepareGame(
        profileId: profile.id,
        gameId: GameId.waterSort,
      );
      expect(available.currentLevel, 6);
      expect(available.generatedThrough, 15);
      expect(available.descriptors, contains(6));
      expect(available.pendingRefillThrough, 30);

      final levelSix = await controller.beginCurrentAttempt(
        profileId: profile.id,
        gameId: GameId.waterSort,
      );
      expect(levelSix.descriptor.level, 6);
      expect(
        repository
            .durableState
            .activeProfile!
            .gameProgress[GameId.waterSort]!
            .pendingRefillThrough,
        30,
      );

      adapter.failFromLevel = null;
      final retried = await controller.prepareGame(
        profileId: profile.id,
        gameId: GameId.waterSort,
      );
      expect(retried.currentLevel, 6);
      expect(retried.generatedThrough, 30);
      expect(retried.pendingRefillThrough, isNull);
      expect(retried.activeAttempt?.attemptId, levelSix.attemptId);
      expect(repository.durableState.activeProfile!.coins, 50);
    },
  );

  test('resume-or-begin creates and publishes a current attempt', () async {
    final repository = InMemoryGameProfilesRepository(
      initialState: _profileState(epoch),
    );
    final container = _containerFor(repository, clock: () => epoch);
    addTearDown(container.dispose);
    await container.read(gameProfilesProvider.future);
    final controller = container.read(gameProfilesProvider.notifier);
    await controller.prepareGame(
      profileId: 'profile-1',
      gameId: GameId.waterSort,
    );

    final launch = await controller.resumeOrBeginCurrentAttempt(
      profileId: 'profile-1',
      gameId: GameId.waterSort,
    );

    expect(launch.attemptId, 'profile-1:waterSort:1');
    expect(launch.descriptor.level, 1);
    expect(launch.playKind, GamePlayKind.current);
    final progress =
        repository.durableState.activeProfile!.gameProgress[GameId.waterSort]!;
    expect(progress.activeAttempt?.attemptId, 'profile-1:waterSort:1');
    expect(progress.attempts, 1);
    expect(progress.attemptSequence, 1);
    expect(repository.durableState.activeProfile!.gamesPlayed, 1);
  });

  test(
    'resume-or-begin republishes the same active attempt idempotently',
    () async {
      final repository = InMemoryGameProfilesRepository(
        initialState: _profileState(epoch),
      );
      var tick = 0;
      final container = _containerFor(
        repository,
        clock: () => epoch.add(Duration(seconds: tick++)),
      );
      addTearDown(container.dispose);
      await container.read(gameProfilesProvider.future);
      final controller = container.read(gameProfilesProvider.notifier);
      await controller.prepareGame(
        profileId: 'profile-1',
        gameId: GameId.waterSort,
      );
      final first = await controller.resumeOrBeginCurrentAttempt(
        profileId: 'profile-1',
        gameId: GameId.waterSort,
      );
      final before = repository.durableState.toMap();
      final writesBefore = repository.writeAttempts;

      final resumed = await controller.resumeOrBeginCurrentAttempt(
        profileId: 'profile-1',
        gameId: GameId.waterSort,
      );

      expect(resumed, first);
      expect(repository.durableState.toMap(), before);
      expect(repository.writeAttempts, writesBefore + 1);
      final progress = repository
          .durableState
          .activeProfile!
          .gameProgress[GameId.waterSort]!;
      expect(progress.attempts, 1);
      expect(progress.attemptSequence, 1);
      expect(repository.durableState.activeProfile!.gamesPlayed, 1);
    },
  );

  test(
    'resume-or-begin rejects an incompatible active attempt atomically',
    () async {
      final repository = InMemoryGameProfilesRepository(
        initialState: _profileState(epoch),
      );
      var tick = 0;
      final container = _containerFor(
        repository,
        clock: () => epoch.add(Duration(seconds: tick++)),
      );
      addTearDown(container.dispose);
      await container.read(gameProfilesProvider.future);
      final controller = container.read(gameProfilesProvider.notifier);
      await controller.prepareGame(
        profileId: 'profile-1',
        gameId: GameId.waterSort,
      );
      final first = await controller.beginCurrentAttempt(
        profileId: 'profile-1',
        gameId: GameId.waterSort,
      );
      await controller.completeLevel(
        first,
        const _ScoreOutcome(GameId.waterSort, 80),
      );
      final replay = await controller.beginReplayAttempt(
        profileId: 'profile-1',
        gameId: GameId.waterSort,
        level: 1,
      );
      final before = repository.durableState.toMap();
      final writesBefore = repository.writeAttempts;

      await expectLater(
        controller.resumeOrBeginCurrentAttempt(
          profileId: 'profile-1',
          gameId: GameId.waterSort,
        ),
        throwsA(
          isA<GameProgressionException>().having(
            (error) => error.code,
            'code',
            GameProgressionError.staleAttempt,
          ),
        ),
      );

      expect(repository.durableState.toMap(), before);
      expect(repository.writeAttempts, writesBefore);
      final progress = repository
          .durableState
          .activeProfile!
          .gameProgress[GameId.waterSort]!;
      expect(progress.activeAttempt?.attemptId, replay.attemptId);
      expect(progress.attempts, 2);
      expect(progress.attemptSequence, 2);
    },
  );

  test(
    'initial catalog generation failure still surfaces atomically',
    () async {
      final repository = InMemoryGameProfilesRepository(
        initialState: _emptyState(),
      );
      final registry = _FakeRegistry();
      final container = _containerFor(
        repository,
        registry: registry,
        clock: () => epoch,
      );
      addTearDown(container.dispose);
      await container.read(gameProfilesProvider.future);
      final controller = container.read(gameProfilesProvider.notifier);
      final profile = await controller.createProfile(name: 'Player');
      registry.adapter(GameId.waterSort).failFromLevel = 1;
      final before = repository.durableState.toMap();

      await expectLater(
        controller.prepareGame(profileId: profile.id, gameId: GameId.waterSort),
        throwsA(
          isA<GameProgressionException>().having(
            (error) => error.code,
            'code',
            GameProgressionError.generationFailed,
          ),
        ),
      );

      expect(repository.durableState.toMap(), before);
      expect(
        container
            .read(gameProfilesProvider)
            .requireValue
            .profiles[profile.id]!
            .gameProgress,
        isEmpty,
      );
    },
  );
}

ProviderContainer _containerFor(
  InMemoryGameProfilesRepository repository, {
  _FakeRegistry? registry,
  String Function()? nextId,
  DateTime Function()? clock,
}) {
  final effectiveRegistry = registry ?? _FakeRegistry();
  final effectiveNextId = nextId ?? (() => 'profile-1');
  final effectiveClock = clock ?? (() => DateTime.utc(2026, 10, 24, 8));
  return ProviderContainer(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      gameAdapterRegistryProvider.overrideWithValue(effectiveRegistry),
      gameProfileIdFactoryProvider.overrideWithValue(effectiveNextId),
      gameProfilesClockProvider.overrideWithValue(effectiveClock),
    ],
  );
}

GameProfilesState _emptyState() => GameProfilesState(
  activeProfileId: null,
  profiles: const {},
  legacyMigrationComplete: true,
);

GameProfilesState _profileState(DateTime createdAt) {
  final profile = PlayerProfile(
    id: 'profile-1',
    name: 'Player',
    createdAt: createdAt,
    updatedAt: createdAt,
  );
  return GameProfilesState(
    activeProfileId: profile.id,
    profiles: {profile.id: profile},
    legacyMigrationComplete: true,
  );
}

final class _ScoreOutcome implements GameLevelOutcome {
  const _ScoreOutcome(this.gameId, this.score);

  final GameId gameId;
  final int score;
}

final class _FakeRegistry implements GameLevelAdapterRegistry {
  _FakeRegistry()
    : _adapters = {
        for (final gameId in GameId.values) gameId: _FakeAdapter(gameId),
      };

  final Map<GameId, _FakeAdapter> _adapters;

  _FakeAdapter adapter(GameId gameId) => _adapters[gameId]!;

  @override
  GameLevelAdapter adapterFor(GameId gameId) => adapter(gameId);
}

final class _FakeAdapter implements GameLevelAdapter {
  _FakeAdapter(this.gameId);

  @override
  final GameId gameId;

  int? failFromLevel;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  GameLevelLayout build(GameLevelDescriptor descriptor) {
    final boundary = failFromLevel;
    if (descriptor.gameId != gameId ||
        !supportsVersion(descriptor.generatorVersion)) {
      throw ArgumentError.value(descriptor, 'descriptor');
    }
    if (boundary != null && descriptor.level >= boundary) {
      throw StateError('Injected generation failure at ${descriptor.level}');
    }
    return _FakeLayout(
      '${gameId.storageId}:${descriptor.level}:${descriptor.seed}:'
      '${descriptor.retrySalt}',
    );
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) {
    if (outcome is! _ScoreOutcome ||
        outcome.gameId != gameId ||
        outcome.score < 0 ||
        outcome.score > 100) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    return outcome.score;
  }
}

final class _FakeLayout implements GameLevelLayout {
  const _FakeLayout(this.canonicalSignature);

  @override
  final String canonicalSignature;
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  if (!condition()) throw StateError('Timed out waiting for test boundary');
}
