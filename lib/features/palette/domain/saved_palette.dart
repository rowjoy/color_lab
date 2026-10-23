import '../../../core/color/color_engine.dart';

/// An immutable palette snapshot. Loading never regenerates saved colors.
final class SavedPalette {
  SavedPalette({
    required String name,
    required this.base,
    required this.mode,
    required Iterable<RgbColor> colors,
    required DateTime createdAt,
  }) : name = name.trim(),
       colors = List<RgbColor>.unmodifiable(colors),
       createdAt = createdAt.toUtc() {
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be blank.');
    }
    if (this.colors.isEmpty ||
        this.colors.length > 5 ||
        this.colors.first != base ||
        this.colors.toSet().length != this.colors.length) {
      throw ArgumentError(
        'A palette needs 1–5 distinct colors with base first.',
      );
    }
  }

  static String idFor(RgbColor base, HarmonyMode mode) =>
      '${mode.name}-${base.hex.substring(1)}';

  String get id => idFor(base, mode);
  final String name;
  final RgbColor base;
  final HarmonyMode mode;
  final List<RgbColor> colors;
  final DateTime createdAt;

  factory SavedPalette.fromMap(Map<dynamic, dynamic> map) {
    try {
      const keys = {
        'version',
        'id',
        'name',
        'base',
        'mode',
        'colors',
        'createdAt',
      };
      if (map.length != keys.length ||
          !map.keys.every(keys.contains) ||
          map['version'] is! int ||
          map['version'] != 1 ||
          map['id'] is! String ||
          map['name'] is! String ||
          map['base'] is! String ||
          map['mode'] is! String ||
          map['colors'] is! List ||
          map['createdAt'] is! String) {
        throw const FormatException('Invalid saved palette schema.');
      }
      RgbColor canonicalColor(dynamic value) {
        if (value is! String) {
          throw const FormatException('Invalid saved palette color.');
        }
        final color = RgbColor.fromHex(value);
        if (color.hex != value) {
          throw const FormatException('Noncanonical saved palette color.');
        }
        return color;
      }

      final createdAt = DateTime.tryParse(map['createdAt'] as String);
      if (createdAt == null ||
          !createdAt.isUtc ||
          createdAt.toIso8601String() != map['createdAt']) {
        throw const FormatException('Invalid saved palette creation date.');
      }
      final mode = HarmonyMode.values.firstWhere(
        (value) => value.name == map['mode'],
        orElse: () => throw const FormatException('Unknown harmony mode.'),
      );
      final saved = SavedPalette(
        name: map['name'] as String,
        base: canonicalColor(map['base']),
        mode: mode,
        colors: (map['colors'] as List).map(canonicalColor),
        createdAt: createdAt,
      );
      if (saved.id != map['id']) {
        throw const FormatException('Invalid saved palette identity.');
      }
      return saved;
    } on ArgumentError {
      throw const FormatException('Invalid saved palette metadata.');
    }
  }

  Map<String, Object> toMap() => Map<String, Object>.unmodifiable({
    'version': 1,
    'id': id,
    'name': name,
    'base': base.hex,
    'mode': mode.name,
    'colors': List<String>.unmodifiable(colors.map((color) => color.hex)),
    'createdAt': createdAt.toIso8601String(),
  });

  @override
  bool operator ==(Object other) =>
      other is SavedPalette &&
      name == other.name &&
      base == other.base &&
      mode == other.mode &&
      createdAt == other.createdAt &&
      colors.length == other.colors.length &&
      Iterable<int>.generate(
        colors.length,
      ).every((index) => colors[index] == other.colors[index]);

  @override
  int get hashCode =>
      Object.hash(name, base, mode, createdAt, Object.hashAll(colors));
}
