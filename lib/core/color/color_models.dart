import 'dart:math' as math;

void _unit(double value, String name) => _range(value, name, 0, 1);

void _range(double value, String name, double min, double max) {
  if (!value.isFinite || value < min || value > max) {
    throw ArgumentError.value(
      value,
      name,
      'Must be finite and in [$min, $max]',
    );
  }
}

void _hue(double value) {
  if (!value.isFinite || value < 0 || value >= 360) {
    throw ArgumentError.value(value, 'hue', 'Must be finite and in [0, 360)');
  }
}

int _channel(double value) => (value * 255).round().clamp(0, 255);

/// An opaque sRGB color with integer display channels.
final class RgbColor {
  RgbColor(this.red, this.green, this.blue) {
    for (final channel in [red, green, blue]) {
      if (channel < 0 || channel > 255) {
        throw ArgumentError.value(channel, 'channel', 'Must be in [0, 255]');
      }
    }
  }

  factory RgbColor.fromHex(String hex) {
    if (!RegExp(r'^#?(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(hex)) {
      throw FormatException('Expected RGB or RRGGBB with an optional #', hex);
    }
    var digits = hex.startsWith('#') ? hex.substring(1) : hex;
    if (digits.length == 3) {
      digits = digits.split('').map((digit) => '$digit$digit').join();
    }
    final value = int.parse(digits, radix: 16);
    return RgbColor(value >> 16, (value >> 8) & 255, value & 255);
  }

  final int red;
  final int green;
  final int blue;

  int get value => (red << 16) | (green << 8) | blue;
  String get hex => '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';

  RgbColor copyWith({int? red, int? green, int? blue}) =>
      RgbColor(red ?? this.red, green ?? this.green, blue ?? this.blue);

  HslColor toHsl() {
    final r = red / 255;
    final g = green / 255;
    final b = blue / 255;
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final delta = max - min;
    final lightness = (max + min) / 2;
    if (delta == 0) return HslColor(0, 0, lightness);
    final saturation = delta / (1 - (2 * lightness - 1).abs());
    return HslColor(
      _rgbHue(r, g, b, max, delta),
      saturation.clamp(0, 1),
      lightness,
    );
  }

  HsvColor toHsv() {
    final r = red / 255;
    final g = green / 255;
    final b = blue / 255;
    final max = math.max(r, math.max(g, b));
    final delta = max - math.min(r, math.min(g, b));
    return HsvColor(
      delta == 0 ? 0 : _rgbHue(r, g, b, max, delta),
      max == 0 ? 0 : delta / max,
      max,
    );
  }

  CmykColor toCmyk() {
    final r = red / 255;
    final g = green / 255;
    final b = blue / 255;
    final max = math.max(r, math.max(g, b));
    if (max == 0) return CmykColor(0, 0, 0, 1);
    return CmykColor(
      (max - r) / max,
      (max - g) / max,
      (max - b) / max,
      1 - max,
    );
  }

  LabColor toLab() {
    double linear(int channel) {
      final v = channel / 255;
      return v <= .04045
          ? v / 12.92
          : math.pow((v + .055) / 1.055, 2.4).toDouble();
    }

    final r = linear(red);
    final g = linear(green);
    final b = linear(blue);
    final x = (.4124564 * r + .3575761 * g + .1804375 * b) / .95047;
    final y = .2126729 * r + .7151522 * g + .0721750 * b;
    final z = (.0193339 * r + .1191920 * g + .9503041 * b) / 1.08883;
    double f(double t) => t > 216 / 24389
        ? math.pow(t, 1 / 3).toDouble()
        : (24389 / 27 * t + 16) / 116;
    final fy = f(y);
    // The rounded standard matrix overshoots L*=100 at white by <0.000004.
    return LabColor(
      (116 * fy - 16).clamp(0, 100),
      500 * (f(x) - fy),
      200 * (fy - f(z)),
    );
  }

  @override
  bool operator ==(Object other) => other is RgbColor && value == other.value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'RgbColor($hex)';
}

double _rgbHue(double r, double g, double b, double max, double delta) {
  final sector = max == r
      ? (g - b) / delta
      : max == g
      ? (b - r) / delta + 2
      : (r - g) / delta + 4;
  return (sector * 60) % 360;
}

RgbColor _fromChroma(double hue, double chroma, double offset) {
  final x = chroma * (1 - ((hue / 60) % 2 - 1).abs());
  final (r, g, b) = switch (hue) {
    < 60 => (chroma, x, 0.0),
    < 120 => (x, chroma, 0.0),
    < 180 => (0.0, chroma, x),
    < 240 => (0.0, x, chroma),
    < 300 => (x, 0.0, chroma),
    _ => (chroma, 0.0, x),
  };
  return RgbColor(
    _channel(r + offset),
    _channel(g + offset),
    _channel(b + offset),
  );
}

final class HslColor {
  HslColor(double hue, this.saturation, this.lightness)
    : hue = saturation == 0 || lightness == 0 || lightness == 1 ? 0 : hue {
    _hue(hue);
    _unit(saturation, 'saturation');
    _unit(lightness, 'lightness');
  }
  final double hue;
  final double saturation;
  final double lightness;

