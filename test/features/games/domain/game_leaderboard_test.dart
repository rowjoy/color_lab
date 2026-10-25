import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_leaderboard.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overall ranks first-clears, coins, then normalized player name', () {
    final zulu = profile(
      id: 'zulu',
      name: 'Zulu',
      coins: 50,
      progress: {GameId.waterSort: progress(GameId.waterSort, completed: 2)},
    );
    final beta = profile(
      id: 'beta',
      name: 'beta',
      coins: 10,
      progress: {GameId.waterSort: progress(GameId.waterSort, completed: 3)},
    );
    final alpha = profile(
      id: 'alpha',
      name: 'Alpha',
      coins: 50,
      progress: {GameId.fruitPop: progress(GameId.fruitPop, completed: 2)},
    );
    final noob = profile(id: 'noob', name: 'New Player');
    final state = stateOf([zulu, noob, beta, alpha], activeProfileId: zulu.id);

    final entries = overallLeaderboard(state);

    expect(entries.map((entry) => entry.profileId), [
      'beta',
      'alpha',
      'zulu',
      'noob',
    ]);
    expect(entries.map((entry) => entry.rank), [1, 2, 3, 4]);
    expect(entries.map((entry) => entry.completedLevels), [3, 2, 2, 0]);
    expect(entries.map((entry) => entry.coins), [10, 50, 50, 0]);
    expect(entries.singleWhere((entry) => entry.isActive).profileId, 'zulu');
    expect(entries.last.profileName, 'New Player');
    expect(() => entries.add(entries.first), throwsUnsupportedError);
  });

  test('overall sums first-clears across games instead of aggregate wins', () {
    final crossGame = profile(
      id: 'cross-game',
      name: 'Cross Game',
      coins: 1,
      gamesWon: 99,
      gamesPlayed: 100,
      progress: {
        GameId.waterSort: progress(GameId.waterSort, completed: 2),
        GameId.rainbowRings: progress(GameId.rainbowRings, completed: 3),
      },
    );
    final legacyOnly = profile(
      id: 'legacy',
      name: 'Legacy Player',
      coins: 999,
      gamesWon: 90,
      gamesPlayed: 100,
    );

    final entries = overallLeaderboard(
      stateOf([legacyOnly, crossGame], activeProfileId: legacyOnly.id),
    );

    expect(entries.map((entry) => entry.profileId), ['cross-game', 'legacy']);
    expect(entries.map((entry) => entry.completedLevels), [5, 0]);
  });

  test('per-game ranks completed level, coins, then normalized name', () {
    final beta = profile(
      id: 'beta',
      name: 'Beta',
      coins: 10,
      progress: {GameId.waterSort: progress(GameId.waterSort, completed: 3)},
    );
    final zulu = profile(
      id: 'zulu',
      name: 'Zulu',
      coins: 50,
      progress: {GameId.waterSort: progress(GameId.waterSort, completed: 2)},
    );
    final zeroScore = profile(
      id: 'zero-score',
      name: 'Zero Score',
      coins: 2,
      progress: {
        GameId.waterSort: progress(GameId.waterSort, completed: 1, score: 0),
      },
    );
    final alpha = profile(id: 'alpha', name: 'Alpha', coins: 50);
    final aaron = profile(id: 'aaron', name: 'aaron', coins: 50);
    final noob = profile(id: 'noob', name: 'New Player');
    final state = stateOf([
      alpha,
      zeroScore,
      noob,
      zulu,
      beta,
      aaron,
    ], activeProfileId: zeroScore.id);

    final entries = gameLeaderboard(state, GameId.waterSort);

    expect(entries.map((entry) => entry.profileId), [
      'beta',
      'zulu',
      'zero-score',
      'aaron',
      'alpha',
      'noob',
    ]);
    expect(entries.map((entry) => entry.completedLevels), [3, 2, 1, 0, 0, 0]);
    expect(entries[2].isActive, isTrue);
    expect(entries[2].rank, 3);
    expect(entries, hasLength(6), reason: 'new profiles stay visible at zero');
  });

  test('empty local profile state produces an immutable empty ranking', () {
    final state = GameProfilesState(
      activeProfileId: null,
      profiles: const {},
      legacyMigrationComplete: true,
    );

    final overall = overallLeaderboard(state);
    final game = gameLeaderboard(state, GameId.colorMatch);

    expect(overall, isEmpty);
    expect(game, isEmpty);
    expect(
      () => overall.add(
        const LeaderboardEntry(
          rank: 1,
          profileId: 'impossible',
          profileName: 'Impossible',
          completedLevels: 0,
          coins: 0,
          isActive: false,
        ),
      ),
      throwsUnsupportedError,
    );
  });
}

final DateTime _createdAt = DateTime.utc(2026, 10, 24, 8);

PlayerProfile profile({
  required String id,
  required String name,
  int coins = 0,
  int gamesPlayed = 0,
  int gamesWon = 0,
  Map<GameId, PlayerGameProgress> progress = const {},
}) => PlayerProfile(
  id: id,
  name: name,
  createdAt: _createdAt,
  updatedAt: _createdAt,
  coins: coins,
  gamesPlayed: gamesPlayed,
  gamesWon: gamesWon,
  gameProgress: progress,
);

PlayerGameProgress progress(
  GameId gameId, {
  required int completed,
  int score = 80,
}) {
  final descriptors = <int, GameLevelDescriptor>{
    for (var level = 1; level <= completed; level++)
      level: descriptor(gameId, level),
  };
  return PlayerGameProgress(
    gameId: gameId,
    currentLevel: completed + 1,
    generatedThrough: completed,
    descriptors: descriptors,
    fingerprints: descriptors.values
        .map((descriptor) => descriptor.fingerprint)
        .toSet(),
    clearedLevels: {for (var level = 1; level <= completed; level++) level},
    bestScores: {for (var level = 1; level <= completed; level++) level: score},
    attempts: completed,
    wins: completed,
    attemptSequence: completed,
    highestCompletedLevel: completed,
  );
}

GameLevelDescriptor descriptor(GameId gameId, int level) => GameLevelDescriptor(
  gameId: gameId,
  level: level,
  seed: level,
  generatorVersion: 1,
  retrySalt: 0,
  fingerprint: level.toRadixString(16).padLeft(64, '0'),
  tier: GameTier.forLevel(level),
  levelPressure: levelPressureFor(level),
);

GameProfilesState stateOf(
  List<PlayerProfile> profiles, {
  required String activeProfileId,
}) => GameProfilesState(
  activeProfileId: activeProfileId,
  profiles: {for (final profile in profiles) profile.id: profile},
  legacyMigrationComplete: true,
);
