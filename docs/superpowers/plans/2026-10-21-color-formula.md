# Approximate Color Formula Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Find and display the best approximate digital base-color recipe for any target color.

**Architecture:** Pure validated formula/search engine, injected isolate service and target-keyed Riverpod results, guarded full-screen UI integrated with Lab and common details. Reuse the existing manual/saved picker, weighted LAB math, history and details.

**Tech Stack:** Existing Flutter/Dart/Riverpod/go_router; no dependencies added.

**Spec:** `docs/superpowers/specs/2026-10-21-color-formula-design.md`, supplied build document section6.5.

## Global Constraints

- English-only offline UI, Android minimum SDK24 and iOS-ready application code; no new dependencies, permissions, persistence schema or network calls.
- Exhaustively search pairs/triples in5% steps using LAB blending; include pure-base endpoints. Rank displayed RGB by CIE76 to target; show that same result/error. Always label approximate/digital, not real paint.
- Default target#B2A4D4; preserve HSL/Mixer/history/settings and session drafts. No harmony wheel/games/room-photo editing or recipe persistence.
- Existing tokens/shared controls, minimum48dp actions,360px/2x text, light/dark and reduced motion. Heavy production search runs in a worker isolate, not in widget build.
- No Git repository exists; preserve current project/user changes and earlier ZIPs. Use baseline source-ZIP file-scoped diffs and keep durable reports. The existing “next” implementation workflow does not need another approval prompt.

## Review Focus

- Grid omissions or zero-endpoint duplicates must not hide a better recipe; Task1 tests full independent small-palette enumeration and a triple optimum.
- Gamut/rounding may change apparent error; Task1 compares the reported error with displayed result and checks known LAB fixtures.
- New target selected before old search finishes must not show stale recipes/errors; Task2 deliberately completes requests out of order; Task3 verifies loading clears obsolete results.
- Opening formula from details must use the actual selected shade and avoid repeated formula stacking; Task3 integration tests route/result/Room behavior and return navigation.
- Picker cancellation, load failure or retry must not reset existing drafts or block target entry; Task3 uses the real existing picker and injected search failure, while prior picker tests retain library failure coverage.

### Task 1: Formula models and exhaustive pure-Dart search — delegate

**Files:** Create `lib/core/color/color_formula.dart`, export from `lib/core/color/color_engine.dart`; create `test/core/color/color_formula_test.dart`.

**Interfaces and exact values:**

- `final class FormulaBase { FormulaBase({required String id, required String name, required RgbColor color}); final String id,name; final RgbColor color; }`. Trim id/name; reject blank. Immutable value equality.
- `final class FormulaPart { FormulaPart({required FormulaBase base, required int percent}); final FormulaBase base; final int percent; }`. Percent must be5..100 divisible by5; immutable value equality.
- `final class ColorFormula { ColorFormula({required RgbColor target, required Iterable<FormulaPart> parts}); final RgbColor target; final List<FormulaPart> parts; RgbColor get result; double get deltaE; }`. Snapshot once to unmodifiable parts; validate1..3 distinct base IDs and total100. Derive result with existing `mixColors` LAB API; derive CIE76 error from displayed result. Immutable value equality is optional.
- `final List<FormulaBase> formulaBases` unmodifiable ordered default: red/Red/#FF0000, orange/Orange/#FF8000, yellow/Yellow/#FFFF00, green/Green/#008000, blue/Blue/#0000FF, violet/Violet/#8000FF, white/White/#FFFFFF, black/Black/#000000, yellow-ochre/Yellow ochre/#C99700, burnt-sienna/Burnt sienna/#A0522D, raw-umber/Raw umber/#826644, paynes-gray/Payne's gray/#536878.
- `ColorFormula findColorFormula(RgbColor target, {Iterable<FormulaBase>? bases})`. Snapshot optional palette once; reject empty or duplicate IDs. Defaults to formulaBases. Search singles100%, every i<j with first percent5..95, every i<j<k with positive5% units totaling100. Rank actual displayed result CIE76, strict lower score replaces best, exact ties retain stable enumeration order; may return at zero error. Reuse existing conversion/LAB mixing contracts, no duplicate conversion implementation. Worker/service owned by Task2.

