import 'dart:convert';
import 'dart:io';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/data/illustrated_room_palette_catalog.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Catches reordered, substituted or mutable starter values at their consumer.
  test(
    'versioned starter catalogue supplies immutable localized snapshots',
    () {
      final file = File('assets/rooms/palettes/starter_palettes.v1.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Original starter catalogue missing',
      );
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['schemaVersion'], 1);
      expect(json['catalogueRevision'], 1);
      expect(json['roles'], ['wall', 'ceiling', 'floor', 'furniture']);
      const expected = {
        'soft-linen': ['#F2E9DA', '#D8C7AC', '#A89073', '#5C554D'],
        'quiet-sage': ['#ECE9DF', '#B7C2A3', '#78866B', '#4E5B4A'],
        'airy-slate': ['#F2F4F3', '#C9D3D8', '#8396A5', '#3F5362'],
        'clay-and-cream': ['#F5EBDD', '#D79A7A', '#9B6553', '#5E4A42'],
        'mist-and-ink': ['#ECEFF1', '#B8C4CE', '#667989', '#263746'],
        'sunwashed-olive': ['#F3E7C7', '#D8B96A', '#8B8F58', '#4F5A3F'],
      };
      final records = json['palettes'] as List;
      expect(records.map((r) => r['id']), expected.keys);
      expect(records.map((r) => r['id']).toSet(), hasLength(6));
      final arb =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
      final generated = File(
        'lib/l10n/generated/app_localizations.dart',
      ).readAsStringSync();
      for (final record in records) {
        expect(record['id'], matches(RegExp(r'^[a-z][a-z0-9-]*$')));
        expect(record['colors'], expected[record['id']]);
        for (final hex in record['colors'] as List) {
          expect(hex, matches(RegExp(r'^#[0-9A-F]{6}$')));
        }
        for (final field in ['nameKey', 'descriptionKey']) {
          expect(arb[record[field]], isA<String>());
          expect(arb['@${record[field]}'], isA<Map>());
          expect(generated, contains('get ${record[field]}'));
        }
      }
      expect(IllustratedRoomPaletteCatalog.all.map((r) => r.id), expected.keys);
      expect(
        () => IllustratedRoomPaletteCatalog.all.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => IllustratedRoomPaletteCatalog.roles.clear(),
        throwsUnsupportedError,
      );
      for (var index = 0; index < records.length; index++) {
        final record = IllustratedRoomPaletteCatalog.all[index];
        expect(record.schemaVersion, 1);
        expect(record.catalogueRevision, 1);
        expect(record.nameKey, records[index]['nameKey']);
        expect(record.descriptionKey, records[index]['descriptionKey']);
        expect(record.colors, expected[record.id]);
        expect(() => record.colors[0] = '#123456', throwsUnsupportedError);
      }
      for (final room in IllustratedRoomCatalog.all) {
        expect(room.palettes.map((p) => p.id), expected.keys);
        expect(() => room.palettes.clear(), throwsUnsupportedError);
        for (final palette in room.palettes) {
          expect(
            IllustratedRoomSurface.values.map(
              (s) => palette.colors.colorFor(s).hex,
            ),
            expected[palette.id],
          );
          final draft = IllustratedRoomDraft.grayscale(
            room,
          ).applyPalette(palette.id);
          final changed = draft.setSurfaceColor(
            IllustratedRoomSurface.wall,
            RgbColor.fromHex('#123456'),
          );
          expect(draft.colors, palette.colors);
          expect(changed.colors!.wall.hex, '#123456');
          expect(changed.colors!.ceiling, draft.colors!.ceiling);
          expect(palette.colors.wall.hex, expected[palette.id]!.first);
        }
      }
    },
  );

  test('opening a legacy saved design retains its explicit visible colors', () {
    final persisted = SavedRoomDesign.fromMap({
      'version': 1,
      'id': 'legacy-design',
      'name': 'My saved study',
      'templateId': 'study',
      'wall': '#B7C5B3',
      'ceiling': '#F8F4EB',
      'floor': '#C6AC84',
      'furniture': '#654A39',
      'createdAt': '2026-10-25T00:00:00.000Z',
      'updatedAt': '2026-10-25T00:00:00.000Z',
    });
    final saved = IllustratedRoomDraft.saved(
      template: IllustratedRoomCatalog.study,
      colors: persisted.colors,
      id: persisted.id,
      name: persisted.name,
    );
    expect(
      IllustratedRoomSurface.values.map((s) => saved.colors!.colorFor(s).hex),
      ['#B7C5B3', '#F8F4EB', '#C6AC84', '#654A39'],
    );
    expect(saved.isDirty, isFalse);
    expect(
      saved
          .setSurfaceColor(
            IllustratedRoomSurface.wall,
            RgbColor.fromHex('#123456'),
          )
          .discardChanges()
          .colors,
      saved.colors,
    );
  });
}
