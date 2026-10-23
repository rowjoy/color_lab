### Task 2: Isolate service and asynchronous providers — delegate

**Files:** Create `lib/features/formula/application/{color_formula_service,formula_providers}.dart`; tests `test/features/formula/application/{color_formula_service,formula_providers}_test.dart`.

**Interfaces:** Consume Task1 exact `ColorFormula`, `FormulaBase`, `FormulaPart`, `findColorFormula` through core/color/color_engine.dart. Do not create stubs/duplicate math in production while Task1 is pending.

- `abstract class ColorFormulaService { Future<ColorFormula> find(RgbColor target); }`.
- `class IsolateColorFormulaService implements ColorFormulaService { const IsolateColorFormulaService(); }` dispatches target to a top-level compute callback, production full default search off the main isolate on Android/iOS. No platform plugins/new dependencies/global result cache.
- `colorFormulaServiceProvider: Provider<ColorFormulaService>` defaults to the isolate service.
- `formulaTargetProvider: NotifierProvider<FormulaTargetController,RgbColor>`; build returns#B2A4D4; `void setColor(RgbColor color)` sets the target. Non-autoDispose retains selection while navigating, no disk writes.
- `formulaResultProvider = FutureProvider.autoDispose.family<ColorFormula,RgbColor>(...)` watches service and calls find(target). Target-keyed completion/errors cannot override another target; invalidate the same key for retry. No provider mutation from widget build, no persistently cached result per every historical target.

- [ ] Write tests first and observe RED: actual isolate returns default pure-red100%/zero error and nonendpoint valid result; compare service contract with independently known black/white or base fixtures rather than a stub. Provider tests use a test-local controlled service: initial/changed target retention, keyed request gets exact target, newer completes before older (old value/error cannot leak), same-key invalidation retries after failure, autoDispose does not retain every finished result after listeners detach.
- [ ] Implement exact APIs, scoped tests/analyze/format and one full suite; wait for Task1 instead of inventing placeholders. Report exact RED/GREEN/results and owned files in `docs/superpowers/plans/formula-task-2-report.md`. No UI/core/routing/history/package edits, Git operations or subagents.

