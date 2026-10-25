import 'game_badge.dart';
import 'game_id.dart';
import 'game_launch.dart';
import 'game_level.dart';
import 'game_level_catalog.dart';
import 'game_profiles_state.dart';
import 'player_profile.dart';

/// The immutable result of applying one pure progression transition.
final class ProgressionChange<T> {
  const ProgressionChange({required this.state, required this.value});

  final GameProfilesState state;
  final T value;
}

enum GameProgressionError {
  profileNotFound,
  duplicateProfileId,
  duplicateProfileName,
  invalidProfile,
  gameNotPrepared,
  levelLocked,
  staleAttempt,
  invalidScore,
  generationFailed,
}

final class GameProgressionException implements Exception {
  const GameProgressionException(this.code, this.message, [this.cause]);

  final GameProgressionError code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'GameProgressionException(${code.name}): $message';
}

/// Pure state transitions for local profiles and endless game progression.
final class GameProgressionEngine {
  const GameProgressionEngine({required this.catalog});

  final GameLevelCatalog catalog;

  ProgressionChange<PlayerProfile> createProfile({
    required GameProfilesState state,
    required String profileId,
    required String name,
    required DateTime now,
  }) {
    if (state.profiles.containsKey(profileId)) {
      throw GameProgressionException(
        GameProgressionError.duplicateProfileId,
        'A profile with ID $profileId already exists',
      );
    }

    final normalizedName = _normalizedName(name);
    if (state.profiles.values.any(
      (profile) => profile.normalizedName == normalizedName,
    )) {
      throw GameProgressionException(
        GameProgressionError.duplicateProfileName,
        'A profile named $name already exists',
      );
    }

    final legacy = state.pendingLegacySnapshot;
    final profile = _buildProfile(
      id: profileId,
      name: name,
      createdAt: now,
      updatedAt: now,
      coins: legacy?.coins ?? 0,
      gamesPlayed: legacy?.gamesPlayed ?? 0,
      gamesWon: legacy?.gamesWon ?? 0,
      bestScore: legacy?.bestScore ?? 0,
    );
    final profiles = <String, PlayerProfile>{
      ...state.profiles,
      profile.id: profile,
    };
    final nextState = GameProfilesState(
      activeProfileId: profile.id,
      profiles: profiles,
      legacyMigrationComplete: true,
    );
    return ProgressionChange(state: nextState, value: profile);
  }

  ProgressionChange<PlayerProfile> renameProfile({
    required GameProfilesState state,
    required String profileId,
    required String name,
    required DateTime now,
  }) {
    final profile = _requireProfile(state, profileId);
    final normalizedName = _normalizedName(name);
    if (state.profiles.values.any(
      (candidate) =>
          candidate.id != profileId &&
          candidate.normalizedName == normalizedName,
    )) {
      throw GameProgressionException(
        GameProgressionError.duplicateProfileName,
        'A profile named $name already exists',
      );
    }

    final renamed = _copyProfile(profile, name: name, updatedAt: now);
    final nextState = state.copyWith(
      profiles: _replaceProfile(state.profiles, renamed),
    );
    return ProgressionChange(state: nextState, value: renamed);
  }

  ProgressionChange<PlayerProfile> deleteProfile({
    required GameProfilesState state,
    required String profileId,
  }) {
    final removed = _requireProfile(state, profileId);
    final profiles = <String, PlayerProfile>{...state.profiles}
      ..remove(profileId);
    var activeProfileId = state.activeProfileId;
    if (activeProfileId == profileId) {
      activeProfileId = profiles.isEmpty
          ? null
          : _earliestProfile(profiles.values).id;
    }
    final nextState = state.copyWith(
      activeProfileId: activeProfileId,
      profiles: profiles,
    );
    return ProgressionChange(state: nextState, value: removed);
  }

  ProgressionChange<PlayerProfile> setActiveProfile({
    required GameProfilesState state,
    required String profileId,
  }) {
    final profile = _requireProfile(state, profileId);
    return ProgressionChange(
      state: state.copyWith(activeProfileId: profileId),
      value: profile,
    );
  }

