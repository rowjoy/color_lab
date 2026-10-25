import 'game_id.dart';

/// An earned, per-game level milestone.
final class GameBadge {
  factory GameBadge({
    required GameId gameId,
    required int milestone,
    required DateTime earnedAt,
  }) {
    if (milestone < 20 || milestone % 20 != 0) {
      throw ArgumentError.value(
        milestone,
        'milestone',
        'Must be a positive multiple of 20',
      );
    }
    return GameBadge._(
      gameId: gameId,
      milestone: milestone,
      earnedAt: earnedAt.toUtc(),
    );
  }

  const GameBadge._({
    required this.gameId,
    required this.milestone,
    required this.earnedAt,
  });

  static const int schemaVersion = 1;

  final GameId gameId;
  final int milestone;
  final DateTime earnedAt;

  String get id => '${gameId.storageId}:$milestone';

  String get accessibleLabel => '${_gameLabel(gameId)} Level $milestone badge';

  Map<String, Object> toMap() => Map<String, Object>.unmodifiable({
    'version': schemaVersion,
    'id': id,
    'gameId': gameId.storageId,
    'milestone': milestone,
    'earnedAt': earnedAt.toIso8601String(),
  });

  factory GameBadge.fromMap(Map<Object?, Object?> map) {
    const keys = {'version', 'id', 'gameId', 'milestone', 'earnedAt'};
    if (!_hasExactKeys(map, keys) ||
        map['version'] != schemaVersion ||
        map['id'] is! String ||
        map['gameId'] is! String ||
        map['milestone'] is! int ||
        map['earnedAt'] is! String) {
      throw const FormatException('Invalid game badge schema');
    }

    final earnedAtText = map['earnedAt']! as String;
    final earnedAt = DateTime.tryParse(earnedAtText);
    if (earnedAt == null ||
        !earnedAt.isUtc ||
        earnedAt.toIso8601String() != earnedAtText) {
      throw const FormatException('Invalid game badge earnedAt');
    }

    try {
      final badge = GameBadge(
        gameId: GameId.parse(map['gameId']! as String),
        milestone: map['milestone']! as int,
        earnedAt: earnedAt,
      );
      if (badge.id != map['id']) {
        throw const FormatException('Invalid game badge identity');
      }
      return badge;
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid game badge', error);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameBadge &&
          other.gameId == gameId &&
          other.milestone == milestone &&
          other.earnedAt == earnedAt;

  @override
  int get hashCode => Object.hash(gameId, milestone, earnedAt);
}

bool _hasExactKeys(Map<Object?, Object?> map, Set<String> keys) =>
    map.length == keys.length && map.keys.every(keys.contains);

String _gameLabel(GameId gameId) => switch (gameId) {
  GameId.bubbleShooter => 'Bubble Shooter',
  GameId.fruitPop => 'Fruit & Veggie Pop',
  GameId.waterSort => 'Water Sort',
  GameId.rainbowRings => 'Rainbow Rings',
  GameId.colorMatch => 'Color Match',
};
