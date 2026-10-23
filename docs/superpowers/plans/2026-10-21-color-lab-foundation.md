# Color Lab Foundation Implementation Plan

> For agentic workers: Use the subagent-driven-development workflow, with independent file ownership and a final integrated review. Steps use checkboxes for tracking.

**Goal:** Deliver the approved runnable Color Lab Foundation and offline color engine.

**Architecture:** Pure Dart color algorithms remain independent of Flutter. Theme tokens and shared widgets support a Riverpod root and indexed go_router shell. Only Foundation dependencies are added.

**Tech Stack:** Flutter 3.41.1, Dart 3.11, flutter_riverpod, go_router, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-21-color-lab-foundation-design.md`

## Global Constraints

- English-only, Android-first, iOS-ready, free and offline.
- Opaque RGB channels 0–255; D65 CIE LAB; CIE76 distance.
- Screens consume centralized design tokens; bundled fonts and color-name data.
- Four destinations: /capture, /palette, /lab, /room. Capture is initial.
- Minimum 48-pixel targets, 360-pixel phone support, text scaling and reduced motion.
- No camera, storage, segmentation, or sharing dependency until its feature exists.
- This directory has no Git repository; edit the authorized workspace directly and report verification without inventing commits.

## Review Focus

- Invalid/nonfinite color inputs must fail explicitly; Task 1 tests validation.
- Repeated or near-identical image samples must not produce empty/NaN clusters; Task 1 tests population merging.
- Missing or malformed name assets must remain nonfatal; Task 1 tests the loader fallback.
- Large text and narrow screens must not overflow; Tasks 2 and 4 exercise these layouts.
- Reduced motion and disabled controls must remain usable; Task 2 tests those states.

## Task 1: Color engine and asset adapter

**Owns:** `lib/core/color/`, `lib/data/assets/`, `test/core/color/`, `test/data/`.

**Interfaces:** Barrel `lib/core/color/color_engine.dart`; immutable `RgbColor(int red, int green, int blue)` with `fromHex`, `hex`, `toHsl`, `toHsv`, `toCmyk`, `toLab`; each space supports `toRgb`; `deltaE76(LabColor, LabColor)`; `ColorNamer` parses dataset entries and finds nearest names; `extractPalette(List<RgbColor>, {int k = 8, int seed = 42, double mergeThreshold = 8})` returns immutable `PaletteColor` entries. Flutter asset adapter loads the complete dataset once and supplies a fallback on failure.

- [x] Write tests for #RGB expansion/rejection, red HSL (0,1,.5), black CMYK (0,0,0,1), D65 red LAB approximately (53.24,80.09,67.20), round trips, validation, CIE76 identity/symmetry, nearest names, deterministic k-means, repeated/merged samples, population sum and fallback loading.
- [x] Run tests and record missing behavior failures.
- [x] Implement value models, conversions, naming/cache, k-means++ and loader. Weighted cluster merges conserve population. Validate iteration/input bounds and avoid mutating caller data.
- [x] Run scoped tests and analyzer; report any failures.

## Task 2: Theme system and shared widgets

**Owns:** `lib/core/theme/`, `lib/core/widgets/`, `test/core/theme/`, `test/core/widgets/`.

**Interfaces:** `theme.dart` exports `AppTheme.light`, `AppTheme.dark`, `AppColors` theme extension and `context.appColors`; `AppSpacing` (xs=4,sm=8,md=12,lg=16,xl=20,xxl=24,xxxl=32,huge=48), `AppRadii`, `AppMotion`; `widgets.dart` exports all required shared widgets. `AppScaffold({required Widget body, Widget? bottomNavigationBar})`; buttons use `label`, `onPressed`, optional `icon`; `IconCircleButton` uses `icon`, `label`, `onPressed`; `SectionHeader` uses `title`, optional `subtitle`, `trailing`; `ColorChip` uses `color`, optional `label`, `onTap`; `ColorSwatchTile` uses `color`, `name`, `hex`, optional `onTap`; `EmptyState` uses `icon`, `title`, `message`, optional `action`.

- [x] Write focused widget tests for button callbacks/disabled/loading, slider change, copy feedback, swatch interaction, layout at 360 pixels with 2x text, and reduced-motion shimmer.
- [x] Run tests to observe failures.
- [x] Implement exact approved tokens, typography and themes. Build all fourteen shared widgets, accessible labels and touch targets, adaptive sizing, reduced-motion handling and feedback. Use Material rounded icons.
- [x] Run scoped tests and analyzer; report public interfaces and results.

## Task 3: Offline assets and licensing

**Owns:** `assets/` and `docs/asset-sources.md`.

**Consumes/produces:** Bundle Plus Jakarta Sans normal variable font, JetBrains Mono normal variable font, font licenses, `assets/data/color_names.json` from upstream color-name-list, and its license. Record pinned upstream revisions and licenses. Root registers these assets in pubspec.

- [x] Fetch assets from primary upstream repositories, inspect formats and file signatures, validate JSON entries with name and hex.
- [x] Record source revisions and licenses and report exact relative filenames.

## Task 4: Working application and delivery

**Owns:** `lib/main.dart`, `lib/app.dart`, `lib/routing/`, `lib/features/`, `pubspec.yaml`, `pubspec.lock`, `test/widget_test.dart`, `test/routing/`, `README.md`, platform minimum SDK if needed.

**Consumes:** Task 1 color engine, Task 2 barrel interfaces, Task 3 assets.

- [x] Resolve flutter_riverpod and go_router against installed SDK. Register fonts/assets and remove unused template dependency.
- [x] Replace counter smoke test with app behavior tests: initial Capture screen, all four navigation actions, working tab controls, theme changes, narrow and large-text screens.
- [x] Run tests to observe failures, then implement ProviderScope entry, ColorLabApp, theme-mode controller and router provider with indexed shell. Build truthful Foundation screens that demonstrate the shared system and let users inspect/copy colors and experiment with existing color utilities.
- [x] Set Android min SDK to 24. Do not request camera/storage permissions before their feature.
- [x] Run full tests, formatter and analyzer. Attempt Android debug compile; report any environment blocker precisely.
- [x] Perform an independent final review, address substantive findings, update README with run commands, milestone scope and phase boundaries, and package source/assets/tests as a Foundation ZIP.

