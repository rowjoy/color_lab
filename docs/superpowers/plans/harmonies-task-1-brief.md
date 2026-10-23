### Task 1: HSL harmony engine and session draft — delegate

**Files:** `lib/core/color/color_harmonies.dart`, export in color_engine.dart; `lib/features/harmonies/application/harmony_controller.dart`; tests `test/core/color/color_harmonies_test.dart`, `test/features/harmonies/application/harmony_controller_test.dart`.

**Exact APIs:**

- Enhanced `enum HarmonyMode { complementary('Complementary'), analogous('Analogous'), triadic('Triadic'), tetradic('Tetradic'), splitComplementary('Split complementary'), monochromatic('Monochromatic'); const HarmonyMode(this.label); final String label; }`.
- `List<RgbColor> generateHarmony(RgbColor base, {HarmonyMode mode = HarmonyMode.complementary})`. Unmodifiable, exact base object first, duplicates removed preserving order. HSL rotations after base: complementary[180],analogous[-30,30],triadic[120,240],tetradic[90,180,270],splitComplementary[150,210]. Mono after base L offsets[-.30,-.15,.15,.30], clamp0..1 with same hue/saturation. Reuse existing conversions, no duplicate math. Gray rotations collapse; colors remain opaque/display valid.
- `typedef HarmonyDraft = ({RgbColor base, HarmonyMode mode});` and `harmonyDraftProvider: NotifierProvider<HarmonyController,HarmonyDraft>` in harmony_controller.dart. Build base#B2A4D4/mode complementary. `void setBase(RgbColor)`, `void setMode(HarmonyMode)`, `void setSelection({required RgbColor base, required HarmonyMode mode})`; retain until container disposal, no storage writes or dependencies on palette models.

- [ ] Write tests before implementation, observe RED. Literal pure-red fixtures: complement[#FF0000,#00FFFF],analogous[#FF0000,#FF0080,#FF8000],triadic[#FF0000,#00FF00,#0000FF],tetradic[#FF0000,#80FF00,#00FFFF,#8000FF],split[#FF0000,#00FF80,#0080FF]. Check independent mono lightness fixture and endpoints/clamps, hue wrap near360, neutral rotations singleton, immutable/dedup/exact anchor. Controller mode/base independence, combined selection, retained draft across listener removal/container isolation.
- [ ] Implement exact owned APIs; focused tests/analyze/format then one full suite, reporting transient sibling failures without edits. Report RED/GREEN command/output, fixtures and files in `docs/superpowers/plans/harmonies-task-1-report.md`. No Git operations/packages/native/UI/storage edits or subagents.

