import 'dart:math' as math;

import '../deterministic_random.dart';
import '../fruit_pop_game.dart';
import '../game_id.dart';
import '../game_level.dart';
import '../game_level_adapter.dart';

final class FruitSimulationSummary {
  const FruitSimulationSummary({
    required this.wins,
    required this.simulations,
    required this.moveBudget,
    required this.parMoves,
  });

  final int wins;
  final int simulations;
  final int moveBudget;
  final int parMoves;
}

typedef FruitCandidateEvaluator =
    FruitSimulationSummary Function(FruitPopLevelLayout layout);

final class FruitPopOutcome implements GameLevelOutcome {
  const FruitPopOutcome({
    required this.rawScore,
    required this.movesUsed,
    required this.parMoves,
  });

  final int rawScore;
  final int movesUsed;
  final int parMoves;
}

final class FruitPopLevelAdapter implements GameLevelAdapter {
  FruitPopLevelAdapter({FruitCandidateEvaluator? evaluateCandidate})
    : _evaluateCandidate = evaluateCandidate ?? _runGreedySimulations;

  static const int _candidateLimit = 64;
  static const int _simulationCount = 16;
  static const int _requiredWins = 8;
  static const int _maximumMoveBudget = 30;
  static const Set<int> _reservedFallbackCells = {0, 1, 2, 8, 9};

  final FruitCandidateEvaluator _evaluateCandidate;

  @override
  GameId get gameId => GameId.fruitPop;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  FruitPopLevelLayout build(GameLevelDescriptor descriptor) {
    if (descriptor.gameId != gameId ||
        !supportsVersion(descriptor.generatorVersion)) {
      throw ArgumentError.value(descriptor, 'descriptor');
    }

    for (var attempt = 0; attempt < _candidateLimit; attempt++) {
      final candidate = _buildCandidate(
        descriptor,
        attempt: attempt,
        usedFallback: false,
      );
      final summary = _evaluateCandidate(candidate);
      if (_isAccepted(summary, candidate.baseMoveBudget)) {
        return _withSummary(candidate, summary);
      }
    }

    return _buildCandidate(
      descriptor,
      attempt: _candidateLimit - 1,
      usedFallback: true,
      forceFallbackBoard: true,
    );
  }

  FruitPopLevelLayout _buildCandidate(
    GameLevelDescriptor descriptor, {
    required int attempt,
    required bool usedFallback,
    bool forceFallbackBoard = false,
  }) {
    final pressure = descriptor.levelPressure;
    final typeCount = math.min(6, 5 + (pressure / 4).floor());
    final target = math.min(3000, 300 + (pressure * 250).round());
    final baseMoveBudget = math.max(14, 22 - (pressure / 2).floor());
    final blockerCount = math.min(8, math.max(0, (pressure - 3).floor()));
    final candidateSeed =
        (descriptor.seed ^
            ((attempt + 1) * 0x9e3779b9) ^
            (descriptor.retrySalt * 0x85ebca6b)) &
        0xffffffff;
    final random = StableRandom(candidateSeed);
    final blockers = _buildBlockers(blockerCount, random);
    final board = forceFallbackBoard
        ? _fallbackBoard(typeCount, blockers)
        : _buildPlayableBoard(typeCount, blockers, random);

    return FruitPopLevelLayout(
      level: descriptor.level,
      typeCount: typeCount,
      target: target,
      baseMoveBudget: baseMoveBudget,
      moveBudget: baseMoveBudget,
      parMoves: baseMoveBudget,
      refillSeed: random.nextUint32(),
      board: board,
      blockers: blockers,
      simulationWins: 0,
      simulationCount: _simulationCount,
      candidateAttempts: attempt + 1,
      usedFallback: usedFallback,
    );
  }

  static Set<int> _buildBlockers(int count, StableRandom random) {
    final candidates = <int>[
      for (
        var index = 0;
        index < FruitPopGame.size * FruitPopGame.size;
        index++
      )
        if (!_reservedFallbackCells.contains(index)) index,
    ];
    final shuffled = stableShuffle(candidates, random);
    return Set<int>.unmodifiable(shuffled.take(count));
  }

  static List<List<int?>> _buildPlayableBoard(
    int typeCount,
    Set<int> blockers,
    StableRandom random,
  ) {
    for (var boardAttempt = 0; boardAttempt < 32; boardAttempt++) {
      final board = List.generate(
        FruitPopGame.size,
        (_) => List<int?>.filled(FruitPopGame.size, null),
      );
      for (var row = 0; row < FruitPopGame.size; row++) {
        for (var column = 0; column < FruitPopGame.size; column++) {
          final index = row * FruitPopGame.size + column;
          if (blockers.contains(index)) continue;
          final choices = <int>[
            for (var type = 0; type < typeCount; type++)
              if (!_wouldCreateMatch(board, blockers, row, column, type)) type,
          ];
          board[row][column] = choices[random.nextInt(choices.length)];
        }
      }
      if (_hasPossibleMove(board, blockers)) return board;
    }
    return _fallbackBoard(typeCount, blockers);
  }

