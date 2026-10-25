import 'package:color_lab/features/games/presentation/fruit_pop_swipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a slow horizontal drag maps to the neighboring tile by distance', () {
    expect(fruitPopSwipeTarget(row: 3, col: 2, dx: 24, dy: 2), (3, 3));
  });

  test('maps swipes in all four directions to one adjacent fruit', () {
    expect(fruitPopSwipeTarget(row: 3, col: 2, dx: -24, dy: 1), (3, 1));
    expect(fruitPopSwipeTarget(row: 3, col: 2, dx: 24, dy: 1), (3, 3));
    expect(fruitPopSwipeTarget(row: 3, col: 2, dx: 1, dy: -24), (2, 2));
    expect(fruitPopSwipeTarget(row: 3, col: 2, dx: 1, dy: 24), (4, 2));
  });

  test('ignores short drags and swipes that leave the board', () {
    expect(fruitPopSwipeTarget(row: 3, col: 2, dx: 8, dy: 4), isNull);
    expect(fruitPopSwipeTarget(row: 0, col: 0, dx: -30, dy: 0), isNull);
  });
}
