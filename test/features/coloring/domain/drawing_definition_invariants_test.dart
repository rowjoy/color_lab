import 'dart:ui';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/vector_regions/domain/vector_region_geometry.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:flutter_test/flutter_test.dart';

// These reject definitions that could bind progress or target colors to the
// wrong artwork, independently of the shared JSON path-validation tests.
void main() {
  for (final mismatch in ['id', 'revision']) {
    test('rejects catalog/artwork $mismatch mismatch', () {
      expect(
        () => _drawing(
          id: mismatch == 'id' ? 'another_drawing' : 'fixture',
          revision: mismatch == 'revision' ? 2 : 1,
        ),
        throwsFormatException,
      );
    });
  }

  for (final field in ['title', 'description']) {
    test('rejects blank $field', () {
      expect(
        () => _drawing(
          title: field == 'title' ? '  ' : 'Fixture',
          description: field == 'description' ? '\n' : 'Three regions.',
        ),
        throwsFormatException,
      );
    });
  }

  for (final count in [0, 2, 6]) {
    test('rejects $count target slots', () {
      expect(
        () => _drawing(
          slots: List.generate(
            count,
            (index) => DrawingColorSlot(
              id: 'slot-$index',
              label: 'Slot $index',
              color: RgbColor(10, 20, 30),
            ),
          ),
        ),
        throwsFormatException,
      );
    });
  }

  for (final badSlot in [
    DrawingColorSlot(id: 'first', label: 'Duplicate', color: RgbColor(1, 2, 3)),
    DrawingColorSlot(id: 'Bad ID', label: 'Unstable', color: RgbColor(1, 2, 3)),
    DrawingColorSlot(id: 'third', label: '  ', color: RgbColor(1, 2, 3)),
  ]) {
    test(
      'rejects invalid or duplicate slot ${badSlot.id}/${badSlot.label}',
      () {
        expect(
          () => _drawing(slots: [..._slots().take(2), badSlot]),
          throwsFormatException,
        );
      },
    );
  }

  test('rejects missing, extra, and unknown region rule keys', () {
    final missing = _rules()..remove('third');
    final extra = _rules()
      ..['other'] = const DrawingRegionRule(
        regionId: 'other',
        targetSlotId: 'first',
        required: true,
      );
    final unknown = _rules()
      ..remove('third')
      ..['other'] = const DrawingRegionRule(
        regionId: 'other',
        targetSlotId: 'first',
        required: true,
      );
    for (final rules in [missing, extra, unknown]) {
      expect(() => _drawing(rules: rules), throwsFormatException);
    }
  });

  for (final invalid in [
    const DrawingRegionRule(
      regionId: 'second',
      targetSlotId: 'first',
      required: true,
    ),
    const DrawingRegionRule(
      regionId: 'first',
      targetSlotId: 'unknown',
      required: true,
    ),
    const DrawingRegionRule(
      regionId: 'first',
      targetSlotId: null,
      required: true,
    ),
    const DrawingRegionRule(
      regionId: 'first',
      targetSlotId: 'unknown',
      required: false,
    ),
  ]) {
    test(
      'rejects invalid rule ${invalid.regionId}/${invalid.targetSlotId}/${invalid.required}',
      () {
        expect(
          () => _drawing(rules: _rules()..['first'] = invalid),
          throwsFormatException,
        );
      },
    );
  }

  test('rejects duplicate artwork region identities', () {
    expect(
      () => _drawing(artwork: _artwork(ids: ['first', 'first', 'third'])),
      throwsFormatException,
    );
  });

  test('optional unassigned regions retain their shared path and rule', () {
    final artwork = _artwork();
    final drawing = _drawing(
      artwork: artwork,
      rules: _rules()
        ..['third'] = const DrawingRegionRule(
          regionId: 'third',
          targetSlotId: null,
          required: false,
        ),
    );
    expect(drawing.artwork, same(artwork));
    expect(drawing.regionRules['third']!.required, isFalse);
    expect(drawing.regionRules['third']!.targetSlotId, isNull);
    expect(
      drawing.artwork.regions.last.geometry.toPath().contains(
        const Offset(70, 10),
      ),
      isTrue,
    );
  });

  test('caller mutation cannot change authored targets or rule ownership', () {
    final slots = _slots();
    final rules = _rules();
    final drawing = _drawing(slots: slots, rules: rules);
    slots.clear();
    rules.clear();
    expect(drawing.slots.map((slot) => slot.id), ['first', 'second', 'third']);
    expect(drawing.slotById('second').color.hex, '#445566');
    expect(drawing.regionRules.keys, ['first', 'second', 'third']);
    expect(() => drawing.slots.clear(), throwsUnsupportedError);
    expect(() => drawing.regionRules.clear(), throwsUnsupportedError);
  });
}

DrawingDefinition _drawing({
  String id = 'fixture',
  int revision = 1,
  String title = 'Fixture',
  String description = 'Three regions.',
  VectorArtworkDefinition? artwork,
  List<DrawingColorSlot>? slots,
  Map<String, DrawingRegionRule>? rules,
}) => DrawingDefinition(
  id: id,
  revision: revision,
  title: title,
  description: description,
  category: DrawingCategory.fruit,
  difficulty: DrawingDifficulty.easy,
  artwork: artwork ?? _artwork(),
  slots: slots ?? _slots(),
  regionRules: rules ?? _rules(),
);

List<DrawingColorSlot> _slots() => [
  DrawingColorSlot(
    id: 'first',
    label: 'First',
    color: RgbColor.fromHex('#112233'),
  ),
  DrawingColorSlot(
    id: 'second',
    label: 'Second',
    color: RgbColor.fromHex('#445566'),
  ),
  DrawingColorSlot(
    id: 'third',
    label: 'Third',
    color: RgbColor.fromHex('#778899'),
  ),
];

Map<String, DrawingRegionRule> _rules() => {
  for (final id in ['first', 'second', 'third'])
    id: DrawingRegionRule(regionId: id, targetSlotId: id, required: true),
};

VectorArtworkDefinition _artwork({
  List<String> ids = const ['first', 'second', 'third'],
}) => VectorArtworkDefinition(
  id: 'fixture',
  revision: 1,
  intrinsicSize: const Size(100, 100),
  regions: [
    for (var index = 0; index < ids.length; index++)
      VectorRegionDefinition(
        id: ids[index],
        labelKey: 'coloringRegion${index + 1}',
        groupId: 'drawing',
        fillable: true,
        paintOrder: index,
        geometry: VectorRegionGeometry(
          parts: [
            VectorRegionPart(
              slot: index,
              commands: [
                ['M', index * 30, 0],
                ['L', index * 30 + 20, 0],
                ['L', index * 30 + 20, 20],
                ['L', index * 30, 20],
                ['Z'],
              ],
            ),
          ],
        ),
      ),
  ],
);
