# Color Mixer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add live multi-color weighted LAB/RGB mixing to Lab while preserving the HSL study and Phase1 workflows.

**Architecture:** Pure math, immutable mixer state/Riverpod controller, root-owned presentation/input sheet and routing. Existing history/details/settings remain authoritative; no new persistence or platform service.

**Tech Stack:** Current Dart/Flutter/Riverpod/go_router only, no dependencies added.

**Spec:** `docs/superpowers/specs/2026-10-21-color-mixer-design.md`, original Color Lab specification Phase2 Mixer and algorithm6.4.

## Global Constraints

- App UI English only, offline/on-device, Android minimum SDK24 and iOS-ready.
- LAB is the default: weighted arithmetic mean of D65 L*,a*,b*, then display RGB conversion. RGB means weighted arithmetic mean of encoded sRGB display channels, round once at output; label it honestly as digital blending, not paint chemistry.
- UI starts with Lilac#B2A4D4/Butter#E8DAA9 at50 parts each; each ingredient weight is finite0–100. Keep at least two ingredients; no arbitrary maximum. All-zero weights show no result and cannot be saved.
- Existing tokens/shared controls,48dp targets,360px/2x text, both themes/readable text contrast and reduced motion. No automatic permission calls, new packages, history schema/source changes, or unrelated refactoring.
- No Git repository exists: use current authorized folder, preserve old source ZIPs and user/device data. User's module-by-module “next” authorizes this scoped implementation without another approval gate.

## Review Focus

- Large/tiny finite weights must normalize without overflow/NaN or losing the sole active endpoint (Task1 reference/boundary tests).
- Zero totals or zeroed ingredients must not show/save stale invented colors or fake bar segments (Tasks1/2 boundary; Task3 rendered state tests).
- Stable IDs must prevent editing/removing the wrong ingredient after list changes; minimum-two/removal and async picker cancellation must preserve draft (Tasks2/3 identity/cancel tests).
- Picker history loading/failure/search must not corrupt shared library filters or stop manual entry (Task3 injected repository tests).
- Navigation/theme changes and details/Room actions must retain HSL/mixer state and use the exact currently selected result, not the other comparison (Tasks2/3 mode/save/navigation tests).

### Task 1: Pure weighted color math — delegated

**Files:** Create `lib/core/color/color_mixer.dart`, modify export `lib/core/color/color_engine.dart`; tests `test/core/color/color_mixer_test.dart`.

**Interfaces:**

- `enum MixingSpace { lab, rgb }`.
- `final class WeightedColor { WeightedColor({required RgbColor color, required double weight}); final RgbColor color; final double weight; }`; weight finite>=0, zero valid, invalid throws ArgumentError. Immutable value equality.
- `List<double> normalizedMixWeights(Iterable<double> weights)`: immutable fractions, one iteration snapshot of input, nonempty/nonnegative/finite/at-least-one-positive validation; scale by max before sum. Throw ArgumentError for invalid input.
- `RgbColor mixColors(Iterable<WeightedColor> colors, {MixingSpace space = MixingSpace.lab})`: consume once, normalize robustly, skip zeros, exact single-effective-color endpoint, LAB weightedmean via existing toLab/toRgb, RGB display channels weightedmean rounded once. No Flutter dependency.

- [x] Write tests first, observe RED: RGB equal red+blue#800080,3:1#BF0040, black/white LAB#777777 vsRGB#808080, at least one independently derived D65 multicolor fixture (not computed by implementation), endpoints, duplicates, zero exclusion, invalid empty/allzero/negative/NaN/infinity, huge/tiny scaling and permutation invariance, immutable normalized fractions.
- [x] Implement owned files, run scoped tests/analysis, then report exact red/green/reference provenance/results in `docs/superpowers/plans/mixer-math-report.md`. Full suite may be transient during root UI integration; report failures without editing siblings. No subagents/Git changes/new packages.

### Task 2: Immutable draft/controller — delegated

