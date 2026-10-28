import '../../../data/schema/corrupt_record.dart';
import 'learning_library.dart';

final class LearningStorageException implements Exception {
  const LearningStorageException();
}

final class LearningChange<T> {
  const LearningChange({required this.state, required this.value});

  final LearningLibrary state;
  final T value;
}

final class LearningLoadResult {
  LearningLoadResult({
    required this.library,
    required Iterable<CorruptRecord> corruptRecords,
  }) : corruptRecords = List.unmodifiable(corruptRecords);

  final LearningLibrary library;
  final List<CorruptRecord> corruptRecords;
}

abstract interface class LearningRepository {
  Future<LearningLoadResult> load();

  Future<LearningChange<T>> transact<T>(
    LearningChange<T> Function(LearningLibrary current) transition,
  );

  Future<void> close();
}
