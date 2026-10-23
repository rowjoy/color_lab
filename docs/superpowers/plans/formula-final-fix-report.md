# Formula final review fix wave report

Completed 2026-10-21 against `formula-final-fix-brief.md`. Both final-review findings are addressed within the authorized three-file scope. No Git operations, subagents, packages, camera production changes, native/storage changes, or unrelated refactors were made. The root agent retains final re-review, APK build, and ZIP delivery.

## Important finding: camera workflow lifetime

Root cause confirmed by tracing `CameraPickerScreen._showDetails`: it stops sampling, awaits shared `showColorDetails`, and resumes in `finally` only when the camera route is current. Shared details previously pushed Formula without awaiting its lifetime. In the real router regression this completed the workflow early enough to create a replacement camera behind Formula.

The only production change is `await context.push<void>('/formula')` in `lib/features/picker/presentation/color_explorer.dart`. Shared details now remains awaited until Formula returns. The existing same-Formula-route guard, selected target assignment, harmony behavior, and Room routing remain intact.

The new test `camera stays paused through formula and samples afresh after Back` uses `ColorLabApp`, the real app router, Capture's actual Open camera action, `CameraPickerScreen`, shared `ColorDetails`, and Formula. The harness injects the existing `FakeCameraSession` from `camera_screen_test.dart` at `cameraSessionFactoryProvider`; native camera hardware is never initialized. A red sample (#FF0000) becomes actual detail RGB and Formula's visible target. The test verifies one stopped session throughout Formula with no replacement/restart, then Back disposes the original and creates/starts a fresh session. A different blue sample (#0000FF) from that replacement is visible in the returned camera UI. This tests the camera workflow's observable resource contract and rendered color, not a synthetic details host.

### Behavioral RED before production change

Command:

```sh
flutter test test/features/formula/presentation/formula_integration_test.dart --plain-name 'camera stays paused through formula and samples afresh after Back' --reporter expanded
```

Exit 1. Exact relevant output:

```text
Expected: an object with length of <1>
  Actual: [Instance of 'FakeCameraSession', Instance of 'FakeCameraSession']
   Which: has length of <2>
No camera restarts behind Formula
00:00 +0 -1: Some tests failed.
```

Log: `/private/tmp/color-lab-formula-final-camera-red.log`. This was a behavioral failure from the real camera → details → Formula workflow, before editing the push.

### GREEN after minimal fix

The same command exited 0 after awaiting the typed push:

```text
00:00 +1: All tests passed!
```

Log: `/private/tmp/color-lab-formula-final-camera-green.log`.

## Minor finding: already-successful output during loading/refresh

Added two tests using the existing controlled service, actual keyed providers, picker, recipe domain, Formula screen, and save controls. They preserve the original pending-request late-error test and every existing fixture.

- `new target hides a successful result recipe and save until it completes`: first completes and displays the real #777777 50/50 black-white recipe, then selects #FF0000 through the actual picker. While its request remains pending, the result swatch, recipe heading, recipe palette, Save color, and Blend details are absent. Completing a valid red 100% recipe restores #FF0000, the recipe, and Save color.
- `refreshing a successful key hides its result recipe and save until recovery`: first displays the #777777 recipe, then invalidates the successful current target's provider key without changing the target. While the second request remains pending, the same result/recipe/save output is absent. Completing a valid white 100% recipe restores #FFFFFF and its recipe/save controls while retaining the target.

Both coverage additions passed without any Formula presentation/provider changes, as anticipated by the brief. They guard the existing suppression behavior, including Riverpod refreshes that retain previous data. Literal displayed colors and percentages are independently known fixtures; no recipe widgets or production services were stubbed into source.

## Verification

Formula integration command:

```sh
flutter test test/features/formula/presentation/formula_integration_test.dart --reporter expanded
```

Exit 0; `00:02 +13: All tests passed!`. Log: `/private/tmp/color-lab-formula-final-integration.log`.

Scoped Formula + camera/detail regression command, run after formatting:

```sh
flutter test test/core/color/color_formula_test.dart test/features/formula test/features/picker/camera_screen_test.dart test/features/picker/camera_backend/camera_session_test.dart test/features/picker/color_details_actions_test.dart --reporter expanded
```

Exit 0; `00:03 +82: All tests passed!`. Log: `/private/tmp/color-lab-formula-final-scoped-tests.log`.

Scoped analysis:

```sh
flutter analyze lib/features/picker/presentation/color_explorer.dart test/features/formula/presentation/formula_integration_test.dart
```

Exit 0; `No issues found! (ran in 1.4s)`. Log: `/private/tmp/color-lab-formula-final-analysis.log`.

Scoped format check:

```sh
dart format --output=none --set-exit-if-changed lib/features/picker/presentation/color_explorer.dart test/features/formula/presentation/formula_integration_test.dart
```

Exit 0; `Formatted 2 files (0 changed) in 0.02 seconds.` Log: `/private/tmp/color-lab-formula-final-format.log`.

One complete suite:

```sh
flutter test --reporter expanded
```

Exit 0; `00:10 +387: All tests passed!`. Log: `/private/tmp/color-lab-formula-final-full-tests.log`. All 387 tests passed, up from the supplied 384-test baseline by these three regressions. No full-suite failures, load failures, or framework exceptions occurred.

## Tooling attempts and remaining limits

The first sandboxed Flutter test invocation exited 1 before loading tests because the SDK wrapper could not write `/Users/jamirulislam/Applications/flutter/bin/cache/engine.stamp`. Re-running with approved SDK-cache access produced the meaningful RED above. The sandboxed `dart format` wrapper hit the same cache permission. A direct SDK formatter did format the test file but exited 1 afterward because telemetry could not update `/Users/jamirulislam/.dart-tool/dart-flutter-telemetry-session.json`. The subsequent approved format check exited 0 with zero changes. These were tooling permission failures, not omitted test failures; no automatic approval rejection occurred.

The tests replace only external camera hardware and expensive worker boundaries; the actual isolate service and camera backend remain covered by the scoped/full suites. No device/native camera execution or new APK/ZIP is claimed by this fix wave. No unresolved implementation concern was found; root should rebuild the previously pre-fix debug APK and package only after its final re-review.
