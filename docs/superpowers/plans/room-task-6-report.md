# Task 6: brush, erase, and exact bounded undo

Status: DONE. No commits created; this workspace has no Git repository. Implementation followed the already reviewed Task 5 real AI gate. The controller supplied the compiler-deny launch command before RED; no manual-first substitution was made.

## Scope and APIs

Created only these four source files and two test files, plus this report:

- `lib/features/room_studio/domain/mask_stroke.dart`: immutable `MaskPoint`, `MaskEditMode`, and deeply snapshotted `MaskStroke`; finite normalized coordinates, nonempty segments, diameter .01–.20/default .05.
- `lib/features/room_studio/domain/mask_undo.dart`: detached immutable typed `MaskUndoCommand` and immutable `MaskUndoHistory`. Invalid dimensions, empty/mismatched delta, unsorted/duplicate/out-of-bounds indices, and labels outside 0–4 are rejected. History exposes `commands`, `last`, `byteLength`, `canUndo`, `push`, and `withoutLast`.
- `lib/features/room_studio/refine/mask_refinement.dart`: immutable `MaskEditResult`, pure `applyMaskStroke` and `undoMaskStroke`. Add transfers ownership, Erase changes selected ownership only, undo restores exact old bytes. Delta indices are sorted and contain changed pixels exactly once. AI differences are counted independently of undo history for both operations.
- `lib/features/room_studio/refine/mask_refinement_service.dart`: `MaskRefinementService`, `IsolateMaskRefinementService`, and `maskRefinementServiceProvider`. Both methods call top-level callbacks through Flutter `compute`; the adapter owns no interpreter, project store, or pixel loop.
- `test/features/room_studio/refine/mask_refinement_test.dart`: 14 cases covering inputs, geometry, ownership, no-op/delta behavior, exact undo, dimensions, dirty count after eviction, and real compute.
- `test/features/room_studio/domain/mask_undo_test.dart`: 7 cases covering validation, immutable typed buffers, history snapshots/identity, command cap, full byte cap, and an oversized single command.

No controller, acquisition, UI, model, dependency, SDK, pub-cache, or platform configuration files were edited. Read-only `diff -qr` against `/private/tmp/color-lab-task6-base.s4OUTk/source/{lib,test}` found only the four new source and two new test files. Unrelated files, old APK, and ZIPs were untouched. No clean, install, data-clear, Git initialization/worktree/commit, APK/native app build, manual compiler command, or dependency resolution was run. Existing warm dependency hook artifacts were neither deleted nor directly modified.

## TDD and guarded test evidence

All actual Flutter test executions used the exact controller-approved fail-closed compiler barrier, with `require_escalated` to permit Seatbelt startup. The inner native-compiler denial remained in place throughout.

Initial launch of the following command under the outer default sandbox exited 71 before Flutter started: `sandbox-exec: sandbox_apply: Operation not permitted`. This is an infrastructure launch denial, not TDD RED. The same command then ran under approved escalation.

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/refine/mask_refinement_test.dart test/features/room_studio/domain/mask_undo_test.dart --reporter expanded
```

1. First actual RED: exit 1, `+0 -2: Some tests failed.` Both test files failed to load because the four refinement APIs did not yet exist. This run also exposed a test fixture inferred as `num` instead of `double`; corrected the fixture list to `<double>` before repeating RED. No production code existed yet.
2. Confirmed RED after that correction, same command: exit 1, `+0 -2: Some tests failed.` Relevant expected errors were missing `mask_stroke.dart`, `mask_undo.dart`, `mask_refinement.dart`, and `mask_refinement_service.dart` and their not-yet-defined types/functions. No unrelated numeric type error remained. This is the fresh RED used before implementation.
3. Focused GREEN after the minimal implementation, same command: exit 0, `+21: All tests passed!`. Both exact-pixel and budget tests and the real compute service passed. No native-compiler barrier failure occurred.
4. One final full suite after final production edits/formatting:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
```

Exit 0 in 28 seconds, `+701: All tests passed!` (680 existing plus 21 new). No failing or skipped tests were reported. No native-compiler barrier failure occurred. The barrier allows existing prebuilt Dart/Flutter tools and dependency libraries; it is not permission to rebuild native dependencies.

## Independent expected pixels and bytes

Expectations use hand-derived fixtures, not rasterizer helpers. Pixel centers are `(x + .5, y + .5)` in image coordinates; normalized points multiply by width/height, with radius `diameterFraction * min(width, height) / 2`. Segment projection clamps to the finite segment, and each separate segment is rasterized independently within image-clipped candidate bounds. No smoothing changes ownership.

