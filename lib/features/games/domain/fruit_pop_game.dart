import 'dart:math';

import 'deterministic_random.dart';
import 'game_difficulty.dart';
import 'game_level_adapter.dart';

final class FruitPopLevelLayout implements GameLevelLayout {
  factory FruitPopLevelLayout({
    required int level,
    required int typeCount,
    required int target,
    required int baseMoveBudget,
    required int moveBudget,
    required int parMoves,
    required int refillSeed,
    required List<List<int?>> board,
    required Set<int> blockers,
    required int simulationWins,
    required int simulationCount,
    required int candidateAttempts,
    bool usedFallback = false,
  }) {
    final safeBlockers = Set<int>.unmodifiable(blockers);
    final validBoard =
        board.length == FruitPopGame.size &&
        board.every((row) => row.length == FruitPopGame.size);
    if (level < 1 ||
        typeCount < 3 ||
        typeCount > FruitPopGame.maxTypeCount ||
        target < 1 ||
        baseMoveBudget < 1 ||
        moveBudget < baseMoveBudget ||
        moveBudget > 30 ||
        parMoves < 1 ||
        parMoves > moveBudget ||
        refillSeed < 0 ||
        refillSeed > 0xffffffff ||
        simulationWins < 0 ||
        simulationCount < 0 ||
        simulationWins > simulationCount ||
        candidateAttempts < 1 ||
        !validBoard ||
        safeBlockers.length > 8 ||
        safeBlockers.any(
          (index) =>
              index < 0 || index >= FruitPopGame.size * FruitPopGame.size,
        )) {
      throw ArgumentError('Invalid Fruit Pop layout');
    }
    for (
      var index = 0;
      index < FruitPopGame.size * FruitPopGame.size;
      index++
    ) {
      final value =
          board[index ~/ FruitPopGame.size][index % FruitPopGame.size];
      if (safeBlockers.contains(index)) {
        if (value != null) throw ArgumentError('Blocker cell must be empty');
      } else if (value == null || value < 0 || value >= typeCount) {
        throw ArgumentError('Playable cell must contain a valid type');
      }
    }
    return FruitPopLevelLayout._(
      level: level,
      typeCount: typeCount,
      target: target,
      baseMoveBudget: baseMoveBudget,
      moveBudget: moveBudget,
      parMoves: parMoves,
      refillSeed: refillSeed,
      board: List<List<int?>>.unmodifiable(
        board.map((row) => List<int?>.unmodifiable(row)),
      ),
      blockers: safeBlockers,
      simulationWins: simulationWins,
      simulationCount: simulationCount,
      candidateAttempts: candidateAttempts,
      usedFallback: usedFallback,
    );
  }

  const FruitPopLevelLayout._({
    required this.level,
    required this.typeCount,
    required this.target,
    required this.baseMoveBudget,
    required this.moveBudget,
    required this.parMoves,
    required this.refillSeed,
    required this.board,
    required this.blockers,
    required this.simulationWins,
    required this.simulationCount,
    required this.candidateAttempts,
    required this.usedFallback,
  });

  final int level;
  final int typeCount;
  final int target;
  final int baseMoveBudget;
  final int moveBudget;
  final int parMoves;
  final int refillSeed;
  final List<List<int?>> board;
  final Set<int> blockers;
  final int simulationWins;
  final int simulationCount;
  final int candidateAttempts;
  final bool usedFallback;

  @override
  String get canonicalSignature {
    final blocked = blockers.toList()..sort();
    final cells = board
        .map((row) => row.map((value) => value?.toString() ?? 'x').join(','))
        .join('/');
    return 'fruit:v1|level=$level|types=$typeCount|target=$target|'
        'base=$baseMoveBudget|moves=$moveBudget|par=$parMoves|'
        'stream=$refillSeed|blockers=${blocked.join(',')}|board=$cells';
  }
}

/// Offline match-3 rules for Fruit & Veggie Pop.
final class FruitPopGame {
  FruitPopGame._({
    required this.level,
    required this.activeTypeCount,
    required this.blockers,
    required this.target,
    required this.initialMoveBudget,
    required this.parMoves,
    required Random random,
  }) : _random = random,
       movesLeft = initialMoveBudget,
       board = List.generate(size, (_) => List<int?>.filled(size, null));

  static const size = 8;
  static const maxTypeCount = 6;
  final int level;
  final int activeTypeCount;
  final Set<int> blockers;
  final Random _random;
  final List<List<int?>> board;
  final int target;
  final int initialMoveBudget;
  final int parMoves;
  int score = 0;
  int movesLeft;
  List<FruitPopCascadeStep> lastMoveCascades = const [];
  int lastMoveScore = 0;

  static GameDifficulty difficultyForLevel(int level) => switch (level) {
    < 4 => GameDifficulty.easy,
    < 8 => GameDifficulty.medium,
    _ => GameDifficulty.hard,
  };

