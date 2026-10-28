import 'dart:async';

import 'package:color_lab/data/schema/corrupt_record.dart';
import 'package:color_lab/features/learning/domain/learning_library.dart';
import 'package:color_lab/features/learning/domain/learning_repository.dart';

final class InMemoryLearningRepository implements LearningRepository {
  InMemoryLearningRepository({
    LearningLibrary? initial,
    Iterable<CorruptRecord> corruptRecords = const [],
  }) : _library = initial ?? LearningLibrary.empty(),
       _corruptRecords = List.unmodifiable(corruptRecords);

  LearningLibrary _library;
  final List<CorruptRecord> _corruptRecords;
  Future<void> _pending = Future<void>.value();
  bool _closed = false;
  bool failNextTransaction = false;
  bool get closed => _closed;

  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    if (_closed) {
      return Future.error(const LearningStorageException());
    }
    final result = _pending.then<T>((_) async {
      if (_closed) throw const LearningStorageException();
      return operation();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<LearningLoadResult> load() => _serialize(
    () =>
        LearningLoadResult(library: _library, corruptRecords: _corruptRecords),
  );

  @override
  Future<LearningChange<T>> transact<T>(
    LearningChange<T> Function(LearningLibrary current) transition,
  ) => _serialize(() {
    final change = transition(_library);
    if (failNextTransaction) {
      failNextTransaction = false;
      throw const LearningStorageException();
    }
    _library = change.state;
    return change;
  });

  @override
  Future<void> close() async {
    if (_closed) return;
    await _pending;
    _closed = true;
  }
}
