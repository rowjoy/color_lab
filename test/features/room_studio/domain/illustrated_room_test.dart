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
);

void main() {
  const expectedDefaults = {
    'living': 'soft-linen',
    'bedroom': 'soft-linen',
    'study': 'quiet-sage',
    'dining': 'soft-linen',
    'kitchen': 'quiet-sage',
    'bathroom': 'airy-slate',
  };
  const expectedLooks = {
    'soft-linen': ['#F2E9DA', '#D8C7AC', '#A89073', '#5C554D'],
    'quiet-sage': ['#ECE9DF', '#B7C2A3', '#78866B', '#4E5B4A'],
    'airy-slate': ['#F2F4F3', '#C9D3D8', '#8396A5', '#3F5362'],
    'clay-and-cream': ['#F5EBDD', '#D79A7A', '#9B6553', '#5E4A42'],
    'mist-and-ink': ['#ECEFF1', '#B8C4CE', '#667989', '#263746'],
    'sunwashed-olive': ['#F3E7C7', '#D8B96A', '#8B8F58', '#4F5A3F'],
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

  test('catalog pins six ordered rooms and original starter looks', () {
    expect(IllustratedRoomCatalog.all.map((room) => room.id), [
      'living',
      'bedroom',
      'study',
      'dining',
      'kitchen',
      'bathroom',
    ]);

    for (final room in IllustratedRoomCatalog.all) {
      expect(room.id, matches(RegExp(r'^[a-z0-9-]+$')));
      expect(room.title.trim(), isNotEmpty);
      expect(room.summary.trim(), isNotEmpty);
      expect(room.assetPath, expectedAssets[room.id]);
      expect(room.defaultPaletteId, expectedDefaults[room.id]);
      expect(room.artboardWidth, 1200);
      expect(room.artboardHeight, 800);
      expect(room.aspectRatio, 1.5);
      expect(room.surfaceLabels.wall, 'Wall');
      expect(room.surfaceLabels.ceiling, 'Ceiling');
      expect(room.surfaceLabels.floor, 'Floor');
      expect(room.surfaceLabels.furniture, furnitureLabels[room.id]);
      expect(room.focalPoint.x, focalPoints[room.id]!.$1);
      expect(room.focalPoint.y, focalPoints[room.id]!.$2);
      expect(room.focalPoint.x, inInclusiveRange(-1, 1));
      expect(room.focalPoint.y, inInclusiveRange(-1, 1));
      expect(room.palettes.map((palette) => palette.id), [
        'soft-linen',
        'quiet-sage',
        'airy-slate',
        'clay-and-cream',
        'mist-and-ink',
        'sunwashed-olive',
      ]);

      for (final palette in room.palettes) {
        expect(palette.name.trim(), isNotEmpty);
        expect(palette.guidance.trim(), isNotEmpty);
        expect(
          [
            palette.colors.wall.hex,
            palette.colors.ceiling.hex,
            palette.colors.floor.hex,
            palette.colors.furniture.hex,
          ],
          expectedLooks[palette.id],
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
    }) => IllustratedRoomPalette(
      id: id,
      name: name,
      guidance: guidance,
      colors: _colors('#000000', '#111111', '#222222', '#333333'),
    );

    expect(() => create(id: ' '), throwsArgumentError);
    expect(() => create(name: ' '), throwsArgumentError);
    expect(() => create(guidance: ' '), throwsArgumentError);
  });
}
