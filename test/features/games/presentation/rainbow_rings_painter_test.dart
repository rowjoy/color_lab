import 'package:color_lab/core/theme/app_colors.dart';
import 'package:color_lab/features/games/domain/rainbow_rings_game.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_animation.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RainbowRingsGeometry', () {
    test('scales safely across short positive stage heights', () {
      for (final width in [360.0, 520.0]) {
        for (final height in [48.0, 60.0, 72.0, 96.0, 120.0, 420.0]) {
          for (final capacity in [4, 8]) {
            for (final pegCount in [5, 8]) {
              final size = Size(width, height);
              late RainbowRingsGeometry geometry;

              expect(
                () => geometry = RainbowRingsGeometry.layout(
                  size,
                  pegCount: pegCount,
                  capacity: capacity,
                ),
                returnsNormally,
                reason:
                    'width=$width height=$height capacity=$capacity '
                    'pegCount=$pegCount',
              );

              _expectFiniteNonInvertedRect(geometry.stageRect);
              _expectFiniteNonInvertedRect(geometry.baseRect);
              expect(geometry.ringSize.width.isFinite, isTrue);
              expect(geometry.ringSize.height.isFinite, isTrue);
              expect(geometry.ringSize.width, greaterThan(0));
              expect(geometry.ringSize.height, greaterThan(0));
              expect(geometry.ringStep.isFinite, isTrue);
              expect(geometry.ringStep, greaterThan(0));
              expect(geometry.hoverY.isFinite, isTrue);
              expect(
                geometry.stageRect.contains(geometry.baseRect.topLeft),
                isTrue,
              );
              expect(
                geometry.stageRect.contains(geometry.baseRect.bottomRight),
                isTrue,
              );

              for (var peg = 0; peg < pegCount; peg++) {
                final hover = geometry.positionFor(
                  RainbowRingsPosition.hover(peg),
                );
                final top = geometry.positionFor(
                  RainbowRingsPosition(peg: peg, slot: capacity - 1),
                );
                final bottom = geometry.positionFor(
                  RainbowRingsPosition(peg: peg, slot: 0),
                );
                expect(hover.dx.isFinite && hover.dy.isFinite, isTrue);
                expect(top.dx.isFinite && top.dy.isFinite, isTrue);
                expect(bottom.dx.isFinite && bottom.dy.isFinite, isTrue);
                expect(hover.dy, lessThan(top.dy));
                expect(top.dy, lessThan(bottom.dy));
                _expectFiniteNonInvertedRect(geometry.ringRectAt(hover));
                _expectFiniteNonInvertedRect(geometry.ringRectAt(top));
                _expectFiniteNonInvertedRect(geometry.ringRectAt(bottom));
              }

              final clock = ValueNotifier(Duration.zero);
              final commands = _painter(
                timeline: RainbowRingsTimeline(seed: 31),
                clock: clock,
                stacks: List.generate(
                  pegCount,
                  (peg) => peg == 0
                      ? List.generate(capacity, (ringId) => ringId)
                      : <int>[],
                ),
                ringColors: List.generate(capacity, (ringId) => ringId % 6),
                capacity: capacity,
              ).debugPaintCommands(size);
              for (final command in commands) {
                final bounds = command.bounds;
                if (bounds != null) _expectFiniteNonInvertedRect(bounds);
                final center = command.center;
                if (center != null) {
                  expect(center.dx.isFinite && center.dy.isFinite, isTrue);
                }
              }
              clock.dispose();
            }
          }
        }
      }
    });

    test('lays out every generator-v1 capacity at 360 and 520 dp', () {
      for (final width in [360.0, 520.0]) {
        for (var capacity = 4; capacity <= 8; capacity++) {
          for (var pegCount = 5; pegCount <= 8; pegCount++) {
            final size = Size(width, 420);
            final geometry = RainbowRingsGeometry.layout(
              size,
              pegCount: pegCount,
              capacity: capacity,
            );

            expect(geometry.stageRect.left, greaterThanOrEqualTo(0));
            expect(geometry.stageRect.right, lessThanOrEqualTo(size.width));
            expect(geometry.baseRect.bottom, lessThan(size.height));
            expect(geometry.ringSize.width, greaterThan(0));
            expect(geometry.ringSize.height, greaterThan(0));

            for (var peg = 0; peg < pegCount; peg++) {
              final hover = geometry.positionFor(
                RainbowRingsPosition.hover(peg),
              );
              final top = geometry.positionFor(
                RainbowRingsPosition(peg: peg, slot: capacity - 1),
              );
              final bottom = geometry.positionFor(
                RainbowRingsPosition(peg: peg, slot: 0),
              );
              expect(hover.dy, lessThan(top.dy));
              expect(top.dy, lessThan(bottom.dy));
              expect(geometry.ringRectAt(hover).inflate(0.01).isEmpty, isFalse);
              expect(hover.dx, inInclusiveRange(0, size.width));
              expect(bottom.dx, inInclusiveRange(0, size.width));

              final centerX = size.width / 2;
              expect(
                (hover.dx - centerX).abs(),
                lessThanOrEqualTo((bottom.dx - centerX).abs() + 0.001),
              );
            }
          }
        }
      }
    });

    test('uses contiguous non-overlapping hit regions with defined edges', () {
      final geometry = RainbowRingsGeometry.layout(
        const Size(360, 420),
        pegCount: 8,
        capacity: 8,
      );

      for (var peg = 0; peg < geometry.pegCount - 1; peg++) {
        final current = geometry.pegHitRect(peg);
        final next = geometry.pegHitRect(peg + 1);
        expect(current.overlaps(next), isFalse);
        expect(current.right, closeTo(next.left, 0.0001));
        expect(
          geometry.hitTest(Offset(current.right, current.center.dy)),
          peg + 1,
        );
      }

      expect(geometry.hitTest(Offset.zero), 0);
      expect(geometry.hitTest(const Offset(360, 420)), 7);
      expect(geometry.hitTest(const Offset(-0.01, 200)), isNull);
      expect(geometry.hitTest(const Offset(360.01, 200)), isNull);
      expect(geometry.hitTest(const Offset(180, -0.01)), isNull);
      expect(geometry.hitTest(const Offset(180, 420.01)), isNull);
    });

    test('keeps resting rings bottom anchored when stage height changes', () {
      final short = RainbowRingsGeometry.layout(
        const Size(360, 360),
        pegCount: 6,
        capacity: 6,
      );
      final tall = RainbowRingsGeometry.layout(
        const Size(360, 520),
        pegCount: 6,
        capacity: 6,
      );
      final shortBottom = short.positionFor(
        const RainbowRingsPosition(peg: 0, slot: 0),
      );
      final tallBottom = tall.positionFor(
        const RainbowRingsPosition(peg: 0, slot: 0),
      );

      expect(360 - shortBottom.dy, closeTo(520 - tallBottom.dy, 0.0001));
      expect(short.ringSize, tall.ringSize);
    });
  });

  group('RainbowRingsPainter', () {
    test('hides the mutated destination ring and draws one travel overlay', () {
      final timeline = RainbowRingsTimeline(seed: 8);
      timeline.startAction(
        at: Duration.zero,
        action: const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.move,
          ringId: 1,
          source: RainbowRingsPosition.hover(0),
          destination: RainbowRingsPosition(peg: 2, slot: 1),
        ),
      );
      final clock = ValueNotifier(const Duration(milliseconds: 400));
      final painter = _painter(
        timeline: timeline,
        clock: clock,
        stacks: const [
          [0],
          [],
          [2, 1],
          [],
          [],
        ],
        ringColors: const [0, 1, 2],
      );

      final travelling = painter
          .debugPaintCommands(const Size(360, 420))
          .where((command) => command.ringId == 1)
          .toList();
      expect(
        travelling.where(
          (command) => command.layer == RainbowRingsPaintLayer.ring,
        ),
        isEmpty,
      );
      expect(
        travelling.where(
          (command) => command.layer == RainbowRingsPaintLayer.overlayRing,
        ),
        hasLength(1),
      );

      clock.value = const Duration(milliseconds: 600);
      final settled = painter
          .debugPaintCommands(const Size(360, 420))
          .where((command) => command.ringId == 1)
          .toList();
      expect(
        settled.where(
          (command) => command.layer == RainbowRingsPaintLayer.ring,
        ),
        hasLength(1),
      );
      expect(
        settled.where(
          (command) => command.layer == RainbowRingsPaintLayer.overlayRing,
        ),
        isEmpty,
      );
      clock.dispose();
    });

    test('multi-slot move and undo travel monotonically through geometry', () {
      for (final destinationSlot in [0, 3]) {
        final moveTimeline = RainbowRingsTimeline(seed: 9);
        moveTimeline.startAction(
          at: Duration.zero,
          action: RainbowRingsActionResult(
            kind: RainbowRingsActionKind.move,
            ringId: 1,
            source: const RainbowRingsPosition.hover(0),
            destination: RainbowRingsPosition(peg: 2, slot: destinationSlot),
          ),
        );
        final moveClock = ValueNotifier(Duration.zero);
        final destination = <int>[
          for (var slot = 0; slot < destinationSlot; slot++) slot + 2,
          1,
        ];
        final movePainter = _painter(
          timeline: moveTimeline,
          clock: moveClock,
          stacks: [
            const [0],
            const [],
            destination,
            const [],
            const [],
          ],
          ringColors: const [0, 1, 2, 2, 2],
        );
        final moveDropY = <double>[];
        for (final milliseconds in [260, 320, 400, 500, 599]) {
          moveClock.value = Duration(milliseconds: milliseconds);
          moveDropY.add(_overlayCenter(movePainter, 1).dy);
        }
        _expectMonotonic(moveDropY, increasing: true);
        moveClock.dispose();
      }

      for (final slots in [(0, 0), (3, 2)]) {
        final undoTimeline = RainbowRingsTimeline(seed: 9);
        undoTimeline.startAction(
          at: Duration.zero,
          action: RainbowRingsActionResult(
            kind: RainbowRingsActionKind.undo,
            ringId: 1,
            source: RainbowRingsPosition(peg: 2, slot: slots.$1),
            destination: RainbowRingsPosition(peg: 0, slot: slots.$2),
          ),
        );
        final undoClock = ValueNotifier(Duration.zero);
        final restored = <int>[
          for (var slot = 0; slot < slots.$2; slot++) slot + 2,
          1,
        ];
        final undoPainter = _painter(
          timeline: undoTimeline,
          clock: undoClock,
          stacks: [
            restored,
            const [],
            const [3, 4, 5],
            const [],
            const [],
          ],
          ringColors: const [0, 1, 0, 2, 2, 2],
        );
        final undoLiftY = <double>[];
        for (final milliseconds in [0, 20, 40, 60, 80]) {
          undoClock.value = Duration(milliseconds: milliseconds);
          undoLiftY.add(_overlayCenter(undoPainter, 1).dy);
        }
        _expectMonotonic(undoLiftY, increasing: false);
        final undoDropY = <double>[];
        for (final milliseconds in [460, 520, 600, 700, 799]) {
          undoClock.value = Duration(milliseconds: milliseconds);
          undoDropY.add(_overlayCenter(undoPainter, 1).dy);
        }
        _expectMonotonic(undoDropY, increasing: true);
        undoClock.dispose();
      }
    });

    test('slot-zero and upper-slot select/deselect paths stay directed', () {
      for (final slot in [0, 3]) {
        final stack = <int>[
          for (var lower = 0; lower < slot; lower++) lower + 2,
          1,
        ];
        final selectTimeline = RainbowRingsTimeline(seed: 11);
        selectTimeline.startAction(
          at: Duration.zero,
          action: RainbowRingsActionResult(
            kind: RainbowRingsActionKind.select,
            ringId: 1,
            source: RainbowRingsPosition(peg: 0, slot: slot),
            destination: const RainbowRingsPosition.hover(0),
          ),
        );
        final selectClock = ValueNotifier(Duration.zero);
        final selectPainter = _painter(
          timeline: selectTimeline,
          clock: selectClock,
          stacks: [stack, const [], const [], const [], const []],
          ringColors: const [0, 1, 2, 2, 2],
          selectedPeg: 0,
        );
        final selectLiftY = <double>[];
        for (final milliseconds in [0, 20, 40, 60, 80]) {
          selectClock.value = Duration(milliseconds: milliseconds);
          selectLiftY.add(_overlayCenter(selectPainter, 1).dy);
        }
        _expectMonotonic(selectLiftY, increasing: false);

        final deselectTimeline = RainbowRingsTimeline(seed: 11);
        deselectTimeline.startAction(
          at: Duration.zero,
          action: RainbowRingsActionResult(
            kind: RainbowRingsActionKind.deselect,
            ringId: 1,
            source: const RainbowRingsPosition.hover(0),
            destination: RainbowRingsPosition(peg: 0, slot: slot),
          ),
        );
        final deselectClock = ValueNotifier(Duration.zero);
        final deselectPainter = _painter(
          timeline: deselectTimeline,
          clock: deselectClock,
          stacks: [stack, const [], const [], const [], const []],
          ringColors: const [0, 1, 2, 2, 2],
        );
        final deselectDropY = <double>[];
        for (final milliseconds in [0, 60, 120, 180, 240, 299]) {
          deselectClock.value = Duration(milliseconds: milliseconds);
          deselectDropY.add(_overlayCenter(deselectPainter, 1).dy);
        }
        _expectMonotonic(deselectDropY, increasing: true);

        selectClock.dispose();
        deselectClock.dispose();
      }
    });

    test('active travel reprojects the same logical progress after resize', () {
      final timeline = RainbowRingsTimeline(seed: 13);
      timeline.startAction(
        at: Duration.zero,
        action: const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.select,
          ringId: 1,
          source: RainbowRingsPosition(peg: 0, slot: 3),
          destination: RainbowRingsPosition.hover(0),
        ),
      );
      final clock = ValueNotifier(const Duration(milliseconds: 80));
      final painter = _painter(
        timeline: timeline,
        clock: clock,
        stacks: const [
          [2, 3, 4, 1],
          [],
          [],
          [],
          [],
        ],
        ringColors: const [0, 1, 2, 2, 2],
        selectedPeg: 0,
      );
      const compactSize = Size(360, 420);
      const wideSize = Size(520, 520);
      final compactCenter = _overlayCenter(painter, 1, size: compactSize);
      final wideCenter = _overlayCenter(painter, 1, size: wideSize);
      final compactProgress = _pathProgress(
        geometry: RainbowRingsGeometry.layout(
          compactSize,
          pegCount: 5,
          capacity: 4,
        ),
        point: compactCenter,
        peg: 0,
        slot: 3,
      );
      final wideProgress = _pathProgress(
        geometry: RainbowRingsGeometry.layout(
          wideSize,
          pegCount: 5,
          capacity: 4,
        ),
        point: wideCenter,
        peg: 0,
        slot: 3,
      );

      expect(compactCenter, isNot(wideCenter));
      expect(compactProgress, closeTo(wideProgress, 0.0001));
      clock.dispose();
    });

    test('deep board, palette, theme, and effect changes repaint', () {
      final timeline = RainbowRingsTimeline(seed: 10);
      final clock = ValueNotifier(Duration.zero);
      final original = _painter(timeline: timeline, clock: clock);
      final equalCopy = _painter(
        timeline: timeline,
        clock: clock,
        stacks: original.stacks.map(List<int>.of).toList(),
        ringColors: List<int>.of(original.ringColors),
      );
      expect(equalCopy.shouldRepaint(original), isFalse);

      final changedStack = _painter(
        timeline: timeline,
        clock: clock,
        stacks: const [
          [0],
          [1, 2],
          [],
          [],
          [],
        ],
      );
      expect(changedStack.shouldRepaint(original), isTrue);

      final changedPalette = _painter(
        timeline: timeline,
        clock: clock,
        ringColors: const [1, 0, 2],
      );
      expect(changedPalette.shouldRepaint(original), isTrue);

      final changedTheme = _painter(
        timeline: timeline,
        clock: clock,
        colors: AppColors.dark,
      );
      expect(changedTheme.shouldRepaint(original), isTrue);

      timeline.startHint(at: Duration.zero, sourcePeg: 0, destinationPeg: 2);
      final changedEffect = _painter(timeline: timeline, clock: clock);
      expect(changedEffect.shouldRepaint(original), isTrue);
      clock.dispose();
    });

    test('forwards the clock as the CustomPainter repaint listenable', () {
      final clock = ValueNotifier(Duration.zero);
      final painter = _painter(
        timeline: RainbowRingsTimeline(seed: 12),
        clock: clock,
      );
      var repaintNotifications = 0;
      void listener() => repaintNotifications++;
      painter.addListener(listener);

      clock.value = const Duration(milliseconds: 1);

      expect(repaintNotifications, 1);
      painter.removeListener(listener);
      clock.dispose();
    });

    test('paints glass, bokeh, base, poles, rings, and persistent glows', () {
      final timeline = RainbowRingsTimeline(seed: 14);
      timeline.setCompletedPegs(const {0});
      timeline.rememberRings(const [
        RainbowRingsRingPlacement(
          ringId: 0,
          position: RainbowRingsPosition(peg: 0, slot: 0),
        ),
        RainbowRingsRingPlacement(
          ringId: 1,
          position: RainbowRingsPosition(peg: 0, slot: 1),
        ),
        RainbowRingsRingPlacement(
          ringId: 2,
          position: RainbowRingsPosition(peg: 0, slot: 2),
        ),
        RainbowRingsRingPlacement(
          ringId: 3,
          position: RainbowRingsPosition(peg: 0, slot: 3),
        ),
      ]);
      final clock = ValueNotifier(const Duration(milliseconds: 1800));
      final commands = _painter(
        timeline: timeline,
        clock: clock,
        stacks: const [
          [0, 1, 2, 3],
          [4],
          [],
          [],
          [],
        ],
        ringColors: const [0, 0, 0, 0, 1],
        selectedPeg: 1,
      ).debugPaintCommands(const Size(360, 420));

      expect(_layers(commands), contains(RainbowRingsPaintLayer.stageGlass));
      expect(_layers(commands), contains(RainbowRingsPaintLayer.base));
      expect(_layers(commands), contains(RainbowRingsPaintLayer.pole));
      expect(_layers(commands), contains(RainbowRingsPaintLayer.ring));
      expect(
        commands.where(
          (command) => command.layer == RainbowRingsPaintLayer.bokeh,
        ),
        hasLength(14),
      );
      expect(
        _layers(commands),
        containsAll([
          RainbowRingsPaintLayer.selectedGlow,
          RainbowRingsPaintLayer.completedGlow,
        ]),
      );
      expect(
        commands.where((command) => command.ringId == 0).single.ringEffect,
        RainbowRingsRingEffectKind.breathe,
      );
      clock.dispose();
    });

    test(
      'completed glow follows presented timeline markers, not domain truth',
      () {
        final timeline = RainbowRingsTimeline(seed: 15);
        final clock = ValueNotifier(Duration.zero);
        final painter = _painter(
          timeline: timeline,
          clock: clock,
          stacks: const [
            [0, 1, 2, 3],
            [],
            [],
            [],
            [],
          ],
          ringColors: const [0, 0, 0, 0],
        );

        List<int> glowingPegs() => painter
            .debugPaintCommands(const Size(360, 420))
            .where(
              (command) =>
                  command.layer == RainbowRingsPaintLayer.completedGlow,
            )
            .map((command) => command.peg!)
            .toList();

        expect(glowingPegs(), isEmpty);
        timeline.setCompletedPegs(const {0});
        expect(glowingPegs(), [0]);
        timeline.setCompletedPegs(const {});
        expect(glowingPegs(), isEmpty);
        clock.dispose();
      },
    );

    test('paints landing, lower press, pole jiggle, and invalid shake', () {
      final timeline = RainbowRingsTimeline(seed: 16);
      timeline.rememberRings(const [
        RainbowRingsRingPlacement(
          ringId: 0,
          position: RainbowRingsPosition(peg: 0, slot: 0),
        ),
        RainbowRingsRingPlacement(
          ringId: 1,
          position: RainbowRingsPosition(peg: 0, slot: 1),
        ),
        RainbowRingsRingPlacement(
          ringId: 2,
          position: RainbowRingsPosition(peg: 0, slot: 2),
        ),
        RainbowRingsRingPlacement(
          ringId: 3,
          position: RainbowRingsPosition(peg: 0, slot: 3),
        ),
      ]);
      timeline.startLanding(
        at: Duration.zero,
        ring: const RainbowRingsRingPlacement(
          ringId: 3,
          position: RainbowRingsPosition(peg: 0, slot: 3),
        ),
        lowerRingIds: const [0, 1, 2],
      );
      timeline.startAction(
        at: Duration.zero,
        action: const RainbowRingsActionResult(
          kind: RainbowRingsActionKind.invalid,
          source: RainbowRingsPosition.hover(0),
          destination: RainbowRingsPosition(peg: 0, slot: 3),
        ),
      );
      final clock = ValueNotifier(const Duration(milliseconds: 175));
      final commands = _painter(
        timeline: timeline,
        clock: clock,
        stacks: const [
          [0, 1, 2, 3],
          [],
          [],
          [],
          [],
        ],
        ringColors: const [0, 1, 2, 3],
      ).debugPaintCommands(const Size(360, 420));

      expect(
        commands.singleWhere((command) => command.ringId == 3).ringEffect,
        RainbowRingsRingEffectKind.landing,
      );
      final pressedRings = commands
          .where(
            (command) =>
                command.ringEffect == RainbowRingsRingEffectKind.lowerPress,
          )
          .toList();
      expect(pressedRings, hasLength(3));
      expect(pressedRings.every((command) => command.rotation == 0), isTrue);
      final pole = commands.singleWhere(
        (command) =>
            command.layer == RainbowRingsPaintLayer.pole && command.peg == 0,
      );
      expect(
        pole.pegEffects,
        containsAll([
          RainbowRingsPegEffectKind.invalidShake,
          RainbowRingsPegEffectKind.jiggle,
        ]),
      );
      expect(pole.rotation, isNot(0));
      expect(pole.center, pole.bounds!.bottomCenter);
      final geometry = RainbowRingsGeometry.layout(
        const Size(360, 420),
        pegCount: 5,
        capacity: 4,
      );
      expect(
        pole.center!.dx,
        isNot(closeTo(geometry.poleRect(0).center.dx, 0.01)),
      );
      clock.dispose();
    });

    test('paints hint pulses, completed jumps, sparkles, and praise toast', () {
      final timeline = RainbowRingsTimeline(seed: 18);
      timeline.startHint(at: Duration.zero, sourcePeg: 0, destinationPeg: 2);
      timeline.startCompletedPeg(
        at: Duration.zero,
        peg: 1,
        rings: const [
          RainbowRingsRingPlacement(
            ringId: 0,
            position: RainbowRingsPosition(peg: 1, slot: 0),
          ),
          RainbowRingsRingPlacement(
            ringId: 1,
            position: RainbowRingsPosition(peg: 1, slot: 1),
          ),
          RainbowRingsRingPlacement(
            ringId: 2,
            position: RainbowRingsPosition(peg: 1, slot: 2),
          ),
          RainbowRingsRingPlacement(
            ringId: 3,
            position: RainbowRingsPosition(peg: 1, slot: 3),
          ),
        ],
      );
      final clock = ValueNotifier(const Duration(milliseconds: 250));
      final painter = _painter(
        timeline: timeline,
        clock: clock,
        stacks: const [
          [],
          [0, 1, 2, 3],
          [],
          [],
          [],
        ],
        ringColors: const [0, 0, 0, 0],
      );
      final commands = painter.debugPaintCommands(const Size(360, 420));

      expect(
        commands.where(
          (command) => command.layer == RainbowRingsPaintLayer.hintGlow,
        ),
        hasLength(2),
      );
      expect(
        commands.where(
          (command) =>
              command.ringEffect == RainbowRingsRingEffectKind.completedJump,
        ),
        hasLength(4),
      );
      expect(
        commands.where(
          (command) => command.layer == RainbowRingsPaintLayer.sparkle,
        ),
        hasLength(12),
      );
      expect(
        commands.where(
          (command) => command.layer == RainbowRingsPaintLayer.toast,
        ),
        hasLength(1),
      );
      expect(
        commands
            .singleWhere(
              (command) => command.layer == RainbowRingsPaintLayer.toast,
            )
            .text,
        isIn(const ['Sorted!', 'Nice!', 'Great!', 'Wow!']),
      );
      clock.value = const Duration(milliseconds: 125);
      final halfPulse = painter
          .debugPaintCommands(const Size(360, 420))
          .where((command) => command.layer == RainbowRingsPaintLayer.hintGlow);
      expect(halfPulse.every((command) => command.glow == .5), isTrue);
      expect(halfPulse.every((command) => command.blurRadius == 11), isTrue);
      clock.dispose();
    });
  });

  test('confetti paints all 80 pieces in full-screen normalized space', () {
    final timeline = RainbowRingsTimeline(seed: 20);
    timeline.startWin(at: Duration.zero, colorCount: 6);
    final clock = ValueNotifier(const Duration(milliseconds: 600));
    final painter = RainbowRingsConfettiPainter(
      timeline: timeline,
      clock: clock,
    );
    final compact = painter.debugPaintCommands(const Size(360, 640));
    final large = painter.debugPaintCommands(const Size(720, 1280));

    expect(compact, hasLength(80));
    expect(
      compact.every(
        (command) => command.layer == RainbowRingsPaintLayer.confetti,
      ),
      isTrue,
    );
    expect(large, hasLength(80));
    expect(
      compact.first.center!.dx / 360,
      closeTo(large.first.center!.dx / 720, 0.0001),
    );
    expect(
      compact.first.center!.dy / 640,
      closeTo(large.first.center!.dy / 1280, 0.0001),
    );
    clock.dispose();
  });
}

