import 'dart:math' as math;

import '../domain/rainbow_rings_game.dart';

/// Frozen timings shared by the Rainbow Rings screen, painter, and tests.
abstract final class RainbowRingsTiming {
  static const breathe = Duration(milliseconds: 3600);
  static const progress = Duration(milliseconds: 600);
  static const introStagger = Duration(milliseconds: 55);
  static const introFall = Duration(milliseconds: 500);
  static const introUnlockPadding = Duration(milliseconds: 700);
  static const selectLift = Duration(milliseconds: 240);
  static const liftPop = Duration(milliseconds: 400);
  static const jelly = Duration(milliseconds: 1100);
  static const deselectDrop = Duration(milliseconds: 300);
  static const transfer = Duration(milliseconds: 260);
  static const drop = Duration(milliseconds: 340);
  static const undoLift = Duration(milliseconds: 200);
  static const invalidShake = Duration(milliseconds: 300);
  static const settle = Duration(milliseconds: 1150);
  static const lowerPress = Duration(milliseconds: 700);
  static const lowerPressStagger = Duration(milliseconds: 70);
  static const poleJiggle = Duration(milliseconds: 550);
  static const hintPulses = Duration(milliseconds: 1500);
  static const hintClear = Duration(milliseconds: 1600);
  static const completedJump = Duration(milliseconds: 550);
  static const completedJumpStagger = Duration(milliseconds: 50);
  static const sparkle = Duration(milliseconds: 900);
  static const toast = Duration(milliseconds: 1000);
  static const winModalDelay = Duration(milliseconds: 800);
  static const modal = Duration(milliseconds: 550);
  static const star = Duration(milliseconds: 600);
  static const starOneDelay = Duration(milliseconds: 300);
  static const starTwoDelay = Duration(milliseconds: 550);
  static const starThreeDelay = Duration(milliseconds: 800);
}

enum RainbowRingsTravelKind { select, deselect, move, undo }

enum RainbowRingsRingEffectKind {
  intro,
  select,
  deselect,
  move,
  undo,
  landing,
  lowerPress,
  completedJump,
  breathe,
}

enum RainbowRingsPegEffectKind { invalidShake, jiggle, hint, completed }

enum RainbowParticleKind { bokeh, sparkle, confetti }

final class RainbowRingsRingPlacement {
  const RainbowRingsRingPlacement({
    required this.ringId,
    required this.position,
  });

  final int ringId;
  final RainbowRingsPosition position;

  @override
  bool operator ==(Object other) =>
      other is RainbowRingsRingPlacement &&
      other.ringId == ringId &&
      other.position == position;

  @override
  int get hashCode => Object.hash(ringId, position);
}

/// Immutable sampled pose in logical peg/slot coordinates. Pixel geometry is
/// deliberately deferred to the painter so a resize during travel is safe.
final class RainbowRingTransform {
  const RainbowRingTransform({
    required this.ringId,
    required this.token,
    required this.kind,
    required this.peg,
    required this.slot,
    required this.restingSlot,
    required this.hoverFraction,
    this.offsetX = 0,
    this.offsetY = 0,
    this.offsetYInRings = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.opacity = 1,
    this.overlay = false,
    this.hideRestingRing = false,
  });

  final int ringId;
  final int token;
  final RainbowRingsRingEffectKind kind;
  final double peg;

  /// The non-sentinel stack slot used as the lower geometry anchor.
  final double restingSlot;

  /// Interpolation/extrapolation from [restingSlot] to the hover anchor.
  final double hoverFraction;

  /// Legacy endpoint slot. Painters must use [restingSlot]/[hoverFraction]
  /// rather than interpolating the domain's `hoverSlot == -1` sentinel.
  final double slot;
  final double offsetX;
  final double offsetY;
  final double offsetYInRings;
  final double scaleX;
  final double scaleY;
  final double rotation;
  final double opacity;
  final bool overlay;
  final bool hideRestingRing;
}

final class RainbowPegTransform {
  const RainbowPegTransform({
    required this.peg,
    required this.token,
    required this.kinds,
    this.offsetX = 0,
    this.rotation = 0,
    this.glow = 0,
    this.completed = false,
  });

  final int peg;
  final int token;
  final Set<RainbowRingsPegEffectKind> kinds;
  final double offsetX;
  final double rotation;
  final double glow;
  final bool completed;
}

/// A deterministic particle with frozen timing and sampled visual state.
final class RainbowParticle {
  const RainbowParticle({
    required this.id,
    required this.kind,
    required this.colorIndex,
    required this.delay,
    required this.duration,
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.scale,
    required this.rotation,
    this.peg,
  });

  final int id;
  final RainbowParticleKind kind;
  final int colorIndex;
  final Duration delay;
  final Duration duration;

  /// Normalized for bokeh/confetti; peg-local logical pixels for sparkles.
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double scale;
  final double rotation;
  final int? peg;

  @override
  bool operator ==(Object other) =>
      other is RainbowParticle &&
      other.id == id &&
      other.kind == kind &&
      other.colorIndex == colorIndex &&
      other.delay == delay &&
      other.duration == duration &&
      other.x == x &&
      other.y == y &&
      other.size == size &&
      other.opacity == opacity &&
      other.scale == scale &&
      other.rotation == rotation &&
      other.peg == peg;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    colorIndex,
    delay,
    duration,
    x,
    y,
    size,
    opacity,
    scale,
    rotation,
    peg,
  );
}

final class RainbowRingsFrame {
  RainbowRingsFrame({
    required this.revision,
    required Map<int, RainbowRingTransform> ringTransforms,
    required Map<int, RainbowPegTransform> pegEffects,
    required List<RainbowParticle> bokeh,
    required List<RainbowParticle> sparkles,
    required List<RainbowParticle> confetti,
    required Set<int> completedPegs,
    required this.inputLocked,
    required this.toast,
    required this.toastPeg,
    required this.toastOpacity,
    required this.toastOffsetY,
    required this.toastScale,
    required this.modalOpacity,
    required this.modalScale,
    required List<double> starProgress,
  }) : ringTransforms = Map.unmodifiable(ringTransforms),
       pegEffects = Map.unmodifiable(pegEffects),
       bokeh = List.unmodifiable(bokeh),
       sparkles = List.unmodifiable(sparkles),
       confetti = List.unmodifiable(confetti),
       completedPegs = Set.unmodifiable(completedPegs),
       starProgress = List.unmodifiable(starProgress);

