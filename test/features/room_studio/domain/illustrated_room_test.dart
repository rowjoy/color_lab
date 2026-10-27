import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:flutter_test/flutter_test.dart';

IllustratedRoomColors _colors(
  String wall,
  String ceiling,
  String floor,
  String furniture,
) => IllustratedRoomColors(
  wall: RgbColor.fromHex(wall),
  ceiling: RgbColor.fromHex(ceiling),
  floor: RgbColor.fromHex(floor),
  furniture: RgbColor.fromHex(furniture),
);

IllustratedRoomPalette _palette({
  required String id,
  String? wall,
  String? ceiling,
  String? floor,
  String? furniture,
}) => IllustratedRoomPalette(
  id: id,
  name: 'Palette $id',
  guidance: 'A complete room palette.',
  colors: _colors(
    wall ?? '#123456',
    ceiling ?? '#234567',
    floor ?? '#345678',
    furniture ?? '#456789',
  ),
);

IllustratedRoomTemplate _template({
  String id = 'room',
  String title = 'Room',
  String summary = 'A test room.',
  String assetPath = 'assets/rooms/room.svg',
  String defaultPaletteId = 'first',
  Iterable<IllustratedRoomPalette>? palettes,
  IllustratedRoomSurfaceLabels surfaceLabels =
      const IllustratedRoomSurfaceLabels(
        wall: 'Wall',
        ceiling: 'Ceiling',
        floor: 'Floor',
        furniture: 'Furniture',
      ),
  IllustratedRoomFocalPoint focalPoint = const IllustratedRoomFocalPoint(
    x: 0,
    y: 0,
  ),
  int artboardWidth = 1200,
  int artboardHeight = 800,
  String paletteReviewLabel = 'Market guide - reviewed October 2026',
  String paletteSourceNote =
      'Display preview only; compare a physical swatch before purchase.',
}) => IllustratedRoomTemplate(
  id: id,
  title: title,
  summary: summary,
  assetPath: assetPath,
  defaultPaletteId: defaultPaletteId,
  palettes: palettes ?? [_palette(id: 'first')],
  surfaceLabels: surfaceLabels,
  focalPoint: focalPoint,
  artboardWidth: artboardWidth,
  artboardHeight: artboardHeight,
  paletteReviewLabel: paletteReviewLabel,
  paletteSourceNote: paletteSourceNote,
);

