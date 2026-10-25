import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_level_catalog.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final epoch = DateTime.utc(2026, 10, 24, 8);
  late _TestRegistry registry;
  late GameProgressionEngine engine;

  setUp(() {
    registry = _TestRegistry();
    engine = GameProgressionEngine(
      catalog: GameLevelCatalog(registry: registry),
    );
  });

  group('profile transitions', () {
    test('first profile imports pending legacy aggregates exactly once', () {
      final pending = _emptyState(
        pendingLegacySnapshot: LegacyGameProgressSnapshot(
          coins: 135,
          gamesPlayed: 12,
          gamesWon: 7,
          bestScore: 92,
        ),
        legacyMigrationComplete: false,
      );

      final first = engine.createProfile(
        state: pending,
        profileId: 'profile-1',
        name: 'Me',
        now: epoch,
      );
      expect(first.value.id, 'profile-1');
      expect(first.value.coins, 135);
      expect(first.value.gamesPlayed, 12);
      expect(first.value.gamesWon, 7);
      expect(first.value.bestScore, 92);
      expect(first.value.gameProgress, isEmpty);
      expect(first.state.pendingLegacySnapshot, isNull);
      expect(first.state.legacyMigrationComplete, isTrue);

      final second = engine.createProfile(
        state: first.state,
        profileId: 'profile-2',
        name: 'Guest',
        now: epoch.add(const Duration(minutes: 1)),
      );
      expect(second.value.coins, 0);
      expect(second.value.gamesPlayed, 0);
      expect(second.value.gamesWon, 0);
      expect(second.value.bestScore, 0);
      expect(second.state.profiles['profile-1']!.coins, 135);
    });

    test('create, rename, switch, and duplicate names are pure', () {
      final first = engine.createProfile(
        state: _emptyState(),
        profileId: 'profile-1',
        name: 'Me',
        now: epoch,
      );
      final second = engine.createProfile(
        state: first.state,
        profileId: 'profile-2',
        name: 'Guest',
        now: epoch.add(const Duration(minutes: 1)),
      );
      expect(first.state.profiles, hasLength(1));
      expect(second.state.activeProfileId, 'profile-2');
      expect(first.state.activeProfileId, 'profile-1');

      final renamed = engine.renameProfile(
        state: second.state,
        profileId: 'profile-1',
        name: '  Owner  ',
        now: epoch.add(const Duration(minutes: 2)),
      );
      expect(renamed.value.name, 'Owner');
      expect(renamed.value.updatedAt, epoch.add(const Duration(minutes: 2)));
      expect(second.state.profiles['profile-1']!.name, 'Me');

      final switched = engine.setActiveProfile(
        state: renamed.state,
        profileId: 'profile-1',
      );
      expect(switched.state.activeProfileId, 'profile-1');
      expect(switched.value.id, 'profile-1');
      expect(
        () => engine.renameProfile(
          state: switched.state,
          profileId: 'profile-1',
          name: 'guest',
          now: epoch.add(const Duration(minutes: 3)),
        ),
        throwsA(isA<GameProgressionException>()),
      );
    });

    test(
      'deleting active profile selects earliest-created remaining player',
      () {
        var state = _emptyState();
        for (final fixture in [
          ('profile-1', 'First', 1),
          ('profile-2', 'Second', 2),
          ('profile-3', 'Third', 3),
        ]) {
          state = engine
              .createProfile(
                state: state,
                profileId: fixture.$1,
                name: fixture.$2,
                now: epoch.add(Duration(minutes: fixture.$3)),
              )
              .state;
        }
        expect(state.activeProfileId, 'profile-3');

        final afterThird = engine.deleteProfile(
          state: state,
          profileId: 'profile-3',
        );
        expect(afterThird.state.activeProfileId, 'profile-1');
        expect(afterThird.state.profiles.keys, ['profile-1', 'profile-2']);

        final afterFirst = engine.deleteProfile(
          state: afterThird.state,
          profileId: 'profile-1',
        );
        expect(afterFirst.state.activeProfileId, 'profile-2');
        final empty = engine.deleteProfile(
          state: afterFirst.state,
          profileId: 'profile-2',
        );
        expect(empty.state.activeProfileId, isNull);
        expect(empty.state.profiles, isEmpty);
      },
    );
  });

  group('catalog preparation and refill', () {
    test('games prepare lazily and remain independent by profile and game', () {
      var state = _createdState(engine, epoch);
      state = engine
          .createProfile(
            state: state,
            profileId: 'profile-2',
            name: 'Guest',
            now: epoch.add(const Duration(minutes: 1)),
          )
          .state;

      final prepared = engine.prepareGame(
        state: state,
        profileId: 'profile-1',
        gameId: GameId.waterSort,
      );
      expect(prepared.value.generatedThrough, 15);
      expect(prepared.value.descriptors.keys, orderedEquals(_levels(1, 15)));
      expect(prepared.value.fingerprints, hasLength(15));
      expect(prepared.state.profiles['profile-1']!.gameProgress.keys, [
        GameId.waterSort,
      ]);
      expect(prepared.state.profiles['profile-2']!.gameProgress, isEmpty);
      expect(state.profiles['profile-1']!.gameProgress, isEmpty);

      var allGames = prepared.state;
      for (final gameId in GameId.values) {
        allGames = engine
            .prepareGame(
              state: allGames,
              profileId: 'profile-2',
              gameId: gameId,
            )
            .state;
      }
      expect(allGames.profiles['profile-2']!.gameProgress.keys, GameId.values);
      expect(allGames.profiles['profile-1']!.gameProgress.keys, [
        GameId.waterSort,
      ]);
    });

    test('repeated preparation is idempotent', () {
      final state = _preparedState(engine, epoch, GameId.waterSort);
      final before = state.toMap();
      final repeated = engine.prepareGame(
        state: state,
        profileId: 'profile-1',
        gameId: GameId.waterSort,
      );

      expect(repeated.state.toMap(), before);
      expect(repeated.value.generatedThrough, 15);
      expect(repeated.value.pendingRefillThrough, isNull);
    });

    test(
      'failed level-5 refill preserves completion and retries through 30',
      () {
        var state = _preparedState(engine, epoch, GameId.waterSort);
        for (var level = 1; level <= 4; level++) {
          state = _clearCurrent(
            engine,
            state,
            GameId.waterSort,
            epoch.add(Duration(minutes: level)),
            score: 70 + level,
          ).state;
        }
        final before = _progress(state, GameId.waterSort);
        final levelSixFingerprint = before.descriptors[6]!.fingerprint;
        registry.adapter(GameId.waterSort).failFromLevel = 16;

        final launch = engine.beginCurrentAttempt(
          state: state,
          profileId: 'profile-1',
          gameId: GameId.waterSort,
          startedAt: epoch.add(const Duration(minutes: 5)),
        );
        final completed = engine.completeLevel(
          state: launch.state,
          launch: launch.value,
          normalizedScore: 95,
          completedAt: epoch.add(const Duration(minutes: 6)),
        );
        final waiting = _progress(completed.state, GameId.waterSort);
        expect(completed.value.firstClear, isTrue);
        expect(completed.value.coinsAwarded, 10);
        expect(waiting.currentLevel, 6);
        expect(waiting.generatedThrough, 15);
        expect(waiting.descriptors[6]!.fingerprint, levelSixFingerprint);
        expect(waiting.pendingRefillThrough, 30);
        expect(completed.state.activeProfile!.coins, 50);

        registry.adapter(GameId.waterSort).failFromLevel = null;
        final retried = engine.prepareGame(
          state: completed.state,
          profileId: 'profile-1',
          gameId: GameId.waterSort,
        );
        expect(retried.value.currentLevel, 6);
        expect(retried.value.generatedThrough, 30);
        expect(retried.value.descriptors.keys, orderedEquals(_levels(1, 30)));
        expect(retried.value.descriptors[6]!.fingerprint, levelSixFingerprint);
        expect(retried.value.pendingRefillThrough, isNull);
        expect(retried.state.activeProfile!.coins, 50);
        expect(retried.state.activeProfile!.gamesWon, 5);
      },
    );
  });

  group('attempt settlement', () {
    test(
      'inactive profile cannot begin current play or mutate durable counters',
      () {
        var state = _preparedState(engine, epoch, GameId.waterSort);
        state = engine
            .createProfile(
              state: state,
              profileId: 'profile-2',
              name: 'Player Two',
              now: epoch.add(const Duration(minutes: 1)),
            )
            .state;
        final before = state.toMap();

        expect(
          () => engine.beginCurrentAttempt(
            state: state,
            profileId: 'profile-1',
            gameId: GameId.waterSort,
            startedAt: epoch.add(const Duration(minutes: 2)),
          ),
          throwsA(
            isA<GameProgressionException>().having(
              (error) => error.code,
              'code',
              GameProgressionError.staleAttempt,
            ),
          ),
        );
        expect(state.toMap(), before);
      },
    );

    test('inactive profile cannot begin replay or mutate durable counters', () {
      var state = _preparedState(engine, epoch, GameId.waterSort);
      state = _clearCurrent(
        engine,
        state,
        GameId.waterSort,
        epoch,
        score: 80,
      ).state;
      state = engine
          .createProfile(
            state: state,
            profileId: 'profile-2',
            name: 'Player Two',
            now: epoch.add(const Duration(minutes: 1)),
          )
          .state;
      final before = state.toMap();

      expect(
        () => engine.beginReplayAttempt(
          state: state,
          profileId: 'profile-1',
          gameId: GameId.waterSort,
          level: 1,
          startedAt: epoch.add(const Duration(minutes: 2)),
        ),
        throwsA(
          isA<GameProgressionException>().having(
            (error) => error.code,
            'code',
            GameProgressionError.staleAttempt,
          ),
        ),
      );
      expect(state.toMap(), before);
    });

    test(
      'switching profiles makes the old launch stale without mutating either player',
      () {
        var state = _createdState(engine, epoch);
        state = engine
            .createProfile(
              state: state,
              profileId: 'profile-2',
              name: 'Player Two',
              now: epoch.add(const Duration(minutes: 1)),
            )
            .state;
        state = engine
            .setActiveProfile(state: state, profileId: 'profile-1')
            .state;
        state = engine
            .prepareGame(
              state: state,
              profileId: 'profile-1',
              gameId: GameId.waterSort,
            )
            .state;
        final begun = engine.beginCurrentAttempt(
          state: state,
          profileId: 'profile-1',
          gameId: GameId.waterSort,
          startedAt: epoch.add(const Duration(minutes: 2)),
        );
        final switched = engine
            .setActiveProfile(state: begun.state, profileId: 'profile-2')
            .state;
        final before = switched.toMap();

        expect(
          () => engine.completeLevel(
            state: switched,
            launch: begun.value,
            normalizedScore: 100,
            completedAt: epoch.add(const Duration(minutes: 3)),
          ),
          throwsA(
            isA<GameProgressionException>().having(
              (error) => error.code,
              'code',
              GameProgressionError.staleAttempt,
            ),
          ),
        );
        expect(switched.toMap(), before);
        expect(switched.activeProfileId, 'profile-2');
        expect(switched.profiles['profile-2']!.coins, 0);
        expect(switched.profiles['profile-2']!.gamesWon, 0);
        final inactiveProgress =
            switched.profiles['profile-1']!.gameProgress[GameId.waterSort]!;
        expect(inactiveProgress.currentLevel, 1);
        expect(inactiveProgress.wins, 0);
        expect(
          inactiveProgress.activeAttempt?.attemptId,
          begun.value.attemptId,
        );
      },
    );

    test(
      'ordered begins allocate exact IDs and abandon the earlier attempt',
      () {
        final state = _preparedState(engine, epoch, GameId.waterSort);
        final first = engine.beginCurrentAttempt(
          state: state,
          profileId: 'profile-1',
          gameId: GameId.waterSort,
          startedAt: epoch,
        );
        final second = engine.beginCurrentAttempt(
          state: first.state,
          profileId: 'profile-1',
          gameId: GameId.waterSort,
          startedAt: epoch.add(const Duration(seconds: 1)),
        );

        expect(first.value.attemptId, 'profile-1:waterSort:1');
        expect(second.value.attemptId, 'profile-1:waterSort:2');
        final progress = _progress(second.state, GameId.waterSort);
        expect(progress.currentLevel, 1);
        expect(progress.attempts, 2);
        expect(progress.wins, 0);
        expect(progress.activeAttempt!.attemptId, second.value.attemptId);
        expect(second.state.activeProfile!.gamesPlayed, 2);
        expect(second.state.activeProfile!.gamesWon, 0);
        expect(
          () => engine.completeLevel(
            state: second.state,
            launch: first.value,
            normalizedScore: 80,
            completedAt: epoch.add(const Duration(seconds: 2)),
          ),
          throwsA(
            isA<GameProgressionException>().having(
              (error) => error.code,
              'code',
              GameProgressionError.staleAttempt,
            ),
          ),
        );
      },
    );

    test(
      'resume-or-begin creates the first current attempt when none exists',
      () {
        final state = _preparedState(engine, epoch, GameId.waterSort);

        final begun = engine.resumeOrBeginCurrentAttempt(
          state: state,
          profileId: 'profile-1',
          gameId: GameId.waterSort,
          startedAt: epoch.add(const Duration(seconds: 1)),
        );

        expect(begun.value.attemptId, 'profile-1:waterSort:1');
        expect(begun.value.descriptor.level, 1);
        expect(begun.value.playKind, GamePlayKind.current);
        final progress = _progress(begun.state, GameId.waterSort);
        expect(progress.attempts, 1);
        expect(progress.attemptSequence, 1);
        expect(progress.activeAttempt?.attemptId, 'profile-1:waterSort:1');
        expect(begun.state.activeProfile!.gamesPlayed, 1);
      },
    );

    test('resume-or-begin returns the matching current attempt unchanged', () {
      final state = _preparedState(engine, epoch, GameId.waterSort);
      final begun = engine.beginCurrentAttempt(
        state: state,
        profileId: 'profile-1',
        gameId: GameId.waterSort,
        startedAt: epoch,
      );
      final before = begun.state.toMap();

      final resumed = engine.resumeOrBeginCurrentAttempt(
        state: begun.state,
        profileId: 'profile-1',
        gameId: GameId.waterSort,
        startedAt: epoch.add(const Duration(seconds: 1)),
      );

      expect(resumed.value, begun.value);
      expect(resumed.state.toMap(), before);
      final progress = _progress(resumed.state, GameId.waterSort);
      expect(progress.attempts, 1);
      expect(progress.attemptSequence, 1);
      expect(resumed.state.activeProfile!.gamesPlayed, 1);
    });

    test(
      'resume-or-begin rejects an incompatible active attempt unchanged',
      () {
        var state = _preparedState(engine, epoch, GameId.waterSort);
        state = _clearCurrent(
          engine,
          state,
          GameId.waterSort,
          epoch,
          score: 80,
        ).state;
        final replay = engine.beginReplayAttempt(
          state: state,
          profileId: 'profile-1',
          gameId: GameId.waterSort,
          level: 1,
          startedAt: epoch.add(const Duration(seconds: 2)),
        );
        final before = replay.state.toMap();

        expect(
          () => engine.resumeOrBeginCurrentAttempt(
            state: replay.state,
            profileId: 'profile-1',
            gameId: GameId.waterSort,
            startedAt: epoch.add(const Duration(seconds: 3)),
          ),
          throwsA(
            isA<GameProgressionException>().having(
              (error) => error.code,
              'code',
              GameProgressionError.staleAttempt,
            ),
          ),
        );
        expect(replay.state.toMap(), before);
        final progress = _progress(replay.state, GameId.waterSort);
        expect(progress.activeAttempt?.attemptId, replay.value.attemptId);
        expect(progress.attempts, 2);
        expect(progress.attemptSequence, 2);
      },
    );

    test('first clear is idempotent until a newer attempt starts', () {
      final state = _preparedState(engine, epoch, GameId.waterSort);
      final launch = engine.beginCurrentAttempt(
        state: state,
        profileId: 'profile-1',
        gameId: GameId.waterSort,
        startedAt: epoch,
      );
      final first = engine.completeLevel(
        state: launch.state,
        launch: launch.value,
        normalizedScore: 72,
        completedAt: epoch.add(const Duration(seconds: 1)),
      );
      expect(first.value.alreadyApplied, isFalse);
      expect(first.value.currentLevelAfter, 2);
      expect(first.value.coinsAwarded, 10);

      final duplicate = engine.completeLevel(
        state: first.state,
        launch: launch.value,
        normalizedScore: 99,
        completedAt: epoch.add(const Duration(seconds: 2)),
      );
      expect(duplicate.value.alreadyApplied, isTrue);
      expect(duplicate.value.normalizedScore, 72);
      expect(duplicate.state.toMap(), first.state.toMap());

      final newer = engine.beginCurrentAttempt(
        state: duplicate.state,
        profileId: 'profile-1',
        gameId: GameId.waterSort,
        startedAt: epoch.add(const Duration(seconds: 3)),
      );
      expect(
        () => engine.completeLevel(
          state: newer.state,
          launch: launch.value,
          normalizedScore: 72,
          completedAt: epoch.add(const Duration(seconds: 4)),
        ),
        throwsA(
          isA<GameProgressionException>().having(
            (error) => error.code,
            'code',
            GameProgressionError.staleAttempt,
          ),
        ),
      );
    });

    test('replay can improve score but cannot advance or reward twice', () {
      var state = _preparedState(engine, epoch, GameId.fruitPop);
      state = _clearCurrent(
        engine,
        state,
        GameId.fruitPop,
        epoch,
        score: 55,
      ).state;
      final replay = engine.beginReplayAttempt(
        state: state,
        profileId: 'profile-1',
        gameId: GameId.fruitPop,
        level: 1,
        startedAt: epoch.add(const Duration(minutes: 1)),
      );
      expect(replay.value.attemptId, 'profile-1:fruitPop:2');
      expect(replay.value.playKind, GamePlayKind.replay);

      final completed = engine.completeLevel(
        state: replay.state,
        launch: replay.value,
        normalizedScore: 91,
        completedAt: epoch.add(const Duration(minutes: 2)),
      );
      final progress = _progress(completed.state, GameId.fruitPop);
      expect(completed.value.firstClear, isFalse);
      expect(completed.value.coinsAwarded, 0);
      expect(completed.value.currentLevelAfter, 2);
      expect(progress.currentLevel, 2);
      expect(progress.bestScores[1], 91);
      expect(progress.wins, 2);
      expect(completed.state.activeProfile!.coins, 10);
      expect(completed.state.activeProfile!.gamesPlayed, 2);
      expect(completed.state.activeProfile!.gamesWon, 2);
      expect(completed.state.activeProfile!.bestScore, 91);
    });

    test('unprepared and locked replay launches fail with typed errors', () {
      final unprepared = _createdState(engine, epoch);
      expect(
        () => engine.beginCurrentAttempt(
          state: unprepared,
          profileId: 'profile-1',
          gameId: GameId.rainbowRings,
          startedAt: epoch,
        ),
        throwsA(isA<GameProgressionException>()),
      );

      final prepared = _preparedState(engine, epoch, GameId.rainbowRings);
      expect(
        () => engine.beginReplayAttempt(
          state: prepared,
          profileId: 'profile-1',
          gameId: GameId.rainbowRings,
          level: 1,
          startedAt: epoch,
        ),
        throwsA(isA<GameProgressionException>()),
      );
    });

    test('levels 20, 40, and 60 earn one stable badge each', () {
      var state = _preparedState(engine, epoch, GameId.waterSort);
      final milestoneReceipts = <int, LevelCompletionReceipt>{};
      for (var level = 1; level <= 60; level++) {
        final clear = _clearCurrent(
          engine,
          state,
          GameId.waterSort,
          epoch.add(Duration(minutes: level)),
          score: 80,
        );
        state = clear.state;
        if (level % 20 == 0) milestoneReceipts[level] = clear.receipt;
      }

      expect(milestoneReceipts[20]!.badgeId, 'waterSort:20');
      expect(milestoneReceipts[40]!.badgeId, 'waterSort:40');
      expect(milestoneReceipts[60]!.badgeId, 'waterSort:60');
      expect(state.activeProfile!.badgeIds, {
        'waterSort:20',
        'waterSort:40',
        'waterSort:60',
      });
      expect(_progress(state, GameId.waterSort).badgeMilestones, {20, 40, 60});
      expect(state.activeProfile!.coins, 2390);

      final replay = engine.beginReplayAttempt(
        state: state,
        profileId: 'profile-1',
        gameId: GameId.waterSort,
        level: 20,
        startedAt: epoch.add(const Duration(hours: 2)),
      );
      final replayed = engine.completeLevel(
        state: replay.state,
        launch: replay.value,
        normalizedScore: 100,
        completedAt: epoch.add(const Duration(hours: 2, seconds: 1)),
      );
      expect(replayed.value.badgeId, isNull);
      expect(replayed.value.coinsAwarded, 0);
      expect(
        replayed.state.activeProfile!.badgeIds,
        state.activeProfile!.badgeIds,
      );
      expect(replayed.state.activeProfile!.coins, 2390);
    });
  });
}

