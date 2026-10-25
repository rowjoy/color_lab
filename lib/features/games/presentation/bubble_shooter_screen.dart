import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/game_adapter_registry.dart';
import '../application/game_audio.dart';
import '../application/game_profiles_provider.dart';
import '../domain/adapters/bubble_shooter_level_adapter.dart';
import '../domain/bubble_shooter_game.dart';
import '../domain/game_id.dart';
import '../domain/game_launch.dart';
import '../domain/game_progression_engine.dart';
import 'game_play_app_bar.dart';
import 'bubble_shooter_painter.dart';

class BubbleShooterScreen extends ConsumerStatefulWidget {
  const BubbleShooterScreen({super.key, required this.launch, this.onOpenMap});

  final GameLaunch launch;
  final VoidCallback? onOpenMap;

  @override
  ConsumerState<BubbleShooterScreen> createState() =>
      _BubbleShooterScreenState();
}

enum _RoundAction { tryAgain, retrySave, nextLevel, close }

class _BubbleShooterScreenState extends ConsumerState<BubbleShooterScreen>
    with SingleTickerProviderStateMixin {
  late GameLaunch _launch;
  late BubbleShooterGame _game;
  late final AnimationController _clock;
  final List<BubbleBurst> _bursts = [];
  final Stopwatch _stopwatch = Stopwatch();
  double _elapsed = 0;
  double _angle = -math.pi / 2;
  double _boardHeight = 28;
  double _shooterY = 25.5;
  double? _rowDropAt;
  bool _soundEnabled = true;
  bool _aiming = false;
  bool _dialogOpen = false;
  bool _roundFinishing = false;
  bool _saveInFlight = false;
  bool _attemptInFlight = false;

  bool get _controlsLocked =>
      _roundFinishing || _saveInFlight || _attemptInFlight;

  @override
  void initState() {
    super.initState();
    _launch = widget.launch;
    _game = _buildGame(_launch);
    _clock =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_onFrame)
          ..repeat();
    _stopwatch.start();
  }

  @override
  void didUpdateWidget(covariant BubbleShooterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launch.attemptId == widget.launch.attemptId) return;
    final game = _buildGame(widget.launch);
    _stopwatch
      ..reset()
      ..start();
    _launch = widget.launch;
    _game = game;
    _bursts.clear();
    _elapsed = 0;
    _rowDropAt = null;
    _angle = -math.pi / 2;
    _aiming = false;
    _roundFinishing = false;
    _saveInFlight = false;
    _attemptInFlight = false;
  }

  BubbleShooterGame _buildGame(GameLaunch launch) {
    if (launch.gameId != GameId.bubbleShooter) {
      throw ArgumentError.value(
        launch.gameId,
        'launch',
        'Bubble Shooter requires a Bubble Shooter launch',
      );
    }
    final layout = ref
        .read(gameAdapterRegistryProvider)
        .adapterFor(launch.gameId)
        .build(launch.descriptor);
    if (layout is! BubbleShooterLevelLayout ||
        layout.level != launch.descriptor.level) {
      throw StateError('Bubble Shooter adapter returned the wrong layout.');
    }
    return BubbleShooterGame.fromLayout(layout);
  }

  @override
  void dispose() {
    _clock.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  void _onFrame() {
    final now = _stopwatch.elapsedMicroseconds / 1000000;
    final dt = (_elapsed == 0 ? 0.0 : (now - _elapsed))
        .clamp(0.0, .05)
        .toDouble();
    _elapsed = now;
    if (!_attemptInFlight && _game.shot != null && dt > 0) {
      final before = _copyGrid();
      final shotColor = _game.shot!.color;
      final result = _game.advanceShot(dt, boardHeight: _boardHeight);
      if (result.wallBounce && _soundEnabled) {
        unawaited(GameAudio.play('stick'));
      }
      if (result.landed) {
        _captureRemoved(before, result.newRow, result.dropped > 0, shotColor);
        if (_soundEnabled) {
          unawaited(GameAudio.play(result.popped > 0 ? 'pop' : 'stick'));
          if (result.dropped > 0) unawaited(GameAudio.play('fall'));
          if (result.newRow) unawaited(GameAudio.play('row'));
        }
        HapticFeedback.selectionClick();
        if (mounted) setState(() {});
      }
      if (result.won) {
        unawaited(_finishRound(won: true));
      } else if (result.lost) {
        unawaited(_finishRound(won: false));
      }
    }
    _bursts.removeWhere(
      (burst) => _elapsed - burst.startedAt > (burst.falling ? .7 : .52),
    );
  }

  List<List<int?>> _copyGrid() => _game.grid.map(List<int?>.of).toList();

  void _captureRemoved(
    List<List<int?>> before,
    bool newRow,
    bool dropped,
    int poppedColor,
  ) {
    for (var row = 0; row < before.length; row++) {
      for (var col = 0; col < before[row].length; col++) {
        final color = before[row][col];
        final targetRow = row + (newRow ? 1 : 0);
        if (color == null ||
            targetRow >= _game.grid.length ||
            _game.grid[targetRow][col] != null) {
          continue;
        }
        _bursts.add(
          BubbleBurst(
            x: 1 + col * 2 + (row.isOdd ? 1 : 0),
            y: 1 + row * BubbleShooterGame.rowSpacing,
            color: color,
            startedAt: _elapsed,
            falling: dropped && color != poppedColor,
          ),
        );
      }
    }
    if (newRow) _rowDropAt = _elapsed;
  }

  double _angleTo(Offset point, Size size) {
    final radius = size.width / BubbleShooterGame.worldWidth;
    var angle = math.atan2(
      point.dy / radius - _shooterY,
      point.dx / radius - BubbleShooterGame.worldWidth / 2,
    );
    if (angle > -.15) angle = angle < math.pi / 2 ? -.15 : -math.pi + .15;
    return angle.clamp(-math.pi + .15, -.15);
  }

  void _aimAt(Offset point, Size size) {
    if (_controlsLocked) return;
    setState(() {
      _angle = _angleTo(point, size);
      _aiming = true;
    });
  }

  void _fire() {
    if (_controlsLocked) return;
    if (_game.launchAt(_angle, shooterY: _shooterY)) {
      if (_soundEnabled) unawaited(GameAudio.play('shoot'));
      HapticFeedback.lightImpact();
      setState(() => _aiming = false);
    }
  }

  void _swap() {
    if (_controlsLocked || _game.shot != null || _game.isWon || _game.isLost) {
      return;
    }
    setState(_game.swapColors);
    if (_soundEnabled) unawaited(GameAudio.play('swap'));
  }

  Future<void> _restart() async {
    if (_controlsLocked) return;
    final launch = _launch;
    if (!_isActiveProfile(launch)) {
      setState(() => _roundFinishing = true);
      await _showStaleSessionDialog();
      if (_isCurrent(launch)) setState(() => _roundFinishing = false);
      return;
    }
    if (_soundEnabled) unawaited(GameAudio.play('tap'));
    if (!await _beginFreshAttempt(launch) && _isCurrent(launch)) {
      _showStartFailure('Level could not restart. Try again.');
    }
  }

  bool _isCurrent(GameLaunch launch) =>
      mounted && _launch.attemptId == launch.attemptId;

  bool _isActiveProfile(GameLaunch launch) {
    if (!_isCurrent(launch)) return false;
    final profiles = ref.read(gameProfilesProvider);
    return profiles.hasValue &&
        profiles.requireValue.activeProfileId == launch.profileId;
  }

  Future<bool> _beginFreshAttempt(GameLaunch previous) async {
    if (_attemptInFlight || !mounted) return false;
    setState(() => _attemptInFlight = true);
    try {
      final controller = ref.read(gameProfilesProvider.notifier);
      final launch = await switch (previous.playKind) {
        GamePlayKind.current => controller.beginCurrentAttempt(
          profileId: previous.profileId,
          gameId: previous.gameId,
        ),
        GamePlayKind.replay => controller.beginReplayAttempt(
          profileId: previous.profileId,
          gameId: previous.gameId,
          level: previous.descriptor.level,
        ),
      };
      if (!_isCurrent(previous)) return false;
      final game = _buildGame(launch);
      if (!_isCurrent(previous)) return false;
      _applyLaunch(launch, game);
      return true;
    } catch (_) {
      if (_isCurrent(previous)) setState(() => _attemptInFlight = false);
      return false;
    }
  }

  Future<bool> _beginPersistedNextAttempt(GameLaunch completedLaunch) async {
    if (_attemptInFlight || !mounted) return false;
    setState(() => _attemptInFlight = true);
    try {
      final controller = ref.read(gameProfilesProvider.notifier);
      await controller.prepareGame(
        profileId: completedLaunch.profileId,
        gameId: completedLaunch.gameId,
      );
      if (!_isCurrent(completedLaunch)) return false;
      final launch = await controller.beginCurrentAttempt(
        profileId: completedLaunch.profileId,
        gameId: completedLaunch.gameId,
      );
      if (!_isCurrent(completedLaunch)) return false;
      final game = _buildGame(launch);
      if (!_isCurrent(completedLaunch)) return false;
      _applyLaunch(launch, game);
      return true;
    } catch (_) {
      if (_isCurrent(completedLaunch)) {
        setState(() => _attemptInFlight = false);
      }
      return false;
    }
  }

  void _applyLaunch(GameLaunch launch, BubbleShooterGame game) {
    _stopwatch
      ..reset()
      ..start();
    setState(() {
      _launch = launch;
      _game = game;
      _bursts.clear();
      _elapsed = 0;
      _rowDropAt = null;
      _angle = -math.pi / 2;
      _aiming = false;
      _roundFinishing = false;
      _saveInFlight = false;
      _attemptInFlight = false;
    });
  }

  Future<void> _finishRound({required bool won}) async {
    if (_roundFinishing || !mounted) return;
    setState(() => _roundFinishing = true);
    if (_soundEnabled) unawaited(GameAudio.play(won ? 'win' : 'lose'));
    if (won) {
      await _finishWin();
    } else {
      await _finishLoss();
    }
  }

  Future<void> _finishLoss() async {
    final launch = _launch;
    await Future<void>.delayed(const Duration(milliseconds: 420));
    while (_isCurrent(launch)) {
      final action = await _showLossDialog();
      if (!_isCurrent(launch) || action != _RoundAction.tryAgain) return;
      if (!_isActiveProfile(launch)) {
        await _showStaleSessionDialog();
        if (_isCurrent(launch)) setState(() => _roundFinishing = false);
        return;
      }
      if (_soundEnabled) unawaited(GameAudio.play('tap'));
      if (await _beginFreshAttempt(launch)) return;
      if (!_isCurrent(launch)) return;
      _showStartFailure('A new attempt could not be saved. Try again.');
    }
  }

  Future<void> _finishWin() async {
    final launch = _launch;
    final outcome = BubbleShooterOutcome(
      rawScore: _game.score,
      shotsFired: _game.shotsFired,
      parShots: _game.parShots,
    );
    var firstDialog = true;
    while (_isCurrent(launch)) {
      if (!_isActiveProfile(launch)) {
        await _showStaleSessionDialog();
        if (_isCurrent(launch)) setState(() => _roundFinishing = false);
        return;
      }
      LevelCompletionReceipt receipt;
      setState(() => _saveInFlight = true);
      try {
        receipt = await ref
            .read(gameProfilesProvider.notifier)
            .completeLevel(launch, outcome);
      } on GameProgressionException {
        if (!_isCurrent(launch)) return;
        setState(() => _saveInFlight = false);
        await _showStaleSessionDialog();
        if (_isCurrent(launch)) setState(() => _roundFinishing = false);
        return;
      } catch (_) {
        if (!_isCurrent(launch)) return;
        setState(() => _saveInFlight = false);
        if (firstDialog) {
          await Future<void>.delayed(const Duration(milliseconds: 420));
          firstDialog = false;
          if (!_isCurrent(launch)) return;
        }
        final action = await _showSaveFailureDialog();
        if (!_isCurrent(launch) || action != _RoundAction.retrySave) return;
        continue;
      }
      if (!_isCurrent(launch)) return;
      setState(() => _saveInFlight = false);
      if (firstDialog) {
        await Future<void>.delayed(const Duration(milliseconds: 420));
        firstDialog = false;
        if (!_isCurrent(launch)) return;
      }

      while (_isCurrent(launch)) {
        if (!_isActiveProfile(launch)) {
          await _showStaleSessionDialog();
          if (_isCurrent(launch)) setState(() => _roundFinishing = false);
          return;
        }
        final action = await _showWinDialog(receipt);
        if (!_isCurrent(launch) || action != _RoundAction.nextLevel) return;
        if (_soundEnabled) unawaited(GameAudio.play('tap'));
        if (await _beginPersistedNextAttempt(launch)) return;
        if (!_isCurrent(launch)) return;
        _showStartFailure('Next level could not be started. Try again.');
      }
    }
  }

  Future<_RoundAction?> _showLossDialog() => _showRoundDialog(
    icon: const Icon(Icons.bubble_chart_rounded, size: 42),
    title: 'Almost there!',
    content: 'Try a new angle and clear the bubbles. Score: ${_game.score}',
    action: _RoundAction.tryAgain,
    actionIcon: Icons.refresh_rounded,
    actionLabel: 'Try again',
  );

  Future<_RoundAction?> _showSaveFailureDialog() => _showRoundDialog(
    icon: const Icon(Icons.cloud_off_rounded, size: 42),
    title: 'Could not save win',
    content: 'Your level is still open. Retry save to keep your progress.',
    action: _RoundAction.retrySave,
    actionIcon: Icons.refresh_rounded,
    actionLabel: 'Retry save',
  );

  Future<_RoundAction?> _showStaleSessionDialog() => _showRoundDialog(
    icon: const Icon(Icons.sync_problem_rounded, size: 42),
    title: 'Session changed',
    content:
        'This attempt is no longer current. Return to the map to start again.',
    action: _RoundAction.close,
    actionIcon: Icons.close_rounded,
    actionLabel: 'Close',
  );

  Future<_RoundAction?> _showWinDialog(LevelCompletionReceipt receipt) {
    final showRewards = !receipt.alreadyApplied;
    final lines = <String>['Beautiful shot! Score: ${_game.score}'];
    if (showRewards && receipt.coinsAwarded > 0) {
      lines.add('+${receipt.coinsAwarded} coins');
    }
    if (showRewards && receipt.badgeId != null) {
      lines.add('Badge earned');
    }
    return _showRoundDialog(
      icon: Icon(
        showRewards ? Icons.celebration_rounded : Icons.check_circle_rounded,
        size: 42,
      ),
      title: receipt.alreadyApplied ? 'Level already saved' : 'Board cleared!',
      content: lines.join('\n'),
      action: _RoundAction.nextLevel,
      actionIcon: Icons.arrow_forward_rounded,
      actionLabel: 'Next Level',
    );
  }

  Future<_RoundAction?> _showRoundDialog({
    required Widget icon,
    required String title,
    required String content,
    required _RoundAction action,
    required IconData actionIcon,
    required String actionLabel,
  }) async {
    if (_dialogOpen || !mounted) return null;
    _dialogOpen = true;
    try {
      return await showDialog<_RoundAction>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            icon: icon,
            title: Text(title),
            content: Text(content, textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(action),
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  void _showStartFailure(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff40317f),
      appBar: GamePlayAppBar(
        title: 'Bubble Shooter',
        subtitle:
            'Level ${_launch.descriptor.level} · ${_launch.descriptor.tier.label}',
        onBack: () => Navigator.of(context).maybePop(),
        onOpenMap: widget.onOpenMap,
        soundEnabled: _soundEnabled,
        onToggleSound: () => setState(() => _soundEnabled = !_soundEnabled),
        onRestart: () => unawaited(_restart()),
        locked: _controlsLocked,
        backgroundColor: const Color(0xff6250bb),
        foregroundColor: Colors.white,
        buttonColor: Colors.white.withValues(alpha: .14),
        accentColor: const Color(0xffffd77d),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: Row(
                children: [
                  _scorePill('LEVEL', '${_launch.descriptor.level}'),
                  const SizedBox(width: 8),
                  _scorePill('TIER', _launch.descriptor.tier.label),
                  const Spacer(),
                  _scorePill('SCORE', '${_game.score}'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Tap to shoot • Drag to aim • Match 3 bubbles to pop',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .86),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final radius = size.width / BubbleShooterGame.worldWidth;
                  _boardHeight = size.height / radius;
                  _shooterY = _boardHeight - 2.5;
                  return AnimatedBuilder(
                    animation: _clock,
                    builder: (context, _) => GestureDetector(
                      key: const ValueKey('bubble-shooter-board'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _controlsLocked
                          ? null
                          : (event) {
                              _aimAt(event.localPosition, size);
                              _fire();
                            },
                      onPanStart: _controlsLocked
                          ? null
                          : (event) => _aimAt(event.localPosition, size),
                      onPanUpdate: _controlsLocked
                          ? null
                          : (event) => _aimAt(event.localPosition, size),
                      onPanEnd: _controlsLocked ? null : (_) => _fire(),
                      child: CustomPaint(
                        size: size,
                        painter: BubbleShooterPainter(
                          game: _game,
                          grid: _copyGrid(),
                          angle: _angle,
                          aiming: _aiming,
                          elapsed: _elapsed,
                          bursts: List.of(_bursts),
                          rowDropAt: _rowDropAt,
                          shooterY: _shooterY,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          !_controlsLocked &&
                              _game.shot == null &&
                              !_game.isWon &&
                              !_game.isLost
                          ? _swap
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x88ffffff)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Swap bubbles'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          !_controlsLocked &&
                              _game.shot == null &&
                              !_game.isWon &&
                              !_game.isLost
                          ? _fire
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xff43347f),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('Shoot'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scorePill(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: .16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label  ',
          style: const TextStyle(
            color: Color(0xbbffffff),
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
