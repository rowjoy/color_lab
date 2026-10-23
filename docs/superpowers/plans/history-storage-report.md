# History storage implementation report

Task 1 is implemented in the four assigned source/test directories.

## Public contracts

- `SavedColor({required id, required hex, required name, required isFavorite, required createdAt, required source})` is immutable, normalizes RGB identity to uppercase `#RRGGBB`, trims and validates names, converts dates to UTC, and implements value equality, `hashCode`, and `copyWith`.
- `SavedColor.toMap()` returns an immutable version-1 map with keys `version`, `id`, `hex`, `name`, `isFavorite`, `createdAt`, and `source`. Timestamps are canonical UTC ISO-8601 strings; sources are enum names. `SavedColor.fromMap(Map<dynamic, dynamic>)` validates field types, canonical identities, timestamps, schema version, and known source values; invalid records throw `FormatException`.
- `ColorSource` exports all six agreed values: manual, studio, lab, room, camera, gallery.
- `ColorHistoryRepository` exports the exact planned `load`, named-argument `save`, `setFavorite`, `delete`, and `close` methods.
- `HistoryStorageException` is exported from `color_history_repository.dart`, has a const no-argument constructor, and exposes only a generic string. All repository failures, including missing favorite targets, use this type.
- `HiveColorHistoryRepository.open({required String directory, String boxName = 'color_history_v1', DateTime Function()? clock})` delegates directory selection and lifetime to its caller. `close()` is idempotent and preserves box files.
- `HiveColorHistoryRepository.fromBox({required Box<dynamic> box, DateTime Function()? clock})` accepts an already opened box and takes ownership of its lifetime. This supports dependency injection without placing fault controls in production storage.

## Behavior and assumptions

Reads and writes share an operation queue. Mutations validate the entire current library before writing, await Hive writes and flushes, and preserve existing duplicate metadata including favorite, timestamp, name, and source. Missing deletes are no-ops. HEX operation IDs normalize through the RGB parser. Results are immutable and sort newest first, then ascending canonical ID for equal timestamps.

Every edit marks a pending durability barrier before calling Hive. Only successful flush clears it. Subsequent reads, mutations (including duplicate/no-op branches), and close must successfully retry that barrier before reporting success or exposing Hive's cached state. A failed close leaves the box available for a later explicit retry. A failed flush can therefore surface the same generic storage error repeatedly until the backing filesystem accepts a flush; the UI retains its last successful list during that interval.

There is no recovery, deletion, or automatic database reset for malformed data. Hive binary crash recovery is explicitly disabled to prevent automatic truncation. Each repository uses an independent `HiveImpl` registry because Hive's global registry otherwise aliases same-name boxes across directories; Hive 2.2.3 has no public registry factory, so the narrow internal import is documented. Opening joins Hive's internal pending-open future to consume its duplicate error completion as well as the caller-facing future. A real invalid-directory failure exposed this Hive behavior; the workaround is covered by invalid-directory and corrupt-file tests.

## Verification

Tests were written first and run before implementation. The initial absence produced expected missing-contract compile failures; minimal contract stubs then produced runtime failures for missing normalization and unimplemented persistence. The full implementation then exposed the Hive duplicate-error bug above, which was investigated in dependency source and corrected.

- `flutter test test/features/history/domain/saved_color_test.dart test/data/db/hive_color_history_repository_test.dart --reporter expanded`: **17 passed**.
- Real temporary-filesystem tests close and reopen Hive for saved metadata, favorite toggles, deletion, duplicate metadata, ordering, and queued edits. Additional tests verify concurrent save/favorite/duplicate/delete/load, immutable snapshots, missing favorites, malformed-map bytes preserved exactly, corrupt binary bytes preserved exactly, generic open failures, queue closure, and separate same-name boxes in separate directories.
- Domain tests cover normalization, validation, all source round trips, immutable versioned maps, copies, equality, malformed schemas/sources/types/dates.
- `dart format lib/features/history/domain lib/data/db test/features/history/domain test/data/db`: completed.
- `flutter analyze lib/features/history/domain lib/data/db test/features/history/domain test/data/db`: **No issues found**.
- Full-suite integration run during concurrent implementation: **62 passed, 3 load failures** because `lib/features/history/presentation/save_color_actions.dart` was still absent. Affected test files were `test/features/history/save_color_actions_test.dart`, `test/features/history/presentation/color_history_section_test.dart`, and `test/widget_test.dart`. Root owns that pending implementation and the final integrated rerun; no storage failures occurred.

## Durability review follow-up

Review identified that Hive 2.2.3 `BoxImpl._writeFrames` commits the cache after backend writes, while `Box.flush` separately calls the backend flush. The initial implementation could return unflushed records from `load` and report success from duplicate saves, unchanged favorites, missing deletes, or close after an earlier flush failed. Dependency source investigation confirmed this exact ordering.

Five fault tests were added using actual filesystem-backed Hive boxes wrapped only at the flush boundary. The red run produced **5 expected failures**: reads exposed the changed cached list after failed save/favorite/delete flushes, and close reported success. The durability barrier above corrected those failures. Tests exercise repeated failed reads and no-op retries, successful retry without losing original metadata, actual close/reopen persistence for save/favorite/delete, successful read retry, and queued close failure followed by successful close retry.

- Final `flutter test test/features/history/domain test/data/db --reporter expanded`: **22 passed**.
- Final `flutter analyze lib/features/history/domain lib/data/db test/features/history/domain test/data/db`: **No issues found**.
- Final `dart format lib/data/db test/data/db`: completed.
- Root owns the full integrated suite rerun after this review fix; earlier integration status above is historical, not a current completion claim.
