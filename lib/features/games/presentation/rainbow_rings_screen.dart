import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../application/game_adapter_registry.dart';
import '../application/game_audio.dart';
import '../application/game_profiles_provider.dart';
import '../domain/adapters/rainbow_rings_level_adapter.dart';
import '../domain/game_id.dart';
import '../domain/game_launch.dart';
import '../domain/game_profiles_state.dart';
import '../domain/game_progression_engine.dart';
import '../domain/player_profile.dart';
import '../domain/rainbow_rings_game.dart';
import 'rainbow_rings_animation.dart';
import 'game_play_app_bar.dart';
import 'rainbow_rings_painter.dart';

int rainbowRingsStarRating({required int moves, required int parMoves}) {
  if (moves <= parMoves) return 3;
  if (moves * 2 <= parMoves * 3) return 2;
  return 1;
}

String rainbowRingsStarSemanticsLabel({
  required int moves,
  required int parMoves,
}) => '${rainbowRingsStarRating(moves: moves, parMoves: parMoves)} of 3 stars';

const _ringColorNames = <String>[
  'Purple',
  'Blue',
  'Green',
  'Red',
  'Yellow',
  'Orange',
];

class RainbowRingsScreen extends ConsumerStatefulWidget {
  const RainbowRingsScreen({super.key, required this.launch, this.onOpenMap});

  final GameLaunch launch;
  final VoidCallback? onOpenMap;

  @override
  ConsumerState<RainbowRingsScreen> createState() => _RainbowRingsScreenState();
}

