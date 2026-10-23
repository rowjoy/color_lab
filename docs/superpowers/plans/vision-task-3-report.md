# Task 3 — Vision activity UI and app integration

Date: 2026-10-21. Scope: Task 3 only. Status: implemented and verified.

## Files

- Added `lib/features/color_test/presentation/vision_screen.dart`.
- Added `test/features/color_test/presentation/vision_integration_test.dart`.
- Updated `lib/features/lab/presentation/lab_screen.dart` with the `open-vision` entry after matching, and replaced obsolete coming-soon copy.
- Updated `lib/routing/app_router.dart` with the guarded root `/vision` route.
- Added this report.

No Task 1/2 files, matching implementation, renderer, README, dependencies,
assets, native code, storage schema, existing archives or APK were edited.
No Git operation, APK/native build, installation, network feature or timer was
used. SDK-cache access for Flutter/Dart commands used the required escalation.

## Result

The real app opens an explicit introduction from Lab. Starting presents the
actual cached procedural painter and six one-digit responses. Zero is valid;
empty Record answer shows validation; Not sure explicitly records null. The
controller retains responses and the pending digit across Back/reentry and
theme changes. Text synchronization changes the controller value only when the
text differs, preserving the selection during ordinary rebuilds.

Record answer and Not sure capture their plate ID and draft in the displayed
build. They check the current active plate before validation or side effects,
and only clear/unfocus after an accepted response. A retained text-edit callback
also checks the active plate ID before writing a draft. Thus callbacks from an
older plate cannot answer or erase/write the following plate's pending digit.

The owned/disposed scroll controller resets on start, plate advance, completion
or replacement set. It resets immediately and after layout so a long former
page cannot strand the destination offscreen. Typing and theme changes retain
the viewport. Back pops when possible, otherwise returns to Lab.

Results show all six frozen Generated number / Your response pairs, a neutral
pattern-match count and Not sure count. No live answer, answer-coded image
semantics, correctness phase, health category or color-coded health signal is
shown. The exact required caveat appears in every stage; the eye-care
professional sentence appears in introduction and results. Restart uses the
shared token-sized buttons and reduced-motion root dialog. Cancel/system Back
preserve the draft. Confirm and explicit Try again create an active replacement
set without affecting saved data or other Lab drafts.

## Tests and observed RED/GREEN

Tests use the full `ColorLabApp`, actual router, real VisionSession/controller
and VisionPlateView. The injected six-plate generator makes expected numbers,
seeds and counts deterministic. Only existing in-memory repository boundaries
replace disk/plugin storage. The new pixel check captures the actual app's
render boundary and crops its plate canvas; it does not replace the painter.

1. Before product edits, the first real Lab-entry test ran with
   `flutter test test/features/color_test/presentation/vision_integration_test.dart --reporter expanded`.
   Exit **1**: `Lab opens vision introduction and requires explicit start`
   expected one `open-vision` widget and found none. This was behavioral RED,
   not a missing-import/compilation failure.
2. The remaining integration cases were authored before UI implementation,
   while real domain/painter files were pending. Their first executable runtime
   run followed those files landing. This is the exact ordering; no claim is
   made that every individual case separately ran RED before UI code.
3. First executable batch: **11 passed, 1 failed**, exit **1**. Failing test:
   `stale Record and Not sure reject without clearing next draft or keyboard`.
   Calling a captured previous field's `onChanged('9')` mutated the next draft,
   violating the same-instance retained-session assertion. Added the active /
   current-plate ID guard to the text-edit path. No controller/painter changes.
4. Rerun: **12/12 passed**, exit **0**. UI API-ready message sent to root.
5. Added actual app raster/theme/advance verification and root Back fallback.
   One test-authoring run exited **1** at compilation because `blankRecord`
   was initially declared in the neighboring test. Moved it into the stale
   callback test. This was a harness error, not feature RED.
6. Next run reached the new raster test and stalled because engine image
   readback was awaited inside widget-test fake async. Cancelled that run;
   Flutter reported shutdown `Cannot close sink while adding stream` /
   `Cannot add event while adding stream`, and the tool returned exit **0**.
   This cancellation is **not** a passing run. Wrapped actual image readback in
   `tester.runAsync`, with image disposal in `finally`.
7. Final focused run: **14/14 passed**, exit **0**, including the real plate
   pixels changing after a response and remaining identical across themes.
8. Added explicit >=48dp dialog-button measurements before final formatting;
   these assertions also passed in the subsequent full suite.

Final coverage catches missing Lab/guard/start behavior; live visual/semantic
answer leaks; blank becoming zero; invalid/multiple-digit typing; null becoming
zero; stale Record, blank Record, Not sure and edit callbacks; unwanted keyboard
dismissal on rejected stale calls; forgotten dismissal on acceptance; stale
plate raster after advancing; theme-dependent actual plate RGB; lost draft or
selection across theme; lost draft/session on Back/reentry; changes to matching,
mixer, formula, harmonies, Lab HSL, history or saved palettes; mistaken result
counts/pairs; missing restart cancellation/system Back; automatic replay;
offscreen new plate/results/replay entry; typing/theme viewport resets; root
Back fallback; and 360px/2x text/both themes/reduced-motion/modal/control sizing.

## Final command results

| Command | Result |
| --- | --- |
| `flutter test test/features/color_test/presentation/vision_integration_test.dart --reporter expanded` | 14 passed, exit 0 |
| `dart format lib/features/color_test/presentation/vision_screen.dart lib/features/lab/presentation/lab_screen.dart lib/routing/app_router.dart test/features/color_test/presentation/vision_integration_test.dart` | 4 files, 3 formatted, exit 0 |
| `flutter analyze lib/features/color_test/presentation/vision_screen.dart lib/features/lab/presentation/lab_screen.dart lib/routing/app_router.dart test/features/color_test/presentation/vision_integration_test.dart` | No issues, exit 0 |
| `flutter test --reporter expanded` | **569 passed**, exit **0**, ~19 seconds |
| `dart format --output=none --set-exit-if-changed` (same four files) | 0 changed, exit 0 |

The full suite was run once for this task, after the final source/coverage
changes. It had **no sibling failures or transients**. Earlier focused failures
and the cancelled raster run are named above. Sibling agents separately saw
earlier concurrent versions; their reports own those runs.

Compared the Lab and router files against
`/private/tmp/color-lab-vision-baseline.ndglOZ`: the diff contains only the new
entry/copy and route/import. Both `diff` commands exit 1 because those intended
differences exist; this is not a failed verification command.

## Self-review and limits

Reviewed all task requirements against the implementation and test assertions.
No unresolved UI issue was found. Callback guards precede local effects, fields
do not publish obsolete values from old plate callbacks, image semantics remain
generic, summaries cannot appear until six accepted responses, and lifecycle
resources are disposed. The actual pixel integration assertion excludes page
chrome by comparing a central plate crop, so the counter/theme cannot satisfy
the expected raster difference by themselves.

These are Flutter widget/raster and analyzer results, not native-device or
clinical validation. Root owns real-font preview inspection, independent/final
review, documentation and source-only archive delivery. No APK was built.
