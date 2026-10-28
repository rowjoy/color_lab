import '../../../core/color/color_engine.dart';

final class LabDraft {
  const LabDraft({
    required this.hue,
    required this.saturation,
    required this.lightness,
  }) : assert(hue >= 0 && hue < 360),
       assert(saturation >= 0 && saturation <= 1),
       assert(lightness >= 0 && lightness <= 1);

  factory LabDraft.initial() {
    final value = RgbColor.fromHex('#B2A4D4').toHsl();
    return LabDraft(
      hue: value.hue,
      saturation: value.saturation,
      lightness: value.lightness,
    );
  }

  final double hue;
  final double saturation;
  final double lightness;

  RgbColor get color => HslColor(hue, saturation, lightness).toRgb();

  LabDraft copyWith({double? hue, double? saturation, double? lightness}) =>
      LabDraft(
        hue: hue ?? this.hue,
        saturation: saturation ?? this.saturation,
        lightness: lightness ?? this.lightness,
      );

  @override
  bool operator ==(Object other) =>
      other is LabDraft &&
      other.hue == hue &&
      other.saturation == saturation &&
      other.lightness == lightness;
  @override
  int get hashCode => Object.hash(hue, saturation, lightness);
}
