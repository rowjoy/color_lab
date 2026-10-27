import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_edit_command.dart';
import 'package:color_lab/features/room_studio/domain/mask_edit_history.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';

import 'room_project_fixtures.dart';

MaskEditCommand historyEdit(
  int index, {
  int width = 2,
  int height = 2,
  int before = 1,
  int after = 4,
  int beforeIntent = 0,
  int afterIntent = 5,
}) => MaskEditCommand(
  width: width,
  height: height,
  indices: Uint32List.fromList([index]),
  beforeLabels: Uint8List.fromList([before]),
  afterLabels: Uint8List.fromList([after]),
  beforeIntent: Uint8List.fromList([beforeIntent]),
  afterIntent: Uint8List.fromList([afterIntent]),
);

RoomProjectSnapshot maskHistoryProjectFixture({int revision = 1}) {
  final first = historyEdit(0);
  final second = historyEdit(1, before: 2, after: 0, afterIntent: 1);
  return roomProjectFixture(revision: revision).copyWith(
    maskBytes: Uint8List.fromList([4, 2, 3, 4]),
    intent: MaskIntentBitmap.fromBytes(
      width: 2,
      height: 2,
      bytes: Uint8List.fromList([5, 0, 0, 0]),
    ),
    history: MaskEditHistory.fromStacks(
      width: 2,
      height: 2,
      undoStack: [first],
      redoStack: [second],
    ),
  );
}
