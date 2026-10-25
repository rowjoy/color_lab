enum GameDifficulty {
  easy(rounds: 3, winningAverage: 55, rewardCoins: 10),
  medium(rounds: 5, winningAverage: 65, rewardCoins: 25),
  hard(rounds: 8, winningAverage: 75, rewardCoins: 50);

  const GameDifficulty({
    required this.rounds,
    required this.winningAverage,
    required this.rewardCoins,
  });

  final int rounds;
  final int winningAverage;
  final int rewardCoins;

  String get label => switch (this) {
    easy => 'Easy',
    medium => 'Medium',
    hard => 'Hard',
  };

  static GameDifficulty parse(Object? value) => GameDifficulty.values
      .firstWhere((difficulty) => difficulty.name == value);
}
