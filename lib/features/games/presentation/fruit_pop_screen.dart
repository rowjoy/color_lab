import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_adapter_registry.dart';
import '../application/game_audio.dart';
import '../application/game_profiles_provider.dart';
import '../domain/adapters/fruit_pop_level_adapter.dart';
import '../domain/fruit_pop_game.dart';
import '../domain/game_id.dart';
import '../domain/game_launch.dart';
import '../domain/game_progression_engine.dart';
import 'game_play_app_bar.dart';
import 'fruit_pop_swipe.dart';

class FruitPopScreen extends ConsumerStatefulWidget {
  const FruitPopScreen({required this.launch, this.onOpenMap, super.key});

  final GameLaunch launch;
  final VoidCallback? onOpenMap;

  @override
  ConsumerState<FruitPopScreen> createState() => _FruitPopScreenState();
}

class _FruitPopScreenState extends ConsumerState<FruitPopScreen>
    with TickerProviderStateMixin {
  static const _fruit = ['🍎', '🥕', '🥦', '🍌', '🍇', '🍆'];
  late GameLaunch _launch;
  late FruitPopGame _game;
  List<List<int?>>? _visualBoard;
  Set<int> _poppingCells = const {};
  Set<int> _swapCells = const {};
  Map<int, Offset> _swapOffsets = const {};
  Set<int> _invalidSwapCells = const {};
  int _invalidSwapNonce = 0;
  int _comboCount = 0;
  int _comboPoints = 0;
  (int, int)? _selected;
  (int, int)? _dragStart;
  Offset? _dragOrigin;
  Offset _dragDelta = Offset.zero;
  bool _moveBusy = false;
  bool _attemptBusy = false;
  bool _completionInFlight = false;
  bool _lossDialogVisible = false;
  bool _dialogOpen = false;
  bool _sound = true;
  late final AnimationController _stageClock;
  late final AnimationController _hintPulse;
  Timer? _hintTimer;
  Set<int> _hintCells = const {};
  int _launchToken = 0;
  LevelCompletionReceipt? _completionReceipt;
  final _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _stageClock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hintPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _installLaunch(widget.launch);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _stageClock.dispose();
    _hintPulse.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FruitPopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launch != widget.launch) {
      _installLaunch(widget.launch);
    }
  }

  FruitPopGame _gameFor(GameLaunch launch) {
    if (launch.gameId != GameId.fruitPop) {
      throw ArgumentError.value(
        launch.gameId,
        'launch',
        'Fruit Pop requires a Fruit Pop launch',
      );
    }
    final layout = ref
        .read(gameAdapterRegistryProvider)
        .adapterFor(GameId.fruitPop)
        .build(launch.descriptor);
    if (layout is! FruitPopLevelLayout ||
        layout.level != launch.descriptor.level) {
      throw StateError('The Fruit Pop adapter returned an invalid layout.');
    }
    return FruitPopGame.fromLayout(layout);
  }

  void _installLaunch(GameLaunch launch, {FruitPopGame? game}) {
    _hintTimer?.cancel();
    _hintPulse.stop();
    _launchToken++;
    _launch = launch;
    _game = game ?? _gameFor(launch);
    _visualBoard = null;
    _poppingCells = const {};
    _swapCells = const {};
    _swapOffsets = const {};
    _invalidSwapCells = const {};
    _comboCount = 0;
    _comboPoints = 0;
    _hintCells = const {};
    _selected = null;
    _dragStart = null;
    _dragOrigin = null;
    _dragDelta = Offset.zero;
    _moveBusy = false;
    _attemptBusy = false;
    _completionInFlight = false;
    _lossDialogVisible = false;
    _completionReceipt = null;
    _scheduleIdleHint();
  }

  bool _isCurrent(GameLaunch launch, int token) =>
      mounted && _launchToken == token && _launch == launch;

  bool _isActiveProfile(GameLaunch launch, int token) {
    if (!_isCurrent(launch, token)) return false;
    final profiles = ref.read(gameProfilesProvider);
    return profiles.hasValue &&
        profiles.requireValue.activeProfileId == launch.profileId;
  }

  bool get _navigationLocked =>
      _moveBusy ||
      _attemptBusy ||
      _completionInFlight ||
      _lossDialogVisible ||
      _dialogOpen ||
      _completionReceipt != null;

  bool get _canPlay =>
      !_moveBusy &&
      !_attemptBusy &&
      !_completionInFlight &&
      _completionReceipt == null &&
      !_game.isWon &&
      !_game.isOutOfMoves;

  Future<void> _trySwap((int, int) a, (int, int) b) async {
    if (!_canPlay) return;
    _dismissIdleHint();
    final launch = _launch;
    final token = _launchToken;
    final before = _copyBoard(_game.board);
    final firstIndex = a.$1 * FruitPopGame.size + a.$2;
    final secondIndex = b.$1 * FruitPopGame.size + b.$2;
    final swapDelta = Offset(
      (b.$2 - a.$2).toDouble(),
      (b.$1 - a.$1).toDouble(),
    );
    setState(() => _moveBusy = true);
    final accepted = _game.swap(a.$1, a.$2, b.$1, b.$2);
    if (!accepted) {
      if (_sound) unawaited(GameAudio.play('invalid'));
      unawaited(HapticFeedback.lightImpact());
      if (_isCurrent(launch, token)) {
        setState(() {
          _selected = null;
          _invalidSwapCells = {firstIndex, secondIndex};
          _invalidSwapNonce++;
        });
        await _waitForStage(const Duration(milliseconds: 220));
        if (!_isCurrent(launch, token)) return;
        setState(() {
          _invalidSwapCells = const {};
          _moveBusy = false;
        });
        _scheduleIdleHint();
      }
      return;
    }

    unawaited(HapticFeedback.selectionClick());
    final swapped = _copyBoard(before);
    final temp = swapped[a.$1][a.$2];
    swapped[a.$1][a.$2] = swapped[b.$1][b.$2];
    swapped[b.$1][b.$2] = temp;
    setState(() {
      _selected = null;
      _visualBoard = swapped;
      _swapCells = {firstIndex, secondIndex};
      _swapOffsets = {firstIndex: swapDelta, secondIndex: -swapDelta};
      _poppingCells = const {};
      _comboCount = 0;
      _comboPoints = 0;
    });
    await _waitForStage(const Duration(milliseconds: 110));
    if (!_isCurrent(launch, token)) return;

    for (final step in _game.lastMoveCascades.take(5)) {
      if (_sound) unawaited(GameAudio.play('pop'));
      setState(() {
        _visualBoard = _copyBoard(step.beforeBoard);
        _poppingCells = step.matchedCells;
        _swapCells = const {};
        _swapOffsets = const {};
        _comboCount = step.combo;
        _comboPoints = step.points;
      });
      await _waitForStage(const Duration(milliseconds: 130));
      if (!_isCurrent(launch, token)) return;
      setState(() {
        _visualBoard = _copyBoard(step.afterBoard);
        _poppingCells = const {};
      });
      await _waitForStage(const Duration(milliseconds: 160));
      if (!_isCurrent(launch, token)) return;
    }

    if (!_isCurrent(launch, token)) return;
    setState(() {
      _visualBoard = _copyBoard(_game.board);
      _poppingCells = const {};
      _swapCells = const {};
      _swapOffsets = const {};
      _comboCount = 0;
      _comboPoints = 0;
      _moveBusy = false;
    });
    _scheduleIdleHint();

    if (_game.isWon) {
      if (_sound) unawaited(GameAudio.play('win'));
      await _completeWin();
    } else if (_game.isOutOfMoves) {
      await _showGameOver();
    }
  }

  List<List<int?>> _copyBoard(List<List<int?>> board) =>
      board.map((row) => List<int?>.of(row)).toList();

  (int, int)? _findHintMove() {
    final probe = _game.copyForSimulation();
    for (var row = 0; row < FruitPopGame.size; row++) {
      for (var col = 0; col < FruitPopGame.size; col++) {
        if (_game.isBlocked(row, col)) continue;
        for (final (dr, dc) in const [(0, 1), (1, 0)]) {
          final otherRow = row + dr;
          final otherCol = col + dc;
          if (otherRow >= FruitPopGame.size ||
              otherCol >= FruitPopGame.size ||
              _game.isBlocked(otherRow, otherCol)) {
            continue;
          }
          final first = probe.board[row][col];
          probe.board[row][col] = probe.board[otherRow][otherCol];
          probe.board[otherRow][otherCol] = first;
          final makesMatch = probe.findMatches().isNotEmpty;
          final second = probe.board[otherRow][otherCol];
          probe.board[otherRow][otherCol] = probe.board[row][col];
          probe.board[row][col] = second;
          if (makesMatch) {
            return (
              row * FruitPopGame.size + col,
              otherRow * FruitPopGame.size + otherCol,
            );
          }
        }
      }
    }
    return null;
  }

  void _scheduleIdleHint() {
    _hintTimer?.cancel();
    if (!mounted || !_canPlay) return;
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_canPlay || _hintCells.isNotEmpty) return;
      final move = _findHintMove();
      if (move == null) return;
      setState(() => _hintCells = {move.$1, move.$2});
      _hintPulse.repeat(reverse: true);
    });
  }

  void _dismissIdleHint() {
    _hintTimer?.cancel();
    _hintTimer = null;
    if (_hintCells.isEmpty) return;
    _hintPulse.stop();
    setState(() => _hintCells = const {});
  }

  Future<void> _waitForStage(Duration duration) async {
    _stageClock.duration = duration;
    try {
      await _stageClock.forward(from: 0).orCancel;
    } on TickerCanceled {
      // A replaced or removed screen must not continue its old move sequence.
    }
  }

  Future<void> _completeWin() async {
    if (_completionInFlight || _completionReceipt != null || !_game.isWon) {
      return;
    }
    final launch = _launch;
    final token = _launchToken;
    final outcome = FruitPopOutcome(
      rawScore: _game.score,
      movesUsed: _game.movesUsed,
      parMoves: _game.parMoves,
    );
    while (_isCurrent(launch, token)) {
      setState(() => _completionInFlight = true);
      try {
        final receipt = await ref
            .read(gameProfilesProvider.notifier)
            .completeLevel(launch, outcome);
        if (!_isCurrent(launch, token)) return;
        setState(() {
          _completionInFlight = false;
          _completionReceipt = receipt;
        });
        await _showCompletion(receipt, launch, token);
        return;
      } catch (error) {
        if (!_isCurrent(launch, token)) return;
        setState(() => _completionInFlight = false);
        if (error is GameProgressionException &&
            error.code == GameProgressionError.staleAttempt) {
          _showMessage('This attempt is no longer active.');
          return;
        }
        final retry = await _showProtectedDialog<bool>(
          builder: (dialogContext) => AlertDialog(
            title: const Text('Could not save progress'),
            content: const Text(
              'Your win has not been saved yet. Check storage and try again.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Retry save'),
              ),
            ],
          ),
        );
        if (retry != true || !_isCurrent(launch, token)) return;
      }
    }
  }

  Future<void> _showCompletion(
    LevelCompletionReceipt receipt,
    GameLaunch launch,
    int token,
  ) async {
    if (!_isCurrent(launch, token)) return;
    final rewardLines = <String>[];
    if (!receipt.alreadyApplied && receipt.coinsAwarded > 0) {
      rewardLines.add('+${receipt.coinsAwarded} coins');
    }
    if (!receipt.alreadyApplied && receipt.badgeId != null) {
      rewardLines.add('Badge earned');
    }
    final details = <String>[
      'Score ${_game.score}',
      if (rewardLines.isNotEmpty) ...rewardLines,
      if (receipt.alreadyApplied) 'Progress already saved',
    ];
    final advance = await _showProtectedDialog<bool>(
      builder: (dialogContext) => AlertDialog(
        icon: const Text('🎉', style: TextStyle(fontSize: 42)),
        title: const Text('Level cleared!'),
        content: Text(details.join('\n')),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Next Level'),
          ),
        ],
      ),
    );
    if (advance == true && _isCurrent(launch, token)) {
      await _startNextLevel(launch, token);
    }
  }

  Future<void> _showGameOver() async {
    if (_lossDialogVisible || !_game.isOutOfMoves) return;
    final launch = _launch;
    final token = _launchToken;
    setState(() => _lossDialogVisible = true);
    final retry = await _showProtectedDialog<bool>(
      builder: (dialogContext) => AlertDialog(
        title: const Text('No moves left'),
        content: Text('Score ${_game.score} · Goal ${_game.target}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
    if (!_isCurrent(launch, token)) return;
    setState(() => _lossDialogVisible = false);
    if (retry == true) await _restartLevel();
  }

  Future<T?> _showProtectedDialog<T>({
    required Widget Function(BuildContext dialogContext) builder,
  }) async {
    if (!mounted || _dialogOpen) return null;
    setState(() => _dialogOpen = true);
    try {
      return await showDialog<T>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            PopScope(canPop: false, child: builder(dialogContext)),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  Future<GameLaunch> _beginFreshAttempt(GameLaunch launch) {
    final controller = ref.read(gameProfilesProvider.notifier);
    return switch (launch.playKind) {
      GamePlayKind.current => controller.beginCurrentAttempt(
        profileId: launch.profileId,
        gameId: GameId.fruitPop,
      ),
      GamePlayKind.replay => controller.beginReplayAttempt(
        profileId: launch.profileId,
        gameId: GameId.fruitPop,
        level: launch.descriptor.level,
      ),
    };
  }

  Future<void> _restartLevel() async {
    if (_attemptBusy || _completionInFlight) return;
    final previous = _launch;
    final token = _launchToken;
    if (!_isActiveProfile(previous, token)) {
      _showMessage('This player is no longer active.');
      return;
    }
    setState(() => _attemptBusy = true);
    try {
      final launch = await _beginFreshAttempt(previous);
      if (!_isCurrent(previous, token)) return;
      if (!_isActiveProfile(previous, token)) {
        setState(() => _attemptBusy = false);
        _showMessage('This player is no longer active.');
        return;
      }
      final game = _gameFor(launch);
      if (!_isCurrent(previous, token)) return;
      setState(() {
        _installLaunch(launch, game: game);
      });
    } catch (error) {
      if (!_isCurrent(previous, token)) return;
      setState(() => _attemptBusy = false);
      if (error is GameProgressionException &&
          error.code == GameProgressionError.staleAttempt) {
        _showMessage('This player is no longer active.');
        return;
      }
      _showMessage('This level could not be restarted. Try again.');
    }
  }

  Future<void> _startNextLevel(GameLaunch completedLaunch, int token) async {
    if (_attemptBusy || !_isCurrent(completedLaunch, token)) return;
    if (!_isActiveProfile(completedLaunch, token)) {
      _showMessage('This player is no longer active.');
      return;
    }
    setState(() => _attemptBusy = true);
    try {
      final controller = ref.read(gameProfilesProvider.notifier);
      await controller.prepareGame(
        profileId: completedLaunch.profileId,
        gameId: GameId.fruitPop,
      );
      if (!_isCurrent(completedLaunch, token)) return;
      if (!_isActiveProfile(completedLaunch, token)) {
        setState(() => _attemptBusy = false);
        _showMessage('This player is no longer active.');
        return;
      }
      final launch = await controller.beginCurrentAttempt(
        profileId: completedLaunch.profileId,
        gameId: GameId.fruitPop,
      );
      if (!_isCurrent(completedLaunch, token)) return;
      if (!_isActiveProfile(completedLaunch, token)) {
        setState(() => _attemptBusy = false);
        _showMessage('This player is no longer active.');
        return;
      }
      final game = _gameFor(launch);
      if (!_isCurrent(completedLaunch, token)) return;
      setState(() {
        _installLaunch(launch, game: game);
      });
    } catch (error) {
      if (!_isCurrent(completedLaunch, token)) return;
      setState(() => _attemptBusy = false);
      if (error is GameProgressionException &&
          error.code == GameProgressionError.staleAttempt) {
        _showMessage('This player is no longer active.');
        return;
      }
      _showMessage(
        'The next level could not be started.',
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => unawaited(_startNextLevel(completedLaunch, token)),
        ),
      );
    }
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Widget _ambientGlow(Color color, double size) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: .2), color.withValues(alpha: 0)],
        ),
      ),
    ),
  );

  void _beginDrag(Offset globalPosition) {
    if (!_canPlay) return;
    _dismissIdleHint();
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final cell = (box.size.width - 10) / FruitPopGame.size;
    final x = local.dx - 5;
    final y = local.dy - 5;
    if (x < 0 ||
        y < 0 ||
        x >= cell * FruitPopGame.size ||
        y >= cell * FruitPopGame.size) {
      return;
    }
    final start = ((y / cell).floor(), (x / cell).floor());
    if (_game.isBlocked(start.$1, start.$2)) return;
    _dragStart = start;
    _dragOrigin = globalPosition;
    _dragDelta = Offset.zero;
  }

  void _continueDrag(Offset globalPosition) {
    final start = _dragStart;
    final origin = _dragOrigin;
    if (start == null || origin == null) return;
    _dragDelta = globalPosition - origin;
    final boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final cellSize = boardBox == null
        ? 40.0
        : (boardBox.size.width - 10) / FruitPopGame.size;
    final target = fruitPopSwipeTarget(
      row: start.$1,
      col: start.$2,
      dx: _dragDelta.dx,
      dy: _dragDelta.dy,
      threshold: math.max(6.0, cellSize * .14),
    );
    if (target == null) return;
    _endDrag();
    unawaited(_trySwap(start, target));
  }

  void _endDrag() {
    _dragStart = null;
    _dragOrigin = null;
    _dragDelta = Offset.zero;
    _scheduleIdleHint();
  }

  void _tap(int row, int col) {
    _endDrag();
    if (!_canPlay || _game.isBlocked(row, col)) return;
    _dismissIdleHint();
    final point = (row, col);
    if (_selected == null) {
      setState(() => _selected = point);
      _scheduleIdleHint();
    } else if (_selected == point) {
      setState(() => _selected = null);
      _scheduleIdleHint();
    } else if ((_selected!.$1 - row).abs() + (_selected!.$2 - col).abs() == 1) {
      unawaited(_trySwap(_selected!, point));
    } else {
      setState(() => _selected = point);
      _scheduleIdleHint();
    }
  }

  @override
  Widget build(BuildContext context) {
    final descriptor = _launch.descriptor;
    final tier = descriptor.tier;
    final profiles = ref.watch(gameProfilesProvider);
    final launchProfile = profiles.hasValue
        ? profiles.requireValue.profiles[_launch.profileId]
        : null;
    final progress = launchProfile?.gameProgress[GameId.fruitPop];
    final best = progress?.bestScores[descriptor.level] ?? 0;
    final displayedBoard = _visualBoard ?? _game.board;
    return Scaffold(
      backgroundColor: const Color(0xff102a31),
      appBar: GamePlayAppBar(
        title: 'Fruit & Veggie Pop',
        subtitle: 'Level ${descriptor.level} · ${descriptor.tier.label}',
        onBack: () => Navigator.of(context).maybePop(),
        onOpenMap: widget.onOpenMap,
        soundEnabled: _sound,
        onToggleSound: () => setState(() => _sound = !_sound),
        onRestart: () => unawaited(_restartLevel()),
        locked: _navigationLocked || _attemptBusy,
        backgroundColor: const Color(0xff102a31),
        foregroundColor: Colors.white,
        buttonColor: Colors.white.withValues(alpha: .12),
        accentColor: const Color(0xff9aefc0),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xff102a31),
                    Color(0xff17434a),
                    Color(0xff25534a),
                  ],
                  stops: [0, .56, 1],
                ),
              ),
            ),
            Positioned(
              top: -95,
              left: -90,
              child: _ambientGlow(const Color(0xff56d6a0), 290),
            ),
            Positioned(
              top: 170,
              right: -150,
              child: _ambientGlow(const Color(0xff69c8e8), 330),
            ),
            Positioned(
              bottom: -180,
              left: 20,
              child: _ambientGlow(const Color(0xffaad85e), 340),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final boardWidth = math.min(
                  math.max(0.0, constraints.maxWidth - 12),
                  math.min(
                    constraints.maxHeight * .78,
                    math.max(0.0, constraints.maxHeight - 270),
                  ),
                );
                return Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 520,
                        minHeight: constraints.maxHeight - 24,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              _Stat(
                                label: 'SCORE',
                                value: '${_game.score}',
                                icon: Icons.stars_rounded,
                              ),
                              _Stat(
                                label: 'MOVES',
                                value: '${_game.movesLeft}',
                                icon: Icons.swap_horiz_rounded,
                              ),
                              _Stat(
                                label: 'Level ${descriptor.level}',
                                value: tier.label,
                                icon: Icons.trending_up_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .14),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'GOAL  ·  ${_game.target} POINTS',
                                  style: const TextStyle(
                                    color: Color(0xffe8fff5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .65,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: (_game.score / _game.target).clamp(
                                      0,
                                      1,
                                    ),
                                    minHeight: 9,
                                    color: const Color(0xff85e8ad),
                                    backgroundColor: Colors.white.withValues(
                                      alpha: .15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: boardWidth,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: GestureDetector(
                                key: const ValueKey('fruit-pop-board'),
                                onPanDown: (details) =>
                                    _beginDrag(details.globalPosition),
                                onPanStart: (details) =>
                                    _continueDrag(details.globalPosition),
                                onPanUpdate: (details) =>
                                    _continueDrag(details.globalPosition),
                                onPanEnd: (_) => _endDrag(),
                                onPanCancel: _endDrag,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      key: _boardKey,
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            const Color(0xffd9f3e8),
                                            const Color(0xffbde4d5),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(26),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: .62,
                                          ),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xff65d5a0,
                                            ).withValues(alpha: .2),
                                            blurRadius: 22,
                                            offset: const Offset(0, 9),
                                          ),
                                        ],
                                      ),
                                      child: GridView.builder(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount:
                                            FruitPopGame.size *
                                            FruitPopGame.size,
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: FruitPopGame.size,
                                              crossAxisSpacing: 2,
                                              mainAxisSpacing: 2,
                                            ),
                                        itemBuilder: (context, index) {
                                          final row =
                                              index ~/ FruitPopGame.size;
                                          final col = index % FruitPopGame.size;
                                          final type = displayedBoard[row][col];
                                          final selected =
                                              _selected == (row, col);
                                          final hinted = _hintCells.contains(
                                            index,
                                          );
                                          final popping = _poppingCells
                                              .contains(index);
                                          final swapping = _swapCells.contains(
                                            index,
                                          );
                                          final invalid = _invalidSwapCells
                                              .contains(index);
                                          const tileColors = [
                                            Color(0xffffd6df),
                                            Color(0xffffe1bd),
                                            Color(0xffcdefd4),
                                            Color(0xfffff0ad),
                                            Color(0xffdce3ff),
                                            Color(0xffefd9ff),
                                          ];
                                          Widget tile = GestureDetector(
                                            key: ValueKey(
                                              'fruit-cell-$row-$col',
                                            ),
                                            onTap: type == null
                                                ? null
                                                : () => _tap(row, col),
                                            child: AnimatedScale(
                                              scale: selected
                                                  ? .82
                                                  : popping
                                                  ? .12
                                                  : hinted
                                                  ? 1.04
                                                  : 1,
                                              duration: Duration(
                                                milliseconds: popping
                                                    ? 190
                                                    : 170,
                                              ),
                                              curve: popping
                                                  ? Curves.easeInBack
                                                  : Curves.easeOutBack,
                                              child: AnimatedOpacity(
                                                opacity: popping ? 0 : 1,
                                                duration: const Duration(
                                                  milliseconds: 170,
                                                ),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 170,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: type == null
                                                        ? LinearGradient(
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight,
                                                            colors: [
                                                              const Color(
                                                                0xffc9ead9,
                                                              ),
                                                              const Color(
                                                                0xffecf8ef,
                                                              ),
                                                            ],
                                                          )
                                                        : LinearGradient(
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight,
                                                            colors: [
                                                              Color.lerp(
                                                                tileColors[type],
                                                                Colors.white,
                                                                .28,
                                                              )!,
                                                              tileColors[type],
                                                              Color.lerp(
                                                                tileColors[type],
                                                                Colors.black,
                                                                .06,
                                                              )!,
                                                            ],
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    border: selected
                                                        ? Border.all(
                                                            color: const Color(
                                                              0xff17855c,
                                                            ),
                                                            width: 2.5,
                                                          )
                                                        : hinted
                                                        ? Border.all(
                                                            color: const Color(
                                                              0xffffd66e,
                                                            ),
                                                            width: 2.4,
                                                          )
                                                        : Border.all(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: .7,
                                                                ),
                                                            width: 1,
                                                          ),
                                                    boxShadow: [
                                                      if (hinted)
                                                        BoxShadow(
                                                          color:
                                                              const Color(
                                                                0xffffcd58,
                                                              ).withValues(
                                                                alpha: .72,
                                                              ),
                                                          blurRadius: 15,
                                                          spreadRadius: 1,
                                                        ),
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: .12,
                                                            ),
                                                        offset: const Offset(
                                                          0,
                                                          3,
                                                        ),
                                                        blurRadius: 5,
                                                      ),
                                                    ],
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: type == null
                                                      ? const Icon(
                                                          Icons.block_rounded,
                                                          size: 24,
                                                        )
                                                      : AnimatedSwitcher(
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    260,
                                                              ),
                                                          switchInCurve: Curves
                                                              .easeOutCubic,
                                                          switchOutCurve: Curves
                                                              .easeInCubic,
                                                          transitionBuilder: (child, animation) {
                                                            final incoming =
                                                                swapping
                                                                ? (_swapOffsets[index] ??
                                                                          const Offset(
                                                                            0,
                                                                            -.85,
                                                                          )) *
                                                                      .8
                                                                : const Offset(
                                                                    0,
                                                                    -.85,
                                                                  );
                                                            return FadeTransition(
                                                              opacity:
                                                                  animation,
                                                              child: SlideTransition(
                                                                position: Tween<Offset>(
                                                                  begin:
                                                                      incoming,
                                                                  end: Offset
                                                                      .zero,
                                                                ).animate(animation),
                                                                child: ScaleTransition(
                                                                  scale:
                                                                      animation,
                                                                  child: child,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          child: FittedBox(
                                                            key: ValueKey(type),
                                                            child: Text(
                                                              _fruit[type],
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        45,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          );
                                          if (invalid) {
                                            tile = TweenAnimationBuilder<double>(
                                              key: ValueKey(
                                                'invalid-$_invalidSwapNonce-$index',
                                              ),
                                              tween: Tween(begin: 0, end: 1),
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                              builder:
                                                  (context, value, child) =>
                                                      Transform.translate(
                                                        offset: Offset(
                                                          math.sin(
                                                                value *
                                                                    math.pi *
                                                                    4,
                                                              ) *
                                                              (1 - value) *
                                                              5,
                                                          0,
                                                        ),
                                                        child: child,
                                                      ),
                                              child: tile,
                                            );
                                          }
                                          if (hinted) {
                                            tile = AnimatedBuilder(
                                              animation: _hintPulse,
                                              builder: (context, child) =>
                                                  Transform.scale(
                                                    scale:
                                                        1 +
                                                        _hintPulse.value * .045,
                                                    child: child,
                                                  ),
                                              child: tile,
                                            );
                                          }
                                          return tile;
                                        },
                                      ),
                                    ),
                                    if (_comboCount > 0)
                                      Positioned(
                                        top: 10,
                                        left: 0,
                                        right: 0,
                                        child: IgnorePointer(
                                          child: Center(
                                            child: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              transitionBuilder:
                                                  (child, animation) =>
                                                      ScaleTransition(
                                                        scale: animation,
                                                        child: FadeTransition(
                                                          opacity: animation,
                                                          child: child,
                                                        ),
                                                      ),
                                              child: Container(
                                                key: ValueKey(
                                                  'combo-$_comboCount-$_comboPoints',
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xffff8f3f),
                                                          Color(0xffef477c),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xffd94471,
                                                      ).withValues(alpha: .36),
                                                      blurRadius: 14,
                                                      offset: const Offset(
                                                        0,
                                                        5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  '${_comboCount > 1 ? 'COMBO ×$_comboCount  ·  ' : 'POP  ·  '}+$_comboPoints',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: .4,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_hintCells.isNotEmpty)
                                      Positioned(
                                        bottom: 10,
                                        left: 0,
                                        right: 0,
                                        child: IgnorePointer(
                                          child: Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xff173a3d,
                                                ).withValues(alpha: .94),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xffffd66e,
                                                  ).withValues(alpha: .75),
                                                ),
                                              ),
                                              child: const Text(
                                                'TRY THIS SWAP',
                                                style: TextStyle(
                                                  color: Color(0xffffe49a),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: .9,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'SWIPE TO MATCH 3 OR MORE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .83),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Best: $best     ·     ${tier.rewardCoins} coins per win',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .62),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .14),
            Colors.white.withValues(alpha: .055),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: const Color(0xff9aefc0)),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .45),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              fontSize: 10,
              letterSpacing: .8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
