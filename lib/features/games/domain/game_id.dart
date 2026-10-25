enum GameId {
  bubbleShooter('bubbleShooter'),
  fruitPop('fruitPop'),
  waterSort('waterSort'),
  rainbowRings('rainbowRings'),
  colorMatch('colorMatch');

  const GameId(this.storageId);

  final String storageId;

  static GameId parse(String value) {
    for (final gameId in values) {
      if (gameId.storageId == value) return gameId;
    }
    throw FormatException('Unknown game ID: $value');
  }
}