  RgbColor toRgb() {
    final chroma = (1 - (2 * lightness - 1).abs()) * saturation;
    return _fromChroma(hue, chroma, lightness - chroma / 2);
  }

  @override
  bool operator ==(Object other) =>
      other is HslColor &&
      hue == other.hue &&
      saturation == other.saturation &&
      lightness == other.lightness;
  @override
  int get hashCode => Object.hash(hue, saturation, lightness);
}

final class HsvColor {
  HsvColor(double hue, this.saturation, this.value)
    : hue = saturation == 0 || value == 0 ? 0 : hue {
    _hue(hue);
    _unit(saturation, 'saturation');
    _unit(value, 'value');
  }
  final double hue;
  final double saturation;
  final double value;

  RgbColor toRgb() {
    final chroma = value * saturation;
    return _fromChroma(hue, chroma, value - chroma);
  }

  @override
  bool operator ==(Object other) =>
      other is HsvColor &&
      hue == other.hue &&
      saturation == other.saturation &&
      value == other.value;
  @override
  int get hashCode => Object.hash(hue, saturation, value);
}

final class CmykColor {
  CmykColor(this.cyan, this.magenta, this.yellow, this.key) {
    _unit(cyan, 'cyan');
    _unit(magenta, 'magenta');
    _unit(yellow, 'yellow');
    _unit(key, 'key');
  }
  final double cyan;
  final double magenta;
  final double yellow;
  final double key;

  RgbColor toRgb() => RgbColor(
    _channel((1 - cyan) * (1 - key)),
    _channel((1 - magenta) * (1 - key)),
    _channel((1 - yellow) * (1 - key)),
  );

  @override
  bool operator ==(Object other) =>
      other is CmykColor &&
      cyan == other.cyan &&
      magenta == other.magenta &&
      yellow == other.yellow &&
      key == other.key;
  @override
  int get hashCode => Object.hash(cyan, magenta, yellow, key);
}

/// CIE L*a*b* with the D65 2-degree reference white.
/// L* is in [0, 100]; a* and b* may be any finite coordinates.
final class LabColor {
  LabColor(this.lightness, this.a, this.b) {
    _range(lightness, 'lightness', 0, 100);
    if (!a.isFinite) throw ArgumentError.value(a, 'a', 'Must be finite');
    if (!b.isFinite) throw ArgumentError.value(b, 'b', 'Must be finite');
  }
  final double lightness;
  final double a;
  final double b;

  RgbColor toRgb() {
    final fy = (lightness + 16) / 116;
    double inverse(double t) =>
        t > 6 / 29 ? t * t * t : 3 * (6 / 29) * (6 / 29) * (t - 4 / 29);
    final x = .95047 * inverse(fy + a / 500);
    final y = inverse(fy);
    final z = 1.08883 * inverse(fy - b / 200);
    int compand(double v) {
      // Clamp in linear RGB before companding to avoid powers of negatives
      // and retain valid output for extreme but finite LAB coordinates.
      final bounded = v.clamp(0.0, 1.0);
      return _channel(
        bounded <= .0031308
            ? 12.92 * bounded
            : 1.055 * math.pow(bounded, 1 / 2.4) - .055,
      );
    }

    return RgbColor(
      compand(3.2404542 * x - 1.5371385 * y - .4985314 * z),
      compand(-.9692660 * x + 1.8760108 * y + .0415560 * z),
      compand(.0556434 * x - .2040259 * y + 1.0572252 * z),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LabColor &&
      lightness == other.lightness &&
      a == other.a &&
      b == other.b;
  @override
  int get hashCode => Object.hash(lightness, a, b);
}

/// Euclidean CIE76 distance in D65 LAB coordinates.
double deltaE76(LabColor first, LabColor second) {
  final dl = first.lightness - second.lightness;
  final da = first.a - second.a;
  final db = first.b - second.b;
  final scale = math.max(dl.abs(), math.max(da.abs(), db.abs()));
  if (scale == 0 || scale.isInfinite) return scale;
  final l = dl / scale;
  final a = da / scale;
  final b = db / scale;
  return scale * math.sqrt(l * l + a * a + b * b);
}

final class NamedColor {
  NamedColor(String name, this.color)
    : name = name.trim(),
      lab = color.toLab() {
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty');
    }
  }
  final String name;
  final RgbColor color;
  final LabColor lab;

  @override
  bool operator ==(Object other) =>
      other is NamedColor && name == other.name && color == other.color;
  @override
  int get hashCode => Object.hash(name, color);
}

final class PaletteColor {
  PaletteColor(this.color, this.population) {
    _unit(population, 'population');
  }
  final RgbColor color;
  final double population;

  @override
  bool operator ==(Object other) =>
      other is PaletteColor &&
      color == other.color &&
      population == other.population;
  @override
  int get hashCode => Object.hash(color, population);
}
