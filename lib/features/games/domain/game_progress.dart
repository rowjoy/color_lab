import 'game_difficulty.dart';

final class GameProgress {
  const GameProgress({
    this.coins = 0,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.bestScore = 0,
    this.lastDifficulty = GameDifficulty.medium,
    this.easyWins = 0,
    this.mediumWins = 0,
    this.hardWins = 0,
  });

  final int coins;
  final int gamesPlayed;
  final int gamesWon;
  final int bestScore;
  final GameDifficulty lastDifficulty;
  final int easyWins;
  final int mediumWins;
  final int hardWins;

  int winsFor(GameDifficulty difficulty) => switch (difficulty) {
    GameDifficulty.easy => easyWins,
    GameDifficulty.medium => mediumWins,
    GameDifficulty.hard => hardWins,
  };

  GameProgress withDifficulty(GameDifficulty difficulty) => GameProgress(
    coins: coins,
    gamesPlayed: gamesPlayed,
    gamesWon: gamesWon,
    bestScore: bestScore,
    lastDifficulty: difficulty,
    easyWins: easyWins,
    mediumWins: mediumWins,
    hardWins: hardWins,
  );

  GameProgress record({
    required GameDifficulty difficulty,
    required int score,
    required bool won,
  }) => GameProgress(
    coins: coins + (won ? difficulty.rewardCoins : 0),
    gamesPlayed: gamesPlayed + 1,
    gamesWon: gamesWon + (won ? 1 : 0),
    bestScore: score > bestScore ? score : bestScore,
    lastDifficulty: difficulty,
    easyWins: easyWins + (won && difficulty == GameDifficulty.easy ? 1 : 0),
    mediumWins:
        mediumWins + (won && difficulty == GameDifficulty.medium ? 1 : 0),
    hardWins: hardWins + (won && difficulty == GameDifficulty.hard ? 1 : 0),
  );

  Map<String, Object?> toMap() => {
    'schemaVersion': 1,
    'coins': coins,
    'gamesPlayed': gamesPlayed,
    'gamesWon': gamesWon,
    'bestScore': bestScore,
    'lastDifficulty': lastDifficulty.name,
    'easyWins': easyWins,
    'mediumWins': mediumWins,
    'hardWins': hardWins,
  };

  factory GameProgress.fromMap(Map<Object?, Object?> map) {
    int readInt(String key) {
      final value = map[key];
      if (value is! int || value < 0) {
        throw FormatException('Invalid game progress $key');
      }
      return value;
    }

    if (map['schemaVersion'] != 1) {
      throw const FormatException('Unsupported game progress version');
    }
    return GameProgress(
      coins: readInt('coins'),
      gamesPlayed: readInt('gamesPlayed'),
      gamesWon: readInt('gamesWon'),
      bestScore: readInt('bestScore'),
      lastDifficulty: GameDifficulty.parse(map['lastDifficulty']),
      easyWins: readInt('easyWins'),
      mediumWins: readInt('mediumWins'),
      hardWins: readInt('hardWins'),
    );
  }
}
