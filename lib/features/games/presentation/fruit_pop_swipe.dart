/// Maps a drag distance to exactly one adjacent tile, regardless of its speed.
(int, int)? fruitPopSwipeTarget({
  required int row,
  required int col,
  required double dx,
  required double dy,
  int gridSize = 8,
  double threshold = 18,
}) {
  if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) return null;
  if (dx.abs() < threshold && dy.abs() < threshold) return null;
  final target = dx.abs() > dy.abs()
      ? (row, col + (dx > 0 ? 1 : -1))
      : (row + (dy > 0 ? 1 : -1), col);
  if (target.$1 < 0 ||
      target.$1 >= gridSize ||
      target.$2 < 0 ||
      target.$2 >= gridSize) {
    return null;
  }
  return target;
}
