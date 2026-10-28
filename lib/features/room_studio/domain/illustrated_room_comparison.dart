import 'illustrated_room_assignments.dart';

enum IllustratedRoomComparisonView {
  current,
  baseline,
  variant,
  original,
  grayscale,
}

/// A session-only, copied display snapshot. Null is an explicit grayscale view,
/// distinct from [IllustratedRoomComparisonView.current].
final class IllustratedRoomComparison {
  const IllustratedRoomComparison.current()
    : view = IllustratedRoomComparisonView.current,
      snapshot = null;

  IllustratedRoomComparison.snapshot(
    this.view,
    IllustratedRoomAssignments? value,
  ) : snapshot = value?.copyWith() {
    if (view == IllustratedRoomComparisonView.current) {
      throw ArgumentError('Use the current constructor for the editable view.');
    }
  }

  final IllustratedRoomComparisonView view;
  final IllustratedRoomAssignments? snapshot;
  bool get isActive => view != IllustratedRoomComparisonView.current;

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomComparison &&
      view == other.view &&
      snapshot == other.snapshot;
  @override
  int get hashCode => Object.hash(view, snapshot);
}