  final int revision;
  final Map<int, RainbowRingTransform> ringTransforms;
  final Map<int, RainbowPegTransform> pegEffects;
  final List<RainbowParticle> bokeh;
  final List<RainbowParticle> sparkles;
  final List<RainbowParticle> confetti;
  final Set<int> completedPegs;
  final bool inputLocked;
  final String? toast;
  final int? toastPeg;
  final double toastOpacity;
  final double toastOffsetY;
  final double toastScale;
  final double modalOpacity;
  final double modalScale;
  final List<double> starProgress;
}

final class RainbowRingsTimeline {
  RainbowRingsTimeline({required int seed, bool reducedMotion = false})
    : _seed = seed,
      _reducedMotion = reducedMotion {
    _createBokeh();
  }

  int _seed;
  bool _reducedMotion;
  int _generation = 1;
  int _revision = 1;
  int _nextToken = 1;
  int _randomDraws = 0;
  _IntroEffect? _intro;
  final Map<int, _ActionEffect> _actions = {};
  final Map<int, _LandingEffect> _landings = {};
  final Map<int, _PressEffect> _presses = {};
  final Map<int, _ShakeEffect> _shakes = {};
  final Map<int, _JiggleEffect> _jiggles = {};
  _HintEffect? _hint;
  final Map<int, _CompletedEffect> _completedEffects = {};
  final Map<int, int> _completedPegTokens = {};
  final Map<int, RainbowRingsRingPlacement> _knownRings = {};
  final List<_ParticleTemplate> _bokeh = [];
  _WinEffect? _win;
  bool _winFinal = false;

  bool get reducedMotion => _reducedMotion;

  set reducedMotion(bool value) {
    if (value == _reducedMotion) return;
    final preserveFinishedWin = _winFinal || _win != null;
    _reducedMotion = value;
    _generation++;
    _revision++;
    _nextToken = 1;
    _clearTransientEffects();
    _winFinal = preserveFinishedWin;
  }

  int get generation => _generation;
  int get revision => _revision;
  int get debugRandomDraws => _randomDraws;

  int get debugEffectCount =>
      (_intro == null ? 0 : 1) +
      _actions.length +
      _landings.length +
      _presses.length +
      _shakes.length +
      _jiggles.length +
      (_hint == null ? 0 : 1) +
      _completedEffects.length +
      (_win == null ? 0 : 1);

  bool isTokenCurrent(int token) => token ~/ 1000000 == _generation;

  int breathingPhaseMilliseconds(int ringId) =>
      _positiveHash(_seed, ringId, 0x5b11) %
      RainbowRingsTiming.breathe.inMilliseconds;

  void rememberRings(Iterable<RainbowRingsRingPlacement> rings) {
    for (final ring in rings) {
      _knownRings[ring.ringId] = ring;
    }
    _revision++;
  }

  int startIntro({
    required Duration at,
    required Iterable<RainbowRingsRingPlacement> rings,
  }) {
    final ordered = rings.toList()
      ..sort((left, right) {
        final slot = left.position.slot.compareTo(right.position.slot);
        return slot != 0
            ? slot
            : left.position.peg.compareTo(right.position.peg);
      });
    rememberRings(ordered);
    final token = _token();
    _cleanup(at);
    _intro = reducedMotion || ordered.isEmpty
        ? null
        : _IntroEffect(token: token, start: at, rings: ordered);
    _revision++;
    return token;
  }

  int startAction({
    required Duration at,
    required RainbowRingsActionResult action,
  }) {
    final token = _token();
    _cleanup(at);
    final ringId = action.ringId;
    final source = action.source;
    final destination = action.destination;
    if (action.kind == RainbowRingsActionKind.invalid) {
      final peg = destination?.peg ?? source?.peg;
      if (peg != null && !reducedMotion) {
        _shakes[peg] = _ShakeEffect(token: token, start: at, peg: peg);
      }
      _revision++;
      return token;
    }
    if (reducedMotion ||
        ringId == null ||
        source == null ||
        destination == null) {
      if (ringId != null) _actions.remove(ringId);
      _revision++;
      return token;
    }
    final kind = switch (action.kind) {
      RainbowRingsActionKind.select => RainbowRingsTravelKind.select,
      RainbowRingsActionKind.deselect => RainbowRingsTravelKind.deselect,
      RainbowRingsActionKind.move => RainbowRingsTravelKind.move,
      RainbowRingsActionKind.undo => RainbowRingsTravelKind.undo,
      RainbowRingsActionKind.invalid || RainbowRingsActionKind.ignored => null,
    };
    if (kind == null) return token;
    final prior = _sampleAction(_actions[ringId], at);
    _actions[ringId] = _ActionEffect(
      token: token,
      start: at,
      ringId: ringId,
      kind: kind,
      source: source,
      destination: destination,
      sampledStart: prior,
    );
    _revision++;
    return token;
  }

  int startLanding({
    required Duration at,
    required RainbowRingsRingPlacement ring,
    required Iterable<int> lowerRingIds,
  }) {
    final token = _token();
    _cleanup(at);
    _knownRings[ring.ringId] = ring;
    if (!reducedMotion) {
      _landings[ring.ringId] = _LandingEffect(
        token: token,
        start: at,
        ring: ring,
      );
      final lower = lowerRingIds.toList();
      for (var index = 0; index < lower.length; index++) {
        final ringId = lower[lower.length - 1 - index];
        _presses[ringId] = _PressEffect(
          token: token,
          start: at + RainbowRingsTiming.lowerPressStagger * index,
          ringId: ringId,
          peg: ring.position.peg,
          slot: math.max(0, ring.position.slot - index - 1),
        );
      }
      _jiggles[ring.position.peg] = _JiggleEffect(
        token: token,
        start: at,
        peg: ring.position.peg,
      );
    }
    _revision++;
    return token;
  }