**Files:** Create `lib/features/mixer/domain/mixer_state.dart`, `lib/features/mixer/application/mixer_controller.dart`; tests `test/features/mixer/{domain,application}/`.

**Interfaces:**

- `MixerIngredient({required String id, required RgbColor color, double weight = 50})`, final fields, copyWith/value equality; nonblank id, finite weight0–100.
- `MixerState({required Iterable<MixerIngredient> ingredients, MixingSpace space = MixingSpace.lab})`, immutable snapshot of at least two entries with distinct IDs. `factory MixerState.initial()` returns ids `color-0`,`color-1`, Lilac#B2A4D4/Butter#E8DAA9 at50. `copyWith({Iterable<MixerIngredient>? ingredients, MixingSpace? space})`, equality.
- Public getters `ingredients`, `space`, `hasActiveColors`, `fractions:List<double>`, `labResult:RgbColor?`, `rgbResult:RgbColor?`, `selectedResult:RgbColor?`. All-zero ->zero fractions and null results; otherwise consume Task1 normalization/math APIs. Derived caching is allowed only within immutable state.
- `mixerProvider: NotifierProvider<MixerController,MixerState>`; `void addColor(RgbColor color)`, `void setColor(String id,RgbColor color)`, `void setWeight(String id,double weight)`, `void removeColor(String id)`, `void setSpace(MixingSpace space)`, `void reset()`. Minimum-two removal is a no-op; unknown/stale IDs are no-ops. Known invalid weights throw ArgumentError. New IDs monotonically unique; reset restores initial values/space without reusing previously added IDs. Retain draft until ProviderContainer ends, not across process restart.

- [x] Write and observe RED for immutable snapshots/unique/minimum count; normalization/allzero; mode comparisons selecting correct output; add/remove/edit-by-ID after reorder/removal; zero/minimum endpoints; invalidweight rejection; reset and retained state across listeners.
- [x] Implement using Task1's exact APIs (do not duplicate math); scoped tests/analyzer/report `docs/superpowers/plans/mixer-state-report.md`. No UI/root/routing/history edits or subagents.

### Task 3: Mixer UI, input picking and delivery — root

**Files:** Create `lib/features/mixer/presentation/{mixer_screen,mixer_color_picker}.dart`; modify `lib/features/lab/presentation/lab_screen.dart`, `lib/routing/app_router.dart`; add `test/features/mixer/presentation/` integration tests; update `tool/render_previews.dart`, README/ledger.

- [x] Write widget tests and observe RED: Lab CTA/guardedroute; actual manualHEX invalid/valid/add/edit; savedhistory search/select with unchangedglobalfilter; cancel and libraryloadretry; ratio/mode result/comparison; zero-total no-save; minimumtwo remove; resetconfirm; saveColorSource.lab; details target; HSL+mixdraft retained after navigation;360px/2x/reducedmotion/both themes.
- [x] Add `/mixer` outside tab shell under existing onboarding/startup guard, enter from Lab. Keep existing HSL controls/state untouched. Screen uses shared UI/tokens and real math/state, live preview and two labeled comparisons. Input cards use stablekeys and partsliders. Filter zero weights before PaletteBar. Allzero shows friendly recovery rather than fake swatch/actions.
- [x] Color picker modal uses root navigator, async cancellation safety, real manualHEX validation and savedlibrary with local search. Read errors show safe retry and leave manualHEX available; no native plugins or mutation of Palette filter state. Result details reuse existing sourceLab; directSave uses resolvedname; resetconfirmation preserves draft oncancel.
- [x] Run independent scoped task review and broad final review, resolve concrete findings through tested fixes. Verify full suite/analyze/format/APK and real-font mixer/picker previews both themes. Document no new packages/platform changes, session-only draft and digital blending limitations.
- [x] Package/validate `dist/color-lab-mixer-2026-10-21.zip`, keep earlier archives. Record exact command results, no native-device execution claim unless actually performed. Next module is approximate color formula.
