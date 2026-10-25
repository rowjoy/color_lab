import 'package:color_lab/features/games/domain/bubble_shooter_game.dart';
import 'package:color_lab/features/games/domain/deterministic_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matching three bubbles pop and award points', () {
    final game = BubbleShooterGame.fromBoard(
      [
        [0, 0, null, null, null, null, null, null, null, null],
      ],
      currentColor: 0,
      nextColor: 1,
    );

    final result = game.landBubble(0, 2, 0);

    expect(result.popped, 3);
    expect(game.score, 30);
    expect(game.grid.first.take(3), everyElement(isNull));
  });

  test('unconnected bubbles fall after a match clears their support', () {
    final game = BubbleShooterGame.fromBoard(
      [
        [0, 0, null, null, null, null, null, null, null, null],
        [1, null, null, null, null, null, null, null, null],
      ],
      currentColor: 0,
      nextColor: 1,
    );

    final result = game.landBubble(0, 2, 0);

    expect(result.popped, 3);
    expect(result.dropped, 1);
    expect(game.grid[1].first, isNull);
    expect(game.score, 50);
  });

  test(
    'shots bounce off the side wall and attach when they hit the ceiling',
    () {
      final game = BubbleShooterGame.fromBoard(
        [List<int?>.filled(10, null)],
        currentColor: 2,
        nextColor: 1,
      );
      game.launchAt(-0.2, shooterY: 20);

      var bounced = false;
      for (var i = 0; i < 160 && game.shot != null; i++) {
        game.advanceShot(0.04, boardHeight: 22);
        bounced |= game.shot?.vx.isNegative == true;
      }

      expect(bounced, isTrue);
      expect(game.shot, isNull);
      expect(game.grid.any((row) => row.any((color) => color == 2)), isTrue);
    },
  );

  test('from-layout runtime stream and shot counter are deterministic', () {
    final board = List.generate(
      9,
      (row) => List<int?>.filled(BubbleShooterGame.columns, null),
    );
    board[0][0] = 0;
    final layout = BubbleShooterLevelLayout(
      level: 1,
      colorCount: 3,
      occupiedRows: 1,
      dropEvery: 1,
      currentColor: 1,
      nextColor: 2,
      runtimeSeed: 77,
      grid: board,
      placementCertificate: const [],
      parShots: 1,
    );
    final first = BubbleShooterGame.fromLayout(layout);
    final second = BubbleShooterGame.fromLayout(layout);

    expect(first.initialBubbleCount, 1);
    expect(first.shotsFired, 0);
    expect(first.launchAt(-1.2, shooterY: 20), isTrue);
    expect(second.launchAt(-1.2, shooterY: 20), isTrue);
    expect(first.shotsFired, 1);
    expect(second.shotsFired, 1);
    expect(first.currentColor, second.currentColor);
    expect(first.nextColor, second.nextColor);

    final pressureFirst = BubbleShooterGame.fromLayout(layout);
    final pressureSecond = BubbleShooterGame.fromLayout(layout);
    expect(pressureFirst.landBubble(0, 1, 1).newRow, isTrue);
    expect(pressureSecond.landBubble(0, 1, 1).newRow, isTrue);
    expect(pressureFirst.grid.first, pressureSecond.grid.first);
    expect(StableRandom(77).nextInt(3), pressureFirst.grid.first.first);
  });
}
