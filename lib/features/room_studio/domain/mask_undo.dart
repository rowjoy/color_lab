// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:typed_data';

import 'room_layer.dart';
import 'mask_bitmap.dart';
import 'mask_intent_bitmap.dart';
import 'mask_edit_command.dart';
import 'mask_edit_history.dart';

/// Exact old ownership for changed pixels, in ascending index order.
@Deprecated('Temporary legacy refinement adapter; use MaskEditCommand.')
final class MaskUndoCommand {
  MaskUndoCommand({
    required this.width,
    required this.height,
    required Uint32List indices,
    required Uint8List previousLabels,
  }) : indices = Uint32List.fromList(indices).asUnmodifiableView(),
       previousLabels = Uint8List.fromList(
         previousLabels,
       ).asUnmodifiableView() {
    if (width <= 0 ||
        height <= 0 ||
        indices.isEmpty ||
        indices.length != previousLabels.length) {
      throw ArgumentError(
        'Positive dimensions and nonempty matching delta required',
      );
    }
    var previousIndex = -1;
    for (var i = 0; i < this.indices.length; i++) {
      final index = this.indices[i];
      if (index <= previousIndex ||
          index >= width * height ||
          this.previousLabels[i] > RoomLayer.values.length) {
        throw ArgumentError(
          'Sorted unique in-bounds indices and labels 0–4 required',
        );
      }
      previousIndex = index;
    }
  }

  final int width;
  final int height;
  final Uint32List indices;
  final Uint8List previousLabels;

  int get byteLength => indices.lengthInBytes + previousLabels.lengthInBytes;
}

/// Immutable bounded history; snapshots share already immutable commands.
@Deprecated('Temporary controller adapter; use MaskEditHistory.')
final class MaskUndoHistory {
  MaskUndoHistory() : commands = const [], byteLength = 0;

  factory MaskUndoHistory.fromEditHistory(MaskEditHistory history) =>
      MaskUndoHistory._(
        [
          for (final command in history.undoStack)
            MaskUndoCommand(
              width: command.width,
              height: command.height,
              indices: command.indices,
              previousLabels: command.beforeLabels,
            ),
        ],
        history.undoStack.fold<int>(
          0,
          (sum, command) => sum + command.indices.length * 5,
        ),
      );

  MaskUndoHistory._(List<MaskUndoCommand> commands, this.byteLength)
    : commands = List.unmodifiable(commands);

  static const _maxCommands = 20;
  static const _maxBytes = 16 * 1024 * 1024;

  final List<MaskUndoCommand> commands;
  final int byteLength;

  bool get canUndo => commands.isNotEmpty;
  MaskUndoCommand? get last => canUndo ? commands.last : null;

  MaskUndoHistory push(MaskUndoCommand command) {
    final next = [...commands, command];
    var bytes = byteLength + command.byteLength;
    while (next.length > _maxCommands || bytes > _maxBytes) {
      bytes -= next.removeAt(0).byteLength;
    }
    return MaskUndoHistory._(next, bytes);
  }

  MaskUndoHistory withoutLast() {
    if (!canUndo) return this;
    return MaskUndoHistory._(
      commands.sublist(0, commands.length - 1),
      byteLength - commands.last.byteLength,
    );
  }
}

/// Complete an old worker delta using the actual before/after ownership.
/// The legacy worker changes no intent; it never infers provenance.
MaskEditCommand completeLegacyMaskUndo({
  required MaskUndoCommand command,
  required MaskBitmap before,
  required MaskBitmap after,
  required MaskIntentBitmap intent,
}) {
  if (command.width != before.width ||
      command.height != before.height ||
      after.width != before.width ||
      after.height != before.height ||
      intent.width != before.width ||
      intent.height != before.height) {
    throw ArgumentError('Legacy edit dimensions must match.');
  }
  final afterLabels = Uint8List(command.indices.length);
  final intents = Uint8List(command.indices.length);
  for (var i = 0; i < command.indices.length; i++) {
    final index = command.indices[i];
    if (before.labels[index] != command.previousLabels[i]) {
      throw StateError('Stale legacy delta.');
    }
    afterLabels[i] = after.labels[index];
    intents[i] = intent.intentAt(index);
  }
  return MaskEditCommand(
    width: command.width,
    height: command.height,
    indices: command.indices,
    beforeLabels: command.previousLabels,
    afterLabels: afterLabels,
    beforeIntent: intents,
    afterIntent: intents,
  );
}

/// Explicit transient compatibility boundary until Task 3 removes old producers.
MaskEditHistory completeLegacyMaskHistory({
  required MaskUndoHistory history,
  required MaskBitmap masks,
  required MaskIntentBitmap intent,
}) {
  final labels = Uint8List.fromList(masks.labels);
  final reversed = <MaskEditCommand>[];
  for (final command in history.commands.reversed) {
    if (command.width != masks.width || command.height != masks.height) {
      throw ArgumentError('Legacy history dimensions must match.');
    }
    final after = Uint8List(command.indices.length);
    final intents = Uint8List(command.indices.length);
    var changed = false;
    for (var i = 0; i < command.indices.length; i++) {
      final index = command.indices[i];
      after[i] = labels[index];
      intents[i] = intent.intentAt(index);
      changed |= after[i] != command.previousLabels[i];
      labels[index] = command.previousLabels[i];
    }
    if (changed) {
      reversed.add(
        MaskEditCommand(
          width: command.width,
          height: command.height,
          indices: command.indices,
          beforeLabels: command.previousLabels,
          afterLabels: after,
          beforeIntent: intents,
          afterIntent: intents,
        ),
      );
    }
  }
  var result = MaskEditHistory.empty(width: masks.width, height: masks.height);
  for (final command in reversed.reversed) {
    result = result.push(command);
  }
  return result;
}
