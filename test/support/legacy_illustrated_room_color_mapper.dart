import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/rendering/illustrated_room_rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Test-only adapter for comparing migrated artwork with frozen pre-region SVGs.
final class LegacyIllustratedRoomColorMapper extends ColorMapper {
  const LegacyIllustratedRoomColorMapper(this.draft);

  static const wallToken = 0xFFFF00A1;
  static const ceilingToken = 0xFF00E5FF;
  static const floorToken = 0xFFB7FF00;
  static const furnitureToken = 0xFF7A00FF;

  final IllustratedRoomDraft draft;

  IllustratedRoomColors get effectiveColors =>
      illustratedRoomEffectiveColors(draft);

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
      return Color(0xFF000000 | effectiveColors.colorFor(surface).value);
    }
    return draft.displayMode == IllustratedRoomVisualMode.colored
        ? color
        : illustratedRoomGrayscaleColor(color);
  }
}
