# Plan 03 Task 2 evidence — 2026-10-28

Base `3aa0c3b72b5919ac533924a4b87bca83d334190a`, branch `TintAtlas`. Task 2 domain/storage foundation only; no new brush intent, visible Redo, AI merge policy or autosave sequencing.

## Exact commands, history and compatibility

- `MaskEditCommand` detaches immutable indices and all four before/after label/intent arrays, validates bounded dimensions/lengths/order/values/non-no-op, and counts all typed payloads (8 bytes per changed pixel). Forward/backward validate every indexed precondition before applying; stale state and mismatched dimensions fail atomically.
- `MaskEditHistory` stores oldest-first undo and last-entry-next redo stacks, with immutable result/history transitions. Push clears redo and evicts oldest whole undo commands. Both stacks count toward 20 commands / 16 MiB. A newest command exceeding 16 MiB clears all history: retaining older commands would leave a broken undo chain. A named full-frame controller compatibility test proves visible pixels survive this case.
- Snapshot and draft own aligned typed `MaskEditHistory` and immutable intent. Snapshot `copyWith`, new draft `copyWith` and `withColors` retain both; complete undo and redo chains are validated against current bytes. Session save/reopen mechanically forwards the new fields so color/metadata actions cannot discard them.
- Old `MaskUndoCommand`/`MaskUndoHistory` remain annotated deprecated, transient adapters only. The draft's temporary constructor accepts either history object and immediately converts legacy deltas from actual ownership without inventing intent; its stored field is always the new type. `legacyHistory` and the temporary `commands` view support the immediate Task 3 migration. Controller changes only bridge existing refinement results/Undo to the exact type; refresh remains behind its legacy adapter. These compatibility paths suppress only same-package deprecation diagnostics. No legacy history is serialized.
- Schema stays 2. Frozen v1 reads untouched intent/empty history; Task 1 transitional v2 without a history key reads empty history. A present history must be valid and non-null. Every new v2 write includes a hashed `.history.bin` asset, including empty history. Missing/corrupt/trailing/oversized history invalidates only its revision, falls back through acknowledged ancestry, quarantines metadata, preserves the CAS token, and ignores a newer orphan. Owned cleanup recognizes history files without changing owner/delete/link boundaries.

## Binary format and bounds

`TAEH`, big endian, version 1. The 28-byte header contains magic, uint16 version/reserved-zero, then uint32 width/height/undo-count/redo-count/payload-bytes. Undo records precede redo records in stack order. Each record has uint32 width/height/index-count, all uint32 indices, and before-label/after-label/before-intent/after-intent byte arrays. Counts, dimensions, extents, total payload, maximum encoded length and exact end-of-input are checked before allocating deltas. Command validation checks order/values/no-op; snapshot validation checks stack ordering/current-state preconditions. Maximum asset size is `16,777,216 + 28 + 20*12 = 16,777,484` bytes, outside the JSON manifest. Digest/path/length checks precede decode.

## TDD commands and counts

`F=/Users/jamirulislam/Applications/flutter/bin/flutter`, bundled Dart `D=/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart`.

Completed RED, exit 1, **+63 / -4**, no compiler/harness errors:

```sh
$F test --no-pub test/features/room_studio/domain/mask_edit_command_test.dart test/features/room_studio/domain/mask_edit_history_test.dart test/features/room_studio/data/room_project_codec_test.dart test/data/files/file_room_project_repository_test.dart --reporter expanded
```

RED failed real missing-history API assertions and the required-history-asset assertion. Initial new domain tests entered through the existing snapshot API; direct command/history edge cases were added before production implementation once the new API could be imported.

One final focused GREEN, exit 0, **+90 / -0**, no failed attempt or passing-suite rerun:

