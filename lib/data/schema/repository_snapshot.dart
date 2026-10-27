import 'corrupt_record.dart';

/// A healthy repository view plus non-destructive warnings for skipped rows.
///
/// Owns defensive copies so neither a consumer nor the supplying repository
/// can mutate a point-in-time result after construction.
final class RepositorySnapshot<T> {
  RepositorySnapshot({
    required List<T> records,
    required List<CorruptRecord> corruptRecords,
  }) : records = List.unmodifiable(records),
       corruptRecords = List.unmodifiable(corruptRecords);

  final List<T> records;
  final List<CorruptRecord> corruptRecords;
}