  static bool _wouldCreateMatch(
    List<List<int?>> board,
    Set<int> blockers,
    int row,
    int column,
    int type,
  ) {
    bool blocked(int checkRow, int checkColumn) =>
        blockers.contains(checkRow * FruitPopGame.size + checkColumn);

    final horizontal =
        column >= 2 &&
        !blocked(row, column - 1) &&
        !blocked(row, column - 2) &&
        board[row][column - 1] == type &&
        board[row][column - 2] == type;
    final vertical =
        row >= 2 &&
        !blocked(row - 1, column) &&
        !blocked(row - 2, column) &&
        board[row - 1][column] == type &&
        board[row - 2][column] == type;
    return horizontal || vertical;
  }

  static List<List<int?>> _fallbackBoard(int typeCount, Set<int> blockers) {
    final board = List.generate(
      FruitPopGame.size,
      (row) => List<int?>.generate(FruitPopGame.size, (column) {
        final index = row * FruitPopGame.size + column;
        return blockers.contains(index) ? null : (row * 2 + column) % typeCount;
      }),
    );
    board[0][0] = 0;
    board[0][1] = 1;
    board[0][2] = 0;
    board[1][0] = 1;
    board[1][1] = 0;
    return board;
  }

  static bool _hasPossibleMove(List<List<int?>> board, Set<int> blockers) {
    for (var row = 0; row < FruitPopGame.size; row++) {
      for (var column = 0; column < FruitPopGame.size; column++) {
        final index = row * FruitPopGame.size + column;
        if (blockers.contains(index)) continue;
        for (final (rowDelta, columnDelta) in const [(0, 1), (1, 0)]) {
          final otherRow = row + rowDelta;
          final otherColumn = column + columnDelta;
          if (otherRow >= FruitPopGame.size ||
              otherColumn >= FruitPopGame.size ||
              blockers.contains(otherRow * FruitPopGame.size + otherColumn)) {
            continue;
          }
          _swap(board, row, column, otherRow, otherColumn);
          final createsMatch = _findMatches(board, blockers).isNotEmpty;
          _swap(board, row, column, otherRow, otherColumn);
          if (createsMatch) return true;
        }
      }
    }
    return false;
  }

  static Set<int> _findMatches(List<List<int?>> board, Set<int> blockers) {
    final matches = <int>{};
    for (var row = 0; row < FruitPopGame.size; row++) {
      for (var column = 0; column < FruitPopGame.size; column++) {
        final index = row * FruitPopGame.size + column;
        if (blockers.contains(index)) continue;
        final type = board[row][column];
        if (type == null) continue;
        var end = column + 1;
        while (end < FruitPopGame.size &&
            !blockers.contains(row * FruitPopGame.size + end) &&
            board[row][end] == type) {
          end++;
        }
        if (end - column >= 3) {
          for (var matchColumn = column; matchColumn < end; matchColumn++) {
            matches.add(row * FruitPopGame.size + matchColumn);
          }
        }
        end = row + 1;
        while (end < FruitPopGame.size &&
            !blockers.contains(end * FruitPopGame.size + column) &&
            board[end][column] == type) {
          end++;
        }
        if (end - row >= 3) {
          for (var matchRow = row; matchRow < end; matchRow++) {
            matches.add(matchRow * FruitPopGame.size + column);
          }
        }
      }
    }
    return matches;
  }

  static void _swap(
    List<List<int?>> board,
    int row,
    int column,
    int otherRow,
    int otherColumn,
  ) {
    final value = board[row][column];
    board[row][column] = board[otherRow][otherColumn];
    board[otherRow][otherColumn] = value;
  }

  static bool _isAccepted(FruitSimulationSummary summary, int baseMoveBudget) =>
      summary.simulations == _simulationCount &&
      summary.wins >= _requiredWins &&
      summary.wins <= summary.simulations &&
      summary.moveBudget >= baseMoveBudget &&
      summary.moveBudget <= _maximumMoveBudget &&
      summary.parMoves >= 1 &&
      summary.parMoves <= summary.moveBudget;

