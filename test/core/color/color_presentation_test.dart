import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/color/color_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail formats and sharing use the same actual color values', () {
    final red = RgbColor(255, 0, 0);
    final values = colorFormatValues(red);
    expect(values['HEX'], '#FF0000');
    expect(values['RGB'], '255, 0, 0');
    expect(values['HSL'], '0°, 100%, 50%');
    expect(values['HSV'], '0°, 100%, 100%');
    expect(values['CMYK'], '0%, 100%, 100%, 0%');
    expect(values['LAB'], '53.2, 80.1, 67.2');
    expect(
      formatColorShare(red, name: 'Red'),
      contains('Red\nHEX: #FF0000\nRGB: 255, 0, 0'),
    );
    expect(() => values.clear(), throwsUnsupportedError);
  });

  test('detail harmony rotates hue without inventing shades for gray', () {
    expect(detailHarmony(RgbColor(255, 0, 0)).map((c) => c.hex), [
      '#FF0080',
      '#FF0000',
      '#FF8000',
      '#00FFFF',
    ]);
    expect(detailHarmony(RgbColor(128, 128, 128)).map((c) => c.hex), [
      '#808080',
    ]);
  });
}
