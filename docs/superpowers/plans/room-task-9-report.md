# Task 9 — Room entry and mask editor integration

Status: DONE. No commits created. Final focused gate: 21/21 passing.
Exactly one final cumulative suite: 779/779 passing (758 baseline + 21).

## Files changed

- `lib/features/room_studio/presentation/room_mask_screen.dart` (new)
- `lib/features/room_studio/presentation/room_mask_dialogs.dart` (new)
- `lib/features/room_studio/presentation/room_screen.dart`
- `lib/routing/app_router.dart`
- `test/features/room_studio/presentation/room_masks_integration_test.dart` (new)
- This report.

Read-only `diff -rq` comparisons of `lib` and `test` against
`/private/tmp/color-lab-task9-base.VRJCWA/source` reported exactly the five Dart
files above. The controller, acquisition producer/store, viewport, segmentation,
refinement, core, other features, dependencies, native targets and build settings
were not edited. The tests reuse the existing in-memory acquisition intent store;
their delayed store subclasses that boundary solely to delay durable clearing.

## Behavior and Task 10 integration contract

`RoomMaskScreen` is a root `/room/masks` route behind the existing preferences /
onboarding redirect. `Prepare room masks` (`open-room-masks`) opens it from Room.
The Room heading is compact and its explanatory description follows the CTA so
the action remains visible at 360dp with doubled text. The explicitly labeled
illustration and existing color actions remain intact. The lower Room card now
accurately distinguishes masks from deferred photo recoloring/export.

The editor uses `StudioPage(name: 'RoomMasks')`, giving `screen-RoomMasks`, and
the title `Room masks`. Back pops or goes to `/room` without resetting retained
state. Explicit gallery/camera imports use the shared acquisition owner and
`PhotoSource.gallery` / `PhotoSource.camera`; the live color sampler is never
opened. The screen checks mounted state, resumed lifecycle, current modal route,
and `GoRouter.state.uri.path` when asynchronous acquisition claims are accepted.
Recovery is started by the existing onboarding-aware recovery scope even for a
direct root entry. Unknown recovered destinations offer explicit Room/Capture
choices; merely rendering the editor does not claim a receipt. Hidden mid-claim
candidates expose `Analyze this photo` for explicit continuation.

Analysis has truthful text and cancellation, without invented progress or
confidence. Failed analysis has safe recovery copy and no editable failed
candidate. A preserved draft is available through `Return to previous masks`.
Valid empty results enable manual editing and explain that no supported surfaces
were found. All four layer chips show current coverage or `Not detected`.
Move/Add/Erase, brush .01–.20, Show original, Undo, Restore and replacement controls
consume the existing retained controller. Persistent uncertainty copy is present.

The actual `RoomMaskViewport` has key `room-mask-viewport` and a finite 300dp
height. A keyed offstage editor keeps its old viewport alive while acquiring,
analyzing or displaying an error. Ordinary revisions/layer/theme changes preserve
the view. Its enclosing key changes only for a committed photo ID or the local
accepted-Restore counter. Stroke closures capture that build's photo ID and
revision; the controller validates those with the stroke's layer and tool.

Public dialog helpers are exactly `Future<bool> confirmRestoreAiMasks(BuildContext
context)` and `Future<bool> confirmReplaceRoomPhoto(BuildContext context)`.
They use the root navigator, shared colors/radii/motion, scrollable content and
48dp actions. Cancel and system Back return false; helpers do not mutate state.
The screen rechecks current route and captured photo/revision after acceptance.
Restore resets the view only after the controller accepts the mutation.

Task 10 can navigate through the real Room entry or directly to `/room/masks`.
Stable action keys: `room-mask-gallery`, `room-mask-camera`,
`room-mask-continue-import`, `room-mask-continue-analysis`, `room-mask-undo`,
`room-mask-restore`, `confirm-room-mask-restore`, `confirm-room-mask-replace`.
Additional control keys: `room-mask-layer-{wall,ceiling,floor,furniture}`,
`room-mask-tool-{move,add,erase}`, `room-mask-brush`, `room-mask-show-original`.
No production preview/test hook was added. Task 10 should keep using real
recorded model output for AI preview artifacts; this task's known-pixel fixtures
are synthetic UI evidence only.

## TDD and focused results

All commands ran from `/Users/jamirulislam/Movies/dart_jpo/color_lab`.
Every Flutter command retained the native compiler denial profile. The focused
command, including the first behavioral RED and final GREEN, was:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_masks_integration_test.dart --reporter expanded
```

Chronology (no interrupted run was counted as passing):

1. Outer sandbox attempt exited71, `sandbox_apply: Operation not permitted`.
   Flutter did not run. Subsequent commands used approved outer escalation while
   retaining the inner barrier. A test import omission then caused an exit1 load
   failure (`colorNamerProvider` undefined); corrected before behavioral RED.
2. Before any production edit, the actual app/Room entry test exited1, `+0 -1`:
   `Found 0 widgets with key [<'open-room-masks'>]`. This was the required genuine
   missing-CTA behavioral RED.
3. The expanded pre-implementation test file had Dart imports accidentally placed
   after declarations, producing an exit1 load failure. Corrected the harness.
   The first production compile then found a non-const `Semantics` incorrectly
   marked const, also exit1/load failure; corrected it. Neither is claimed as a
   behavior RED.
4. First running implementation: exit1, 11 passed / 4 failed. System Back test had
   mistakenly tapped an offscreen Back button; replaced it with
   `binding.handlePopRoute`. A route-transition test needed bounded pumps past
   its exit animation. Both narrow-theme entry tests exposed the real layout
   defect. Subsequent run: exit1, 13 passed / 2 narrow-layout failures.
5. A targeted narrow run exited1, `+0 -1`, measuring entry y528–684 while the Room
   viewport ended at588. Moving explanatory description below the CTA fixed the
   remaining visibility defect. The full focused file then exited0, 15/15.
6. Added five integration cases. Run exited1, 19 passed / 1 failed: zoom fixture
   expected a pixel outside the default .05 brush's quarter-pixel radius. Set
   the actual brush slider to .10 so the hand-derived zoomed pixel is covered.
   Targeted transform run exited0, 1/1; no production change was required.
7. Added stale viewport-callback coverage and replacement system-Back coverage.
   Final focused run exited0: `00:04 +21: All tests passed!`, no warnings/errors.

The targeted diagnostic commands used the same full guarded command, inserting
`--plain-name '360dp doubled text light keeps new-photo entry and dialogs usable'`
or `--plain-name 'zoom survives revisions layer theme and failed replacement; only
accepted restore or new photo resets it'` before `--reporter expanded`.