class _RainbowRingsScreenState extends ConsumerState<RainbowRingsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late GameLaunch _launch;
  late RainbowRingsGame _game;
  bool _soundEnabled = true;
  bool _attemptBusy = false;
  bool _completionInFlight = false;
  bool _dialogOpen = false;
  int _launchToken = 0;
  LevelCompletionReceipt? _completionReceipt;
  late final ValueNotifier<Duration> _paintClock;
  late RainbowRingsTimeline _paintTimeline;
  late final Ticker _ticker;
  final List<_ScheduledRainbowCallback> _animationCallbacks = [];
  final Set<Completer<bool>> _animationWaiters = {};
  final Map<int, int> _ringEffectTokens = {};
  final Set<int> _presentedCompletedPegs = {};
  final Set<int> _celebratedCompletedPegs = {};
  _PendingRainbowWin? _pendingWin;
  _PendingRainbowHint? _pendingHint;
  OverlayEntry? _confettiOverlay;
  Route<dynamic>? _activeDialogRoute;
  NavigatorState? _activeDialogNavigator;
  late final ProviderSubscription<AsyncValue<GameProfilesState>>
  _profilesSubscription;
  Duration _tickerEpoch = Duration.zero;
  bool _dependenciesReady = false;
  bool _lifecycleActive = true;
  bool _reducedMotion = false;
  bool _animationLocked = false;
  bool _winCelebrationStarted = false;
  String? _liveAnnouncement;
  int _liveAnnouncementRevision = 0;
  int _animationGeneration = 0;
  int _lockedActionToken = 0;
  int _animationCallbackSequence = 0;
  double _progressFrom = 0;
  double _progressTarget = 0;
  Duration _progressStartedAt = Duration.zero;

  @override
  void initState() {
    super.initState();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _lifecycleActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _paintClock = ValueNotifier(Duration.zero);
    _ticker = createTicker(_onTick);
    _installLaunch(widget.launch);
    _profilesSubscription = ref.listenManual(
      gameProfilesProvider,
      (_, next) => _handleProfilesChanged(next),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!_dependenciesReady) {
      _dependenciesReady = true;
      _reducedMotion = reducedMotion;
      _paintTimeline.reducedMotion = reducedMotion;
      if (!reducedMotion) _startTicker();
      _startIntro();
      return;
    }
    if (_reducedMotion == reducedMotion) return;
    final resumePendingModal =
        _winCelebrationStarted &&
        _completionReceipt != null &&
        !(_completionReceipt?.alreadyApplied ?? false) &&
        !_dialogOpen;
    final pendingHint = _pendingHint;
    _reducedMotion = reducedMotion;
    _invalidateAnimationCallbacks(animationWaitersReady: resumePendingModal);
    _paintTimeline.reducedMotion = reducedMotion;
    _paintTimeline.rememberRings(_ringPlacements);
    _paintTimeline.setCompletedPegs(_presentedCompletedPegs);
    if (pendingHint != null) {
      _startHintOrInvalid(
        pendingHint.hint,
        at: _now,
        fallbackPeg: pendingHint.fallbackPeg,
      );
    }
    _pendingWin?.completeDrop(_now);
    if (_pendingWin == null) {
      for (final peg in _completePegIndexes.difference(
        _presentedCompletedPegs,
      )) {
        _startCompletedPeg(peg, at: _now);
      }
    }
    if (reducedMotion) {
      _removeConfettiOverlay();
      _stopTicker();
    } else {
      _startTicker();
    }
  }

  @override
  void didUpdateWidget(covariant RainbowRingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launch != widget.launch) _installLaunch(widget.launch);
  }

  RainbowRingsGame _gameFor(GameLaunch launch) {
    if (launch.gameId != GameId.rainbowRings) {
      throw ArgumentError.value(
        launch.gameId,
        'launch',
        'Rainbow Rings requires a Rainbow Rings launch',
      );
    }
    final layout = ref
        .read(gameAdapterRegistryProvider)
        .adapterFor(GameId.rainbowRings)
        .build(launch.descriptor);
    if (layout is! RainbowRingsLevelLayout ||
        layout.level != launch.descriptor.level) {
      throw StateError('Rainbow Rings adapter returned an invalid layout.');
    }
    return RainbowRingsGame.fromLayout(layout);
  }

  void _installLaunch(GameLaunch launch, {RainbowRingsGame? game}) {
    _dismissActiveDialog();
    _removeConfettiOverlay();
    _pendingWin?.cancel();
    _pendingWin = null;
    _invalidateAnimationCallbacks();
    _launchToken++;
    _launch = launch;
    _game = game ?? _gameFor(launch);
    _attemptBusy = false;
    _completionInFlight = false;
    _completionReceipt = null;
    _winCelebrationStarted = false;
    _liveAnnouncement = null;
    _paintTimeline = RainbowRingsTimeline(
      seed: launch.descriptor.seed,
      reducedMotion: _reducedMotion,
    );
    final completed = _completePegIndexes;
    _presentedCompletedPegs
      ..clear()
      ..addAll(completed);
    _celebratedCompletedPegs
      ..clear()
      ..addAll(completed);
    _paintTimeline.setCompletedPegs(completed);
    final ratio = _completedRatio;
    _progressFrom = ratio;
    _progressTarget = ratio;
    _progressStartedAt = _paintClock.value;
    if (_dependenciesReady) _startIntro();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profilesSubscription.close();
    _dismissActiveDialog();
    _removeConfettiOverlay();
    _pendingWin?.cancel();
    _invalidateAnimationCallbacks();
    _ticker.dispose();
    _paintClock.dispose();
    super.dispose();
  }

  Duration get _now => _paintClock.value;

  void _onTick(Duration elapsed) {
    final next = _tickerEpoch + elapsed;
    if (_paintClock.value != next) _paintClock.value = next;
    _runDueAnimationCallbacks(next);
  }

  void _startTicker() {
    if (_ticker.isActive || !_lifecycleActive || _reducedMotion) return;
    _tickerEpoch = _paintClock.value;
    _ticker.start();
  }

  void _stopTicker() {
    if (!_ticker.isActive) return;
    _ticker.stop();
    _tickerEpoch = _paintClock.value;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_lifecycleActive == active) return;
    _lifecycleActive = active;
    if (active) {
      if (_dependenciesReady && !_reducedMotion) _startTicker();
    } else {
      _stopTicker();
    }
  }

  void _invalidateAnimationCallbacks({bool animationWaitersReady = false}) {
    _animationGeneration++;
    _lockedActionToken++;
    _animationLocked = false;
    _ringEffectTokens.clear();
    _pendingHint = null;
    for (final waiter in _animationWaiters.toList(growable: false)) {
      if (!waiter.isCompleted) waiter.complete(animationWaitersReady);
    }
    _animationWaiters.clear();
    _animationCallbacks.clear();
  }

  void _scheduleAnimation(
    Duration delay, {
    required int generation,
    required VoidCallback callback,
  }) {
    if (delay <= Duration.zero) {
      if (mounted && generation == _animationGeneration) callback();
      return;
    }
    _animationCallbacks.add(
      _ScheduledRainbowCallback(
        at: _now + delay,
        generation: generation,
        sequence: _animationCallbackSequence++,
        callback: callback,
      ),
    );
    _animationCallbacks.sort((a, b) {
      final timeOrder = a.at.compareTo(b.at);
      return timeOrder != 0 ? timeOrder : a.sequence.compareTo(b.sequence);
    });
  }

  void _runDueAnimationCallbacks(Duration now) {
    while (_animationCallbacks.isNotEmpty &&
        _animationCallbacks.first.at <= now) {
      final scheduled = _animationCallbacks.removeAt(0);
      if (!mounted || scheduled.generation != _animationGeneration) continue;
      scheduled.callback();
    }
  }

  Future<bool> _waitForAnimation(Duration delay) {
    if (delay <= Duration.zero) return Future<bool>.value(true);
    final waiter = Completer<bool>();
    _animationWaiters.add(waiter);
    final generation = _animationGeneration;
    _scheduleAnimation(
      delay,
      generation: generation,
      callback: () {
        _animationWaiters.remove(waiter);
        if (!waiter.isCompleted) waiter.complete(true);
      },
    );
    return waiter.future;
  }

  void _showConfettiOverlay() {
    if (!mounted || _reducedMotion || _confettiOverlay != null) return;
    final timeline = _paintTimeline;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('rainbow-rings-confetti'),
            painter: RainbowRingsConfettiPainter(
              timeline: timeline,
              clock: _paintClock,
            ),
          ),
        ),
      ),
    );
    _confettiOverlay = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _removeConfettiOverlay() {
    final entry = _confettiOverlay;
    _confettiOverlay = null;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  void _dismissActiveDialog() {
    final route = _activeDialogRoute;
    final navigator = _activeDialogNavigator;
    _activeDialogRoute = null;
    _activeDialogNavigator = null;
    _dialogOpen = false;
    if (route == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted || route.navigator != navigator) return;
      navigator.removeRoute(route);
    });
  }

  Iterable<RainbowRingsRingPlacement> get _ringPlacements sync* {
    for (var peg = 0; peg < _game.stacks.length; peg++) {
      for (var slot = 0; slot < _game.stacks[peg].length; slot++) {
        yield RainbowRingsRingPlacement(
          ringId: _game.stacks[peg][slot],
          position: RainbowRingsPosition(peg: peg, slot: slot),
        );
      }
    }
  }

  Set<int> get _completePegIndexes => {
    for (var peg = 0; peg < _game.stacks.length; peg++)
      if (_game.isPegComplete(peg)) peg,
  };

  Iterable<RainbowRingsRingPlacement> _ringsOnPeg(int peg) sync* {
    for (var slot = 0; slot < _game.stacks[peg].length; slot++) {
      yield RainbowRingsRingPlacement(
        ringId: _game.stacks[peg][slot],
        position: RainbowRingsPosition(peg: peg, slot: slot),
      );
    }
  }

  void _startIntro() {
    final rings = _ringPlacements.toList(growable: false);
    final timelineToken = _paintTimeline.startIntro(at: _now, rings: rings);
    if (_reducedMotion || rings.isEmpty) {
      _animationLocked = false;
      return;
    }
    _animationLocked = true;
    final generation = _animationGeneration;
    final lockToken = ++_lockedActionToken;
    final delay =
        RainbowRingsTiming.introStagger * (rings.length - 1) +
        RainbowRingsTiming.introUnlockPadding;
    _scheduleAnimation(
      delay,
      generation: generation,
      callback: () {
        if (lockToken != _lockedActionToken ||
            !_paintTimeline.isTokenCurrent(timelineToken)) {
          return;
        }
        setState(() => _animationLocked = false);
      },
    );
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
      _attemptBusy ||
      _completionInFlight ||
      _dialogOpen ||
      _completionReceipt != null;

  bool get _controlsLocked => _animationLocked || _navigationLocked;

  double get _completedRatio {
    if (_game.colorCount == 0) return 0;
    final completed = List<int>.generate(
      _game.stacks.length,
      (index) => index,
    ).where(_game.isPegComplete).length;
    return (completed / _game.colorCount).clamp(0.0, 1.0);
  }

  double _progressAt(Duration now) {
    if (_reducedMotion || _progressFrom == _progressTarget) {
      return _progressTarget;
    }
    final elapsed = now - _progressStartedAt;
    if (elapsed <= Duration.zero) return _progressFrom;
    if (elapsed >= RainbowRingsTiming.progress) return _progressTarget;
    final raw =
        elapsed.inMicroseconds / RainbowRingsTiming.progress.inMicroseconds;
    final eased = const Cubic(.34, 1.4, .6, 1).transform(raw).clamp(0.0, 1.0);
    return _progressFrom + (_progressTarget - _progressFrom) * eased;
  }

  void _syncCompletedProgress(Duration at) {
    final next = _completedRatio;
    if ((next - _progressTarget).abs() < .0000001) return;
    _progressFrom = _progressAt(at);
    _progressTarget = next;
    _progressStartedAt = at;
  }

  int _startTimelineAction(
    RainbowRingsActionResult action, {
    required Duration at,
  }) {
    final token = _paintTimeline.startAction(at: at, action: action);
    final ringId = action.ringId;
    if (ringId != null) _ringEffectTokens[ringId] = token;
    return token;
  }

  bool _startLandingIfCurrent(
    RainbowRingsActionResult action, {
    required Duration at,
    required int actionToken,
  }) {
    final ringId = action.ringId;
    final destination = action.destination;
    if (ringId == null ||
        destination == null ||
        destination.slot == RainbowRingsPosition.hoverSlot ||
        _ringEffectTokens[ringId] != actionToken ||
        !_paintTimeline.isTokenCurrent(actionToken)) {
      return false;
    }
    final stack = _game.stacks[destination.peg];
    if (destination.slot < 0 ||
        destination.slot >= stack.length ||
        stack[destination.slot] != ringId) {
      return false;
    }
    final landingToken = _paintTimeline.startLanding(
      at: at,
      ring: RainbowRingsRingPlacement(ringId: ringId, position: destination),
      lowerRingIds: stack.take(destination.slot),
    );
    _ringEffectTokens[ringId] = landingToken;
    return true;
  }

  void _lockForLanding(
    RainbowRingsActionResult action, {
    required Duration at,
    required Duration duration,
    required int actionToken,
    VoidCallback? onLanded,
  }) {
    final landingAt = _reducedMotion ? at : at + duration;
    if (_reducedMotion) {
      if (_startLandingIfCurrent(
        action,
        at: landingAt,
        actionToken: actionToken,
      )) {
        onLanded?.call();
      }
      return;
    }
    _animationLocked = true;
    final generation = _animationGeneration;
    final lockToken = ++_lockedActionToken;
    _scheduleAnimation(
      duration,
      generation: generation,
      callback: () {
        if (lockToken != _lockedActionToken) return;
        if (_startLandingIfCurrent(
          action,
          at: landingAt,
          actionToken: actionToken,
        )) {
          onLanded?.call();
        }
        setState(() => _animationLocked = false);
      },
    );
  }

  void _startCompletedPeg(int peg, {required Duration at}) {
    if (!_celebratedCompletedPegs.add(peg)) return;
    _presentedCompletedPegs.add(peg);
    _paintTimeline.startCompletedPeg(at: at, peg: peg, rings: _ringsOnPeg(peg));
    final praise = _paintTimeline.completedPegPraise(peg);
    _setLiveAnnouncement('$praise Peg ${peg + 1} completed.');
    if (_soundEnabled) unawaited(GameAudio.play('pop'));
    unawaited(HapticFeedback.mediumImpact());
  }

  void _presentCompletedPegsWithoutCelebration(Iterable<int> pegs) {
    _presentedCompletedPegs.addAll(pegs);
    _celebratedCompletedPegs.addAll(pegs);
    _paintTimeline.setCompletedPegs(_presentedCompletedPegs);
  }

  void _reconcileCompletedPegs() {
    final current = _completePegIndexes;
    final removed = _presentedCompletedPegs.difference(current);
    _presentedCompletedPegs.retainAll(current);
    _celebratedCompletedPegs.removeAll(removed);
    _paintTimeline.setCompletedPegs(_presentedCompletedPegs);
  }

  void _playActionFeedback(RainbowRingsActionKind kind) {
    switch (kind) {
      case RainbowRingsActionKind.select:
      case RainbowRingsActionKind.deselect:
      case RainbowRingsActionKind.move:
      case RainbowRingsActionKind.undo:
        if (_soundEnabled) unawaited(GameAudio.play('move'));
        unawaited(HapticFeedback.selectionClick());
      case RainbowRingsActionKind.invalid:
        _setLiveAnnouncement('That move is not allowed.');
        if (_soundEnabled) unawaited(GameAudio.play('invalid'));
        unawaited(HapticFeedback.lightImpact());
      case RainbowRingsActionKind.ignored:
        break;
    }
  }

  void _tapPeg(Offset position, Size size) {
    if (_controlsLocked || _game.isWon) return;
    final index = RainbowRingsGeometry.layout(
      size,
      pegCount: _game.stacks.length,
      capacity: _game.capacity,
    ).hitTest(position);
    if (index == null) return;
    _activatePeg(index);
  }

  void _activatePeg(int index) {
    if (_controlsLocked || _game.isWon) return;
    final at = _now;
    final completedBefore = _completePegIndexes;
    final action = _game.tapPeg(index);
    final newlyCompleted = _completePegIndexes.difference(completedBefore);
    final actionToken = _startTimelineAction(action, at: at);
    _playActionFeedback(action.kind);
    _PendingRainbowWin? pendingWin;
    if (action.kind == RainbowRingsActionKind.move && _game.isWon) {
      pendingWin = _PendingRainbowWin(
        launchToken: _launchToken,
        completedPegs: newlyCompleted,
      );
      _pendingWin = pendingWin;
    }
    switch (action.kind) {
      case RainbowRingsActionKind.deselect:
        _lockForLanding(
          action,
          at: at,
          duration: RainbowRingsTiming.deselectDrop,
          actionToken: actionToken,
        );
      case RainbowRingsActionKind.move:
        _lockForLanding(
          action,
          at: at,
          duration: RainbowRingsTiming.transfer + RainbowRingsTiming.drop,
          actionToken: actionToken,
          onLanded: () {
            final pending = pendingWin;
            if (pending != null) {
              pending.completeDrop(_now);
              return;
            }
            for (final peg in newlyCompleted) {
              _startCompletedPeg(peg, at: _now);
            }
          },
        );
      case RainbowRingsActionKind.select:
      case RainbowRingsActionKind.undo:
      case RainbowRingsActionKind.invalid:
      case RainbowRingsActionKind.ignored:
        break;
    }
    _syncCompletedProgress(at);
    setState(() {});
    if (pendingWin != null) {
      unawaited(_completeWin(pendingWin));
    }
  }

  LevelCompletionReceipt? _matchingReceiptFrom(
    GameProfilesState? profiles,
    GameLaunch launch,
  ) {
    final progress =
        profiles?.profiles[launch.profileId]?.gameProgress[launch.gameId];
    final receipt = progress?.latestReceipt;
    if (receipt == null ||
        receipt.attemptId != launch.attemptId ||
        receipt.level != launch.descriptor.level ||
        receipt.descriptorFingerprint != launch.descriptor.fingerprint) {
      return null;
    }
    return receipt;
  }

  LevelCompletionReceipt? _matchingReceipt(GameLaunch launch) =>
      _matchingReceiptFrom(
        ref.read(gameProfilesProvider).asData?.value,
        launch,
      );

  Future<LevelCompletionReceipt> _completeAtDurableReceipt(
    GameLaunch launch,
    RainbowRingsMoveOutcome outcome,
  ) {
    final observed = Completer<LevelCompletionReceipt>();
    final completion = ref
        .read(gameProfilesProvider.notifier)
        .completeLevel(launch, outcome);
    final subscription = ref.listenManual(gameProfilesProvider, (_, next) {
      final receipt = _matchingReceiptFrom(next.asData?.value, launch);
      if (receipt != null && !observed.isCompleted) {
        observed.complete(receipt);
      }
    }, fireImmediately: true);
    return Future.any<LevelCompletionReceipt>([
      completion,
      observed.future,
    ]).whenComplete(subscription.close);
  }

  bool _isPendingCurrent(
    _PendingRainbowWin pending,
    GameLaunch launch,
    int token,
  ) =>
      _isCurrent(launch, token) &&
      identical(_pendingWin, pending) &&
      pending.launchToken == token &&
      !pending.isCanceled;

  void _abortPendingWinAsStale(_PendingRainbowWin pending) {
    pending.cancel();
    if (identical(_pendingWin, pending)) _pendingWin = null;
    _dismissActiveDialog();
    _removeConfettiOverlay();
    _invalidateAnimationCallbacks();
    _paintTimeline.reset(
      seed: _launch.descriptor.seed,
      reducedMotion: _reducedMotion,
    );
    _paintTimeline.rememberRings(_ringPlacements);
    _paintTimeline.setCompletedPegs(_presentedCompletedPegs);
    setState(() {
      _completionInFlight = false;
      _completionReceipt = null;
      _winCelebrationStarted = false;
    });
    _showMessage('This attempt is no longer active.');
  }

  void _handleProfilesChanged(AsyncValue<GameProfilesState> next) {
    if (!mounted ||
        !next.hasValue ||
        next.requireValue.activeProfileId == _launch.profileId) {
      return;
    }
    final pending = _pendingWin;
    if (pending != null) _abortPendingWinAsStale(pending);
  }

  Future<void> _completeWin(_PendingRainbowWin pending) async {
    if (_completionInFlight ||
        _completionReceipt != null ||
        !_game.isWon ||
        !identical(_pendingWin, pending)) {
      return;
    }
    final launch = _launch;
    final token = _launchToken;
    final outcome = RainbowRingsMoveOutcome(
      actualMoves: _game.moves,
      parMoves: _game.parMoves,
    );
    if (!_isActiveProfile(launch, token)) {
      _showMessage('This attempt is no longer active.');
      return;
    }
    LevelCompletionReceipt? receipt;
    final existing = _matchingReceipt(launch);
    if (existing != null) {
      receipt = existing.asAlreadyApplied();
    }

    while (receipt == null && _isPendingCurrent(pending, launch, token)) {
      if (!_isActiveProfile(launch, token)) {
        _showMessage('This attempt is no longer active.');
        return;
      }
      setState(() => _completionInFlight = true);
      try {
        receipt = await _completeAtDurableReceipt(launch, outcome);
      } catch (error) {
        if (!_isPendingCurrent(pending, launch, token)) return;
        setState(() => _completionInFlight = false);
        if (!_isActiveProfile(launch, token)) {
          _showMessage('This attempt is no longer active.');
          return;
        }
        final durableReceipt = _matchingReceipt(launch);
        if (durableReceipt != null) {
          receipt =
              error is GameProgressionException &&
                  error.code == GameProgressionError.staleAttempt
              ? durableReceipt.asAlreadyApplied()
              : durableReceipt;
          break;
        }
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
        if (retry != true || !_isPendingCurrent(pending, launch, token)) {
          return;
        }
      }
    }
    if (receipt == null || !_isPendingCurrent(pending, launch, token)) return;
    if (!_isActiveProfile(launch, token)) {
      setState(() => _completionInFlight = false);
      _showMessage('This attempt is no longer active.');
      return;
    }
    setState(() {
      _completionInFlight = false;
      _completionReceipt = receipt;
    });

    final dropAt = await pending.dropCompleted;
    if (dropAt == null || !_isPendingCurrent(pending, launch, token)) return;
    if (!_isActiveProfile(launch, token)) {
      _abortPendingWinAsStale(pending);
      return;
    }
    final completedPegs = pending.completedPegs.isEmpty
        ? _completePegIndexes.difference(_presentedCompletedPegs)
        : pending.completedPegs;

    if (receipt.alreadyApplied) {
      _presentCompletedPegsWithoutCelebration(completedPegs);
      setState(() {});
      await _showCompletion(
        receipt,
        launch,
        token,
        celebrate: false,
        moves: outcome.actualMoves,
        parMoves: outcome.parMoves,
      );
      return;
    }

    final celebrationAt = _now < dropAt ? dropAt : _now;
    for (final peg in completedPegs) {
      _startCompletedPeg(peg, at: celebrationAt);
    }
    _paintTimeline.startWin(at: celebrationAt, colorCount: _game.colorCount);
    setState(() => _winCelebrationStarted = true);
    _showConfettiOverlay();

    final modalReady = await _waitForAnimation(
      _reducedMotion ? Duration.zero : RainbowRingsTiming.winModalDelay,
    );
    if (!modalReady || !_isPendingCurrent(pending, launch, token)) return;
    if (!_isActiveProfile(launch, token)) {
      _abortPendingWinAsStale(pending);
      return;
    }
    if (_soundEnabled) unawaited(GameAudio.play('win'));
    await _showCompletion(
      receipt,
      launch,
      token,
      celebrate: true,
      moves: outcome.actualMoves,
      parMoves: outcome.parMoves,
    );
  }

  Future<void> _showCompletion(
    LevelCompletionReceipt receipt,
    GameLaunch launch,
    int token, {
    required bool celebrate,
    required int moves,
    required int parMoves,
  }) async {
    if (!_isCurrent(launch, token)) return;
    final advance = await _showProtectedWinDialog(
      receipt: receipt,
      launch: launch,
      launchToken: token,
      moves: moves,
      parMoves: parMoves,
      celebrate: celebrate,
    );
    if (advance != true || !_isCurrent(launch, token)) return;
    await _startNextLevel(launch, token);
  }

  Future<bool?> _showProtectedWinDialog({
    required LevelCompletionReceipt receipt,
    required GameLaunch launch,
    required int launchToken,
    required int moves,
    required int parMoves,
    required bool celebrate,
  }) async {
    if (!mounted || _dialogOpen || !_isActiveProfile(launch, launchToken)) {
      return null;
    }
    _removeConfettiOverlay();
    setState(() => _dialogOpen = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    final timeline = _paintTimeline;
    final clock = _paintClock;
    final reducedMotion = _reducedMotion;
    final dialogLaunchToken = _launchToken;
    late final RawDialogRoute<bool> route;
    route = RawDialogRoute<bool>(
      barrierDismissible: false,
      barrierLabel: 'Rainbow Rings level complete',
      barrierColor: Colors.black.withValues(alpha: .58),
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, _) {
        if (!mounted ||
            dialogLaunchToken != _launchToken ||
            !_isActiveProfile(launch, launchToken) ||
            !identical(_activeDialogRoute, route)) {
          return const SizedBox.shrink();
        }
        return PopScope(
          canPop: false,
          child: _RainbowWinOverlay(
            timeline: timeline,
            clock: clock,
            receipt: receipt,
            moves: moves,
            parMoves: parMoves,
            celebrate: celebrate,
            reducedMotion: reducedMotion,
            onNext: () => navigator.pop(true),
          ),
        );
      },
    );
    _activeDialogRoute = route;
    _activeDialogNavigator = navigator;
    try {
      return await navigator.push<bool>(route);
    } finally {
      if (identical(_activeDialogRoute, route)) {
        _activeDialogRoute = null;
        _activeDialogNavigator = null;
        if (mounted) setState(() => _dialogOpen = false);
      }
    }
  }

  Future<T?> _showProtectedDialog<T>({
    required Widget Function(BuildContext dialogContext) builder,
  }) async {
    if (!mounted || _dialogOpen) return null;
    setState(() => _dialogOpen = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    final dialogLaunchToken = _launchToken;
    late final DialogRoute<T> route;
    route = DialogRoute<T>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!mounted ||
            dialogLaunchToken != _launchToken ||
            !identical(_activeDialogRoute, route)) {
          return const SizedBox.shrink();
        }
        return PopScope(canPop: false, child: builder(dialogContext));
      },
    );
    _activeDialogRoute = route;
    _activeDialogNavigator = navigator;
    try {
      return await navigator.push<T>(route);
    } finally {
      if (identical(_activeDialogRoute, route)) {
        _activeDialogRoute = null;
        _activeDialogNavigator = null;
        if (mounted) setState(() => _dialogOpen = false);
      }
    }
  }

  Future<GameLaunch> _beginFreshAttempt(GameLaunch launch) {
    final controller = ref.read(gameProfilesProvider.notifier);
    return switch (launch.playKind) {
      GamePlayKind.current => controller.beginCurrentAttempt(
        profileId: launch.profileId,
        gameId: GameId.rainbowRings,
      ),
      GamePlayKind.replay => controller.beginReplayAttempt(
        profileId: launch.profileId,
        gameId: GameId.rainbowRings,
        level: launch.descriptor.level,
      ),
    };
  }

  Future<void> _restartLevel() async {
    if (_controlsLocked || _game.isWon) return;
    final previous = _launch;
    final token = _launchToken;
    if (!_isActiveProfile(previous, token)) {
      _showMessage('This attempt is no longer active.');
      return;
    }
    setState(() {
      _attemptBusy = true;
      _invalidateAnimationCallbacks();
      _paintTimeline.reset(
        seed: _launch.descriptor.seed,
        reducedMotion: _reducedMotion,
      );
      _paintTimeline.rememberRings(_ringPlacements);
      _paintTimeline.setCompletedPegs(_presentedCompletedPegs);
    });
    try {
      final launch = await _beginFreshAttempt(previous);
      if (!_isCurrent(previous, token)) return;
      if (!_isActiveProfile(previous, token)) {
        setState(() => _attemptBusy = false);
        _showMessage('This attempt is no longer active.');
        return;
      }
      final game = _gameFor(launch);
      if (!_isCurrent(previous, token)) return;
      setState(() => _installLaunch(launch, game: game));
    } catch (_) {
      if (!_isCurrent(previous, token)) return;
      setState(() => _attemptBusy = false);
      _showMessage('This level could not be restarted. Try again.');
    }
  }

  Future<void> _startNextLevel(GameLaunch completedLaunch, int token) async {
    if (_attemptBusy || !_isCurrent(completedLaunch, token)) return;
    _ExpectedNextAttempt? expected;
    while (_isCurrent(completedLaunch, token)) {
      if (!_isActiveProfile(completedLaunch, token)) {
        setState(() {
          _attemptBusy = false;
          _completionReceipt = null;
        });
        _showMessage('This attempt is no longer active.');
        return;
      }
      setState(() => _attemptBusy = true);
      try {
        final controller = ref.read(gameProfilesProvider.notifier);
        final visibleProgress = _visibleProgress(completedLaunch);
        if (visibleProgress?.activeAttempt != null) {
          final adopted = expected?.launchFrom(
            profileId: completedLaunch.profileId,
            progress: visibleProgress!,
          );
          if (adopted == null) {
            _rejectNextAsStale(completedLaunch, token);
            return;
          }
          final game = _gameFor(adopted);
          if (!_isCurrent(completedLaunch, token)) return;
          setState(() => _installLaunch(adopted, game: game));
          return;
        }

        final prepared = await controller.prepareGame(
          profileId: completedLaunch.profileId,
          gameId: GameId.rainbowRings,
        );
        if (!_isCurrent(completedLaunch, token)) return;
        if (!_isActiveProfile(completedLaunch, token)) {
          setState(() {
            _attemptBusy = false;
            _completionReceipt = null;
          });
          _showMessage('This attempt is no longer active.');
          return;
        }
        final durableAttempt = prepared.activeAttempt;
        if (durableAttempt != null) {
          final adopted = expected?.launchFrom(
            profileId: completedLaunch.profileId,
            progress: prepared,
          );
          if (adopted == null) {
            _rejectNextAsStale(completedLaunch, token);
            return;
          }
          final game = _gameFor(adopted);
          if (!_isCurrent(completedLaunch, token)) return;
          setState(() => _installLaunch(adopted, game: game));
          return;
        }

        expected ??= _ExpectedNextAttempt.fromProgress(
          profileId: completedLaunch.profileId,
          progress: prepared,
        );
        if (!expected.canBeginFrom(prepared)) {
          _rejectNextAsStale(completedLaunch, token);
          return;
        }
        final launch = await controller.resumeOrBeginCurrentAttempt(
          profileId: completedLaunch.profileId,
          gameId: GameId.rainbowRings,
        );
        if (!_isCurrent(completedLaunch, token)) return;
        if (!_isActiveProfile(completedLaunch, token)) {
          setState(() {
            _attemptBusy = false;
            _completionReceipt = null;
          });
          _showMessage('This attempt is no longer active.');
          return;
        }
        if (!expected.matchesLaunch(launch)) {
          _rejectNextAsStale(completedLaunch, token);
          return;
        }
        final game = _gameFor(launch);
        if (!_isCurrent(completedLaunch, token)) return;
        setState(() => _installLaunch(launch, game: game));
        return;
      } catch (error) {
        if (!_isCurrent(completedLaunch, token)) return;
        setState(() => _attemptBusy = false);
        if (error is GameProgressionException &&
            error.code == GameProgressionError.staleAttempt) {
          setState(() => _completionReceipt = null);
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

  PlayerGameProgress? _visibleProgress(GameLaunch launch) {
    final state = ref.read(gameProfilesProvider).asData?.value;
    return state?.profiles[launch.profileId]?.gameProgress[launch.gameId];
  }

  void _rejectNextAsStale(GameLaunch completedLaunch, int token) {
    if (!_isCurrent(completedLaunch, token)) return;
    setState(() {
      _attemptBusy = false;
      _completionReceipt = null;
    });
    _showMessage('This attempt is no longer active.');
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void _undo() {
    if (_controlsLocked || !_game.canUndo || _game.isWon) return;
    final at = _now;
    RainbowRingsActionResult? selectedDrop;
    int? selectedDropToken;
    final selectedPeg = _game.selectedPeg;
    if (selectedPeg != null) {
      final stack = _game.stacks[selectedPeg];
      selectedDrop = RainbowRingsActionResult(
        kind: RainbowRingsActionKind.deselect,
        ringId: stack.last,
        source: RainbowRingsPosition.hover(selectedPeg),
        destination: RainbowRingsPosition(
          peg: selectedPeg,
          slot: stack.length - 1,
        ),
      );
      selectedDropToken = _startTimelineAction(selectedDrop, at: at);
    }

    final action = _game.undo();
    if (action.kind != RainbowRingsActionKind.undo) return;
    _reconcileCompletedPegs();
    final actionToken = _startTimelineAction(action, at: at);
    _playActionFeedback(action.kind);
    _syncCompletedProgress(at);
    final undoDuration =
        RainbowRingsTiming.undoLift +
        RainbowRingsTiming.transfer +
        RainbowRingsTiming.drop;
    if (_reducedMotion) {
      if (selectedDrop != null && selectedDropToken != null) {
        _startLandingIfCurrent(
          selectedDrop,
          at: at + RainbowRingsTiming.deselectDrop,
          actionToken: selectedDropToken,
        );
      }
      _startLandingIfCurrent(
        action,
        at: at + undoDuration,
        actionToken: actionToken,
      );
      setState(() {});
      return;
    }

    _animationLocked = true;
    final generation = _animationGeneration;
    final lockToken = ++_lockedActionToken;
    if (selectedDrop != null && selectedDropToken != null) {
      final drop = selectedDrop;
      final dropToken = selectedDropToken;
      _scheduleAnimation(
        RainbowRingsTiming.deselectDrop,
        generation: generation,
        callback: () => _startLandingIfCurrent(
          drop,
          at: at + RainbowRingsTiming.deselectDrop,
          actionToken: dropToken,
        ),
      );
    }
    _scheduleAnimation(
      undoDuration,
      generation: generation,
      callback: () {
        if (lockToken != _lockedActionToken) return;
        _startLandingIfCurrent(
          action,
          at: at + undoDuration,
          actionToken: actionToken,
        );
        setState(() => _animationLocked = false);
      },
    );
    setState(() {});
  }

  void _startHintOrInvalid(
    RainbowRingsMove? hint, {
    required Duration at,
    required int fallbackPeg,
  }) {
    if (hint != null) {
      _setLiveAnnouncement(
        'Hint: move from peg ${hint.sourcePeg + 1} '
        'to peg ${hint.destinationPeg + 1}.',
      );
      _paintTimeline.startHint(
        at: at,
        sourcePeg: hint.sourcePeg,
        destinationPeg: hint.destinationPeg,
      );
      return;
    }
    final invalid = RainbowRingsActionResult(
      kind: RainbowRingsActionKind.invalid,
      destination: RainbowRingsPosition(peg: fallbackPeg, slot: 0),
    );
    _startTimelineAction(invalid, at: at);
    _playActionFeedback(invalid.kind);
  }

  void _setLiveAnnouncement(String message) {
    _liveAnnouncement = message;
    _liveAnnouncementRevision++;
  }

  void _hint() {
    if (_controlsLocked || _game.isWon) return;
    final at = _now;
    final hint = _game.suggestMove();
    final selectedPeg = _game.selectedPeg;
    if (selectedPeg == null) {
      _startHintOrInvalid(hint, at: at, fallbackPeg: 0);
      setState(() {});
      return;
    }

    final drop = _game.tapPeg(selectedPeg);
    final dropToken = _startTimelineAction(drop, at: at);
    final hintAt = at + RainbowRingsTiming.deselectDrop;
    if (_reducedMotion) {
      _startLandingIfCurrent(drop, at: hintAt, actionToken: dropToken);
      _startHintOrInvalid(hint, at: hintAt, fallbackPeg: selectedPeg);
      setState(() {});
      return;
    }

    _animationLocked = true;
    final generation = _animationGeneration;
    final lockToken = ++_lockedActionToken;
    final pendingHint = _PendingRainbowHint(
      hint: hint,
      fallbackPeg: selectedPeg,
    );
    _pendingHint = pendingHint;
    _scheduleAnimation(
      RainbowRingsTiming.deselectDrop,
      generation: generation,
      callback: () {
        if (lockToken != _lockedActionToken ||
            !identical(_pendingHint, pendingHint)) {
          return;
        }
        _pendingHint = null;
        _startLandingIfCurrent(drop, at: hintAt, actionToken: dropToken);
        _startHintOrInvalid(hint, at: hintAt, fallbackPeg: selectedPeg);
        setState(() => _animationLocked = false);
      },
    );
    setState(() {});
  }

  String _pegSemanticsLabel(int peg) {
    final stack = _game.stacks[peg];
    final parts = <String>['Peg ${peg + 1}'];
    if (stack.isEmpty) {
      parts.add('empty');
    } else {
      parts.add(stack.length == 1 ? '1 ring' : '${stack.length} rings');
      final colorIndex = _game.ringColors[stack.last];
      final colorName = colorIndex >= 0 && colorIndex < _ringColorNames.length
          ? _ringColorNames[colorIndex]
          : 'Color ${colorIndex + 1}';
      parts.add('top $colorName');
    }
    if (_game.selectedPeg == peg) parts.add('selected');
    if (_game.isPegComplete(peg)) parts.add('completed');
    return '${parts.join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mediaQuery = MediaQuery.of(context);
    final viewport = mediaQuery.size;
    final textScale = mediaQuery.textScaler.scale(1);
    final compact =
        viewport.height < 420 || viewport.width < 400 || textScale > 1.3;
    return Scaffold(
      appBar: GamePlayAppBar(
        title: 'Rainbow Rings',
        subtitle:
            'Level ${_launch.descriptor.level} · ${_launch.descriptor.tier.label}',
        onBack: () => Navigator.of(context).maybePop(),
        onOpenMap: widget.onOpenMap,
        soundEnabled: _soundEnabled,
        onToggleSound: () => setState(() => _soundEnabled = !_soundEnabled),
        onRestart: _controlsLocked || _game.isWon
            ? null
            : () => unawaited(_restartLevel()),
        locked: _navigationLocked,
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        buttonColor: colors.surfaceElevated,
        accentColor: colors.primary,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    compact ? AppSpacing.xs : AppSpacing.sm,
                    AppSpacing.lg,
                    compact ? AppSpacing.xs : AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: compact ? AppSpacing.xs : AppSpacing.sm,
                        children: [
                          _ScorePill(
                            label: 'LEVEL',
                            value: '${_launch.descriptor.level}',
                          ),
                          _ScorePill(
                            label: 'TIER',
                            value: _launch.descriptor.tier.label,
                          ),
                          _ScorePill(
                            key: const ValueKey('rainbow-rings-moves'),
                            label: 'MOVES',
                            value: '${_game.moves}',
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
                      _CompletionProgress(
                        clock: _paintClock,
                        from: _progressFrom,
                        target: _progressTarget,
                        startedAt: _progressStartedAt,
                        colorCount: _game.colorCount,
                        reducedMotion: _reducedMotion,
                        showLabel: !compact,
                      ),
                      if (!compact) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Move each ring onto an empty peg or a matching color.\nFill each peg with one color.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ] else
                        const SizedBox(height: AppSpacing.xs),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final boardSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            if (boardSize.width <= 0 || boardSize.height <= 0) {
                              return const SizedBox.shrink();
                            }
                            final geometry = RainbowRingsGeometry.layout(
                              boardSize,
                              pegCount: _game.stacks.length,
                              capacity: _game.capacity,
                            );
                            return Semantics(
                              label:
                                  'Rainbow Rings level ${_game.level} board. ${_game.stacks.length} pegs.',
                              child: GestureDetector(
                                key: const ValueKey('rainbow-rings-board'),
                                behavior: HitTestBehavior.opaque,
                                excludeFromSemantics: true,
                                onTapUp: _controlsLocked || _game.isWon
                                    ? null
                                    : (event) => _tapPeg(
                                        event.localPosition,
                                        boardSize,
                                      ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    RepaintBoundary(
                                      key: const ValueKey(
                                        'rainbow-rings-repaint-boundary',
                                      ),
                                      child: CustomPaint(
                                        size: boardSize,
                                        painter: RainbowRingsPainter(
                                          stacks: _game.stacks,
                                          ringColors: _game.ringColors,
                                          capacity: _game.capacity,
                                          selectedPeg: _game.selectedPeg,
                                          colors: colors,
                                          timeline: _paintTimeline,
                                          clock: _paintClock,
                                        ),
                                      ),
                                    ),
                                    for (
                                      var peg = 0;
                                      peg < _game.stacks.length;
                                      peg++
                                    )
                                      Positioned.fromRect(
                                        rect: geometry.pegHitRect(peg),
                                        child: _RainbowPegControl(
                                          key: ValueKey(
                                            'rainbow-rings-peg-$peg',
                                          ),
                                          label: _pegSemanticsLabel(peg),
                                          selected: _game.selectedPeg == peg,
                                          focusIndicatorKey: ValueKey(
                                            'rainbow-rings-peg-focus-$peg',
                                          ),
                                          onPressed:
                                              !_controlsLocked &&
                                                  !_game.isWon &&
                                                  !_game.isPegComplete(peg)
                                              ? () => _activatePeg(peg)
                                              : null,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
                      LayoutBuilder(
                        builder: (context, controlConstraints) {
                          final spacing = compact
                              ? AppSpacing.xs
                              : AppSpacing.sm;
                          final columns =
                              textScale > 1.5 &&
                                  controlConstraints.maxWidth < 400
                              ? 1
                              : controlConstraints.maxWidth < 360
                              ? 2
                              : 3;
                          final width =
                              (controlConstraints.maxWidth -
                                  spacing * (columns - 1)) /
                              columns;
                          return Wrap(
                            alignment: WrapAlignment.center,
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              SizedBox(
                                width: width,
                                child: OutlinedButton.icon(
                                  key: const ValueKey('rainbow-rings-undo'),
                                  onPressed:
                                      !_controlsLocked &&
                                          _game.canUndo &&
                                          !_game.isWon
                                      ? _undo
                                      : null,
                                  icon: const Icon(Icons.undo_rounded),
                                  label: const Text('Undo'),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: OutlinedButton.icon(
                                  key: const ValueKey('rainbow-rings-hint'),
                                  onPressed: _controlsLocked || _game.isWon
                                      ? null
                                      : _hint,
                                  icon: const Icon(
                                    Icons.lightbulb_outline_rounded,
                                  ),
                                  label: const Text('Hint'),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: FilledButton.icon(
                                  key: const ValueKey('rainbow-rings-restart'),
                                  onPressed: _controlsLocked || _game.isWon
                                      ? null
                                      : () => unawaited(_restartLevel()),
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text('Restart'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_liveAnnouncement case final announcement?)
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: Semantics(
                  key: ValueKey(
                    'rainbow-rings-live-announcement-'
                    '$_liveAnnouncementRevision',
                  ),
                  container: true,
                  liveRegion: true,
                  label: announcement,
                  child: const SizedBox.expand(
                    key: ValueKey('rainbow-rings-live-announcement'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _ScheduledRainbowCallback {
  const _ScheduledRainbowCallback({
    required this.at,
    required this.generation,
    required this.sequence,
    required this.callback,
  });

  final Duration at;
  final int generation;
  final int sequence;
  final VoidCallback callback;
}

final class _PendingRainbowHint {
  const _PendingRainbowHint({required this.hint, required this.fallbackPeg});

  final RainbowRingsMove? hint;
  final int fallbackPeg;
}

final class _ExpectedNextAttempt {
  const _ExpectedNextAttempt({
    required this.attemptId,
    required this.sequence,
    required this.level,
    required this.descriptorFingerprint,
  });

  factory _ExpectedNextAttempt.fromProgress({
    required String profileId,
    required PlayerGameProgress progress,
  }) {
    final level = progress.currentLevel;
    final descriptor = progress.descriptors[level];
    if (descriptor == null) {
      throw GameProgressionException(
        GameProgressionError.gameNotPrepared,
        'Level $level has not been generated',
      );
    }
    final sequence = progress.attemptSequence + 1;
    return _ExpectedNextAttempt(
      attemptId: '$profileId:${progress.gameId.storageId}:$sequence',
      sequence: sequence,
      level: level,
      descriptorFingerprint: descriptor.fingerprint,
    );
  }

  final String attemptId;
  final int sequence;
  final int level;
  final String descriptorFingerprint;

  bool canBeginFrom(PlayerGameProgress progress) =>
      progress.activeAttempt == null &&
      progress.currentLevel == level &&
      progress.attemptSequence == sequence - 1 &&
      progress.descriptors[level]?.fingerprint == descriptorFingerprint;

  bool matchesLaunch(GameLaunch launch) =>
      launch.attemptId == attemptId &&
      launch.descriptor.level == level &&
      launch.descriptor.fingerprint == descriptorFingerprint &&
      launch.playKind == GamePlayKind.current;

  GameLaunch? launchFrom({
    required String profileId,
    required PlayerGameProgress progress,
  }) {
    final attempt = progress.activeAttempt;
    final descriptor = progress.descriptors[level];
    if (attempt == null ||
        descriptor == null ||
        progress.currentLevel != level ||
        progress.attemptSequence != sequence ||
        attempt.attemptId != attemptId ||
        attempt.sequence != sequence ||
        attempt.level != level ||
        attempt.playKind != GamePlayKind.current ||
        attempt.descriptorFingerprint != descriptorFingerprint ||
        descriptor.fingerprint != descriptorFingerprint) {
      return null;
    }
    return GameLaunch(
      profileId: profileId,
      gameId: progress.gameId,
      descriptor: descriptor,
      attemptId: attemptId,
      playKind: GamePlayKind.current,
    );
  }
}

final class _PendingRainbowWin {
  _PendingRainbowWin({
    required this.launchToken,
    required Iterable<int> completedPegs,
  }) : completedPegs = Set<int>.unmodifiable(completedPegs);

  final int launchToken;
  final Set<int> completedPegs;
  final Completer<Duration?> _dropCompleted = Completer<Duration?>();
  bool isCanceled = false;

  Future<Duration?> get dropCompleted => _dropCompleted.future;

  void completeDrop(Duration at) {
    if (!_dropCompleted.isCompleted) _dropCompleted.complete(at);
  }

  void cancel() {
    isCanceled = true;
    if (!_dropCompleted.isCompleted) _dropCompleted.complete(null);
  }
}

class _RainbowWinOverlay extends StatelessWidget {
  const _RainbowWinOverlay({
    required this.timeline,
    required this.clock,
    required this.receipt,
    required this.moves,
    required this.parMoves,
    required this.celebrate,
    required this.reducedMotion,
    required this.onNext,
  });

  final RainbowRingsTimeline timeline;
  final ValueListenable<Duration> clock;
  final LevelCompletionReceipt receipt;
  final int moves;
  final int parMoves;
  final bool celebrate;
  final bool reducedMotion;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: clock,
    builder: (context, _, _) {
      final reduceEffects =
          reducedMotion || MediaQuery.disableAnimationsOf(context);
      final frame = timeline.sample(clock.value);
      final opacity = celebrate ? frame.modalOpacity : 1.0;
      final scale = celebrate ? frame.modalScale : 1.0;
      final stars = celebrate ? frame.starProgress : const <double>[1, 1, 1];
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: IgnorePointer(
                      key: const ValueKey(
                        'rainbow-rings-win-modal-interaction',
                      ),
                      ignoring: celebrate && opacity < 1,
                      child: Opacity(
                        key: const ValueKey('rainbow-rings-win-modal'),
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale,
                          child: _RainbowWinCard(
                            receipt: receipt,
                            moves: moves,
                            parMoves: parMoves,
                            starProgress: stars,
                            onNext: celebrate && opacity < 1 ? null : onNext,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (celebrate && !reduceEffects)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('rainbow-rings-confetti'),
                    painter: RainbowRingsConfettiPainter(
                      timeline: timeline,
                      clock: clock,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: Semantics(
                  key: const ValueKey('rainbow-rings-completion-announcement'),
                  container: true,
                  liveRegion: true,
                  label: receipt.alreadyApplied
                      ? 'Level already saved. $moves moves. Par $parMoves.'
                      : 'Level complete. $moves moves. Par $parMoves. '
                            '${receipt.coinsAwarded} coins earned.',
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _RainbowPegControl extends StatefulWidget {
  const _RainbowPegControl({
    super.key,
    required this.label,
    required this.selected,
    required this.focusIndicatorKey,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Key focusIndicatorKey;
  final VoidCallback? onPressed;

  @override
  State<_RainbowPegControl> createState() => _RainbowPegControlState();
}

class _RainbowPegControlState extends State<_RainbowPegControl> {
  late final FocusNode _focusNode = FocusNode(debugLabel: widget.label);
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (mounted && _focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: widget.onPressed != null,
      selected: widget.selected,
      label: widget.label,
      onTap: widget.onPressed,
      child: Container(
        key: widget.focusIndicatorKey,
        decoration: BoxDecoration(
          color: _focused ? primary.withValues(alpha: .12) : Colors.transparent,
          border: Border.all(
            color: _focused ? primary : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: TextButton(
          focusNode: _focusNode,
          onPressed: widget.onPressed,
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize: WidgetStatePropertyAll(Size.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            foregroundColor: WidgetStatePropertyAll(Colors.transparent),
            overlayColor: WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RainbowWinCard extends StatelessWidget {
  const _RainbowWinCard({
    required this.receipt,
    required this.moves,
    required this.parMoves,
    required this.starProgress,
    required this.onNext,
  });

  final LevelCompletionReceipt receipt;
  final int moves;
  final int parMoves;
  final List<double> starProgress;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final rating = rainbowRingsStarRating(moves: moves, parMoves: parMoves);
    final details = <Widget>[
      Text(
        '$moves moves • Par $parMoves',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (receipt.alreadyApplied)
        const Text(
          'This solved attempt is already on your profile.',
          textAlign: TextAlign.center,
        ),
      if (!receipt.alreadyApplied && receipt.coinsAwarded > 0)
        Text('+${receipt.coinsAwarded} coins', textAlign: TextAlign.center),
      if (!receipt.alreadyApplied && receipt.badgeId != null)
        const Text('Badge earned', textAlign: TextAlign.center),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.celebration_rounded, size: 42),
        title: Text(
          receipt.alreadyApplied ? 'Level already saved' : 'Level complete!',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: '$rating of 3 stars',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(3, (index) {
                    final progress = starProgress[index].clamp(0.0, 1.0);
                    return Transform.rotate(
                      angle: (1 - progress) * -math.pi / 2,
                      child: Transform.scale(
                        scale: progress,
                        child: Opacity(
                          opacity: progress,
                          child: Icon(
                            index < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: index < rating
                                ? const Color(0xffffc928)
                                : Theme.of(context).colorScheme.outline,
                            size: 42,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...details.expand(
              (detail) => <Widget>[
                detail,
                const SizedBox(height: AppSpacing.xs),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Next Level'),
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label  ', style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _CompletionProgress extends StatelessWidget {
  const _CompletionProgress({
    required this.clock,
    required this.from,
    required this.target,
    required this.startedAt,
    required this.colorCount,
    required this.reducedMotion,
    required this.showLabel,
  });

  final ValueListenable<Duration> clock;
  final double from;
  final double target;
  final Duration startedAt;
  final int colorCount;
  final bool reducedMotion;
  final bool showLabel;

  double _valueAt(Duration now) {
    if (reducedMotion || from == target) return target;
    final elapsed = now - startedAt;
    if (elapsed <= Duration.zero) return from;
    if (elapsed >= RainbowRingsTiming.progress) return target;
    final raw =
        elapsed.inMicroseconds / RainbowRingsTiming.progress.inMicroseconds;
    final eased = const Cubic(.34, 1.4, .6, 1).transform(raw).clamp(0.0, 1.0);
    return from + (target - from) * eased;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: clock,
    builder: (context, now, _) {
      final value = _valueAt(now);
      final bar = LinearProgressIndicator(
        key: const ValueKey('rainbow-rings-completion-progress'),
        minHeight: 7,
        value: value,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      );
      if (!showLabel) return bar;
      final completed = (target * colorCount).round();
      return Row(
        children: [
          Text(
            'SORTED $completed/$colorCount',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: bar),
        ],
      );
    },
  );
}
