import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/db/hive_game_progress_repository.dart';
import '../domain/game_difficulty.dart';
import '../domain/game_progress.dart';
import '../domain/game_progress_repository.dart';

final gameProgressDirectoryProvider = FutureProvider<Directory>(
  (ref) => getApplicationDocumentsDirectory(),
  retry: (retryCount, error) => null,
);

final gameProgressRepositoryProvider = FutureProvider<GameProgressRepository>((
  ref,
) async {
  final directory = await ref.watch(gameProgressDirectoryProvider.future);
  if (!ref.mounted) throw StateError('Game storage was disposed.');
  final repository = await HiveGameProgressRepository.open(
    directory: '${directory.path}/color_lab',
  );
  if (!ref.mounted) {
    await repository.close();
    throw StateError('Game storage was disposed.');
  }
  ref.onDispose(() {
    unawaited(
      repository.close().catchError((Object error, StackTrace stack) {
        debugPrint('Game progress could not be closed cleanly.');
      }),
    );
  });
  return repository;
}, retry: (retryCount, error) => null);

final gameProgressProvider =
    AsyncNotifierProvider<GameProgressController, GameProgress>(
      GameProgressController.new,
      retry: (retryCount, error) => null,
    );

class GameProgressController extends AsyncNotifier<GameProgress> {
  Future<void> _pending = Future<void>.value();

  @override
  Future<GameProgress> build() async => ref
      .watch(gameProgressRepositoryProvider.future)
      .then((repository) => repository.load());

  Future<void> _mutate(
    Future<GameProgress> Function(GameProgressRepository repository) operation,
  ) {
    final result = Completer<void>();
    _pending = _pending.then((_) async {
      try {
        await future;
        if (!ref.mounted) throw StateError('Game progress is unavailable.');
        final repository = await ref.read(
          gameProgressRepositoryProvider.future,
        );
        final updated = await operation(repository);
        if (ref.mounted) state = AsyncData(updated);
        result.complete();
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<void> setDifficulty(GameDifficulty difficulty) =>
      _mutate((repository) => repository.setDifficulty(difficulty));

  Future<void> recordResult({
    required GameDifficulty difficulty,
    required int score,
    required bool won,
  }) => _mutate(
    (repository) =>
        repository.recordResult(difficulty: difficulty, score: score, won: won),
  );

  void retry() {
    if (ref.read(gameProgressDirectoryProvider).hasError) {
      ref.invalidate(gameProgressDirectoryProvider);
    }
    if (ref.read(gameProgressRepositoryProvider).hasError) {
      ref.invalidate(gameProgressRepositoryProvider);
    }
    ref.invalidateSelf();
  }
}
