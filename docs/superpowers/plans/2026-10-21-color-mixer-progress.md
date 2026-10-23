# SDD ledger — plan: docs/superpowers/plans/2026-10-21-color-mixer.md

Scope: first Phase2 module only, Color Mixer. Existing HSL study, persistence, onboarding and capture are retained. Recipes/harmony wheels/games/Room photo editing are deferred.

Execution: root integrates UI while delegates own disjoint pure math and immutable/controller paths. No Git repo exists; file-scoped diffs from the prior Onboarding ZIP substitute for commit ranges. Parallel disjoint work follows active collaboration instructions. No new dependencies, platforms or history schema changes.

RGB decision: encoded sRGB channel arithmetic average, explicitly labeled in UI/docs. It is not linear-light mixing or pigment simulation; changing that interpretation later would change RGB results. LAB follows the exact weighted D65 formula in the original document.

| Task / interface pair | Preflight check |
| --- | --- |
| 1 / 2 | Exact MixingSpace,WeightedColor,normalization/mix APIs; no duplicate math |
| 2 / 3 | Exact state getters/controller methods/IDs/null-total behavior; root owns picker/route |
| 1 / 3 | UI comparison labels match encoded RGB/LAB behavior; both actual results shown |
| 1 | Tests include reference, numeric limits, endpoints and immutable fractions |
| 2 | Minimum-two, IDs, reset, stale edits and session retention specified consistently |
| 3 | Legacy HSL untouched; root guard/native boundary preserved; sourceLab avoids schema change |

Task 1: complete (file-scoped diff, spec compliance and quality approved by independent mixer_math_review; no findings). Forty focused tests, independent D65 reference fixtures and scoped analysis are recorded in mixer-math-report.md.
Task 2: complete (file-scoped diff, spec compliance and quality approved by independent mixer_state_review; no findings). Twenty-four focused tests and scoped analysis are recorded in mixer-state-report.md.
Task 3: complete (UI spec compliance and quality approved by independent mixer_ui_review; broad mixer_final_review approved with no findings; full tests, analysis, format, APK, previews and cumulative source archive verified).

Task3 ingredient picker is delegated as a disjoint presentation subtask (`mixer-picker-brief.md`); root retains the mixer screen/routing/integration. Exact return-only picker API prevents side effects on draft or global library filters. Four implementation slots use separate paths.

The compact selected-result bar is pinned below the scrolling ingredients, keeping the live output visible during ratio edits. A regression test first failed because the persistent result was absent, then passed after implementation, including a real slider drag and opening the updated #AAAAAA result. It is hidden for all-zero totals. The original nine screen tests plus this interaction test pass; the narrow-theme cases also check reduced motion in final verification.

Picker verification: fourteen focused tests and clean scoped analysis; manual and saved selection, cancellation, local-filter isolation, library loading/failure/retry, long-list scrolling, keyboard, narrow/large text and reduced motion. See mixer-picker-report.md. Its pre-pinned-bar full-suite run passed333 tests; the root final run supersedes that count.

## Fresh integrated verification

- `flutter test --reporter expanded`:334 passed, exit0; log `/private/tmp/color-lab-mixer-final-tests.log`. Counts:246 prior tests +40 math +24 draft/controller +14 picker +10 screen.
- `flutter analyze`: no issues, exit0.
- `dart format --output=none --set-exit-if-changed lib test tool`:97 Dart files,0 changes, exit0.
- Real-font renderer produced32 previews, preserving22 older captures and adding10 mixer/picker captures. Root inspected light/dark overview and ingredients/pinned result, manual/saved picker and360px/2x screenshots. No clipped interactive controls or overflow observed; the picker remains scrollable at large text. Fixture naming uses a deliberately small sample catalog, not the production31,943-entry asset.
- `flutter build apk --debug`: exit0, built `build/app/outputs/flutter-apk/app-debug.apk` in8.1s.

Scoped UI review limits resolved: no new native code/permissions/packages means existing platform/device verification boundaries remain. Shared primary/secondary text colors use the existing contrast-tested theme tokens; small text does not use the lower-contrast dark accent. Actual screen reader/predictive-back, physical camera and iOS execution remain device checks, not claimed here. Picker disposal safety is reviewed via mounted/stable-ID checks; there is no dedicated presentation-disposal test. Existing immutable/controller tests cover stale IDs and session lifetime.

Final review and each declined-to-judge item are recorded in mixer-independent-review.md. Root retains the native/performance/exact-end-to-end test boundaries honestly. Existing shared Room interaction tests and selected-result screen tests support the integration; no physical-paint simulation or large-list frame-time profiling is claimed.

Root independently reran `flutter test tool/render_previews.dart --reporter expanded`: both theme render tests passed, exit0. Compared pubspec.yaml/lock, Android Gradle/manifest and iOS Podfile/Info.plist with the baseline: byte-identical. No dependencies, native configuration or storage schemas changed.

## Delivery

- `dist/color-lab-mixer-2026-10-21.zip` is the cumulative source handoff. `unzip -tq` exited0 with no compressed-data errors. Mixer source/tests, asset licenses and independent review record are included.
- Archive excludes local.properties, build/cache directories, Pods/symlinks/ephemeral configuration and IDE/user data. All four prior module archives remain untouched. No app/device/user data was cleared and no Git repository or branch was created.
- Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`. Previews: `build/previews/` (32 PNGs). Pure-Flutter functionality is verified; no physical-device or iOS execution is claimed.
- All scoped and final reviews are clean. Next module, on a new “next”, is approximate color formula; harmony wheel/games and real room-photo editing remain later work.