  int startCompletedPeg({
    required Duration at,
    required int peg,
    required Iterable<RainbowRingsRingPlacement> rings,
  }) {
    final token = _token();
    _cleanup(at);
    final ordered = rings.toList()
      ..sort((a, b) => a.position.slot.compareTo(b.position.slot));
    for (final ring in ordered) {
      _knownRings[ring.ringId] = ring;
      _actions.remove(ring.ringId);
      _landings.remove(ring.ringId);
      _presses.remove(ring.ringId);
    }
    _shakes.remove(peg);
    _jiggles.remove(peg);
    _completedPegTokens[peg] = token;
    if (reducedMotion) {
      _completedEffects.remove(peg);
      _revision++;
      return token;
    }
    final praise = completedPegPraise(peg);
    final particles = reducedMotion
        ? const <_ParticleTemplate>[]
        : List<_ParticleTemplate>.generate(12, (index) {
            final base = 0x530000 + peg * 97 + index * 7;
            final angle = _draw(base) * math.pi * 2;
            final distance = 24 + _draw(base + 1) * 38;
            return _ParticleTemplate(
              id: index,
              kind: RainbowParticleKind.sparkle,
              colorIndex: index % 6,
              delay: Duration.zero,
              duration: RainbowRingsTiming.sparkle,
              x: math.cos(angle) * distance,
              y: math.sin(angle) * distance - 10,
              size: 5 + _draw(base + 2) * 5,
              rotation: 0,
              peg: peg,
            );
          });
    _completedEffects[peg] = _CompletedEffect(
      token: token,
      start: at,
      peg: peg,
      rings: ordered,
      praise: praise,
      particles: particles,
    );
    _revision++;
    return token;
  }

  /// Returns the deterministic praise used for a completed peg's toast.
  ///
  /// Reduced motion omits the visual toast, but callers can still announce
  /// the same message to assistive technology.
  String completedPegPraise(int peg) => const [
    'Sorted!',
    'Nice!',
    'Great!',
    'Wow!',
  ][_positiveHash(_seed, peg, 0x70726169) % 4];

  /// Reconciles persistent presentation markers without replaying completion.
  ///
  /// The screen uses this to seed already-complete boards and to remove a
  /// marker when Undo makes a peg incomplete. Newly completed pegs should use
  /// [startCompletedPeg] so their jump, sparkle, and toast still run.
  void setCompletedPegs(Iterable<int> pegs) {
    final next = pegs.toSet();
    var changed = false;
    for (final peg in _completedPegTokens.keys.toList(growable: false)) {
      if (next.contains(peg)) continue;
      _completedPegTokens.remove(peg);
      _completedEffects.remove(peg);
      changed = true;
    }
    for (final peg in next) {
      if (_completedPegTokens.containsKey(peg)) continue;
      _completedPegTokens[peg] = _token();
      changed = true;
    }
    if (changed) _revision++;
  }

  int startHint({
    required Duration at,
    required int sourcePeg,
    required int destinationPeg,
  }) {
    final token = _token();
    _cleanup(at);
    _hint = reducedMotion
        ? null
        : _HintEffect(
            token: token,
            start: at,
            sourcePeg: sourcePeg,
            destinationPeg: destinationPeg,
          );
    _revision++;
    return token;
  }

  int startWin({required Duration at, required int colorCount}) {
    final token = _token();
    _cleanup(at);
    if (reducedMotion) {
      _win = null;
      _winFinal = true;
      _revision++;
      return token;
    }
    _winFinal = false;
    final particles = List<_ParticleTemplate>.generate(80, (index) {
      final base = 0x770000 + index * 11;
      return _ParticleTemplate(
        id: index,
        kind: RainbowParticleKind.confetti,
        colorIndex: index % math.max(1, colorCount),
        delay: Duration(milliseconds: (_draw(base) * 501).floor()),
        duration: Duration(
          milliseconds: 1600 + (_draw(base + 1) * 1801).floor(),
        ),
        x: _draw(base + 2),
        y: -0.08 - _draw(base + 3) * .15,
        size: 5 + _draw(base + 4) * 7,
        rotation: _draw(base + 5) * math.pi * 2,
      );
    });
    _win = _WinEffect(token: token, start: at, particles: particles);
    _revision++;
    return token;
  }

  bool inputLockedAt(Duration now) {
    if (reducedMotion) return false;
    final intro = _intro;
    if (intro != null && now >= intro.start && now < intro.lockEnd) return true;
    for (final action in _actions.values) {
      final end = action.lockEnd;
      if (end != null && now >= action.start && now < end) return true;
    }
    return false;
  }

