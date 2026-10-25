import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/color/color_models.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';

final class IllustratedRoomColorMapper extends ColorMapper {
  const IllustratedRoomColorMapper(this.draft);

  static const wallToken = 0xFFFF00A1;
  static const ceilingToken = 0xFF00E5FF;
  static const floorToken = 0xFFB7FF00;
  static const furnitureToken = 0xFF7A00FF;

  static final _grayscale = IllustratedRoomColors(
    wall: RgbColor.fromHex('#C8C8C8'),
    ceiling: RgbColor.fromHex('#F2F2F2'),
    floor: RgbColor.fromHex('#A9A9A9'),
    furniture: RgbColor.fromHex('#737373'),
  );

  final IllustratedRoomDraft draft;

  IllustratedRoomColors get effectiveColors => draft.colors ?? _grayscale;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final surface = switch (color.toARGB32()) {
      wallToken => IllustratedRoomSurface.wall,
      ceilingToken => IllustratedRoomSurface.ceiling,
      floorToken => IllustratedRoomSurface.floor,
      furnitureToken => IllustratedRoomSurface.furniture,
      _ => null,
    };
    if (surface != null) {
      return _materialColor(effectiveColors.colorFor(surface));
    }
    if (draft.mode == IllustratedRoomVisualMode.colored) return color;

    final value = color.toARGB32();
    final red = (value >> 16) & 0xFF;
    final green = (value >> 8) & 0xFF;
    final blue = value & 0xFF;
    final gray = (red * 299 + green * 587 + blue * 114) ~/ 1000;
    return Color.fromARGB((value >> 24) & 0xFF, gray, gray, gray);
  }

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomColorMapper && draft == other.draft;

  @override
  int get hashCode => draft.hashCode;
}

Color _materialColor(RgbColor color) => Color(0xFF000000 | color.value);
