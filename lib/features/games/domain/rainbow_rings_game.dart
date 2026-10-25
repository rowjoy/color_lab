import 'dart:math';

import 'game_level_adapter.dart';

int _rainbowParMoves(int colorCount, int capacity) =>
    (colorCount * capacity * .9 + colorCount).round();

enum RainbowRingsActionKind { select, deselect, move, undo, invalid, ignored }

final class RainbowRingsPosition {
  const RainbowRingsPosition({required this.peg, required this.slot});

  const RainbowRingsPosition.hover(this.peg) : slot = hoverSlot;

  static const int hoverSlot = -1;

  final int peg;
  final int slot;

  @override
  bool operator ==(Object other) =>
      other is RainbowRingsPosition && other.peg == peg && other.slot == slot;

  @override
  int get hashCode => Object.hash(peg, slot);
}

final class RainbowRingsMove {
  const RainbowRingsMove({
    required this.ringId,
    required this.sourcePeg,
    required this.sourceSlot,
    required this.destinationPeg,
    required this.destinationSlot,
  });

  final int ringId;
  final int sourcePeg;
  final int sourceSlot;
  final int destinationPeg;
  final int destinationSlot;

  int get source => sourcePeg;
  int get target => destinationPeg;

  @override
  bool operator ==(Object other) =>
      other is RainbowRingsMove &&
      other.ringId == ringId &&
      other.sourcePeg == sourcePeg &&
      other.sourceSlot == sourceSlot &&
      other.destinationPeg == destinationPeg &&
      other.destinationSlot == destinationSlot;

  @override
  int get hashCode => Object.hash(
    ringId,
    sourcePeg,
    sourceSlot,
    destinationPeg,
    destinationSlot,
  );
}

final class RainbowRingsActionResult {
  const RainbowRingsActionResult({
    required this.kind,
    this.ringId,
    this.source,
    this.destination,
    this.move,
  });

  final RainbowRingsActionKind kind;
  final int? ringId;
  final RainbowRingsPosition? source;
  final RainbowRingsPosition? destination;
  final RainbowRingsMove? move;

  bool get changed => switch (kind) {
    RainbowRingsActionKind.select ||
    RainbowRingsActionKind.deselect ||
    RainbowRingsActionKind.move ||
    RainbowRingsActionKind.undo => true,
    RainbowRingsActionKind.invalid || RainbowRingsActionKind.ignored => false,
  };

  @override
  bool operator ==(Object other) =>
      other is RainbowRingsActionResult &&
      other.kind == kind &&
      other.ringId == ringId &&
      other.source == source &&
      other.destination == destination &&
      other.move == move;

  @override
  int get hashCode => Object.hash(kind, ringId, source, destination, move);
}

