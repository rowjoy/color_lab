# Formula task 1 report

Implemented the exact task-1 API in `lib/core/color/color_formula.dart`, exported
through `color_engine.dart`, with 29 tests in `color_formula_test.dart`.
Only these three source/test files and this report were edited for task 1.
No package, native, storage, provider, UI, or Git changes were made.

## Implementation

- Immutable `FormulaBase` trims and validates id/name and compares all fields by
  value; immutable `FormulaPart` validates positive 5% steps through 100% and
  compares base/percent by value.
- `ColorFormula` consumes its parts iterable once into an unmodifiable snapshot,
  validates 1–3 distinct IDs totaling 100%, calls the existing `mixColors` LAB
  implementation, and computes existing `deltaE76` from the actual rounded and
  clamped displayed RGB result. No conversion code was duplicated in production.
- The ordered, unmodifiable default palette contains all 12 exact named values
  from the brief.
- `findColorFormula` consumes the optional palette once, rejects empty/duplicate
  IDs before considering an early endpoint result, enumerates all singles,
  i<j pairs, and i<j<k triples on the positive 5% grid, and replaces its winner
  only on a strictly lower displayed-result CIE76 score. Zero error can return
  immediately. Singles precede pairs, which precede triples; exact ties preserve
  that order and the palette order. A full 12-base search has 38,886 candidates.
- API documentation identifies the output as a digital LAB approximation and
  explicitly distinguishes it from physical pigment mixing.

## Test-first RED evidence

Read `formula-task-1-brief.md` first, then the test-driven-development skill and
its complete `writing-good-tests.md` reference before writing tests. Tests were
written before the production API existed.

First unprivileged invocation of
`flutter test test/core/color/color_formula_test.dart --reporter expanded`
was blocked before testing by Flutter's SDK cache write:

```text
/Users/jamirulislam/Applications/flutter/bin/internal/update_engine_version.sh: line 64: /Users/jamirulislam/Applications/flutter/bin/cache/engine.stamp: Operation not permitted
```

The same command was then run with approved SDK cache access and exited 1.
Exact diagnostic excerpts:

```text
00:00 +0: loading /Users/jamirulislam/Movies/dart_jpo/color_lab/test/core/color/color_formula_test.dart
test/core/color/color_formula_test.dart:6:1: Error: Type 'FormulaBase' not found.
FormulaBase _base(String id, String hex) =>
^^^^^^^^^^^
test/core/color/color_formula_test.dart:7:5: Error: Method not found: 'FormulaBase'.
    FormulaBase(id: id, name: id, color: RgbColor.fromHex(hex));
    ^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

The full diagnostic also identified absent `FormulaPart`, `ColorFormula`,
`formulaBases`, and `findColorFormula` symbols. This was an expected missing-API
compilation RED, not an assertion RED; no production stubs existed before it.

## GREEN and verification

After implementation, the identical focused command exited 0. Exact final lines:

```text
00:00 +23: findColorFormula matches a separate exhaustive allocation oracle globally
00:00 +24: findColorFormula exact ties retain first singleton and prefer fewer parts
00:00 +25: findColorFormula tied pairs retain palette order before equivalent triples
00:00 +26: findColorFormula consumes palette once and handles one available base
00:00 +27: findColorFormula validates entire palette before accepting an exact endpoint
00:00 +28: findColorFormula searches the full default palette for an arbitrary target
Default formula search: 39 ms; #758198; deltaE=2.112932954529412
00:00 +29: All tests passed!
```

The remaining passing tests cover trimmed/equal/invalid model values; every
allowed and representative forbidden percentage; neutral midpoint; independent
three-color fixture; displayed-result error; immutable/once-consumed recipe
snapshots; invalid recipe count, IDs and totals; all 12 exact pure endpoints;
the ordered immutable default palette; pair/triple search; and palette errors.

Commands and exact analyzer/formatter results:

```text
$ dart format lib/core/color/color_formula.dart lib/core/color/color_engine.dart test/core/color/color_formula_test.dart
Formatted test/core/color/color_formula_test.dart
Formatted 3 files (1 changed) in 0.01 seconds.