  ProgressionChange<PlayerGameProgress> prepareGame({
    required GameProfilesState state,
    required String profileId,
    required GameId gameId,
    int initialBatchSize = GameLevelCatalog.initialBatchSize,
  }) {
    if (initialBatchSize < 1) {
      throw ArgumentError.value(
        initialBatchSize,
        'initialBatchSize',
        'Must be positive',
      );
    }
    final profile = _requireProfile(state, profileId);
    final existing = profile.gameProgress[gameId];
    if (existing == null) {
      final descriptors = _generate(
        profileId: profileId,
        gameId: gameId,
        startLevel: 1,
        count: initialBatchSize,
        existingByLevel: const {},
        existingFingerprints: const {},
      );
      final byLevel = <int, GameLevelDescriptor>{
        for (final descriptor in descriptors) descriptor.level: descriptor,
      };
      final progress = PlayerGameProgress(
        gameId: gameId,
        generatedThrough: initialBatchSize,
        descriptors: byLevel,
        fingerprints: {
          for (final descriptor in descriptors) descriptor.fingerprint,
        },
      );
      return _withProgress(state, profile, progress);
    }

    final pendingTarget = existing.pendingRefillThrough;
    final shouldRefill =
        pendingTarget != null ||
        catalog.needsRefill(
          currentLevel: existing.currentLevel,
          generatedThrough: existing.generatedThrough,
        );
    if (!shouldRefill) {
      return ProgressionChange(state: state, value: existing);
    }

    final target =
        pendingTarget ??
        existing.generatedThrough + GameLevelCatalog.refillBatchSize;
    final generated = _generate(
      profileId: profileId,
      gameId: gameId,
      startLevel: existing.generatedThrough + 1,
      count: target - existing.generatedThrough,
      existingByLevel: existing.descriptors,
      existingFingerprints: existing.fingerprints,
    );
    final descriptors = <int, GameLevelDescriptor>{...existing.descriptors};
    final fingerprints = <String>{...existing.fingerprints};
    for (final descriptor in generated) {
      descriptors[descriptor.level] = descriptor;
      fingerprints.add(descriptor.fingerprint);
    }
    final progress = existing.copyWith(
      generatedThrough: target,
      descriptors: descriptors,
      fingerprints: fingerprints,
      pendingRefillThrough: null,
    );
    return _withProgress(state, profile, progress);
  }

  ProgressionChange<GameLaunch> beginCurrentAttempt({
    required GameProfilesState state,
    required String profileId,
    required GameId gameId,
    required DateTime startedAt,
  }) {
    final profile = _requireActiveProfile(state, profileId);
    final progress = _requireProgress(profile, gameId);
    return _beginAttempt(
      state: state,
      profile: profile,
      progress: progress,
      level: progress.currentLevel,
      playKind: GamePlayKind.current,
      startedAt: startedAt,
    );
  }

  /// Resumes the durable current-level attempt, or creates it atomically.
  ///
  /// Unlike [beginCurrentAttempt], this transition never abandons an existing
  /// attempt. Callers use it when retrying a start whose durable outcome may
  /// already exist even though the storage operation reported an error.
  ProgressionChange<GameLaunch> resumeOrBeginCurrentAttempt({
    required GameProfilesState state,
    required String profileId,
    required GameId gameId,
    required DateTime startedAt,
  }) {
    final profile = _requireActiveProfile(state, profileId);
    final progress = _requireProgress(profile, gameId);
    final active = progress.activeAttempt;
    if (active == null) {
      return _beginAttempt(
        state: state,
        profile: profile,
        progress: progress,
        level: progress.currentLevel,
        playKind: GamePlayKind.current,
        startedAt: startedAt,
      );
    }

    final descriptor = progress.descriptors[progress.currentLevel];
    if (descriptor == null) {
      throw GameProgressionException(
        GameProgressionError.gameNotPrepared,
        'Level ${progress.currentLevel} has not been generated',
      );
    }
    if (active.sequence != progress.attemptSequence ||
        active.level != progress.currentLevel ||
        active.playKind != GamePlayKind.current ||
        active.descriptorFingerprint != descriptor.fingerprint) {
      throw const GameProgressionException(
        GameProgressionError.staleAttempt,
        'A different attempt is already active',
      );
    }

    return ProgressionChange(
      state: state,
      value: GameLaunch(
        profileId: profileId,
        gameId: gameId,
        descriptor: descriptor,
        attemptId: active.attemptId,
        playKind: GamePlayKind.current,
      ),
    );
  }

