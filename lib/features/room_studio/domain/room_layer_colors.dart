import '../../../core/color/color_models.dart';
import 'room_layer.dart';

/// One optional session-only color for each editable room surface.
final class RoomLayerColors {
  const RoomLayerColors({this.wall, this.ceiling, this.floor, this.furniture});

  final RgbColor? wall;
  final RgbColor? ceiling;
  final RgbColor? floor;
  final RgbColor? furniture;

  bool get hasAny =>
      wall != null || ceiling != null || floor != null || furniture != null;

  RgbColor? colorFor(RoomLayer layer) => switch (layer) {
    RoomLayer.wall => wall,
    RoomLayer.ceiling => ceiling,
    RoomLayer.floor => floor,
    RoomLayer.furniture => furniture,
  };

  RoomLayerColors withColor(RoomLayer layer, RgbColor? color) {
    if (colorFor(layer) == color) return this;
    return switch (layer) {
      RoomLayer.wall => RoomLayerColors(
        wall: color,
        ceiling: ceiling,
        floor: floor,
        furniture: furniture,
      ),
      RoomLayer.ceiling => RoomLayerColors(
        wall: wall,
        ceiling: color,
        floor: floor,
        furniture: furniture,
      ),
      RoomLayer.floor => RoomLayerColors(
        wall: wall,
        ceiling: ceiling,
        floor: color,
        furniture: furniture,
      ),
      RoomLayer.furniture => RoomLayerColors(
        wall: wall,
        ceiling: ceiling,
        floor: floor,
        furniture: color,
      ),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RoomLayerColors &&
      wall == other.wall &&
      ceiling == other.ceiling &&
      floor == other.floor &&
      furniture == other.furniture;

  @override
  int get hashCode => Object.hash(wall, ceiling, floor, furniture);
}