  RainbowRingsFrame sample(Duration now) {
    final rings = <int, RainbowRingTransform>{};
    if (!reducedMotion) {
      for (final placement in _knownRings.values) {
        rings[placement.ringId] = _sampleBreathe(placement, now);
      }
      final intro = _intro;
      if (intro != null) {
        for (var index = 0; index < intro.rings.length; index++) {
          final transform = _sampleIntro(intro, index, now);
          if (transform != null) rings[transform.ringId] = transform;
        }
      }
      for (final effect in _completedEffects.values) {
        _sampleCompletedRings(effect, now, rings);
      }
      for (final effect in _presses.values) {
        final transform = _samplePress(effect, now);
        if (transform != null) rings[effect.ringId] = transform;
      }
      for (final effect in _landings.values) {
        final transform = _sampleLanding(effect, now);
        if (transform != null) rings[effect.ring.ringId] = transform;
      }
      for (final effect in _actions.values) {
        final transform = _sampleAction(effect, now);
        if (transform != null) rings[effect.ringId] = transform;
      }
    }

    final pegBuilders = <int, _PegBuilder>{};
    for (final entry in _completedPegTokens.entries) {
      pegBuilders.putIfAbsent(entry.key, () => _PegBuilder(entry.key))
        ..token = entry.value
        ..completed = true
        ..glow = 1
        ..kinds.add(RainbowRingsPegEffectKind.completed);
    }
    if (!reducedMotion) {
      _sampleTransientPegEffects(now, pegBuilders);
    }

    final sparkles = <RainbowParticle>[];
    String? toast;
    int? toastPeg;
    var toastOpacity = 0.0;
    var toastOffsetY = 0.0;
    var toastScale = 1.0;
    final latestToastToken = _latestToastToken(now);
    for (final effect in _completedEffects.values) {
      if (!reducedMotion) {
        sparkles.addAll(_sampleParticles(effect.particles, now - effect.start));
      }
      final p = _progress(now, effect.start, RainbowRingsTiming.toast);
      if (p != null && effect.token == latestToastToken) {
        toast = effect.praise;
        toastPeg = effect.peg;
        toastOpacity = 1 - p;
        toastOffsetY = _keyframes(p, const [(0, 0), (.2, -10), (1, -44)]);
        toastScale = p <= .2
            ? _lerp(.6, 1.15, p / .2)
            : _lerp(1.15, 1, (p - .2) / .8);
      }
    }

    var modalOpacity = 0.0;
    var modalScale = 1.0;
    var stars = const <double>[0, 0, 0];
    final confetti = <RainbowParticle>[];
    final win = _win;
    if (win != null) {
      if (!reducedMotion) {
        confetti.addAll(_sampleParticles(win.particles, now - win.start));
      }
      if (reducedMotion) {
        modalOpacity = 1;
        modalScale = 1;
        stars = const [1, 1, 1];
      } else {
        final modalStart = win.start + RainbowRingsTiming.winModalDelay;
        final p = _progress(now, modalStart, RainbowRingsTiming.modal);
        if (p != null) {
          modalOpacity = p;
          modalScale = _elasticScale(p);
        } else if (now >= modalStart + RainbowRingsTiming.modal) {
          modalOpacity = 1;
          modalScale = 1;
        } else {
          modalScale = .4;
        }
        stars = [
          _delayedProgress(
            now,
            modalStart + RainbowRingsTiming.starOneDelay,
            RainbowRingsTiming.star,
          ),
          _delayedProgress(
            now,
            modalStart + RainbowRingsTiming.starTwoDelay,
            RainbowRingsTiming.star,
          ),
          _delayedProgress(
            now,
            modalStart + RainbowRingsTiming.starThreeDelay,
            RainbowRingsTiming.star,
          ),
        ];
      }
    } else if (_winFinal) {
      modalOpacity = 1;
      modalScale = 1;
      stars = const [1, 1, 1];
    }

    return RainbowRingsFrame(
      revision: _revision,
      ringTransforms: rings,
      pegEffects: {
        for (final entry in pegBuilders.entries) entry.key: entry.value.build(),
      },
      bokeh: reducedMotion ? const [] : _sampleBokeh(now),
      sparkles: reducedMotion ? const [] : sparkles,
      confetti: reducedMotion ? const [] : confetti,
      completedPegs: _completedPegTokens.keys.toSet(),
      inputLocked: inputLockedAt(now),
      toast: toast,
      toastPeg: toastPeg,
      toastOpacity: toastOpacity,
      toastOffsetY: toastOffsetY,
      toastScale: toastScale,
      modalOpacity: modalOpacity,
      modalScale: modalScale,
      starProgress: stars,
    );
  }

  void reset({required int seed, bool? reducedMotion}) {
    _seed = seed;
    if (reducedMotion != null) _reducedMotion = reducedMotion;
    _generation++;
    _revision++;
    _nextToken = 1;
    _clearTransientEffects();
    _completedPegTokens.clear();
    _knownRings.clear();
    _winFinal = false;
    _bokeh.clear();
    _createBokeh();
  }

  void _clearTransientEffects() {
    _intro = null;
    _actions.clear();
    _landings.clear();
    _presses.clear();
    _shakes.clear();
    _jiggles.clear();
    _hint = null;
    _completedEffects.clear();
    _win = null;
  }

  int _token() => _generation * 1000000 + _nextToken++;

  void _cleanup(Duration now) {
    _actions.removeWhere((_, effect) {
      if (effect.kind == RainbowRingsTravelKind.select) return false;
      return now >= effect.visualEnd;
    });
    _landings.removeWhere(
      (_, effect) => now >= effect.start + RainbowRingsTiming.settle,
    );
    _presses.removeWhere(
      (_, effect) => now >= effect.start + RainbowRingsTiming.lowerPress,
    );
    _shakes.removeWhere(
      (_, effect) => now >= effect.start + RainbowRingsTiming.invalidShake,
    );
    _jiggles.removeWhere(
      (_, effect) => now >= effect.start + RainbowRingsTiming.poleJiggle,
    );
    if (_hint != null && now >= _hint!.end) _hint = null;
    _completedEffects.removeWhere((_, effect) {
      final jumpEnd =
          effect.start +
          RainbowRingsTiming.completedJump +
          RainbowRingsTiming.completedJumpStagger *
              math.max(0, effect.rings.length - 1);
      return now >= effect.start + RainbowRingsTiming.toast && now >= jumpEnd;
    });
    final intro = _intro;
    if (intro != null) {
      final visualEnd =
          intro.start +
          RainbowRingsTiming.introStagger *
              math.max(0, intro.rings.length - 1) +
          RainbowRingsTiming.introFall +
          RainbowRingsTiming.settle;
      if (now >= visualEnd) _intro = null;
    }
  }

  int _latestToastToken(Duration now) {
    var result = 0;
    for (final effect in _completedEffects.values) {
      if (_progress(now, effect.start, RainbowRingsTiming.toast) != null) {
        result = math.max(result, effect.token);
      }
    }
    return result;
  }

  void _sampleTransientPegEffects(
    Duration now,
    Map<int, _PegBuilder> pegBuilders,
  ) {
    for (final effect in _shakes.values) {
      final p = _progress(now, effect.start, RainbowRingsTiming.invalidShake);
      if (p == null) continue;
      final offset = _keyframes(p, const [(0, 0), (.25, -5), (.75, 5), (1, 0)]);
      final builder = pegBuilders.putIfAbsent(
        effect.peg,
        () => _PegBuilder(effect.peg),
      );
      builder
        ..token = math.max(builder.token, effect.token)
        ..offsetX += offset
        ..kinds.add(RainbowRingsPegEffectKind.invalidShake);
    }
    for (final effect in _jiggles.values) {
      final p = _progress(now, effect.start, RainbowRingsTiming.poleJiggle);
      if (p == null) continue;
      final degrees = _keyframes(p, const [
        (0, 0),
        (.2, 3),
        (.45, -2.5),
        (.7, 1),
        (1, 0),
      ]);
      final builder = pegBuilders.putIfAbsent(
        effect.peg,
        () => _PegBuilder(effect.peg),
      );
      builder
        ..token = math.max(builder.token, effect.token)
        ..rotation += degrees * math.pi / 180
        ..kinds.add(RainbowRingsPegEffectKind.jiggle);
    }
    final hint = _hint;
    if (hint != null && now >= hint.start && now < hint.end) {
      final elapsed = (now - hint.start).inMicroseconds / 1000;
      final glow = elapsed < RainbowRingsTiming.hintPulses.inMilliseconds
          ? 1 - ((elapsed % 500) / 250 - 1).abs()
          : 0.0;
      for (final peg in [hint.sourcePeg, hint.destinationPeg]) {
        final builder = pegBuilders.putIfAbsent(peg, () => _PegBuilder(peg));
        builder
          ..token = math.max(builder.token, hint.token)
          ..glow = math.max(builder.glow, glow)
          ..kinds.add(RainbowRingsPegEffectKind.hint);
      }
    }
  }

