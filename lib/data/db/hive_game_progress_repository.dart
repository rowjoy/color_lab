import 'dart:async';

import 'package:hive/hive.dart';
// Hive 2 has no public independent-registry factory; avoid sharing its global
// box cache with the app's other repositories.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../features/games/domain/game_difficulty.dart';
import '../../features/games/domain/game_progress.dart';
import '../../features/games/domain/game_progress_repository.dart';

final class HiveGameProgressRepository implements GameProgressRepository {
  HiveGameProgressRepository.fromBox({required Box<dynamic> box}) : _box = box;

  static Future<HiveGameProgressRepository> open({
    required String directory,
    String boxName = 'game_progress_v1',
  }) async {
    try {
      final hive = HiveImpl();
      Future<Box<dynamic>> openBox() =>
          hive.openBox<dynamic>(boxName, path: directory, crashRecovery: false);
      final opened = await Future.wait([openBox(), openBox()]);
      return HiveGameProgressRepository.fromBox(box: opened.first);
    } catch (_) {
      throw const GameProgressStorageException();
    }
  }

  final Box<dynamic> _box;
  Future<void> _pending = Future<void>.value();
  Future<void>? _closing;
  bool _needsFlush = false;

  Future<void> _ensureDurable() async {
    if (!_needsFlush) return;
    await _box.flush();
    _needsFlush = false;
  }

  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    if (_closing != null) {
      return Future<T>.error(const GameProgressStorageException());
    }
    final result = _pending.then<T>((_) async {
      try {
        await _ensureDurable();
        return await operation();
      } catch (_) {
        throw const GameProgressStorageException();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  GameProgress _read() {
    final value = _box.get('progress');
    if (value == null) return const GameProgress();
    if (value is! Map) throw const GameProgressStorageException();
    return GameProgress.fromMap(value);
  }

  Future<GameProgress> _write(GameProgress progress) async {
    _needsFlush = true;
    await _box.put('progress', progress.toMap());
    await _ensureDurable();
    return progress;
  }

  @override
  Future<GameProgress> load() => _serialize(_read);

  @override
  Future<GameProgress> setDifficulty(GameDifficulty difficulty) =>
      _serialize(() async {
        final updated = _read().withDifficulty(difficulty);
        return _write(updated);
      });

  @override
  Future<GameProgress> recordResult({
    required GameDifficulty difficulty,
    required int score,
    required bool won,
  }) => _serialize(() async {
    if (score < 0 || score > 100) {
      throw const GameProgressStorageException();
    }
    final updated = _read().record(
      difficulty: difficulty,
      score: score,
      won: won,
    );
    return _write(updated);
  });

  @override
  Future<void> close() => _closing ??= _pending.then((_) async {
    try {
      await _ensureDurable();
      await _box.close();
    } catch (_) {
      _closing = null;
      throw const GameProgressStorageException();
    }
  });
}