  factory FruitPopGame.generate({required int level, Random? random}) {
    final safeLevel = max(1, level);
    final difficulty = difficultyForLevel(safeLevel);
    final moves = switch (difficulty) {
      GameDifficulty.easy => 20,
      GameDifficulty.medium => 18,
      GameDifficulty.hard => 16,
    };
    final game = FruitPopGame._(
      level: safeLevel,
      activeTypeCount: maxTypeCount,
      blockers: const {},
      target: 300 + safeLevel * 250,
      initialMoveBudget: moves,
      parMoves: moves,
      random: random ?? Random(),
    );
    game._fillFreshBoard();
    return game;
  }

  factory FruitPopGame.fromLayout(FruitPopLevelLayout layout) {
    final game = FruitPopGame._(
      level: layout.level,
      activeTypeCount: layout.typeCount,
      blockers: layout.blockers,
      target: layout.target,
      initialMoveBudget: layout.moveBudget,
      parMoves: layout.parMoves,
      random: StableRandom(layout.refillSeed),
    );
    for (var row = 0; row < size; row++) {
      game.board[row].setAll(0, layout.board[row]);
    }
    return game;
  }

  FruitPopGame copyForSimulation() {
    final random = _random;
    if (random is! StableRandom) {
      throw StateError('Only descriptor-based games can be copied');
    }
    final copy = FruitPopGame._(
      level: level,
      activeTypeCount: activeTypeCount,
      blockers: blockers,
      target: target,
      initialMoveBudget: initialMoveBudget,
      parMoves: parMoves,
      random: random.copy(),
    );
    for (var row = 0; row < size; row++) {
      copy.board[row].setAll(0, board[row]);
    }
    copy.score = score;
    copy.movesLeft = movesLeft;
    return copy;
  }

  int get movesUsed => initialMoveBudget - movesLeft;
  bool get isWon => score >= target;
  bool get isOutOfMoves => movesLeft <= 0 && !isWon;

  bool isBlocked(int row, int col) =>
      row >= 0 &&
      row < size &&
      col >= 0 &&
      col < size &&
      blockers.contains(row * size + col);