  RainbowRingTransform _sampleBreathe(
    RainbowRingsRingPlacement placement,
    Duration now,
  ) {
    final period = RainbowRingsTiming.breathe.inMilliseconds;
    final phase = breathingPhaseMilliseconds(placement.ringId);
    final elapsed = (now.inMilliseconds + phase) % period;
    final p = elapsed / period;
    final wave = .5 - .5 * math.cos(p * math.pi * 2);
    return RainbowRingTransform(
      ringId: placement.ringId,
      token: 0,
      kind: RainbowRingsRingEffectKind.breathe,
      peg: placement.position.peg.toDouble(),
      slot: placement.position.slot.toDouble(),
      restingSlot: placement.position.slot.toDouble(),
      hoverFraction: 0,
      scaleX: 1 + .025 * wave,
      scaleY: 1 - .035 * wave,
    );
  }

  RainbowRingTransform? _sampleIntro(
    _IntroEffect effect,
    int index,
    Duration now,
  ) {
    final placement = effect.rings[index];
    final start = effect.start + RainbowRingsTiming.introStagger * index;
    if (now < start) {
      return RainbowRingTransform(
        ringId: placement.ringId,
        token: effect.token,
        kind: RainbowRingsRingEffectKind.intro,
        peg: placement.position.peg.toDouble(),
        slot: placement.position.slot.toDouble(),
        restingSlot: placement.position.slot.toDouble(),
        hoverFraction: 0,
        offsetYInRings: -3,
        opacity: 0,
      );
    }
    final elapsed = now - start;
    if (elapsed < RainbowRingsTiming.introFall) {
      final raw = _ratio(elapsed, RainbowRingsTiming.introFall);
      final p = _cubic(raw, .5, 0, .9, .5);
      return RainbowRingTransform(
        ringId: placement.ringId,
        token: effect.token,
        kind: RainbowRingsRingEffectKind.intro,
        peg: placement.position.peg.toDouble(),
        slot: placement.position.slot.toDouble(),
        restingSlot: placement.position.slot.toDouble(),
        hoverFraction: 0,
        offsetYInRings: _lerp(-3, 0, p),
        opacity: p,
      );
    }
    final settle = _progress(
      now,
      start + RainbowRingsTiming.introFall,
      RainbowRingsTiming.settle,
    );
    if (settle == null) return null;
    final values = _settleValues(settle);
    return RainbowRingTransform(
      ringId: placement.ringId,
      token: effect.token,
      kind: RainbowRingsRingEffectKind.intro,
      peg: placement.position.peg.toDouble(),
      slot: placement.position.slot.toDouble(),
      restingSlot: placement.position.slot.toDouble(),
      hoverFraction: 0,
      scaleX: values.$1,
      scaleY: values.$2,
      offsetY: values.$3,
      rotation: values.$4,
    );
  }

  RainbowRingTransform? _sampleAction(_ActionEffect? effect, Duration now) {
    if (effect == null || now < effect.start) return null;
    final elapsed = now - effect.start;
    final fallbackRestingSlot =
        effect.sampledStart?.restingSlot ??
        (effect.source.slot == RainbowRingsPosition.hoverSlot
            ? effect.destination.slot.toDouble()
            : effect.source.slot.toDouble());
    final sourcePose =
        effect.sampledStart?._poseValue ??
        _pose(effect.source, fallbackRestingSlot: fallbackRestingSlot);
    switch (effect.kind) {
      case RainbowRingsTravelKind.select:
        final lift = math.min(
          1.0,
          _ratio(elapsed, RainbowRingsTiming.selectLift),
        );
        final liftEase = _cubic(lift, .3, 1.3, .5, 1);
        final pose = _lerpPose(
          sourcePose,
          _pose(
            effect.destination,
            fallbackRestingSlot: sourcePose.restingSlot,
          ),
          liftEase,
        );
        final (scaleX, scaleY, rotation) = elapsed < RainbowRingsTiming.liftPop
            ? _liftPopValues(_ratio(elapsed, RainbowRingsTiming.liftPop))
            : _jellyValues(
                ((elapsed - RainbowRingsTiming.liftPop).inMicroseconds %
                        RainbowRingsTiming.jelly.inMicroseconds) /
                    RainbowRingsTiming.jelly.inMicroseconds,
              );
        return _transformFromPose(
          effect,
          pose,
          RainbowRingsRingEffectKind.select,
          scaleX: scaleX,
          scaleY: scaleY,
          rotation: rotation,
          overlay: true,
          hideRestingRing: true,
        );
      case RainbowRingsTravelKind.deselect:
        if (elapsed >= RainbowRingsTiming.deselectDrop) return null;
        final p = _cubic(
          _ratio(elapsed, RainbowRingsTiming.deselectDrop),
          .5,
          0,
          .9,
          .5,
        );
        return _transformFromPose(
          effect,
          _lerpPose(
            sourcePose,
            _pose(
              effect.destination,
              fallbackRestingSlot: sourcePose.restingSlot,
            ),
            p,
          ),
          RainbowRingsRingEffectKind.deselect,
          scaleX: _lerp(effect.sampledStart?.scaleX ?? 1, 1, p),
          scaleY: _lerp(effect.sampledStart?.scaleY ?? 1, 1, p),
          rotation: _lerp(effect.sampledStart?.rotation ?? 0, 0, p),
          overlay: true,
          hideRestingRing: true,
        );
      case RainbowRingsTravelKind.move:
        return _sampleMove(effect, elapsed, sourcePose, undo: false);
      case RainbowRingsTravelKind.undo:
        return _sampleMove(effect, elapsed, sourcePose, undo: true);
    }
  }

