### Task 1: Formula models and exhaustive pure-Dart search — delegate

**Files:** Create `lib/core/color/color_formula.dart`, export from `lib/core/color/color_engine.dart`; create `test/core/color/color_formula_test.dart`.

**Interfaces and exact values:**

- `final class FormulaBase { FormulaBase({required String id, required String name, required RgbColor color}); final String id,name; final RgbColor color; }`. Trim id/name; reject blank. Immutable value equality.
- `final class FormulaPart { FormulaPart({required FormulaBase base, required int percent}); final FormulaBase base; final int percent; }`. Percent must be5..100 divisible by5; immutable value equality.
- `final class ColorFormula { ColorFormula({required RgbColor target, required Iterable<FormulaPart> parts}); final RgbColor target; final List<FormulaPart> parts; RgbColor get result; double get deltaE; }`. Snapshot once to unmodifiable parts; validate1..3 distinct base IDs and total100. Derive result with existing `mixColors` LAB API; derive CIE76 error from displayed result. Immutable value equality is optional.
- `final List<FormulaBase> formulaBases` unmodifiable ordered default: red/Red/#FF0000, orange/Orange/#FF8000, yellow/Yellow/#FFFF00, green/Green/#008000, blue/Blue/#0000FF, violet/Violet/#8000FF, white/White/#FFFFFF, black/Black/#000000, yellow-ochre/Yellow ochre/#C99700, burnt-sienna/Burnt sienna/#A0522D, raw-umber/Raw umber/#826644, paynes-gray/Payne's gray/#536878.
- `ColorFormula findColorFormula(RgbColor target, {Iterable<FormulaBase>? bases})`. Snapshot optional palette once; reject empty or duplicate IDs. Defaults to formulaBases. Search singles100%, every i<j with first percent5..95, every i<j<k with positive5% units totaling100. Rank actual displayed result CIE76, strict lower score replaces best, exact ties retain stable enumeration order; may return at zero error. Reuse existing conversion/LAB mixing contracts, no duplicate conversion implementation. Worker/service owned by Task2.

- [ ] Write tests first and observe RED: all default base endpoints return same HEX/one100% part; known black/white50:50 LAB#777777 gives zero error; independent multicolor/triple fixture; all returned parts positive multiples5 and total100; strict global minimum against independent small-palette exhaustive oracle; deterministic equal-error/fewer-part tie; displayed-result error, immutable snapshots/once-consumed iterables and invalid base/palette/recipe inputs.
- [ ] Implement exact owned APIs, run focused tests/analyze/format and one full suite, reporting any transient sibling integration failures without editing their files. Record RED/GREEN commands/output, independent fixture provenance and a nonbinding measured search timing in `docs/superpowers/plans/formula-task-1-report.md`. No Git commits, packages, native/UI/provider edits or subagents.

