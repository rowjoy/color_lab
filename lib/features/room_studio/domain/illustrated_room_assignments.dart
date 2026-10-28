import '../../../core/color/color_models.dart';
import '../../../core/vector_regions/domain/vector_region_geometry.dart';
import 'illustrated_room.dart';

/// Geometry-free membership, supplied explicitly without loading assets.
final class IllustratedRoomRegionMembership {
  IllustratedRoomRegionMembership({
    required Map<String, Iterable<String>> groups,
  }) : groups = Map.unmodifiable({
         for (final entry in groups.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }) {
    if (this.groups.length != groupIds.length ||
        !this.groups.keys.toSet().containsAll(groupIds)) {
      throw ArgumentError.value(
        groups,
        'groups',
        'Declare all four room groups',
      );
    }
    final mapping = <String, String>{};
    for (final entry in this.groups.entries) {
      if (entry.value.isEmpty) {
        throw ArgumentError.value(
          entry.key,
          'groups',
          'Groups must have members',
        );
      }
      for (final id in entry.value) {
        if (!_stableId.hasMatch(id) || mapping.containsKey(id)) {
          throw ArgumentError.value(
            id,
            'regionId',
            'Invalid or duplicate region',
          );
        }
        mapping[id] = entry.key;
      }
    }
    _regionGroups = Map.unmodifiable(mapping);
  }

  factory IllustratedRoomRegionMembership.fromRegions(
    Iterable<VectorRegionDefinition> regions,
  ) {
    final groups = {for (final id in groupIds) id: <String>[]};
    final seen = <String>{};
    for (final region in regions) {
      if (!_stableId.hasMatch(region.id) ||
          !seen.add(region.id) ||
          !groups.containsKey(region.groupId)) {
        throw ArgumentError.value(
          region.id,
          'regions',
          'Invalid region declaration',
        );
      }
      if (region.fillable) groups[region.groupId]!.add(region.id);
    }
    return IllustratedRoomRegionMembership(groups: groups);
  }

  static const groupIds = {'walls', 'ceiling', 'floor', 'furniture'};
  static final _stableId = RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$');

  static final living = IllustratedRoomRegionMembership(
    groups: {
      'walls': ['wall-back', 'wall-side', 'wall-accent'],
      'ceiling': ['ceiling'],
      'floor': ['floor'],
      'furniture': ['console', 'sofa', 'accent-chair', 'coffee-table'],
    },
  );

  static final bedroom = IllustratedRoomRegionMembership(
    groups: {
      'walls': ['wall-back', 'wall-side', 'wall-accent'],
      'ceiling': ['ceiling'],
      'floor': ['floor'],
      'furniture': [
        'wardrobe',
        'bedside-table-left',
        'bedside-table-right',
        'bed',
      ],
    },
  );

  /// Frozen Study identity contract; a JSON parity test prevents asset drift.
  static final study = IllustratedRoomRegionMembership(
    groups: {
      'walls': ['wall-back', 'wall-side', 'wall-accent'],
      'ceiling': ['ceiling'],
      'floor': ['floor'],
      'furniture': ['shelves', 'desk', 'chair'],
    },
  );

  static final dining = IllustratedRoomRegionMembership(
    groups: {
      'walls': ['wall-back', 'wall-side'],
      'ceiling': ['ceiling'],
      'floor': ['floor'],
      'furniture': [
        'sideboard',
        'chair-back-left',
        'chair-back-right',
        'chair-front-left',
        'chair-front-right',
        'dining-table',
      ],
    },
  );

  static final kitchen = IllustratedRoomRegionMembership(
    groups: {
      'walls': ['wall-back', 'wall-side', 'wall-accent'],
      'ceiling': ['ceiling'],
      'floor': ['floor'],
      'furniture': [
        'cabinet-upper-left',
        'cabinet-lower-left',
        'cabinet-upper-right',
        'cabinet-lower-right',
        'island',
      ],
    },
  );

  static final bathroom = IllustratedRoomRegionMembership(
    groups: {
      'walls': ['wall-back', 'wall-side', 'wall-accent'],
      'ceiling': ['ceiling'],
      'floor': ['floor'],
      'furniture': ['vanity', 'storage'],
    },
  );

  /// Transitional synthetic identities for templates still using the v1 mapper.
  /// These are group adapters, not authored vector-region identities.
  static final _legacyGroups = IllustratedRoomRegionMembership(
    groups: {
      'walls': ['legacy-wall'],
      'ceiling': ['legacy-ceiling'],
      'floor': ['legacy-floor'],
      'furniture': ['legacy-furniture'],
    },
  );

  static IllustratedRoomRegionMembership forTemplate(
    IllustratedRoomTemplate template,
  ) => switch (template.id) {
    'living' => living,
    'bedroom' => bedroom,
    'study' => study,
    'dining' => dining,
    'kitchen' => kitchen,
    'bathroom' => bathroom,
    _ => _legacyGroups,
  };

  final Map<String, List<String>> groups;
  late final Map<String, String> _regionGroups;

  String groupFor(String regionId) =>
      _regionGroups[regionId] ??
      (throw ArgumentError.value(regionId, 'regionId', 'Unknown room region'));

  List<String> membersOf(String groupId) =>
      groups[groupId] ??
      (throw ArgumentError.value(groupId, 'groupId', 'Unknown room group'));

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomRegionMembership &&
      _mapEquals(_regionGroups, other._regionGroups);

  @override
  int get hashCode => _mapHash(_regionGroups);
}

/// Copied colors only: no live palette or asset references cross this boundary.
final class IllustratedRoomAssignments {
  IllustratedRoomAssignments({
    required this.membership,
    required Map<String, RgbColor> groupColors,
    Map<String, RgbColor> regionOverrides = const {},
  }) : groupColors = Map.unmodifiable(groupColors),
       regionOverrides = Map.unmodifiable(regionOverrides) {
    if (this.groupColors.length != membership.groups.length ||
        !this.groupColors.keys.toSet().containsAll(membership.groups.keys)) {
      throw ArgumentError.value(
        groupColors,
        'groupColors',
        'Supply every declared group',
      );
    }
    for (final id in this.regionOverrides.keys) {
      membership.groupFor(id);
    }
  }

