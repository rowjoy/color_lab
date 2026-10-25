import 'dart:async';

import 'package:color_lab/features/games/domain/game_profiles_repository.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';

/// Deterministic repository boundary used by repository and provider tests.
///
/// Reads, transactions, and close share one queue. Gates pause the matching
/// operation after it reaches the durable boundary, and failure flags remain
/// active until the test clears them.
final class InMemoryGameProfilesRepository implements GameProfilesRepository {
  InMemoryGameProfilesRepository({required GameProfilesState initialState})
    : _durableState = initialState;

  GameProfilesState _durableState;
  Future<void> _tail = Future<void>.value();
  Future<void>? _closeFuture;
  bool _acceptingWork = true;
  bool _closed = false;

  Completer<void>? loadGate;
  Completer<void>? writeGate;
  Completer<void>? closeGate;

  bool failLoad = false;
  bool failWrite = false;
  bool failClose = false;

  /// Fails the selected transaction after its state is durably installed.
  ///
  /// This is a one-shot test hook for storage implementations whose flush can
  /// report an error after the underlying write has become observable.
  int? failAfterWriteAttempt;

  int readCount = 0;
  int transitionCount = 0;
  int writeAttempts = 0;
  int writeCount = 0;
  int closeAttempts = 0;

  GameProfilesState get durableState => _durableState;
  bool get isClosed => _closed;

  @override
  Future<GameProfilesState> loadState() {
    if (!_acceptingWork) return _rejected<GameProfilesState>();
    return _enqueue(() async {
      readCount++;
      await loadGate?.future;
      if (failLoad) throw const TestGameProfilesRepositoryException('load');
      return _durableState;
    });
  }

  @override
  Future<ProgressionChange<T>> transact<T>(
    ProgressionChange<T> Function(GameProfilesState current) transition,
  ) {
    if (!_acceptingWork) return _rejected<ProgressionChange<T>>();
    return _enqueue(() async {
      readCount++;
      await loadGate?.future;
      if (failLoad) throw const TestGameProfilesRepositoryException('load');

      transitionCount++;
      final change = transition(_durableState);
      writeAttempts++;
      await writeGate?.future;
      if (failWrite) {
        throw const TestGameProfilesRepositoryException('write');
      }

      _durableState = change.state;
      writeCount++;
      if (failAfterWriteAttempt == writeAttempts) {
        failAfterWriteAttempt = null;
        throw const TestGameProfilesRepositoryException('post-write');
      }
      return change;
    });
  }

  @override
  Future<void> close() {
    if (_closed) return Future<void>.value();
    final inFlight = _closeFuture;
    if (inFlight != null) return inFlight;
    _acceptingWork = false;
    final future = _enqueue(() async {
      closeAttempts++;
      await closeGate?.future;
      if (failClose) {
        throw const TestGameProfilesRepositoryException('close');
      }
      _closed = true;
    });
    _closeFuture = future.whenComplete(() {
      if (!_closed) _closeFuture = null;
    });
    return _closeFuture!;
  }

  Future<T> _enqueue<T>(FutureOr<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<T> _rejected<T>() => Future<T>.error(
    StateError('GameProfilesRepository is closing or closed'),
  );
}

final class TestGameProfilesRepositoryException implements Exception {
  const TestGameProfilesRepositoryException(this.operation);

  final String operation;

  @override
  String toString() => 'TestGameProfilesRepositoryException($operation)';
}
