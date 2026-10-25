import 'dart:async';
import 'dart:io';

import 'package:color_lab/data/db/hive_game_profiles_repository.dart';
import 'package:color_lab/features/games/domain/game_badge.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../features/games/domain/game_profiles_repository_contract_test.dart';

void main() {
  late Directory directory;
  var contractBoxSequence = 0;
  const profilesBoxName = 'profiles_repository_test';
  const legacyBoxName = 'profiles_repository_test_legacy';
  final storageError = throwsA(isA<GameProfilesStorageException>());

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('game-profiles-v2-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  gameProfilesRepositoryContract('Hive game profiles repository', (
    initial,
  ) async {
    contractBoxSequence++;
    final repository = await HiveGameProfilesRepository.open(
      directory: directory.path,
      boxName: 'profiles_contract_$contractBoxSequence',
      legacyBoxName: 'profiles_contract_legacy_$contractBoxSequence',
    );
    await repository.transact<void>(
      (_) => ProgressionChange<void>(state: initial, value: null),
    );
    return repository;
  });

  test(
    'full nested schema-v2 state survives a real close and reopen',
    () async {
      final expected = _fullState();
      var repository = await HiveGameProfilesRepository.open(
        directory: directory.path,
        boxName: profilesBoxName,
        legacyBoxName: legacyBoxName,
      );
      await repository.transact<void>(
        (_) => ProgressionChange<void>(state: expected, value: null),
      );
      await repository.close();

      repository = await HiveGameProfilesRepository.open(
        directory: directory.path,
        boxName: profilesBoxName,
        legacyBoxName: legacyBoxName,
      );
      final reopened = await repository.loadState();
      expect(reopened.toMap(), expected.toMap());
      expect(reopened.profiles.keys, ['profile-b', 'profile-a']);
      expect(
        reopened
            .profiles['profile-a']!
            .gameProgress[GameId.waterSort]!
            .activeAttempt,
        isNotNull,
      );
      expect(
        reopened
            .profiles['profile-a']!
            .gameProgress[GameId.waterSort]!
            .latestReceipt!
            .badgeId,
        'waterSort:20',
      );
      expect(
        reopened
            .profiles['profile-b']!
            .gameProgress[GameId.fruitPop]!
            .pendingRefillThrough,
        30,
      );
      await repository.close();
    },
  );

  test(
    'transactions serialize and publish only after put and flush finish',
    () async {
      final setup = await _boundaryRepository(
        directory: directory.path,
        profilesBoxName: profilesBoxName,
        legacyBoxName: legacyBoxName,
        initial: _simpleState(coins: 0),
      );
      final profilesBox = setup.profilesBox;
      final repository = setup.repository;
      profilesBox.writeGate = Completer<void>();
      final seenCoins = <int>[];
      var firstCompleted = false;

      final first = repository
          .transact<int>((current) {
            final coins = current.activeProfile!.coins;
            seenCoins.add(coins);
            return _coinChange(current, coins + 1);
          })
          .whenComplete(() => firstCompleted = true);
      final second = repository.transact<int>((current) {
        final coins = current.activeProfile!.coins;
        seenCoins.add(coins);
        return _coinChange(current, coins + 1);
      });

      await _flushMicrotasks();
      expect(seenCoins, [0]);
      expect(firstCompleted, isFalse);
      expect(
        GameProfilesState.fromMap(
          Map<Object?, Object?>.from(
            profilesBox.delegate.get(HiveGameProfilesRepository.stateKey)
                as Map,
          ),
        ).activeProfile!.coins,
        0,
      );

      profilesBox.writeGate!.complete();
      final results = await Future.wait([first, second]);
      expect(seenCoins, [0, 1]);
      expect(results.map((change) => change.value), [1, 2]);
      expect((await repository.loadState()).activeProfile!.coins, 2);

      profilesBox.flushGate = Completer<void>();
      var thirdCompleted = false;
      final third = repository
          .transact<int>((current) => _coinChange(current, 3))
          .whenComplete(() => thirdCompleted = true);
      await _waitUntil(() => profilesBox.flushAttempts >= 3);
      expect(thirdCompleted, isFalse);
      profilesBox.flushGate!.complete();
      expect((await third).value, 3);
      await repository.close();
    },
  );

  test(
    'failed flush blocks reads and transitions until durability recovers',
    () async {
      final setup = await _boundaryRepository(
        directory: directory.path,
        profilesBoxName: profilesBoxName,
        legacyBoxName: legacyBoxName,
        initial: _simpleState(coins: 4),
      );
      final profilesBox = setup.profilesBox;
      final repository = setup.repository;
      profilesBox.failFlush = true;

      await expectLater(
        repository.transact<int>((current) => _coinChange(current, 9)),
        storageError,
      );
      await expectLater(repository.loadState(), storageError);
      var transitionRan = false;
      await expectLater(
        repository.transact<void>((current) {
          transitionRan = true;
          return ProgressionChange<void>(state: current, value: null);
        }),
        storageError,
      );
      expect(transitionRan, isFalse);

      profilesBox.failFlush = false;
      expect((await repository.loadState()).activeProfile!.coins, 9);
      await repository.close();

      final reopened = await HiveGameProfilesRepository.open(
        directory: directory.path,
        boxName: profilesBoxName,
        legacyBoxName: legacyBoxName,
      );
      expect((await reopened.loadState()).activeProfile!.coins, 9);
      await reopened.close();
    },
  );

  test('malformed or unsupported v2 state is never overwritten', () async {
    final records = <Object?>[
      null,
      'not a map',
      const <String, Object?>{'schemaVersion': 99},
    ];
    for (var index = 0; index < records.length; index++) {
      final hive = HiveImpl();
      final profilesBox = await hive.openBox<dynamic>(
        'corrupt_state_$index',
        path: directory.path,
        crashRecovery: false,
      );
      final legacyBox = await hive.openBox<dynamic>(
        'corrupt_legacy_$index',
        path: directory.path,
        crashRecovery: false,
      );
      final record = records[index];
      await profilesBox.put(HiveGameProfilesRepository.stateKey, record);
      await profilesBox.flush();
      final repository = HiveGameProfilesRepository.fromBoxes(
        profilesBox: profilesBox,
        legacyBox: legacyBox,
      );
      var transitionRan = false;

      await expectLater(repository.loadState(), storageError);
      await expectLater(
        repository.transact<void>((current) {
          transitionRan = true;
          return ProgressionChange<void>(state: current, value: null);
        }),
        storageError,
      );
      expect(transitionRan, isFalse);
      expect(
        profilesBox.containsKey(HiveGameProfilesRepository.stateKey),
        isTrue,
      );
      expect(profilesBox.get(HiveGameProfilesRepository.stateKey), record);
      await repository.close();
    }
  });

  test(
    'partial two-box close failure retries only the still-open box',
    () async {
      final setup = await _boundaryRepository(
        directory: directory.path,
        profilesBoxName: profilesBoxName,
        legacyBoxName: legacyBoxName,
        initial: _simpleState(coins: 2),
      );
      final profilesBox = setup.profilesBox;
      final legacyBox = setup.legacyBox;
      final repository = setup.repository;
      final closePlan = _ClosePlan(failOnAttempt: 2);
      profilesBox.closePlan = closePlan;
      legacyBox.closePlan = closePlan;

      await expectLater(repository.close(), storageError);
      final closedAfterFailure = [
        profilesBox,
        legacyBox,
      ].where((box) => !box.delegate.isOpen).single;
      final openAfterFailure = identical(closedAfterFailure, profilesBox)
          ? legacyBox
          : profilesBox;
      expect(closedAfterFailure.closeAttempts, 1);
      expect(openAfterFailure.closeAttempts, 1);
      await expectLater(repository.loadState(), throwsStateError);

      closePlan.failOnAttempt = null;
      await repository.close();
      expect(closedAfterFailure.closeAttempts, 1);
      expect(openAfterFailure.closeAttempts, 2);
      expect(profilesBox.delegate.isOpen, isFalse);
      expect(legacyBox.delegate.isOpen, isFalse);
    },
  );
}

