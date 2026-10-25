import 'dart:math';

import 'deterministic_random.dart';
import 'game_level_adapter.dart';

final class BubbleShooterPlacement {
  const BubbleShooterPlacement({
    required this.row,
    required this.column,
    required this.color,
  });

  final int row;
  final int column;
  final int color;
}

final class BubbleShooterLevelLayout implements GameLevelLayout {
  factory BubbleShooterLevelLayout({
    required int level,
    required int colorCount,
    required int occupiedRows,
    required int dropEvery,
    required int currentColor,
    required int nextColor,
    required int runtimeSeed,
    required List<List<int?>> grid,
    required List<BubbleShooterPlacement> placementCertificate,
    required int parShots,
    bool usedFallback = false,
  }) {
    if (level < 1 ||
        colorCount < 1 ||
        occupiedRows < 1 ||
        occupiedRows > 9 ||
        dropEvery < 1 ||
        currentColor < 0 ||
        currentColor >= colorCount ||
        nextColor < 0 ||
        nextColor >= colorCount ||
        runtimeSeed < 0 ||
        runtimeSeed > 0xffffffff ||
        parShots < 1 ||
        grid.length != 9 ||
        grid.any((row) => row.length != BubbleShooterGame.columns) ||
        grid
            .expand((row) => row)
            .whereType<int>()
            .any((color) => color < 0 || color >= colorCount)) {
      throw ArgumentError('Invalid Bubble Shooter layout');
    }
    return BubbleShooterLevelLayout._(
      level: level,
      colorCount: colorCount,
      occupiedRows: occupiedRows,
      dropEvery: dropEvery,
      currentColor: currentColor,
      nextColor: nextColor,
      runtimeSeed: runtimeSeed,
      grid: List<List<int?>>.unmodifiable(
        grid.map((row) => List<int?>.unmodifiable(row)),
      ),
      placementCertificate: List<BubbleShooterPlacement>.unmodifiable(
        placementCertificate,
      ),
      parShots: parShots,
      usedFallback: usedFallback,
    );
  }

  const BubbleShooterLevelLayout._({
    required this.level,
    required this.colorCount,
    required this.occupiedRows,
    required this.dropEvery,
    required this.currentColor,
    required this.nextColor,
    required this.runtimeSeed,
    required this.grid,
    required this.placementCertificate,
    required this.parShots,
    required this.usedFallback,
  });

  final int level;
  final int colorCount;
  final int occupiedRows;
  final int dropEvery;
  final int currentColor;
  final int nextColor;
  final int runtimeSeed;
  final List<List<int?>> grid;
  final List<BubbleShooterPlacement> placementCertificate;
  final int parShots;
  final bool usedFallback;

  int get initialBubbleCount =>
      grid.expand((row) => row).whereType<int>().length;

  @override
  String get canonicalSignature {
    final board = grid
        .map((row) => row.map((color) => color?.toString() ?? '.').join(','))
        .join('/');
    return 'bubble:v1|level=$level|colors=$colorCount|rows=$occupiedRows|'
        'drop=$dropEvery|current=$currentColor|next=$nextColor|'
        'stream=$runtimeSeed|par=$parShots|grid=$board';
  }
}

final class BubbleShot {
  BubbleShot({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
  });

  double x;
  double y;
  double vx;
  double vy;
  final int color;
}

final class BubbleShotResult {
  const BubbleShotResult({
    this.landed = false,
    this.popped = 0,
    this.dropped = 0,
    this.wallBounce = false,
    this.won = false,
    this.lost = false,
    this.newRow = false,
  });

  final bool landed;
  final int popped;
  final int dropped;
  final bool wallBounce;
  final bool won;
  final bool lost;
  final bool newRow;
}

/// Bubble grid and collision rules for the offline Bubble Shooter.
final class BubbleShooterGame {
  BubbleShooterGame._({
    required this.level,
    required List<List<int?>> grid,
    required this.currentColor,
    required this.nextColor,
    required this.colorCount,
    required this.dropEvery,
    required this.initialBubbleCount,
    required this.parShots,
    required Random random,
  }) : grid = grid.map(List<int?>.of).toList(),
       _random = random;