```sh
$F test --no-pub test/features/room_studio/domain/mask_edit_command_test.dart test/features/room_studio/domain/mask_edit_history_test.dart test/features/room_studio/domain/mask_undo_test.dart test/features/room_studio/data/room_project_codec_test.dart test/data/files/file_room_project_repository_test.dart --reporter expanded
```

Additional narrowly named existing controller budget assertion, exit 0, **+1 / -0**:

```sh
$F test --no-pub test/features/room_studio/application/room_mask_controller_test.dart --plain-name 'over-budget exact commands retain visible pixels with no partial undo' --reporter expanded
```

That assertion formerly assumed 5 bytes/pixel (`12,800,000` bytes for 1600×1600); the required exact payload is 8 bytes/pixel (`20,480,000`), so history is empty and the edited floor remains visible. The controller suite was not run.

## Analyzer, format and preservation

The 18 changed eligible Dart paths below were supplied explicitly to bundled-Dart formatting, never `lib/main.dart`. Initial formatting: 17 files / 16 changed, exit 0; subsequent changed-path formatting: 9 files / 2 changed. Final `$D format --output=none --set-exit-if-changed` over all 18 paths: exit 0, **0 changed**.

`$F analyze --no-pub` over the initial 17 paths reported 12 brace-style infos and one unused import (exit 1); fixed before GREEN. The nine affected/additional paths were analyzed again: exit 0, **no issues** (2.1 s). Together these runs cover all 18 final changed Dart paths. `git diff --check` is clean.

- Frozen source fixtures unchanged. Independent recheck: all **13 files / 5,801 bytes** match inventory lengths/SHA-256; inventory SHA-256 remains `365055822f7b29fbff9b09afdd242c8bd597f0ff9a0980b99d559e11fbca1013`. Tests read exact static v1 bytes, plus transitional-v2 and both-stack rewrite/reopen cases.
- Appearance/intent/variants/IDs/UTC timestamps, valid immutable assets, storage revision/CAS, private `color_lab` root and shared-library ownership are preserved. Source/external exports and deletion boundaries are unchanged. Existing process-interruption guarantee is retained; no power-loss/directory-fsync guarantee or v1/Task-1-reader downgrade compatibility is claimed.
- No full suite, Android/iOS build, dependency/native/ads/signing changes, push, publish or merge. Full/native checks remain deferred until approved Plan 08 completion.
- `git diff -- lib/main.dart` SHA-256 remains `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`; file SHA-256 remains `11c14bf82927540b14857b8da7a948708062b9bbb093857c7d418f7e3fb278d5`. Never edited, formatted, staged or committed.

Logs in `/private/tmp/`:

| Log | SHA-256 |
| --- | --- |
| `plan03-task2-red.log` | `666aaa221cc372348d4d75b8176374d1f862b71223c3924fb75d60deb5390dd2` |
| `plan03-task2-green.log` | `1ae7aa7f23c7f07a6f1f129b8b0031a80b6d99a1df8bbf47ca23a7d1844600ed` |
| `plan03-task2-green-controller-compatibility.log` | `b6976827dcbb5b60e47a4865ef5d1030a23bc6e70124786d88d0303029f35380` |
| `plan03-task2-analyze.log` | `7487fff40d7f911761a87a8c8356b526623c5972c6747f5517943e21681885d5` |
| `plan03-task2-analyze-final.log` | `66ab780aa6b19b26d8b8fadb55ea02c29d74d4d5274249fc0ece503218137ab6` |

## Explicit path inventory