  RainbowRingTransform? _sampleMove(
    _ActionEffect effect,
    Duration elapsed,
    _Pose sourcePose, {
    required bool undo,
  }) {
    var phaseElapsed = elapsed;
    var travelStart = sourcePose;
    if (undo) {
      if (phaseElapsed < RainbowRingsTiming.undoLift) {
        final p = _cubic(
          _ratio(phaseElapsed, RainbowRingsTiming.undoLift),
          .3,
          1.3,
          .5,
          1,
        );
        final hover = _Pose(sourcePose.peg, sourcePose.restingSlot, 1, 0);
        return _transformFromPose(
          effect,
          _lerpPose(sourcePose, hover, p),
          RainbowRingsRingEffectKind.undo,
          overlay: true,
          hideRestingRing: true,
        );
      }
      phaseElapsed -= RainbowRingsTiming.undoLift;
      travelStart = _Pose(sourcePose.peg, sourcePose.restingSlot, 1, 0);
    }
    final destinationRestingSlot =
        effect.destination.slot == RainbowRingsPosition.hoverSlot
        ? sourcePose.restingSlot
        : effect.destination.slot.toDouble();
    final hoverDestination = _Pose(
      effect.destination.peg.toDouble(),
      destinationRestingSlot,
      1,
      0,
    );
    if (phaseElapsed < RainbowRingsTiming.transfer) {
      final raw = _ratio(phaseElapsed, RainbowRingsTiming.transfer);
      final p = _cubic(raw, .45, 0, .2, 1);
      final swing = _swingValues(
        raw,
        effect.destination.peg >= effect.source.peg ? 1 : -1,
        startScaleX: effect.sampledStart?.scaleX,
        startScaleY: effect.sampledStart?.scaleY,
        startRotation: effect.sampledStart?.rotation,
      );
      return _transformFromPose(
        effect,
        _lerpPose(travelStart, hoverDestination, p),
        undo
            ? RainbowRingsRingEffectKind.undo
            : RainbowRingsRingEffectKind.move,
        scaleX: swing.$1,
        scaleY: swing.$2,
        rotation: swing.$3,
        overlay: true,
        hideRestingRing: true,
      );
    }
    phaseElapsed -= RainbowRingsTiming.transfer;
    if (phaseElapsed >= RainbowRingsTiming.drop) return null;
    final p = _cubic(
      _ratio(phaseElapsed, RainbowRingsTiming.drop),
      .5,
      0,
      .9,
      .5,
    );
    return _transformFromPose(
      effect,
      _lerpPose(
        hoverDestination,
        _pose(effect.destination, fallbackRestingSlot: destinationRestingSlot),
        p,
      ),
      undo ? RainbowRingsRingEffectKind.undo : RainbowRingsRingEffectKind.move,
      scaleX: 1.06,
      scaleY: 1.06,
      overlay: true,
      hideRestingRing: true,
    );
  }

  RainbowRingTransform? _sampleLanding(_LandingEffect effect, Duration now) {
    final p = _progress(now, effect.start, RainbowRingsTiming.settle);
    if (p == null) return null;
    final values = _settleValues(p);
    return RainbowRingTransform(
      ringId: effect.ring.ringId,
      token: effect.token,
      kind: RainbowRingsRingEffectKind.landing,
      peg: effect.ring.position.peg.toDouble(),
      slot: effect.ring.position.slot.toDouble(),
      restingSlot: effect.ring.position.slot.toDouble(),
      hoverFraction: 0,
      scaleX: values.$1,
      scaleY: values.$2,
      offsetY: values.$3,
      rotation: values.$4,
    );
  }

  RainbowRingTransform? _samplePress(_PressEffect effect, Duration now) {
    final p = _progress(now, effect.start, RainbowRingsTiming.lowerPress);
    if (p == null) return null;
    final x = _keyframes(p, const [
      (0, 1),
      (.25, 1.14),
      (.55, .95),
      (.8, 1.02),
      (1, 1),
    ]);
    final y = _keyframes(p, const [
      (0, 1),
      (.25, .74),
      (.55, 1.08),
      (.8, .99),
      (1, 1),
    ]);
    return RainbowRingTransform(
      ringId: effect.ringId,
      token: effect.token,
      kind: RainbowRingsRingEffectKind.lowerPress,
      peg: effect.peg.toDouble(),
      slot: effect.slot.toDouble(),
      restingSlot: effect.slot.toDouble(),
      hoverFraction: 0,
      scaleX: x,
      scaleY: y,
    );
  }

  void _sampleCompletedRings(
    _CompletedEffect effect,
    Duration now,
    Map<int, RainbowRingTransform> target,
  ) {
    for (var index = 0; index < effect.rings.length; index++) {
      final placement = effect.rings[index];
      final start =
          effect.start + RainbowRingsTiming.completedJumpStagger * index;
      final p = _progress(now, start, RainbowRingsTiming.completedJump);
      if (p == null) continue;
      final jump = p <= .4
          ? _lerp(0, -14, p / .4)
          : _lerp(-14, 0, (p - .4) / .6);
      target[placement.ringId] = RainbowRingTransform(
        ringId: placement.ringId,
        token: effect.token,
        kind: RainbowRingsRingEffectKind.completedJump,
        peg: placement.position.peg.toDouble(),
        slot: placement.position.slot.toDouble(),
        restingSlot: placement.position.slot.toDouble(),
        hoverFraction: 0,
        offsetY: jump,
      );
    }
  }

  List<RainbowParticle> _sampleBokeh(Duration now) => [
    for (final particle in _bokeh) _sampleBokehParticle(particle, now),
  ];

  RainbowParticle _sampleBokehParticle(
    _ParticleTemplate particle,
    Duration now,
  ) {
    final period = particle.duration.inMicroseconds;
    final elapsed =
        (now.inMicroseconds + particle.delay.inMicroseconds) % period;
    final p = elapsed / period;
    return RainbowParticle(
      id: particle.id,
      kind: particle.kind,
      colorIndex: particle.colorIndex,
      delay: particle.delay,
      duration: particle.duration,
      x: particle.x,
      y: _lerp(1.12, -.18, p),
      size: particle.size,
      opacity: math.sin(p * math.pi).abs() * .24,
      scale: 1,
      rotation: particle.rotation + p * math.pi * 2,
    );
  }

  List<RainbowParticle> _sampleParticles(
    List<_ParticleTemplate> particles,
    Duration elapsed,
  ) => [
    for (final particle in particles)
      if (elapsed < particle.delay + particle.duration)
        _sampleParticle(particle, elapsed),
  ];