  factory BubbleShooterGame.generate({required int level, Random? random}) {
    final safeLevel = max(1, level);
    final rng = random ?? Random.secure();
    final colors = min(6, 3 + (safeLevel + 1) ~/ 2);
    final grid = List.generate(9, (_) => List<int?>.filled(columns, null));
    final rows = min(8, 4 + safeLevel ~/ 3);
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final previous = col > 0 ? grid[row][col - 1] : null;
        grid[row][col] = previous != null && rng.nextDouble() < .35
            ? previous
            : rng.nextInt(colors);
      }
    }
    return BubbleShooterGame._(
      level: safeLevel,
      grid: grid,
      currentColor: rng.nextInt(colors),
      nextColor: rng.nextInt(colors),
      colorCount: colors,
      dropEvery: max(4, 8 - safeLevel ~/ 2),
      initialBubbleCount: grid.expand((row) => row).whereType<int>().length,
      parShots: max(
        1,
        (grid.expand((row) => row).whereType<int>().length / 3).ceil(),
      ),
      random: rng,
    );
  }

  factory BubbleShooterGame.fromLayout(BubbleShooterLevelLayout layout) =>
      BubbleShooterGame._(
        level: layout.level,
        grid: layout.grid,
        currentColor: layout.currentColor,
        nextColor: layout.nextColor,
        colorCount: layout.colorCount,
        dropEvery: layout.dropEvery,
        initialBubbleCount: layout.initialBubbleCount,
        parShots: layout.parShots,
        random: StableRandom(layout.runtimeSeed),
      );

  factory BubbleShooterGame.fromBoard(
    List<List<int?>> board, {
    int currentColor = 0,
    int nextColor = 1,
    int level = 1,
  }) {
    final grid = board
        .map(
          (row) => List<int?>.generate(
            columns,
            (index) => index < row.length ? row[index] : null,
          ),
        )
        .toList();
    while (grid.length < 9) {
      grid.add(List<int?>.filled(columns, null));
    }
    return BubbleShooterGame._(
      level: level,
      grid: grid,
      currentColor: currentColor,
      nextColor: nextColor,
      colorCount: 6,
      dropEvery: 8,
      initialBubbleCount: grid.expand((row) => row).whereType<int>().length,
      parShots: max(
        1,
        (grid.expand((row) => row).whereType<int>().length / 3).ceil(),
      ),
      random: Random(),
    );
  }

  static const columns = 10;
  static const radius = 1.0;
  static const rowSpacing = 1.7320508075688772;
  static const worldWidth = columns * 2.0 + 1.0;

  final int level;
  final List<List<int?>> grid;
  final int colorCount;
  final int dropEvery;
  final int initialBubbleCount;
  final int parShots;
  final Random _random;
  int currentColor;
  int nextColor;
  int score = 0;
  int shotsSinceDrop = 0;
  int shotsFired = 0;
  BubbleShot? shot;
  bool isWon = false;
  bool isLost = false;

  List<int> get activeColors =>
      grid.expand((row) => row).whereType<int>().toSet().toList();

  void swapColors() {
    if (shot != null || isWon || isLost) return;
    final old = currentColor;
    currentColor = nextColor;
    nextColor = old;
  }

  bool launchAt(double angle, {required double shooterY}) {
    if (shot != null || isWon || isLost) return false;
    final safeAngle = angle.clamp(-pi + .15, -.15);
    const speed = 36.0;
    shot = BubbleShot(
      x: worldWidth / 2,
      y: shooterY,
      vx: cos(safeAngle) * speed,
      vy: sin(safeAngle) * speed,
      color: currentColor,
    );
    shotsFired++;
    currentColor = nextColor;
    final availableColors = activeColors;
    nextColor = availableColors.isEmpty
        ? _random.nextInt(colorCount)
        : availableColors[_random.nextInt(availableColors.length)];
    return true;
  }

  BubbleShotResult advanceShot(double seconds, {required double boardHeight}) {
    _lastBoardHeight = boardHeight;
    final activeShot = shot;
    if (activeShot == null || isWon || isLost) return const BubbleShotResult();
    var remaining = seconds.clamp(0.0, .08);
    var bounced = false;
    while (remaining > 0 && shot != null) {
      final dt = min(remaining, .008);
      remaining -= dt;
      activeShot.x += activeShot.vx * dt;
      activeShot.y += activeShot.vy * dt;
      if (activeShot.x < radius) {
        activeShot.x = radius;
        activeShot.vx = activeShot.vx.abs();
        bounced = true;
      } else if (activeShot.x > worldWidth - radius) {
        activeShot.x = worldWidth - radius;
        activeShot.vx = -activeShot.vx.abs();
        bounced = true;
      }
      var collision = activeShot.y <= radius;
      collision = collision || _touchesBubble(activeShot.x, activeShot.y);
      if (activeShot.y >= boardHeight - radius) {
        shot = null;
        isLost = true;
        return BubbleShotResult(lost: true, wallBounce: bounced);
      }
      if (collision) {
        final cell = _nearestCell(activeShot.x, activeShot.y);
        shot = null;
        if (cell == null) {
          isLost = true;
          return BubbleShotResult(lost: true, wallBounce: bounced);
        }
        final landed = landBubble(cell.$1, cell.$2, activeShot.color);
        return BubbleShotResult(
          landed: true,
          popped: landed.popped,
          dropped: landed.dropped,
          wallBounce: bounced,
          won: landed.won,
          lost: landed.lost,
          newRow: landed.newRow,
        );
      }
    }
    return BubbleShotResult(wallBounce: bounced);
  }

  /// Places an arrived bubble and resolves matches, unsupported clusters and pressure rows.
  BubbleShotResult landBubble(int row, int col, int color) {
    if (row < 0 ||
        row >= grid.length ||
        col < 0 ||
        col >= columns ||
        grid[row][col] != null) {
      isLost = true;
      return const BubbleShotResult(lost: true);
    }
    grid[row][col] = color;
    final group = _group(row, col, matchingColorOnly: true);
    var popped = 0;
    var dropped = 0;
    if (group.length >= 3) {
      popped = group.length;
      for (final cell in group) {
        grid[cell.$1][cell.$2] = null;
      }
      score += popped * 10;
      final connected = <(int, int)>{};
      final queue = <(int, int)>[];
      for (var c = 0; c < columns; c++) {
        if (grid[0][c] != null) {
          connected.add((0, c));
          queue.add((0, c));
        }
      }
      while (queue.isNotEmpty) {
        final cell = queue.removeLast();
        for (final neighbor in _neighbors(cell.$1, cell.$2)) {
          if (grid[neighbor.$1][neighbor.$2] != null &&
              connected.add(neighbor)) {
            queue.add(neighbor);
          }
        }
      }
      for (var r = 0; r < grid.length; r++) {
        for (var c = 0; c < columns; c++) {
          if (grid[r][c] != null && !connected.contains((r, c))) {
            grid[r][c] = null;
            dropped++;
          }
        }
      }
      score += dropped * 20;
      shotsSinceDrop = 0;
    } else {
      shotsSinceDrop++;
    }
    isWon = grid.every((line) => line.every((value) => value == null));
    if (isWon) {
      return BubbleShotResult(
        landed: true,
        popped: popped,
        dropped: dropped,
        won: true,
      );
    }
    final dangerY = _lastBoardHeight - 5.0;
    if (grid.indexed.any(
      (entry) =>
          entry.$2.any((color) => color != null) &&
          _centerY(entry.$1) >= dangerY,
    )) {
      isLost = true;
      return BubbleShotResult(
        landed: true,
        popped: popped,
        dropped: dropped,
        lost: true,
      );
    }

    var newRow = false;
    if (shotsSinceDrop >= dropEvery) {
      if (grid.last.any((value) => value != null)) {
        isLost = true;
        return BubbleShotResult(
          landed: true,
          popped: popped,
          dropped: dropped,
          lost: true,
        );
      }
      grid.removeLast();
      grid.insert(
        0,
        List<int?>.generate(columns, (_) => _random.nextInt(colorCount)),
      );
      shotsSinceDrop = 0;
      newRow = true;
    }
    return BubbleShotResult(
      landed: true,
      popped: popped,
      dropped: dropped,
      newRow: newRow,
    );
  }

  (int, int)? _nearestCell(double x, double y) {
    final rowGuess = ((y - 1) / rowSpacing).round().clamp(0, grid.length - 1);
    (int, int)? nearest;
    var best = double.infinity;
    for (
      var row = max(0, rowGuess - 1);
      row <= min(grid.length - 1, rowGuess + 1);
      row++
    ) {
      for (var col = 0; col < columns; col++) {
        if (grid[row][col] != null) continue;
        final dx = _centerX(row, col) - x;
        final dy = _centerY(row) - y;
        final distance = dx * dx + dy * dy;
        if (distance < best) {
          best = distance;
          nearest = (row, col);
        }
      }
    }
    return nearest;
  }

  bool _touchesBubble(double x, double y) {
    final rowGuess = ((y - 1) / rowSpacing).round();
    for (
      var row = max(0, rowGuess - 1);
      row <= min(grid.length - 1, rowGuess + 1);
      row++
    ) {
      final colGuess = ((x - 1 - (row.isOdd ? 1 : 0)) / 2).round();
      for (
        var col = max(0, colGuess - 1);
        col <= min(columns - 1, colGuess + 1);
        col++
      ) {
        if (grid[row][col] == null) continue;
        final dx = _centerX(row, col) - x;
        final dy = _centerY(row) - y;
        if (dx * dx + dy * dy < 3.9) return true;
      }
    }
    return false;
  }

  List<(int, int)> _group(int row, int col, {required bool matchingColorOnly}) {
    final color = grid[row][col];
    final found = <(int, int)>{(row, col)};
    final queue = <(int, int)>[(row, col)];
    while (queue.isNotEmpty) {
      final cell = queue.removeLast();
      for (final neighbor in _neighbors(cell.$1, cell.$2)) {
        if (found.contains(neighbor)) continue;
        final value = grid[neighbor.$1][neighbor.$2];
        if (value != null && (!matchingColorOnly || value == color)) {
          found.add(neighbor);
          queue.add(neighbor);
        }
      }
    }
    return found.toList();
  }

  Iterable<(int, int)> _neighbors(int row, int col) sync* {
    if (col > 0) yield (row, col - 1);
    if (col + 1 < columns) yield (row, col + 1);
    for (final otherRow in [row - 1, row + 1]) {
      if (otherRow < 0 || otherRow >= grid.length) continue;
      final offset = row.isEven ? 0 : 1;
      for (final otherCol in [col + offset - 1, col + offset]) {
        if (otherCol >= 0 && otherCol < columns) yield (otherRow, otherCol);
      }
    }
  }

  double _centerX(int row, int col) =>
      1.0 + col * 2.0 + (row.isOdd ? 1.0 : 0.0);
  double _centerY(int row) => 1.0 + row * rowSpacing;
  double _lastBoardHeight = 30;
}
