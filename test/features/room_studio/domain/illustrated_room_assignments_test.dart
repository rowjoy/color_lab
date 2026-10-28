import 'dart:io';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/vector_regions/data/vector_region_json_codec.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_assignments.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final study = IllustratedRoomCatalog.study;
  final red = RgbColor.fromHex('#AA1122');
  final blue = RgbColor.fromHex('#1122AA');
  final green = RgbColor.fromHex('#11AA22');

  IllustratedRoomAssignments base() => IllustratedRoomAssignments.fromColors(
    study.defaultPalette.colors,
    membership: IllustratedRoomRegionMembership.study,
  );

  // Mutations caught: stale hand-written membership; mutable membership aliases.
  test('all memberships match authored fill regions and catalogue paths', () {
    for (final template in IllustratedRoomCatalog.all) {
      final path = 'assets/rooms/regions/${template.id}_room.v1.json';
      expect(template.regionAssetPath, path, reason: template.id);
      final artwork = VectorRegionJsonCodec().decode(
        File(path).readAsStringSync(),
      );
      final fromArtwork = IllustratedRoomRegionMembership.fromRegions(
        artwork.regions,
      );
      expect(
        fromArtwork,
        IllustratedRoomRegionMembership.forTemplate(template),
        reason: template.id,
      );
      expect(artwork.id, template.id);
      expect(artwork.revision, 1);
    }
    final artwork = VectorRegionJsonCodec().decode(
      File('assets/rooms/regions/study_room.v1.json').readAsStringSync(),
    );
    final fromArtwork = IllustratedRoomRegionMembership.fromRegions(
      artwork.regions,
    );
    expect(
      () => IllustratedRoomRegionMembership.fromRegions([
        ...artwork.regions,
        artwork.regions.first,
      ]),
      throwsArgumentError,
    );
    expect(fromArtwork.membersOf('walls'), [
      'wall-back',
      'wall-side',
      'wall-accent',
    ]);
    expect(fromArtwork.membersOf('furniture'), ['shelves', 'desk', 'chair']);
    final walls = ['wall-back', 'wall-side', 'wall-accent'];
    final groups = <String, Iterable<String>>{
      'walls': walls,
      'ceiling': ['ceiling'],
      'floor': ['floor'],
      'furniture': ['shelves', 'desk', 'chair'],
    };
    final membership = IllustratedRoomRegionMembership(groups: groups);
    walls.clear();
    groups.clear();
    expect(membership, fromArtwork);
    expect(membership.hashCode, fromArtwork.hashCode);
    expect(() => membership.groups.clear(), throwsUnsupportedError);
    expect(() => membership.membersOf('walls').clear(), throwsUnsupportedError);
  });

  test('authored memberships freeze exact region order for every room', () {
    expect(IllustratedRoomRegionMembership.living.groups, {
      'walls': ['wall-back', 'wall-side', 'wall-accent'],
      'ceiling': ['ceiling'],
      'floor': ['floor'],
      'furniture': ['console', 'sofa', 'accent-chair', 'coffee-table'],
    });
    expect(IllustratedRoomRegionMembership.bedroom.membersOf('furniture'), [
      'wardrobe',
      'bedside-table-left',
      'bedside-table-right',
      'bed',
    ]);
    expect(IllustratedRoomRegionMembership.dining.groups['walls'], [
      'wall-back',
      'wall-side',
    ]);
    expect(IllustratedRoomRegionMembership.dining.membersOf('furniture'), [
      'sideboard',
      'chair-back-left',
      'chair-back-right',
      'chair-front-left',
      'chair-front-right',
      'dining-table',
    ]);
    expect(IllustratedRoomRegionMembership.kitchen.membersOf('furniture'), [
      'cabinet-upper-left',
      'cabinet-lower-left',
      'cabinet-upper-right',
      'cabinet-lower-right',
      'island',
    ]);
    expect(IllustratedRoomRegionMembership.bathroom.membersOf('furniture'), [
      'vanity',
      'storage',
    ]);
  });

  // Mutations caught: duplicate/invalid declarations accepted at the domain boundary.
  test(
    'membership rejects duplicate, missing, empty and unknown declarations',
    () {
      final groups = IllustratedRoomRegionMembership.study.groups;
      for (final invalid in <Map<String, Iterable<String>>>[
        {
          ...groups,
          'walls': ['wall-back', 'wall-back'],
        },
        {
          ...groups,
          'floor': ['desk'],
        },
        {...groups, 'walls': []},
        {...groups}..remove('ceiling'),
        {
          ...groups,
          'unknown': ['other'],
        },
        {
          ...groups,
          'walls': ['Bad ID'],
        },
        {
          ...groups,
          'walls': [''],
        },
      ]) {
        expect(
          () => IllustratedRoomRegionMembership(groups: invalid),
          throwsArgumentError,
        );
      }
    },
  );

  // Mutations caught: first region edit updates its entire group or reseeds later edits.
  test(
    'first region edit seeds once and overrides only the selected region',
    () {
      final fresh = IllustratedRoomDraft.grayscale(study);
      final first = fresh.setRegionColor('wall-side', red);
      expect(first.assignments!.groupColors.map((k, v) => MapEntry(k, v.hex)), {
        'walls': '#ECE9DF',
        'ceiling': '#B7C2A3',
        'floor': '#78866B',
        'furniture': '#4E5B4A',
      });
      expect(first.assignments!.regionOverrides, {'wall-side': red});
      expect(first.assignments!.colorFor('wall-back').hex, '#ECE9DF');
      expect(first.assignments!.colorFor('wall-side'), red);
      expect(first.sourcePaletteId, isNull);
      expect(first.visualStateLabel, 'Custom combination');
      final next = first.setRegionColor('desk', blue);
      expect(next.assignments!.groupColors, first.assignments!.groupColors);
      expect(next.assignments!.regionOverrides, {
        'wall-side': red,
        'desk': blue,
      });
      expect(fresh.assignments, isNull);
    },
  );

  // Mutations caught: All Walls/Furniture edits delete unrelated overrides or miss members.
  test(
    'All Walls changes exactly three walls and preserves unrelated overrides',
    () {
      final before = base()
          .setRegionColor('wall-side', red)
          .setRegionColor('desk', blue)
          .setRegionColor('floor', green);
      final after = before.setGroupColor('walls', green);
      expect(after.regionOverrides, {'desk': blue, 'floor': green});
      for (final id in ['wall-back', 'wall-side', 'wall-accent']) {
        expect(after.colorFor(id), green);
      }
      for (final id in ['ceiling', 'floor', 'desk', 'chair', 'shelves']) {
        expect(after.colorFor(id), before.colorFor(id));
      }
      expect(before.regionOverrides['wall-side'], red);
    },
  );

  test('Furniture changes only desk chair shelves', () {
    final before = base()
        .setRegionColor('wall-accent', red)
        .setRegionColor('chair', blue);
    final after = before.setGroupColor('furniture', green);
    expect(after.regionOverrides, {'wall-accent': red});
    for (final id in ['desk', 'chair', 'shelves']) {
      expect(after.colorFor(id), green);
    }
    for (final id in [
      'wall-back',
      'wall-side',
      'wall-accent',
      'ceiling',
      'floor',
    ]) {
      expect(after.colorFor(id), before.colorFor(id));
    }
  });

  // Mutations caught: shallow copies, order-sensitive equality/hash, missing validation.
  test(
    'assignments and copies defensively freeze exact maps with value equality',
    () {
      final groups = Map<String, RgbColor>.of(base().groupColors);
      final overrides = {'desk': blue};
      final snapshot = IllustratedRoomAssignments(
        membership: IllustratedRoomRegionMembership.study,
        groupColors: groups,
        regionOverrides: overrides,
      );
      groups['walls'] = red;
      overrides.clear();
      expect(snapshot.colorFor('wall-back').hex, '#ECE9DF');
      expect(snapshot.colorFor('desk'), blue);
      expect(() => snapshot.groupColors.clear(), throwsUnsupportedError);
      expect(() => snapshot.regionOverrides.clear(), throwsUnsupportedError);
      final copy = snapshot.copyWith(
        groupColors: Map.fromEntries(
          snapshot.groupColors.entries.toList().reversed,
        ),
      );
      expect(copy, snapshot);
      expect(copy.hashCode, snapshot.hashCode);
      expect(snapshot.copyWith(regionOverrides: {}), base());
      expect(
        snapshot.copyWith(regionOverrides: {'chair': red}),
        isNot(snapshot),
      );
      expect(snapshot.toLegacyColors(), study.defaultPalette.colors);
    },
  );

  test('invalid lookup edit and incomplete snapshot IDs are rejected', () {
    final assignment = base();
    for (final id in ['', 'missing', 'Walls', 'wall']) {
      expect(() => assignment.colorFor(id), throwsArgumentError);
      expect(() => assignment.setRegionColor(id, red), throwsArgumentError);
      expect(() => assignment.setGroupColor(id, red), throwsArgumentError);
    }
    expect(
      () => assignment.copyWith(regionOverrides: {'missing': red}),
      throwsArgumentError,
    );
    expect(
      () => assignment.copyWith(groupColors: {'walls': red}),
      throwsArgumentError,
    );
    expect(
      () => assignment.copyWith(
        groupColors: {...assignment.groupColors, 'missing': red},
      ),
      throwsArgumentError,
    );
  });
}