  RainbowParticle _sampleParticle(
    _ParticleTemplate particle,
    Duration elapsed,
  ) {
    final local = elapsed - particle.delay;
    final p = local.isNegative
        ? 0.0
        : _ratio(local, particle.duration).clamp(0.0, 1.0);
    final visible = local.isNegative ? 0.0 : 1 - p;
    return switch (particle.kind) {
      RainbowParticleKind.sparkle => RainbowParticle(
        id: particle.id,
        kind: particle.kind,
        colorIndex: particle.colorIndex,
        delay: particle.delay,
        duration: particle.duration,
        x: particle.x * p,
        y: particle.y * p,
        size: particle.size,
        opacity: visible,
        scale: _lerp(1, .2, p),
        rotation: particle.rotation + math.pi * p,
        peg: particle.peg,
      ),
      RainbowParticleKind.confetti => RainbowParticle(
        id: particle.id,
        kind: particle.kind,
        colorIndex: particle.colorIndex,
        delay: particle.delay,
        duration: particle.duration,
        x: particle.x + math.sin(p * math.pi * 4 + particle.rotation) * .06,
        y: _lerp(particle.y, 1.1, p),
        size: particle.size,
        opacity: local.isNegative ? 0 : 1,
        scale: 1,
        rotation: particle.rotation + math.pi * 4 * p,
      ),
      RainbowParticleKind.bokeh => throw StateError(
        'Bokeh uses its own sampler',
      ),
    };
  }

  void _createBokeh() {
    for (var index = 0; index < 14; index++) {
      final base = index * 17 + 0x4400;
      _bokeh.add(
        _ParticleTemplate(
          id: index,
          kind: RainbowParticleKind.bokeh,
          colorIndex: index % 6,
          delay: Duration(milliseconds: (_draw(base) * 30000).floor()),
          duration: Duration(
            milliseconds: 14000 + (_draw(base + 1) * 16001).floor(),
          ),
          x: .03 + _draw(base + 2) * .94,
          y: 1.1,
          size: 14 + _draw(base + 3) * 34,
          rotation: _draw(base + 4) * math.pi * 2,
        ),
      );
    }
  }

  double _draw(int salt) {
    _randomDraws++;
    return _positiveHash(_seed, 0x51ed, salt) / 0x20000000;
  }
}

final class _IntroEffect {
  const _IntroEffect({
    required this.token,
    required this.start,
    required this.rings,
  });
  final int token;
  final Duration start;
  final List<RainbowRingsRingPlacement> rings;
  Duration get lockEnd =>
      start +
      RainbowRingsTiming.introStagger * math.max(0, rings.length - 1) +
      RainbowRingsTiming.introUnlockPadding;
}

final class _ActionEffect {
  const _ActionEffect({
    required this.token,
    required this.start,
    required this.ringId,
    required this.kind,
    required this.source,
    required this.destination,
    required this.sampledStart,
  });
  final int token;
  final Duration start;
  final int ringId;
  final RainbowRingsTravelKind kind;
  final RainbowRingsPosition source;
  final RainbowRingsPosition destination;
  final RainbowRingTransform? sampledStart;

  Duration? get lockEnd => switch (kind) {
    RainbowRingsTravelKind.select => null,
    RainbowRingsTravelKind.deselect => start + RainbowRingsTiming.deselectDrop,
    RainbowRingsTravelKind.move =>
      start + RainbowRingsTiming.transfer + RainbowRingsTiming.drop,
    RainbowRingsTravelKind.undo =>
      start +
          RainbowRingsTiming.undoLift +
          RainbowRingsTiming.transfer +
          RainbowRingsTiming.drop,
  };
  Duration get visualEnd => lockEnd ?? const Duration(days: 36500);
}

final class _LandingEffect {
  const _LandingEffect({
    required this.token,
    required this.start,
    required this.ring,
  });
  final int token;
  final Duration start;
  final RainbowRingsRingPlacement ring;
}

final class _PressEffect {
  const _PressEffect({
    required this.token,
    required this.start,
    required this.ringId,
    required this.peg,
    required this.slot,
  });
  final int token;
  final Duration start;
  final int ringId;
  final int peg;
  final int slot;
}

final class _ShakeEffect {
  const _ShakeEffect({
    required this.token,
    required this.start,
    required this.peg,
  });
  final int token;
  final Duration start;
  final int peg;
}

final class _JiggleEffect {
  const _JiggleEffect({
    required this.token,
    required this.start,
    required this.peg,
  });
  final int token;
  final Duration start;
  final int peg;
}

final class _HintEffect {
  const _HintEffect({
    required this.token,
    required this.start,
    required this.sourcePeg,
    required this.destinationPeg,
  });
  final int token;
  final Duration start;
  final int sourcePeg;
  final int destinationPeg;
  Duration get end => start + RainbowRingsTiming.hintClear;
}

final class _CompletedEffect {
  const _CompletedEffect({
    required this.token,
    required this.start,
    required this.peg,
    required this.rings,
    required this.praise,
    required this.particles,
  });
  final int token;
  final Duration start;
  final int peg;
  final List<RainbowRingsRingPlacement> rings;
  final String praise;
  final List<_ParticleTemplate> particles;
}

final class _WinEffect {
  const _WinEffect({
    required this.token,
    required this.start,
    required this.particles,
  });
  final int token;
  final Duration start;
  final List<_ParticleTemplate> particles;
}

final class _ParticleTemplate {
  const _ParticleTemplate({
    required this.id,
    required this.kind,
    required this.colorIndex,
    required this.delay,
    required this.duration,
    required this.x,
    required this.y,
    required this.size,
    required this.rotation,
    this.peg,
  });
  final int id;
  final RainbowParticleKind kind;
  final int colorIndex;
  final Duration delay;
  final Duration duration;
  final double x;
  final double y;
  final double size;
  final double rotation;
  final int? peg;
}

final class _PegBuilder {
  _PegBuilder(this.peg);
  final int peg;
  int token = 0;
  final Set<RainbowRingsPegEffectKind> kinds = {};
  double offsetX = 0;
  double rotation = 0;
  double glow = 0;
  bool completed = false;

  RainbowPegTransform build() => RainbowPegTransform(
    peg: peg,
    token: token,
    kinds: Set.unmodifiable(kinds),
    offsetX: offsetX,
    rotation: rotation,
    glow: glow,
    completed: completed,
  );
}

final class _Pose {
  const _Pose(
    this.peg,
    this.restingSlot,
    this.hoverFraction,
    this.offsetYInRings,
  );
  final double peg;
  final double restingSlot;
  final double hoverFraction;
  final double offsetYInRings;
}

