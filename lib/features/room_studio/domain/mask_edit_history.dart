import 'dart:typed_data';

import 'mask_bitmap.dart';
import 'mask_edit_command.dart';
import 'mask_intent_bitmap.dart';
import 'room_project.dart' show RoomProjectLimits;

final class MaskEditTransition {
  const MaskEditTransition({required this.result, required this.history});
  final MaskEditResult result;
  final MaskEditHistory history;
}

/// Undo is oldest-first; the last redo entry is the next command to replay.
final class MaskEditHistory {
  factory MaskEditHistory.empty({required int width, required int height}) =>
      MaskEditHistory.fromStacks(width: width, height: height);

  factory MaskEditHistory.fromStacks({
    required int width,
    required int height,
    List<MaskEditCommand> undoStack = const [],
    List<MaskEditCommand> redoStack = const [],
  }) {
    if (width < 1 ||
        height < 1 ||
        width > RoomProjectLimits.maxDimension ||
        height > RoomProjectLimits.maxDimension ||
        width * height > RoomProjectLimits.maxPixels ||
        undoStack.length + redoStack.length > maxCommands) {
      throw ArgumentError(
        'Bounded history dimensions and command count required.',
      );
    }
    var bytes = 0;
    for (final command in [...undoStack, ...redoStack]) {
      if (command.width != width || command.height != height) {
        throw ArgumentError('History commands must be aligned.');
      }
      bytes += command.byteLength;
      if (bytes > maxBytes) {
        throw ArgumentError('History exceeds its payload bound.');
      }
    }
    return MaskEditHistory._(width, height, undoStack, redoStack, bytes);
  }

  MaskEditHistory._(
    this.width,
    this.height,
    List<MaskEditCommand> undoStack,
    List<MaskEditCommand> redoStack,
    this.byteLength,
  ) : undoStack = List.unmodifiable(undoStack),
      redoStack = List.unmodifiable(redoStack);

  static const maxCommands = 20;
  static const maxBytes = 16 * 1024 * 1024;
  final int width;
  final int height;
  final List<MaskEditCommand> undoStack;
  final List<MaskEditCommand> redoStack;
  final int byteLength;
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  /// Deprecated compatibility view for the immediately dependent controller migration.
  List<MaskEditCommand> get commands => undoStack;

  MaskEditHistory push(MaskEditCommand command) {
    if (command.width != width || command.height != height) {
      throw ArgumentError('History command dimensions must match.');
    }
    // An unrecordable newest edit breaks the chain. Retain no older undo or redo.
    if (command.byteLength > maxBytes) {
      return MaskEditHistory.empty(width: width, height: height);
    }
    final next = [...undoStack, command];
    var bytes = next.fold<int>(0, (sum, entry) => sum + entry.byteLength);
    while (next.length > maxCommands || bytes > maxBytes) {
      bytes -= next.removeAt(0).byteLength;
    }
    return MaskEditHistory._(width, height, next, const [], bytes);
  }

  MaskEditTransition undo({
    required MaskBitmap masks,
    required MaskIntentBitmap intent,
  }) {
    if (!canUndo) throw StateError('No command to undo.');
    final command = undoStack.last;
    final result = command.applyBackward(masks: masks, intent: intent);
    return MaskEditTransition(
      result: result,
      history: MaskEditHistory._(
        width,
        height,
        undoStack.sublist(0, undoStack.length - 1),
        [...redoStack, command],
        byteLength,
      ),
    );
  }

  MaskEditTransition redo({
    required MaskBitmap masks,
    required MaskIntentBitmap intent,
  }) {
    if (!canRedo) throw StateError('No command to redo.');
    final command = redoStack.last;
    final result = command.applyForward(masks: masks, intent: intent);
    return MaskEditTransition(
      result: result,
      history: MaskEditHistory._(
        width,
        height,
        [...undoStack, command],
        redoStack.sublist(0, redoStack.length - 1),
        byteLength,
      ),
    );
  }

  /// Validate both chains against the current snapshot without retaining work buffers.
  void validateAgainst({
    required MaskBitmap masks,
    required MaskIntentBitmap intent,
  }) {
    if (masks.width != width ||
        masks.height != height ||
        intent.width != width ||
        intent.height != height) {
      throw ArgumentError('History and snapshot dimensions must match.');
    }
    if (!canUndo && !canRedo) return;
    final labels = Uint8List.fromList(masks.labels);
    final intents = Uint8List.fromList(intent.bytes);
    void walk(Iterable<MaskEditCommand> stack, bool forward) {
      for (final command in stack) {
        final expectedLabels = forward
            ? command.beforeLabels
            : command.afterLabels;
        final expectedIntent = forward
            ? command.beforeIntent
            : command.afterIntent;
        for (var i = 0; i < command.indices.length; i++) {
          final index = command.indices[i];
          if (labels[index] != expectedLabels[i] ||
              intents[index] != expectedIntent[i]) {
            throw StateError('History order does not match the snapshot.');
          }
        }
        for (var i = 0; i < command.indices.length; i++) {
          final index = command.indices[i];
          labels[index] = forward
              ? command.afterLabels[i]
              : command.beforeLabels[i];
          intents[index] = forward
              ? command.afterIntent[i]
              : command.beforeIntent[i];
        }
      }
    }

    walk(undoStack.reversed, false);
    labels.setAll(0, masks.labels);
    intents.setAll(0, intent.bytes);
    walk(redoStack.reversed, true);
  }
}
