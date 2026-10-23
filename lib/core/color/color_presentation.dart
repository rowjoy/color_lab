import 'color_engine.dart';

Map<String, String> colorFormatValues(RgbColor color) {
  final hsl = color.toHsl();
  final hsv = color.toHsv();
  final cmyk = color.toCmyk();
  final lab = color.toLab();
  String percent(double v) => '${(v * 100).round()}%';
  return Map.unmodifiable({
    'HEX': color.hex,
    'RGB': '${color.red}, ${color.green}, ${color.blue}',
    'HSL':
        '${hsl.hue.round()}°, ${percent(hsl.saturation)}, ${percent(hsl.lightness)}',
    'HSV':
        '${hsv.hue.round()}°, ${percent(hsv.saturation)}, ${percent(hsv.value)}',
    'CMYK':
        '${percent(cmyk.cyan)}, ${percent(cmyk.magenta)}, ${percent(cmyk.yellow)}, ${percent(cmyk.key)}',
    'LAB':
        '${lab.lightness.toStringAsFixed(1)}, ${lab.a.toStringAsFixed(1)}, ${lab.b.toStringAsFixed(1)}',
  });
}

String formatColorShare(RgbColor color, {String? name}) => [
  name ?? 'Color',
  for (final entry in colorFormatValues(color).entries)
    '${entry.key}: ${entry.value}',
  'Created with Color Lab',
].join('\n');

/// A compact analogous/complementary strip; achromatic duplicates collapse.
List<RgbColor> detailHarmony(RgbColor color) {
  final hsl = color.toHsl();
  return List.unmodifiable({
    for (final rotation in [-30, 0, 30, 180])
      HslColor(
        (hsl.hue + rotation) % 360,
        hsl.saturation,
        hsl.lightness,
      ).toRgb(),
  });
}