final class RainbowRingsLevelLayout implements GameLevelLayout {
  factory RainbowRingsLevelLayout({
    required int level,
    required int colorCount,
    required int capacity,
    required int scrambleDepth,
    required List<int> ringColors,
    required List<List<int>> stacks,
    required List<RainbowRingsMove> inverseSolution,
    required int parMoves,
    required int candidateAttempts,
    bool usedFallback = false,
  }) {
    final safeColors = List<int>.unmodifiable(ringColors);
    final safeStacks = List<List<int>>.unmodifiable(
      stacks.map((stack) => List<int>.unmodifiable(stack)),
    );
    final safeSolution = List<RainbowRingsMove>.unmodifiable(inverseSolution);
    final ringCount = colorCount * capacity;
    if (level < 1 ||
        colorCount < 3 ||
        colorCount > 6 ||
        capacity < 4 ||
        capacity > 8 ||
        scrambleDepth < 1 ||
        safeColors.length != ringCount ||
        safeStacks.length != colorCount + 2 ||
        safeStacks.where((stack) => stack.isEmpty).length != 2 ||
        safeSolution.length != scrambleDepth ||
        parMoves != _rainbowParMoves(colorCount, capacity) ||
        candidateAttempts < 1 ||
        candidateAttempts > 64) {
      throw ArgumentError('Invalid Rainbow Rings layout');
    }
    final colorCounts = List<int>.filled(colorCount, 0);
    for (final color in safeColors) {
      if (color < 0 || color >= colorCount) {
        throw ArgumentError('Invalid Rainbow Rings color');
      }
      colorCounts[color]++;
    }
    final ringIds = <int>[];
    var everyOccupiedPegIsMixed = true;
    for (final stack in safeStacks) {
      if (stack.isNotEmpty) {
        if (stack.length != capacity) {
          throw ArgumentError('Every occupied Rainbow Rings peg must be full');
        }
        everyOccupiedPegIsMixed =
            everyOccupiedPegIsMixed &&
            stack.map((ring) => safeColors[ring]).toSet().length > 1;
      }
      ringIds.addAll(stack);
    }
    ringIds.sort();
    final hasEveryRing =
        ringIds.length == ringCount &&
        List<int>.generate(
          ringCount,
          (index) => index,
        ).every((ring) => ringIds[ring] == ring);
    if (colorCounts.any((count) => count != capacity) ||
        !hasEveryRing ||
        !everyOccupiedPegIsMixed ||
        safeSolution.any(
          (move) =>
              move.ringId < 0 ||
              move.ringId >= ringCount ||
              move.sourcePeg < 0 ||
              move.sourcePeg >= safeStacks.length ||
              move.destinationPeg < 0 ||
              move.destinationPeg >= safeStacks.length ||
              move.sourcePeg == move.destinationPeg ||
              move.sourceSlot < 0 ||
              move.sourceSlot >= capacity ||
              move.destinationSlot < 0 ||
              move.destinationSlot >= capacity,
        )) {
      throw ArgumentError('Invalid Rainbow Rings board or certificate');
    }
    return RainbowRingsLevelLayout._(
      level: level,
      colorCount: colorCount,
      capacity: capacity,
      scrambleDepth: scrambleDepth,
      ringColors: safeColors,
      stacks: safeStacks,
      inverseSolution: safeSolution,
      parMoves: parMoves,
      candidateAttempts: candidateAttempts,
      usedFallback: usedFallback,
    );
  }

  const RainbowRingsLevelLayout._({
    required this.level,
    required this.colorCount,
    required this.capacity,
    required this.scrambleDepth,
    required this.ringColors,
    required this.stacks,
    required this.inverseSolution,
    required this.parMoves,
    required this.candidateAttempts,
    required this.usedFallback,
  });

  final int level;
  final int colorCount;
  final int capacity;
  final int scrambleDepth;
  final List<int> ringColors;
  final List<List<int>> stacks;
  final List<RainbowRingsMove> inverseSolution;
  final int parMoves;
  final int candidateAttempts;
  final bool usedFallback;

  @override
  String get canonicalSignature {
    final ids = stacks.map((stack) => stack.join(',')).join('/');
    final colors = RainbowRingsGame._signatureOf(stacks, ringColors);
    return 'rainbow:v1|level=$level|colors=$colorCount|capacity=$capacity|'
        'depth=$scrambleDepth|par=$parMoves|ringColors=${ringColors.join(',')}|'
        'stacks=$ids|colorLayout=$colors';
  }
}

final class RainbowRingsGame {
  RainbowRingsGame._({
    required this.level,
    required this.capacity,
    required this.parMoves,
    required this.ringColors,
    required List<List<int>> stacks,
  }) : _initialStacks = stacks.map(List<int>.of).toList(),
       stacks = stacks.map(List<int>.of).toList();

  factory RainbowRingsGame.fromBoard({
    required int level,
    required int capacity,
    required List<int> ringColors,
    required List<List<int>> stacks,
    int? parMoves,
  }) => RainbowRingsGame._(
    level: level,
    capacity: capacity,
    parMoves: parMoves ?? _rainbowParMoves(ringColors.toSet().length, capacity),
    ringColors: List<int>.unmodifiable(ringColors),
    stacks: stacks,
  );

  factory RainbowRingsGame.fromLayout(RainbowRingsLevelLayout layout) =>
      RainbowRingsGame._(
        level: layout.level,
        capacity: layout.capacity,
        parMoves: layout.parMoves,
        ringColors: layout.ringColors,
        stacks: layout.stacks,
      );

