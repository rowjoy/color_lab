import 'game_difficulty.dart';
import 'game_progress.dart';

abstract interface class GameProgressRepository {
  Future<GameProgress> load();
  Future<GameProgress> recordResult({
    required GameDifficulty difficulty,
    required int score,
    required bool won,
  });
  Future<GameProgress> setDifficulty(GameDifficulty difficulty);
  Future<void> close();
}

final class GameProgressStorageException implements Exception {
  const GameProgressStorageException();
}