  ProgressionChange<GameLaunch> beginReplayAttempt({
    required GameProfilesState state,
    required String profileId,
    required GameId gameId,
    required int level,
    required DateTime startedAt,
  }) {
    final profile = _requireActiveProfile(state, profileId);
    final progress = _requireProgress(profile, gameId);
    if (!progress.clearedLevels.contains(level)) {
      throw GameProgressionException(
        GameProgressionError.levelLocked,
        'Level $level has not been cleared',
      );
    }
    return _beginAttempt(
      state: state,
      profile: profile,
      progress: progress,
      level: level,
      playKind: GamePlayKind.replay,
      startedAt: startedAt,
    );
  }

  ProgressionChange<LevelCompletionReceipt> completeLevel({
    required GameProfilesState state,
    required GameLaunch launch,
    required int normalizedScore,
    required DateTime completedAt,
  }) {
    if (state.activeProfileId != launch.profileId) {
      throw const GameProgressionException(
        GameProgressionError.staleAttempt,
        'The attempt does not belong to the active profile',
      );
    }
    final profile = _requireProfile(state, launch.profileId);
    final progress = _requireProgress(profile, launch.gameId);
    final activeAttempt = progress.activeAttempt;
    if (activeAttempt == null) {
      final receipt = progress.latestReceipt;
      if (receipt != null && receipt.attemptId == launch.attemptId) {
        return ProgressionChange(
          state: state,
          value: receipt.asAlreadyApplied(),
        );
      }
      throw const GameProgressionException(
        GameProgressionError.staleAttempt,
        'The attempt is no longer active',
      );
    }
    if (activeAttempt.attemptId != launch.attemptId ||
        activeAttempt.level != launch.descriptor.level ||
        activeAttempt.playKind != launch.playKind ||
        activeAttempt.descriptorFingerprint != launch.descriptor.fingerprint ||
        progress.descriptors[activeAttempt.level] != launch.descriptor) {
      throw const GameProgressionException(
        GameProgressionError.staleAttempt,
        'The launch does not match the active attempt',
      );
    }
    if (normalizedScore < 0 || normalizedScore > 100) {
      throw GameProgressionException(
        GameProgressionError.invalidScore,
        'Normalized score must be between 0 and 100',
      );
    }

    final firstClear = activeAttempt.playKind == GamePlayKind.current;
    final level = activeAttempt.level;
    final currentLevelAfter = firstClear
        ? progress.currentLevel + 1
        : progress.currentLevel;
    final coinsAwarded = firstClear ? GameTier.forLevel(level).rewardCoins : 0;
    final earnsBadge = firstClear && level % 20 == 0;
    final badgeId = earnsBadge ? '${launch.gameId.storageId}:$level' : null;
    final receipt = LevelCompletionReceipt(
      attemptId: activeAttempt.attemptId,
      attemptSequence: activeAttempt.sequence,
      level: level,
      descriptorFingerprint: activeAttempt.descriptorFingerprint,
      normalizedScore: normalizedScore,
      firstClear: firstClear,
      coinsAwarded: coinsAwarded,
      badgeId: badgeId,
      currentLevelAfter: currentLevelAfter,
      completedAt: completedAt,
    );

    final clearedLevels = <int>{...progress.clearedLevels};
    final bestScores = <int, int>{...progress.bestScores};
    final previousBest = bestScores[level];
    if (previousBest == null || normalizedScore > previousBest) {
      bestScores[level] = normalizedScore;
    }
    if (firstClear) clearedLevels.add(level);

    final milestones = <int>{...progress.badgeMilestones};
    if (earnsBadge) milestones.add(level);

    var generatedThrough = progress.generatedThrough;
    var descriptors = <int, GameLevelDescriptor>{...progress.descriptors};
    var fingerprints = <String>{...progress.fingerprints};
    var pendingRefillThrough = progress.pendingRefillThrough;
    final needsRefill =
        firstClear &&
        (pendingRefillThrough != null ||
            catalog.needsRefill(
              currentLevel: currentLevelAfter,
              generatedThrough: generatedThrough,
            ));
    if (needsRefill) {
      final target =
          pendingRefillThrough ??
          generatedThrough + GameLevelCatalog.refillBatchSize;
      try {
        final generated = catalog.generateBatch(
          profileId: profile.id,
          gameId: launch.gameId,
          startLevel: generatedThrough + 1,
          count: target - generatedThrough,
          existingByLevel: descriptors,
          existingFingerprints: fingerprints,
        );
        for (final descriptor in generated) {
          descriptors[descriptor.level] = descriptor;
          fingerprints.add(descriptor.fingerprint);
        }
        generatedThrough = target;
        pendingRefillThrough = null;
      } on Object {
        // Completion is already earned. Keep it durable and make generation
        // explicitly retryable through prepareGame rather than rolling back.
        pendingRefillThrough = target;
      }
    }

    final updatedProgress = PlayerGameProgress(
      gameId: progress.gameId,
      currentLevel: currentLevelAfter,
      generatedThrough: generatedThrough,
      descriptors: descriptors,
      fingerprints: fingerprints,
      clearedLevels: clearedLevels,
      bestScores: bestScores,
      attempts: progress.attempts,
      wins: progress.wins + 1,
      attemptSequence: progress.attemptSequence,
      latestReceipt: receipt,
      highestCompletedLevel: firstClear
          ? progress.highestCompletedLevel + 1
          : progress.highestCompletedLevel,
      badgeMilestones: milestones,
      pendingRefillThrough: pendingRefillThrough,
    );

    final gameProgress = <GameId, PlayerGameProgress>{
      ...profile.gameProgress,
      launch.gameId: updatedProgress,
    };
    final badges = <String, GameBadge>{...profile.badges};
    if (earnsBadge) {
      final badge = GameBadge(
        gameId: launch.gameId,
        milestone: level,
        earnedAt: completedAt,
      );
      badges[badge.id] = badge;
    }
    final updatedProfile = _copyProfile(
      profile,
      updatedAt: completedAt,
      coins: profile.coins + coinsAwarded,
      gamesWon: profile.gamesWon + 1,
      bestScore: normalizedScore > profile.bestScore
          ? normalizedScore
          : profile.bestScore,
      gameProgress: gameProgress,
      badges: badges,
    );
    final nextState = state.copyWith(
      profiles: _replaceProfile(state.profiles, updatedProfile),
    );
    return ProgressionChange(state: nextState, value: receipt);
  }

