import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_edit_command.dart';
import 'package:color_lab/features/room_studio/domain/mask_edit_history.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/mask_edit_fixtures.dart';
import '../../../support/room_project_fixtures.dart';

MaskEditCommand large(int count) => MaskEditCommand(
  width: 4096,
  height: 1024,
  indices: Uint32List.fromList(List.generate(count, (i) => i)),
  beforeLabels: Uint8List(count),
  afterLabels: Uint8List.fromList(List.filled(count, 1)),
  beforeIntent: Uint8List(count),
  afterIntent: Uint8List.fromList(List.filled(count, 2)),
);

void main() {
  test(
    'empty history owns immutable dimension-aligned stacks and rejects impossible transitions',
    () {
      final snapshot = roomProjectFixture();
      expect(snapshot.history.canUndo, isFalse);
      expect(snapshot.history.canRedo, isFalse);
      expect(snapshot.history.byteLength, 0);
      expect(() => snapshot.history.undoStack.clear(), throwsUnsupportedError);
      expect(() => snapshot.history.redoStack.clear(), throwsUnsupportedError);
      final masks = MaskBitmap(width: 2, height: 2, labels: snapshot.maskBytes);
      expect(
        () => snapshot.history.undo(masks: masks, intent: snapshot.intent),
        throwsStateError,
      );
      expect(
        () => snapshot.history.redo(masks: masks, intent: snapshot.intent),
        throwsStateError,
      );
      expect(
        () => snapshot.copyWith(
          history: MaskEditHistory.empty(width: 1, height: 4),
        ),
        throwsArgumentError,
      );
      expect(
        () => snapshot.history.push(historyEdit(0, width: 1, height: 4)),
        throwsArgumentError,
      );
    },
  );

  test(
    'undo and redo move exact complete commands in deterministic order with immutable snapshots',
    () {
      final snapshot = maskHistoryProjectFixture();
      final original = snapshot.history;
      final masks = MaskBitmap(width: 2, height: 2, labels: snapshot.maskBytes);
      expect(original.byteLength, 16);
      expect(original.canUndo, isTrue);
      expect(original.canRedo, isTrue);
      final undo = original.undo(masks: masks, intent: snapshot.intent);
      expect(undo.result.masks.labels, [1, 2, 3, 4]);
      expect(undo.result.intent.bytes, [0, 0, 0, 0]);
      expect(undo.history.undoStack, isEmpty);
      expect(undo.history.redoStack, hasLength(2));
      expect(undo.history.redoStack.last, same(original.undoStack.last));
      final redo = undo.history.redo(
        masks: undo.result.masks,
        intent: undo.result.intent,
      );
      expect(redo.result.masks.labels, [4, 2, 3, 4]);
      expect(redo.result.intent.bytes, [5, 0, 0, 0]);
      expect(redo.history.undoStack.single, same(original.undoStack.single));
      final all = redo.history.redo(
        masks: redo.result.masks,
        intent: redo.result.intent,
      );
      expect(all.result.masks.labels, [4, 0, 3, 4]);
      expect(all.result.intent.bytes, [5, 1, 0, 0]);
      expect(all.history.redoStack, isEmpty);
      expect(all.history.byteLength, 16);
      expect(original.undoStack, hasLength(1));
      expect(original.redoStack, hasLength(1));
      final newer = original.push(
        historyEdit(2, before: 3, after: 2, afterIntent: 3),
      );
      expect(newer.redoStack, isEmpty);
      expect(newer.undoStack, hasLength(2));
      expect(original.redoStack, hasLength(1));
      expect(
        () => original.undo(
          masks: MaskBitmap(width: 2, height: 2, labels: Uint8List(4)),
          intent: snapshot.intent,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'twenty commands and combined stacks are counted with oldest whole-command eviction',
    () {
      final commands = List.generate(
        21,
        (i) => historyEdit(i, width: 30, height: 1, before: 0),
      );
      var history = MaskEditHistory.empty(width: 30, height: 1);
      for (final command in commands) {
        history = history.push(command);
      }
      expect(history.undoStack, commands.sublist(1));
      expect(history.byteLength, 160);
      final input = commands.sublist(0, 10);
      final redo = commands.sublist(10, 20).reversed.toList();
      final split = MaskEditHistory.fromStacks(
        width: 30,
        height: 1,
        undoStack: input,
        redoStack: redo,
      );
      input.clear();
      redo.clear();
      expect(split.undoStack, hasLength(10));
      expect(split.redoStack, hasLength(10));
      expect(split.byteLength, 160);
      expect(
        () => MaskEditHistory.fromStacks(
          width: 30,
          height: 1,
          undoStack: commands.sublist(0, 10),
          redoStack: commands.sublist(10),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    '16 MiB counts all five arrays across undo and redo and evicts only complete commands',
    () {
      final first = large(1000000);
      final second = large(1097152);
      final exact = MaskEditHistory.fromStacks(
        width: 4096,
        height: 1024,
        undoStack: [first],
        redoStack: [second],
      );
      expect(exact.byteLength, 16777216);
      final full = MaskEditHistory.empty(
        width: 4096,
        height: 1024,
      ).push(first).push(second);
      final over = full.push(historyEdit(0, width: 4096, height: 1024));
      expect(over.undoStack, [second, over.undoStack.last]);
      expect(over.byteLength, 8777224);
      expect(full.undoStack, [first, second]);
      final oversized = large(2097153);
      final cleared = full.push(oversized);
      expect(oversized.byteLength, 16777224);
      expect(cleared.undoStack, isEmpty);
      expect(cleared.redoStack, isEmpty);
      expect(cleared.byteLength, 0);
      expect(
        () => MaskEditHistory.fromStacks(
          width: 4096,
          height: 1024,
          undoStack: [oversized],
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'snapshot and draft preserve both stacks and intent and reject stale or misaligned history',
    () {
      final snapshot = maskHistoryProjectFixture();
      expect(
        snapshot.copyWith(name: 'Renamed').history,
        same(snapshot.history),
      );
      expect(
        () => snapshot.copyWith(maskBytes: Uint8List.fromList([1, 2, 3, 4])),
        throwsStateError,
      );
      final photo = PreparedPhoto(
        width: 2,
        height: 2,
        rgbaBytes: Uint8List(16),
        previewBytes: Uint8List(0),
        palette: const [],
      );
      final draft = RoomMaskDraft(
        photoId: 'photo-1',
        photo: photo,
        aiMasks: MaskBitmap(width: 2, height: 2, labels: snapshot.aiMaskBytes),
        masks: MaskBitmap(width: 2, height: 2, labels: snapshot.maskBytes),
        intent: snapshot.intent,
        history: snapshot.history,
        maskRevision: 2,
        changedFromAiCount: 2,
      );
      expect(draft.copyWith(colorRevision: 4).history, same(snapshot.history));
      expect(
        () => draft.copyWith(
          intent: MaskIntentBitmap.untouched(width: 1, height: 4),
        ),
        throwsArgumentError,
      );
      expect(
        draft.withColors(snapshot.variants.last.colors).history,
        same(snapshot.history),
      );
      expect(draft.withColors(snapshot.variants.last.colors).intent.bytes, [
        5,
        0,
        0,
        0,
      ]);
      expect(
        () => RoomMaskDraft(
          photoId: 'x',
          photo: photo,
          aiMasks: draft.aiMasks,
          masks: draft.masks,
          intent: snapshot.intent,
          history: MaskEditHistory.empty(width: 1, height: 4),
          maskRevision: 1,
          changedFromAiCount: 0,
        ),
        throwsArgumentError,
      );
    },
  );
}
