import 'dart:math';

import 'game_level_adapter.dart';

final class WaterSegment {
  const WaterSegment(this.color, this.amount);

  final int color;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is WaterSegment && other.color == color && other.amount == amount;

  @override
  int get hashCode => Object.hash(color, amount);
}

final class WaterSortMove {
  const WaterSortMove({required this.source, required this.target});

  final int source;
  final int target;

  @override
  bool operator ==(Object other) =>
      other is WaterSortMove &&
      other.source == source &&
      other.target == target;

  @override
  int get hashCode => Object.hash(source, target);
}

final class WaterSortLevelLayout implements GameLevelLayout {
  factory WaterSortLevelLayout({
    required int level,
    required int colorCount,
    required int scrambleDepth,
    required List<List<WaterSegment>> tubes,
    required List<WaterSortMove> inverseSolution,
    required int parMoves,
    required int candidateAttempts,
    bool usedFallback = false,
  }) {
    final safeTubes = List<List<WaterSegment>>.unmodifiable(
      tubes.map((tube) => List<WaterSegment>.unmodifiable(tube)),
    );
    final safeSolution = List<WaterSortMove>.unmodifiable(inverseSolution);
    if (level < 1 ||
        colorCount < 3 ||
        colorCount > 9 ||
        scrambleDepth < 1 ||
        safeTubes.length != colorCount + 2 ||
        safeTubes.where((tube) => tube.isEmpty).length != 2 ||
        safeSolution.length != scrambleDepth ||
        parMoves != safeSolution.length ||
        candidateAttempts < 1 ||
        candidateAttempts > 64 ||
        safeSolution.any(
          (move) =>
              move.source < 0 ||
              move.source >= safeTubes.length ||
              move.target < 0 ||
              move.target >= safeTubes.length ||
              move.source == move.target,
        )) {
      throw ArgumentError('Invalid Water Sort layout');
    }
    final colorAmounts = List<int>.filled(colorCount, 0);
    var hasMixedTube = false;
    for (final tube in safeTubes) {
      final volume = tube.fold<int>(0, (sum, segment) => sum + segment.amount);
      if (tube.isNotEmpty && volume != WaterSortGame.tubeCapacity) {
        throw ArgumentError('Every non-empty tube must be full');
      }
      if (tube.length > 1) hasMixedTube = true;
      for (var index = 0; index < tube.length; index++) {
        final segment = tube[index];
        if (segment.color < 0 ||
            segment.color >= colorCount ||
            segment.amount < 1 ||
            segment.amount > WaterSortGame.tubeCapacity ||
            (index > 0 && tube[index - 1].color == segment.color)) {
          throw ArgumentError('Invalid Water Sort segment');
        }
        colorAmounts[segment.color] += segment.amount;
      }
    }
    if (!hasMixedTube ||
        colorAmounts.any((amount) => amount != WaterSortGame.tubeCapacity)) {
      throw ArgumentError('Water Sort layout must be mixed and balanced');
    }
    return WaterSortLevelLayout._(
      level: level,
      colorCount: colorCount,
      scrambleDepth: scrambleDepth,
      tubes: safeTubes,
      inverseSolution: safeSolution,
      parMoves: parMoves,
      candidateAttempts: candidateAttempts,
      usedFallback: usedFallback,
    );
  }

  const WaterSortLevelLayout._({
    required this.level,
    required this.colorCount,
    required this.scrambleDepth,
    required this.tubes,
    required this.inverseSolution,
    required this.parMoves,
    required this.candidateAttempts,
    required this.usedFallback,
  });

  final int level;
  final int colorCount;
  final int scrambleDepth;
  final List<List<WaterSegment>> tubes;
  final List<WaterSortMove> inverseSolution;
  final int parMoves;
  final int candidateAttempts;
  final bool usedFallback;

  int get capacity => WaterSortGame.tubeCapacity;

  @override
  String get canonicalSignature =>
      'water:v1|level=$level|colors=$colorCount|capacity=$capacity|'
      'depth=$scrambleDepth|par=$parMoves|'
      'tubes=${WaterSortGame._signatureOf(tubes)}';
}

final class WaterSortGame {
  WaterSortGame._({
    required this.level,
    required this.colorCount,
    required List<List<WaterSegment>> tubes,
  }) : tubes = _clone(tubes),
       _initialTubes = _clone(tubes);

  factory WaterSortGame.fromTubes(
    List<List<WaterSegment>> tubes, {
    int? colorCount,
    int level = 1,
  }) {
    final count =
        colorCount ??
        (tubes
            .expand((tube) => tube)
            .map((segment) => segment.color)
            .fold<int>(0, (maxColor, color) => max(maxColor, color + 1)));
    return WaterSortGame._(level: level, colorCount: count, tubes: tubes);
  }