  ProgressionChange<GameLaunch> _beginAttempt({
    required GameProfilesState state,
    required PlayerProfile profile,
    required PlayerGameProgress progress,
    required int level,
    required GamePlayKind playKind,
    required DateTime startedAt,
  }) {
    final descriptor = progress.descriptors[level];
    if (descriptor == null) {
      throw GameProgressionException(
        GameProgressionError.gameNotPrepared,
        'Level $level has not been generated',
      );
    }
    final sequence = progress.attemptSequence + 1;
    final attemptId = '${profile.id}:${progress.gameId.storageId}:$sequence';
    final attempt = ActiveGameAttempt(
      attemptId: attemptId,
      sequence: sequence,
      level: level,
      playKind: playKind,
      descriptorFingerprint: descriptor.fingerprint,
      startedAt: startedAt,
    );
    final updatedProgress = progress.copyWith(
      attempts: progress.attempts + 1,
      attemptSequence: sequence,
      activeAttempt: attempt,
    );
    final gameProgress = <GameId, PlayerGameProgress>{
      ...profile.gameProgress,
      progress.gameId: updatedProgress,
    };
    final updatedProfile = _copyProfile(
      profile,
      updatedAt: startedAt,
      gamesPlayed: profile.gamesPlayed + 1,
      gameProgress: gameProgress,
    );
    final nextState = state.copyWith(
      profiles: _replaceProfile(state.profiles, updatedProfile),
    );
    final launch = GameLaunch(
      profileId: profile.id,
      gameId: progress.gameId,
      descriptor: descriptor,
      attemptId: attemptId,
      playKind: playKind,
    );
    return ProgressionChange(state: nextState, value: launch);
  }

