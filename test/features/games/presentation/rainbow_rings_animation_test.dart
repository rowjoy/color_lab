import 'dart:math' as math;

import 'package:color_lab/features/games/domain/rainbow_rings_game.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const zero = Duration.zero;
  const ring = RainbowRingsRingPlacement(
    ringId: 7,
    position: RainbowRingsPosition(peg: 1, slot: 2),
  );

  RainbowRingsActionResult action(
    RainbowRingsActionKind kind, {
    RainbowRingsPosition? source,
    RainbowRingsPosition? destination,
  }) => RainbowRingsActionResult(
    kind: kind,
    ringId: 7,
    source: source,
    destination: destination,
  );

  List<RainbowRingsFrame> around(
    RainbowRingsTimeline timeline,
    Duration boundary, {
    Duration step = const Duration(microseconds: 1),
  }) => [
    timeline.sample(boundary - step),
    timeline.sample(boundary),
    timeline.sample(boundary + step),
  ];

  group('frozen timings and intro', () {
    test('publishes every literal duration used by screen orchestration', () {
      expect(RainbowRingsTiming.breathe, const Duration(milliseconds: 3600));
      expect(RainbowRingsTiming.progress, const Duration(milliseconds: 600));
      expect(RainbowRingsTiming.introStagger, const Duration(milliseconds: 55));
      expect(RainbowRingsTiming.introFall, const Duration(milliseconds: 500));
      expect(
        RainbowRingsTiming.introUnlockPadding,
        const Duration(milliseconds: 700),
      );
      expect(RainbowRingsTiming.selectLift, const Duration(milliseconds: 240));
      expect(RainbowRingsTiming.liftPop, const Duration(milliseconds: 400));
      expect(RainbowRingsTiming.jelly, const Duration(milliseconds: 1100));
      expect(
        RainbowRingsTiming.deselectDrop,
        const Duration(milliseconds: 300),
      );
      expect(RainbowRingsTiming.transfer, const Duration(milliseconds: 260));
      expect(RainbowRingsTiming.drop, const Duration(milliseconds: 340));
      expect(RainbowRingsTiming.undoLift, const Duration(milliseconds: 200));
      expect(
        RainbowRingsTiming.invalidShake,
        const Duration(milliseconds: 300),
      );
      expect(RainbowRingsTiming.settle, const Duration(milliseconds: 1150));
      expect(RainbowRingsTiming.lowerPress, const Duration(milliseconds: 700));
      expect(
        RainbowRingsTiming.lowerPressStagger,
        const Duration(milliseconds: 70),
      );
      expect(RainbowRingsTiming.poleJiggle, const Duration(milliseconds: 550));
      expect(RainbowRingsTiming.hintPulses, const Duration(milliseconds: 1500));
      expect(RainbowRingsTiming.hintClear, const Duration(milliseconds: 1600));
      expect(
        RainbowRingsTiming.completedJump,
        const Duration(milliseconds: 550),
      );
      expect(
        RainbowRingsTiming.completedJumpStagger,
        const Duration(milliseconds: 50),
      );
      expect(RainbowRingsTiming.sparkle, const Duration(milliseconds: 900));
      expect(RainbowRingsTiming.toast, const Duration(milliseconds: 1000));
      expect(
        RainbowRingsTiming.winModalDelay,
        const Duration(milliseconds: 800),
      );
      expect(RainbowRingsTiming.modal, const Duration(milliseconds: 550));
      expect(RainbowRingsTiming.star, const Duration(milliseconds: 600));
      expect(
        RainbowRingsTiming.starOneDelay,
        const Duration(milliseconds: 300),
      );
      expect(
        RainbowRingsTiming.starTwoDelay,
        const Duration(milliseconds: 550),
      );
      expect(
        RainbowRingsTiming.starThreeDelay,
        const Duration(milliseconds: 800),
      );
    });

    test(
      'intro orders bottom slot then peg and unlocks at final stagger + 700ms',
      () {
        final timeline = RainbowRingsTimeline(seed: 10);
        timeline.startIntro(
          at: zero,
          rings: const [
            RainbowRingsRingPlacement(
              ringId: 3,
              position: RainbowRingsPosition(peg: 1, slot: 1),
            ),
            RainbowRingsRingPlacement(
              ringId: 2,
              position: RainbowRingsPosition(peg: 1, slot: 0),
            ),
            RainbowRingsRingPlacement(
              ringId: 1,
              position: RainbowRingsPosition(peg: 0, slot: 0),
            ),
          ],
        );

        final first = timeline.sample(zero).ringTransforms[1]!;
        final secondBefore = timeline
            .sample(const Duration(milliseconds: 54))
            .ringTransforms[2]!;
        final secondAt = timeline
            .sample(const Duration(milliseconds: 55))
            .ringTransforms[2]!;
        final secondAfter = timeline
            .sample(const Duration(milliseconds: 56))
            .ringTransforms[2]!;
        final thirdStagger = around(
          timeline,
          const Duration(milliseconds: 110),
          step: const Duration(milliseconds: 1),
        );
        expect(first.opacity, 0);
        expect(first.offsetYInRings, -3);
        expect(secondBefore.opacity, 0);
        expect(secondAt.opacity, 0);
        expect(secondAfter.opacity, greaterThan(0));
        expect(secondAfter.offsetYInRings, greaterThan(-3));
        expect(thirdStagger[0].ringTransforms[3]!.opacity, 0);
        expect(thirdStagger[1].ringTransforms[3]!.opacity, 0);
        expect(thirdStagger[2].ringTransforms[3]!.opacity, greaterThan(0));
        expect(
          timeline.inputLockedAt(const Duration(milliseconds: 809)),
          isTrue,
        );
        expect(
          timeline.inputLockedAt(const Duration(milliseconds: 810)),
          isFalse,
        );
        expect(
          timeline
              .sample(const Duration(milliseconds: 610))
              .ringTransforms[2]!
              .opacity,
          1,
        );
      },
    );

    test('intro opacity follows fall easing through the 500ms boundary', () {
      final timeline = RainbowRingsTimeline(seed: 100);
      timeline.startIntro(at: zero, rings: const [ring]);

      final midpoint = timeline
          .sample(const Duration(milliseconds: 250))
          .ringTransforms[7]!;
      expect(midpoint.opacity, closeTo(.1775, .002));
      expect(midpoint.offsetYInRings, closeTo(-2.4675, .006));

      final before = timeline
          .sample(const Duration(milliseconds: 499))
          .ringTransforms[7]!;
      final at = timeline
          .sample(const Duration(milliseconds: 500))
          .ringTransforms[7]!;
      final after = timeline
          .sample(const Duration(milliseconds: 501))
          .ringTransforms[7]!;
      expect(before.opacity, lessThan(1));
      expect(at.opacity, 1);
      expect(after.opacity, 1);
      expect(at.scaleX, closeTo(1.4, .001));
    });
  });

  group('selection, retarget, move, and undo', () {
    test('travel exposes resize-safe resting slot and hover fraction', () {
      for (final restingSlot in [0, 3]) {
        final select = RainbowRingsTimeline(seed: 101);
        select.startAction(
          at: zero,
          action: action(
            RainbowRingsActionKind.select,
            source: RainbowRingsPosition(peg: 1, slot: restingSlot),
            destination: const RainbowRingsPosition.hover(1),
          ),
        );
        final lifted = select
            .sample(const Duration(milliseconds: 120))
            .ringTransforms[7]!;
        expect(lifted.restingSlot, restingSlot);
        expect(lifted.hoverFraction, greaterThan(0));
        expect(lifted.slot, anyOf(restingSlot.toDouble(), -1.0));
        final hovered = select
            .sample(const Duration(milliseconds: 240))
            .ringTransforms[7]!;
        expect(hovered.restingSlot, restingSlot);
        expect(hovered.hoverFraction, closeTo(1, .001));

        final deselect = RainbowRingsTimeline(seed: 102);
        deselect.startAction(
          at: zero,
          action: action(
            RainbowRingsActionKind.deselect,
            source: const RainbowRingsPosition.hover(1),
            destination: RainbowRingsPosition(peg: 1, slot: restingSlot),
          ),
        );
        final dropping = deselect
            .sample(const Duration(milliseconds: 150))
            .ringTransforms[7]!;
        expect(dropping.restingSlot, restingSlot);
        expect(dropping.hoverFraction, inExclusiveRange(0, 1));
      }

      final move = RainbowRingsTimeline(seed: 103);
      move.startAction(
        at: zero,
        action: action(
          RainbowRingsActionKind.move,
          source: const RainbowRingsPosition.hover(0),
          destination: const RainbowRingsPosition(peg: 2, slot: 3),
        ),
      );
      final transferring = move
          .sample(const Duration(milliseconds: 130))
          .ringTransforms[7]!;
      expect(transferring.restingSlot, 3);
      expect(transferring.hoverFraction, 1);
      final dropping = move
          .sample(const Duration(milliseconds: 430))
          .ringTransforms[7]!;
      expect(dropping.peg, 2);
      expect(dropping.restingSlot, 3);
      expect(dropping.hoverFraction, inExclusiveRange(0, 1));

      final undo = RainbowRingsTimeline(seed: 104);
      undo.startAction(
        at: zero,
        action: action(
          RainbowRingsActionKind.undo,
          source: const RainbowRingsPosition(peg: 2, slot: 2),
          destination: const RainbowRingsPosition(peg: 0, slot: 0),
        ),
      );
      final undoLift = undo
          .sample(const Duration(milliseconds: 100))
          .ringTransforms[7]!;
      expect(undoLift.restingSlot, 2);
      expect(undoLift.hoverFraction, greaterThan(0));
      final undoDrop = undo
          .sample(const Duration(milliseconds: 630))
          .ringTransforms[7]!;
      expect(undoDrop.restingSlot, 0);
      expect(undoDrop.hoverFraction, inExclusiveRange(0, 1));
    });

    test(
      'lift-pop enters deterministic jelly keyframes without locking input',
      () {
        final timeline = RainbowRingsTimeline(seed: 1);
        timeline.startAction(
          at: zero,
          action: action(
            RainbowRingsActionKind.select,
            source: const RainbowRingsPosition(peg: 1, slot: 2),
            destination: const RainbowRingsPosition.hover(1),
          ),
        );

        expect(timeline.inputLockedAt(zero), isFalse);
        expect(timeline.sample(zero).ringTransforms[7]!.scaleX, 1);
        final popQuarter = timeline
            .sample(const Duration(milliseconds: 100))
            .ringTransforms[7]!;
        expect(popQuarter.scaleX, closeTo(1.34, .001));
        expect(popQuarter.scaleY, closeTo(.62, .001));
        final jellyStart = timeline
            .sample(const Duration(milliseconds: 400))
            .ringTransforms[7]!;
        expect(jellyStart.scaleX, closeTo(1.05, .001));
        expect(jellyStart.scaleY, closeTo(1.07, .001));
        expect(jellyStart.rotation, closeTo(-3 * math.pi / 180, .001));
        final jellyMiddle = timeline
            .sample(const Duration(milliseconds: 950))
            .ringTransforms[7]!;
        expect(jellyMiddle.scaleX, closeTo(1.16, .001));
        expect(jellyMiddle.rotation, closeTo(3 * math.pi / 180, .001));
      },
    );

    test(
      'rapid move retarget starts from the currently sampled lifted pose',
      () {
        final timeline = RainbowRingsTimeline(seed: 2);
        timeline.startAction(
          at: zero,
          action: action(
            RainbowRingsActionKind.select,
            source: const RainbowRingsPosition(peg: 0, slot: 3),
            destination: const RainbowRingsPosition.hover(0),
          ),
        );
        const retargetAt = Duration(milliseconds: 120);
        final sampled = timeline.sample(retargetAt).ringTransforms[7]!;
        timeline.startAction(
          at: retargetAt,
          action: action(
            RainbowRingsActionKind.move,
            source: const RainbowRingsPosition.hover(0),
            destination: const RainbowRingsPosition(peg: 2, slot: 1),
          ),
        );
        final retargeted = timeline.sample(retargetAt).ringTransforms[7]!;
        expect(retargeted.peg, closeTo(sampled.peg, 1e-9));
        expect(retargeted.slot, closeTo(sampled.slot, 1e-9));
        expect(
          retargeted.offsetYInRings,
          closeTo(sampled.offsetYInRings, 1e-9),
        );
        expect(retargeted.restingSlot, closeTo(sampled.restingSlot, 1e-9));
        expect(retargeted.hoverFraction, closeTo(sampled.hoverFraction, 1e-9));
        expect(retargeted.scaleX, closeTo(sampled.scaleX, 1e-9));
        expect(retargeted.scaleY, closeTo(sampled.scaleY, 1e-9));
        expect(retargeted.rotation, closeTo(sampled.rotation, 1e-9));
        expect(retargeted.hideRestingRing, isTrue);
        final swing30 = timeline
            .sample(retargetAt + const Duration(milliseconds: 78))
            .ringTransforms[7]!;
        expect(swing30.scaleX, closeTo(.93, .001));
        expect(swing30.scaleY, closeTo(1.12, .001));
        expect(swing30.rotation, closeTo(14 * math.pi / 180, .001));
        final swing60 = timeline
            .sample(retargetAt + const Duration(milliseconds: 156))
            .ringTransforms[7]!;
        expect(swing60.scaleX, closeTo(1.08, .001));
        expect(swing60.scaleY, closeTo(.95, .001));
        expect(swing60.rotation, closeTo(-7 * math.pi / 180, .001));
        expect(timeline.debugEffectCount, lessThanOrEqualTo(2));
      },
    );

    test(
      'move locks exactly 600ms and hides only the mutated resting ring',
      () {
        final timeline = RainbowRingsTimeline(seed: 3);
        timeline.startAction(
          at: zero,
          action: action(
            RainbowRingsActionKind.move,
            source: const RainbowRingsPosition.hover(0),
            destination: const RainbowRingsPosition(peg: 2, slot: 1),
          ),
        );

        expect(
          timeline.inputLockedAt(const Duration(milliseconds: 599)),
          isTrue,
        );
        expect(
          timeline.inputLockedAt(const Duration(milliseconds: 600)),
          isFalse,
        );
        final transferEnd = timeline
            .sample(const Duration(milliseconds: 260))
            .ringTransforms[7]!;
        expect(transferEnd.peg, closeTo(2, .001));
        expect(transferEnd.slot, RainbowRingsPosition.hoverSlot);
        expect(transferEnd.scaleX, closeTo(1.06, .001));
        expect(transferEnd.scaleY, closeTo(1.06, .001));
        expect(transferEnd.rotation, closeTo(0, .001));
        expect(transferEnd.hideRestingRing, isTrue);
        final dropMiddle = timeline
            .sample(const Duration(milliseconds: 430))
            .ringTransforms[7]!;
        expect(dropMiddle.hoverFraction, closeTo(.8225, .002));
        final end = timeline.sample(const Duration(milliseconds: 600));
        expect(end.ringTransforms[7], isNull);
      },
    );

    test('undo prepends 200ms lift and locks exactly 800ms', () {
      final timeline = RainbowRingsTimeline(seed: 4);
      timeline.startAction(
        at: zero,
        action: action(
          RainbowRingsActionKind.undo,
          source: const RainbowRingsPosition(peg: 2, slot: 1),
          destination: const RainbowRingsPosition(peg: 0, slot: 3),
        ),
      );
      final liftEnd = timeline
          .sample(const Duration(milliseconds: 200))
          .ringTransforms[7]!;
      expect(liftEnd.peg, closeTo(2, .001));
      expect(liftEnd.slot, RainbowRingsPosition.hoverSlot);
      expect(timeline.inputLockedAt(const Duration(milliseconds: 799)), isTrue);
      expect(
        timeline.inputLockedAt(const Duration(milliseconds: 800)),
        isFalse,
      );
    });

    test('deselect locks for 300ms and invalid shake keeps no travel lock', () {
      final timeline = RainbowRingsTimeline(seed: 5);
      timeline.startAction(
        at: zero,
        action: action(
          RainbowRingsActionKind.deselect,
          source: const RainbowRingsPosition.hover(1),
          destination: const RainbowRingsPosition(peg: 1, slot: 2),
        ),
      );
      expect(timeline.inputLockedAt(const Duration(milliseconds: 299)), isTrue);
      expect(
        timeline
            .sample(const Duration(milliseconds: 150))
            .ringTransforms[7]!
            .hoverFraction,
        closeTo(.8225, .002),
      );
      expect(
        timeline.inputLockedAt(const Duration(milliseconds: 300)),
        isFalse,
      );
      timeline.startAction(
        at: const Duration(seconds: 1),
        action: action(
          RainbowRingsActionKind.invalid,
          source: const RainbowRingsPosition.hover(1),
          destination: const RainbowRingsPosition(peg: 2, slot: 0),
        ),
      );
      expect(timeline.inputLockedAt(const Duration(seconds: 1)), isFalse);
      expect(
        timeline
            .sample(const Duration(milliseconds: 1075))
            .pegEffects[2]!
            .offsetX,
        closeTo(-5, .001),
      );
      expect(
        timeline
            .sample(const Duration(milliseconds: 1225))
            .pegEffects[2]!
            .offsetX,
        closeTo(5, .001),
      );
    });
  });

  group('landing, hint, completed stack, and ambient effects', () {
    test(
      'landing samples literal settle, press, and pole-jiggle keyframes',
      () {
        final timeline = RainbowRingsTimeline(seed: 6);
        timeline.startLanding(at: zero, ring: ring, lowerRingIds: const [2, 3]);
        final start = timeline.sample(zero);
        expect(start.ringTransforms[7]!.scaleX, closeTo(1.4, .001));
        expect(start.ringTransforms[7]!.scaleY, closeTo(.5, .001));
        expect(start.pegEffects[1]!.rotation, 0);
        final jiggle20 = timeline
            .sample(const Duration(milliseconds: 110))
            .pegEffects[1]!;
        expect(jiggle20.rotation, closeTo(3 * math.pi / 180, .001));
        final press25 = timeline
            .sample(const Duration(milliseconds: 175))
            .ringTransforms[3]!;
        expect(press25.scaleX, closeTo(1.14, .001));
        expect(press25.scaleY, closeTo(.74, .001));
        expect(
          timeline.sample(const Duration(milliseconds: 1149)).ringTransforms[7],
          isNotNull,
        );
        expect(
          timeline
              .sample(const Duration(milliseconds: 1150))
              .ringTransforms[7]!
              .kind,
          RainbowRingsRingEffectKind.breathe,
        );
      },
    );

    test('hint pulses three times and clears at 1.6 seconds', () {
      final timeline = RainbowRingsTimeline(seed: 7);
      timeline.startHint(at: zero, sourcePeg: 1, destinationPeg: 3);
      expect(timeline.sample(zero).pegEffects[1]!.glow, closeTo(0, .001));
      expect(
        timeline.sample(const Duration(milliseconds: 250)).pegEffects[1]!.glow,
        closeTo(1, .001),
      );
      expect(
        timeline.sample(const Duration(milliseconds: 750)).pegEffects[3]!.glow,
        closeTo(1, .001),
      );
      expect(
        timeline.sample(const Duration(milliseconds: 1250)).pegEffects[1]!.glow,
        closeTo(1, .001),
      );
      expect(
        timeline.sample(const Duration(milliseconds: 1599)).pegEffects,
        isNotEmpty,
      );
      expect(
        timeline.sample(const Duration(milliseconds: 1600)).pegEffects,
        isEmpty,
      );
    });

    test(
      'completed peg jumps bottom-up with 12 deterministic stars and toast',
      () {
        final timeline = RainbowRingsTimeline(seed: 8);
        timeline.startCompletedPeg(
          at: zero,
          peg: 2,
          rings: const [
            RainbowRingsRingPlacement(
              ringId: 1,
              position: RainbowRingsPosition(peg: 2, slot: 0),
            ),
            RainbowRingsRingPlacement(
              ringId: 2,
              position: RainbowRingsPosition(peg: 2, slot: 1),
            ),
          ],
        );
        final frame = timeline.sample(const Duration(milliseconds: 220));
        expect(frame.completedPegs, contains(2));
        expect(frame.sparkles, hasLength(12));
        expect(frame.toast, anyOf('Sorted!', 'Nice!', 'Great!', 'Wow!'));
        expect(frame.ringTransforms[1]!.offsetY, lessThan(0));
        expect(frame.toastOpacity, greaterThan(0));
        expect(frame.toastPeg, 2);
        final toastAt20 = timeline.sample(const Duration(milliseconds: 200));
        expect(toastAt20.toastOffsetY, closeTo(-10, .001));
        expect(toastAt20.toastScale, closeTo(1.15, .001));
        final sparkleMiddle = timeline
            .sample(const Duration(milliseconds: 450))
            .sparkles;
        expect(sparkleMiddle, hasLength(12));
        expect(
          sparkleMiddle,
          everyElement(
            predicate<RainbowParticle>(
              (particle) =>
                  particle.peg == 2 &&
                  (particle.opacity - .5).abs() < .001 &&
                  (particle.scale - .6).abs() < .001 &&
                  (particle.rotation - math.pi / 2).abs() < .001,
            ),
          ),
        );
        for (final particle in sparkleMiddle) {
          final terminalX = particle.x * 2;
          final terminalY = particle.y * 2;
          final radialDistance = math.sqrt(
            terminalX * terminalX + (terminalY + 10) * (terminalY + 10),
          );
          expect(radialDistance, inInclusiveRange(24, 62));
          expect(particle.size, inInclusiveRange(5, 10));
        }
        expect(
          timeline.sample(const Duration(milliseconds: 900)).sparkles,
          isEmpty,
        );
        final toastBeforeEnd = timeline.sample(
          const Duration(microseconds: 999999),
        );
        expect(toastBeforeEnd.toast, isNotNull);
        expect(toastBeforeEnd.toastOpacity, closeTo(0, .001));
        expect(toastBeforeEnd.toastOffsetY, closeTo(-44, .001));
        expect(toastBeforeEnd.toastScale, closeTo(1, .001));
        final toastEnd = timeline.sample(const Duration(milliseconds: 1000));
        expect(toastEnd.toast, isNull);
        expect(toastEnd.toastOpacity, 0);
        expect(toastEnd.toastOffsetY, 0);
        expect(toastEnd.toastScale, 1);
      },
    );

    test(
      'bokeh and breathing are deterministic and sampling draws no randomness',
      () {
        final first = RainbowRingsTimeline(seed: 9)
          ..rememberRings(const [ring]);
        final second = RainbowRingsTimeline(seed: 9)
          ..rememberRings(const [ring]);
        final draws = first.debugRandomDraws;
        final peak = Duration(
          milliseconds:
              (1800 - first.breathingPhaseMilliseconds(ring.ringId)) % 3600,
        );
        final frame = first.sample(peak);
        expect(frame.bokeh, hasLength(14));
        expect(frame.bokeh, second.sample(peak).bokeh);
        expect(
          frame.bokeh.map((particle) => particle.x).reduce(math.min),
          lessThan(.25),
        );
        expect(
          frame.bokeh.map((particle) => particle.x).reduce(math.max),
          greaterThan(.75),
        );
        expect(
          frame.bokeh.map((particle) => particle.duration.inMilliseconds),
          everyElement(inInclusiveRange(14000, 30000)),
        );
        expect(frame.ringTransforms[7]!.scaleX, closeTo(1.025, .001));
        expect(frame.ringTransforms[7]!.scaleY, closeTo(.965, .001));
        expect(first.debugRandomDraws, draws);
      },
    );
  });

  group('frozen keyframe boundary matrix', () {
    test('lift-pop and jelly sample immediately around every keyframe', () {
      const start = Duration(milliseconds: 100);
      final timeline = RainbowRingsTimeline(seed: 201);
      timeline.startAction(
        at: start,
        action: action(
          RainbowRingsActionKind.select,
          source: const RainbowRingsPosition(peg: 1, slot: 3),
          destination: const RainbowRingsPosition.hover(1),
        ),
      );

      final beforeStart = timeline.sample(
        start - const Duration(microseconds: 1),
      );
      expect(beforeStart.ringTransforms[7], isNull);
      const popFrames = [
        (0, 1.0, 1.0),
        (100, 1.34, .62),
        (220, .9, 1.22),
        (312, 1.1, .96),
      ];
      for (final (elapsedMs, expectedX, expectedY) in popFrames) {
        final samples = around(
          timeline,
          start + Duration(milliseconds: elapsedMs),
        );
        final at = samples[1].ringTransforms[7]!;
        expect(at.scaleX, closeTo(expectedX, .001));
        expect(at.scaleY, closeTo(expectedY, .001));
        expect(samples[2].ringTransforms[7]!.scaleX, closeTo(expectedX, .01));
        if (elapsedMs > 0) {
          expect(samples[0].ringTransforms[7]!.scaleX, closeTo(expectedX, .01));
        }
      }

      final liftEnd = around(
        timeline,
        start + const Duration(milliseconds: 240),
      );
      expect(liftEnd[1].ringTransforms[7]!.hoverFraction, closeTo(1, .001));
      expect(liftEnd[2].ringTransforms[7]!.hoverFraction, closeTo(1, .001));

      final jellyStart = around(
        timeline,
        start + const Duration(milliseconds: 400),
      );
      expect(jellyStart[0].ringTransforms[7]!.scaleX, closeTo(1.06, .001));
      expect(jellyStart[1].ringTransforms[7]!.scaleX, closeTo(1.05, .001));
      expect(jellyStart[1].ringTransforms[7]!.scaleY, closeTo(1.07, .001));
      expect(
        jellyStart[1].ringTransforms[7]!.rotation,
        closeTo(-3 * math.pi / 180, .001),
      );
      expect(jellyStart[2].ringTransforms[7]!.scaleX, closeTo(1.05, .001));

      final jellyMiddle = around(
        timeline,
        start + const Duration(milliseconds: 950),
      );
      for (final frame in jellyMiddle) {
        expect(frame.ringTransforms[7]!.scaleX, closeTo(1.16, .001));
        expect(frame.ringTransforms[7]!.scaleY, closeTo(.98, .001));
        expect(
          frame.ringTransforms[7]!.rotation,
          closeTo(3 * math.pi / 180, .001),
        );
      }

      final jellyWrap = around(
        timeline,
        start + const Duration(milliseconds: 1500),
      );
      for (final frame in jellyWrap) {
        expect(frame.ringTransforms[7]!.scaleX, closeTo(1.05, .001));
        expect(frame.ringTransforms[7]!.scaleY, closeTo(1.07, .001));
        expect(
          frame.ringTransforms[7]!.rotation,
          closeTo(-3 * math.pi / 180, .001),
        );
      }
    });

    test('move, drop, undo, and deselect pin every phase boundary', () {
      const start = Duration(milliseconds: 100);
      final move = RainbowRingsTimeline(seed: 202);
      move.startAction(
        at: start,
        action: action(
          RainbowRingsActionKind.move,
          source: const RainbowRingsPosition.hover(0),
          destination: const RainbowRingsPosition(peg: 2, slot: 3),
        ),
      );
      const swingFrames = [
        (0, 1.06, 1.06, 0.0),
        (78, .93, 1.12, 14.0),
        (156, 1.08, .95, -7.0),
      ];
      for (final (elapsedMs, expectedX, expectedY, degrees) in swingFrames) {
        final samples = around(move, start + Duration(milliseconds: elapsedMs));
        final at = samples[1].ringTransforms[7]!;
        expect(at.scaleX, closeTo(expectedX, .001));
        expect(at.scaleY, closeTo(expectedY, .001));
        expect(at.rotation, closeTo(degrees * math.pi / 180, .001));
        expect(samples[2].ringTransforms[7]!.scaleX, closeTo(expectedX, .01));
      }
      final dropStart = around(move, start + const Duration(milliseconds: 260));
      for (final frame in dropStart) {
        expect(frame.ringTransforms[7]!.peg, closeTo(2, .001));
        expect(frame.ringTransforms[7]!.hoverFraction, closeTo(1, .001));
      }
      final moveEnd = around(move, start + const Duration(milliseconds: 600));
      expect(moveEnd[0].ringTransforms[7], isNotNull);
      expect(moveEnd[1].ringTransforms[7], isNull);
      expect(moveEnd[2].ringTransforms[7], isNull);
      expect(
        move.inputLockedAt(start + const Duration(milliseconds: 599)),
        isTrue,
      );
      expect(
        move.inputLockedAt(start + const Duration(milliseconds: 600)),
        isFalse,
      );

      final reverse = RainbowRingsTimeline(seed: 211);
      reverse.startAction(
        at: start,
        action: action(
          RainbowRingsActionKind.move,
          source: const RainbowRingsPosition.hover(2),
          destination: const RainbowRingsPosition(peg: 0, slot: 1),
        ),
      );
      final reverse30 = reverse
          .sample(start + const Duration(milliseconds: 78))
          .ringTransforms[7]!;
      expect(reverse30.scaleX, closeTo(.93, .001));
      expect(reverse30.scaleY, closeTo(1.12, .001));
      expect(reverse30.rotation, closeTo(-14 * math.pi / 180, .001));
      final reverse60 = reverse
          .sample(start + const Duration(milliseconds: 156))
          .ringTransforms[7]!;
      expect(reverse60.scaleX, closeTo(1.08, .001));
      expect(reverse60.scaleY, closeTo(.95, .001));
      expect(reverse60.rotation, closeTo(7 * math.pi / 180, .001));

      final undo = RainbowRingsTimeline(seed: 203);
      undo.startAction(
        at: start,
        action: action(
          RainbowRingsActionKind.undo,
          source: const RainbowRingsPosition(peg: 2, slot: 2),
          destination: const RainbowRingsPosition(peg: 0, slot: 0),
        ),
      );
      final undoTransferStart = around(
        undo,
        start + const Duration(milliseconds: 200),
      );
      expect(
        undoTransferStart[0].ringTransforms[7]!.hoverFraction,
        closeTo(1, .001),
      );
      expect(
        undoTransferStart[1].ringTransforms[7]!.hoverFraction,
        closeTo(1, .001),
      );
      final undoDropStart = around(
        undo,
        start + const Duration(milliseconds: 460),
      );
      expect(undoDropStart[1].ringTransforms[7]!.peg, closeTo(0, .001));
      expect(
        undoDropStart[1].ringTransforms[7]!.hoverFraction,
        closeTo(1, .001),
      );
      final undoEnd = around(undo, start + const Duration(milliseconds: 800));
      expect(undoEnd[0].ringTransforms[7], isNotNull);
      expect(undoEnd[1].ringTransforms[7], isNull);
      expect(
        undo.inputLockedAt(start + const Duration(milliseconds: 800)),
        isFalse,
      );

      final deselect = RainbowRingsTimeline(seed: 204);
      deselect.startAction(
        at: start,
        action: action(
          RainbowRingsActionKind.deselect,
          source: const RainbowRingsPosition.hover(1),
          destination: const RainbowRingsPosition(peg: 1, slot: 0),
        ),
      );
      final deselectStart = around(deselect, start);
      expect(deselectStart[0].ringTransforms[7], isNull);
      expect(deselectStart[1].ringTransforms[7]!.hoverFraction, 1);
      expect(deselectStart[2].ringTransforms[7]!.hoverFraction, lessThan(1));
      final deselectEnd = around(
        deselect,
        start + const Duration(milliseconds: 300),
      );
      expect(deselectEnd[0].ringTransforms[7], isNotNull);
      expect(deselectEnd[1].ringTransforms[7], isNull);
      expect(deselectEnd[2].ringTransforms[7], isNull);
    });

    test('settle, staggered press, jiggle, and shake pin all keyframes', () {
      const start = Duration(milliseconds: 100);
      final landing = RainbowRingsTimeline(seed: 205);
      landing.startLanding(at: start, ring: ring, lowerRingIds: const [2, 3]);
      final landingStart = around(landing, start);
      expect(
        landingStart[0].ringTransforms[7]!.kind,
        RainbowRingsRingEffectKind.breathe,
      );
      expect(landingStart[1].ringTransforms[7]!.scaleX, 1.4);
      const settleFrames = [
        (184, .84, 1.24, -12.0, -4.0),
        (368, 1.16, .86, 0.0, 3.0),
        (552, .93, 1.09, -4.0, -2.0),
        (736, 1.06, .95, 0.0, 1.0),
        (920, .98, 1.02, 0.0, 0.0),
      ];
      for (final (elapsedMs, scaleX, scaleY, y, degrees) in settleFrames) {
        final samples = around(
          landing,
          start + Duration(milliseconds: elapsedMs),
        );
        final at = samples[1].ringTransforms[7]!;
        expect(at.scaleX, closeTo(scaleX, .001));
        expect(at.scaleY, closeTo(scaleY, .001));
        expect(at.offsetY, closeTo(y, .001));
        expect(at.rotation, closeTo(degrees * math.pi / 180, .001));
        for (final neighbor in [samples[0], samples[2]]) {
          expect(neighbor.ringTransforms[7]!.scaleX, closeTo(scaleX, .01));
          expect(neighbor.ringTransforms[7]!.offsetY, closeTo(y, .02));
        }
      }
      final settleEnd = around(
        landing,
        start + const Duration(milliseconds: 1150),
      );
      expect(
        settleEnd[0].ringTransforms[7]!.kind,
        RainbowRingsRingEffectKind.landing,
      );
      expect(
        settleEnd[1].ringTransforms[7]!.kind,
        RainbowRingsRingEffectKind.breathe,
      );

      const pressFrames = [
        (175, 1.14, .74),
        (385, .95, 1.08),
        (560, 1.02, .99),
      ];
      for (final (elapsedMs, scaleX, scaleY) in pressFrames) {
        final samples = around(
          landing,
          start + Duration(milliseconds: elapsedMs),
        );
        final at = samples[1].ringTransforms[3]!;
        expect(at.scaleX, closeTo(scaleX, .001));
        expect(at.scaleY, closeTo(scaleY, .001));
        expect(samples[0].ringTransforms[3]!.scaleX, closeTo(scaleX, .01));
        expect(samples[2].ringTransforms[3]!.scaleX, closeTo(scaleX, .01));
      }
      final stagger = around(landing, start + const Duration(milliseconds: 70));
      expect(stagger[0].ringTransforms[2], isNull);
      expect(stagger[1].ringTransforms[2]!.scaleX, 1);
      expect(stagger[2].ringTransforms[2], isNotNull);
      final pressEnd = around(
        landing,
        start + const Duration(milliseconds: 700),
      );
      expect(pressEnd[0].ringTransforms[3], isNotNull);
      expect(pressEnd[1].ringTransforms[3], isNull);

      const jiggleFrames = [(110000, 3.0), (247500, -2.5), (385000, 1.0)];
      for (final (elapsedUs, degrees) in jiggleFrames) {
        final samples = around(
          landing,
          start + Duration(microseconds: elapsedUs),
        );
        expect(
          samples[1].pegEffects[1]!.rotation,
          closeTo(degrees * math.pi / 180, .001),
        );
        expect(
          samples[0].pegEffects[1]!.rotation,
          closeTo(degrees * math.pi / 180, .001),
        );
        expect(
          samples[2].pegEffects[1]!.rotation,
          closeTo(degrees * math.pi / 180, .001),
        );
      }
      final jiggleEnd = around(
        landing,
        start + const Duration(milliseconds: 550),
      );
      expect(jiggleEnd[0].pegEffects[1], isNotNull);
      expect(jiggleEnd[1].pegEffects[1], isNull);

      final shake = RainbowRingsTimeline(seed: 206);
      shake.startAction(
        at: start,
        action: action(
          RainbowRingsActionKind.invalid,
          destination: const RainbowRingsPosition(peg: 2, slot: 0),
        ),
      );
      for (final (elapsedMs, x) in const [(75, -5.0), (225, 5.0)]) {
        final samples = around(
          shake,
          start + Duration(milliseconds: elapsedMs),
        );
        for (final frame in samples) {
          expect(frame.pegEffects[2]!.offsetX, closeTo(x, .001));
        }
      }
      final shakeEnd = around(shake, start + const Duration(milliseconds: 300));
      expect(shakeEnd[0].pegEffects[2], isNotNull);
      expect(shakeEnd[1].pegEffects[2], isNull);
      expect(shakeEnd[2].pegEffects[2], isNull);
    });

    test('hint, completed jump, sparkle, and toast pin all boundaries', () {
      const start = Duration(milliseconds: 100);
      final hint = RainbowRingsTimeline(seed: 207);
      hint.startHint(at: start, sourcePeg: 0, destinationPeg: 2);
      final hintStart = around(hint, start);
      expect(hintStart[0].pegEffects, isEmpty);
      expect(hintStart[1].pegEffects[0]!.glow, 0);
      expect(hintStart[2].pegEffects[0]!.glow, greaterThan(0));
      for (final (elapsedMs, glow) in const [
        (250, 1.0),
        (500, 0.0),
        (750, 1.0),
        (1000, 0.0),
        (1250, 1.0),
        (1500, 0.0),
      ]) {
        final samples = around(hint, start + Duration(milliseconds: elapsedMs));
        for (final frame in samples) {
          expect(frame.pegEffects[0]!.glow, closeTo(glow, .001));
          expect(frame.pegEffects[2]!.glow, closeTo(glow, .001));
        }
      }
      final hintEnd = around(hint, start + const Duration(milliseconds: 1600));
      expect(hintEnd[0].pegEffects, isNotEmpty);
      expect(hintEnd[1].pegEffects, isEmpty);
      expect(hintEnd[2].pegEffects, isEmpty);

      const bottom = RainbowRingsRingPlacement(
        ringId: 1,
        position: RainbowRingsPosition(peg: 2, slot: 0),
      );
      const top = RainbowRingsRingPlacement(
        ringId: 2,
        position: RainbowRingsPosition(peg: 2, slot: 1),
      );
      final completed = RainbowRingsTimeline(seed: 208);
      completed.startCompletedPeg(
        at: start,
        peg: 2,
        rings: const [top, bottom],
      );
      final jumpStart = around(completed, start);
      expect(
        jumpStart[0].ringTransforms[1]!.kind,
        RainbowRingsRingEffectKind.breathe,
      );
      expect(jumpStart[1].ringTransforms[1]!.offsetY, 0);
      expect(jumpStart[2].ringTransforms[1]!.offsetY, lessThan(0));
      final topStart = around(
        completed,
        start + const Duration(milliseconds: 50),
      );
      expect(
        topStart[0].ringTransforms[2]!.kind,
        RainbowRingsRingEffectKind.breathe,
      );
      expect(
        topStart[1].ringTransforms[2]!.kind,
        RainbowRingsRingEffectKind.completedJump,
      );
      for (final (elapsedMs, ringId) in const [(220, 1), (270, 2)]) {
        final samples = around(
          completed,
          start + Duration(milliseconds: elapsedMs),
        );
        for (final frame in samples) {
          expect(frame.ringTransforms[ringId]!.offsetY, closeTo(-14, .001));
        }
      }
      final bottomEnd = around(
        completed,
        start + const Duration(milliseconds: 550),
      );
      expect(
        bottomEnd[0].ringTransforms[1]!.kind,
        RainbowRingsRingEffectKind.completedJump,
      );
      expect(
        bottomEnd[1].ringTransforms[1]!.kind,
        RainbowRingsRingEffectKind.breathe,
      );
      final topEnd = around(
        completed,
        start + const Duration(milliseconds: 600),
      );
      expect(
        topEnd[0].ringTransforms[2]!.kind,
        RainbowRingsRingEffectKind.completedJump,
      );
      expect(
        topEnd[1].ringTransforms[2]!.kind,
        RainbowRingsRingEffectKind.breathe,
      );

      final sparkleStart = around(completed, start);
      expect(
        sparkleStart[0].sparkles,
        everyElement(
          predicate<RainbowParticle>((particle) => particle.opacity == 0),
        ),
      );
      expect(
        sparkleStart[1].sparkles,
        everyElement(
          predicate<RainbowParticle>(
            (particle) =>
                particle.opacity == 1 &&
                particle.scale == 1 &&
                particle.rotation == 0,
          ),
        ),
      );
      final sparkleMiddle = around(
        completed,
        start + const Duration(milliseconds: 450),
      );
      for (final frame in sparkleMiddle) {
        expect(
          frame.sparkles,
          everyElement(
            predicate<RainbowParticle>(
              (particle) =>
                  (particle.opacity - .5).abs() < .001 &&
                  (particle.scale - .6).abs() < .001 &&
                  (particle.rotation - math.pi / 2).abs() < .001,
            ),
          ),
        );
      }
      final sparkleEnd = around(
        completed,
        start + const Duration(milliseconds: 900),
      );
      expect(sparkleEnd[0].sparkles, hasLength(12));
      expect(sparkleEnd[1].sparkles, isEmpty);
      expect(sparkleEnd[2].sparkles, isEmpty);

      final toastStart = around(completed, start);
      expect(toastStart[0].toast, isNull);
      expect(toastStart[1].toastOpacity, 1);
      expect(toastStart[1].toastOffsetY, 0);
      expect(toastStart[1].toastScale, .6);
      final toastPop = around(
        completed,
        start + const Duration(milliseconds: 200),
      );
      for (final frame in toastPop) {
        expect(frame.toastOffsetY, closeTo(-10, .001));
        expect(frame.toastScale, closeTo(1.15, .001));
      }
      final toastEnd = around(
        completed,
        start + const Duration(milliseconds: 1000),
      );
      expect(toastEnd[0].toast, isNotNull);
      expect(toastEnd[1].toast, isNull);
      expect(toastEnd[2].toast, isNull);
    });

    test('breathing and bokeh wrap exactly at deterministic boundaries', () {
      final timeline = RainbowRingsTimeline(seed: 209)
        ..rememberRings(const [ring]);
      final phase = timeline.breathingPhaseMilliseconds(ring.ringId);
      final wrapMs = (3600 - phase) % 3600 + 3600;
      final breatheWrap = around(
        timeline,
        Duration(milliseconds: wrapMs),
        step: const Duration(milliseconds: 1),
      );
      for (final frame in breatheWrap) {
        expect(frame.ringTransforms[7]!.scaleX, closeTo(1, .001));
        expect(frame.ringTransforms[7]!.scaleY, closeTo(1, .001));
      }
      final breathePeak = around(
        timeline,
        Duration(milliseconds: wrapMs + 1800),
        step: const Duration(milliseconds: 1),
      );
      for (final frame in breathePeak) {
        expect(frame.ringTransforms[7]!.scaleX, closeTo(1.025, .001));
        expect(frame.ringTransforms[7]!.scaleY, closeTo(.965, .001));
      }

      final initial = timeline.sample(zero).bokeh;
      expect(initial, hasLength(14));
      for (final particle in initial) {
        expect(particle.x, inInclusiveRange(.03, .97));
        expect(particle.size, inInclusiveRange(14, 48));
        expect(particle.opacity, inInclusiveRange(0, .24));
        expect(
          particle.duration.inMilliseconds,
          inInclusiveRange(14000, 30000),
        );
      }
      final particle = initial.first;
      var particleWrapMs =
          particle.duration.inMilliseconds -
          particle.delay.inMilliseconds % particle.duration.inMilliseconds;
      if (particleWrapMs < 2) {
        particleWrapMs += particle.duration.inMilliseconds;
      }
      final bokehWrap = around(
        timeline,
        Duration(milliseconds: particleWrapMs),
        step: const Duration(milliseconds: 1),
      );
      final before = bokehWrap[0].bokeh.first;
      final at = bokehWrap[1].bokeh.first;
      final after = bokehWrap[2].bokeh.first;
      expect(before.y, closeTo(-.18, .001));
      expect(at.y, closeTo(1.12, .001));
      expect(after.y, closeTo(1.12, .001));
      expect(at.opacity, 0);
      expect(before.opacity, closeTo(0, .001));
      expect(after.opacity, closeTo(0, .001));
    });

    test('confetti, modal, and stars pin delay/start/end boundaries', () {
      const start = Duration(milliseconds: 100);
      final timeline = RainbowRingsTimeline(seed: 210);
      timeline.startWin(at: start, colorCount: 5);
      final initial = timeline.sample(start);
      expect(initial.confetti, hasLength(80));
      for (final particle in initial.confetti) {
        expect(particle.delay.inMilliseconds, inInclusiveRange(0, 500));
        expect(particle.duration.inMilliseconds, inInclusiveRange(1600, 3400));
        expect(particle.colorIndex, inInclusiveRange(0, 4));
        expect(particle.size, inInclusiveRange(5, 12));
      }

      final particle = initial.confetti.first;
      final particleStart = around(timeline, start + particle.delay);
      final beforeStart = particleStart[0].confetti.firstWhere(
        (candidate) => candidate.id == particle.id,
      );
      final atStart = particleStart[1].confetti.firstWhere(
        (candidate) => candidate.id == particle.id,
      );
      final afterStart = particleStart[2].confetti.firstWhere(
        (candidate) => candidate.id == particle.id,
      );
      expect(beforeStart.opacity, 0);
      expect(atStart.opacity, 1);
      expect(afterStart.opacity, 1);

      final particleEnd = around(
        timeline,
        start + particle.delay + particle.duration,
      );
      final beforeEnd = particleEnd[0].confetti.firstWhere(
        (candidate) => candidate.id == particle.id,
      );
      expect(beforeEnd.y, closeTo(1.1, .001));
      expect(
        beforeEnd.rotation - particle.rotation,
        closeTo(4 * math.pi, .001),
      );
      expect(
        particleEnd[1].confetti.where(
          (candidate) => candidate.id == particle.id,
        ),
        isEmpty,
      );
      expect(
        particleEnd[2].confetti.where(
          (candidate) => candidate.id == particle.id,
        ),
        isEmpty,
      );

      final modalStart = around(
        timeline,
        start + const Duration(milliseconds: 800),
      );
      expect(modalStart[0].modalOpacity, 0);
      expect(modalStart[0].modalScale, .4);
      expect(modalStart[1].modalOpacity, 0);
      expect(modalStart[1].modalScale, .4);
      expect(modalStart[2].modalOpacity, greaterThan(0));
      final modalEnd = around(
        timeline,
        start + const Duration(milliseconds: 1350),
      );
      expect(modalEnd[0].modalOpacity, lessThan(1));
      expect(modalEnd[1].modalOpacity, 1);
      expect(modalEnd[1].modalScale, 1);
      expect(modalEnd[2].modalOpacity, 1);

      for (var index = 0; index < 3; index++) {
        final delay = [1100, 1350, 1600][index];
        final starStart = around(
          timeline,
          start + Duration(milliseconds: delay),
        );
        expect(starStart[0].starProgress[index], 0);
        expect(starStart[1].starProgress[index], 0);
        expect(starStart[2].starProgress[index], greaterThan(0));
        final starEnd = around(
          timeline,
          start + Duration(milliseconds: delay + 600),
        );
        expect(starEnd[0].starProgress[index], lessThan(1));
        expect(starEnd[1].starProgress[index], 1);
        expect(starEnd[2].starProgress[index], 1);
      }
    });
  });

  group('win, supersession, reset, and reduced motion', () {
    test('win emits 80 bounded confetti pieces and delayed modal/stars', () {
      final first = RainbowRingsTimeline(seed: 11);
      final second = RainbowRingsTimeline(seed: 11);
      first.startWin(at: zero, colorCount: 5);
      second.startWin(at: zero, colorCount: 5);

      final initial = first.sample(zero);
      expect(initial.confetti, hasLength(80));
      expect(initial.confetti, second.sample(zero).confetti);
      for (final particle in initial.confetti) {
        expect(particle.delay.inMilliseconds, inInclusiveRange(0, 500));
        expect(particle.duration.inMilliseconds, inInclusiveRange(1600, 3400));
      }
      expect(first.sample(const Duration(milliseconds: 799)).modalOpacity, 0);
      final modalStart = first.sample(const Duration(milliseconds: 800));
      expect(modalStart.modalOpacity, 0);
      expect(modalStart.modalScale, closeTo(.4, .001));
      final modalMiddle = first.sample(const Duration(milliseconds: 1075));
      expect(modalMiddle.modalOpacity, closeTo(.5, .001));
      expect(modalMiddle.modalScale, closeTo(1.01624, .001));
      expect(
        first.sample(const Duration(milliseconds: 1350)).modalOpacity,
        closeTo(1, .001),
      );
      expect(
        first.sample(const Duration(milliseconds: 1099)).starProgress[0],
        0,
      );
      expect(
        first.sample(const Duration(milliseconds: 1400)).starProgress[0],
        closeTo(.5, .001),
      );
      expect(
        first.sample(const Duration(milliseconds: 1650)).starProgress[1],
        closeTo(.5, .001),
      );
      expect(
        first.sample(const Duration(milliseconds: 1900)).starProgress[2],
        closeTo(.5, .001),
      );
      expect(
        first.sample(const Duration(milliseconds: 1700)).starProgress[0],
        1,
      );
      expect(
        first.sample(const Duration(milliseconds: 1950)).starProgress[1],
        1,
      );
      expect(
        first.sample(const Duration(milliseconds: 2200)).starProgress[2],
        1,
      );
    });

    test(
      'new same-target effects supersede old ones and cleanup stays bounded',
      () {
        final timeline = RainbowRingsTimeline(seed: 12);
        for (var index = 0; index < 200; index++) {
          final at = Duration(milliseconds: index * 10);
          timeline.startHint(at: at, sourcePeg: 0, destinationPeg: 1);
          timeline.startLanding(at: at, ring: ring, lowerRingIds: const []);
        }
        expect(timeline.debugEffectCount, lessThanOrEqualTo(8));
        final latest = timeline
            .sample(const Duration(milliseconds: 1990))
            .ringTransforms[7]!;
        final latestToken = latest.token;
        expect(latestToken, greaterThan(1));
        timeline.sample(const Duration(seconds: 10));
        expect(timeline.debugEffectCount, lessThanOrEqualTo(3));
        final rewound = timeline
            .sample(const Duration(milliseconds: 1990))
            .ringTransforms[7]!;
        expect(rewound.token, latest.token);
        expect(rewound.kind, latest.kind);
        expect(rewound.scaleX, latest.scaleX);
        expect(rewound.scaleY, latest.scaleY);
      },
    );

    test('new ring effects supersede only matching targets', () {
      const lowerRing = RainbowRingsRingPlacement(
        ringId: 2,
        position: RainbowRingsPosition(peg: 1, slot: 0),
      );
      const unrelatedRing = RainbowRingsRingPlacement(
        ringId: 9,
        position: RainbowRingsPosition(peg: 3, slot: 0),
      );
      final timeline = RainbowRingsTimeline(seed: 120);
      timeline.startLanding(at: zero, ring: ring, lowerRingIds: const [2]);
      timeline.startLanding(
        at: zero,
        ring: unrelatedRing,
        lowerRingIds: const [],
      );
      timeline.startCompletedPeg(
        at: const Duration(milliseconds: 100),
        peg: 1,
        rings: const [lowerRing, ring],
      );

      final frame = timeline.sample(const Duration(milliseconds: 320));
      expect(
        frame.ringTransforms[2]!.kind,
        RainbowRingsRingEffectKind.completedJump,
      );
      expect(
        frame.ringTransforms[7]!.kind,
        RainbowRingsRingEffectKind.completedJump,
      );
      expect(frame.ringTransforms[9]!.kind, RainbowRingsRingEffectKind.landing);
    });

    test('revision is stable while real effect tokens propagate to frames', () {
      final timeline = RainbowRingsTimeline(seed: 121);
      final initialRevision = timeline.revision;
      final completedToken = timeline.startCompletedPeg(
        at: zero,
        peg: 1,
        rings: const [ring],
      );
      final first = timeline.sample(zero);
      expect(first.revision, greaterThan(initialRevision));
      expect(first.revision, timeline.revision);
      expect(first.pegEffects[1]!.token, completedToken);
      expect(
        timeline.sample(const Duration(milliseconds: 100)).revision,
        first.revision,
      );

      final hintToken = timeline.startHint(
        at: const Duration(milliseconds: 100),
        sourcePeg: 1,
        destinationPeg: 2,
      );
      final hinted = timeline.sample(const Duration(milliseconds: 350));
      expect(hinted.revision, greaterThan(first.revision));
      expect(hinted.pegEffects[1]!.token, hintToken);
      expect(hinted.pegEffects[2]!.token, hintToken);
    });

    test(
      'completed peg reconciliation seeds markers and clears stale effects',
      () {
        final timeline = RainbowRingsTimeline(seed: 122);
        timeline.setCompletedPegs(const {2});
        var frame = timeline.sample(zero);
        expect(frame.completedPegs, {2});
        expect(frame.sparkles, isEmpty);
        expect(frame.toast, isNull);

        timeline.startCompletedPeg(at: zero, peg: 1, rings: const [ring]);
        frame = timeline.sample(const Duration(milliseconds: 100));
        expect(frame.completedPegs, {1, 2});
        expect(frame.sparkles, hasLength(12));

        timeline.setCompletedPegs(const {2});
        frame = timeline.sample(const Duration(milliseconds: 100));
        expect(frame.completedPegs, {2});
        expect(frame.sparkles, isEmpty);
        expect(frame.toast, isNull);
      },
    );

    test(
      'reset invalidates tokens, seed, effects, and known completed pegs',
      () {
        final timeline = RainbowRingsTimeline(seed: 13);
        final token = timeline.startHint(
          at: zero,
          sourcePeg: 1,
          destinationPeg: 2,
        );
        timeline.startCompletedPeg(at: zero, peg: 1, rings: const [ring]);
        final generation = timeline.generation;
        timeline.reset(seed: 99);
        expect(timeline.generation, generation + 1);
        expect(timeline.isTokenCurrent(token), isFalse);
        final frame = timeline.sample(zero);
        expect(frame.pegEffects, isEmpty);
        expect(frame.completedPegs, isEmpty);
        expect(frame.bokeh, hasLength(14));
      },
    );

    test('generation tokens never perturb seeded visual output', () {
      RainbowRingsFrame completedFrame(RainbowRingsTimeline timeline) {
        timeline.startCompletedPeg(at: zero, peg: 1, rings: const [ring]);
        return timeline.sample(const Duration(milliseconds: 450));
      }

      final directCompletion = completedFrame(RainbowRingsTimeline(seed: 21));
      final reorderedCompletionTimeline = RainbowRingsTimeline(seed: 21)
        ..startHint(at: zero, sourcePeg: 0, destinationPeg: 2);
      final reorderedCompletion = completedFrame(reorderedCompletionTimeline);
      final resetCompletionTimeline = RainbowRingsTimeline(seed: -1)
        ..reset(seed: 21);
      final resetCompletion = completedFrame(resetCompletionTimeline);
      expect(reorderedCompletion.toast, directCompletion.toast);
      expect(reorderedCompletion.sparkles, directCompletion.sparkles);
      expect(resetCompletion.toast, directCompletion.toast);
      expect(resetCompletion.sparkles, directCompletion.sparkles);

      RainbowRingsFrame winFrame(RainbowRingsTimeline timeline) {
        timeline.startWin(at: zero, colorCount: 5);
        return timeline.sample(zero);
      }

      final directWin = winFrame(RainbowRingsTimeline(seed: 22));
      final reorderedWinTimeline = RainbowRingsTimeline(seed: 22)
        ..startHint(at: zero, sourcePeg: 0, destinationPeg: 2);
      final reorderedWin = winFrame(reorderedWinTimeline);
      final resetWinTimeline = RainbowRingsTimeline(seed: -1)..reset(seed: 22);
      final resetWin = winFrame(resetWinTimeline);
      expect(reorderedWin.confetti, directWin.confetti);
      expect(resetWin.confetti, directWin.confetti);

      final freshBokeh = RainbowRingsTimeline(seed: 23).sample(zero).bokeh;
      final resetBokehTimeline = RainbowRingsTimeline(seed: -1)
        ..reset(seed: 23);
      expect(resetBokehTimeline.sample(zero).bokeh, freshBokeh);
    });

    test('active sparkle and confetti sampling performs no random work', () {
      final timeline = RainbowRingsTimeline(seed: 25);
      timeline.startCompletedPeg(at: zero, peg: 1, rings: const [ring]);
      timeline.startWin(at: zero, colorCount: 5);
      final drawsAfterRegistration = timeline.debugRandomDraws;

      for (final at in const [
        Duration.zero,
        Duration(milliseconds: 250),
        Duration(milliseconds: 450),
        Duration(milliseconds: 899),
        Duration(milliseconds: 1700),
        Duration(seconds: 4),
      ]) {
        timeline.sample(at);
        expect(timeline.debugRandomDraws, drawsAfterRegistration);
      }
    });

    test('reduced motion is immediate, unlocked, and particle free', () {
      final timeline = RainbowRingsTimeline(seed: 14, reducedMotion: true);
      timeline.startIntro(at: zero, rings: const [ring]);
      timeline.startAction(
        at: zero,
        action: action(
          RainbowRingsActionKind.move,
          source: const RainbowRingsPosition.hover(1),
          destination: const RainbowRingsPosition(peg: 2, slot: 0),
        ),
      );
      timeline.startCompletedPeg(at: zero, peg: 2, rings: const [ring]);
      timeline.startWin(at: zero, colorCount: 4);
      final frame = timeline.sample(zero);
      expect(timeline.inputLockedAt(zero), isFalse);
      expect(frame.ringTransforms[7], isNull);
      expect(frame.bokeh, isEmpty);
      expect(frame.sparkles, isEmpty);
      expect(frame.confetti, isEmpty);
      expect(frame.completedPegs, contains(2));
      expect(frame.modalOpacity, 1);
      expect(frame.modalScale, 1);
      expect(frame.starProgress, everyElement(1));
    });

    test('toggling reduced motion collapses active effects permanently', () {
      const landingRing = RainbowRingsRingPlacement(
        ringId: 8,
        position: RainbowRingsPosition(peg: 2, slot: 2),
      );
      const completionRing = RainbowRingsRingPlacement(
        ringId: 10,
        position: RainbowRingsPosition(peg: 4, slot: 0),
      );
      final timeline = RainbowRingsTimeline(seed: 24);
      final introToken = timeline.startIntro(at: zero, rings: const [ring]);
      timeline.startAction(
        at: zero,
        action: action(
          RainbowRingsActionKind.select,
          source: ring.position,
          destination: const RainbowRingsPosition.hover(1),
        ),
      );
      timeline.startLanding(
        at: zero,
        ring: landingRing,
        lowerRingIds: const [9],
      );
      timeline.startAction(
        at: zero,
        action: action(
          RainbowRingsActionKind.invalid,
          destination: const RainbowRingsPosition(peg: 3, slot: 0),
        ),
      );
      timeline.startHint(at: zero, sourcePeg: 0, destinationPeg: 5);
      timeline.startCompletedPeg(
        at: zero,
        peg: 4,
        rings: const [completionRing],
      );
      timeline.startWin(at: zero, colorCount: 4);
      expect(timeline.debugEffectCount, 9);

      timeline.reducedMotion = true;
      final reduced = timeline.sample(const Duration(milliseconds: 100));
      expect(timeline.isTokenCurrent(introToken), isFalse);
      expect(
        timeline.inputLockedAt(const Duration(milliseconds: 100)),
        isFalse,
      );
      expect(reduced.ringTransforms, isEmpty);
      expect(reduced.bokeh, isEmpty);
      expect(reduced.sparkles, isEmpty);
      expect(reduced.confetti, isEmpty);
      expect(reduced.toast, isNull);
      expect(reduced.completedPegs, contains(4));
      expect(reduced.modalOpacity, 1);
      expect(reduced.starProgress, everyElement(1));
      expect(timeline.debugEffectCount, 0);

      timeline.reducedMotion = false;
      final restored = timeline.sample(const Duration(milliseconds: 101));
      expect(
        restored.ringTransforms.values,
        everyElement(
          predicate<RainbowRingTransform>(
            (transform) => transform.kind == RainbowRingsRingEffectKind.breathe,
          ),
        ),
      );
      expect(restored.sparkles, isEmpty);
      expect(restored.confetti, isEmpty);
      expect(restored.toast, isNull);
      expect(restored.modalOpacity, 1);
      expect(timeline.debugEffectCount, 0);
    });
  });
}
