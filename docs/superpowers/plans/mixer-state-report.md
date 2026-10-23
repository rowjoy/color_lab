# Mixer Task 2: immutable draft and controller

Implemented the exact interfaces in `mixer-task-2-brief.md`, using the constraints in `2026-10-21-color-mixer-design.md`. The implementation only owns the state/controller, their tests, and this report. No dependencies, persistence, history, routes, UI, math implementations, or Git changes were added by this task.

## Files

- `lib/features/mixer/domain/mixer_state.dart`: immutable validated `MixerIngredient` and `MixerState`, value equality, snapshotting, initial recipe, cached fractions and LAB/RGB results.
- `lib/features/mixer/application/mixer_controller.dart`: non-autoDispose `mixerProvider`, ID-based edits/removal, minimum-two protection, mode changes, reset, monotonically increasing added IDs.
- `test/features/mixer/domain/mixer_state_test.dart`: 12 domain tests.
- `test/features/mixer/application/mixer_controller_test.dart`: 12 controller tests.
- `docs/superpowers/plans/mixer-state-report.md`: this report.

## Contract and implementation

The initial state contains `color-0` / Lilac `#B2A4D4` and `color-1` / Butter `#E8DAA9`, each at 50 parts, with LAB selected. Ingredients enforce nonblank IDs and finite weights in the inclusive range 0–100. States snapshot incoming iterables into unmodifiable lists, require at least two unique IDs, and expose unmodifiable fractions. Ingredient colors are already immutable `RgbColor` values.

Active mixes delegate exclusively to Task 1's `normalizedMixWeights`, `WeightedColor`, and `mixColors`, imported through `color_engine.dart`. An all-zero state deliberately bypasses the math functions that reject that input: it returns zero fractions and null LAB, RGB, and selected results. Result caches belong to each immutable snapshot.

The notifier edits by ID, including after reordering or earlier-item removal. Unknown/stale IDs are no-ops, including when supplied an invalid weight; known invalid weights throw `ArgumentError` without publishing a changed state. Removing at two ingredients is a no-op. Added entries start at 50 parts, have unique increasing IDs, and have no arbitrary count limit. Reset restores the original two IDs, colors, weights, and LAB selection, while preserving the counter for added IDs so removed/reset-added IDs cannot target future entries. State remains alive when all listeners leave and is discarded with its `ProviderContainer`.

## TDD evidence

Read the TDD skill and its complete `writing-good-tests.md` reference before writing tests. Tests were written before the two production modules.

RED command:

```text
flutter test test/features/mixer/domain test/features/mixer/application
```

Observed exit 1, `+0 -2`: both test files failed to load because `mixer_state.dart` and `mixer_controller.dart` did not exist; Task 1's `MixingSpace` export was also not present at that moment. This was an API-bootstrap compilation RED for the missing feature, rather than an assertion failure. No unrelated production code was changed to create it.

After implementing the state/controller and once Task 1's exports were available, the same command exited 0 with `+24: All tests passed!`.

The domain tests catch blank/duplicate IDs, invalid count/weight ranges, mutable source collection leakage, mutable public collections, repeated iterable consumption, incorrect fractions, zero-weight contribution, all-zero error handling, mode selection, endpoint color identity, and ordered value equality. Independent literal blend checks use black/white LAB `#777777` versus RGB `#808080`, and a 25:75 black/white RGB result `#BFBFBF`; the state tests do not generate expected blend values through the implementation's math helpers.

The controller tests catch wrong-position edits after removal/reordering, mutation of old snapshots, duplicate/recycled IDs, minimum-count violations, unknown-ID mutation or validation, failed-edit publication, all-zero recovery, lost mode/input state, reset not restoring the initial recipe, auto-disposal after listener removal, unwanted cross-container persistence, and an arbitrary count limit (102 total entries exercised).

## Verification results

```text
dart format lib/features/mixer/domain/mixer_state.dart lib/features/mixer/application/mixer_controller.dart test/features/mixer/domain/mixer_state_test.dart test/features/mixer/application/mixer_controller_test.dart
Formatted 4 files (4 changed).

dart format --output=none --set-exit-if-changed lib/features/mixer/domain/mixer_state.dart lib/features/mixer/application/mixer_controller.dart test/features/mixer/domain/mixer_state_test.dart test/features/mixer/application/mixer_controller_test.dart
Formatted 4 files (0 changed). (exit 0)

flutter test test/features/mixer/domain test/features/mixer/application
+24: All tests passed! (exit 0)

dart analyze lib/features/mixer/domain/mixer_state.dart lib/features/mixer/application/mixer_controller.dart test/features/mixer/domain test/features/mixer/application
No issues found! (exit 0)

flutter test
+308 -1: Some tests failed. (exit 1)
```

The full-suite run had one failure: loading `test/features/mixer/presentation/mixer_screen_test.dart`, because root-owned `lib/features/mixer/presentation/mixer_screen.dart` did not yet exist during concurrent UI work. The compiler additionally identified undefined `MixerScreen` references at test lines 52 and 173. All 308 executable tests passed, including the 24 state/controller tests; no assertion failures were observed. The pre-task baseline supplied in the brief was 246 passing tests. This task did not edit the root UI or suppress the transient failure; root must rerun full integration verification once UI work lands.

All Flutter/Dart commands used elevated sandbox access and scoped command prefixes because their SDK cache is outside the workspace. No unresolved state/controller issues or interface deviations were identified. The final integrated UI/full-suite result remains the root task's responsibility.