  ProgressionChange<PlayerGameProgress> _withProgress(
    GameProfilesState state,
    PlayerProfile profile,
    PlayerGameProgress progress,
  ) {
    final gameProgress = <GameId, PlayerGameProgress>{
      ...profile.gameProgress,
      progress.gameId: progress,
    };
    final updatedProfile = _copyProfile(profile, gameProgress: gameProgress);
    final nextState = state.copyWith(
      profiles: _replaceProfile(state.profiles, updatedProfile),
    );
    return ProgressionChange(state: nextState, value: progress);
  }

  List<GameLevelDescriptor> _generate({
    required String profileId,
    required GameId gameId,
    required int startLevel,
    required int count,
    required Map<int, GameLevelDescriptor> existingByLevel,
    required Set<String> existingFingerprints,
  }) {
    try {
      return catalog.generateBatch(
        profileId: profileId,
        gameId: gameId,
        startLevel: startLevel,
        count: count,
        existingByLevel: existingByLevel,
        existingFingerprints: existingFingerprints,
      );
    } on Object catch (error) {
      throw GameProgressionException(
        GameProgressionError.generationFailed,
        'Could not generate ${gameId.storageId} levels',
        error,
      );
    }
  }
}

PlayerProfile _requireProfile(GameProfilesState state, String profileId) {
  final profile = state.profiles[profileId];
  if (profile == null) {
    throw GameProgressionException(
      GameProgressionError.profileNotFound,
      'Unknown profile $profileId',
    );
  }
  return profile;
}

PlayerProfile _requireActiveProfile(GameProfilesState state, String profileId) {
  final profile = _requireProfile(state, profileId);
  if (state.activeProfileId != profileId) {
    throw const GameProgressionException(
      GameProgressionError.staleAttempt,
      'The attempt does not belong to the active profile',
    );
  }
  return profile;
}

PlayerGameProgress _requireProgress(PlayerProfile profile, GameId gameId) {
  final progress = profile.gameProgress[gameId];
  if (progress == null) {
    throw GameProgressionException(
      GameProgressionError.gameNotPrepared,
      '${gameId.storageId} has not been prepared',
    );
  }
  return progress;
}

String _normalizedName(String name) {
  try {
    return PlayerProfile.normalizedNameFor(name);
  } on Object catch (error) {
    throw GameProgressionException(
      GameProgressionError.invalidProfile,
      'Invalid profile name',
      error,
    );
  }
}

PlayerProfile _buildProfile({
  required String id,
  required String name,
  required DateTime createdAt,
  required DateTime updatedAt,
  int coins = 0,
  int gamesPlayed = 0,
  int gamesWon = 0,
  int bestScore = 0,
}) {
  try {
    return PlayerProfile(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      coins: coins,
      gamesPlayed: gamesPlayed,
      gamesWon: gamesWon,
      bestScore: bestScore,
    );
  } on Object catch (error) {
    throw GameProgressionException(
      GameProgressionError.invalidProfile,
      'Invalid profile',
      error,
    );
  }
}

PlayerProfile _copyProfile(
  PlayerProfile profile, {
  String? name,
  DateTime? updatedAt,
  int? coins,
  int? gamesPlayed,
  int? gamesWon,
  int? bestScore,
  Map<GameId, PlayerGameProgress>? gameProgress,
  Map<String, GameBadge>? badges,
}) {
  try {
    return profile.copyWith(
      name: name,
      updatedAt: updatedAt,
      coins: coins,
      gamesPlayed: gamesPlayed,
      gamesWon: gamesWon,
      bestScore: bestScore,
      gameProgress: gameProgress,
      badges: badges,
    );
  } on Object catch (error) {
    throw GameProgressionException(
      GameProgressionError.invalidProfile,
      'Invalid profile transition',
      error,
    );
  }
}

Map<String, PlayerProfile> _replaceProfile(
  Map<String, PlayerProfile> profiles,
  PlayerProfile replacement,
) => <String, PlayerProfile>{
  for (final entry in profiles.entries)
    entry.key: entry.key == replacement.id ? replacement : entry.value,
};

PlayerProfile _earliestProfile(Iterable<PlayerProfile> profiles) {
  final ordered = profiles.toList()
    ..sort((left, right) {
      final created = left.createdAt.compareTo(right.createdAt);
      return created != 0 ? created : left.id.compareTo(right.id);
    });
  return ordered.first;
}