## Actual coverage

The 21 tests use the real app/router, acquisition controller, Room controller,
refinement compute adapter and viewport. Only photo acquisition/segmentation and
disk repositories are replaced at their boundaries. Analysis replies and native
picker/receipt-clear timing are explicitly delayed; refinement is awaited using
a bounded busy-state condition, not an assumed fixed completion delay.

- Visible Room entry and initially visible gallery/camera actions; both sources
  invoke analysis before any manual editor is available. No live camera session.
- Runtime failure stays noneditable; explicit retry of a valid all-empty AI
  result enables manual masks with the specified empty-result explanation.
- On a 10×10 all-Floor map, real Add at(.55,.55) changes only index55 to Wall.
  Erasing that pixel with Floor selected changes nothing. Undo restores all100
  Floor labels exactly. Original-only leaves the draft unchanged and uses Move.
- Restore Cancel/system Back preserve edits; accepted Restore restores the
  exact empty AI map, increments revision and clears history. Stale revision
  confirmations cannot restore or launch replacement. Accepted root-dialog
  results arriving while `/welcome` is current do neither.
- Cancelled picker, cancelled replacement dialog/system Back, permission error,
  and inference failure preserve the previous draft. Failure hides editing until
  explicit Return. Successful replacement has new identity/revision0 and empty
  history. Cancel analysis ignores the old operation's late successful result.
- Real pinch doubles zoom. Brush hits map to indices53/56 across mask revisions,
  layer changes, theme writes and failed replacement/Return; Restore and new
  photo reset the same hit to index52. A cancelled replacement also preserves
  the transformed mapping. Captured old viewport callbacks cannot edit a newer
  revision or an equal-sized replacement at the same revision0.
- Native output arriving while an imperatively pushed `/welcome` owns the root
  route stays pending, starts no AI and never navigates. Explicit Continue claims
  it later. Hidden durable claim stages a candidate without analysis until the
  user chooses Analyze. Unknown recovered receipt offers both destinations and
  Capture navigation retains the receipt for that screen's explicit continuation.
- Direct root navigation obeys onboarding with zero picker/recovery/inference
  work before completion. Back without a stack goes to Room; reopening retains
  the same draft. Existing Use in Room updates the illustrated color to the
  edited Lab shade while retaining Lab state, exact Room draft and saved history.
- Light and dark at360dp,2× text, reduced motion: entry and both new-photo actions
  are hit-testable without `ensureVisible`; layer/tool/original/undo/restore and
  dialog action heights are at least48dp. Both dialogs are usable and there are
  no layout/framework exceptions. Semantics handles are disposed inline.

## Final gates

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics analyze lib/features/room_studio/presentation/room_mask_screen.dart lib/features/room_studio/presentation/room_mask_dialogs.dart lib/features/room_studio/presentation/room_screen.dart lib/routing/app_router.dart test/features/room_studio/presentation/room_masks_integration_test.dart
```

Exit0: `No issues found!`. Earlier scoped analysis found one unused test import
and one braces-style info; both were corrected before the final gate.

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test tool
```

Exit0: `Formatted 186 files (0 changed)`. Formatting mutations were restricted to
the five owned Dart files. The first formatter attempt exited65 on the misplaced
test imports; subsequent scoped formatting exited0.

Exactly one final full suite, after final focused GREEN and all code changes:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
```

Exit0: `00:23 +779: All tests passed!`. No interrupted suite or unfinished sibling
failure. The final output showed no failing/skipped tests. The tool truncated a
large intermediate output chunk; the final completion and total were inspected.

## Self-review and limits

Reviewed route/lifecycle checks, retained offstage identity, captured dialog /
stroke snapshots, explicit recovery choices, safe failure/empty distinction,
shared tokens, narrow layout, and unchanged illustration/color behavior.
No outstanding correctness concern was identified. The screen remains one
focused stateful view (365 lines); dialogs are a separate pure boolean boundary.

This is host UI/gesture evidence, not native phone execution or model accuracy
evidence; the actual AI execution gate remains Tasks1/5. No native/APK build,
install, clean, data clear, cache deletion, SDK/pub-cache patch, `dart run`,
dependency fetch, Git initialization/worktree/commit or agent delegation was
performed. The guarded Flutter runs did not report a native compiler attempt.
Existing APK/ZIP artifacts were not modified. Android24/iOS13 targets, image
1600/24Mpixel/16384 bounds,24/32MiB budgets, four exclusive masks, default brush,
20-command/16MiB undo limits, and all frozen producer APIs remain unchanged.