RainbowRingsPainter _painter({
  required RainbowRingsTimeline timeline,
  required ValueNotifier<Duration> clock,
  List<List<int>> stacks = const [
    [0, 1],
    [2],
    [],
    [],
    [],
  ],
  List<int> ringColors = const [0, 1, 2],
  int capacity = 4,
  int? selectedPeg,
  AppColors colors = AppColors.light,
}) => RainbowRingsPainter(
  stacks: stacks,
  ringColors: ringColors,
  capacity: capacity,
  selectedPeg: selectedPeg,
  colors: colors,
  timeline: timeline,
  clock: clock,
);

Set<RainbowRingsPaintLayer> _layers(
  Iterable<RainbowRingsPaintCommand> commands,
) => commands.map((command) => command.layer).toSet();

Offset _overlayCenter(
  RainbowRingsPainter painter,
  int ringId, {
  Size size = const Size(360, 420),
}) => painter
    .debugPaintCommands(size)
    .singleWhere(
      (command) =>
          command.layer == RainbowRingsPaintLayer.overlayRing &&
          command.ringId == ringId,
    )
    .center!;

void _expectMonotonic(List<double> values, {required bool increasing}) {
  for (var index = 1; index < values.length; index++) {
    if (increasing) {
      expect(values[index], greaterThanOrEqualTo(values[index - 1]));
    } else {
      expect(values[index], lessThanOrEqualTo(values[index - 1]));
    }
  }
  expect(values.last, isNot(closeTo(values.first, 0.001)));
}

double _pathProgress({
  required RainbowRingsGeometry geometry,
  required Offset point,
  required int peg,
  required int slot,
}) {
  final resting = geometry.positionFor(
    RainbowRingsPosition(peg: peg, slot: slot),
  );
  final hover = geometry.positionFor(RainbowRingsPosition.hover(peg));
  final path = hover - resting;
  final fromStart = point - resting;
  return (fromStart.dx * path.dx + fromStart.dy * path.dy) /
      (path.dx * path.dx + path.dy * path.dy);
}

void _expectFiniteNonInvertedRect(Rect rect) {
  expect(
    [
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
    ].every((value) => value.isFinite),
    isTrue,
  );
  expect(rect.width, greaterThanOrEqualTo(0));
  expect(rect.height, greaterThanOrEqualTo(0));
}
