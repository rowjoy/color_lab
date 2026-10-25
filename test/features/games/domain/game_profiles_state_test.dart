import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_badge.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 24, 8);

  PlayerProfile profile(String id, String name) => PlayerProfile(
    id: id,
    name: name,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  test('schema-v2 root round trips ordered profiles and immutable state', () {
    final first = profile('profile-1', 'Me');
    final second = profile('profile-2', 'Guest');
    final state = GameProfilesState(
      activeProfileId: second.id,
      profiles: {first.id: first, second.id: second},
      legacyMigrationComplete: true,
    );

    final encoded = state.toMap();
    final decoded = GameProfilesState.fromMap(encoded);
    expect(encoded['schemaVersion'], 2);
    expect(decoded.toMap(), encoded);
    expect(decoded.profiles.keys, ['profile-1', 'profile-2']);
    expect(decoded.activeProfile!.name, 'Guest');
    expect(() => decoded.profiles.clear(), throwsUnsupportedError);
    expect(() => (encoded['profiles'] as List).clear(), throwsUnsupportedError);
  });

  test('root enforces active identity and case-insensitive unique names', () {
    final first = profile('profile-1', 'Me');
    final duplicate = profile('profile-2', '  me  ');
    expect(
      () => GameProfilesState(
        activeProfileId: 'missing',
        profiles: {first.id: first},
        legacyMigrationComplete: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => GameProfilesState(
        activeProfileId: first.id,
        profiles: {first.id: first, duplicate.id: duplicate},
        legacyMigrationComplete: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => GameProfilesState(
        activeProfileId: null,
        profiles: {first.id: first},
        legacyMigrationComplete: true,
      ),
      throwsArgumentError,
    );
  });

  test('pending legacy data exists only before the first profile', () {
    final pending = LegacyGameProgressSnapshot(
      coins: 0,
      gamesPlayed: 0,
      gamesWon: 0,
      bestScore: 0,
    );
    expect(
      () => GameProfilesState(
        activeProfileId: null,
        profiles: const {},
        legacyMigrationComplete: false,
      ),
      throwsArgumentError,
    );
    expect(
      () => GameProfilesState(
        activeProfileId: 'profile-1',
        profiles: {'profile-1': profile('profile-1', 'Player')},
        pendingLegacySnapshot: pending,
        legacyMigrationComplete: false,
      ),
      throwsArgumentError,
    );
  });

  test('legacy schema-v1 snapshot is exact and best remains profile-wide', () {
    final legacyMap = <String, Object?>{
      'schemaVersion': 1,
      'coins': 135,
      'gamesPlayed': 12,
      'gamesWon': 7,
      'bestScore': 92,
      'lastDifficulty': 'hard',
      'easyWins': 2,
      'mediumWins': 3,
      'hardWins': 2,
    };
    final legacy = LegacyGameProgressSnapshot.fromLegacyMap(legacyMap);
    final pending = GameProfilesState(
      activeProfileId: null,
      profiles: const {},
      pendingLegacySnapshot: legacy,
      legacyMigrationComplete: false,
    );

    expect(legacy.toMap(), {
      'version': 1,
      'coins': 135,
      'gamesPlayed': 12,
      'gamesWon': 7,
      'bestScore': 92,
    });
    expect(GameProfilesState.fromMap(pending.toMap()).toMap(), pending.toMap());
    final imported = PlayerProfile(
      id: 'profile-1',
      name: 'Me',
      createdAt: createdAt,
      updatedAt: createdAt,
      coins: legacy.coins,
      gamesPlayed: legacy.gamesPlayed,
      gamesWon: legacy.gamesWon,
      bestScore: legacy.bestScore,
    );
    final migrated = GameProfilesState(
      activeProfileId: imported.id,
      profiles: {imported.id: imported},
      legacyMigrationComplete: true,
    );
    expect(migrated.activeProfile!.bestScore, 92);
    expect(migrated.activeProfile!.gameProgress, isEmpty);
    expect(migrated.pendingLegacySnapshot, isNull);
  });

  test('malformed legacy difficulty is reported as a format error', () {
    expect(
      () => LegacyGameProgressSnapshot.fromLegacyMap({
        'schemaVersion': 1,
        'coins': 0,
        'gamesPlayed': 0,
        'gamesWon': 0,
        'bestScore': 0,
        'lastDifficulty': 'futureDifficulty',
        'easyWins': 0,
        'mediumWins': 0,
        'hardWins': 0,
      }),
      throwsFormatException,
    );
  });

  test('strict decoding rejects unknown versions, IDs, dates, and fields', () {
    final state = GameProfilesState(
      activeProfileId: 'profile-1',
      profiles: {'profile-1': profile('profile-1', 'Player')},
      legacyMigrationComplete: true,
    );
    final encoded = state.toMap();
    final profileMap = Map<Object?, Object?>.of(
      (encoded['profiles'] as List).single as Map,
    );
    final invalid = <Map<Object?, Object?>>[
      {...encoded, 'schemaVersion': 3},
      {...encoded, 'extra': true},
      {...encoded, 'activeProfileId': 'missing'},
      {
        ...encoded,
        'profiles': [
          {...profileMap, 'createdAt': '2026-10-24T14:00:00.000+06:00'},
        ],
      },
      {
        ...encoded,
        'profiles': [
          {
            ...profileMap,
            'gameProgress': [
              {'version': 1, 'gameId': 'futureGame'},
            ],
          },
        ],
      },
    ];
    for (final map in invalid) {
      expect(
        () => GameProfilesState.fromMap(map),
        throwsFormatException,
        reason: '$map',
      );
    }
    expect(
      () => GameProfilesState(
        activeProfileId: null,
        profiles: const {},
        pendingLegacySnapshot: LegacyGameProgressSnapshot.fromLegacyMap({
          'schemaVersion': 1,
          'coins': 0,
          'gamesPlayed': 0,
          'gamesWon': 0,
          'bestScore': 0,
          'lastDifficulty': 'medium',
          'easyWins': 0,
          'mediumWins': 0,
          'hardWins': 0,
        }),
        legacyMigrationComplete: true,
      ),
      throwsArgumentError,
    );
  });

  test('profile badge IDs must correspond to per-game milestones', () {
    expect(
      () => PlayerProfile(
        id: 'profile-1',
        name: 'Player',
        createdAt: createdAt,
        updatedAt: createdAt,
        badges: {
          'waterSort:20': GameBadge(
            gameId: GameId.waterSort,
            milestone: 20,
            earnedAt: createdAt,
          ),
        },
        gameProgress: const <GameId, PlayerGameProgress>{},
      ),
      throwsArgumentError,
    );
  });
}