  factory RainbowRingsGame.generate({
    required int level,
    Random? random,
    String? previousSignature,
  }) {
    final rng = random ?? Random.secure();
    final safeLevel = max(1, level);
    final colors = min(6, 2 + safeLevel);
    final capacity = min(8, 4 + safeLevel ~/ 2);
    late List<int> ringColors;
    late List<List<int>> stacks;
    var signature = '';
    var solved = false;
    for (var attempt = 0; attempt < 128; attempt++) {
      ringColors = [
        for (var color = 0; color < colors; color++)
          for (var ring = 0; ring < capacity; ring++) color,
      ]..shuffle(rng);
      stacks = [
        for (var peg = 0; peg < colors; peg++)
          [for (var slot = 0; slot < capacity; slot++) peg * capacity + slot],
        [],
        [],
      ];
      signature = _signatureOf(stacks, ringColors);
      solved = stacks
          .take(colors)
          .any(
            (peg) =>
                peg.every((ring) => ringColors[ring] == ringColors[peg.first]),
          );
      if (!solved && signature != previousSignature) break;
    }
    if (solved || signature == previousSignature) {
      _differentColors:
      for (var aPeg = 0; aPeg < colors; aPeg++) {
        for (var aSlot = 0; aSlot < capacity; aSlot++) {
          for (var bPeg = aPeg; bPeg < colors; bPeg++) {
            for (
              var bSlot = bPeg == aPeg ? aSlot + 1 : 0;
              bSlot < capacity;
              bSlot++
            ) {
              final first = stacks[aPeg][aSlot];
              final second = stacks[bPeg][bSlot];
              if (ringColors[first] != ringColors[second]) {
                stacks[aPeg][aSlot] = second;
                stacks[bPeg][bSlot] = first;
                break _differentColors;
              }
            }
          }
        }
      }
    }
    return RainbowRingsGame._(
      level: safeLevel,
      capacity: capacity,
      parMoves: _rainbowParMoves(colors, capacity),
      ringColors: List<int>.unmodifiable(ringColors),
      stacks: stacks,
    );
  }

  final int level;
  final int capacity;
  final int parMoves;
  final List<int> ringColors;
  final List<List<int>> stacks;
  final List<List<int>> _initialStacks;
  final List<RainbowRingsMove> _history = [];
  int? selectedPeg;
  int moves = 0;
  bool isWon = false;

  int get colorCount => ringColors.toSet().length;
  bool get canUndo => _history.isNotEmpty;
  String get signature => _signatureOf(stacks, ringColors);

  RainbowRingsActionResult tapPeg(int index) {
    if (isWon || index < 0 || index >= stacks.length) {
      return const RainbowRingsActionResult(
        kind: RainbowRingsActionKind.ignored,
      );
    }
    final selected = selectedPeg;
    if (selected == null) {
      final stack = stacks[index];
      if (stack.isEmpty) {
        return RainbowRingsActionResult(
          kind: RainbowRingsActionKind.invalid,
          destination: RainbowRingsPosition(peg: index, slot: 0),
        );
      }
      final source = RainbowRingsPosition(peg: index, slot: stack.length - 1);
      final ringId = stack.last;
      if (isPegComplete(index)) {
        return RainbowRingsActionResult(
          kind: RainbowRingsActionKind.invalid,
          ringId: ringId,
          source: source,
          destination: source,
        );
      }
      selectedPeg = index;
      return RainbowRingsActionResult(
        kind: RainbowRingsActionKind.select,
        ringId: ringId,
        source: source,
        destination: RainbowRingsPosition.hover(index),
      );
    }
    final source = stacks[selected];
    final ringId = source.last;
    if (selected == index) {
      selectedPeg = null;
      return RainbowRingsActionResult(
        kind: RainbowRingsActionKind.deselect,
        ringId: ringId,
        source: RainbowRingsPosition.hover(selected),
        destination: RainbowRingsPosition(
          peg: selected,
          slot: source.length - 1,
        ),
      );
    }
    final target = stacks[index];
    if (target.length >= capacity ||
        (target.isNotEmpty &&
            ringColors[target.last] != ringColors[source.last])) {
      return RainbowRingsActionResult(
        kind: RainbowRingsActionKind.invalid,
        ringId: ringId,
        source: RainbowRingsPosition.hover(selected),
        destination: RainbowRingsPosition(peg: index, slot: target.length),
      );
    }
    final move = RainbowRingsMove(
      ringId: ringId,
      sourcePeg: selected,
      sourceSlot: source.length - 1,
      destinationPeg: index,
      destinationSlot: target.length,
    );
    _history.add(move);
    target.add(source.removeLast());
    selectedPeg = null;
    moves++;
    isWon = _isComplete;
    return RainbowRingsActionResult(
      kind: RainbowRingsActionKind.move,
      ringId: ringId,
      source: RainbowRingsPosition.hover(selected),
      destination: RainbowRingsPosition(peg: index, slot: move.destinationSlot),
      move: move,
    );
  }

