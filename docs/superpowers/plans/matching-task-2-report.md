# Matching Task 2 implementation report

Implemented the real retained matching screen and Lab/router integration against
Task 1's exact shared API. No duplicate models, controller stubs, packages, native
changes, storage changes, renderer edits, or Git operations were introduced.

## Owned files

- Added `lib/features/color_test/presentation/matching_screen.dart`.
- Updated `lib/features/lab/presentation/lab_screen.dart`.
- Updated `lib/routing/app_router.dart`.
- Added `test/features/color_test/presentation/matching_integration_test.dart`.
- Added this report.

## Behavior

Lab's `Play color matching` CTA follows Harmonies and opens guarded `/matching`.
The old game-coming copy now identifies color-vision plates as the next module.
Matching delegates every coordinate and transition to the real retained game
controller. It owns no scoring, generation, persistence, timer, or color math.

The shared Target/Your match tiles hide HEX and disable details until submission.
Feedback reveals the exact display RGB pair, two-decimal CIE76 error and points
in a live region, freezes sliders, and uses exact wording only for RGB equality.
Round progression and repeated/stale callback handling use the shared controller.
Five immutable attempts appear as result pairs with individual score/error,
total/500 and average/100. Explicit Play again starts the next game.

Restart uses a root confirmation dialog, shared 48dp token-based buttons and
reduced-motion animation settings. Cancel and system Back preserve the draft.
AppBar Back pops when possible and otherwise goes to Lab without resetting.
The screen explains display/light effects, scoring's game convention and the
nonmedical scope.

The root clarified that both colors must remain visible while adjusting sliders
on a phone. A compact SafeArea comparison follows the existing Mixer's bottom
result pattern. It keeps actual target/guess RGB visible at Lightness, has intrinsic
text height for 2x scaling, exposes role-only semantics, and adds no HEX hints or
duplicate detail actions. The original shared tiles remain in scrollable content.

## Actual TDD evidence

Read the brief, exact Task 1 API, approved design, TDD skill and its full
`writing-good-tests.md` reference before implementation. Tests use the full
`ColorLabApp`, real router, real game/controller and shared widgets. Only existing
repository boundaries use memory fixtures; only the game generator is overridden
with deterministic red/green/blue/cyan/yellow target lists.

1. The initial test had a fixture import error (`colorHistoryRepositoryProvider`
   missing). Fixed the import before treating the run as RED evidence.
2. Reran `flutter test test/features/color_test/presentation/matching_integration_test.dart --reporter expanded`
   before production edits. The real Lab assertion failed because
   `open-matching` did not exist. This is the initial missing-feature RED.
3. Expanded behavioral tests before production implementation; once Task 1 files
   existed, the expanded run compiled and reported **1 pass / 12 failures** because
   the matching route/widgets did not yet exist. Onboarding guard already passed.
4. Before implementing the pinned comparison, added and ran the phone comparison
   test alone (`--plain-name 'both comparison colors'`). It failed on missing
   `matching-comparison-target` after scrolling to Lightness. Then implemented the
   comparison and verified it in the complete focused run.
5. Final focused matching run reported **14/14 passing** in approximately 3 seconds.

The focused tests cover Lab entry/onboarding guard; visible/semantic hint hiding
and disabled detail taps; grey-to-red ΔE **104.55**, score **0** and actual
`#808080`; slider-generated green-to-red ΔE **170.57**, score **0**; raw neutral
hue retention; frozen sliders and stale submit/slider/next callbacks; nonexact
`#FE0000` versus `#FF0000` still rounding to **100** without exact wording;
post-submit Lab-source target save and guess-to-Room; five exact snapshot pairs,
**500/500** and **100.00/100**, retained completion and replay; restart
cancel/system Back/confirm; navigation/theme retention of game and HSL/Mixer/
Formula/Harmony drafts; unchanged seeded history/palette records; a genuinely
failed history provider not blocking play; retained comparison colors; and all
states at 360px/2x text/reduced motion in both light and dark themes.

## Failures investigated and corrected

The first implementation run reported 8 passes and 5 failures. The causes were
traced to the component or test boundary rather than changing numeric fixtures:

- `StudioHeading` uppercases its eyebrow, hiding literal `Round N of 5` from the
  intended case-sensitive UI contract. Round progress now uses normal Text in
  the retained footer, remaining visible during edits.
