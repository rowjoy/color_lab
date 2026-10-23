import 'color_models.dart';

enum HarmonyMode {
  complementary('Complementary'),
  analogous('Analogous'),
  triadic('Triadic'),
  tetradic('Tetradic'),
  splitComplementary('Split complementary'),
  monochromatic('Monochromatic');

  const HarmonyMode(this.label);

  final String label;
}

/// Generates an opaque HSL harmony, retaining the exact base first.
///
/// Display-equivalent colors appear only once, in their first-seen order.
List<RgbColor> generateHarmony(
  RgbColor base, {
  HarmonyMode mode = HarmonyMode.complementary,
}) {
  final hsl = base.toHsl();
  final colors = <RgbColor>{base};
  if (mode == HarmonyMode.monochromatic) {
    for (final offset in [-.30, -.15, .15, .30]) {
      colors.add(
        HslColor(
          hsl.hue,
          hsl.saturation,
          (hsl.lightness + offset).clamp(0.0, 1.0),
        ).toRgb(),
      );
    }
  } else {
    final rotations = switch (mode) {
      HarmonyMode.complementary => [180],
      HarmonyMode.analogous => [-30, 30],
      HarmonyMode.triadic => [120, 240],
      HarmonyMode.tetradic => [90, 180, 270],
      HarmonyMode.splitComplementary => [150, 210],
      HarmonyMode.monochromatic => const <int>[],
    };
    for (final rotation in rotations) {
      colors.add(
        HslColor(
          (hsl.hue + rotation) % 360,
          hsl.saturation,
          hsl.lightness,
        ).toRgb(),
      );
    }
  }
  return List<RgbColor>.unmodifiable(colors);
}
