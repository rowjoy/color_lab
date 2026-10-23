# Task 7 — retained revision-safe Room controller

Status: DONE. API ready for the Room editor UI. Commits: none.

## Files

- `lib/features/room_studio/domain/room_mask_state.dart`
- `lib/features/room_studio/application/room_mask_controller.dart`
- `test/features/room_studio/application/room_mask_controller_test.dart`
- This report.

Read-only comparisons against `/private/tmp/color-lab-task7-base.lC4T1j/source`
showed only the two new production files under `lib`, and the new application
test directory under `test`. No UI, acquisition, segmentation, refinement,
native, SDK, dependency, model, or existing artifact edits were made.

## API and behavior

The required retained `roomMaskProvider`, `roomPhotoIdFactoryProvider`, immutable
candidate/draft/state types, enums, import/continue/analyze/retry/cancel methods,
selection controls, and captured stroke/undo/restore methods are implemented.
`failure` is a nullable `RoomMaskFailureKind`. Nullable snapshot fields can be
cleared explicitly through `copyWith`. Draft construction checks both mask
dimensions, revision, and dirty-count bounds without scanning pixels.

Provider creation has no acquisition, recovery, inference, or refinement side
effects. Dependencies are read during explicit actions, not watched in `build`.
The provider survives removal of all screen subscriptions.

Identity domains are separate: acquisition `requestId`, generated `photoId`,
logical operation generation, edit-selection generation, and `maskRevision`.
Equal image dimensions never establish identity. New successful inference
atomically commits a draft at revision 0 with empty history; failed inference
keeps the previous committed draft and candidate available for retry/cancel.
Only a valid successful AI result, including an all-empty result, enables
manual editing. A model error never substitutes an empty editable draft.

Import passes a live/current-operation/screen-active callback into the real
acquisition request. Claims check screen activity before starting, then accept
prepared pixels synchronously while acquisition holds its gate. Hidden during
claim: stage the candidate in `acquiring`, `editBusy=false`, start no AI, and
wait for explicit `analyzeCandidate`. Disposed/superseded during claim: reject
acceptance so the receipt remains pending. Hidden/cancelled/disposed late
native results likewise remain in the shared acquisition owner.

Refinement is serialized through a physical gate. Captured photo/revision,
selected layer, and tool are checked before launch. Selection changes during
work invalidate completion even if selection is changed back. Replacements and
cancellation discard old worker output and errors. A current ready draft stays
`editBusy=true` until an older physical worker finishes, so `canEdit` accurately
reflects whether a new edit can start. Finishing that gate only releases busy
state, never old masks/history/errors. Acquiring/analyzing phases disable edits
through stage; staged candidates do not show edit busy.

All rasterization and dirty-pixel counting remain in the refinement service.
The controller consumes `changedFromAiCount`; history length never determines
dirty status. Restore uses the original immutable AI map, clears history,
increments revision, and requires the caller to have obtained UI confirmation.
Show-original preserves pixels and switches the tool to Move. Brush input is
clamped to .01–.20; nonfinite values are ignored; default is .05.

## Verification commands and results

Working directory for every command:
`/Users/jamirulislam/Movies/dart_jpo/color_lab`.

Every Flutter invocation used this exact command for the focused tests:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_mask_controller_test.dart --reporter expanded
```

The initial outer-sandbox attempt exited 71 with
`sandbox-exec: sandbox_apply: Operation not permitted`; it ran no tests.
Subsequent Flutter commands used approved `require_escalated` outer execution
and kept the mandatory inner compiler-denial profile intact.

Focused command chronology:

1. Fresh RED before either production file existed: exit 1, 0 passing / 1 load
   failure. The compiler reported the two exact missing production files and
   their missing API names. This was the expected absent-feature RED; it was
   a load/compile failure rather than an assertion failure.
2. Initial implementation GREEN: exit 0, 33/33 passing.
3. Expanded coverage and busy-state regression attempt: exit 1, 36 passing / 2
   failing. One replacement-busy assertion had accidentally been placed in the
   non-pending stale-action test. That test placement was corrected before
   production was changed; the cancel-busy failure was already valid.
4. Corrected busy-state RED, still before the production fix: exit 1, 36 passing
   / 2 failing. `refinement serializes and old completion cannot change
   replacement` and `late undo after cancel, failed refinement and dispose
   never mutate draft` both reported `Expected: true, Actual: false` for
   `editBusy` while the physical worker remained pending.
5. Final focused GREEN after the busy-state fix: exit 0, 38/38 passing.

The busy-state behavior was clarified with the parent/controller before its
fix. No other functional changes followed final focused GREEN.

Formatter mutation commands (only the three scoped new Dart files):

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format lib/features/room_studio/domain/room_mask_state.dart lib/features/room_studio/application/room_mask_controller.dart test/features/room_studio/application/room_mask_controller_test.dart
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format test/features/room_studio/application/room_mask_controller_test.dart
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format lib/features/room_studio/application/room_mask_controller.dart test/features/room_studio/application/room_mask_controller_test.dart
```