final class _BoundarySetup {
  const _BoundarySetup({
    required this.profilesBox,
    required this.legacyBox,
    required this.repository,
  });

  final _BoundaryBox profilesBox;
  final _BoundaryBox legacyBox;
  final HiveGameProfilesRepository repository;
}

Future<_BoundarySetup> _boundaryRepository({
  required String directory,
  required String profilesBoxName,
  required String legacyBoxName,
  required GameProfilesState initial,
}) async {
  final hive = HiveImpl();
  final realProfilesBox = await hive.openBox<dynamic>(
    profilesBoxName,
    path: directory,
    crashRecovery: false,
  );
  final realLegacyBox = await hive.openBox<dynamic>(
    legacyBoxName,
    path: directory,
    crashRecovery: false,
  );
  await realProfilesBox.put(
    HiveGameProfilesRepository.stateKey,
    initial.toMap(),
  );
  await realProfilesBox.flush();
  final profilesBox = _BoundaryBox(realProfilesBox);
  final legacyBox = _BoundaryBox(realLegacyBox);
  return _BoundarySetup(
    profilesBox: profilesBox,
    legacyBox: legacyBox,
    repository: HiveGameProfilesRepository.fromBoxes(
      profilesBox: profilesBox,
      legacyBox: legacyBox,
    ),
  );
}

