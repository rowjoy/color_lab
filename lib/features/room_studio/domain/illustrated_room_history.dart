import 'illustrated_room_assignments.dart';
import 'illustrated_room_edit.dart';

/// A persistent bounded command stack. Every returned history is independent.
final class IllustratedRoomHistory {
  IllustratedRoomHistory({IllustratedRoomAssignments? initial})
    : this._(initial, const [], const []);

  IllustratedRoomHistory._(
    this.current,
    List<IllustratedRoomEdit> undoCommands,
    List<IllustratedRoomEdit> redoCommands,
  ) : undoCommands = List.unmodifiable(undoCommands),
      redoCommands = List.unmodifiable(redoCommands);

  static const capacity = 50;
  final IllustratedRoomAssignments? current;
  final List<IllustratedRoomEdit> undoCommands;
  final List<IllustratedRoomEdit> redoCommands;

  bool get canUndo => undoCommands.isNotEmpty;
  bool get canRedo => redoCommands.isNotEmpty;

  IllustratedRoomHistory record(IllustratedRoomAssignments? next) {
    if (current == next) return this;
    final commands = [
      ...undoCommands,
      IllustratedRoomEdit(before: current, after: next),
    ];
    return IllustratedRoomHistory._(
      next,
      commands.length > capacity
          ? commands.sublist(commands.length - capacity)
          : commands,
      const [],
    );
  }

  IllustratedRoomHistory undo() {
    if (!canUndo) return this;
    final command = undoCommands.last;
    return IllustratedRoomHistory._(
      command.before,
      undoCommands.sublist(0, undoCommands.length - 1),
      [...redoCommands, command],
    );
  }

  IllustratedRoomHistory redo() {
    if (!canRedo) return this;
    final command = redoCommands.last;
    return IllustratedRoomHistory._(command.after, [
      ...undoCommands,
      command,
    ], redoCommands.sublist(0, redoCommands.length - 1));
  }
}