  static FruitPopLevelLayout _withSummary(
    FruitPopLevelLayout layout,
    FruitSimulationSummary summary,
  ) => FruitPopLevelLayout(
    level: layout.level,
    typeCount: layout.typeCount,
    target: layout.target,
    baseMoveBudget: layout.baseMoveBudget,
    moveBudget: summary.moveBudget,
    parMoves: summary.parMoves,
    refillSeed: layout.refillSeed,
    board: layout.board,
    blockers: layout.blockers,
    simulationWins: summary.wins,
    simulationCount: summary.simulations,
    candidateAttempts: layout.candidateAttempts,
    usedFallback: false,
  );

  static FruitSimulationSummary _runGreedySimulations(
    FruitPopLevelLayout layout,
  ) {
    final winningMoveCounts = <int>[];
    for (var simulation = 0; simulation < _simulationCount; simulation++) {
      final simulationLayout = FruitPopLevelLayout(
        level: layout.level,
        typeCount: layout.typeCount,
        target: layout.target,
        baseMoveBudget: layout.baseMoveBudget,
        moveBudget: _maximumMoveBudget,
        parMoves: _maximumMoveBudget,
        refillSeed: layout.refillSeed,
        board: layout.board,
        blockers: layout.blockers,
        simulationWins: 0,
        simulationCount: _simulationCount,
        candidateAttempts: layout.candidateAttempts,
      );
      final game = FruitPopGame.fromLayout(simulationLayout);
      final tieBreaker = StableRandom(
        (layout.refillSeed ^ ((simulation + 1) * 0x27d4eb2d)) & 0xffffffff,
      );
      while (!game.isWon && !game.isOutOfMoves) {
        final moves = _bestImmediateMoves(game);
        if (moves.isEmpty) break;
        final move = moves[tieBreaker.nextInt(moves.length)];
        if (!game.swap(
          move.row,
          move.column,
          move.otherRow,
          move.otherColumn,
        )) {
          break;
        }
      }
      if (game.isWon) winningMoveCounts.add(game.movesUsed);
    }

    winningMoveCounts.sort();
    if (winningMoveCounts.length < _requiredWins) {
      return FruitSimulationSummary(
        wins: winningMoveCounts.length,
        simulations: _simulationCount,
        moveBudget: _maximumMoveBudget,
        parMoves: _maximumMoveBudget,
      );
    }
    final moveBudget = math.max(
      layout.baseMoveBudget,
      winningMoveCounts[_requiredWins - 1],
    );
    final acceptedWins = winningMoveCounts
        .where((moves) => moves <= moveBudget)
        .toList();
    final parMoves = acceptedWins[acceptedWins.length ~/ 2];
    return FruitSimulationSummary(
      wins: acceptedWins.length,
      simulations: _simulationCount,
      moveBudget: moveBudget,
      parMoves: math.max(1, parMoves),
    );
  }

  static List<_FruitMove> _bestImmediateMoves(FruitPopGame game) {
    final legalMoves = <_FruitMove>[];
    for (var row = 0; row < FruitPopGame.size; row++) {
      for (var column = 0; column < FruitPopGame.size; column++) {
        if (game.isBlocked(row, column)) continue;
        for (final (rowDelta, columnDelta) in const [(0, 1), (1, 0)]) {
          final otherRow = row + rowDelta;
          final otherColumn = column + columnDelta;
          if (otherRow >= FruitPopGame.size ||
              otherColumn >= FruitPopGame.size ||
              game.isBlocked(otherRow, otherColumn)) {
            continue;
          }
          _swap(game.board, row, column, otherRow, otherColumn);
          final createsMatch = game.findMatches().isNotEmpty;
          _swap(game.board, row, column, otherRow, otherColumn);
          if (createsMatch) {
            legalMoves.add(_FruitMove(row, column, otherRow, otherColumn));
          }
        }
      }
    }

    var bestScoreGain = -1;
    final bestMoves = <_FruitMove>[];
    for (final move in legalMoves) {
      final trial = game.copyForSimulation();
      if (!trial.swap(move.row, move.column, move.otherRow, move.otherColumn)) {
        continue;
      }
      final scoreGain = trial.score - game.score;
      if (scoreGain > bestScoreGain) {
        bestScoreGain = scoreGain;
        bestMoves
          ..clear()
          ..add(move);
      } else if (scoreGain == bestScoreGain) {
        bestMoves.add(move);
      }
    }
    return bestMoves;
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) {
    if (outcome is! FruitPopOutcome ||
        outcome.rawScore < 0 ||
        outcome.movesUsed < 0 ||
        outcome.parMoves < 1) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    final actualMoves = math.max(1, outcome.movesUsed);
    final denominator = math.max(outcome.parMoves, actualMoves);
    return (100 * outcome.parMoves / denominator).round().clamp(0, 100);
  }
}

final class _FruitMove {
  const _FruitMove(this.row, this.column, this.otherRow, this.otherColumn);

  final int row;
  final int column;
  final int otherRow;
  final int otherColumn;
}