```text
lib/features/room_studio/domain/mask_edit_command.dart
lib/features/room_studio/domain/mask_edit_history.dart
lib/features/room_studio/domain/mask_undo.dart
lib/features/room_studio/domain/room_mask_state.dart
lib/features/room_studio/domain/room_project.dart
lib/features/room_studio/data/mask_edit_history_codec.dart
lib/features/room_studio/data/room_project_codec.dart
lib/data/files/file_room_project_repository.dart
lib/features/room_studio/application/room_mask_controller.dart
lib/features/room_studio/application/room_project_session_controller.dart
test/features/room_studio/domain/mask_edit_command_test.dart
test/features/room_studio/domain/mask_edit_history_test.dart
test/features/room_studio/domain/mask_undo_test.dart
test/features/room_studio/data/room_project_codec_test.dart
test/data/files/file_room_project_repository_test.dart
test/support/room_project_fixtures.dart
test/support/mask_edit_fixtures.dart
test/features/room_studio/application/room_mask_controller_test.dart
docs/release/schema-registry.md
.superpowers/sdd/2026-10-27-tintatlas-manual-mask-correction/task-2-report.md
```

Commit message: `feat: add exact room mask undo and redo`. Expected postcommit status: only protected ` M lib/main.dart`.


## Fix round 1 — prevent lossy refresh (2026-10-28)

FIX_BASE `3c5cb9ad53d36b5b0ec4f964fb90be616bd301c6`. Addressed only the Important finding that legacy refresh discarded exact intent history and redo. `reanalyzeCurrentPhoto` now returns false for a nonempty redo stack or any undo command with differing before/after intent. This check occurs before operation increment, state publication, AI dispatch, legacy conversion and autosave. Losslessly representable legacy refresh remains available; Task 3 still owns exact refresh rebasing. No new rebasing semantics were invented.

Three new tests load valid persisted snapshots with (a) intent-only undo, (b) label-changing undo with different before/after intent and (c) redo. Each verifies rejection, identical draft/history/state/session, exact intent, zero segmentation requests/saves and unchanged stored revision/snapshot.

Clean RED, exit 1, **+0 / -3**, all expected false / actual true (no compiler/harness errors):

```sh
$F test --no-pub test/features/room_studio/application/room_mask_controller_test.dart --name 'refresh rejects lossy exact history' --reporter expanded
```

Verification of only the regressions plus named lossless/failed/stale checks:

```sh
$F test --no-pub test/features/room_studio/application/room_mask_controller_test.dart --name 'refresh rejects lossy exact history|^refresh RoomSegmentationFailureKind.processing keeps the edited draft usable$|^late refresh (success|error) cannot overwrite edit$|^refresh keeps manual Add and Erase, colors, and rebased undo$' --reporter expanded
```

This completed **+4 / -3** (exit 1): all four existing named checks passed. The three regressions had already verified rejection and unchanged state, then failed a test-only identity assumption comparing reopened history to the original repository fixture; `compute` copies that object. Corrected that assertion to the captured pre-refresh draft history. Production code was unchanged. Reran only the three failed named cases using the RED command: exit 0, **+3 / -0**. Thus all seven selected cases have passing evidence without repeating passing checks or any prior suite.

Changed-path analyzer: controller + test, exit 0/no issues (1.3 s); corrected test alone, exit 0/no issues (1.3 s). Formatter: two paths / one changed, followed by `$D format --output=none --set-exit-if-changed` on those two paths, exit 0/**0 changed**. `git diff --check` clean. No broad suite/build. Frozen fixtures/domain/storage/dependencies/native files unchanged. Protected main diff SHA-256 remains `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`.

Exact fix paths: `lib/features/room_studio/application/room_mask_controller.dart`, `test/features/room_studio/application/room_mask_controller_test.dart`, and this appended report only. Commit message: `fix: reject lossy legacy mask refresh`.

| `/private/tmp/` log | SHA-256 |
| --- | --- |
| `plan03-task2-fix1-red.log` | `1031c2a63cf85eb128ff83b5dc5b1540546249bed1357172e08b9575d2de2f32` |
| `plan03-task2-fix1-green.log` | `d0d12e32f081c6f107f549af43f1b384abe790b80390f853395c9b9df70ed0b2` |
| `plan03-task2-fix1-green-correction.log` | `a70b06817cc2efd873a4028dcfe9c263ef2d10a6d67664e2a04b1b2b79831166` |
