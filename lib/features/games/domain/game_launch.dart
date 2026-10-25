import 'game_id.dart';
import 'game_level.dart';

enum GamePlayKind {
  current,
  replay;

  static GamePlayKind parse(String value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    throw FormatException('Unknown game play kind: $value');
  }
}

/// The durable open attempt for one profile/game pair.
final class ActiveGameAttempt {
  factory ActiveGameAttempt({
    required String attemptId,
    required int sequence,
    required int level,
    required GamePlayKind playKind,
    required String descriptorFingerprint,
    required DateTime startedAt,
  }) {
    _validateIdentity(attemptId, 'attemptId');
    if (sequence < 1) {
      throw ArgumentError.value(sequence, 'sequence', 'Must be positive');
    }
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'Must be positive');
    }
    _validateFingerprint(descriptorFingerprint);
    return ActiveGameAttempt._(
      attemptId: attemptId,
      sequence: sequence,
      level: level,
      playKind: playKind,
      descriptorFingerprint: descriptorFingerprint,
      startedAt: startedAt.toUtc(),
    );
  }

  const ActiveGameAttempt._({
    required this.attemptId,
    required this.sequence,
    required this.level,
    required this.playKind,
    required this.descriptorFingerprint,
    required this.startedAt,
  });

  static const int schemaVersion = 1;

  final String attemptId;
  final int sequence;
  final int level;
  final GamePlayKind playKind;
  final String descriptorFingerprint;
  final DateTime startedAt;

  Map<String, Object> toMap() => Map<String, Object>.unmodifiable({
    'version': schemaVersion,
    'attemptId': attemptId,
    'sequence': sequence,
    'level': level,
    'playKind': playKind.name,
    'descriptorFingerprint': descriptorFingerprint,
    'startedAt': startedAt.toIso8601String(),
  });

  factory ActiveGameAttempt.fromMap(Map<Object?, Object?> map) {
    const keys = {
      'version',
      'attemptId',
      'sequence',
      'level',
      'playKind',
      'descriptorFingerprint',
      'startedAt',
    };
    if (!_hasExactKeys(map, keys) ||
        map['version'] != schemaVersion ||
        map['attemptId'] is! String ||
        map['sequence'] is! int ||
        map['level'] is! int ||
        map['playKind'] is! String ||
        map['descriptorFingerprint'] is! String ||
        map['startedAt'] is! String) {
      throw const FormatException('Invalid active game attempt schema');
    }
    final startedAt = _readUtc(map['startedAt']! as String, 'startedAt');
    try {
      return ActiveGameAttempt(
        attemptId: map['attemptId']! as String,
        sequence: map['sequence']! as int,
        level: map['level']! as int,
        playKind: GamePlayKind.parse(map['playKind']! as String),
        descriptorFingerprint: map['descriptorFingerprint']! as String,
        startedAt: startedAt,
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid active game attempt', error);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveGameAttempt &&
          other.attemptId == attemptId &&
          other.sequence == sequence &&
          other.level == level &&
          other.playKind == playKind &&
          other.descriptorFingerprint == descriptorFingerprint &&
          other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(
    attemptId,
    sequence,
    level,
    playKind,
    descriptorFingerprint,
    startedAt,
  );
}

/// Immutable navigation input for one current-level play or replay.
final class GameLaunch {
  factory GameLaunch({
    required String profileId,
    required GameId gameId,
    required GameLevelDescriptor descriptor,
    required String attemptId,
    required GamePlayKind playKind,
  }) {
    _validateIdentity(profileId, 'profileId');
    _validateIdentity(attemptId, 'attemptId');
    if (descriptor.gameId != gameId) {
      throw ArgumentError.value(
        descriptor,
        'descriptor',
        'Descriptor game does not match launch game',
      );
    }
    return GameLaunch._(
      profileId: profileId,
      gameId: gameId,
      descriptor: descriptor,
      attemptId: attemptId,
      playKind: playKind,
    );
  }

  const GameLaunch._({
    required this.profileId,
    required this.gameId,
    required this.descriptor,
    required this.attemptId,
    required this.playKind,
  });

  final String profileId;
  final GameId gameId;
  final GameLevelDescriptor descriptor;
  final String attemptId;
  final GamePlayKind playKind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameLaunch &&
          other.profileId == profileId &&
          other.gameId == gameId &&
          other.descriptor == descriptor &&
          other.attemptId == attemptId &&
          other.playKind == playKind;

  @override
  int get hashCode =>
      Object.hash(profileId, gameId, descriptor, attemptId, playKind);
}

/// Durable terminal data for the most recently settled attempt.
///
/// [alreadyApplied] is response-only. It is intentionally omitted from the
/// persisted map so retrying the same callback cannot mutate the receipt.
final class LevelCompletionReceipt {
  factory LevelCompletionReceipt({
    required String attemptId,
    required int attemptSequence,
    required int level,
    required String descriptorFingerprint,
    required int normalizedScore,
    required bool firstClear,
    required int coinsAwarded,
    String? badgeId,
    required int currentLevelAfter,
    required DateTime completedAt,
    bool alreadyApplied = false,
  }) {
    _validateIdentity(attemptId, 'attemptId');
    if (attemptSequence < 1) {
      throw ArgumentError.value(
        attemptSequence,
        'attemptSequence',
        'Must be positive',
      );
    }
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'Must be positive');
    }
    _validateFingerprint(descriptorFingerprint);
    if (normalizedScore < 0 || normalizedScore > 100) {
      throw ArgumentError.value(
        normalizedScore,
        'normalizedScore',
        'Must be between 0 and 100',
      );
    }
    if (currentLevelAfter < 1) {
      throw ArgumentError.value(
        currentLevelAfter,
        'currentLevelAfter',
        'Must be positive',
      );
    }
    final expectedCoins = firstClear ? GameTier.forLevel(level).rewardCoins : 0;
    if (coinsAwarded != expectedCoins) {
      throw ArgumentError.value(
        coinsAwarded,
        'coinsAwarded',
        'Does not match first-clear reward',
      );
    }
    if (firstClear) {
      if (currentLevelAfter != level + 1) {
        throw ArgumentError.value(
          currentLevelAfter,
          'currentLevelAfter',
          'A first clear must advance exactly one level',
        );
      }
    } else if (currentLevelAfter <= level) {
      throw ArgumentError.value(
        currentLevelAfter,
        'currentLevelAfter',
        'A replay level must remain behind the current level',
      );
    }

    final earnsBadge = firstClear && level % 20 == 0;
    if ((badgeId != null) != earnsBadge) {
      throw ArgumentError.value(
        badgeId,
        'badgeId',
        'Must match a first-clear badge milestone',
      );
    }
    if (badgeId != null) {
      _validateBadgeId(badgeId, level);
    }

    return LevelCompletionReceipt._(
      attemptId: attemptId,
      attemptSequence: attemptSequence,
      level: level,
      descriptorFingerprint: descriptorFingerprint,
      normalizedScore: normalizedScore,
      firstClear: firstClear,
      coinsAwarded: coinsAwarded,
      badgeId: badgeId,
      currentLevelAfter: currentLevelAfter,
      completedAt: completedAt.toUtc(),
      alreadyApplied: alreadyApplied,
    );
  }

  const LevelCompletionReceipt._({
    required this.attemptId,
    required this.attemptSequence,
    required this.level,
    required this.descriptorFingerprint,
    required this.normalizedScore,
    required this.firstClear,
    required this.coinsAwarded,
    required this.badgeId,
    required this.currentLevelAfter,
    required this.completedAt,
    required this.alreadyApplied,
  });

  static const int schemaVersion = 1;

  final String attemptId;
  final int attemptSequence;
  final int level;
  final String descriptorFingerprint;
  final int normalizedScore;
  final bool firstClear;
  final int coinsAwarded;
  final String? badgeId;
  final int currentLevelAfter;
  final DateTime completedAt;
  final bool alreadyApplied;

  LevelCompletionReceipt asAlreadyApplied() => alreadyApplied
      ? this
      : LevelCompletionReceipt._(
          attemptId: attemptId,
          attemptSequence: attemptSequence,
          level: level,
          descriptorFingerprint: descriptorFingerprint,
          normalizedScore: normalizedScore,
          firstClear: firstClear,
          coinsAwarded: coinsAwarded,
          badgeId: badgeId,
          currentLevelAfter: currentLevelAfter,
          completedAt: completedAt,
          alreadyApplied: true,
        );

  Map<String, Object?> toMap() => Map<String, Object?>.unmodifiable({
    'version': schemaVersion,
    'attemptId': attemptId,
    'attemptSequence': attemptSequence,
    'level': level,
    'descriptorFingerprint': descriptorFingerprint,
    'normalizedScore': normalizedScore,
    'firstClear': firstClear,
    'coinsAwarded': coinsAwarded,
    'badgeId': badgeId,
    'currentLevelAfter': currentLevelAfter,
    'completedAt': completedAt.toIso8601String(),
  });

  factory LevelCompletionReceipt.fromMap(Map<Object?, Object?> map) {
    const keys = {
      'version',
      'attemptId',
      'attemptSequence',
      'level',
      'descriptorFingerprint',
      'normalizedScore',
      'firstClear',
      'coinsAwarded',
      'badgeId',
      'currentLevelAfter',
      'completedAt',
    };
    if (!_hasExactKeys(map, keys) ||
        map['version'] != schemaVersion ||
        map['attemptId'] is! String ||
        map['attemptSequence'] is! int ||
        map['level'] is! int ||
        map['descriptorFingerprint'] is! String ||
        map['normalizedScore'] is! int ||
        map['firstClear'] is! bool ||
        map['coinsAwarded'] is! int ||
        (map['badgeId'] != null && map['badgeId'] is! String) ||
        map['currentLevelAfter'] is! int ||
        map['completedAt'] is! String) {
      throw const FormatException('Invalid level completion receipt schema');
    }
    final completedAt = _readUtc(map['completedAt']! as String, 'completedAt');
    try {
      return LevelCompletionReceipt(
        attemptId: map['attemptId']! as String,
        attemptSequence: map['attemptSequence']! as int,
        level: map['level']! as int,
        descriptorFingerprint: map['descriptorFingerprint']! as String,
        normalizedScore: map['normalizedScore']! as int,
        firstClear: map['firstClear']! as bool,
        coinsAwarded: map['coinsAwarded']! as int,
        badgeId: map['badgeId'] as String?,
        currentLevelAfter: map['currentLevelAfter']! as int,
        completedAt: completedAt,
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid level completion receipt', error);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelCompletionReceipt &&
          other.attemptId == attemptId &&
          other.attemptSequence == attemptSequence &&
          other.level == level &&
          other.descriptorFingerprint == descriptorFingerprint &&
          other.normalizedScore == normalizedScore &&
          other.firstClear == firstClear &&
          other.coinsAwarded == coinsAwarded &&
          other.badgeId == badgeId &&
          other.currentLevelAfter == currentLevelAfter &&
          other.completedAt == completedAt &&
          other.alreadyApplied == alreadyApplied;

  @override
  int get hashCode => Object.hash(
    attemptId,
    attemptSequence,
    level,
    descriptorFingerprint,
    normalizedScore,
    firstClear,
    coinsAwarded,
    badgeId,
    currentLevelAfter,
    completedAt,
    alreadyApplied,
  );
}

final RegExp _fingerprintPattern = RegExp(r'^[0-9a-f]{64}$');

bool _hasExactKeys(Map<Object?, Object?> map, Set<String> keys) =>
    map.length == keys.length && map.keys.every(keys.contains);

void _validateIdentity(String value, String name) {
  if (value.isEmpty || value.trim() != value) {
    throw ArgumentError.value(value, name, 'Must be a non-empty canonical ID');
  }
}

void _validateFingerprint(String value) {
  if (!_fingerprintPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'descriptorFingerprint',
      'Must be a lowercase SHA-256 hex digest',
    );
  }
}

DateTime _readUtc(String value, String field) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
    throw FormatException('Invalid $field');
  }
  return parsed;
}

void _validateBadgeId(String badgeId, int level) {
  final separator = badgeId.lastIndexOf(':');
  if (separator < 1 || separator == badgeId.length - 1) {
    throw ArgumentError.value(badgeId, 'badgeId', 'Invalid badge identity');
  }
  final milestoneText = badgeId.substring(separator + 1);
  final milestone = int.tryParse(milestoneText);
  if (milestone != level || milestone.toString() != milestoneText) {
    throw ArgumentError.value(badgeId, 'badgeId', 'Invalid badge milestone');
  }
  try {
    GameId.parse(badgeId.substring(0, separator));
  } on FormatException {
    throw ArgumentError.value(badgeId, 'badgeId', 'Unknown badge game');
  }
}
