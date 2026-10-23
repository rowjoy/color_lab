# Color Matching Task 1 report

Task 1 API is implemented. Focused tests pass (28), scoped analysis is clean,
and the seven owned Dart files are formatted. The full suite was run once while
sibling presentation work was still in progress and is **not green**: 510 passed,
12 failed, all in the sibling matching integration test file listed below.

## Owned files

- Added `lib/core/color/color_matching.dart`.
- Added the matching export to `lib/core/color/color_engine.dart`; comparison
  against `/private/tmp/color-lab-matching-baseline.eVdpa3` confirms this is its
  only change.
- Added `lib/features/color_test/domain/matching_game.dart`.
- Added `lib/features/color_test/application/matching_game_controller.dart`.
- Added `test/core/color/color_matching_test.dart`.
- Added `test/features/color_test/domain/matching_game_test.dart`.
- Added `test/features/color_test/application/matching_game_controller_test.dart`.
- Added this report; no other documentation, UI, renderer, route, Lab, package,
  native, storage or archive edits were made by this task. No Git initialization
  or commits, and no subagents.

## RED evidence

All three test files were written before the matching implementation or export.
Command:

```text
flutter test test/core/color/color_matching_test.dart test/features/color_test/domain/matching_game_test.dart test/features/color_test/application/matching_game_controller_test.dart --reporter expanded
```

Actual output excerpts, before production files existed:

```text
test/core/color/color_matching_test.dart:13:16: Error: Method not found: 'matchingScore'.
test/core/color/color_matching_test.dart:28:23: Error: Method not found: 'generateMatchingTargets'.
00:00 +0 -1: loading /Users/jamirulislam/Movies/dart_jpo/color_lab/test/core/color/color_matching_test.dart [E]
00:00 +0 -3: Some tests failed.
```

The domain/controller imports also failed because their required source files
did not yet exist. This was a missing-API **compilation RED**, permitted by the
task brief, not an assertion RED. Raw output is preserved at
`/private/tmp/color-lab-matching-task1-red.log`. The original shell wrapper ended
with `tail`, so its process exit was 0; Flutter's exit code was not preserved in
that first wrapper. The recorded `+0 -3` failure output is the RED evidence.

## GREEN and static verification

The same focused command after implementation exited 0. Exact final line:

```text
00:00 +28: All tests passed!
```

Raw output: `/private/tmp/color-lab-matching-task1-green.log`.

Scoped command, exit 0:

```text
flutter analyze lib/core/color/color_matching.dart lib/core/color/color_engine.dart lib/features/color_test/domain/matching_game.dart lib/features/color_test/application/matching_game_controller.dart test/core/color/color_matching_test.dart test/features/color_test/domain/matching_game_test.dart test/features/color_test/application/matching_game_controller_test.dart
Analyzing 7 items...
No issues found! (ran in 1.0s)
```

Raw output: `/private/tmp/color-lab-matching-task1-analyze.log`.

Formatting was applied only to the seven owned Dart files. Final formatting
verification exited 0:

```text
dart format --output=none --set-exit-if-changed lib/core/color/color_matching.dart lib/core/color/color_engine.dart lib/features/color_test/domain/matching_game.dart lib/features/color_test/application/matching_game_controller.dart test/core/color/color_matching_test.dart test/features/color_test/domain/matching_game_test.dart test/features/color_test/application/matching_game_controller_test.dart
Formatted 7 files (0 changed) in 0.01 seconds.
```

## Full-suite result and every observed failure

Command `flutter test --reporter expanded`, exit **1**. Exact final output:

```text
00:19 +510 -12: Some tests failed.
```

Raw output: `/private/tmp/color-lab-matching-task1-full-suite.log`. No Task 1 or
legacy test failure appeared. All 12 failing tests were in
`test/features/color_test/presentation/matching_integration_test.dart`:

1. `Lab opens the retained color matching game`
2. `editing hides both HEX values and their accessible detail actions`
3. `grey submission scores actual display RGB and freezes one attempt`
4. `sliders retain neutral hue then score green against red with literal error`
5. `a rounded score of100 does not claim an exact RGB match`
6. `feedback details save the exact Lab target and Room receives the guess`
7. `five frozen pairs finish with total average and explicit replay`
8. `restart cancel and system Back retain draft; confirm replaces game`
9. `Back reentry theme and completion preserve game and independent drafts`
10. `history load failure does not block play or results`
11. `matching states fit360px2x reduced-motion light`
12. `matching states fit360px2x reduced-motion dark`

The first failed with the exact diagnostic:

```text
Expected: exactly one matching candidate
  Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'open-matching'>]: []>
```

The remaining failures reported `Bad state: No element` while looking up the
not-yet-available matching screen widgets. Root was notified with the log and
names. Sibling files were not changed to conceal or resolve these failures.
The parent task must rerun cumulative verification after completing UI/routing.

## Behavior and self-review

The TDD and writing-good-tests instructions informed the test design: real
domain/controller objects, literal scores, independently supplied CIE76 fixtures,
literal constant-random target colors, and meaningful phase/isolation assertions.
No public testing hooks or replacement sibling types were introduced.

- Scoring rejects negative/nonfinite input and rounds clamped `100 - deltaE`.
  Literal checks cover 0, .49, .51, 20, 100 and 150. Actual RGB fixtures cover
  red/green delta-E 170.565242, black/white 100, exact red, and nonidentical
  red `(254, 0, 0)` whose score rounds to 100 while `isExact` remains false.
- Targets use one random hue offset, five 72-degree bins, less-than-36-degree
  jitter, saturation .35–.90, lightness .25–.75, existing HSL conversion, and
  shuffle with the same random source. Generation uses bounded work; zero and
  upper-bound constant streams terminate within 20 random calls, and 100 seeded
  games satisfy display HSL bounds/uniqueness/separation. Returned lists reject
  mutation. Quantization tolerance is explicit in display-HSL tests.
- The domain snapshots a single-use target iterable once, validates five unique
  RGBs, and keeps all public state final. Target and attempt lists reject mutation.
  Frozen snapshots remain unchanged after edits, advancing and restart.
- Raw HSL is retained separately from display RGB; hue 240 survives saturation
  zero and lightness zero/one and restores literal blue `#0000FF`. Initial and
  next-round coordinates produce `#808080` independently of target colors.
- Submit creates exactly one actual display-RGB attempt and does not advance.
  Valid frozen-phase edits, submit and invalid-phase advance return identical
  states. Invalid slider values still throw in all phases. Round-five feedback
  advances to complete with the fifth guess retained; literal five-round scores
  yield total 300 and average 60, including a four-round average of 75.
- The retained NotifierProvider reads the generator once when built, survives
  listener removal, and keeps containers independent. Updating the generator
  cannot reset the active game; explicit restart reads it afresh. Invalid targets
  and generator errors preserve the prior state. Restart is verified to retain
  Mixer, harmony, formula, Room and history-filter selections.
- Mutation review: wrong score direction/clamping/rounding, collapsed target bins,
  RGB-derived neutral coordinates, omitted validation, duplicate submit, premature
  advance, early completion, mutable snapshots, watched generator resets, and
  failed restart publication each have observable tests that would fail.

Task 1 introduces no persistence, network, async operations, timer, account,
dependency, native change, or platform-specific behavior. Saved history/palette
repository mutation is absent by construction; this focused provider test does
not itself execute durable history/palette storage. Target concealment, common
details, accessibility/layout, APK, device/iOS, native checks and visual previews
belong to the parent/sibling work and are not claimed by this report.
