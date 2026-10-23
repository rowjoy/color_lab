import 'dart:typed_data';

import 'room_layer.dart';

/// Exact old ownership for changed pixels, in ascending index order.
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
final class MaskUndoHistory {
  MaskUndoHistory() : commands = const [], byteLength = 0;

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