$ flutter analyze lib/core/color/color_formula.dart lib/core/color/color_engine.dart test/core/color/color_formula_test.dart
Analyzing 3 items...
No issues found! (ran in 1.2s)

$ dart format --output=none --set-exit-if-changed lib/core/color/color_formula.dart lib/core/color/color_engine.dart test/core/color/color_formula_test.dart
Formatted 3 files (0 changed) in 0.02 seconds.
```

Analyzer and final format check exited 0. The first unprivileged format command
had the same SDK cache permission error as the initial test run; the approved
rerun succeeded. No automatic approval review rejected an action.

The required complete suite was run after formatting:
`flutter test --reporter expanded`. It exited 1 after 17 seconds with 374 passing
tests and one load failure. Exact diagnostic and final summary:

```text
test/features/formula/presentation/formula_integration_test.dart:8:8: Error: Error when reading 'lib/features/formula/presentation/formula_screen.dart': No such file or directory
import 'package:color_lab/features/formula/presentation/formula_screen.dart';
       ^
00:08 +221 -1: loading /Users/jamirulislam/Movies/dart_jpo/color_lab/test/features/formula/presentation/formula_integration_test.dart [E]
00:17 +374 -1: Some tests failed.
```

The associated `FormulaScreen` references at lines 124, 153 and 253 were also
undefined because that parallel UI implementation had not yet been created.
This transient integration failure was reported to the parent; no sibling files
were changed. Task 1's tests also passed during that complete-suite run.

## Independent fixture provenance

The literal three-color fixture was evaluated separately in JavaScript using
the rational sRGB↔XYZ matrices published with W3C CSS Color 4's conversion code,
D65 white `[0.9504559271, 1, 1.0890577508]`, the standard sRGB transfer curve and
piecewise CIELAB functions. The CSS D50 adaptation was deliberately omitted to
match the app's D65 contract. Reference:
https://www.w3.org/TR/css-color-4/#color-conversion-code

For pure red, pure full-intensity green and pure blue with 20:30:50 weights:

```text
Red LAB:   [53.23711559542937, 80.0901135166881, 67.20326351236281]
Green LAB: [87.73551910966, -86.18159689651684, 83.18662027480481]
Blue LAB:  [32.30087290398018, 79.1952703025332, -107.85546553739552]
Mean LAB:  [53.118515303973965, 29.76117878564917, -15.531093983783755]
RGB:       [164.9431396358056, 108.47626540913231, 154.05631831194137]
Rounded:   #A56C9A
```

The production mixer uses its pre-existing rounded standard matrices, while the
independent fixture uses rational matrices. Both round to the same literal HEX.
The fixture is used both to derive `ColorFormula.result` and to require a genuine
three-base search result of 20%, 30%, and 50% with zero displayed-result error.

The neutral displayed-error fixture was independently calculated from the sRGB
neutral-axis lightness function: `L*(128)-L*(119)=3.550574659630797`, with tolerance
`0.00001` for the established matrix rounding. It catches scoring the unrounded
50% LAB point instead of its displayed `#777777` result against `#808080`.

The global-minimum oracle uses recursive allocation of 20 units across every
slot in a four-base palette, permits zero shares, and filters allocations to
at most three active bases. This independent enumeration differs from the
production singleton/pair/triple loops. It evaluates four literal arbitrary
targets and computes Euclidean displayed-result distance directly in the test.
It intentionally shares only established conversion/mixing APIs, whose correct
use is separately checked by the independent literal fixtures.

## Timing and concerns

One focused-test run measured a complete default search for `#71839B` at 39 ms
on this machine, returning `#758198` with CIE76 `2.112932954529412`. This is a
nonbinding local debug-test observation, not a performance guarantee. Worker
execution and UI responsiveness remain task 2/3 integration concerns.

The only verification concern at handoff is the parallel UI's missing-file
full-suite load failure described above. The parent should rerun the complete
suite once that implementation is present. The default grid is intentionally
discrete and the displayed result can be an approximation; it does not model
paint chemistry. No additional dependencies or I/O were introduced.