- [x] Write tests first and observe RED: all default base endpoints return same HEX/one100% part; known black/white50:50 LAB#777777 gives zero error; independent multicolor/triple fixture; all returned parts positive multiples5 and total100; strict global minimum against independent small-palette exhaustive oracle; deterministic equal-error/fewer-part tie; displayed-result error, immutable snapshots/once-consumed iterables and invalid base/palette/recipe inputs.
- [x] Implement exact owned APIs, run focused tests/analyze/format and one full suite, reporting any transient sibling integration failures without editing their files. Record RED/GREEN commands/output, independent fixture provenance and a nonbinding measured search timing in `docs/superpowers/plans/formula-task-1-report.md`. No Git commits, packages, native/UI/provider edits or subagents.

### Task 2: Isolate service and asynchronous providers — delegate

**Files:** Create `lib/features/formula/application/{color_formula_service,formula_providers}.dart`; tests `test/features/formula/application/{color_formula_service,formula_providers}_test.dart`.

**Interfaces:** Consume Task1 exact `ColorFormula`, `FormulaBase`, `FormulaPart`, `findColorFormula` through core/color/color_engine.dart. Do not create stubs/duplicate math in production while Task1 is pending.

- `abstract class ColorFormulaService { Future<ColorFormula> find(RgbColor target); }`.
- `class IsolateColorFormulaService implements ColorFormulaService { const IsolateColorFormulaService(); }` dispatches target to a top-level compute callback, production full default search off the main isolate on Android/iOS. No platform plugins/new dependencies/global result cache.
- `colorFormulaServiceProvider: Provider<ColorFormulaService>` defaults to the isolate service.
- `formulaTargetProvider: NotifierProvider<FormulaTargetController,RgbColor>`; build returns#B2A4D4; `void setColor(RgbColor color)` sets the target. Non-autoDispose retains selection while navigating, no disk writes.
- `formulaResultProvider = FutureProvider.autoDispose.family<ColorFormula,RgbColor>(...)` watches service and calls find(target). Target-keyed completion/errors cannot override another target; invalidate the same key for retry. No provider mutation from widget build, no persistently cached result per every historical target.

- [x] Write tests first and observe RED: actual isolate returns default pure-red100%/zero error and nonendpoint valid result; compare service contract with independently known black/white or base fixtures rather than a stub. Provider tests use a test-local controlled service: initial/changed target retention, keyed request gets exact target, newer completes before older (old value/error cannot leak), same-key invalidation retries after failure, autoDispose does not retain every finished result after listeners detach.
- [x] Implement exact APIs, scoped tests/analyze/format and one full suite; wait for Task1 instead of inventing placeholders. Report exact RED/GREEN/results and owned files in `docs/superpowers/plans/formula-task-2-report.md`. No UI/core/routing/history/package edits, Git operations or subagents.

### Task 3: Formula presentation, entry points and delivery — root

**Files:** Create `lib/features/formula/presentation/{formula_screen,formula_recipe_card}.dart`; integrate `lib/features/lab/presentation/lab_screen.dart`, `lib/features/picker/presentation/color_explorer.dart`, `lib/routing/app_router.dart`; create `test/features/formula/presentation/formula_integration_test.dart`; update previews/README/ledger.

- [x] Write widget tests and observe RED for Lab and common-details entry/exact target, manual target selection/cancel, loading/error/retry/new-target stale suppression, percentages/error/swatch and selected-result save/details/Room, first-run guards, retained HSL/Mixer/session target, repeated same-route formula entry,360px/2x/reducedmotion/both themes. Use injected boundary services, not mocked recipe widgets; retain real picker/state/history/router.
- [x] Implement full-screen `/formula` under startup/onboarding guard. `FormulaScreen` reads formulaTargetProvider and target-keyed results, shows input picker, truthful approximate digital caveat, target/result comparison, positive percentage recipe/bar, exact CIE76 error, default-base reference chips and Lab-source result save/details. Friendly loading/failure+Retry, no stale result; picker mounted/cancel safety; responsive recipe card component to keep screen focused. Reuse showMixerColorPicker return-only API rather than duplicate input code.
- [x] Common details closes its sheet, sets the exact selected target and pushes formula unless already at `/formula` (update without stacking). Preserve harmony replacement and Room behavior. Lab gets a separate formula CTA without replacing HSL/Mixer.
- [x] Run independent code-scoped UI task review and broad final review; resolve findings with tests. Verify full suite/analyze/format/debugAPK plus real-font formula/result/narrow/picker previews both themes. Update README changed tree, no package/native additions, exact search/scoring/digital/session-only limits and run commands.
- [x] Package cumulative `dist/color-lab-formula-2026-10-21.zip`, validate content/integrity, preserve all earlier archives and record evidence. Next module is full harmonies/palette saving; do not start it in this reply.
