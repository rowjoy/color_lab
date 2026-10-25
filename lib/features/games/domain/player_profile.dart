import 'package:characters/characters.dart';

import 'game_badge.dart';
import 'game_id.dart';
import 'game_launch.dart';
import 'game_level.dart';

const Object _notProvided = Object();

/// Durable, independent progression for one game inside a player profile.
final class PlayerGameProgress {
  factory PlayerGameProgress({
    required GameId gameId,
    int currentLevel = 1,
    int generatedThrough = 0,
    Map<int, GameLevelDescriptor> descriptors = const {},
    Set<String> fingerprints = const {},
    Set<int> clearedLevels = const {},
    Map<int, int> bestScores = const {},
    int attempts = 0,
    int wins = 0,
    int attemptSequence = 0,
    ActiveGameAttempt? activeAttempt,
    LevelCompletionReceipt? latestReceipt,
    int highestCompletedLevel = 0,
    Set<int> badgeMilestones = const {},
    int? pendingRefillThrough,
  }) {
    final descriptorKeys = descriptors.keys.toList()..sort();
    final descriptorCopy = <int, GameLevelDescriptor>{
      for (final level in descriptorKeys) level: descriptors[level]!,
    };
    final fingerprintCopy = Set<String>.unmodifiable(fingerprints);
    final clearedCopy = Set<int>.unmodifiable(clearedLevels);
    final scoreKeys = bestScores.keys.toList()..sort();
    final scoreCopy = <int, int>{
      for (final level in scoreKeys) level: bestScores[level]!,
    };
    final badgeCopy = Set<int>.unmodifiable(badgeMilestones);

    _validateProgress(
      gameId: gameId,
      currentLevel: currentLevel,
      generatedThrough: generatedThrough,
      descriptors: descriptorCopy,
      fingerprints: fingerprintCopy,
      clearedLevels: clearedCopy,
      bestScores: scoreCopy,
      attempts: attempts,
      wins: wins,
      attemptSequence: attemptSequence,
      activeAttempt: activeAttempt,
      latestReceipt: latestReceipt,
      highestCompletedLevel: highestCompletedLevel,
      badgeMilestones: badgeCopy,
      pendingRefillThrough: pendingRefillThrough,
    );

    return PlayerGameProgress._(
      gameId: gameId,
      currentLevel: currentLevel,
      generatedThrough: generatedThrough,
      descriptors: Map<int, GameLevelDescriptor>.unmodifiable(descriptorCopy),
      fingerprints: fingerprintCopy,
      clearedLevels: clearedCopy,
      bestScores: Map<int, int>.unmodifiable(scoreCopy),
      attempts: attempts,
      wins: wins,
      attemptSequence: attemptSequence,
      activeAttempt: activeAttempt,
      latestReceipt: latestReceipt,
      highestCompletedLevel: highestCompletedLevel,
      badgeMilestones: badgeCopy,
      pendingRefillThrough: pendingRefillThrough,
    );
  }

  const PlayerGameProgress._({
    required this.gameId,
    required this.currentLevel,
    required this.generatedThrough,
    required this.descriptors,
    required this.fingerprints,
    required this.clearedLevels,
    required this.bestScores,
    required this.attempts,
    required this.wins,
    required this.attemptSequence,
    required this.activeAttempt,
    required this.latestReceipt,
    required this.highestCompletedLevel,
    required this.badgeMilestones,
    required this.pendingRefillThrough,
  });

  static const int schemaVersion = 1;

  final GameId gameId;
  final int currentLevel;
  final int generatedThrough;
  final Map<int, GameLevelDescriptor> descriptors;
  final Set<String> fingerprints;
  final Set<int> clearedLevels;
  final Map<int, int> bestScores;
  final int attempts;
  final int wins;
  final int attemptSequence;
  final ActiveGameAttempt? activeAttempt;
  final LevelCompletionReceipt? latestReceipt;
  final int highestCompletedLevel;
  final Set<int> badgeMilestones;
  final int? pendingRefillThrough;