GameProfilesState _emptyState({
  LegacyGameProgressSnapshot? pendingLegacySnapshot,
  bool legacyMigrationComplete = true,
}) => GameProfilesState(
  activeProfileId: null,
  profiles: const {},
  pendingLegacySnapshot: pendingLegacySnapshot,
  legacyMigrationComplete: legacyMigrationComplete,
);

GameProfilesState _createdState(GameProgressionEngine engine, DateTime now) =>
    engine
        .createProfile(
          state: _emptyState(),
          profileId: 'profile-1',
          name: 'Player One',
          now: now,
        )
        .state;

GameProfilesState _preparedState(
  GameProgressionEngine engine,
  DateTime now,
  GameId gameId,
) => engine
    .prepareGame(
      state: _createdState(engine, now),
      profileId: 'profile-1',
      gameId: gameId,
    )
    .state;

PlayerGameProgress _progress(GameProfilesState state, GameId gameId) =>
    state.activeProfile!.gameProgress[gameId]!;

({GameProfilesState state, LevelCompletionReceipt receipt, GameLaunch launch})
_clearCurrent(
  GameProgressionEngine engine,
  GameProfilesState state,
  GameId gameId,
  DateTime at, {
  required int score,
}) {
  final begun = engine.beginCurrentAttempt(
    state: state,
    profileId: 'profile-1',
    gameId: gameId,
    startedAt: at,
  );
  final completed = engine.completeLevel(
    state: begun.state,
    launch: begun.value,
    normalizedScore: score,
    completedAt: at.add(const Duration(seconds: 1)),
  );
  return (
    state: completed.state,
    receipt: completed.value,
    launch: begun.value,
  );
}