  bool get hasPossibleMove {
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (isBlocked(row, col)) continue;
        for (final (dr, dc) in const [(0, 1), (1, 0)]) {
          final otherRow = row + dr;
          final otherCol = col + dc;
          if (otherRow >= size ||
              otherCol >= size ||
              isBlocked(otherRow, otherCol)) {
            continue;
          }
          _swap(row, col, otherRow, otherCol);
          final found = findMatches().isNotEmpty;
          _swap(row, col, otherRow, otherCol);
          if (found) return true;
        }
      }
    }
    return false;
  }

  Set<int> findMatches() {
    final matches = <int>{};
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (isBlocked(row, col)) continue;
        final type = board[row][col];
        if (type == null) continue;
        var end = col + 1;
        while (end < size && !isBlocked(row, end) && board[row][end] == type) {
          end++;
        }
        if (end - col >= 3) {
          for (var c = col; c < end; c++) {
            matches.add(row * size + c);
          }
        }
        end = row + 1;
        while (end < size && !isBlocked(end, col) && board[end][col] == type) {
          end++;
        }
        if (end - row >= 3) {
          for (var r = row; r < end; r++) {
            matches.add(r * size + col);
          }
        }
      }
    }
    return matches;
  }

  /// Returns false and restores the board if the adjacent swap makes no match.
  bool swap(int row, int col, int otherRow, int otherCol) {
    if (movesLeft <= 0 ||
        !_isAdjacent(row, col, otherRow, otherCol) ||
        isBlocked(row, col) ||
        isBlocked(otherRow, otherCol)) {
      return false;
    }
    _swap(row, col, otherRow, otherCol);
    if (findMatches().isEmpty) {
      _swap(row, col, otherRow, otherCol);
      return false;
    }
    movesLeft--;
    lastMoveCascades = const [];
    lastMoveScore = 0;
    final scoreBefore = score;
    _resolveCascades();
    lastMoveScore = score - scoreBefore;
    if (!hasPossibleMove) _shuffleUntilPlayable();
    return true;
  }

  void _fillFreshBoard() {
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (isBlocked(row, col)) {
          board[row][col] = null;
          continue;
        }
        var type = _random.nextInt(activeTypeCount);
        while ((col >= 2 &&
                !isBlocked(row, col - 1) &&
                !isBlocked(row, col - 2) &&
                board[row][col - 1] == type &&
                board[row][col - 2] == type) ||
            (row >= 2 &&
                !isBlocked(row - 1, col) &&
                !isBlocked(row - 2, col) &&
                board[row - 1][col] == type &&
                board[row - 2][col] == type)) {
          type = _random.nextInt(activeTypeCount);
        }
        board[row][col] = type;
      }
    }
    if (!hasPossibleMove) _shuffleUntilPlayable();
  }

  void _resolveCascades() {
    var combo = 1;
    final steps = <FruitPopCascadeStep>[];
    for (var cascade = 0; cascade < 100; cascade++) {
      final matches = findMatches();
      if (matches.isEmpty) {
        lastMoveCascades = List.unmodifiable(steps);
        return;
      }
      final before = _copyBoard();
      final points =
          matches.length * 10 * combo +
          (matches.length > 3 ? (matches.length - 3) * 15 : 0);
      score += points;
      for (final index in matches) {
        board[index ~/ size][index % size] = null;
      }
      _collapseAndRefill();
      steps.add(
        FruitPopCascadeStep(
          matchedCells: Set.unmodifiable(matches),
          beforeBoard: before,
          afterBoard: _copyBoard(),
          combo: combo,
          points: points,
        ),
      );
      combo++;
    }
    lastMoveCascades = List.unmodifiable(steps);
    _shuffleUntilPlayable();
  }

  List<List<int?>> _copyBoard() =>
      List.unmodifiable(board.map((row) => List<int?>.unmodifiable(row)));

  void _collapseAndRefill() {
    for (var col = 0; col < size; col++) {
      var segmentEnd = size - 1;
      while (segmentEnd >= 0) {
        if (isBlocked(segmentEnd, col)) {
          segmentEnd--;
          continue;
        }
        var segmentStart = segmentEnd;
        while (segmentStart > 0 && !isBlocked(segmentStart - 1, col)) {
          segmentStart--;
        }
        final values = <int>[
          for (var row = segmentStart; row <= segmentEnd; row++)
            if (board[row][col] case final int value) value,
        ];
        var writeRow = segmentEnd;
        for (final value in values.reversed) {
          board[writeRow--][col] = value;
        }
        while (writeRow >= segmentStart) {
          board[writeRow--][col] = _random.nextInt(activeTypeCount);
        }
        segmentEnd = segmentStart - 2;
      }
    }
  }

  void _shuffleUntilPlayable() {
    final playableIndices = <int>[
      for (var index = 0; index < size * size; index++)
        if (!blockers.contains(index)) index,
    ];
    final types = playableIndices
        .map((index) => board[index ~/ size][index % size]!)
        .toList();
    for (var attempt = 0; attempt < 100; attempt++) {
      _shuffle(types);
      for (var i = 0; i < types.length; i++) {
        final index = playableIndices[i];
        board[index ~/ size][index % size] = types[i];
      }
      if (findMatches().isEmpty && hasPossibleMove) return;
    }
    _fillFallbackBoard();
  }

  void _shuffle<T>(List<T> values) {
    for (var index = values.length - 1; index > 0; index--) {
      final other = _random.nextInt(index + 1);
      final value = values[index];
      values[index] = values[other];
      values[other] = value;
    }
  }

  void _fillFallbackBoard() {
    void resetPattern() {
      for (var row = 0; row < size; row++) {
        for (var col = 0; col < size; col++) {
          board[row][col] = isBlocked(row, col)
              ? null
              : (row * 2 + col) % activeTypeCount;
        }
      }
    }

    resetPattern();
    if (findMatches().isEmpty && hasPossibleMove) return;
    for (var row = 0; row < size - 1; row++) {
      for (var col = 0; col < size - 2; col++) {
        final motif = [
          row * size + col,
          row * size + col + 1,
          row * size + col + 2,
          (row + 1) * size + col + 1,
        ];
        if (motif.any(blockers.contains)) continue;
        for (var firstType = 0; firstType < activeTypeCount; firstType++) {
          final secondType = (firstType + 1) % activeTypeCount;
          resetPattern();
          board[row][col] = firstType;
          board[row][col + 1] = secondType;
          board[row][col + 2] = firstType;
          board[row + 1][col + 1] = firstType;
          if (findMatches().isEmpty && hasPossibleMove) return;
        }
      }
    }
  }

  bool _isAdjacent(int row, int col, int otherRow, int otherCol) =>
      row >= 0 &&
      row < size &&
      col >= 0 &&
      col < size &&
      otherRow >= 0 &&
      otherRow < size &&
      otherCol >= 0 &&
      otherCol < size &&
      (row - otherRow).abs() + (col - otherCol).abs() == 1;

  void _swap(int row, int col, int otherRow, int otherCol) {
    final value = board[row][col];
    board[row][col] = board[otherRow][otherCol];
    board[otherRow][otherCol] = value;
  }
}

final class FruitPopCascadeStep {
  const FruitPopCascadeStep({
    required this.matchedCells,
    required this.beforeBoard,
    required this.afterBoard,
    required this.combo,
    required this.points,
  });

  final Set<int> matchedCells;
  final List<List<int?>> beforeBoard;
  final List<List<int?>> afterBoard;
  final int combo;
  final int points;
}
