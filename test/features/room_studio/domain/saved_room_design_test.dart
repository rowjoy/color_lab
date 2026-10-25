import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
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

  test('version 1 record round-trips exactly', () {
    final saved = design();

    expect(saved.toMap(), canonical);
    expect(SavedRoomDesign.fromMap(canonical), saved);
    expect(SavedRoomDesign.fromMap(canonical).hashCode, saved.hashCode);
  });

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
}