- A broad no-Delta-E matcher also matched the generic scoring explanation.
  Narrowed it to actual `^ΔE ` result rows; HEX hiding, inaccessible detail
  actions and literal score/error fixtures remain strict.
- Scrolling to Save color moved the common-details Close button offscreen.
  The test now scrolls it into view before tapping, eliminating missed-hit
  warnings and verifying that the subsequent guess sheet contains `#808080`.
- `tester.pageBack()` tried to tap the appbar through an open dialog rather than
  delivering system Back. The test now calls `handlePopRoute()` and asserts
  the dialog disappeared and the draft retained identity.
- `addTearDown` disposed a SemanticsHandle after widget-test end verification.
  Existing repository tests dispose inline; this fixture now disposes with
  try/finally, removing the remaining handle failure.

Scoped analysis initially identified one unused import and one unnecessary
import in the test. Both were removed; subsequent analysis is clean. No warning
is suppressed and the final focused/full runs emit no missed-hit warnings.

## Verification and self-review

- `flutter analyze lib/features/color_test/presentation/matching_screen.dart lib/features/lab/presentation/lab_screen.dart lib/routing/app_router.dart test/features/color_test/presentation/matching_integration_test.dart`
  — **No issues found**.
- `dart format --output=none --set-exit-if-changed lib/features/color_test/presentation/matching_screen.dart lib/features/lab/presentation/lab_screen.dart lib/routing/app_router.dart test/features/color_test/presentation/matching_integration_test.dart`
  — **4 files, 0 changes**.
- After announcing API/UI readiness to root, ran the required full
  `flutter test --reporter expanded` once: **523/523 passed**, approximately
  **23 seconds**, exit 0. **No transient sibling failures** occurred in this run.

Reviewed the actual baseline diffs for both existing files against
`/private/tmp/color-lab-matching-baseline.eVdpa3` and reread the new screen/test.
The existing-file diff consists only of the matching Lab CTA, coming-soon copy,
matching screen import and guarded route. Shared details, shell, preferences,
history/palette storage, other feature controllers and native files are untouched.
Mentally checked wrong handlers, pre-submit detail leakage, premature exact-match
claims, stale coordinate mutations, wrong submitted RGB, final-pair-only summary,
restart without confirmation and game/draft resets against the relevant tests.

Renderer/real-font visual inspection, APK packaging, cumulative archive review,
and independent task review belong to root's follow-up work. Device accessibility,
Android execution and iOS execution are not claimed by this UI widget-test report.

## Final review follow-up: results/replay viewport entry

Root identified a concrete scroll-entry risk before packaging. Added a focused
360x800 behavioral test first: finish all five rounds through visible real
Submit/Next buttons, inspect results without scrolling to them, then tap Play
again from the summary bottom and inspect the new target without scrolling.

**Actual RED:** summary and replay visibility were both false. The summary kept
offset **1098**, putting Total points at **y=-792..-770**. Replay kept offset
**840**, putting the target tile at **y=-492..-292**. The stable keyed
SingleChildScrollView reused its scroll position despite replacing its content.
A second test established slider/theme offset retention and observed confirmed
same-phase restart incorrectly retaining offset **840** instead of zero.

The minimal fix is a screen-owned, disposed ScrollController. A Riverpod listener
resets only the viewport to zero when the round index changes, the game enters or
leaves completion, or target-snapshot identity changes. Coordinate edits,
editing-to-feedback submission, theme changes and ordinary navigation do not
trigger this listener's reset condition. Game/controller/domain/scoring APIs are
unchanged. Existing keys and shared tiles are unchanged. Root clarified that
submission should preserve the controls/feedback viewport; an explicit regression
first failed against the initial broad phase-reset condition (expected retained
offset **840**, observed **0**), then passed after narrowing the condition.

**Actual GREEN:** focused matching integration suite now **16/16 passing**, about
3 seconds. Results' Total points and average are immediately hit-testable after
See results; replay's target is immediately hit-testable. The companion test
verifies exact scroll-offset preservation for slider, theme and submission changes
and zero offset after confirmed new-game restart. Scoped analysis of the two modified
source/test files reports **No issues found**; format check reports **2 files,
0 changes**. Per root's explicit instruction, no full suite was rerun in this
follow-up; the earlier 523-test result predates these two additional tests.
