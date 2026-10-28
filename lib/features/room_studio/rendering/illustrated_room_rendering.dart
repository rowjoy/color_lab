import 'package:flutter/material.dart';

import '../../../core/color/color_models.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';

final _grayscale = IllustratedRoomColors(
  wall: RgbColor.fromHex('#C8C8C8'),
  ceiling: RgbColor.fromHex('#F2F2F2'),
  floor: RgbColor.fromHex('#A9A9A9'),
  furniture: RgbColor.fromHex('#737373'),
);

/// The one display projection used by canvas, semantics and export.
IllustratedRoomColors illustratedRoomEffectiveColors(
  IllustratedRoomDraft draft,
) => draft.displayAssignments?.toLegacyColors() ?? _grayscale;

/// Integer luminance is frozen to match the pre-region illustrated renderer.
Color illustratedRoomGrayscaleColor(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xFF;
  final green = (value >> 8) & 0xFF;
  final blue = value & 0xFF;
  final gray = (red * 299 + green * 587 + blue * 114) ~/ 1000;
  return Color.fromARGB((value >> 24) & 0xFF, gray, gray, gray);
}