void main() {
  const expectedLooks = <String, Map<String, Object>>{
    'living': {
      'default': 'warm-natural',
      'warm-natural': ['#E6D8C3', '#F8F4EB', '#C5AD8A', '#7B5944'],
      'soft-botanical': ['#C4D3C1', '#F8F4EB', '#BEB2A2', '#9A7557'],
      'cool-airy': ['#D3E0E4', '#F7F5EF', '#B5BEC1', '#5F493F'],
      'soft-pink-earthy-neutrals': ['#E5C8BE', '#F8F4EB', '#C5AD8A', '#E1CCB7'],
      'coral-peach-layers': ['#E49473', '#F8F4EB', '#C5AD8A', '#F1BAA2'],
      'white-gentle-grey': ['#C8C8C6', '#F8F4EB', '#C5AD8A', '#E8E6E2'],
      'pink-lavender-pairing': ['#DFCAC9', '#F8F4EB', '#C5AD8A', '#D4C9CF'],
      'peach-coral-glow': ['#F1B89B', '#F8F4EB', '#C5AD8A', '#EDA28E'],
    },
    'bedroom': {
      'default': 'warm-natural',
      'warm-natural': ['#DED5C7', '#FAF6EE', '#C2A483', '#785747'],
      'soft-botanical': ['#C8D3C2', '#F8F4EC', '#BCA58A', '#80614E'],
      'cool-airy': ['#D4DFE4', '#F8F6F0', '#B7BEC1', '#67514B'],
    },
    'study': {
      'default': 'soft-botanical',
      'warm-natural': ['#E2D5BF', '#F8F4EB', '#C5AA84', '#72513D'],
      'soft-botanical': ['#B7C5B3', '#F8F4EB', '#C6AC84', '#654A39'],
      'cool-airy': ['#C7D6DF', '#F6F5F0', '#B7A083', '#465967'],
    },
    'dining': {
      'default': 'warm-natural',
      'warm-natural': ['#D5BCAA', '#FAF5EC', '#A98464', '#704C3B'],
      'soft-botanical': ['#C3D0BB', '#F8F4EA', '#AC9274', '#6E5242'],
      'cool-airy': ['#CFDCE0', '#F8F5EE', '#AA927D', '#5C4740'],
    },
    'kitchen': {
      'default': 'soft-botanical',
      'warm-natural': ['#E3D7C6', '#FAF8F2', '#BBAF9E', '#987454'],
      'soft-botanical': ['#D8E1D3', '#FAF8F2', '#B8B0A3', '#A7B39B'],
      'cool-airy': ['#D8E4E6', '#FBF9F4', '#B7C0C2', '#718184'],
    },
    'bathroom': {
      'default': 'cool-airy',
      'warm-natural': ['#E6DDD1', '#FBF9F4', '#C4B8AA', '#92745F'],
      'soft-botanical': ['#D4E0D7', '#FAFBF7', '#B8C2BA', '#789080'],
      'cool-airy': ['#D8E5E7', '#FBFBF8', '#B9C2C4', '#8A725F'],
    },
  };

  const expectedAssets = <String, String>{
    'living': 'assets/rooms/living_room.svg',
    'bedroom': 'assets/rooms/bedroom_room.svg',
    'study': 'assets/rooms/study_room.svg',
    'dining': 'assets/rooms/dining_room.svg',
    'kitchen': 'assets/rooms/kitchen_room.svg',
    'bathroom': 'assets/rooms/bathroom_room.svg',
  };

  const furnitureLabels = <String, String>{
    'living': 'Furniture',
    'bedroom': 'Bed & furniture',
    'study': 'Desk & furniture',
    'dining': 'Table & furniture',
    'kitchen': 'Cabinets',
    'bathroom': 'Vanity & storage',
  };

  const focalPoints = <String, (double, double)>{
    'living': (0, .08),
    'bedroom': (.05, .05),
    'study': (0, 0),
    'dining': (0, .08),
    'kitchen': (.05, 0),
    'bathroom': (-.05, .02),
  };

  test('catalog pins six ordered rooms and exact market-guided looks', () {
    expect(IllustratedRoomCatalog.all.map((room) => room.id), [
      'living',
      'bedroom',
      'study',
      'dining',
      'kitchen',
      'bathroom',
    ]);

    for (final room in IllustratedRoomCatalog.all) {
      final expected = expectedLooks[room.id]!;
      expect(room.id, matches(RegExp(r'^[a-z0-9-]+$')));
      expect(room.title.trim(), isNotEmpty);
      expect(room.summary.trim(), isNotEmpty);
      expect(room.assetPath, expectedAssets[room.id]);
      expect(room.defaultPaletteId, expected['default']);
      expect(room.artboardWidth, 1200);
      expect(room.artboardHeight, 800);
      expect(room.aspectRatio, 1.5);
      expect(room.surfaceLabels.wall, 'Wall');
      expect(room.surfaceLabels.ceiling, 'Ceiling');
      expect(room.surfaceLabels.floor, 'Floor');
      expect(room.surfaceLabels.furniture, furnitureLabels[room.id]);
      expect(room.paletteReviewLabel, 'Market guide - reviewed October 2026');
      expect(room.paletteSourceNote.toLowerCase(), contains('display preview'));
      expect(room.paletteSourceNote.toLowerCase(), contains('physical swatch'));
      expect(room.focalPoint.x, focalPoints[room.id]!.$1);
      expect(room.focalPoint.y, focalPoints[room.id]!.$2);
      expect(room.focalPoint.x, inInclusiveRange(-1, 1));
      expect(room.focalPoint.y, inInclusiveRange(-1, 1));
      expect(
        room.palettes.map((palette) => palette.id),
        expected.keys.where((key) => key != 'default'),
      );

      for (final palette in room.palettes) {
        expect(palette.name.trim(), isNotEmpty);
        expect(palette.guidance.trim(), isNotEmpty);
        expect(palette.provenance?.trim(), isNotEmpty);
        expect(
          [
            palette.colors.wall.hex,
            palette.colors.ceiling.hex,
            palette.colors.floor.hex,
            palette.colors.furniture.hex,
          ],
          expected[palette.id],
          reason: '${room.id}/${palette.id}',
        );
        expect(room.matchingPalette(palette.colors), same(palette));
      }
    }

    expect(
      IllustratedRoomCatalog.maybeById('study'),
      same(IllustratedRoomCatalog.study),
    );
    expect(IllustratedRoomCatalog.maybeById('future-room'), isNull);
  });

  test('catalog exposes five generic page-inspired look names', () {
    const newIds = [
      'soft-pink-earthy-neutrals',
      'coral-peach-layers',
      'white-gentle-grey',
      'pink-lavender-pairing',
      'peach-coral-glow',
    ];
    const expectedNames = [
      'Soft Pink with Earthy Neutrals',
      'Coral and Peach Layers',
      'White with Gentle Grey',
      'Pink and Lavender Pairing',
      'Peach and Coral Glow',
    ];
    final newPalettes = IllustratedRoomCatalog.living.palettes
        .where((palette) => newIds.contains(palette.id))
        .toList(growable: false);

    expect(newPalettes.map((palette) => palette.name), expectedNames);
  });

  test('catalog metadata omits paint branding, shade names and codes', () {
    const disallowedTerms = [
      'asian paints',
      'milkshake',
      'white clay',
      'timber glaze',
      'gossamer',
      'pink plume',
      'petal pink',
      'coral rocks',
      'peach carnation',
      'grey flannel',
      'quiet hush',
      'pink essence',
      'lavender laugh',
      'peach blossom',
      'rose glow',
    ];
    final paintCode = RegExp(r'\b(?:\d{4}|[0o]p\d{2})\b', caseSensitive: false);
    for (final room in IllustratedRoomCatalog.all) {
      for (final palette in room.palettes) {
        final metadata = [
          palette.name,
          palette.guidance,
          ?palette.provenance,
        ].join(' ').toLowerCase();
        for (final term in disallowedTerms) {
          expect(
            metadata,
            isNot(contains(term)),
            reason: '${room.id}/${palette.id}',
          );
        }
        expect(
          metadata,
          isNot(matches(paintCode)),
          reason: '${room.id}/${palette.id}',
        );
      }
    }
  });

  test(
    'surface labels and suggested colors preserve semantic palette order',
    () {
      final room = _template(
        palettes: [
          _palette(id: 'first', wall: '#111111'),
          _palette(id: 'repeat', wall: '#111111', ceiling: '#999999'),
          _palette(id: 'last', wall: '#222222'),
        ],
      );

      expect(IllustratedRoomSurface.values.map(room.surfaceLabels.labelFor), [
        'Wall',
        'Ceiling',
        'Floor',
        'Furniture',
      ]);
      expect(
        room
            .suggestedColors(IllustratedRoomSurface.wall)
            .map((color) => color.hex),
        ['#111111', '#222222'],
      );
      expect(room.matchingPalette(room.palette('repeat').colors)?.id, 'repeat');
      expect(
        room.matchingPalette(
          room.defaultPalette.colors.withColor(
            IllustratedRoomSurface.wall,
            RgbColor.fromHex('#FFFFFF'),
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'template rejects malformed or empty metadata and invalid identities',
    () {
      expect(() => _template(id: 'Bad ID'), throwsArgumentError);
      expect(() => _template(title: ' '), throwsArgumentError);
      expect(() => _template(summary: ' '), throwsArgumentError);
      expect(() => _template(assetPath: ' '), throwsArgumentError);
      expect(() => _template(paletteReviewLabel: ' '), throwsArgumentError);
      expect(() => _template(paletteSourceNote: ' '), throwsArgumentError);
      expect(() => _template(artboardWidth: 0), throwsArgumentError);
      expect(() => _template(artboardHeight: -1), throwsArgumentError);
      expect(
        () => _template(
          surfaceLabels: const IllustratedRoomSurfaceLabels(
            wall: ' ',
            ceiling: 'Ceiling',
            floor: 'Floor',
            furniture: 'Furniture',
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => _template(
          palettes: [
            _palette(id: 'first'),
            _palette(id: 'first'),
          ],
        ),
        throwsArgumentError,
      );
      expect(() => _template(defaultPaletteId: 'missing'), throwsArgumentError);
      expect(() => _template().palette('missing'), throwsArgumentError);
    },
  );

  test('palette rejects empty user-facing metadata', () {
    IllustratedRoomPalette create({
      String id = 'id',
      String name = 'Name',
      String guidance = 'Guidance',
      String? provenance,
    }) => IllustratedRoomPalette(
      id: id,
      name: name,
      guidance: guidance,
      provenance: provenance,
      colors: _colors('#000000', '#111111', '#222222', '#333333'),
    );

    expect(() => create(id: ' '), throwsArgumentError);
    expect(() => create(name: ' '), throwsArgumentError);
    expect(() => create(guidance: ' '), throwsArgumentError);
    expect(() => create(provenance: ' '), throwsArgumentError);
  });
}
