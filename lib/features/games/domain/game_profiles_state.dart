import 'dart:collection';

import 'game_progress.dart';
import 'player_profile.dart';

/// The aggregate values retained while a schema-v1 save waits for its first
/// schema-v2 profile to be created.
final class LegacyGameProgressSnapshot {
  LegacyGameProgressSnapshot({
    required this.coins,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.bestScore,
  }) {
    if (coins < 0) {
      throw ArgumentError.value(coins, 'coins', 'Must not be negative');
    }
    if (gamesPlayed < 0) {
      throw ArgumentError.value(
        gamesPlayed,
        'gamesPlayed',
        'Must not be negative',
      );
    }
    if (gamesWon < 0 || gamesWon > gamesPlayed) {
      throw ArgumentError.value(
        gamesWon,
        'gamesWon',
        'Must be between zero and gamesPlayed',
      );
    }
    if (bestScore < 0 || bestScore > 100) {
      throw ArgumentError.value(
        bestScore,
        'bestScore',
        'Must be between zero and 100',
      );
    }
  }

  static const int schemaVersion = 1;

  final int coins;
  final int gamesPlayed;
  final int gamesWon;
  final int bestScore;

  /// Reads the exact map written by the retired schema-v1 repository.
  factory LegacyGameProgressSnapshot.fromLegacyMap(Map<Object?, Object?> map) {
    _requireExactKeys(map, const {
      'schemaVersion',
      'coins',
      'gamesPlayed',
      'gamesWon',
      'bestScore',
      'lastDifficulty',
      'easyWins',
      'mediumWins',
      'hardWins',
    }, context: 'legacy game progress');

    try {
      final progress = GameProgress.fromMap(map);
      if (progress.bestScore > 100) {
        throw const FormatException(
          'Legacy bestScore must be between zero and 100',
        );
      }
      if (progress.gamesWon > progress.gamesPlayed) {
        throw const FormatException(
          'Legacy gamesWon must not exceed gamesPlayed',
        );
      }
      if (progress.easyWins + progress.mediumWins + progress.hardWins !=
          progress.gamesWon) {
        throw const FormatException(
          'Legacy difficulty wins must equal gamesWon',
        );
      }
      return LegacyGameProgressSnapshot(
        coins: progress.coins,
        gamesPlayed: progress.gamesPlayed,
        gamesWon: progress.gamesWon,
        bestScore: progress.bestScore,
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid legacy game progress: $error');
    }
  }

  factory LegacyGameProgressSnapshot.fromMap(Map<Object?, Object?> map) {
    _requireExactKeys(map, const {
      'version',
      'coins',
      'gamesPlayed',
      'gamesWon',
      'bestScore',
    }, context: 'legacy snapshot');
    if (map['version'] != schemaVersion) {
      throw const FormatException('Unsupported legacy snapshot version');
    }

    try {
      return LegacyGameProgressSnapshot(
        coins: _readNonNegativeInt(map, 'coins', 'legacy snapshot'),
        gamesPlayed: _readNonNegativeInt(map, 'gamesPlayed', 'legacy snapshot'),
        gamesWon: _readNonNegativeInt(map, 'gamesWon', 'legacy snapshot'),
        bestScore: _readNonNegativeInt(map, 'bestScore', 'legacy snapshot'),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid legacy snapshot: $error');
    }
  }

  Map<String, Object?> toMap() => Map<String, Object?>.unmodifiable({
    'version': schemaVersion,
    'coins': coins,
    'gamesPlayed': gamesPlayed,
    'gamesWon': gamesWon,
    'bestScore': bestScore,
  });
}

/// The single persisted root for all local game profiles.
final class GameProfilesState {
  GameProfilesState({
    required this.activeProfileId,
    required Map<String, PlayerProfile> profiles,
    this.pendingLegacySnapshot,
    required this.legacyMigrationComplete,
  }) : profiles = _freezeProfiles(profiles) {
    _validate();
  }

  static const int schemaVersion = 2;
  static const Object _notProvided = Object();

  final String? activeProfileId;
  final Map<String, PlayerProfile> profiles;
  final LegacyGameProgressSnapshot? pendingLegacySnapshot;
  final bool legacyMigrationComplete;

  PlayerProfile? get activeProfile {
    final id = activeProfileId;
    return id == null ? null : profiles[id];
  }

  void _validate() {
    if (profiles.isEmpty) {
      if (activeProfileId != null) {
        throw ArgumentError.value(
          activeProfileId,
          'activeProfileId',
          'Must be null when there are no profiles',
        );
      }
    } else if (activeProfileId == null ||
        !profiles.containsKey(activeProfileId)) {
      throw ArgumentError.value(
        activeProfileId,
        'activeProfileId',
        'Must identify an existing profile',
      );
    }

    final names = <String>{};
    for (final entry in profiles.entries) {
      if (entry.key != entry.value.id) {
        throw ArgumentError.value(
          entry.key,
          'profiles',
          'Map keys must match profile IDs',
        );
      }
      if (!names.add(entry.value.normalizedName)) {
        throw ArgumentError.value(
          entry.value.name,
          'profiles',
          'Profile names must be unique ignoring case',
        );
      }
    }

    if (legacyMigrationComplete) {
      if (pendingLegacySnapshot != null) {
        throw ArgumentError.value(
          pendingLegacySnapshot,
          'pendingLegacySnapshot',
          'A completed migration cannot retain a pending snapshot',
        );
      }
    } else if (pendingLegacySnapshot == null || profiles.isNotEmpty) {
      throw ArgumentError.value(
        pendingLegacySnapshot,
        'pendingLegacySnapshot',
        'A pending migration requires a snapshot and no profiles',
      );
    }
  }

  GameProfilesState copyWith({
    Object? activeProfileId = _notProvided,
    Map<String, PlayerProfile>? profiles,
    Object? pendingLegacySnapshot = _notProvided,
    bool? legacyMigrationComplete,
  }) => GameProfilesState(
    activeProfileId: identical(activeProfileId, _notProvided)
        ? this.activeProfileId
        : activeProfileId as String?,
    profiles: profiles ?? this.profiles,
    pendingLegacySnapshot: identical(pendingLegacySnapshot, _notProvided)
        ? this.pendingLegacySnapshot
        : pendingLegacySnapshot as LegacyGameProgressSnapshot?,
    legacyMigrationComplete:
        legacyMigrationComplete ?? this.legacyMigrationComplete,
  );

  Map<String, Object?> toMap() {
    final encodedProfiles = profiles.values
        .map((profile) => Map<String, Object?>.unmodifiable(profile.toMap()))
        .toList(growable: false);
    return Map<String, Object?>.unmodifiable({
      'schemaVersion': schemaVersion,
      'activeProfileId': activeProfileId,
      'profiles': List<Map<String, Object?>>.unmodifiable(encodedProfiles),
      'pendingLegacySnapshot': pendingLegacySnapshot?.toMap(),
      'legacyMigrationComplete': legacyMigrationComplete,
    });
  }

  factory GameProfilesState.fromMap(Map<Object?, Object?> map) {
    _requireExactKeys(map, const {
      'schemaVersion',
      'activeProfileId',
      'profiles',
      'pendingLegacySnapshot',
      'legacyMigrationComplete',
    }, context: 'game profiles state');
    if (map['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported game profiles state version');
    }

    try {
      final activeValue = map['activeProfileId'];
      if (activeValue != null && activeValue is! String) {
        throw const FormatException('Invalid activeProfileId');
      }
      final profilesValue = map['profiles'];
      if (profilesValue is! List) {
        throw const FormatException('Invalid profiles list');
      }
      final decodedProfiles = <String, PlayerProfile>{};
      for (final value in profilesValue) {
        final profile = PlayerProfile.fromMap(_readObjectMap(value, 'profile'));
        if (decodedProfiles.containsKey(profile.id)) {
          throw FormatException('Duplicate profile ID: ${profile.id}');
        }
        decodedProfiles[profile.id] = profile;
      }

      final pendingValue = map['pendingLegacySnapshot'];
      final pending = pendingValue == null
          ? null
          : LegacyGameProgressSnapshot.fromMap(
              _readObjectMap(pendingValue, 'pendingLegacySnapshot'),
            );
      final completeValue = map['legacyMigrationComplete'];
      if (completeValue is! bool) {
        throw const FormatException('Invalid legacyMigrationComplete');
      }

      return GameProfilesState(
        activeProfileId: activeValue as String?,
        profiles: decodedProfiles,
        pendingLegacySnapshot: pending,
        legacyMigrationComplete: completeValue,
      );
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException('Invalid game profiles state: $error');
    } on TypeError catch (error) {
      throw FormatException('Invalid game profiles state: $error');
    }
  }

  static Map<String, PlayerProfile> _freezeProfiles(
    Map<String, PlayerProfile> source,
  ) {
    final copy = <String, PlayerProfile>{};
    copy.addAll(source);
    return UnmodifiableMapView<String, PlayerProfile>(copy);
  }
}

Map<Object?, Object?> _readObjectMap(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('Invalid $field');
  }
  return Map<Object?, Object?>.of(value);
}

int _readNonNegativeInt(Map<Object?, Object?> map, String key, String context) {
  final value = map[key];
  if (value is! int || value < 0) {
    throw FormatException('Invalid $context $key');
  }
  return value;
}

void _requireExactKeys(
  Map<Object?, Object?> map,
  Set<String> expected, {
  required String context,
}) {
  if (map.length != expected.length ||
      map.keys.any((key) => key is! String || !expected.contains(key))) {
    throw FormatException('Invalid $context fields');
  }
}
