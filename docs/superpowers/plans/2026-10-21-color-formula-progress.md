# SDD ledger — plan: docs/superpowers/plans/2026-10-21-color-formula.md

Scope: approximate Color Formula only, continuing the user's established “Next” module workflow. New subsystem gets a written design/plan; original instructions authorize immediate implementation without repeated design approval prompts. No Git repository exists, so work remains in the user-authorized project and all prior ZIPs are preserved. Baseline snapshot: `/private/tmp/color-lab-formula-baseline.WrYORg` from the previous Mixer source ZIP. Durable briefs/reports are retained here rather than in Git-only disposable workspace.

Execution uses subagent-driven-development with disjoint math/service tasks and root UI integration, following active proactive-parallel collaboration instructions. No overlapping write ownership. All exact interfaces are fixed in the plan before dispatch.

| Task/interface pair | Preflight check |
| --- | --- |
| 1/2 | Exact immutable ColorFormula and findColorFormula API; worker consumes pure core through existing export, no stubs |
| 1/3 | UI consumes derived displayed result/error and valid positive parts; same scoring/caveat as spec |
| 2/3 | Target notifier + autoDispose family API, retry invalidation and old-result isolation defined consistently |
| 1 |5% exhaustive positive pairs/triples plus endpoints covers original zero-inclusive grid; independent numeric and global minimum tests |
| 2 | Actual isolate service and controlled async provider tests; no global cache or persistence conflict |
| 3 | Existing details/Room/harmony behavior preserved, nonstacking formula entry, real shared picker and current sourceLab reuse |

Task 1: complete (independent formula_math_review: spec compliant, quality approved, no findings).29 focused tests, clean scoped analysis/format, independent fixtures/oracle and local timing recorded in formula-task-1-report.md.
Task 2: complete (independent formula_async_review: spec compliant, quality approved, no findings).11 focused tests, actual VM compute and a synchronous-regression mutation RED, clean scoped analysis/format recorded in formula-task-2-report.md.
Task 3: complete (UI spec/quality approved; one consolidated final fix wave addressed both findings; scoped re-review approved; full checks, APK, previews and cumulative source archive verified).

Design/plan self-review: no placeholders or internal interface conflicts. Displayed-result CIE76 ranking explicitly resolves rounding/gamut ambiguity; digital base HEX values and enumeration order are fixed and visible. The selected target is session-only; results recompute as needed. No external API, new dependency or native/storage change.

## Verification and review

Baseline:334 tests passed before changes. Earlier delegate full-suite runs each passed374 loaded tests with one test-first missing-FormulaScreen load failure; no sibling files were changed to conceal it. Root integrated the screen and ran the whole suite:384 tests passed, exit0 (`/private/tmp/color-lab-formula-final-tests.log`). Counts:334 prior +29 math +11 isolate/providers +10 UI. Reduced-motion expansion test initially failed (expected zero-duration style, actual null), then passed in this full run after using AppMotion.sheetAnimation.

First whole-project analysis found one test-only curly_braces_in_flow_control_structures info at line94. Root traced it to the new helper's unbraced if, added braces and reran `flutter analyze`: no issues, exit0. Initial format check:106 Dart files,0 changes. Final post-polish reruns are recorded below.

UI task reviewer confirms recipe/error and selected-target correctness, explicit loading/refresh suppression, mounted/cancel picker safety, exact selected detail entry without formula stacking, selected-result Lab-source save/details/Room, shared tokens/48dp controls/guards and reduced motion.

Task 3: minor (carried to final review, then addressed in the consolidated fix wave): the original stale-target widget test started with the initial request pending; two added tests now explicitly suppress a previously successful result/recipe/save during new-target loading and same-key refresh, then verify recovery. No Formula UI/provider production changes were needed for this coverage.

Root visual check at360px/2x found the long word “Approximate” splitting inside the recipe heading. Kept the approximation label in the subtitle/caveat and shortened the heading to “Your formula”; preview selectors now use a stable heading key. This changes no algorithm/data behavior. Re-rendered screenshots are reviewed before final handoff.