  PlayerGameProgress copyWith({
    int? currentLevel,
    int? generatedThrough,
    Map<int, GameLevelDescriptor>? descriptors,
    Set<String>? fingerprints,
    Set<int>? clearedLevels,
    Map<int, int>? bestScores,
    int? attempts,
    int? wins,
    int? attemptSequence,
    Object? activeAttempt = _notProvided,
    Object? latestReceipt = _notProvided,
    int? highestCompletedLevel,
    Set<int>? badgeMilestones,
    Object? pendingRefillThrough = _notProvided,
  }) => PlayerGameProgress(
    gameId: gameId,
    currentLevel: currentLevel ?? this.currentLevel,
    generatedThrough: generatedThrough ?? this.generatedThrough,
    descriptors: descriptors ?? this.descriptors,
    fingerprints: fingerprints ?? this.fingerprints,
    clearedLevels: clearedLevels ?? this.clearedLevels,
    bestScores: bestScores ?? this.bestScores,
    attempts: attempts ?? this.attempts,
    wins: wins ?? this.wins,
    attemptSequence: attemptSequence ?? this.attemptSequence,
    activeAttempt: identical(activeAttempt, _notProvided)
        ? this.activeAttempt
        : activeAttempt as ActiveGameAttempt?,
    latestReceipt: identical(latestReceipt, _notProvided)
        ? this.latestReceipt
        : latestReceipt as LevelCompletionReceipt?,
    highestCompletedLevel: highestCompletedLevel ?? this.highestCompletedLevel,
    badgeMilestones: badgeMilestones ?? this.badgeMilestones,
    pendingRefillThrough: identical(pendingRefillThrough, _notProvided)
        ? this.pendingRefillThrough
        : pendingRefillThrough as int?,
  );

  Map<String, Object?> toMap() {
    final descriptorMaps = descriptors.values
        .map(
          (descriptor) => Map<String, Object?>.unmodifiable(descriptor.toMap()),
        )
        .toList(growable: false);
    final sortedFingerprints = fingerprints.toList()..sort();
    final sortedCleared = clearedLevels.toList()..sort();
    final scoreMaps = bestScores.entries
        .map(
          (entry) => Map<String, Object>.unmodifiable({
            'level': entry.key,
            'score': entry.value,
          }),
        )
        .toList(growable: false);
    final sortedBadges = badgeMilestones.toList()..sort();

    return Map<String, Object?>.unmodifiable({
      'version': schemaVersion,
      'gameId': gameId.storageId,
      'currentLevel': currentLevel,
      'generatedThrough': generatedThrough,
      'descriptors': List<Map<String, Object?>>.unmodifiable(descriptorMaps),
      'fingerprints': List<String>.unmodifiable(sortedFingerprints),
      'clearedLevels': List<int>.unmodifiable(sortedCleared),
      'bestScores': List<Map<String, Object>>.unmodifiable(scoreMaps),
      'attempts': attempts,
      'wins': wins,
      'attemptSequence': attemptSequence,
      'activeAttempt': activeAttempt?.toMap(),
      'latestReceipt': latestReceipt?.toMap(),
      'highestCompletedLevel': highestCompletedLevel,
      'badgeMilestones': List<int>.unmodifiable(sortedBadges),
      'pendingRefillThrough': pendingRefillThrough,
    });
  }

