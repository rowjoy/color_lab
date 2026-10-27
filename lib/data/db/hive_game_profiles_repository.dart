import 'dart:async';
import '../storage/local_data_manager.dart';
import '../storage/hive_data_lease.dart';

import 'package:hive/hive.dart';
// Hive 2 has no public independent-registry factory. A private registry keeps
// equal box names in different directories from sharing the global box cache.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../features/games/domain/game_profiles_repository.dart';
import '../../features/games/domain/game_profiles_state.dart';
import '../../features/games/domain/game_progression_engine.dart';

/// Durable schema-v2 storage for every local player profile.
final class HiveGameProfilesRepository
    implements GameProfilesRepository, LocalDataOwner {
  /// Takes ownership of both boxes, including closing them on [close].
  HiveGameProfilesRepository.fromBoxes({
    required Box<dynamic> profilesBox,
    required Box<dynamic> legacyBox,
  }) : _profilesBox = profilesBox,
       _legacyBox = legacyBox;

  static const String stateKey = 'state';
  static const String legacyProgressKey = 'progress';

  static Future<HiveGameProfilesRepository> open({
    required String directory,
    String boxName = 'game_profiles_v2',
    String legacyBoxName = 'game_progress_v1',
  }) async {
    if (boxName == legacyBoxName) {
      throw const GameProfilesStorageException();
    }

    final hive = HiveImpl();
    Box<dynamic>? profilesBox;
    try {
      profilesBox = await _openObservedBox(
        hive: hive,
        directory: directory,
        boxName: boxName,
      );
      final legacyBox = await _openObservedBox(
        hive: hive,
        directory: directory,
        boxName: legacyBoxName,
      );
      return HiveGameProfilesRepository.fromBoxes(
        profilesBox: profilesBox,
        legacyBox: legacyBox,
      );
    } on Object catch (error) {
      if (profilesBox != null && profilesBox.isOpen) {
        try {
          await profilesBox.close();
        } on Object {
          // Preserve the original open failure.
        }
      }
      throw GameProfilesStorageException(error);
    }
  }

  final Box<dynamic> _profilesBox;
  final Box<dynamic> _legacyBox;

  @override
  Future<T> withMaintenance<T>(Future<T> Function(LocalDataLease) action) =>
      _enqueue(() async {
        await _ensureDurable();
        return action(
          HiveDataLease(
            {'profiles': _profilesBox, 'legacy': _legacyBox},
            beforeWrite: () => _needsFlush = true,
            flush: _ensureDurable,
          ),
        );
      });

  Future<void> _pending = Future<void>.value();
  Future<void>? _closing;
  bool _acceptingWork = true;
  bool _needsFlush = false;
  bool _profilesClosed = false;
  bool _legacyClosed = false;

  bool get _isClosed => _profilesClosed && _legacyClosed;

  Future<T> _enqueue<T>(FutureOr<T> Function() operation) {
    if (!_acceptingWork) {
      return Future<T>.error(
        StateError('HiveGameProfilesRepository is closing or closed'),
      );
    }
    final result = _pending.then<T>((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _ensureDurable() async {
    if (!_needsFlush) return;
    try {
      await _profilesBox.flush();
      await _legacyBox.flush();
      _needsFlush = false;
    } on Object catch (error) {
      throw GameProfilesStorageException(error);
    }
  }

  GameProfilesState _readState() {
    try {
      if (_profilesBox.containsKey(stateKey)) {
        final value = _profilesBox.get(stateKey);
        if (value is! Map) throw const FormatException('Invalid v2 state');
        return GameProfilesState.fromMap(Map<Object?, Object?>.from(value));
      }

      if (_legacyBox.containsKey(legacyProgressKey)) {
        final value = _legacyBox.get(legacyProgressKey);
        if (value is! Map) {
          throw const FormatException('Invalid legacy game progress');
        }
        final pending = LegacyGameProgressSnapshot.fromLegacyMap(
          Map<Object?, Object?>.from(value),
        );
        return GameProfilesState(
          activeProfileId: null,
          profiles: const {},
          pendingLegacySnapshot: pending,
          legacyMigrationComplete: false,
        );
      }

      return GameProfilesState(
        activeProfileId: null,
        profiles: const {},
        legacyMigrationComplete: true,
      );
    } on GameProfilesStorageException {
      rethrow;
    } on Object catch (error) {
      throw GameProfilesStorageException(error);
    }
  }

  Future<void> _writeState(GameProfilesState state) async {
    try {
      // Hive mutates its in-memory map before flush. Set the barrier before
      // put so any interrupted/failed boundary must be retried before reads.
      _needsFlush = true;
      await _profilesBox.put(stateKey, state.toMap());
      await _ensureDurable();
    } on GameProfilesStorageException {
      rethrow;
    } on Object catch (error) {
      throw GameProfilesStorageException(error);
    }
  }

  @override
  Future<GameProfilesState> loadState() => _enqueue(() async {
    await _ensureDurable();
    return _readState();
  });

  @override
  Future<ProgressionChange<T>> transact<T>(
    ProgressionChange<T> Function(GameProfilesState current) transition,
  ) => _enqueue(() async {
    await _ensureDurable();
    final current = _readState();

    // Transition failures are caller/domain failures and intentionally pass
    // through unchanged. No durable boundary has been reached at this point.
    final change = transition(current);
    await _writeState(change.state);
    return change;
  });

  @override
  Future<void> close() {
    if (_isClosed) return Future<void>.value();
    final inFlight = _closing;
    if (inFlight != null) return inFlight;

    // Closing is a one-way lifecycle boundary even when an individual box
    // close fails. A retry may finish cleanup, but no new work is accepted.
    _acceptingWork = false;
    final attempt = _pending.then((_) async {
      try {
        await _ensureDurable();
        if (!_profilesClosed) {
          await _profilesBox.close();
          _profilesClosed = true;
        }
        if (!_legacyClosed) {
          await _legacyBox.close();
          _legacyClosed = true;
        }
      } on GameProfilesStorageException {
        rethrow;
      } on Object catch (error) {
        throw GameProfilesStorageException(error);
      }
    });

    late final Future<void> tracked;
    tracked = attempt.whenComplete(() {
      if (!_isClosed && identical(_closing, tracked)) _closing = null;
    });
    _closing = tracked;
    return tracked;
  }
}

Future<Box<dynamic>> _openObservedBox({
  required HiveImpl hive,
  required String directory,
  required String boxName,
}) async {
  Future<Box<dynamic>> openBox() =>
      hive.openBox<dynamic>(boxName, path: directory, crashRecovery: false);

  // Observe Hive's shared opening future as well as the initiating one;
  // otherwise a failed file open can emit a second unhandled async error.
  final opened = await Future.wait([openBox(), openBox()]);
  return opened.first;
}

final class GameProfilesStorageException implements Exception {
  const GameProfilesStorageException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'GameProfilesStorageException';
}
