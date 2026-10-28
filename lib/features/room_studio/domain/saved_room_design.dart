import '../../../core/color/color_models.dart';
import 'illustrated_room.dart';
import 'illustrated_room_assignments.dart';

/// Storage-only copied HEX values. Unknown template/region identities survive
/// decoding; membership is validated only when materializing an editor draft.
final class RoomDesignSnapshot {
  RoomDesignSnapshot({
    required Map<String, String> groupColors,
    Map<String, String> regionOverrides = const {},
  }) : groupColors = Map.unmodifiable(groupColors),
       regionOverrides = Map.unmodifiable(regionOverrides) {
    if (this.groupColors.length != 4 ||
        !this.groupColors.keys.toSet().containsAll(
          IllustratedRoomRegionMembership.groupIds,
        )) {
      throw const FormatException('Invalid room groups.');
    }
    for (final entry in this.groupColors.entries) {
      _canonicalColor(entry.value);
    }
    for (final entry in this.regionOverrides.entries) {
      if (!RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$').hasMatch(entry.key)) {
        throw const FormatException('Invalid region identity.');
      }
      _canonicalColor(entry.value);
    }
  }

  factory RoomDesignSnapshot.fromAssignments(
    IllustratedRoomAssignments value,
  ) => RoomDesignSnapshot(
    groupColors: value.groupColors.map(
      (key, color) => MapEntry(key, color.hex),
    ),
    regionOverrides: value.regionOverrides.map(
      (key, color) => MapEntry(key, color.hex),
    ),
  );
  factory RoomDesignSnapshot.fromColors(IllustratedRoomColors colors) =>
      RoomDesignSnapshot(
        groupColors: {
          'walls': colors.wall.hex,
          'ceiling': colors.ceiling.hex,
          'floor': colors.floor.hex,
          'furniture': colors.furniture.hex,
        },
      );
  factory RoomDesignSnapshot.fromMap(Map<dynamic, dynamic> map) {
    if (map.length != 2 ||
        !map.keys.toSet().containsAll({'groupColors', 'regionOverrides'})) {
      throw const FormatException('Invalid room snapshot.');
    }
    Map<String, String> colors(Object? value) {
      if (value is! Map ||
          value.entries.any((e) => e.key is! String || e.value is! String)) {
        throw const FormatException('Invalid room colors.');
      }
      return Map<String, String>.from(value);
    }

    return RoomDesignSnapshot(
      groupColors: colors(map['groupColors']),
      regionOverrides: colors(map['regionOverrides']),
    );
  }
  final Map<String, String> groupColors;
  final Map<String, String> regionOverrides;
  Map<String, Object> toMap() => Map.unmodifiable({
    'groupColors': groupColors,
    'regionOverrides': regionOverrides,
  });
  IllustratedRoomColors get colors => IllustratedRoomColors(
    wall: _canonicalColor(groupColors['walls']!),
    ceiling: _canonicalColor(groupColors['ceiling']!),
    floor: _canonicalColor(groupColors['floor']!),
    furniture: _canonicalColor(groupColors['furniture']!),
  );
  IllustratedRoomAssignments materialize(
    IllustratedRoomRegionMembership membership,
  ) => IllustratedRoomAssignments(
    membership: membership,
    groupColors: groupColors.map(
      (key, value) => MapEntry(key, _canonicalColor(value)),
    ),
    regionOverrides: regionOverrides.map(
      (key, value) => MapEntry(key, _canonicalColor(value)),
    ),
  );