  factory PlayerGameProgress.fromMap(Map<Object?, Object?> map) {
    const keys = {
      'version',
      'gameId',
      'currentLevel',
      'generatedThrough',
      'descriptors',
      'fingerprints',
      'clearedLevels',
      'bestScores',
      'attempts',
      'wins',
      'attemptSequence',
      'activeAttempt',
      'latestReceipt',
      'highestCompletedLevel',
      'badgeMilestones',
      'pendingRefillThrough',
    };
    if (!_hasExactKeys(map, keys) || map['version'] != schemaVersion) {
      throw const FormatException('Invalid player game progress schema');
    }

    final descriptors = <int, GameLevelDescriptor>{};
    for (final item in _readList(map, 'descriptors')) {
      final nested = _readMap(item, 'descriptor');
      _requireExactDescriptorKeys(nested);
      final descriptor = GameLevelDescriptor.fromMap(nested);
      if (descriptors.containsKey(descriptor.level)) {
        throw const FormatException('Duplicate descriptor level');
      }
      descriptors[descriptor.level] = descriptor;
    }

    final fingerprints = <String>{};
    for (final item in _readList(map, 'fingerprints')) {
      if (item is! String || !fingerprints.add(item)) {
        throw const FormatException('Invalid or duplicate fingerprint');
      }
    }

    final clearedLevels = <int>{};
    for (final item in _readList(map, 'clearedLevels')) {
      if (item is! int || !clearedLevels.add(item)) {
        throw const FormatException('Invalid or duplicate cleared level');
      }
    }

    final bestScores = <int, int>{};
    for (final item in _readList(map, 'bestScores')) {
      final nested = _readMap(item, 'best score');
      if (!_hasExactKeys(nested, const {'level', 'score'})) {
        throw const FormatException('Invalid best score schema');
      }
      final level = _readInt(nested, 'level');
      final score = _readInt(nested, 'score');
      if (bestScores.containsKey(level)) {
        throw const FormatException('Duplicate best score level');
      }
      bestScores[level] = score;
    }

    final badgeMilestones = <int>{};
    for (final item in _readList(map, 'badgeMilestones')) {
      if (item is! int || !badgeMilestones.add(item)) {
        throw const FormatException('Invalid or duplicate badge milestone');
      }
    }

    final activeValue = map['activeAttempt'];
    final receiptValue = map['latestReceipt'];
    final refillValue = map['pendingRefillThrough'];
    if (refillValue != null && refillValue is! int) {
      throw const FormatException('Invalid pendingRefillThrough');
    }

    try {
      return PlayerGameProgress(
        gameId: GameId.parse(_readString(map, 'gameId')),
        currentLevel: _readInt(map, 'currentLevel'),
        generatedThrough: _readInt(map, 'generatedThrough'),
        descriptors: descriptors,
        fingerprints: fingerprints,
        clearedLevels: clearedLevels,
        bestScores: bestScores,
        attempts: _readInt(map, 'attempts'),
        wins: _readInt(map, 'wins'),
        attemptSequence: _readInt(map, 'attemptSequence'),
        activeAttempt: activeValue == null
            ? null
            : ActiveGameAttempt.fromMap(_readMap(activeValue, 'activeAttempt')),
        latestReceipt: receiptValue == null
            ? null
            : LevelCompletionReceipt.fromMap(
                _readMap(receiptValue, 'latestReceipt'),
              ),
        highestCompletedLevel: _readInt(map, 'highestCompletedLevel'),
        badgeMilestones: badgeMilestones,
        pendingRefillThrough: refillValue as int?,
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid player game progress', error);
    }
  }
}

/// A named, device-local player and all of their durable game state.
final class PlayerProfile {
  factory PlayerProfile({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    int coins = 0,
    int gamesPlayed = 0,
    int gamesWon = 0,
    int bestScore = 0,
    Map<GameId, PlayerGameProgress> gameProgress = const {},
    Map<String, GameBadge> badges = const {},
  }) {
    _validateIdentity(id, 'id');
    final cleanName = _validatedName(name);
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

    final canonicalCreatedAt = createdAt.toUtc();
    final canonicalUpdatedAt = updatedAt.toUtc();
    if (canonicalUpdatedAt.isBefore(canonicalCreatedAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Must not precede createdAt',
      );
    }

    final progressCopy = <GameId, PlayerGameProgress>{};
    for (final gameId in GameId.values) {
      final progress = gameProgress[gameId];
      if (progress == null) continue;
      if (progress.gameId != gameId) {
        throw ArgumentError.value(
          progress,
          'gameProgress',
          'Map key does not match progress game',
        );
      }
      progressCopy[gameId] = progress;
    }
    if (progressCopy.length != gameProgress.length) {
      throw ArgumentError.value(
        gameProgress,
        'gameProgress',
        'Contains a mismatched game key',
      );
    }

    final badgeKeys = badges.keys.toList()..sort();
    final badgeCopy = <String, GameBadge>{};
    for (final key in badgeKeys) {
      final badge = badges[key]!;
      if (badge.id != key) {
        throw ArgumentError.value(
          key,
          'badges',
          'Map key does not match badge ID',
        );
      }
      final progress = progressCopy[badge.gameId];
      if (progress == null ||
          !progress.badgeMilestones.contains(badge.milestone)) {
        throw ArgumentError.value(
          badge,
          'badges',
          'Badge has no corresponding game milestone',
        );
      }
      badgeCopy[key] = badge;
    }
    final milestoneCount = progressCopy.values.fold<int>(
      0,
      (total, progress) => total + progress.badgeMilestones.length,
    );
    if (badgeCopy.length != milestoneCount) {
      throw ArgumentError.value(
        badges,
        'badges',
        'Every game milestone must have badge metadata',
      );
    }

    return PlayerProfile._(
      id: id,
      name: cleanName,
      normalizedName: cleanName.toLowerCase(),
      createdAt: canonicalCreatedAt,
      updatedAt: canonicalUpdatedAt,
      coins: coins,
      gamesPlayed: gamesPlayed,
      gamesWon: gamesWon,
      bestScore: bestScore,
      gameProgress: Map<GameId, PlayerGameProgress>.unmodifiable(progressCopy),
      badges: Map<String, GameBadge>.unmodifiable(badgeCopy),
    );
  }

