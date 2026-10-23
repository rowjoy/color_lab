import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all four room layers start unset', () {
    const colors = RoomLayerColors();

    expect(RoomLayer.values, hasLength(4));
    for (final layer in RoomLayer.values) {
      expect(colors.colorFor(layer), isNull);
    }
    expect(colors.hasAny, isFalse);
  });

  test('changing one layer preserves the other three', () {
    final wall = RgbColor.fromHex('#A7B5A0');
    final floor = RgbColor.fromHex('#D9BC9E');

    final colors = const RoomLayerColors()
        .withColor(RoomLayer.wall, wall)
        .withColor(RoomLayer.floor, floor);

    expect(colors.wall, wall);
    expect(colors.ceiling, isNull);
    expect(colors.floor, floor);
    expect(colors.furniture, isNull);
    expect(colors.hasAny, isTrue);
    expect(colors.withColor(RoomLayer.wall, wall), same(colors));
  });

  test('equal assignments have value equality and reset to empty', () {
    final lilac = RgbColor.fromHex('#C5B7D0');
    final first = const RoomLayerColors().withColor(RoomLayer.ceiling, lilac);
    final second = RoomLayerColors(ceiling: lilac);

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first.withColor(RoomLayer.ceiling, null), const RoomLayerColors());
  });
}
