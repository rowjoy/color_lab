# Formula Task 2 — isolate service and providers

Implemented the exact Task 2 interfaces using the Task 1 core exports. Only the five files listed below were created/edited by this task. No dependencies, platform settings, storage, core math, routing, UI, Git metadata, or other task files were changed. No agents were spawned.

## Owned files

- `lib/features/formula/application/color_formula_service.dart`
- `lib/features/formula/application/formula_providers.dart`
- `test/features/formula/application/color_formula_service_test.dart`
- `test/features/formula/application/formula_providers_test.dart`
- `docs/superpowers/plans/formula-task-2-report.md`

## Behavior

`ColorFormulaService.find(RgbColor)` returns `Future<ColorFormula>`. The const `IsolateColorFormulaService` calls Flutter `compute` with the top-level `_findColorFormula` callback, passing the target and using `color-formula-search` as its debug label. The callback calls the shared `findColorFormula(target)` with the full default palette. No duplicate math or temporary domain stubs were introduced.

`colorFormulaServiceProvider` defaults to that isolate service. `formulaTargetProvider` is a non-autoDispose `NotifierProvider<FormulaTargetController, RgbColor>` initialized to `#B2A4D4`; `setColor` changes session state. `formulaResultProvider` is an autoDispose `FutureProvider.family<ColorFormula, RgbColor>` that watches the service and passes its exact target. Each target owns separate async state, and detached results expire. Retry uses `ref.invalidate(formulaResultProvider(target))` for the same key.

## Tests and independent expectations

The test-driven-development skill and its complete `writing-good-tests.md` reference were read before tests were written. Five real service tests exercise default searches through production `compute`: literal red, white and black endpoints each yield one 100% part and zero error; the independently known equal black/white LAB midpoint yields `#777777`, exactly white 50% / black 50%, zero error; arbitrary nonendpoint `#B2A4D4` produces valid positive 5% steps totaling 100, distinct bases, finite nonnegative error, and allows a caller event-loop timer to run before completion.

Six provider tests keep Riverpod and the domain models real, controlling only worker completion in a test-local `ColorFormulaService`. They cover the initial/edited target retained across listener removal, exact target forwarding, a newer target finishing before an old success, a newer target finishing before an old error, same-key invalidation after failure, and finished keys expiring when listeners detach (reopening starts another request). Test containers disable automatic retries to make explicit retry behavior deterministic.

The service tests really executed native VM compute workers. The installed Flutter implementation was inspected at `packages/flutter/lib/src/foundation/_isolates_io.dart`: `compute` calls `Isolate.run` with the callback. No compute or isolate mock was installed. An actual synchronous-search mutation was also rejected by the event-loop test, as recorded below. Android/iOS device execution was not run in this task; those platforms use this same native compute implementation. The timer test protects responsiveness rather than imposing a hardware-dependent duration threshold.

## Actual RED/GREEN and commands

All commands ran from `/Users/jamirulislam/Movies/dart_jpo/color_lab` with existing dependencies and `--no-pub`; no network operation was requested. The first sandboxed Flutter and Dart invocations exited 1 before executing because Flutter tried to update `/Users/jamirulislam/Applications/flutter/bin/cache/engine.stamp`. SDK-cache escalations were approved and subsequent commands ran normally. This environment failure is not counted as a test RED.

1. Tests were created before either owned production file. Initial command:

   ```sh
   flutter test --no-pub test/features/formula/application/color_formula_service_test.dart test/features/formula/application/formula_providers_test.dart
   ```

   The first escalated run exited 1 with both test files failing to load: the service/provider files and pending Task 1 domain types did not exist yet. It also found a test typo (`isFinite` was not an available matcher). The typo was corrected to `expect(formula.deltaE.isFinite, isTrue)`, and the exact command was rerun before production files were created. This second RED exited 1 (`+0 -2`) solely for missing production service/provider APIs and the pending core exports. This was missing-feature compilation RED, not a behavioral assertion RED. No placeholders were added while core was pending.

2. Added the exact production APIs, formatted, and waited for the shared core to become available. Formatting command:

   ```sh
   dart format lib/features/formula/application/color_formula_service.dart lib/features/formula/application/formula_providers.dart test/features/formula/application/color_formula_service_test.dart test/features/formula/application/formula_providers_test.dart
   ```

   Exit 0: `Formatted 4 files (3 changed) in 0.01 seconds.`

3. After Task 1's implementation/export was available, reran the scoped test command in step 1. Exit 0: `+11: All tests passed!` (5 service / 6 provider tests).

4. Established behavioral RED for worker responsiveness by temporarily replacing the production `compute(...)` call with `Future.value(_findColorFormula(target))`, still running the real full search synchronously. Command:

   ```sh
   flutter test --no-pub test/features/formula/application/color_formula_service_test.dart --plain-name 'full nonendpoint search leaves the caller event loop responsive'
   ```

   Exit 1, `+0 -1`: expected `true`, actual `false`, at the caller-loop assertion. Restored the exact production `compute` implementation immediately.

5. Reran the exact scoped command in step 1 after restoring compute. Exit 0: `+11: All tests passed!`. This verified the restored implementation, including all real worker searches and provider cases.

6. Scoped static analysis:

   ```sh
   flutter analyze --no-pub lib/features/formula/application/color_formula_service.dart lib/features/formula/application/formula_providers.dart test/features/formula/application/color_formula_service_test.dart test/features/formula/application/formula_providers_test.dart
   ```

   Exit 0: `No issues found! (ran in 1.3s)`.

7. Scoped formatting verification:

   ```sh
   dart format --output=none --set-exit-if-changed lib/features/formula/application/color_formula_service.dart lib/features/formula/application/formula_providers.dart test/features/formula/application/color_formula_service_test.dart test/features/formula/application/formula_providers_test.dart
   ```

   Exit 0: `Formatted 4 files (0 changed) in 0.01 seconds.`

8. One required full suite:

   ```sh
   flutter test --no-pub
   ```

   Exit 1 after approximately 11 seconds: `+374 -1: Some tests failed.` All 374 loaded tests passed. The sole failed test-file load was `test/features/formula/presentation/formula_integration_test.dart`, because concurrent Task 3 had written its tests before creating `lib/features/formula/presentation/formula_screen.dart` (`No such file or directory`; consequently `FormulaScreen` undefined at test lines 124, 153 and 253). No sibling file was edited to mask that transient integration failure. Root was notified to rerun the full suite after Task 3 implementation.

## Concerns and limits

There are no known Task 2 failures. The full suite needs rerunning after the concurrent screen implementation exists. Obsolete workers may finish in the background; target-keyed state and automatic disposal prevent their values/errors from becoming another target's state. The current selection survives navigation only inside the current provider-container session; nothing is written to disk. Results are not retained as a historical global cache. Web compute uses Flutter's web behavior; the requested Android/iOS path uses a worker isolate.