List<int> _levels(int start, int end) => [
  for (var level = start; level <= end; level++) level,
];

final class _TestRegistry implements GameLevelAdapterRegistry {
  _TestRegistry()
    : _adapters = {
        for (final gameId in GameId.values) gameId: _TestAdapter(gameId),
      };

  final Map<GameId, _TestAdapter> _adapters;

  _TestAdapter adapter(GameId gameId) => _adapters[gameId]!;

  @override
  GameLevelAdapter adapterFor(GameId gameId) => adapter(gameId);
}

final class _TestAdapter implements GameLevelAdapter {
  _TestAdapter(this.gameId);

  @override
  final GameId gameId;

  int? failFromLevel;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  GameLevelLayout build(GameLevelDescriptor descriptor) {
    final failureBoundary = failFromLevel;
    if (failureBoundary != null && descriptor.level >= failureBoundary) {
      throw StateError('Injected generation failure at ${descriptor.level}');
    }
    return _TestLayout(
      '${gameId.storageId}:${descriptor.level}:${descriptor.seed}:'
      '${descriptor.retrySalt}',
    );
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) =>
      throw UnsupportedError('Normalization is outside the pure engine');
}

final class _TestLayout implements GameLevelLayout {
  const _TestLayout(this.canonicalSignature);

  @override
  final String canonicalSignature;
}