  RainbowRingsActionResult undo() {
    if (isWon || _history.isEmpty) {
      return const RainbowRingsActionResult(
        kind: RainbowRingsActionKind.ignored,
      );
    }
    selectedPeg = null;
    final forward = _history.removeLast();
    final currentSource = stacks[forward.destinationPeg];
    final restoredTarget = stacks[forward.sourcePeg];
    final sourceSlot = currentSource.length - 1;
    final destinationSlot = restoredTarget.length;
    final ringId = currentSource.removeLast();
    restoredTarget.add(ringId);
    moves--;
    final reverse = RainbowRingsMove(
      ringId: ringId,
      sourcePeg: forward.destinationPeg,
      sourceSlot: sourceSlot,
      destinationPeg: forward.sourcePeg,
      destinationSlot: destinationSlot,
    );
    return RainbowRingsActionResult(
      kind: RainbowRingsActionKind.undo,
      ringId: ringId,
      source: RainbowRingsPosition(
        peg: reverse.sourcePeg,
        slot: reverse.sourceSlot,
      ),
      destination: RainbowRingsPosition(
        peg: reverse.destinationPeg,
        slot: reverse.destinationSlot,
      ),
      move: reverse,
    );
  }

  bool isPegComplete(int index) {
    if (index < 0 || index >= stacks.length) return false;
    final stack = stacks[index];
    return stack.length == capacity &&
        stack.every((ring) => ringColors[ring] == ringColors[stack.first]);
  }

  RainbowRingsMove? suggestMove() {
    if (isWon) return null;
    RainbowRingsMove? matching;
    var matchingTargetSize = -1;
    for (var sourcePeg = 0; sourcePeg < stacks.length; sourcePeg++) {
      final source = stacks[sourcePeg];
      if (source.isEmpty || isPegComplete(sourcePeg)) continue;
      final ringId = source.last;
      final color = ringColors[ringId];
      for (
        var destinationPeg = 0;
        destinationPeg < stacks.length;
        destinationPeg++
      ) {
        if (destinationPeg == sourcePeg) continue;
        final destination = stacks[destinationPeg];
        if (destination.isEmpty ||
            destination.length >= capacity ||
            ringColors[destination.last] != color) {
          continue;
        }
        if (destination.length > matchingTargetSize) {
          matchingTargetSize = destination.length;
          matching = RainbowRingsMove(
            ringId: ringId,
            sourcePeg: sourcePeg,
            sourceSlot: source.length - 1,
            destinationPeg: destinationPeg,
            destinationSlot: destination.length,
          );
        }
      }
    }
    if (matching != null) return matching;

    final emptyPeg = stacks.indexWhere((stack) => stack.isEmpty);
    if (emptyPeg < 0) return null;
    for (var sourcePeg = 0; sourcePeg < stacks.length; sourcePeg++) {
      final source = stacks[sourcePeg];
      if (source.isEmpty || sourcePeg == emptyPeg) continue;
      final colors = source.map((ring) => ringColors[ring]).toSet();
      if (colors.length < 2) continue;
      return RainbowRingsMove(
        ringId: source.last,
        sourcePeg: sourcePeg,
        sourceSlot: source.length - 1,
        destinationPeg: emptyPeg,
        destinationSlot: 0,
      );
    }
    return null;
  }

  void restart() {
    for (var i = 0; i < stacks.length; i++) {
      stacks[i]
        ..clear()
        ..addAll(_initialStacks[i]);
    }
    selectedPeg = null;
    _history.clear();
    moves = 0;
    isWon = false;
  }

  bool get _isComplete =>
      List<int>.generate(
        stacks.length,
        (index) => index,
      ).where(isPegComplete).length ==
      colorCount;

  static String _signatureOf(List<List<int>> stacks, List<int> colors) =>
      stacks.map((peg) => peg.map((ring) => colors[ring]).join(',')).join('/');
}
