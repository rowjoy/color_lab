import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_assignments.dart';
import 'package:color_lab/features/room_studio/domain/recoverable_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 25, 4);
  final canonical = <String, Object>{
    'version': 1,
    'id': 'study-1792900800000000',
    'name': 'My focused study',
    'templateId': 'study',
    'wall': '#A7B5A0',
    'ceiling': '#F7F2E8',
    'floor': '#C9A77B',
    'furniture': '#5B4636',
    'createdAt': '2026-10-25T04:00:00.000Z',
    'updatedAt': '2026-10-25T04:00:00.000Z',
  };

  SavedRoomDesign design({
    String id = 'study-1792900800000000',
    String name = 'My focused study',
    String templateId = 'study',
    DateTime? created,
    DateTime? updated,
  }) => SavedRoomDesign(
    id: id,
    name: name,
    templateId: templateId,
    colors: IllustratedRoomColors(
      wall: RgbColor.fromHex('#A7B5A0'),
      ceiling: RgbColor.fromHex('#F7F2E8'),
      floor: RgbColor.fromHex('#C9A77B'),
      furniture: RgbColor.fromHex('#5B4636'),
    ),
    createdAt: created ?? createdAt,
    updatedAt: updated ?? createdAt,
  );

  test('version 1 reads migrate to version 2 without changing colors', () {
    final saved = design();

    expect(saved.toMap()['version'], 2);
    expect(saved.toMap()['groupColors'], {
      'walls': '#A7B5A0',
      'ceiling': '#F7F2E8',
      'floor': '#C9A77B',
      'furniture': '#5B4636',
    });
    expect(saved.toMap()['regionOverrides'], isEmpty);
    expect(saved.toMap()['activeBaseline'], isNull);
    expect(SavedRoomDesign.fromMap(canonical), saved);
    expect(SavedRoomDesign.fromMap(canonical).hashCode, saved.hashCode);
  });

  // Catches mutable snapshots, palette inference, lossy overrides and permissive v2 parsing.
  test(
    'v2 snapshots are strict immutable and independent of live membership',
    () {
      final groups = <String, String>{
        'walls': '#123456',
        'ceiling': '#ABCDEF',
        'floor': '#010203',
        'furniture': '#FFEEDD',
      };
      final overrides = <String, String>{'future-region': '#654321'};
      final snapshot = RoomDesignSnapshot(
        groupColors: groups,
        regionOverrides: overrides,
      );
      final saved = SavedRoomDesign(
        id: 'future-1',
        name: 'Future',
        templateId: 'future-room',
        templateRevision: 7,
        snapshot: snapshot,
        activeBaseline: snapshot,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      groups['walls'] = '#000000';
      overrides.clear();
      expect(saved.snapshot.groupColors['walls'], '#123456');
      expect(saved.snapshot.regionOverrides, {'future-region': '#654321'});
      expect(() => saved.snapshot.groupColors.clear(), throwsUnsupportedError);
      final map = saved.toMap();
      expect(
        map.keys,
        unorderedEquals([
          'version',
          'id',
          'name',
          'templateId',
          'templateRevision',
          'groupColors',
          'regionOverrides',
          'activeBaseline',
          'createdAt',
          'updatedAt',
        ]),
      );
      expect(SavedRoomDesign.fromMap(map), saved);
      expect(() => (map['groupColors'] as Map).clear(), throwsUnsupportedError);
      for (final patch in <Map<String, Object?>>[
        {'version': 3},
        {'version': 2.0},
        {'templateRevision': 0},
        {'templateRevision': 1.0},
        {
          'groupColors': {...snapshot.groupColors, 'walls': '#abcdef'},
        },
        {
          'groupColors': {...snapshot.groupColors}..remove('floor'),
        },
        {
          'regionOverrides': {'bad id': '#123456'},
        },
        {
          'activeBaseline': {'groupColors': snapshot.groupColors},
        },
        {'id': '@draft:study'},
        {'id': ' white '},
        {'sourcePaletteId': 'quiet-sage'},
        {'createdAt': '2026-10-25T04:00:00+00:00'},
        {'updatedAt': '2020-01-01T00:00:00.000Z'},
      ]) {
        expect(
          () => SavedRoomDesign.fromMap({...map, ...patch}),
          throwsFormatException,
          reason: '$patch',
        );
      }
    },
  );

  test('constructor trims names and preserves unknown template IDs', () {
    final saved = design(
      name: '  My focused study  ',
      templateId: 'future-library',
    );

    expect(saved.name, 'My focused study');
    expect(saved.templateId, 'future-library');
    expect(SavedRoomDesign.fromMap(saved.toMap()), saved);
  });

  test('name requires one to sixty Unicode scalar values', () {
    expect(() => design(name: '   '), throwsArgumentError);
    expect(
      () => design(name: List.filled(61, 'a').join()),
      throwsArgumentError,
    );
    expect(() => design(name: List.filled(60, '😀').join()), returnsNormally);
    expect(
      () => design(name: List.filled(61, '😀').join()),
      throwsArgumentError,
    );
  });

  test('identity and timestamp invariants are validated', () {
    expect(() => design(id: ' '), throwsArgumentError);
    expect(() => design(templateId: ' '), throwsArgumentError);
    expect(
      () =>
          design(updated: createdAt.subtract(const Duration(microseconds: 1))),
      throwsArgumentError,
    );
  });

  test('map accepts only canonical uppercase six-digit colors', () {
    for (final invalid in ['#a7b5a0', '#ABC', 'A7B5A0', '#GGGGGG']) {
      expect(
        () => SavedRoomDesign.fromMap({...canonical, 'wall': invalid}),
        throwsFormatException,
        reason: invalid,
      );
    }
    expect(
      () => SavedRoomDesign.fromMap({...canonical, 'wall': 0xA7B5A0}),
      throwsFormatException,
    );
  });

  test('map accepts only canonical UTC timestamps in chronological order', () {
    expect(
      () => SavedRoomDesign.fromMap({
        ...canonical,
        'createdAt': '2026-10-25T04:00:00+00:00',
      }),
      throwsFormatException,
    );
    expect(
      () => SavedRoomDesign.fromMap({
        ...canonical,
        'updatedAt': '2026-10-25T03:59:59.999Z',
      }),
      throwsFormatException,
    );
    expect(
      () => SavedRoomDesign.fromMap({...canonical, 'updatedAt': 'not-a-date'}),
      throwsFormatException,
    );
  });

  test('map schema rejects missing unexpected or mistyped values', () {
    expect(
      () => SavedRoomDesign.fromMap({...canonical, 'version': 2}),
      throwsFormatException,
    );
    expect(
      () => SavedRoomDesign.fromMap({...canonical, 'extra': true}),
      throwsFormatException,
    );
    expect(
      () => SavedRoomDesign.fromMap({...canonical}..remove('name')),
      throwsFormatException,
    );
    expect(
      () => SavedRoomDesign.fromMap({...canonical, 'templateId': 7}),
      throwsFormatException,
    );
    expect(
      () => SavedRoomDesign.fromMap({...canonical, 'name': '   '}),
      throwsFormatException,
    );
  });

  test(
    'five migrated templates expand legacy-only overrides without changing bytes',
    () {
      final groups = {
        'walls': '#101010',
        'ceiling': '#202020',
        'floor': '#303030',
        'furniture': '#404040',
      };
      final legacy = {
        'legacy-wall': '#AA0001',
        'legacy-ceiling': '#00AA02',
        'legacy-floor': '#0000AA',
        'legacy-furniture': '#A0A003',
      };
      final snapshot = RoomDesignSnapshot(
        groupColors: groups,
        regionOverrides: legacy,
      );
      final frozen = snapshot.toMap();
      for (final template in IllustratedRoomCatalog.all.where(
        (template) => template.id != 'study',
      )) {
        final membership = IllustratedRoomRegionMembership.forTemplate(
          template,
        );
        expect(() => snapshot.materialize(membership), throwsArgumentError);
        final restored = snapshot.materializeForTemplate(template);
        expect(restored.groupColors.map((k, v) => MapEntry(k, v.hex)), groups);
        for (final group in membership.groups.entries) {
          final legacyId = switch (group.key) {
            'walls' => 'legacy-wall',
            'ceiling' => 'legacy-ceiling',
            'floor' => 'legacy-floor',
            'furniture' => 'legacy-furniture',
            _ => throw StateError('Unexpected group'),
          };
          for (final regionId in group.value) {
            expect(
              restored.regionOverrides[regionId]?.hex,
              legacy[legacyId],
              reason: '${template.id}:$regionId',
            );
          }
        }
      }
      expect(snapshot.toMap(), frozen);
      expect(snapshot.regionOverrides, legacy);
    },
  );

  test(
    'template-aware migration rejects mixed unknown and unsupported input',
    () {
      final groups = {
        'walls': '#101010',
        'ceiling': '#202020',
        'floor': '#303030',
        'furniture': '#404040',
      };
      RoomDesignSnapshot snapshot(Map<String, String> overrides) =>
          RoomDesignSnapshot(groupColors: groups, regionOverrides: overrides);
      expect(
        () => snapshot({
          'legacy-wall': '#AA0001',
          'sofa': '#00AA02',
        }).materializeForTemplate(IllustratedRoomCatalog.living),
        throwsFormatException,
      );
      expect(
        () => snapshot({
          'legacy-wall': '#AA0001',
          'future-region': '#00AA02',
        }).materializeForTemplate(IllustratedRoomCatalog.living),
        throwsFormatException,
      );
      expect(
        () => snapshot({
          'legacy-wall': '#AA0001',
        }).materializeForTemplate(IllustratedRoomCatalog.study),
        throwsArgumentError,
      );
      expect(
        () => snapshot({'legacy-wall': '#AA0001'}).materializeForTemplate(
          IllustratedRoomCatalog.living,
          templateRevision: 2,
        ),
        throwsArgumentError,
      );
      final authored = snapshot({
        'sofa': '#AA0001',
      }).materializeForTemplate(IllustratedRoomCatalog.living);
      expect(authored.regionOverrides['sofa']?.hex, '#AA0001');
    },
  );

  test(
    'recoverable restoration migrates visible saved and pinned positions',
    () {
      RoomDesignSnapshot snapshot(String legacyId, String color) =>
          RoomDesignSnapshot(
            groupColors: {
              'walls': '#101010',
              'ceiling': '#202020',
              'floor': '#303030',
              'furniture': '#404040',
            },
            regionOverrides: {legacyId: color},
          );
      final record = RecoverableRoomDraft(
        templateId: 'living',
        visible: snapshot('legacy-wall', '#AA0001'),
        savedSnapshot: snapshot('legacy-furniture', '#00AA02'),
        activeBaseline: snapshot('legacy-floor', '#0000AA'),
        savedDesignId: 'living-saved',
        savedName: 'Living saved',
        updatedAt: createdAt,
      );
      final restored = record.restore(IllustratedRoomCatalog.living);
      for (final id in restored.membership.membersOf('walls')) {
        expect(restored.assignments!.regionOverrides[id]?.hex, '#AA0001');
      }
      for (final id in restored.membership.membersOf('furniture')) {
        expect(restored.savedAssignments!.regionOverrides[id]?.hex, '#00AA02');
      }
      for (final id in restored.membership.membersOf('floor')) {
        expect(restored.pinnedBaseline!.regionOverrides[id]?.hex, '#0000AA');
      }
      expect(
        RecoverableRoomDraft.fromMap(record.toMap()).toMap(),
        record.toMap(),
      );
    },
  );
}
