import '../../../core/color/color_models.dart';
import 'illustrated_room.dart';

final class SavedRoomDesign {
  SavedRoomDesign({
    required String id,
    required String name,
    required String templateId,
    required this.colors,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : id = _requiredText(id, 'id'),
       name = _validatedName(name),
       templateId = _requiredText(templateId, 'templateId'),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Must not be earlier than createdAt',
      );
    }
  }

  final String id;
  final String name;
  final String templateId;
  final IllustratedRoomColors colors;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SavedRoomDesign.fromMap(Map<dynamic, dynamic> map) {
    const keys = {
      'version',
      'id',
      'name',
      'templateId',
      'wall',
      'ceiling',
      'floor',
      'furniture',
      'createdAt',
      'updatedAt',
    };
    try {
      if (map.length != keys.length ||
          !map.keys.every(keys.contains) ||
          map['version'] != 1 ||
          map['version'] is! int ||
          map['id'] is! String ||
          map['name'] is! String ||
          map['templateId'] is! String ||
          map['wall'] is! String ||
          map['ceiling'] is! String ||
          map['floor'] is! String ||
          map['furniture'] is! String ||
          map['createdAt'] is! String ||
          map['updatedAt'] is! String) {
        throw const FormatException('Invalid saved room design schema.');
      }

      final createdAt = _canonicalUtc(map['createdAt'] as String);
      final updatedAt = _canonicalUtc(map['updatedAt'] as String);
      return SavedRoomDesign(
        id: map['id'] as String,
        name: map['name'] as String,
        templateId: map['templateId'] as String,
        colors: IllustratedRoomColors(
          wall: _canonicalColor(map['wall'] as String),
          ceiling: _canonicalColor(map['ceiling'] as String),
          floor: _canonicalColor(map['floor'] as String),
          furniture: _canonicalColor(map['furniture'] as String),
        ),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } on ArgumentError {
      throw const FormatException('Invalid saved room design metadata.');
    }
  }

  Map<String, Object> toMap() => Map.unmodifiable({
    'version': 1,
    'id': id,
    'name': name,
    'templateId': templateId,
    'wall': colors.wall.hex,
    'ceiling': colors.ceiling.hex,
    'floor': colors.floor.hex,
    'furniture': colors.furniture.hex,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  });

  @override
  bool operator ==(Object other) =>
      other is SavedRoomDesign &&
      id == other.id &&
      name == other.name &&
      templateId == other.templateId &&
      colors == other.colors &&
      createdAt == other.createdAt &&
      updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, templateId, colors, createdAt, updatedAt);
}

String _requiredText(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty');
  }
  return trimmed;
}

String _validatedName(String value) {
  final name = _requiredText(value, 'name');
  if (name.runes.length > 60) {
    throw ArgumentError.value(value, 'name', 'Must be at most 60 characters');
  }
  return name;
}

RgbColor _canonicalColor(String value) {
  if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
    throw const FormatException('Invalid saved room design color.');
  }
  return RgbColor.fromHex(value);
}

DateTime _canonicalUtc(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
    throw const FormatException('Invalid saved room design timestamp.');
  }
  return parsed;
}
