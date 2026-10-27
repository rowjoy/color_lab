import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/hive_game_profiles_repository.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../domain/game_id.dart';
import '../domain/game_leaderboard.dart';
import '../domain/game_launch.dart';
import '../domain/game_level_adapter.dart';
import '../domain/game_profiles_repository.dart';
import '../domain/game_profiles_state.dart';
import '../domain/game_progression_engine.dart';
import '../domain/player_profile.dart';
import 'game_adapter_registry.dart';

final gameProfilesDirectoryProvider = appStorageDirectoryProvider;

final gameProfilesRepositoryProvider = FutureProvider<GameProfilesRepository>((
  ref,
) async {
  final storage = await ref.watch(appStorageDirectoryProvider.future);
  if (!ref.mounted) {
    throw StateError('Game profiles were disposed during initialization.');
  }
  final directory = resolveAppStorageDirectory(storage);

  final repository = await HiveGameProfilesRepository.open(
    directory: directory.path,
  );
  if (!ref.mounted) {
    await repository.close();
    throw StateError('Game profiles were disposed during initialization.');
  }
  ref.onDispose(() {
    unawaited(
      repository.close().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Game profiles could not be closed cleanly.');
      }),
    );
  });
  return repository;
}, retry: (retryCount, error) => null);

final gameProfilesClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

final gameProfileIdFactoryProvider = Provider<String Function()>((ref) {
  final random = math.Random.secure();
  var sequence = 0;
  return () {
    sequence++;
    final timestamp = DateTime.now()
        .toUtc()
        .microsecondsSinceEpoch
        .toRadixString(36);
    final entropy = random.nextInt(0x7fffffff).toRadixString(36);
    return 'profile-$timestamp-$sequence-$entropy';
  };
});

final gameProfilesProvider =
    AsyncNotifierProvider<GameProfilesController, GameProfilesState>(
      GameProfilesController.new,
      retry: (retryCount, error) => null,
    );

final activePlayerProfileProvider = Provider<PlayerProfile?>((ref) {
  final profiles = ref.watch(gameProfilesProvider);
  return profiles.hasValue ? profiles.requireValue.activeProfile : null;
});

final activeGameProgressProvider = Provider.family<PlayerGameProgress?, GameId>(
  (ref, gameId) {
    return ref.watch(activePlayerProfileProvider)?.gameProgress[gameId];
  },
);

final overallLeaderboardProvider = Provider<List<LeaderboardEntry>>((ref) {
  final profiles = ref.watch(gameProfilesProvider);
  return profiles.hasValue
      ? overallLeaderboard(profiles.requireValue)
      : const <LeaderboardEntry>[];
});

final gameLeaderboardProvider = Provider.family<List<LeaderboardEntry>, GameId>(
  (ref, gameId) {
    final profiles = ref.watch(gameProfilesProvider);
    return profiles.hasValue
        ? gameLeaderboard(profiles.requireValue, gameId)
        : const <LeaderboardEntry>[];
  },
);

final class GameProfilesController extends AsyncNotifier<GameProfilesState> {
  Future<void> _pending = Future<void>.value();

  @override
  Future<GameProfilesState> build() async {
    final repository = await ref.watch(gameProfilesRepositoryProvider.future);
    _ensureMounted();
    final loaded = await repository.loadState();
    _ensureMounted();
    return loaded;
  }

