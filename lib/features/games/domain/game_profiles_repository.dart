import 'game_profiles_state.dart';
import 'game_progression_engine.dart';

/// Atomic persistence boundary for the complete local profile snapshot.
abstract interface class GameProfilesRepository {
  Future<GameProfilesState> loadState();

  /// Re-reads the latest durable state, applies [transition], durably writes
  /// the returned state, and only then publishes the change.
  Future<ProgressionChange<T>> transact<T>(
    ProgressionChange<T> Function(GameProfilesState current) transition,
  );

  Future<void> close();
}
