### Task 1: Pure weighted color math — delegated

**Files:** Create `lib/core/color/color_mixer.dart`, modify export `lib/core/color/color_engine.dart`; tests `test/core/color/color_mixer_test.dart`.

**Interfaces:**

- `enum MixingSpace { lab, rgb }`.
- `final class WeightedColor { WeightedColor({required RgbColor color, required double weight}); final RgbColor color; final double weight; }`; weight finite>=0, zero valid, invalid throws ArgumentError. Immutable value equality.
- `List<double> normalizedMixWeights(Iterable<double> weights)`: immutable fractions, one iteration snapshot of input, nonempty/nonnegative/finite/at-least-one-positive validation; scale by max before sum. Throw ArgumentError for invalid input.
- `RgbColor mixColors(Iterable<WeightedColor> colors, {MixingSpace space = MixingSpace.lab})`: consume once, normalize robustly, skip zeros, exact single-effective-color endpoint, LAB weightedmean via existing toLab/toRgb, RGB display channels weightedmean rounded once. No Flutter dependency.

- [ ] Write tests first, observe RED: RGB equal red+blue#800080,3:1#BF0040, black/white LAB#777777 vsRGB#808080, at least one independently derived D65 multicolor fixture (not computed by implementation), endpoints, duplicates, zero exclusion, invalid empty/allzero/negative/NaN/infinity, huge/tiny scaling and permutation invariance, immutable normalized fractions.
- [ ] Implement owned files, run scoped tests/analysis, then report exact red/green/reference provenance/results in `docs/superpowers/plans/mixer-math-report.md`. Full suite may be transient during root UI integration; report failures without editing siblings. No subagents/Git changes/new packages.