- On `[1,2,0,4]` at 2×2, Floor Add at `(.25,.25)`/.01 yields `[3,2,0,4]`, index `[0]`, previous `[1]`, dirty count 1, and undo restores `[1,2,0,4]` with dirty count 0.
- On `[3,1,2]`, erasing Wall at the Floor pixel leaves `[3,1,2]` and no command; traversing the whole row erases only Wall to `[3,0,2]`.
- A 5×5 diagonal from `(.1,.1)` to `(.9,.9)` with diameter .20 has radius .5. Only indices `[0,6,12,18,24]` are within that distance; the complete literal 25-label output is asserted.
- Disconnected points on a 5×1 row produce `[3,0,0,0,3]`; they cannot paint the middle. A 10×2 point at `(.25,.25)` with diameter .20 changes only index 2, distinguishing the shorter-side radius from a width-based radius.
- A line on the left border of 5×5 with radius .5 includes the first column exactly; a point at `(.2,.1)` includes exact-radius indices `[0,1]`.
- Repeated points and overlapping traversal over `[4,2,1]` produce `[3,3,3]` with unique sorted indices `[0,1,2]` and old labels `[4,2,1]`.
- 21 separate edits on a 30×1 AI-zero map evict the first command. Undoing all 20 retained commands leaves only the first pixel 3 and `changedFromAiCount == 1`, despite empty history.

Each changed pixel costs exactly 4 bytes (`Uint32List` index) plus 1 byte (`Uint8List` prior label); `byteLength` sums typed buffer lengths only. A full 1600×1600 delta therefore costs `2,560,000 * 5 = 12,800,000` bytes, below the `16 * 1024 * 1024 = 16,777,216` byte cap. The real constructor/history budget test stores this full-frame-sized command, then 795,443 more entries costing 3,977,215 bytes, totaling 16,777,215. One additional five-byte command forces oldest-first eviction, leaving 3,977,220 bytes. Another test confirms a single 16,777,220-byte command evicts itself and earlier history rather than breaking the cap. A separate 21-command fixture verifies the 20-command limit. Existing immutable commands remain identical across snapshots; their buffers are not recopied by pushes/pops.

## Real compute, immutability, analyzer, and format

The service test obtains the actual provider/default `IsolateMaskRefinementService`, calls real `compute` apply and undo without replacing callbacks or Flutter compute, checks literal returned ownership/dirty values and old bytes, and verifies that the returned command's typed indices remain immutable after transport. Both methods perform their pixel work inside the compute callback on the native test platform. Other tests mutate original stroke lists and delta input arrays after construction and attempt mutation through both typed lists and their buffer views; snapshots remain detached and mutation throws.

Initial scoped analyzer found one `curly_braces_in_flow_control_structures` info in the new rasterizer. Added braces; no functional behavior changed. Final scoped analyzer:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics analyze lib/features/room_studio test/features/room_studio
```

Exit 0, `No issues found!`.

The first formatter invocation formatted the new files but exited 1 because its telemetry session mtime write outside the workspace was denied. Subsequent commands used the supported `--suppress-analytics` flag; no telemetry settings/config files were edited. Final scoped formatting:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format lib/features/room_studio/domain/mask_stroke.dart lib/features/room_studio/domain/mask_undo.dart lib/features/room_studio/refine/mask_refinement.dart lib/features/room_studio/refine/mask_refinement_service.dart test/features/room_studio/refine/mask_refinement_test.dart test/features/room_studio/domain/mask_undo_test.dart
```

Exit 0, 6 files, 0 changed. Final global format check:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test tool
```

Exit 0, 176 files, 0 changed.

## Self-review and limits

Reviewed all six new files against the brief and baseline scope. Confirmed exact finite-segment pixel-center geometry, disconnected breaks, inclusive radius, border clipping, exclusive ownership, unchanged-pixel exclusion, once-per-index old labels, precise immutable typed deltas, oldest eviction under both limits, structural sharing, exact restoration, dimension checks, and dirty computation independent of history. Pure functions are directly testable; the production adapter has only compute dispatch and no UI-isolate pixel loops. No unresolved correctness concern identified.

The existing photo limits (24/32 MiB, 24 million pixels, 16,384 per source axis, working longest edge 1600), Android API 24, and iOS 13 remain unchanged. Task 6 does not connect a controller or UI; callers in subsequent tasks will supply the prepared working ownership map and original AI map. The pure domain types do not add a competing image acquisition limit. The controller retains responsibility for independent review and its final native-model smoke; this report claims only the guarded tests and analysis executed here.