_Pose _pose(
  RainbowRingsPosition position, {
  required double fallbackRestingSlot,
}) => position.slot == RainbowRingsPosition.hoverSlot
    ? _Pose(position.peg.toDouble(), fallbackRestingSlot, 1, 0)
    : _Pose(position.peg.toDouble(), position.slot.toDouble(), 0, 0);

_Pose _lerpPose(_Pose from, _Pose to, double t) => _Pose(
  _lerp(from.peg, to.peg, t),
  _lerp(from.restingSlot, to.restingSlot, t),
  _lerp(from.hoverFraction, to.hoverFraction, t),
  _lerp(from.offsetYInRings, to.offsetYInRings, t),
);

RainbowRingTransform _transformFromPose(
  _ActionEffect effect,
  _Pose pose,
  RainbowRingsRingEffectKind kind, {
  double scaleX = 1,
  double scaleY = 1,
  double rotation = 0,
  bool overlay = false,
  bool hideRestingRing = false,
}) => RainbowRingTransform(
  ringId: effect.ringId,
  token: effect.token,
  kind: kind,
  peg: pose.peg,
  slot: pose.hoverFraction == 1
      ? RainbowRingsPosition.hoverSlot.toDouble()
      : pose.restingSlot,
  restingSlot: pose.restingSlot,
  hoverFraction: pose.hoverFraction,
  offsetYInRings: pose.offsetYInRings,
  scaleX: scaleX,
  scaleY: scaleY,
  rotation: rotation,
  overlay: overlay,
  hideRestingRing: hideRestingRing,
);

extension on RainbowRingTransform {
  _Pose get _poseValue =>
      _Pose(peg, restingSlot, hoverFraction, offsetYInRings);
}

double _ratio(Duration elapsed, Duration duration) =>
    elapsed.inMicroseconds / duration.inMicroseconds;

double? _progress(Duration now, Duration start, Duration duration) {
  if (now < start || now >= start + duration) return null;
  return _ratio(now - start, duration).clamp(0.0, 1.0);
}

double _delayedProgress(Duration now, Duration start, Duration duration) {
  if (now <= start) return 0;
  if (now >= start + duration) return 1;
  return _ratio(now - start, duration).clamp(0.0, 1.0);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _keyframes(double t, List<(double, double)> frames) {
  if (t <= frames.first.$1) return frames.first.$2;
  for (var index = 1; index < frames.length; index++) {
    final next = frames[index];
    if (t <= next.$1) {
      final previous = frames[index - 1];
      final local = (t - previous.$1) / (next.$1 - previous.$1);
      return _lerp(previous.$2, next.$2, local);
    }
  }
  return frames.last.$2;
}

(double, double, double) _liftPopValues(double t) => (
  _keyframes(t, const [(0, 1), (.25, 1.34), (.55, .9), (.78, 1.1), (1, 1.06)]),
  _keyframes(t, const [(0, 1), (.25, .62), (.55, 1.22), (.78, .96), (1, 1.06)]),
  0,
);

(double, double, double) _jellyValues(double t) {
  final degrees = t <= .5 ? _lerp(-3, 3, t * 2) : _lerp(3, -3, (t - .5) * 2);
  return (
    t <= .5 ? _lerp(1.05, 1.16, t * 2) : _lerp(1.16, 1.05, (t - .5) * 2),
    t <= .5 ? _lerp(1.07, .98, t * 2) : _lerp(.98, 1.07, (t - .5) * 2),
    degrees * math.pi / 180,
  );
}

(double, double, double) _swingValues(
  double t,
  int direction, {
  double? startScaleX,
  double? startScaleY,
  double? startRotation,
}) {
  final degrees = _keyframes(t, [
    (0, (startRotation ?? 0) * 180 / math.pi),
    (.3, 14.0 * direction),
    (.6, -7.0 * direction),
    (1, 0),
  ]);
  return (
    _keyframes(t, [(0, startScaleX ?? 1.06), (.3, .93), (.6, 1.08), (1, 1.06)]),
    _keyframes(t, [(0, startScaleY ?? 1.06), (.3, 1.12), (.6, .95), (1, 1.06)]),
    degrees * math.pi / 180,
  );
}

(double, double, double, double) _settleValues(double t) => (
  _keyframes(t, const [
    (0, 1.4),
    (.16, .84),
    (.32, 1.16),
    (.48, .93),
    (.64, 1.06),
    (.8, .98),
    (1, 1),
  ]),
  _keyframes(t, const [
    (0, .5),
    (.16, 1.24),
    (.32, .86),
    (.48, 1.09),
    (.64, .95),
    (.8, 1.02),
    (1, 1),
  ]),
  _keyframes(t, const [
    (0, 0),
    (.16, -12),
    (.32, 0),
    (.48, -4),
    (.64, 0),
    (.8, 0),
    (1, 0),
  ]),
  _keyframes(t, const [
        (0, 0),
        (.16, -4),
        (.32, 3),
        (.48, -2),
        (.64, 1),
        (.8, 0),
        (1, 0),
      ]) *
      math.pi /
      180,
);

double _elasticScale(double t) {
  if (t <= 0) return .4;
  if (t >= 1) return 1;
  final eased =
      1 - math.pow(2, -10 * t) * math.cos((t * 10 - .75) * 2 * math.pi / 3);
  return _lerp(.4, 1, eased.toDouble());
}

double _cubic(double x, double x1, double y1, double x2, double y2) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  var low = 0.0;
  var high = 1.0;
  var t = x;
  for (var index = 0; index < 18; index++) {
    final estimate = _bezier(t, x1, x2);
    if (estimate < x) {
      low = t;
    } else {
      high = t;
    }
    t = (low + high) / 2;
  }
  return _bezier(t, y1, y2);
}

double _bezier(double t, double a, double b) {
  final inverse = 1 - t;
  return 3 * inverse * inverse * t * a + 3 * inverse * t * t * b + t * t * t;
}

int _positiveHash(int a, int b, int c) {
  var value = 0x1fffffff & (a ^ 0x9e3779b9);
  value = 0x1fffffff & (value + b * 0x45d9f3b);
  value ^= value >> 16;
  value = 0x1fffffff & (value * 0x45d9f3b + c * 0x27d4eb2d);
  value ^= value >> 15;
  return value & 0x7fffffff;
}