final class _BoundaryBox implements Box<dynamic> {
  _BoundaryBox(this.delegate);

  final Box<dynamic> delegate;
  Completer<void>? writeGate;
  Completer<void>? flushGate;
  bool failFlush = false;
  _ClosePlan? closePlan;
  int flushAttempts = 0;
  int closeAttempts = 0;

  @override
  bool containsKey(dynamic key) => delegate.containsKey(key);

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);

  @override
  Future<void> put(dynamic key, dynamic value) async {
    await writeGate?.future;
    await delegate.put(key, value);
  }

  @override
  Future<void> flush() async {
    flushAttempts++;
    await flushGate?.future;
    if (failFlush) throw const FileSystemException('injected flush failure');
    await delegate.flush();
  }

  @override
  Future<void> close() async {
    closeAttempts++;
    final plan = closePlan;
    if (plan != null && plan.shouldFail()) {
      throw const FileSystemException('injected close failure');
    }
    await delegate.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ClosePlan {
  _ClosePlan({this.failOnAttempt});

  int? failOnAttempt;
  int attempts = 0;

  bool shouldFail() {
    attempts++;
    return attempts == failOnAttempt;
  }
}

final DateTime _createdAt = DateTime.utc(2026, 10, 24, 8);

GameProfilesState _simpleState({required int coins}) {
  final profile = PlayerProfile(
    id: 'profile-1',
    name: 'Player',
    createdAt: _createdAt,
    updatedAt: _createdAt,
    coins: coins,
  );
  return GameProfilesState(
    activeProfileId: profile.id,
    profiles: {profile.id: profile},
    legacyMigrationComplete: true,
  );
}

GameProfilesState _fullState() {
  final fruitProgress = _progress(
    profileId: 'profile-b',
    gameId: GameId.fruitPop,
    completed: 5,
    generatedThrough: 15,
    active: true,
    pendingRefillThrough: 30,
  );
  final fruitProfile = PlayerProfile(
    id: 'profile-b',
    name: 'Guest',
    createdAt: _createdAt,
    updatedAt: _createdAt.add(const Duration(minutes: 7)),
    coins: 50,
    gamesPlayed: 6,
    gamesWon: 5,
    bestScore: 85,
    gameProgress: {GameId.fruitPop: fruitProgress},
  );

  final waterProgress = _progress(
    profileId: 'profile-a',
    gameId: GameId.waterSort,
    completed: 20,
    generatedThrough: 30,
    active: true,
  );
  final badge = GameBadge(
    gameId: GameId.waterSort,
    milestone: 20,
    earnedAt: _createdAt.add(const Duration(minutes: 20)),
  );
  final waterProfile = PlayerProfile(
    id: 'profile-a',
    name: 'Me',
    createdAt: _createdAt.add(const Duration(minutes: 1)),
    updatedAt: _createdAt.add(const Duration(minutes: 21)),
    coins: 390,
    gamesPlayed: 21,
    gamesWon: 20,
    bestScore: 100,
    gameProgress: {GameId.waterSort: waterProgress},
    badges: {badge.id: badge},
  );

  return GameProfilesState(
    activeProfileId: waterProfile.id,
    profiles: {fruitProfile.id: fruitProfile, waterProfile.id: waterProfile},
    legacyMigrationComplete: true,
  );
}

PlayerGameProgress _progress({
  required String profileId,
  required GameId gameId,
  required int completed,
  required int generatedThrough,
  required bool active,
  int? pendingRefillThrough,
}) {
  final descriptors = <int, GameLevelDescriptor>{
    for (var level = 1; level <= generatedThrough; level++)
      level: _descriptor(gameId, level),
  };
  final latestReceipt = completed == 0
      ? null
      : LevelCompletionReceipt(
          attemptId: '$profileId:${gameId.storageId}:$completed',
          attemptSequence: completed,
          level: completed,
          descriptorFingerprint: descriptors[completed]!.fingerprint,
          normalizedScore: 80 + (completed % 21),
          firstClear: true,
          coinsAwarded: GameTier.forLevel(completed).rewardCoins,
          badgeId: completed % 20 == 0
              ? '${gameId.storageId}:$completed'
              : null,
          currentLevelAfter: completed + 1,
          completedAt: _createdAt.add(Duration(minutes: completed)),
        );
  final sequence = completed + (active ? 1 : 0);
  final activeAttempt = active
      ? ActiveGameAttempt(
          attemptId: '$profileId:${gameId.storageId}:$sequence',
          sequence: sequence,
          level: completed + 1,
          playKind: GamePlayKind.current,
          descriptorFingerprint: descriptors[completed + 1]!.fingerprint,
          startedAt: _createdAt.add(Duration(minutes: sequence)),
        )
      : null;

  return PlayerGameProgress(
    gameId: gameId,
    currentLevel: completed + 1,
    generatedThrough: generatedThrough,
    descriptors: descriptors,
    fingerprints: descriptors.values
        .map((descriptor) => descriptor.fingerprint)
        .toSet(),
    clearedLevels: {for (var level = 1; level <= completed; level++) level},
    bestScores: {
      for (var level = 1; level <= completed; level++) level: 80 + (level % 21),
    },
    attempts: sequence,
    wins: completed,
    attemptSequence: sequence,
    activeAttempt: activeAttempt,
    latestReceipt: latestReceipt,
    highestCompletedLevel: completed,
    badgeMilestones: {
      for (var milestone = 20; milestone <= completed; milestone += 20)
        milestone,
    },
    pendingRefillThrough: pendingRefillThrough,
  );
}

GameLevelDescriptor _descriptor(GameId gameId, int level) {
  final identity = (GameId.values.indexOf(gameId) + 1) * 1000 + level;
  return GameLevelDescriptor(
    gameId: gameId,
    level: level,
    seed: identity,
    generatorVersion: 1,
    retrySalt: 0,
    fingerprint: identity.toRadixString(16).padLeft(64, '0'),
    tier: GameTier.forLevel(level),
    levelPressure: levelPressureFor(level),
  );
}

ProgressionChange<int> _coinChange(GameProfilesState current, int coins) {
  final active = current.activeProfile!;
  final updated = active.copyWith(coins: coins);
  final profiles = Map<String, PlayerProfile>.of(current.profiles)
    ..[active.id] = updated;
  return ProgressionChange<int>(
    state: current.copyWith(profiles: profiles),
    value: coins,
  );
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  if (!condition()) throw StateError('Timed out waiting for test boundary');
}
