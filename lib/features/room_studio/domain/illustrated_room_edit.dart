import 'illustrated_room_assignments.dart';

/// Exact immutable assignment snapshots; null represents the grayscale mode.
final class IllustratedRoomEdit {
  const IllustratedRoomEdit({required this.before, required this.after});

  final IllustratedRoomAssignments? before;
  final IllustratedRoomAssignments? after;

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomEdit &&
      before == other.before &&
      after == other.after;

  @override
  int get hashCode => Object.hash(before, after);
}