All exited 0. The last formatted 2 files with 0 changes.

Scoped Room analyzer:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics analyze lib/features/room_studio test/features/room_studio
```

Initial run exited 0 with 3 curly-brace style infos in the new controller;
those were fixed. Final run exited 0: `No issues found!`.

Final global format check:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test tool
```

Exit 0: `Formatted 179 files (0 changed)`.

Exactly one final full-suite run, after all functional changes:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
```

Exit 0: `00:20 +739: All tests passed!`. Baseline was 701; Task 7 adds 38.
No compiler-barrier failure or native compilation attempt was reported.

## Race, retention, and independence evidence

The 38 focused tests use fresh real Riverpod containers, the real shared
`PhotoAcquisitionController`, immutable `PreparedPhoto`/`MaskBitmap` objects,
delayed picker/store boundaries, delayed segmentation replies, and delayed
refinement that runs the actual pure stroke/undo functions.

- Old A success and old A error both leave equal-sized committed B unchanged.
- Hidden/cancelled during recovery or intent save prevents native launch.
- Hidden late receipt is not cleared/claimed until an explicit active Continue.
- Hidden mid-claim stages pixels without invoking segmentation.
- Cancelled/disposed/superseded mid-claim keeps the same pending receipt.
- Cancelled/disposed/superseded while native pick is pending keeps its late
  receipt. Disposed pending inference does not populate a new controller.
- Pick cancellation, permission failure, failed claim storage, failed inference,
  and logical cancellation retain the exact previous committed draft.
- Wrong result photo identity or dimensions is rejected as invalid output.
- Captured stale photo/revision, wrong layer/tool, busy, hidden-overlay, and
  invalid-phase edits/undo/restore are rejected without changing the draft.
- Delayed stroke/undo results cannot mutate a replacement or cancelled draft.
  Tool/layer/overlay changes invalidate in-flight edits even if toggled back.
- Undo restores prior ownership exactly. Restore preserves original AI map
  identity, clears history/dirty state, and increments revision.
- Twenty-command eviction: after 21 edits and 20 undos, history is empty but
  the remaining changed pixel still makes `hasEdits=true`.
- Sixteen-MiB eviction: real 1600×1600 full-frame strokes produce 12,800,000-byte
  deltas. The second evicts the first; undoing the retained delta leaves no undo
  history but all 2,560,000 pixels still differ from AI and `hasEdits=true`.
- Erasing back to AI yields `hasEdits=false` despite two retained undo entries.
  A no-op stroke preserves the exact draft, revision, and history.
- Closing all subscriptions, changing layer, changing Room color, matching
  hue/HSL state, mixer ingredients, formula target, harmony base, real theme
  preference, history entries, and saved palettes leaves the draft untouched.
  History/theme/palette providers use existing in-memory repository boundaries;
  actual provider mutations are exercised. Invalidating injected service/ID
  providers also leaves the retained draft untouched. A fresh container starts
  with no Room draft.

## Self-review and limits

Reviewed every async request/claim/analyze/refine success, failure, disposal,
supersession, and busy-release path. Self-review found and fixed the physical
worker busy-state mismatch with fresh failing assertions. Style findings were
resolved. No remaining correctness concern is known; independent review is
owned by the parent/controller.

Task 7 does not implement Room UI, confirmation dialogs, or disk persistence of
photos/masks/edits. UI must call Restore only after confirmation and explicitly
continue staged candidates. Controller tests use controlled segmentation
results; Task 5 owns the reviewed real-model pipeline and Task 6 owns real
compute-worker evidence. This host test run is not phone compatibility proof.
No APK/native app build, install, clean, data clearing, `dart run`, dependency
fetch, config change, cache deletion, SDK/pub-cache patch, worktree, or commit
was performed. Existing 24/32-MiB budgets, 24M/16384/1600 photo limits, four
exclusive layers, Android 24/iOS 13 targets, old APK/ZIPs, and hook cache remain
unchanged.
