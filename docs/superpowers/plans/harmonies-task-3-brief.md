### Task 3: Procedural harmony wheel — delegate

**Files:** `lib/features/harmonies/presentation/harmony_wheel.dart`, `test/features/harmonies/presentation/harmony_wheel_test.dart`.

**Interface:** `HarmonyWheel({super.key,required RgbColor base,required HarmonyMode mode,required List<RgbColor> colors})` stateless read-only diagram using code-native CustomPaint. Core types from Task1, existing theme tokens. No picker/controller/storage/root edits.

- Show a circular HSL hue ring (red at top0°, clockwise), markers filled with actual generated RGB colors and connecting hue relationships. Base remains identifiable. Monochromatic marker layout must distinguish its lightness shades rather than overpaint coincident same-hue dots. Neutrals have no fake hue angle: use a neutral/lightness indication instead and explain in readable text. Renderer may define focused geometry helpers if tested/needed, but no package/assets/global infrastructure.
- Layout adaptively within parent width (root max640); use theme neutral chrome and existing tokens. Base/mode/colors semantic description exposes actual HEX colors and neutral explanation, image not button; wheel has no interactive hit targets or fake drag affordance. Do not suppress text scaling or animate under reduced motion. Parent screen owns mode chips and tappable swatches.
- [ ] Tests first/RED then meaningful render/semantic tests across six modes and both themes, achromatic and mono inputs,360px/2x/reducedmotion and no canvas/layout exceptions. Verify actual painter output changes with base/mode/colors and semantics list exact given shades; do not merely assert mocked widget existence. Scoped tests/analyze/format and one full suite with transient integration failures reported. Report `docs/superpowers/plans/harmonies-task-3-report.md`. No subagents/Git/root/shared-state edits.

