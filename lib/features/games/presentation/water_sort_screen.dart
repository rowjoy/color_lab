import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/game_adapter_registry.dart';
import '../application/game_audio.dart';
import '../application/game_profiles_provider.dart';
import '../domain/adapters/water_sort_level_adapter.dart';
import '../domain/game_id.dart';
import '../domain/game_launch.dart';
import '../domain/game_progression_engine.dart';
import '../domain/water_sort_game.dart';
import 'game_play_app_bar.dart';
import 'water_sort_painter.dart';

class WaterSortScreen extends ConsumerStatefulWidget {
  const WaterSortScreen({super.key, required this.launch, this.onOpenMap});

  final GameLaunch launch;
  final VoidCallback? onOpenMap;

  @override
  ConsumerState<WaterSortScreen> createState() => _WaterSortScreenState();
}

class _WaterSortScreenState extends ConsumerState<WaterSortScreen>
    with TickerProviderStateMixin {
  late GameLaunch _launch;
  late WaterSortGame _game;
  late int _parMoves;
  late final AnimationController _ambient;
  late final AnimationController _pourController;
  late final AnimationController _selectionController;
  late final AnimationController _confettiController;
  int? _selectedTube;
  WaterPourMotion? _motion;
  bool _soundEnabled = true;
  bool _pourSoundStarted = false;
  bool _showConfetti = false;
  bool _attemptBusy = false;
  bool _completionInFlight = false;
  bool _dialogOpen = false;
  int _launchToken = 0;
  LevelCompletionReceipt? _completionReceipt;

  bool get _navigationLocked =>
      _motion != null ||
      _attemptBusy ||
      _completionInFlight ||
      _dialogOpen ||
      _completionReceipt != null;

  @override
  void initState() {
    super.initState();
    _launchToken++;
    _launch = widget.launch;
    final session = _buildSession(_launch);
    _game = session.game;
    _parMoves = session.parMoves;
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _pourController = AnimationController(vsync: this)
      ..addListener(_onPourFrame)
      ..addStatusListener(_onPourStatus);
    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didUpdateWidget(covariant WaterSortScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launch == widget.launch) return;
    final session = _buildSession(widget.launch);
    _pourController
      ..stop()
      ..reset();
    _selectionController.reset();
    _confettiController.reset();
    _launchToken++;
    _launch = widget.launch;
    _game = session.game;
    _parMoves = session.parMoves;
    _selectedTube = null;
    _motion = null;
    _pourSoundStarted = false;
    _showConfetti = false;
    _attemptBusy = false;
    _completionInFlight = false;
    _dialogOpen = false;
    _completionReceipt = null;
  }

  ({WaterSortGame game, int parMoves}) _buildSession(GameLaunch launch) {
    if (launch.gameId != GameId.waterSort) {
      throw ArgumentError.value(
        launch.gameId,
        'launch',
        'Water Sort requires a Water Sort launch',
      );
    }
    final layout = ref
        .read(gameAdapterRegistryProvider)
        .adapterFor(GameId.waterSort)
        .build(launch.descriptor);
    if (layout is! WaterSortLevelLayout ||
        layout.level != launch.descriptor.level) {
      throw StateError('The Water Sort adapter returned an invalid layout.');
    }
    return (game: WaterSortGame.fromLayout(layout), parMoves: layout.parMoves);
  }

  bool _isCurrent(GameLaunch launch, int token) =>
      mounted && _launchToken == token && _launch == launch;

  bool _isActiveProfile(GameLaunch launch, int token) {
    if (!_isCurrent(launch, token)) return false;
    final profiles = ref.read(gameProfilesProvider);
    return profiles.hasValue &&
        profiles.requireValue.activeProfileId == launch.profileId;
  }

  Future<GameLaunch> _beginFreshAttempt(GameLaunch launch) {
    final controller = ref.read(gameProfilesProvider.notifier);
    return switch (launch.playKind) {
      GamePlayKind.current => controller.beginCurrentAttempt(
        profileId: launch.profileId,
        gameId: GameId.waterSort,
      ),
      GamePlayKind.replay => controller.beginReplayAttempt(
        profileId: launch.profileId,
        gameId: GameId.waterSort,
        level: launch.descriptor.level,
      ),
    };
  }

  void _applyLaunch(
    GameLaunch launch,
    ({WaterSortGame game, int parMoves}) session,
  ) {
    _pourController
      ..stop()
      ..reset();
    _selectionController.reset();
    _confettiController.reset();
    _launchToken++;
    setState(() {
      _launch = launch;
      _game = session.game;
      _parMoves = session.parMoves;
      _selectedTube = null;
      _motion = null;
      _pourSoundStarted = false;
      _showConfetti = false;
      _attemptBusy = false;
      _completionInFlight = false;
      _dialogOpen = false;
      _completionReceipt = null;
    });
  }

  @override
  void dispose() {
    _ambient.dispose();
    _pourController.dispose();
    _selectionController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onPourStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _motion == null || !mounted) {
      return;
    }
    final motion = _motion!;
    final wasComplete = List<bool>.generate(
      _game.tubes.length,
      (i) => _game.isTubeComplete(_game.tubes[i]),
    );
    _game.pour(motion.source, motion.target);
    final becameComplete = List<bool>.generate(
      _game.tubes.length,
      (i) => !wasComplete[i] && _game.isTubeComplete(_game.tubes[i]),
    ).any((value) => value);
    setState(() => _motion = null);
    if (_soundEnabled) {
      if (becameComplete) {
        unawaited(GameAudio.play('win'));
        unawaited(HapticFeedback.mediumImpact());
      }
    }
    if (_game.isWon) unawaited(_finishLevel());
  }

  void _onPourFrame() {
    final motion = _motion;
    if (motion == null || _pourSoundStarted || !_soundEnabled) return;
    if (motion.isPouringAt(_pourController.value)) {
      _pourSoundStarted = true;
      unawaited(GameAudio.playWaterPour(motion.amount));
    }
  }

  Future<void> _finishLevel() async {
    if (_completionInFlight || _completionReceipt != null || !_game.isWon) {
      return;
    }
    final launch = _launch;
    final token = _launchToken;
    if (!_isActiveProfile(launch, token)) {
      _showMessage('This attempt is no longer active.');
      return;
    }
    final moves = _game.moves;
    final outcome = WaterSortOutcome(actualMoves: moves, parMoves: _parMoves);
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
          _showConfetti = true;
        });
        _confettiController.forward(from: 0);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!_isCurrent(launch, token)) return;
        final advance = await _showCompletionDialog(
          receipt: receipt,
          moves: moves,
        );
        if (advance == true && _isCurrent(launch, token)) {
          if (!_isActiveProfile(launch, token)) {
            _leaveCompletedSession();
            _showMessage('This attempt is no longer active.');
            return;
          }
          await _startNextLevel(launch, token);
        }
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

  Future<bool?> _showCompletionDialog({
    required LevelCompletionReceipt receipt,
    required int moves,
  }) {
    final lines = <String>['Solved in $moves moves.'];
    if (!receipt.alreadyApplied && receipt.coinsAwarded > 0) {
      lines.add('+${receipt.coinsAwarded} coins');
    }
    if (!receipt.alreadyApplied && receipt.badgeId != null) {
      lines.add('Badge earned');
    }
    if (receipt.alreadyApplied) lines.add('Progress already saved');
    return _showProtectedDialog<bool>(
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.celebration_rounded, size: 42),
        title: const Text('Level complete!'),
        content: Text(lines.join('\n'), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Next Level'),
          ),
        ],
      ),
    );
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

  Future<void> _startNextLevel(GameLaunch completedLaunch, int token) async {
    if (_attemptBusy || !_isCurrent(completedLaunch, token)) return;
    while (_isCurrent(completedLaunch, token)) {
      if (!_isActiveProfile(completedLaunch, token)) {
        _leaveCompletedSession();
        _showMessage('This attempt is no longer active.');
        return;
      }
      setState(() => _attemptBusy = true);
      try {
        final controller = ref.read(gameProfilesProvider.notifier);
        await controller.prepareGame(
          profileId: completedLaunch.profileId,
          gameId: GameId.waterSort,
        );
        if (!_isCurrent(completedLaunch, token)) return;
        if (!_isActiveProfile(completedLaunch, token)) {
          _leaveCompletedSession();
          _showMessage('This attempt is no longer active.');
          return;
        }
        final launch = await controller.beginCurrentAttempt(
          profileId: completedLaunch.profileId,
          gameId: GameId.waterSort,
        );
        if (!_isCurrent(completedLaunch, token)) return;
        if (!_isActiveProfile(completedLaunch, token)) {
          _leaveCompletedSession();
          _showMessage('This attempt is no longer active.');
          return;
        }
        final session = _buildSession(launch);
        if (!_isCurrent(completedLaunch, token)) return;
        _applyLaunch(launch, session);
        return;
      } catch (error) {
        if (!_isCurrent(completedLaunch, token)) return;
        setState(() => _attemptBusy = false);
        if (error is GameProgressionException &&
            error.code == GameProgressionError.staleAttempt) {
          _leaveCompletedSession();
          _showMessage('This attempt is no longer active.');
          return;
        }
        final retry = await _showProtectedDialog<bool>(
          builder: (dialogContext) => AlertDialog(
            title: const Text('Could not start next level'),
            content: const Text(
              'The next level has not started yet. Check storage and retry.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Retry Next Level'),
              ),
            ],
          ),
        );
        if (retry != true || !_isCurrent(completedLaunch, token)) return;
      }
    }
  }

  void _leaveCompletedSession() {
    _confettiController.reset();
    setState(() {
      _attemptBusy = false;
      _completionInFlight = false;
      _completionReceipt = null;
      _showConfetti = false;
    });
  }

  void _tapBoard(Offset point, Size size) {
    if (_navigationLocked) return;
    final geometry = WaterSortGeometry.layout(size, _game.tubes.length);
    final tube = geometry.hitTest(point);
    if (tube == null) return;
    final selected = _selectedTube;
    if (selected == null) {
      if (_game.tubes[tube].isEmpty ||
          _game.isTubeComplete(_game.tubes[tube])) {
        _badMove();
        return;
      }
      setState(() => _selectedTube = tube);
      _selectionController.forward();
      _playClick();
      return;
    }
    if (selected == tube) {
      setState(() => _selectedTube = null);
      _selectionController.reverse();
      _playClick();
      return;
    }
    if (!_game.canPour(selected, tube)) {
      _badMove();
      if (_game.tubes[tube].isNotEmpty &&
          !_game.isTubeComplete(_game.tubes[tube])) {
        setState(() => _selectedTube = tube);
        _selectionController.forward();
      }
      return;
    }
    final source = _game.tubes[selected];
    final destination = _game.tubes[tube];
    final top = source.last;
    final amount = math.min(
      top.amount,
      WaterSortGame.tubeCapacity -
          destination.fold<int>(0, (sum, segment) => sum + segment.amount),
    );
    _motion = WaterPourMotion(
      source: selected,
      target: tube,
      color: top.color,
      amount: amount,
      direction: geometry.positions[tube].dx > geometry.positions[selected].dx
          ? 1
          : -1,
      pourMillis: 450 + 260 * amount,
    );
    _pourSoundStarted = false;
    setState(() => _selectedTube = null);
    _selectionController.reverse();
    _pourController.duration = Duration(milliseconds: _motion!.totalMillis);
    _pourController.forward(from: 0);
    if (_soundEnabled) {
      unawaited(GameAudio.play('tap'));
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _playClick() {
    if (_soundEnabled) unawaited(GameAudio.play('tap'));
  }

  void _badMove() {
    if (_soundEnabled) {
      unawaited(GameAudio.play('invalid'));
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _undo() {
    if (_navigationLocked) return;
    if (_game.undo()) {
      setState(() => _selectedTube = null);
      _selectionController.reverse();
      if (_soundEnabled) {
        unawaited(GameAudio.play('move'));
        unawaited(HapticFeedback.selectionClick());
      }
    }
  }

  Future<void> _restart() async {
    if (_navigationLocked) return;
    final previous = _launch;
    final token = _launchToken;
    if (!_isActiveProfile(previous, token)) {
      _showMessage('This attempt is no longer active.');
      return;
    }
    if (_motion != null) {
      _pourController.stop();
      _motion = null;
    }
    setState(() => _attemptBusy = true);
    try {
      final launch = await _beginFreshAttempt(previous);
      if (!_isCurrent(previous, token) || !_isActiveProfile(previous, token)) {
        if (_isCurrent(previous, token)) {
          setState(() => _attemptBusy = false);
          _showMessage('This attempt is no longer active.');
        }
        return;
      }
      final session = _buildSession(launch);
      if (!_isCurrent(previous, token)) return;
      _applyLaunch(launch, session);
      _playClick();
    } catch (_) {
      if (!_isCurrent(previous, token)) return;
      setState(() => _attemptBusy = false);
      _showMessage('This level could not be restarted. Try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xffeef0fa) : const Color(0xff2b2b3a);
    final bg1 = dark ? const Color(0xff2a3350) : const Color(0xffa9b8dc);
    final bg2 = dark ? const Color(0xff3b3452) : const Color(0xffcfc6de);
    final mutedColor = ink.withValues(alpha: .68);
    return Scaffold(
      backgroundColor: bg1,
      appBar: GamePlayAppBar(
        title: 'Water Sort',
        subtitle:
            'Level ${_launch.descriptor.level} · ${_launch.descriptor.tier.label}',
        onBack: () => context.pop(),
        onOpenMap: widget.onOpenMap,
        soundEnabled: _soundEnabled,
        onToggleSound: () => setState(() => _soundEnabled = !_soundEnabled),
        locked: _navigationLocked,
        backgroundColor: bg1,
        foregroundColor: ink,
        buttonColor: ink.withValues(alpha: .09),
        accentColor: dark ? const Color(0xffa4c8ff) : const Color(0xff385caa),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg1, bg2],
          ),
        ),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    children: [
                      _header(ink, mutedColor),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: dark ? .12 : .1),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final size = Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  );
                                  return GestureDetector(
                                    key: const ValueKey('water-sort-board'),
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: _navigationLocked
                                        ? null
                                        : (event) => _tapBoard(
                                            event.localPosition,
                                            size,
                                          ),
                                    child: AnimatedBuilder(
                                      animation: Listenable.merge([
                                        _ambient,
                                        _pourController,
                                        _selectionController,
                                      ]),
                                      builder: (context, _) => CustomPaint(
                                        size: size,
                                        painter: WaterSortPainter(
                                          tubes: _game.tubes
                                              .map(List<WaterSegment>.of)
                                              .toList(),
                                          geometry: WaterSortGeometry.layout(
                                            size,
                                            _game.tubes.length,
                                          ),
                                          selectedTube: _selectedTube,
                                          selectedLift:
                                              _selectionController.value,
                                          motion: _motion,
                                          motionProgress: _pourController.value,
                                          time: _ambient.value * 6,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      _controlBar(ink, bg1),
                    ],
                  ),
                ),
              ),
              if (_showConfetti)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _confettiController,
                      builder: (context, _) => CustomPaint(
                        painter: _ConfettiPainter(_confettiController.value),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Color ink, Color mutedColor) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CounterPill(
          label: 'Level',
          value: '${_launch.descriptor.level}',
          color: ink,
        ),
        const SizedBox(width: 7),
        _CounterPill(
          label: '',
          value: _launch.descriptor.tier.label,
          color: ink,
        ),
        const SizedBox(width: 7),
        _CounterPill(
          label: 'Moves',
          value: '${_game.moves + (_motion == null ? 0 : 1)}',
          color: ink,
          muted: mutedColor,
        ),
      ],
    ),
  );

  Widget _controlBar(Color ink, Color background) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _GameButton(
          icon: Icons.undo_rounded,
          label: 'Undo',
          enabled: _game.canUndo && !_navigationLocked,
          foreground: background,
          background: ink,
          onPressed: _undo,
        ),
        const SizedBox(width: 8),
        _GameButton(
          icon: Icons.refresh_rounded,
          label: 'Restart',
          enabled: !_navigationLocked,
          foreground: background,
          background: ink,
          onPressed: () => unawaited(_restart()),
        ),
      ],
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);
  final double progress;

  static final _particles = List.generate(70, (index) {
    final random = math.Random(index * 43 + 7);
    return (
      random.nextDouble(),
      random.nextDouble() * .5,
      1.6 + random.nextDouble() * 1.8,
      index % waterSortColors.length,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = progress * 2.2;
    for (final particle in _particles) {
      final local = (elapsed - particle.$2) / particle.$3;
      if (local < 0 || local > 1) continue;
      final rect = Rect.fromCenter(
        center: Offset(
          particle.$1 * size.width,
          -20 + local * (size.height + 40),
        ),
        width: 9,
        height: 13,
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(local * math.pi * 4);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: rect.width,
          height: rect.height,
        ),
        Paint()..color = waterSortColors[particle.$4],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({
    required this.label,
    required this.value,
    required this.color,
    this.muted,
  });
  final String label;
  final String value;
  final Color color;
  final Color? muted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text.rich(
      TextSpan(
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        children: [
          if (label.isNotEmpty)
            TextSpan(
              text: '$label ',
              style: TextStyle(color: muted ?? color),
            ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

class _GameButton extends StatelessWidget {
  const _GameButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final bool enabled;
  final Color foreground;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : .4,
    child: Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