  Future<T> _enqueue<T>(
    Future<T> Function(
      GameProfilesRepository repository,
      GameProgressionEngine engine,
    )
    operation,
  ) {
    if (!ref.mounted) {
      return Future<T>.error(
        StateError('Game profiles are no longer available.'),
      );
    }

    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        _ensureMounted();
        await future;
        _ensureMounted();
        final repository = await ref.read(
          gameProfilesRepositoryProvider.future,
        );
        _ensureMounted();
        final engine = ref.read(gameProgressionEngineProvider);
        final value = await operation(repository, engine);
        _ensureMounted();
        result.complete(value);
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<T> _transact<T>(
    ProgressionChange<T> Function(
      GameProgressionEngine engine,
      GameProfilesState current,
    )
    transition,
  ) => _enqueue((repository, engine) async {
    final change = await repository.transact<T>(
      (current) => transition(engine, current),
    );
    _ensureMounted();
    state = AsyncData(change.state);
    return change.value;
  });

  Future<PlayerProfile> createProfile({required String name}) async {
    _ensureMounted();
    final profileId = ref.read(gameProfileIdFactoryProvider)();
    final now = _utcNow();
    return _transact(
      (engine, current) => engine.createProfile(
        state: current,
        profileId: profileId,
        name: name,
        now: now,
      ),
    );
  }

  Future<PlayerProfile> renameProfile({
    required String profileId,
    required String name,
  }) async {
    _ensureMounted();
    final now = _utcNow();
    return _transact(
      (engine, current) => engine.renameProfile(
        state: current,
        profileId: profileId,
        name: name,
        now: now,
      ),
    );
  }

  Future<PlayerProfile> deleteProfile({required String profileId}) => _transact(
    (engine, current) =>
        engine.deleteProfile(state: current, profileId: profileId),
  );

  Future<PlayerProfile> setActiveProfile({required String profileId}) =>
      _transact(
        (engine, current) =>
            engine.setActiveProfile(state: current, profileId: profileId),
      );

  Future<PlayerGameProgress> prepareGame({
    required String profileId,
    required GameId gameId,
  }) => _transact((engine, current) {
    try {
      return engine.prepareGame(
        state: current,
        profileId: profileId,
        gameId: gameId,
      );
    } on GameProgressionException catch (error) {
      final progress = current.profiles[profileId]?.gameProgress[gameId];
      if (error.code != GameProgressionError.generationFailed ||
          progress?.descriptors.containsKey(progress.currentLevel) != true) {
        rethrow;
      }
      return ProgressionChange(state: current, value: progress!);
    }
  });

  /// Prepares the first level and persists its attempt in one write so a game
  /// tile can launch without waiting for two sequential storage transactions.
  Future<GameLaunch> prepareAndResumeGame({
    required String profileId,
    required GameId gameId,
  }) {
    final startedAt = _utcNow();
    return _transact((engine, current) {
      late ProgressionChange<PlayerGameProgress> prepared;
      try {
        prepared = engine.prepareGame(
          state: current,
          profileId: profileId,
          gameId: gameId,
          initialBatchSize: 1,
        );
      } on GameProgressionException catch (error) {
        final existing = current.profiles[profileId]?.gameProgress[gameId];
        if (error.code != GameProgressionError.generationFailed ||
            existing?.descriptors.containsKey(existing.currentLevel) != true) {
          rethrow;
        }
        prepared = ProgressionChange(state: current, value: existing!);
      }
      final launch = engine.resumeOrBeginCurrentAttempt(
        state: prepared.state,
        profileId: profileId,
        gameId: gameId,
        startedAt: startedAt,
      );
      return ProgressionChange(state: launch.state, value: launch.value);
    });
  }

  /// Removes a just-created attempt when its launch lost an active-player
  /// race before navigation. Existing/resumed attempts are never discarded.
  Future<PlayerProfile> discardStaleNewAttempt({
    required PlayerProfile originalProfile,
    required GameLaunch launch,
  }) => _transact((engine, current) {
    final currentProfile = current.profiles[launch.profileId];
    if (currentProfile == null ||
        current.activeProfileId == launch.profileId ||
        originalProfile.id != launch.profileId) {
      return ProgressionChange(
        state: current,
        value: currentProfile ?? originalProfile,
      );
    }

    final originalProgress = originalProfile.gameProgress[launch.gameId];
    final currentProgress = currentProfile.gameProgress[launch.gameId];
    final startedHere =
        originalProgress?.activeAttempt == null &&
        currentProgress?.activeAttempt?.attemptId == launch.attemptId &&
        currentProfile.gamesPlayed == originalProfile.gamesPlayed + 1 &&
        currentProgress!.attempts == (originalProgress?.attempts ?? 0) + 1 &&
        currentProfile.coins == originalProfile.coins &&
        currentProfile.gamesWon == originalProfile.gamesWon &&
        currentProfile.bestScore == originalProfile.bestScore &&
        currentProfile.badges.length == originalProfile.badges.length;
    if (!startedHere) {
      return ProgressionChange(state: current, value: currentProfile);
    }

    final profiles = <String, PlayerProfile>{...current.profiles};
    profiles[originalProfile.id] = originalProfile;
    final restored = current.copyWith(profiles: profiles);
    return ProgressionChange(state: restored, value: originalProfile);
  });

  Future<GameLaunch> beginCurrentAttempt({
    required String profileId,
    required GameId gameId,
  }) async {
    _ensureMounted();
    final startedAt = _utcNow();
    return _transact(
      (engine, current) => engine.beginCurrentAttempt(
        state: current,
        profileId: profileId,
        gameId: gameId,
        startedAt: startedAt,
      ),
    );
  }

  Future<GameLaunch> resumeOrBeginCurrentAttempt({
    required String profileId,
    required GameId gameId,
  }) async {
    _ensureMounted();
    final startedAt = _utcNow();
    return _transact(
      (engine, current) => engine.resumeOrBeginCurrentAttempt(
        state: current,
        profileId: profileId,
        gameId: gameId,
        startedAt: startedAt,
      ),
    );
  }

  Future<GameLaunch> beginReplayAttempt({
    required String profileId,
    required GameId gameId,
    required int level,
  }) async {
    _ensureMounted();
    final startedAt = _utcNow();
    return _transact(
      (engine, current) => engine.beginReplayAttempt(
        state: current,
        profileId: profileId,
        gameId: gameId,
        level: level,
        startedAt: startedAt,
      ),
    );
  }

  Future<LevelCompletionReceipt> completeLevel(
    GameLaunch launch,
    GameLevelOutcome outcome,
  ) async {
    _ensureMounted();
    final adapter = ref
        .read(gameAdapterRegistryProvider)
        .adapterFor(launch.gameId);
    final normalizedScore = adapter.normalizeScore(outcome);
    final completedAt = _utcNow();

    return _enqueue((repository, engine) async {
      final completed = await repository.transact<LevelCompletionReceipt>(
        (current) => engine.completeLevel(
          state: current,
          launch: launch,
          normalizedScore: normalizedScore,
          completedAt: completedAt,
        ),
      );
      _ensureMounted();
      state = AsyncData(completed.state);

      final pending = completed
          .state
          .profiles[launch.profileId]
          ?.gameProgress[launch.gameId]
          ?.pendingRefillThrough;
      if (pending != null) {
        try {
          final refilled = await repository.transact<PlayerGameProgress>(
            (current) => engine.prepareGame(
              state: current,
              profileId: launch.profileId,
              gameId: launch.gameId,
            ),
          );
          _ensureMounted();
          state = AsyncData(refilled.state);
        } on GameProgressionException catch (error) {
          if (error.code != GameProgressionError.generationFailed) rethrow;
        }
      }
      return completed.value;
    });
  }

  void retry() {
    if (!ref.mounted) return;
    if (ref.read(gameProfilesDirectoryProvider).hasError) {
      ref.invalidate(gameProfilesDirectoryProvider);
    }
    if (ref.read(gameProfilesRepositoryProvider).hasError) {
      ref.invalidate(gameProfilesRepositoryProvider);
    }
    ref.invalidateSelf();
  }

  DateTime _utcNow() => ref.read(gameProfilesClockProvider)().toUtc();

  void _ensureMounted() {
    if (!ref.mounted) {
      throw StateError('Game profiles are no longer available.');
    }
  }
}