  const PlayerProfile._({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.createdAt,
    required this.updatedAt,
    required this.coins,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.bestScore,
    required this.gameProgress,
    required this.badges,
  });

  static const int schemaVersion = 1;

  final String id;
  final String name;
  final String normalizedName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int coins;
  final int gamesPlayed;
  final int gamesWon;
  final int bestScore;
  final Map<GameId, PlayerGameProgress> gameProgress;
  final Map<String, GameBadge> badges;

  Set<String> get badgeIds => Set<String>.unmodifiable(badges.keys);

  static String normalizedNameFor(String name) =>
      _validatedName(name).toLowerCase();

  PlayerProfile copyWith({
    String? name,
    DateTime? updatedAt,
    int? coins,
    int? gamesPlayed,
    int? gamesWon,
    int? bestScore,
    Map<GameId, PlayerGameProgress>? gameProgress,
    Map<String, GameBadge>? badges,
  }) => PlayerProfile(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    coins: coins ?? this.coins,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    gamesWon: gamesWon ?? this.gamesWon,
    bestScore: bestScore ?? this.bestScore,
    gameProgress: gameProgress ?? this.gameProgress,
    badges: badges ?? this.badges,
  );

  Map<String, Object?> toMap() {
    final progressMaps = gameProgress.values
        .map((progress) => progress.toMap())
        .toList(growable: false);
    final badgeMaps = badges.values
        .map((badge) => badge.toMap())
        .toList(growable: false);
    return Map<String, Object?>.unmodifiable({
      'version': schemaVersion,
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'coins': coins,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'bestScore': bestScore,
      'gameProgress': List<Map<String, Object?>>.unmodifiable(progressMaps),
      'badges': List<Map<String, Object>>.unmodifiable(badgeMaps),
    });
  }

