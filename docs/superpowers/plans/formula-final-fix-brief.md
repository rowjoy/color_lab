# Formula final review fix wave

One consolidated fix wave for the final reviewer’s complete findings. Original design/plan:2026-10-21-color-formula-design.md and2026-10-21-color-formula.md. No new feature scope, packages, native/schema changes or unrelated refactor.

## Important finding (verbatim)

`lib/features/picker/presentation/color_explorer.dart:89` — Formula navigation is fire-and-forget, prematurely completing `showColorDetails`. The existing camera caller stops sampling before awaiting this function (`camera_picker_screen.dart:165`) and resumes only in its `finally` when its route is current (`:187`). Opening formula therefore ends the camera’s paused workflow before formula closes: depending on routing timing, sampling can restart behind formula or remain stopped when returning. No route-pop observer restores it. Await the formula push and add a real-router/fake-camera regression covering sample → details → formula → Back, asserting no background restart and fresh sampling after return.

## Minor finding (verbatim)

`test/features/formula/presentation/formula_integration_test.dart:259` — Retain the existing ledger finding: the stale-target test starts while the original request is pending. It cannot detect regressions that retain an already-visible recipe during a new target search or same-key successful-result refresh. Add a successful-result → pending transition assertion for both result swatch and recipe; optionally exercise successful-key invalidation. Nonblocking because production explicitly suppresses loading/refresh output, and provider tests cover late success/error isolation.

## Fix requirements and ownership

- Own only `lib/features/picker/presentation/color_explorer.dart`, `test/features/formula/presentation/formula_integration_test.dart`, and `docs/superpowers/plans/formula-final-fix-report.md`. Preserve all existing tests and current behavior. No camera production edits are expected: retain awaited workflow lifetime at shared-details entry.
- Read existing camera `_showDetails` lifecycle and existing FakeCameraSession fixture first. Extend the real-app/router integration harness to inject a camera boundary, never initialize native camera hardware. Reuse the existing fixture or a focused test-local fake without refactoring unrelated tests.
- Write the camera round-trip test BEFORE changing the push; run it and record a meaningful behavioral RED. It must enter the actual sampled camera detail, open formula with the correct sampled target, show no new running camera behind formula, return and observe a fresh replacement session emitting a different color into visible UI. Fix by awaiting the typed formula push; verify GREEN. If a different failure shows the finding is inaccurate, report evidence instead of guessing.
- Close the minor as part of this same wave: controlled service starts with a successful visible recipe; select another target and verify both result swatch AND recipe/save output disappear while loading. Also exercise invalidating the successful current key and assert no previous recipe/save while refresh is pending. Complete pending requests and verify correct output recovery. These are regression coverage additions, not a new product behavior; they may already pass.
- Follow TDD/systematic debugging; scoped test commands covering Formula plus camera/detail actions, scoped analysis/format, then one full suite. Report exact RED/GREEN and full-suite output including all failures. Do not edit siblings to mask failures.
- No Git repo; no commits/init/destructive operations. No subagents or reviewers. Return a short status/report path/testsummary/concerns; root owns the one scoped re-review and final APK/ZIP.