  factory WaterSortGame.fromLayout(WaterSortLevelLayout layout) =>
      WaterSortGame._(
        level: layout.level,
        colorCount: layout.colorCount,
        tubes: layout.tubes,
      );

  factory WaterSortGame.generate({
    required int level,
    Random? random,
    String? previousSignature,
  }) {
    final safeLevel = max(1, level);
    final colors = min(9, 2 + safeLevel);
    final rng = random ?? Random.secure();
    late List<int> units;
    late List<List<WaterSegment>> tubes;
    var signature = '';
    var solved = false;
    for (var attempt = 0; attempt < 128; attempt++) {
      units = [
        for (var color = 0; color < colors; color++) ...List.filled(4, color),
      ]..shuffle(rng);
      tubes = _compactUnits(units, colors);
      signature = _signatureOf(tubes);
      solved = tubes.take(colors).any(_isComplete);
      if (!solved && signature != previousSignature) break;
    }
    if (solved || signature == previousSignature) {
      _swapDifferentColors(units);
      tubes = _compactUnits(units, colors);
    }
    return WaterSortGame._(level: safeLevel, colorCount: colors, tubes: tubes);
  }

  static const tubeCapacity = 4;

  final int level;
  final int colorCount;
  final List<List<WaterSegment>> tubes;
  final List<List<WaterSegment>> _initialTubes;
  final List<List<List<WaterSegment>>> _history = [];
  int moves = 0;

  bool get canUndo => _history.isNotEmpty;
  bool get isWon => tubes.every((tube) => tube.isEmpty || isTubeComplete(tube));

  String get signature => _signatureOf(tubes);

  bool isTubeComplete(List<WaterSegment> tube) => _isComplete(tube);

  bool canPour(int source, int target) {
    if (source < 0 ||
        target < 0 ||
        source >= tubes.length ||
        target >= tubes.length ||
        source == target ||
        isWon) {
      return false;
    }
    final from = tubes[source];
    final to = tubes[target];
    if (from.isEmpty || _isComplete(from) || _volume(to) >= tubeCapacity) {
      return false;
    }
    return to.isEmpty || to.last.color == from.last.color;
  }

  bool pour(int source, int target) {
    if (!canPour(source, target)) return false;
    _history.add(_clone(tubes));
    final from = tubes[source];
    final to = tubes[target];
    final top = from.removeLast();
    final amount = min(top.amount, tubeCapacity - _volume(to));
    if (top.amount > amount) {
      from.add(WaterSegment(top.color, top.amount - amount));
    }
    if (to.isNotEmpty && to.last.color == top.color) {
      to[to.length - 1] = WaterSegment(top.color, to.last.amount + amount);
    } else {
      to.add(WaterSegment(top.color, amount));
    }
    moves++;
    return true;
  }

  bool undo() {
    if (_history.isEmpty || isWon) return false;
    final previous = _history.removeLast();
    for (var i = 0; i < tubes.length; i++) {
      tubes[i]
        ..clear()
        ..addAll(previous[i]);
    }
    moves--;
    return true;
  }

  void restart() {
    for (var i = 0; i < tubes.length; i++) {
      tubes[i]
        ..clear()
        ..addAll(_initialTubes[i]);
    }
    _history.clear();
    moves = 0;
  }

  static bool _isComplete(List<WaterSegment> tube) =>
      tube.length == 1 && tube.single.amount == tubeCapacity;

  static int _volume(List<WaterSegment> tube) =>
      tube.fold(0, (sum, segment) => sum + segment.amount);

  static List<List<WaterSegment>> _compactUnits(List<int> units, int colors) {
    final tubes = <List<WaterSegment>>[];
    for (var tube = 0; tube < colors; tube++) {
      final segments = <WaterSegment>[];
      for (final color in units.skip(tube * tubeCapacity).take(tubeCapacity)) {
        if (segments.isNotEmpty && segments.last.color == color) {
          final top = segments.removeLast();
          segments.add(WaterSegment(color, top.amount + 1));
        } else {
          segments.add(WaterSegment(color, 1));
        }
      }
      tubes.add(segments);
    }
    tubes
      ..add([])
      ..add([]);
    return tubes;
  }

  static void _swapDifferentColors(List<int> units) {
    for (var first = 0; first < units.length; first++) {
      for (var second = first + 1; second < units.length; second++) {
        if (units[first] != units[second]) {
          final color = units[first];
          units[first] = units[second];
          units[second] = color;
          return;
        }
      }
    }
  }

  static String _signatureOf(List<List<WaterSegment>> tubes) => tubes
      .map(
        (tube) => tube
            .map((segment) => '${segment.color}:${segment.amount}')
            .join(','),
      )
      .join('/');

  static List<List<T>> _clone<T>(List<List<T>> source) =>
      source.map(List<T>.of).toList();
}