  factory PlayerProfile.fromMap(Map<Object?, Object?> map) {
    const keys = {
      'version',
      'id',
      'name',
      'createdAt',
      'updatedAt',
      'coins',
      'gamesPlayed',
      'gamesWon',
      'bestScore',
      'gameProgress',
      'badges',
    };
    if (!_hasExactKeys(map, keys) || map['version'] != schemaVersion) {
      throw const FormatException('Invalid player profile schema');
    }

    final progress = <GameId, PlayerGameProgress>{};
    for (final item in _readList(map, 'gameProgress')) {
      final value = PlayerGameProgress.fromMap(_readMap(item, 'gameProgress'));
      if (progress.containsKey(value.gameId)) {
        throw const FormatException('Duplicate game progress');
      }
      progress[value.gameId] = value;
    }

    final badges = <String, GameBadge>{};
    for (final item in _readList(map, 'badges')) {
      final value = GameBadge.fromMap(_readMap(item, 'badge'));
      if (badges.containsKey(value.id)) {
        throw const FormatException('Duplicate badge');
      }
      badges[value.id] = value;
    }

    try {
      return PlayerProfile(
        id: _readString(map, 'id'),
        name: _readString(map, 'name'),
        createdAt: _readUtc(map, 'createdAt'),
        updatedAt: _readUtc(map, 'updatedAt'),
        coins: _readInt(map, 'coins'),
        gamesPlayed: _readInt(map, 'gamesPlayed'),
        gamesWon: _readInt(map, 'gamesWon'),
        bestScore: _readInt(map, 'bestScore'),
        gameProgress: progress,
        badges: badges,
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid player profile', error);
    }
  }
}

void _validateProgress({
  required GameId gameId,
  required int currentLevel,
  required int generatedThrough,
  required Map<int, GameLevelDescriptor> descriptors,
  required Set<String> fingerprints,
  required Set<int> clearedLevels,
  required Map<int, int> bestScores,
  required int attempts,
  required int wins,
  required int attemptSequence,
  required ActiveGameAttempt? activeAttempt,
  required LevelCompletionReceipt? latestReceipt,
  required int highestCompletedLevel,
  required Set<int> badgeMilestones,
  required int? pendingRefillThrough,
}) {
  if (currentLevel < 1) {
    throw ArgumentError.value(currentLevel, 'currentLevel', 'Must be positive');
  }
  if (generatedThrough < 0 || currentLevel > generatedThrough + 1) {
    throw ArgumentError.value(
      generatedThrough,
      'generatedThrough',
      'Must cover every level before currentLevel',
    );
  }
  if (descriptors.length != generatedThrough) {
    throw ArgumentError.value(
      descriptors,
      'descriptors',
      'Must contain every generated level exactly once',
    );
  }
  for (var level = 1; level <= generatedThrough; level++) {
    final descriptor = descriptors[level];
    if (descriptor == null ||
        descriptor.level != level ||
        descriptor.gameId != gameId) {
      throw ArgumentError.value(
        descriptors,
        'descriptors',
        'Descriptor identity or sequence is invalid',
      );
    }
  }
  if (fingerprints.length != descriptors.length ||
      descriptors.values.any(
        (descriptor) => !fingerprints.contains(descriptor.fingerprint),
      )) {
    throw ArgumentError.value(
      fingerprints,
      'fingerprints',
      'Must exactly match unique descriptor fingerprints',
    );
  }

  if (highestCompletedLevel != currentLevel - 1) {
    throw ArgumentError.value(
      highestCompletedLevel,
      'highestCompletedLevel',
      'Must be immediately before currentLevel',
    );
  }
  if (clearedLevels.length != highestCompletedLevel) {
    throw ArgumentError.value(
      clearedLevels,
      'clearedLevels',
      'Cleared levels must be contiguous',
    );
  }
  for (var level = 1; level <= highestCompletedLevel; level++) {
    if (!clearedLevels.contains(level)) {
      throw ArgumentError.value(
        clearedLevels,
        'clearedLevels',
        'Cleared levels must be contiguous',
      );
    }
  }
  if (bestScores.length != clearedLevels.length ||
      bestScores.keys.any((level) => !clearedLevels.contains(level)) ||
      bestScores.values.any((score) => score < 0 || score > 100)) {
    throw ArgumentError.value(
      bestScores,
      'bestScores',
      'Must contain one 0..100 score per cleared level',
    );
  }

  if (attempts < 0 || attemptSequence != attempts) {
    throw ArgumentError.value(
      attempts,
      'attempts',
      'Must equal the monotonic attempt sequence',
    );
  }
  if (wins < clearedLevels.length || wins > attempts) {
    throw ArgumentError.value(
      wins,
      'wins',
      'Must include all clears and not exceed attempts',
    );
  }

  if (activeAttempt != null) {
    final descriptor = descriptors[activeAttempt.level];
    final isCurrent = activeAttempt.playKind == GamePlayKind.current;
    if (activeAttempt.sequence != attemptSequence ||
        descriptor == null ||
        descriptor.fingerprint != activeAttempt.descriptorFingerprint ||
        (isCurrent && activeAttempt.level != currentLevel) ||
        (!isCurrent && !clearedLevels.contains(activeAttempt.level))) {
      throw ArgumentError.value(
        activeAttempt,
        'activeAttempt',
        'Does not match the current progress snapshot',
      );
    }
  }

  if (latestReceipt != null) {
    final descriptor = descriptors[latestReceipt.level];
    final expectedBadgeId = '${gameId.storageId}:${latestReceipt.level}';
    if (latestReceipt.attemptSequence > attemptSequence ||
        descriptor == null ||
        descriptor.fingerprint != latestReceipt.descriptorFingerprint ||
        latestReceipt.currentLevelAfter != currentLevel ||
        (latestReceipt.firstClear &&
            !clearedLevels.contains(latestReceipt.level)) ||
        (latestReceipt.badgeId != null &&
            latestReceipt.badgeId != expectedBadgeId)) {
      throw ArgumentError.value(
        latestReceipt,
        'latestReceipt',
        'Does not match the current progress snapshot',
      );
    }
  }

  final expectedMilestones = <int>{
    for (
      var milestone = 20;
      milestone <= highestCompletedLevel;
      milestone += 20
    )
      milestone,
  };
  if (badgeMilestones.length != expectedMilestones.length ||
      !badgeMilestones.containsAll(expectedMilestones)) {
    throw ArgumentError.value(
      badgeMilestones,
      'badgeMilestones',
      'Must exactly match completed 20-level milestones',
    );
  }
  if (pendingRefillThrough != null &&
      (pendingRefillThrough <= generatedThrough ||
          pendingRefillThrough < currentLevel)) {
    throw ArgumentError.value(
      pendingRefillThrough,
      'pendingRefillThrough',
      'Must extend beyond generated progress',
    );
  }
}

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001f\u007f-\u009f]');

String _validatedName(String original) {
  if (_controlCharacters.hasMatch(original)) {
    throw ArgumentError.value(
      original,
      'name',
      'Control characters are not allowed',
    );
  }
  final trimmed = original.trim();
  final length = trimmed.characters.length;
  if (length < 2 || length > 20) {
    throw ArgumentError.value(
      original,
      'name',
      'Must contain 2 to 20 visible graphemes',
    );
  }
  return trimmed;
}

void _validateIdentity(String value, String field) {
  if (value.isEmpty ||
      value.trim() != value ||
      _controlCharacters.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Must be a canonical identity');
  }
}

bool _hasExactKeys(Map<Object?, Object?> map, Set<String> keys) =>
    map.length == keys.length && map.keys.every(keys.contains);

void _requireExactDescriptorKeys(Map<Object?, Object?> map) {
  const keys = {
    'schemaVersion',
    'gameId',
    'level',
    'seed',
    'generatorVersion',
    'retrySalt',
    'fingerprint',
    'tier',
    'levelPressure',
  };
  if (!_hasExactKeys(map, keys)) {
    throw const FormatException('Invalid level descriptor schema');
  }
}

int _readInt(Map<Object?, Object?> map, String field) {
  final value = map[field];
  if (value is! int) throw FormatException('Invalid $field');
  return value;
}

String _readString(Map<Object?, Object?> map, String field) {
  final value = map[field];
  if (value is! String) throw FormatException('Invalid $field');
  return value;
}

List<Object?> _readList(Map<Object?, Object?> map, String field) {
  final value = map[field];
  if (value is! List) throw FormatException('Invalid $field');
  return List<Object?>.of(value);
}

Map<Object?, Object?> _readMap(Object? value, String field) {
  if (value is! Map) throw FormatException('Invalid $field');
  return Map<Object?, Object?>.from(value);
}

DateTime _readUtc(Map<Object?, Object?> map, String field) {
  final value = _readString(map, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
    throw FormatException('Invalid $field');
  }
  return parsed;
}
