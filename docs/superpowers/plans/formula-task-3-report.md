# Formula Task3 UI implementation report

Root owns formula_screen.dart, formula_recipe_card.dart, Lab/common-details entry, router, integration tests and delivery documentation. Presentation is separated from search/service code. No dependencies, native code or storage schemas changed.

## Behavior

Guarded `/formula` reads the retained session target and keyed result provider, never computes search during build. It shows the target and actual closest blend, editable manual/saved target picker, worker loading/error/retry and no stale output during a new request. Existing picker is reused with mounted/cancel safety and local library search. The recipe card renders positive percentages/bar, exact displayed-result CIE76 error, Lab-source save and common details. Digital-base reference chips expose all12 names/HEX values. Approximate/not-paint and session-only/no recipe persistence caveats remain visible.

Lab has a separate CTA retaining HSL and Mixer drafts. Common details closes its route first, applies the exact selected color to formulaTargetProvider and pushes formula only if not already there. Existing harmony replacement, Room and sharing are preserved. Result details can update the current formula target without an extra stacked formula screen.

## Test-first evidence

`flutter test test/features/formula/presentation/formula_integration_test.dart --reporter expanded` initially exited1 because FormulaScreen, pending service APIs and core types did not exist. Log: `/private/tmp/color-lab-formula-ui-red.log`. Tests were written before screen/routing/common-entry implementation. Input/output assertions were then expressed through the existing shared ColorSwatchTile public HEX property instead of inventing a duplicate HEX Text field.

After implementation, the same command passed all10 tests, exit0. Log: `/private/tmp/color-lab-formula-ui-tests.log`. Tests use actual app routing, providers, picker, recipe domain, history and details, replacing only the expensive worker boundary with either a controlled service or a valid50/50 black-white recipe. Independent literal display expectation is#777777; with that same target error is0.00. No mock recipe widgets are used.

Coverage: Lab entry, exact manual target selection/session retention and intact HSL/Mixer; selected mixed#800080 common-detail entry and nonstacking result re-entry; percentages/result/error/caveat/reference bases; cancelled target preserving recipe; old pending target failure not replacing a newer target; safe worker error/retry and no raw exception; saving/details/Room use result#777777 rather than target; first-run guard;360px2x and reduced-motion both themes.

Additional reduced-motion assertion was added before implementing ExpansionTile animation style. Focused command `flutter test test/features/formula/presentation/formula_integration_test.dart --plain-name 'formula and target picker fit360px2x reduced-motion light' --reporter expanded` exited1: expected Duration.zero, actual null. Log: `/private/tmp/color-lab-formula-motion-red.log`. The production tile now uses AppMotion.sheetAnimation, disabling expansion transitions with reduced motion. Final GREEN and integrated verification are recorded in the ledger.

## Delivery

Root runs fresh full-suite/analyzer/format/APK/preview checks, independent code-scoped UI review and final whole-module review before packaging. Agent earlier full-suite missing-screen load failures are transient test-first integration states, not omitted failures; the final run supersedes them. Device/iOS/native accessibility execution is not implied by widget tests.