Scoped review boundaries: math is isolated in core, worker behavior is verified in real VM tests, and UI integration verifies selected-result Room navigation. Physical Android/iOS/native accessibility and hardware timing remain explicit device-check boundaries. No physical-pigment accuracy is claimed.

## Final-tree verification

- `flutter test --reporter expanded`:384 passed, exit0 after heading/style polish; log `/private/tmp/color-lab-formula-final-tests.log`. This supersedes both delegates' transient missing-screen full-suite failures.
- `flutter analyze`: no issues, exit0 after fixing the test-only brace lint.
- `dart format --output=none --set-exit-if-changed lib test tool`:106 Dart files,0 changes, exit0 after final polish.
- `flutter test tool/render_previews.dart --reporter expanded`: both theme tests passed, exit0.42 PNGs total;32 prior preserved +10 Formula images. Root inspected target/result, recipe percentages/error and picker in both themes, including360px/2x recipe/error. Compact heading no longer splits a word; all interactive controls remain readable and within bounds. Existing picker tests cover short-landscape/keyboard and library failures.
- `flutter build apk --debug`: exit0,15.1s; built `build/app/outputs/flutter-apk/app-debug.apk`.
- pubspec.yaml/lock, Android Gradle/manifest and iOS Podfile/Info.plist are byte-identical to the preceding module snapshot. No package/native permissions/schema changes.

No physical-device install/run, iOS build or native screen-reader/predictive-back evidence is claimed. Local pure search timing in the math report is not a mobile performance guarantee.

## Final review fix wave

Final reviewer requested one Important lifecycle fix: fire-and-forget formula push lets showColorDetails finish before the nested workflow returns, losing the camera caller's pause/resume ownership. Root traced the code to camera `_showDetails`: it stops sampling, awaits shared details and only resumes in finally when its route is current. An awaited typed formula push preserves that ownership. Root dispatches one consolidated fix wave including this regression and the carried successful→pending/refresh UI coverage minor; see formula-final-fix-brief.md. Do not package the pre-fix APK as final.

Fix implementer formula_final_fix changed one production line to `await context.push<void>('/formula')`, plus three tests/harness in the existing integration file. The real-router/fake-camera test first failed:2 sessions existed while Formula was open (expected1); after the await it passed with no background restart and a fresh blue sample after Back.13 integration,82 scoped and387 full tests passed. Exact RED/GREEN/commands and all tooling permission retries are recorded in formula-final-fix-report.md.

## Post-fix delivery verification

- Root independently reran the complete suite:387 passed, exit0 (`/private/tmp/color-lab-formula-final-tests.log`).334 prior +29 core +11 async +13 integration.
- Whole `flutter analyze`: no issues, exit0; final formatting106 files,0 changes, exit0.
- Rebuilt final debug APK with awaited navigation:9.4s, exit0. Earlier15.1s APK was pre-fix and has been replaced.
- Root final renderer rerun:2 tests passed, exit0,42 images. The fix does not change rendered data/layout.
- Scoped final re-review approved both findings as ADDRESSED, no new breakage or out-of-scope observations. See formula-independent-review.md. No new native/package/schema changes or physical-device execution.

## Final handoff

- Cumulative source archive: `dist/color-lab-formula-2026-10-21.zip`; `unzip -tq` exited0, no compressed-data errors. Checked formula core/service/UI/tests, license notices and final fix/review reports are included. Local machine configuration, caches/build outputs, Pods/symlinks/ephemeral configuration and IDE user data are excluded.
- Final debug APK: `build/app/outputs/flutter-apk/app-debug.apk`, rebuilt after the awaited camera navigation fix.42 preview PNGs remain in `build/previews/`.
- All five earlier source ZIPs are preserved. No user/app/emulator/device data was cleared, no Git repository/branch created, and no external publishing occurred. Reports remain durable with source because no Git history exists to replace them.
- Final state:387 tests pass, whole analysis clean,106 formatted Dart files,42 previews, APK and ZIP verified; no open/deferred/parked review findings. Device/iOS/native accessibility and hardware performance limitations remain documented.
- Next on a new “Next”: full Harmonies and palette saving. No later module was started here.