  factory IllustratedRoomAssignments.fromColors(
    IllustratedRoomColors colors, {
    required IllustratedRoomRegionMembership membership,
  }) => IllustratedRoomAssignments(
    membership: membership,
    groupColors: {
      'walls': colors.wall,
      'ceiling': colors.ceiling,
      'floor': colors.floor,
      'furniture': colors.furniture,
    },
  );

  final IllustratedRoomRegionMembership membership;
  final Map<String, RgbColor> groupColors;
  final Map<String, RgbColor> regionOverrides;

  RgbColor colorFor(String regionId) {
    final group = membership.groupFor(regionId);
    return regionOverrides[regionId] ?? groupColors[group]!;
  }

  IllustratedRoomAssignments setRegionColor(String regionId, RgbColor color) {
    final group = membership.groupFor(regionId);
    if (colorFor(regionId) == color) return this;
    final overrides = Map<String, RgbColor>.of(regionOverrides);
    if (groupColors[group] == color) {
      overrides.remove(regionId);
    } else {
      overrides[regionId] = color;
    }
    return copyWith(regionOverrides: overrides);
  }

  IllustratedRoomAssignments setGroupColor(String groupId, RgbColor color) {
    final members = membership.membersOf(groupId);
    final overrides = Map<String, RgbColor>.of(regionOverrides)
      ..removeWhere((id, _) => members.contains(id));
    final result = copyWith(
      groupColors: {...groupColors, groupId: color},
      regionOverrides: overrides,
    );
    return result == this ? this : result;
  }

  IllustratedRoomAssignments copyWith({
    Map<String, RgbColor>? groupColors,
    Map<String, RgbColor>? regionOverrides,
  }) => IllustratedRoomAssignments(
    membership: membership,
    groupColors: groupColors ?? this.groupColors,
    regionOverrides: regionOverrides ?? this.regionOverrides,
  );

  /// Schema-v1 group adapter. Per-region snapshots migrate to storage in Task 4.
  IllustratedRoomColors toLegacyColors() => IllustratedRoomColors(
    wall: groupColors['walls']!,
    ceiling: groupColors['ceiling']!,
    floor: groupColors['floor']!,
    furniture: groupColors['furniture']!,
  );

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomAssignments &&
      membership == other.membership &&
      _mapEquals(groupColors, other.groupColors) &&
      _mapEquals(regionOverrides, other.regionOverrides);

  @override
  int get hashCode =>
      Object.hash(membership, _mapHash(groupColors), _mapHash(regionOverrides));
}

bool _mapEquals<T>(Map<String, T> left, Map<String, T> right) =>
    left.length == right.length &&
    left.entries.every((entry) => right[entry.key] == entry.value);

int _mapHash<T>(Map<String, T> map) => Object.hashAllUnordered(
  map.entries.map((entry) => Object.hash(entry.key, entry.value)),
);