  /// Materializes snapshots across the one-time legacy group-region adapter.
  ///
  /// Stored bytes remain untouched. Only the five templates that become
  /// region-aware in artwork revision 1 may translate an all-legacy override
  /// set. Mixed or unknown identities are rejected instead of guessed.
  IllustratedRoomAssignments materializeForTemplate(
    IllustratedRoomTemplate template, {
    int templateRevision = 1,
  }) {
    if (templateRevision != 1) {
      throw ArgumentError('Unsupported template revision.');
    }
    final membership = IllustratedRoomRegionMembership.forTemplate(template);
    if (regionOverrides.isEmpty) return materialize(membership);
    const migrated = {'living', 'bedroom', 'dining', 'kitchen', 'bathroom'};
    const legacyGroups = {
      'legacy-wall': 'walls',
      'legacy-ceiling': 'ceiling',
      'legacy-floor': 'floor',
      'legacy-furniture': 'furniture',
    };
    final keys = regionOverrides.keys.toSet();
    final hasLegacy = keys.any(legacyGroups.containsKey);
    if (!migrated.contains(template.id) || !hasLegacy) {
      return materialize(membership);
    }
    if (!keys.every(legacyGroups.containsKey)) {
      throw const FormatException(
        'Legacy and authored room overrides cannot be mixed.',
      );
    }
    final expanded = <String, RgbColor>{};
    for (final entry in regionOverrides.entries) {
      final groupId = legacyGroups[entry.key]!;
      final color = _canonicalColor(entry.value);
      for (final regionId in membership.membersOf(groupId)) {
        expanded[regionId] = color;
      }
    }
    return IllustratedRoomAssignments(
      membership: membership,
      groupColors: groupColors.map(
        (key, value) => MapEntry(key, _canonicalColor(value)),
      ),
      regionOverrides: expanded,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RoomDesignSnapshot &&
      _equal(groupColors, other.groupColors) &&
      _equal(regionOverrides, other.regionOverrides);
  @override
  int get hashCode => Object.hash(_hash(groupColors), _hash(regionOverrides));
}

final class SavedRoomDesign {
  SavedRoomDesign({
    required String id,
    required String name,
    required String templateId,
    IllustratedRoomColors? colors,
    RoomDesignSnapshot? snapshot,
    this.activeBaseline,
    this.templateRevision = 1,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : id = roomStorageIdentity(id),
       name = _validatedName(name),
       templateId = roomStorageIdentity(templateId),
       snapshot =
           snapshot ??
           RoomDesignSnapshot.fromColors(
             colors ?? (throw ArgumentError('Supply a snapshot.')),
           ),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    if (templateRevision < 1 || this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('Invalid room revision or timestamp order.');
    }
  }
  final String id;
  final String name;
  final String templateId;
  final int templateRevision;
  final RoomDesignSnapshot snapshot;
  final RoomDesignSnapshot? activeBaseline;
  IllustratedRoomColors get colors => snapshot.colors;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SavedRoomDesign.fromMap(Map<dynamic, dynamic> map) {
    const metadata = {
      'version',
      'id',
      'name',
      'templateId',
      'createdAt',
      'updatedAt',
    };
    const v1 = {...metadata, 'wall', 'ceiling', 'floor', 'furniture'};
    const v2 = {
      ...metadata,
      'templateRevision',
      'groupColors',
      'regionOverrides',
      'activeBaseline',
    };
    try {
      final version = map['version'];
      final keys = version == 1 ? v1 : v2;
      if (version is! int ||
          (version != 1 && version != 2) ||
          map.length != keys.length ||
          !map.keys.every(keys.contains) ||
          [
            'id',
            'name',
            'templateId',
            'createdAt',
            'updatedAt',
          ].any((key) => map[key] is! String) ||
          (map['name'] as String).trim() != map['name']) {
        throw const FormatException('Invalid saved room design schema.');
      }
      final snapshot = version == 1
          ? RoomDesignSnapshot.fromMap({
              'groupColors': {
                'walls': map['wall'],
                'ceiling': map['ceiling'],
                'floor': map['floor'],
                'furniture': map['furniture'],
              },
              'regionOverrides': <String, String>{},
            })
          : RoomDesignSnapshot.fromMap({
              'groupColors': map['groupColors'],
              'regionOverrides': map['regionOverrides'],
            });
      if (version == 2 &&
          (map['templateRevision'] is! int ||
              (map['activeBaseline'] != null &&
                  map['activeBaseline'] is! Map))) {
        throw const FormatException('Invalid saved room revision or baseline.');
      }
      return SavedRoomDesign(
        id: map['id'] as String,
        name: map['name'] as String,
        templateId: map['templateId'] as String,
        templateRevision: version == 1 ? 1 : map['templateRevision'] as int,
        snapshot: snapshot,
        activeBaseline: map['activeBaseline'] == null
            ? null
            : RoomDesignSnapshot.fromMap(map['activeBaseline'] as Map),
        createdAt: roomCanonicalUtc(map['createdAt'] as String),
        updatedAt: roomCanonicalUtc(map['updatedAt'] as String),
      );
    } on ArgumentError {
      throw const FormatException('Invalid saved room metadata.');
    }
  }
  Map<String, Object?> toMap() => Map.unmodifiable({
    'version': 2,
    'id': id,
    'name': name,
    'templateId': templateId,
    'templateRevision': templateRevision,
    ...snapshot.toMap(),
    'activeBaseline': activeBaseline?.toMap(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  });
  @override
  bool operator ==(Object other) =>
      other is SavedRoomDesign &&
      id == other.id &&
      name == other.name &&
      templateId == other.templateId &&
      templateRevision == other.templateRevision &&
      snapshot == other.snapshot &&
      activeBaseline == other.activeBaseline &&
      createdAt == other.createdAt &&
      updatedAt == other.updatedAt;
  @override
  int get hashCode => Object.hash(
    id,
    name,
    templateId,
    templateRevision,
    snapshot,
    activeBaseline,
    createdAt,
    updatedAt,
  );
}

String roomStorageIdentity(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$').hasMatch(value)) {
    throw ArgumentError('Invalid room identity.');
  }
  return value;
}

String _validatedName(String value) {
  final name = value.trim();
  if (name.isEmpty || name.runes.length > 60) {
    throw ArgumentError('Invalid room name.');
  }
  return name;
}

RgbColor _canonicalColor(String value) {
  if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
    throw const FormatException('Invalid room color.');
  }
  return RgbColor.fromHex(value);
}

DateTime roomCanonicalUtc(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
    throw const FormatException('Invalid room timestamp.');
  }
  return parsed;
}

bool _equal(Map<String, String> left, Map<String, String> right) =>
    left.length == right.length &&
    left.entries.every((e) => right[e.key] == e.value);
int _hash(Map<String, String> map) => Object.hashAllUnordered(
  map.entries.map((e) => Object.hash(e.key, e.value)),
);
