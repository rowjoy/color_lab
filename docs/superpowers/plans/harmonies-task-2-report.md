# Task 2 — durable saved palettes

Implemented the exact Task 2 model, repository, provider and test-helper APIs.
Saved palette snapshots are immutable, identified by base/mode, persisted in the
independent `color_palettes_v1` box, and never regenerated during construction or
loading. Existing history/preferences repositories and schemas were not edited.

## RED / GREEN evidence

All commands used the existing SDK and packages with network/package operations
excluded. The first non-escalated Flutter invocation could not write the existing
SDK's `engine.stamp`; subsequent test/format/analyze commands ran with the approved
SDK-cache access. No package installation or native changes occurred.

1. Before production model/storage code, ran:

   ```text
   flutter test --no-pub test/features/palette/domain/saved_palette_test.dart test/data/db/hive_palette_repository_test.dart test/data/db/hive_palette_durability_test.dart
   ```

   RED: exit 1, `+0 -3`, expected compilation failures because
   `saved_palette.dart`, `saved_palette_repository.dart`, and
   `hive_palette_repository.dart` did not exist. These were missing-feature
   compilation REDs, not runtime assertion failures. Task 1's real core types
   were available by execution; no stubs or duplicate harmony types were added.

   After implementation, the same command passed: exit 0, `+19: All tests passed!`.

2. Before production provider code, ran:

   ```text
   flutter test --no-pub test/features/palette/application/saved_palettes_providers_test.dart
   ```

   RED: exit 1, `+0 -1`, expected missing
   `lib/features/palette/application/saved_palettes_providers.dart` and its APIs.
   After implementation, the same command passed: exit 0,
   `+11: All tests passed!`.

3. Formatted the nine owned Dart files:

   ```text
   dart format lib/features/palette/domain lib/features/palette/application lib/data/db/hive_palette_repository.dart test/features/palette/domain test/features/palette/application test/data/db/hive_palette_repository_test.dart test/data/db/hive_palette_durability_test.dart test/support/in_memory_saved_palette_repository.dart
   ```

   Exit 0: `Formatted 9 files (8 changed)`.

4. Final scoped tests after formatting:

   ```text
   flutter test --no-pub test/features/palette/domain/saved_palette_test.dart test/features/palette/application/saved_palettes_providers_test.dart test/data/db/hive_palette_repository_test.dart test/data/db/hive_palette_durability_test.dart
   ```

   Exit 0: `+30: All tests passed!`.

5. Scoped analysis:

   ```text
   dart analyze lib/features/palette/domain lib/features/palette/application lib/data/db/hive_palette_repository.dart test/features/palette/domain test/features/palette/application test/data/db/hive_palette_repository_test.dart test/data/db/hive_palette_durability_test.dart test/support/in_memory_saved_palette_repository.dart
   ```

   Exit 0: `No issues found!`.

6. One full suite:

   ```text
   flutter test --no-pub
   ```

   Exit 1: `00:23 +459 -1: Some tests failed.` The sole failure was sibling
   `test/features/harmonies/presentation/harmonies_integration_test.dart` loading
   while `lib/features/harmonies/presentation/harmonies_screen.dart` did not yet
   exist. Compiler errors named that missing import at line 10 and undefined
   `HarmoniesScreen` at lines 306, 312 and 373. This was concurrent sibling work;
   no sibling files were edited and no full-suite success is claimed.

## Behavior covered

- Canonical literal v1 map for `complementary-AABBCC`, including an arbitrary
  stored `[#AABBCC, #010203]` snapshot that deliberately differs from generated
  harmony output. Trims names, converts offset timestamps to UTC, consumes a
  single-use input once, detaches from source mutations, and checks complete
  value equality/hash behavior.
- Rejects blank names; empty, oversized, repeated or wrongly anchored colors;
  unsupported versions; missing/extra keys; wrong types; unknown modes;
  noncanonical HEX; mismatched identity; and invalid/non-UTC/noncanonical dates.
- Actual disk save/close/fresh-open restores every field and the exact ordered
  color snapshot. Two simultaneously open equal-named boxes in separate
  directories retain independent libraries. Loads are immutable, newest first,
  with ascending identity as equal-time tie breaker.
- Idempotent duplicate base/mode saves preserve original name, timestamp and
  colors exactly. Different modes remain distinct. Concurrent save, duplicate,
  delete, read and close requests preserve queue order; missing deletes are
  harmless; operations after close reject.
- Failed save/delete flushes use a real Hive file/cache behind a wrapper that
  fails only the flush boundary. Reads, duplicate saves and missing deletes all
  reject while the flush barrier fails. Recovery then survives a fresh reopen.
  Queued close waits for writes, failed close leaves the box open for explicit
  retry, and successful retry persists the pending snapshot.
- Unsupported records, non-map records and mismatched box keys block reads and
  all writes; file bytes remain unchanged. Invalid Hive bytes are not recovered
  or truncated. Failed open futures do not leak unhandled asynchronous errors.
  Public repository errors do not expose raw paths/data.
- Providers serialize mutations and publish after durable operation plus reload;
  gated operations leave committed UI state visible. Save/delete failure keeps
  the prior list. Initial-load failure blocks edits until retry. A healthy
  repository is reused for load retry; failed directory/factory providers are
  recreated by explicit retry, with automatic background retries disabled.
- A real-file provider restart across fresh containers restores every snapshot
  field and persists deletion. Normal factory disposal closes the actual box.
  Disposal before directory resolution creates no files. A directory boundary
  fixture forces disposal immediately before real asynchronous open: the late
  factory creates the file and removes its owned lock on close. Queued controller
  edits reject after disposal instead of touching the library.
- Test-only in-memory helper validates constructor entries, preserves first
  duplicate, sorts deterministically, stores immutable snapshots, and exposes
  `failLoad`, `failWrites`, `writeGate`, `closeCount`, `activeWrites` and
  `maxConcurrentWrites`. It is a UI/provider boundary, not durability evidence.

## Owned files

- `lib/features/palette/domain/saved_palette.dart`
- `lib/features/palette/domain/saved_palette_repository.dart`
- `lib/data/db/hive_palette_repository.dart`
- `lib/features/palette/application/saved_palettes_providers.dart`
- `test/features/palette/domain/saved_palette_test.dart`
- `test/features/palette/application/saved_palettes_providers_test.dart`
- `test/data/db/hive_palette_repository_test.dart`
- `test/data/db/hive_palette_durability_test.dart`
- `test/support/in_memory_saved_palette_repository.dart`
- `docs/superpowers/plans/harmonies-task-2-report.md`

## Limits

Durability evidence is actual file flush/close/reopen and controlled flush
failure, not a simulated power-loss test. Documents-directory lookup is
overridden with temporary app-private directories in tests; platform plugin
execution and native builds were outside this task. Full integration completion
depends on sibling harmonies UI work. No Git initialization/commits, subagents,
package changes or existing repository refactors were performed.
