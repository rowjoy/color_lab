import 'dart:async';

import 'package:hive/hive.dart';
// Hive has no public factory for an independent registry.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../features/learning/domain/experiment_snapshot.dart';
import '../../features/learning/domain/learning_content.dart';
import '../../features/learning/domain/learning_library.dart';
import '../../features/learning/domain/learning_repository.dart';
import '../schema/corrupt_record.dart';
import '../schema/schema_registry.dart';
import '../storage/hive_data_lease.dart';
import '../storage/local_data_manager.dart';

final class HiveLearningRepository
    implements LearningRepository, LocalDataOwner {
  HiveLearningRepository._(this._box);

  /// Takes ownership of [box], including its close lifecycle.
  factory HiveLearningRepository.fromBox({required Box<dynamic> box}) =>
      HiveLearningRepository._(box);

  static Future<HiveLearningRepository> open({
    required String directory,
    String boxName = 'learning_library_v1',
  }) async {
    try {
      final hive = HiveImpl();
      final box = await hive.openBox<dynamic>(
        boxName,
        path: directory,
        crashRecovery: false,
      );
      return HiveLearningRepository._(box);
    } catch (_) {
      throw const LearningStorageException();
    }
  }

  static const _metaKey = '@library';
  static const _progressPrefix = 'progress:';
  static const _practicePrefix = 'practice:';
  static const _experimentPrefix = 'experiment:';
  static const _missing = Object();

  final Box<dynamic> _box;
  Future<void> _pending = Future<void>.value();
  Future<void>? _closing;
  bool _needsFlush = false;
  Map<Object, Object?>? _rollback;

  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    if (_closing != null) {
      return Future<T>.error(const LearningStorageException());
    }
    final result = _pending.then<T>((_) async {
      try {
        if (_rollback != null) await _restoreRollback();
        await _ensureDurable();
        return await operation();
      } catch (_) {
        throw const LearningStorageException();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _ensureDurable() async {
    if (!_needsFlush) return;
    await _box.flush();
    _needsFlush = false;
  }

  Future<void> _restoreRollback() async {
    final rollback = _rollback;
    if (rollback == null) return;
    _needsFlush = true;
    for (final entry in rollback.entries) {
      if (identical(entry.value, _missing)) {
        await _box.delete(entry.key);
      } else {
        await _box.put(entry.key, entry.value);
      }
    }
    await _ensureDurable();
    _rollback = null;
  }

  Future<void> _write(Map<Object, Object?> changes) async {
    _rollback = {
      for (final key in changes.keys)
        key: _box.keys.contains(key) ? _box.get(key) : _missing,
    };
    try {
      _needsFlush = true;
      for (final entry in changes.entries) {
        if (entry.value == null) {
          await _box.delete(entry.key);
        } else {
          await _box.put(entry.key, entry.value);
        }
      }
      await _ensureDurable();
      _rollback = null;
    } catch (_) {
      try {
        await _restoreRollback();
      } catch (_) {
        // The next serialized operation retries the exact rollback first.
      }
      throw const LearningStorageException();
    }
  }

  @override
  Future<T> withMaintenance<T>(
    Future<T> Function(LocalDataLease lease) action,
  ) => _serialize(
    () => action(
      HiveDataLease(
        {'learning': _box},
        beforeWrite: () => _needsFlush = true,
        flush: _ensureDurable,
      ),
    ),
  );

  @override
  Future<LearningLoadResult> load() => _serialize(() => _read().result);

  @override
  Future<LearningChange<T>> transact<T>(
    LearningChange<T> Function(LearningLibrary current) transition,
  ) => _serialize(() async {
    final before = _read();
    final change = transition(before.result.library);
    if (change.state.schemaVersion != 1) {
      throw const LearningStorageException();
    }
    final desired = _encode(change.state);
    final corruptKeys = before.corruptKeys;
    if (desired.keys.any(corruptKeys.contains)) {
      throw const LearningStorageException();
    }
    final changes = <Object, Object?>{
      for (final key in before.healthyKeys)
        if (!desired.containsKey(key)) key: null,
      ...desired,
    };
    await _write(changes);
    return change;
  });

  _LearningRead _read() {
    var topics = <LearningTopic>{};
    final progress = <String, LessonProgress>{};
    final practice = <PracticeAttempt>[];
    final experiments = <ExperimentRecord>[];
    final corrupt = <CorruptRecord>[];
    final healthyKeys = <Object>{};
    final corruptKeys = <Object>{};

    void reject(Object key, String reason) {
      corruptKeys.add(key);
      corrupt.add(
        CorruptRecord(
          collectionId: SchemaRegistry.learningLibrary.id,
          storageKey: key,
          reason: reason,
        ),
      );
    }

    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (key is! String || raw is! Map) {
        reject(key as Object, 'Stored value is not a named record.');
        continue;
      }
      try {
        if (key == _metaKey) {
          topics = _decodeMeta(raw);
        } else if (key.startsWith(_progressPrefix)) {
          final record = LessonProgress.fromMap(raw);
          if (key != '$_progressPrefix${record.lessonId}') {
            throw const FormatException('Progress key mismatch.');
          }
          progress[record.lessonId] = record;
        } else if (key.startsWith(_practicePrefix)) {
          final record = PracticeAttempt.fromMap(raw);
          if (key != '$_practicePrefix${record.id}') {
            throw const FormatException('Practice key mismatch.');
          }
          practice.add(record);
        } else if (key.startsWith(_experimentPrefix)) {
          final record = ExperimentRecord.fromMap(raw);
          if (key != '$_experimentPrefix${record.id}') {
            throw const FormatException('Experiment key mismatch.');
          }
          experiments.add(record);
        } else {
          throw const FormatException('Unknown learning row.');
        }
        healthyKeys.add(key);
      } on FormatException {
        reject(key, 'Stored learning record could not be decoded.');
      }
    }

    practice.sort((first, second) {
      final byTime = first.attemptedAt.compareTo(second.attemptedAt);
      return byTime == 0 ? first.id.compareTo(second.id) : byTime;
    });
    experiments.sort((first, second) {
      final byTime = second.updatedAt.compareTo(first.updatedAt);
      return byTime == 0 ? first.id.compareTo(second.id) : byTime;
    });
    return _LearningRead(
      result: LearningLoadResult(
        library: LearningLibrary(
          schemaVersion: 1,
          progressByLesson: progress,
          practiceHistory: practice,
          topicsToRevisit: topics,
          experiments: experiments,
        ),
        corruptRecords: corrupt,
      ),
      healthyKeys: healthyKeys,
      corruptKeys: corruptKeys,
    );
  }

  Map<Object, Object?> _encode(LearningLibrary library) => {
    _metaKey: {
      'schemaVersion': 1,
      'topicsToRevisit': [
        for (final topic in library.topicsToRevisit) topic.name,
      ],
    },
    for (final entry in library.progressByLesson.entries)
      '$_progressPrefix${entry.key}': entry.value.toMap(),
    for (final attempt in library.practiceHistory)
      '$_practicePrefix${attempt.id}': attempt.toMap(),
    for (final experiment in library.experiments)
      '$_experimentPrefix${experiment.id}': experiment.toMap(),
  };

  Set<LearningTopic> _decodeMeta(Map<dynamic, dynamic> raw) {
    if (raw.length != 2 ||
        raw['schemaVersion'] != 1 ||
        raw['topicsToRevisit'] is! List ||
        (raw['topicsToRevisit'] as List).any((item) => item is! String)) {
      throw const FormatException('Invalid learning metadata.');
    }
    final topics = <LearningTopic>{};
    for (final rawTopic in (raw['topicsToRevisit'] as List).cast<String>()) {
      final topic = LearningTopic.values.where((item) => item.name == rawTopic);
      if (topic.length != 1 || !topics.add(topic.single)) {
        throw const FormatException('Invalid learning topic.');
      }
    }
    return topics;
  }

  @override
  Future<void> close() {
    final existing = _closing;
    if (existing != null) return existing;
    final completer = Completer<void>();
    _closing = completer.future;
    () async {
      try {
        await _pending;
        if (_rollback != null) await _restoreRollback();
        await _ensureDurable();
        await _box.close();
        completer.complete();
      } catch (_) {
        completer.completeError(const LearningStorageException());
      }
    }();
    return completer.future;
  }
}

final class _LearningRead {
  const _LearningRead({
    required this.result,
    required this.healthyKeys,
    required this.corruptKeys,
  });

  final LearningLoadResult result;
  final Set<Object> healthyKeys;
  final Set<Object> corruptKeys;
}
