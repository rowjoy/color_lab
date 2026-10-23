# Color Mixer Task 1: pure weighted color math

Completed the exact Task 1 APIs in the delegated brief. The implementation is
pure Dart and imports only the existing color model module. No dependencies,
Flutter imports, sibling implementation changes, Git operations, or subagents
were introduced.

## Changed files

- `lib/core/color/color_mixer.dart`: `MixingSpace`, immutable value-equal
  `WeightedColor`, immutable `normalizedMixWeights`, and `mixColors`.
- `lib/core/color/color_engine.dart`: exports the mixer API.
- `test/core/color/color_mixer_test.dart`: 40 behavior tests.
- `docs/superpowers/plans/mixer-math-report.md`: this report.

## Behavior and numerical decisions

Each public iterable is consumed once. The normalizer snapshots and validates
finite nonnegative weights, rejects empty/all-zero inputs with `ArgumentError`,
divides by the largest weight before summing, and returns an unmodifiable list.
Zero positions remain present in the fraction list, while mixing excludes zero
contributions. A single effective input returns the exact input color object.
`WeightedColor` validates its constructor and includes color and weight in value
equality and hashing.

LAB is the default. It averages existing D65 L*a*b* coordinates and reuses the
existing display-gamut conversion. Lightness is bounded to its valid range to
protect against floating-point overshoot. RGB averages **encoded sRGB display
channels**, rounding once at the end; it is not linear-light interpolation.
Neither mode simulates physical pigment mixing. The API documentation states
this distinction.

The scaled weight sum and channel/coordinate accumulators use Neumaier
compensated summation. This preserves small contributions and prevents a
demonstrated half-channel rounding error with 36 ingredients. There is no
arbitrary color-count or epsilon cutoff. As with double-precision arithmetic
generally, fractions smaller than the minimum representable double can underflow
to zero when finite weights span the entire representable range.

## Test-first evidence

Read the Task 1 brief, design, existing `color_models.dart`, the complete
`test-driven-development/SKILL.md`, and its `writing-good-tests.md` reference
before implementation.

1. Wrote the public-API behavior tests first. Initial
   `flutter test test/core/color/color_mixer_test.dart` exited 1 because the new
   API did not exist.
2. Added API scaffolding and the engine export, then reran the test file with
   `--reporter expanded`: **2 passed, 36 failed**. Failures were real assertions:
   missing weight validation/equality, unnormalized fractions, first-input RGB
   instead of the expected blend, wrong default LAB midpoint, and zero/empty
   handling. The two passing duplicate-color checks already held for the initial
   first-input scaffolding and are reported explicitly.
3. Implemented max-scaled normalization and weighted LAB/RGB accumulation:
   **38 passed**.
4. Added two numerical regressions before improving accumulation:
   **38 passed, 2 failed**. Twenty weights of `1e-16` after a weight of 1 were
   discarded, producing a largest fraction of 1 rather than the literal
   `0.999999999999998`. Eighteen black and eighteen white ingredients produced
   `#7F7F7F` instead of the exact 50:50 RGB midpoint `#808080`.
5. Introduced compensated summation, formatted the owned Dart files, then reran
   the complete scoped file: **40 passed**, exit 0.

Tests use real values, literal expected HEX fixtures, and single-use generated
iterables. They cover unequal ratios, endpoints, duplicates, zero exclusion,
empty/all-zero input, negative/NaN/infinite validation, huge finite sums, tiny and
subnormal inputs, immutable source snapshots, one-pass consumption, all six
three-color permutations, common scaling, and final-only RGB rounding.

## Independent fixture provenance

Reference: [W3C CSS Color 4 sample conversion code](https://www.w3.org/TR/css-color-4/#color-conversion-code),
read on 2026-10-21. Independently evaluated its rational sRGB-to-XYZ and inverse
matrices in a JavaScript tool cell. Used the stated D65 white
`[0.3127 / 0.3290, 1, (1 - 0.3127 - 0.3290) / 0.3290]`, the CIELAB piecewise
equations with `epsilon = 216/24389` and `kappa = 24389/27`, and the standard
sRGB decode/encode transfer functions. The reference calculation never imported
or called the Dart mixer or its conversion helpers and used rational matrices
rather than the production module's rounded matrices.

CSS's sample LAB helpers assume D50. For this app's D65 model, the independent
calculation deliberately substituted the D65 white in both directions and did
not perform D65/D50 chromatic adaptation. Weighted means were calculated in LAB,
then converted back to encoded sRGB and rounded to bytes.

| Literal recipe | Independent mean D65 LAB | Independent encoded RGB before rounding | Expected HEX |
| --- | --- | --- | --- |
| Red/green/blue, weights 1/2/3 | `[54.2684620878, 24.2187884441, -14.9983154267]` | `[159.5623643163, 115.5957208174, 156.0342599129]` | `#A0749C` |
| Lilac `#B2A4D4` / Butter `#E8DAA9`, weights 50/50 | `[78.5456162338, 5.9936706407, 1.6888343951]` | `[207.1771242124, 190.5660745719, 191.4183055623]` | `#CFBFBF` |

Additional hand-derived literals: RGB red/blue 1:1 gives `(127.5, 0, 127.5)` →
`#800080`; RGB red/blue 3:1 gives `(191.25, 0, 63.75)` → `#BF0040`; black/white
1:1 gives LAB `#777777` versus encoded RGB `#808080`. The three-primary RGB
fixture averages to `(42.5, 85, 127.5)` → `#2B5580`.

## Verification and integration snapshot

- `dart format lib/core/color/color_mixer.dart lib/core/color/color_engine.dart test/core/color/color_mixer_test.dart`:
  exit 0; formatted the mixer and tests.
- `flutter test test/core/color/color_mixer_test.dart --reporter expanded`:
  **40 passed**, exit 0.
- `flutter analyze lib/core/color/color_mixer.dart lib/core/color/color_engine.dart test/core/color/color_mixer_test.dart`:
  **No issues found**, exit 0.
- First full `flutter test --reporter expanded` during parallel UI edits:
  **302 passed, 3 load failures**, exit 1. The visible failure was
  `test/features/mixer/presentation/mixer_color_picker_test.dart`, caused by
  `mixer_color_picker.dart:88` referencing nonexistent `AppColors.border`.
  The tool truncated two subsequent failure names; they cannot be identified
  reliably from that captured output. Reported this limitation to the root.
- A second full-suite attempt captured failures concisely after the compile
  issue had changed: **331 passed, 1 failed**, exit 1. The remaining named
  failure was `test/features/mixer/presentation/mixer_screen_test.dart`:
  `minimum two colors and confirmed reset preserve deliberate choices`.
  Reported it to the root for the ongoing UI task. All math tests passed in
  both full runs. No sibling files were changed to resolve integration failures.

Task 1 has no known outstanding math/API issue. The root must complete its final
integration verification after concurrent UI work settles; this report does not
claim that the application suite is fully green.
