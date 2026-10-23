import '../../../core/color/color_engine.dart';

enum ColorSource { manual, studio, lab, room, camera, gallery }

/// Immutable metadata for one opaque RGB color, identified by canonical HEX.
final class SavedColor {
  SavedColor({
    required String id,
    required String hex,
    required String name,
    required this.isFavorite,
    required DateTime createdAt,
    required this.source,
  }) : id = RgbColor.fromHex(id).hex,
       hex = RgbColor.fromHex(hex).hex,
       name = name.trim(),
       createdAt = createdAt.toUtc() {
    if (this.id != this.hex) {
      throw ArgumentError('Saved color identity must match its HEX.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be blank.');
    }
  }

  /// Reject unknown versions and malformed records instead of guessing defaults.
  factory SavedColor.fromMap(Map<dynamic, dynamic> map) {
    try {
      if (map['version'] is! int || map['version'] != 1) {
        throw const FormatException('Unsupported saved color schema.');
      }
      if (map['id'] is! String ||
          map['hex'] is! String ||
          map['name'] is! String ||
          map['isFavorite'] is! bool ||
          map['createdAt'] is! String ||
          map['source'] is! String) {
        throw const FormatException('Invalid saved color fields.');
      }
      final createdAt = DateTime.tryParse(map['createdAt'] as String);
      if (createdAt == null ||
          !createdAt.isUtc ||
          createdAt.toIso8601String() != map['createdAt']) {
        throw const FormatException('Invalid saved color creation date.');
      }
      final source = ColorSource.values.firstWhere(
        (source) => source.name == map['source'],
        orElse: () => throw const FormatException('Unknown color source.'),
      );
      final saved = SavedColor(
        id: map['id'] as String,
        hex: map['hex'] as String,
        name: map['name'] as String,
        isFavorite: map['isFavorite'] as bool,
        createdAt: createdAt,
        source: source,
      );
      if (saved.id != map['id'] || saved.hex != map['hex']) {
        throw const FormatException('Noncanonical saved color identity.');
      }
      return saved;
    } on ArgumentError {
      throw const FormatException('Invalid saved color metadata.');
    }
  }
  final String id;
  final String hex;
  final String name;
  final bool isFavorite;
  final DateTime createdAt;
  final ColorSource source;

  SavedColor copyWith({
    String? id,
    String? hex,
    String? name,
    bool? isFavorite,
    DateTime? createdAt,
    ColorSource? source,
  }) => SavedColor(
    id: id ?? this.id,
    hex: hex ?? this.hex,
    name: name ?? this.name,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt ?? this.createdAt,
    source: source ?? this.source,
  );

  Map<String, Object> toMap() => Map.unmodifiable({
    'version': 1,
    'id': id,
    'hex': hex,
    'name': name,
    'isFavorite': isFavorite,
    'createdAt': createdAt.toIso8601String(),
    'source': source.name,
  });

  @override
  bool operator ==(Object other) =>
      other is SavedColor &&
      id == other.id &&
      hex == other.hex &&
      name == other.name &&
      isFavorite == other.isFavorite &&
      createdAt == other.createdAt &&
      source == other.source;

  @override
  int get hashCode => Object.hash(id, hex, name, isFavorite, createdAt, source);
}
