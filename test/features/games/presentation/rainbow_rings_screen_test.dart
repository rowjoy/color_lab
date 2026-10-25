import 'dart:async';

import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_level_catalog.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/domain/rainbow_rings_game.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_animation.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_painter.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

const _audioChannel = MethodChannel('com.colorlab/game_audio');
const _boardKey = ValueKey('rainbow-rings-board');
const _undoKey = ValueKey('rainbow-rings-undo');
const _hintKey = ValueKey('rainbow-rings-hint');
const _restartKey = ValueKey('rainbow-rings-restart');
const _progressKey = ValueKey('rainbow-rings-completion-progress');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('star rating keeps literal par and one-and-a-half-par boundaries', () {
    expect(rainbowRingsStarRating(moves: 14, parMoves: 14), 3);
    expect(rainbowRingsStarRating(moves: 15, parMoves: 14), 2);
    expect(rainbowRingsStarRating(moves: 21, parMoves: 14), 2);
    expect(rainbowRingsStarRating(moves: 22, parMoves: 14), 1);
    expect(
      rainbowRingsStarSemanticsLabel(moves: 14, parMoves: 14),
      '3 of 3 stars',
    );
    expect(
      rainbowRingsStarSemanticsLabel(moves: 21, parMoves: 14),
      '2 of 3 stars',
    );
    expect(
      rainbowRingsStarSemanticsLabel(moves: 22, parMoves: 14),
      '1 of 3 stars',
    );
  });

  testWidgets('intro is bottom-first and locks only game-changing controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);

    expect(_frame(tester).inputLocked, isTrue);
    expect(_buttonEnabled<OutlinedButton>(tester, _undoKey), isFalse);
    expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isFalse);
    expect(_buttonEnabled<FilledButton>(tester, _restartKey), isFalse);
    expect(_soundButton(tester).onPressed, isNotNull);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('rainbow-rings-peg-0'))),
      matchesSemantics(
        label: 'Peg 1, 4 rings, top Blue.',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasSelectedState: true,
        isSelected: false,
        textDirection: TextDirection.ltr,
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    final intro = _frame(tester);
    expect(intro.ringTransforms[9]!.opacity, greaterThan(0));
    expect(intro.ringTransforms[1]!.opacity, 0);

    await tester.pump(const Duration(milliseconds: 1184));
    expect(_frame(tester).inputLocked, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_frame(tester).inputLocked, isFalse);
    expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isTrue);
    expect(_buttonEnabled<FilledButton>(tester, _restartKey), isTrue);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('rainbow-rings-peg-0')))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('peg semantics expose state and invoke the real peg action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = await _pumpHarness(tester, reducedMotion: true);
    addTearDown(harness.dispose);

    final pegOne = find.byKey(const ValueKey('rainbow-rings-peg-0'));
    final pegFour = find.byKey(const ValueKey('rainbow-rings-peg-3'));
    final boardSemantics = find.semantics
        .byLabel('Rainbow Rings level 1 board. 5 pegs.')
        .evaluate()
        .single;
    expect(
      boardSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(
      find.semantics.byLabel(RegExp(r'^Peg [1-5],')).evaluate(),
      hasLength(5),
    );
    expect(
      tester.getSemantics(pegOne),
      matchesSemantics(
        label: 'Peg 1, 4 rings, top Blue.',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
        textDirection: TextDirection.ltr,
      ),
    );
    expect(
      tester.getSemantics(pegFour),
      matchesSemantics(
        label: 'Peg 4, empty.',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
        textDirection: TextDirection.ltr,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('Peg 1, 4 rings, top Blue.'));
    await tester.pump();
    expect(
      tester.getSemantics(pegOne).label,
      'Peg 1, 4 rings, top Blue, selected.',
    );

    tester.semantics.tap(find.semantics.byLabel('Peg 4, empty.'));
    await tester.pump();
    expect(_movesText(tester), '1');
    expect(tester.getSemantics(pegFour).label, 'Peg 4, 1 ring, top Blue.');

    await _move(tester, 1, 4);
    await _move(tester, 2, 0);
    final completed = tester.getSemantics(pegOne);
    expect(
      completed,
      matchesSemantics(
        label: 'Peg 1, 4 rings, top Purple, completed.',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasSelectedState: true,
        isSelected: false,
        textDirection: TextDirection.ltr,
      ),
    );
    semantics.dispose();
  });

  testWidgets('focused peg controls activate with Enter and Space', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester, reducedMotion: true);
    addTearDown(harness.dispose);

    TextButton pegButton(int peg) => tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(ValueKey('rainbow-rings-peg-$peg')),
        matching: find.byType(TextButton),
      ),
    );

    BoxDecoration focusDecoration(int peg) =>
        tester
                .widget<Container>(
                  find.byKey(ValueKey('rainbow-rings-peg-focus-$peg')),
                )
                .decoration
            as BoxDecoration;

    expect(focusDecoration(0).border!.top.color.a, 0);
    pegButton(0).focusNode!.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(focusDecoration(0).border!.top.color.a, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_movesText(tester), '0');
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('rainbow-rings-peg-0')))
          .label,
      contains('selected'),
    );

    pegButton(3).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_movesText(tester), '1');
  });

  testWidgets('pointer peg control performs exactly one game action', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester, reducedMotion: true);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const ValueKey('rainbow-rings-peg-0')));
    await tester.pump();
    expect(_movesText(tester), '0');
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('rainbow-rings-peg-0')))
          .label,
      contains('selected'),
    );

    await tester.tap(find.byKey(const ValueKey('rainbow-rings-peg-3')));
    await tester.pump();
    expect(_movesText(tester), '1');
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('rainbow-rings-peg-3')))
          .label,
      'Peg 4, 1 ring, top Blue.',
    );
  });

  testWidgets('invalid, hint, praise, and completion update live regions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = await _pumpHarness(tester, reducedMotion: true);
    addTearDown(harness.dispose);
    const liveKey = ValueKey('rainbow-rings-live-announcement');

    await _tapPeg(tester, 3);
    expect(
      tester.getSemantics(find.byKey(liveKey)),
      matchesSemantics(
        label: 'That move is not allowed.',
        isLiveRegion: true,
        textDirection: TextDirection.ltr,
      ),
    );

    await tester.tap(find.byKey(_hintKey));
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(liveKey)).label,
      'Hint: move from peg 1 to peg 4.',
    );

    await _move(tester, 0, 3);
    await _move(tester, 1, 4);
    await _move(tester, 2, 0);
    expect(
      tester.getSemantics(find.byKey(liveKey)).label,
      'Nice! Peg 1 completed.',
    );

    await _move(tester, 4, 2);
    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('rainbow-rings-completion-announcement')),
      ),
      matchesSemantics(
        label: 'Level complete. 5 moves. Par 14. 10 coins earned.',
        isLiveRegion: true,
        textDirection: TextDirection.ltr,
      ),
    );
    expect(
      find.semantics
          .byLabel('Level complete. 5 moves. Par 14. 10 coins earned.')
          .evaluate(),
      hasLength(1),
    );
    expect(find.semantics.byLabel('3 of 3 stars').evaluate(), hasLength(1));
    semantics.dispose();
  });

  testWidgets('repeated identical feedback replaces the live semantic node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = await _pumpHarness(tester, reducedMotion: true);
    addTearDown(harness.dispose);

    await _tapPeg(tester, 3);
    final firstNode = find.semantics
        .byLabel('That move is not allowed.')
        .evaluate()
        .single;
    await _tapPeg(tester, 3);
    final secondNode = find.semantics
        .byLabel('That move is not allowed.')
        .evaluate()
        .single;

    expect(secondNode.id, isNot(firstNode.id));
    semantics.dispose();
  });

  testWidgets(
    'quick destination retarget mutates once and keeps one overlay while locked',
    (tester) async {
      final harness = await _pumpHarness(tester);
      addTearDown(harness.dispose);
      await _finishIntro(tester);

      await _tapPeg(tester, 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_overlayCommands(tester), hasLength(1));
      expect(
        _overlayCommands(tester).single.ringEffect,
        RainbowRingsRingEffectKind.select,
      );

      await _tapPeg(tester, 3);
      expect(_movesText(tester), '1');
      expect(_overlayCommands(tester), hasLength(1));
      expect(
        _overlayCommands(tester).single.ringEffect,
        RainbowRingsRingEffectKind.move,
      );
      expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isFalse);
      expect(_buttonEnabled<FilledButton>(tester, _restartKey), isFalse);
      expect(_soundButton(tester).onPressed, isNotNull);

      await _tapPeg(tester, 1);
      await _tapPeg(tester, 4);
      await tester.pump(const Duration(milliseconds: 599));
      expect(_movesText(tester), '1');
      expect(_overlayCommands(tester), hasLength(1));

      await tester.pump(const Duration(milliseconds: 1));
      expect(_overlayCommands(tester), isEmpty);
      expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isTrue);
      expect(
        _frame(tester).ringTransforms[4]!.kind,
        RainbowRingsRingEffectKind.landing,
      );

      await _tapPeg(tester, 1);
      expect(
        _frame(
          tester,
        ).ringTransforms.values.where((transform) => transform.overlay),
        hasLength(1),
      );
      expect(
        _frame(tester).ringTransforms.values.any(
          (transform) => transform.kind == RainbowRingsRingEffectKind.landing,
        ),
        isTrue,
      );
    },
  );

  testWidgets('deselect and invalid actions preserve domain and feedback', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    await _tapPeg(tester, 3);
    expect(_movesText(tester), '0');
    expect(feedback.audioEffects, ['invalid']);
    expect(feedback.hapticTypes, ['HapticFeedbackType.lightImpact']);
    expect(
      _frame(tester).pegEffects[3]!.kinds,
      contains(RainbowRingsPegEffectKind.invalidShake),
    );

    feedback.clear();
    await _tapPeg(tester, 0);
    await _tapPeg(tester, 1);
    expect(_movesText(tester), '0');
    expect(_overlayCommands(tester), hasLength(1));
    expect(
      _frame(tester).pegEffects[1]!.kinds,
      contains(RainbowRingsPegEffectKind.invalidShake),
    );
    expect(feedback.audioEffects, ['move', 'invalid']);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
    ]);

    feedback.clear();
    await _tapPeg(tester, 0);
    expect(_overlayCommands(tester), hasLength(1));
    expect(
      _overlayCommands(tester).single.ringEffect,
      RainbowRingsRingEffectKind.deselect,
    );
    expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_overlayCommands(tester), isEmpty);
    expect(_movesText(tester), '0');
    expect(feedback.audioEffects, ['move']);
    expect(feedback.hapticTypes, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('undo animates once and also clears an active selection', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    expect(_buttonEnabled<OutlinedButton>(tester, _undoKey), isFalse);
    await _move(tester, 0, 3);
    await tester.pump(const Duration(milliseconds: 600));
    await _tapPeg(tester, 1);
    feedback.clear();

    await tester.tap(find.byKey(_undoKey));
    await tester.pump();
    expect(_movesText(tester), '0');
    expect(_buttonEnabled<OutlinedButton>(tester, _undoKey), isFalse);
    expect(_overlayCommands(tester), isNotEmpty);
    expect(
      _overlayCommands(tester).where(
        (command) => command.ringEffect == RainbowRingsRingEffectKind.undo,
      ),
      hasLength(1),
    );
    expect(feedback.audioEffects, ['move']);
    expect(feedback.hapticTypes, ['HapticFeedbackType.selectionClick']);

    await tester.pump(const Duration(milliseconds: 799));
    expect(_buttonEnabled<FilledButton>(tester, _restartKey), isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_buttonEnabled<FilledButton>(tester, _restartKey), isTrue);
    expect(_overlayCommands(tester), isEmpty);
  });

  testWidgets('accepted move and undo without selection fire feedback once', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    await _move(tester, 0, 3);
    expect(feedback.audioEffects, ['move', 'move']);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(_buttonEnabled<OutlinedButton>(tester, _undoKey), isTrue);

    feedback.clear();
    await tester.tap(find.byKey(_undoKey));
    await tester.pump();
    expect(feedback.audioEffects, ['move']);
    expect(feedback.hapticTypes, ['HapticFeedbackType.selectionClick']);
    expect(_movesText(tester), '0');
  });

  testWidgets('hint pulses immediately or after dropping a selection', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    await tester.tap(find.byKey(_hintKey));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_hintPegs(tester), {0, 3});
    expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isTrue);

    await _tapPeg(tester, 0);
    await tester.tap(find.byKey(_hintKey));
    await tester.pump();
    expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isFalse);
    expect(_overlayCommands(tester), hasLength(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_overlayCommands(tester), isEmpty);
    expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isTrue);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_hintPegs(tester), {0, 3});
  });

  testWidgets('progress reaches exact ratios without regressing on overlap', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    await _moveAndFinish(tester, 0, 3);
    await _moveAndFinish(tester, 1, 4);
    await _move(tester, 2, 0);
    expect(_progressValue(tester), 0);
    await tester.pump(const Duration(milliseconds: 100));
    final early = _progressValue(tester);
    expect(early, inExclusiveRange(0, 1 / 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_progressValue(tester), closeTo(1 / 3, 0.000001));

    await _move(tester, 4, 2);
    final samples = <double>[_progressValue(tester)];
    for (var step = 0; step < 6; step++) {
      await tester.pump(const Duration(milliseconds: 100));
      samples.add(_progressValue(tester));
    }
    for (var index = 1; index < samples.length; index++) {
      expect(samples[index], greaterThanOrEqualTo(samples[index - 1]));
    }
    expect(samples.last, closeTo(2 / 3, 0.000001));
  });

  testWidgets('a nonfinal completed peg celebrates once after its drop', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    await _moveAndFinish(tester, 0, 3);
    await _moveAndFinish(tester, 1, 4);
    feedback.clear();
    await _move(tester, 2, 0);
    expect(_frame(tester).completedPegs, isNot(contains(0)));
    expect(_completedGlowPegs(tester), isNot(contains(0)));
    expect(feedback.audioEffects, ['move', 'move']);

    await tester.pump(const Duration(milliseconds: 599));
    expect(_frame(tester).completedPegs, isNot(contains(0)));
    await tester.pump(const Duration(milliseconds: 1));
    final completed = _frame(tester);
    expect(completed.completedPegs, contains(0));
    expect(_completedGlowPegs(tester), contains(0));
    expect(completed.sparkles, hasLength(12));
    expect(completed.toast, 'Nice!');
    expect(
      completed.ringTransforms.values.any(
        (transform) =>
            transform.kind == RainbowRingsRingEffectKind.completedJump,
      ),
      isTrue,
    );
    expect(feedback.audioEffects, ['move', 'move', 'pop']);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);

    _frame(tester);
    _overlayCommands(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      feedback.audioEffects.where((effect) => effect == 'pop'),
      hasLength(1),
    );
    expect(
      feedback.hapticTypes.where(
        (type) => type == 'HapticFeedbackType.mediumImpact',
      ),
      hasLength(1),
    );

    feedback.clear();
    await _tapPeg(tester, 4);
    expect(feedback.audioEffects, ['move']);
    expect(feedback.hapticTypes, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('undo clears completed glow and a real recompletion celebrates', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);
    await _moveAndFinish(tester, 0, 3);
    await _moveAndFinish(tester, 1, 4);
    await _moveAndFinish(tester, 2, 0);
    expect(_completedGlowPegs(tester), contains(0));

    await tester.tap(find.byKey(_undoKey));
    await tester.pump();
    expect(_frame(tester).completedPegs, isNot(contains(0)));
    expect(_completedGlowPegs(tester), isNot(contains(0)));
    await tester.pump(const Duration(milliseconds: 800));

    feedback.clear();
    await _moveAndFinish(tester, 2, 0);
    expect(_frame(tester).completedPegs, contains(0));
    expect(_completedGlowPegs(tester), contains(0));
    expect(feedback.audioEffects, ['move', 'move', 'pop']);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  testWidgets(
    'winning celebration waits for both durable receipt and visible drop',
    (tester) async {
      final feedback = _installFeedbackSpies(tester);
      final harness = await _pumpHarness(tester);
      addTearDown(harness.dispose);
      await _finishIntro(tester);
      await _prepareFinalMove(tester);
      feedback.clear();

      final writesBefore = harness.repository.writeAttempts;
      harness.repository.writeGate = Completer<void>();
      await _move(tester, 3, 1);
      expect(harness.repository.writeAttempts, writesBefore + 1);
      expect(_frame(tester).completedPegs, isNot(contains(1)));
      expect(_frame(tester).confetti, isEmpty);

      await tester.pump(const Duration(milliseconds: 600));
      expect(_frame(tester).completedPegs, isNot(contains(1)));
      expect(_frame(tester).confetti, isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_frame(tester).confetti, isEmpty);
      expect(
        find.byKey(const ValueKey('rainbow-rings-win-modal')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('rainbow-rings-confetti')),
        findsNothing,
      );

      harness.repository.writeGate!.complete();
      harness.repository.writeGate = null;
      await _pumpWithoutTimeUntil(
        tester,
        () => _frame(tester).completedPegs.contains(1),
      );
      await tester.pump();
      final celebration = _frame(tester);
      expect(celebration.sparkles, hasLength(12));
      expect(celebration.confetti, hasLength(80));
      expect(
        celebration.confetti.every(
          (particle) =>
              particle.delay >= Duration.zero &&
              particle.delay <= const Duration(milliseconds: 500) &&
              particle.duration >= const Duration(milliseconds: 1600) &&
              particle.duration <= const Duration(milliseconds: 3400),
        ),
        isTrue,
      );
      expect(celebration.modalOpacity, 0);
      expect(celebration.modalScale, .4);
      expect(
        find.byKey(const ValueKey('rainbow-rings-win-modal')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('rainbow-rings-confetti')),
        findsOneWidget,
      );
      final confettiRect = tester.getRect(
        find.byKey(const ValueKey('rainbow-rings-confetti')),
      );
      expect(confettiRect.topLeft, Offset.zero);
      expect(
        confettiRect.size,
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );
      expect(feedback.audioEffects, ['move', 'move', 'pop']);
      expect(feedback.hapticTypes, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.mediumImpact',
      ]);

      await tester.pump(const Duration(milliseconds: 799));
      expect(_frame(tester).modalOpacity, 0);
      expect(_frame(tester).starProgress, [0, 0, 0]);
      expect(
        find.byKey(const ValueKey('rainbow-rings-win-modal')),
        findsNothing,
      );
      expect(feedback.audioEffects, ['move', 'move', 'pop']);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(_frame(tester).modalOpacity, 0);
      expect(_frame(tester).modalScale, .4);
      expect(feedback.audioEffects, ['move', 'move', 'pop', 'win']);
      expect(
        find.byKey(const ValueKey('rainbow-rings-win-modal')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rainbow-rings-confetti')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('rainbow-rings-win-modal-interaction')),
            )
            .ignoring,
        isTrue,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Next Level'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('5 moves • Par 14'), findsOneWidget);
      expect(find.text('+10 coins'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_frame(tester).modalOpacity, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 298));
      expect(_frame(tester).starProgress, [0, 0, 0]);
      await tester.pump(const Duration(milliseconds: 2));
      expect(_frame(tester).starProgress[0], greaterThan(0));
      expect(_frame(tester).starProgress[1], 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_frame(tester).modalOpacity, 1);
      expect(_frame(tester).modalScale, closeTo(1, .000001));
      expect(_frame(tester).starProgress[1], greaterThan(0));
      expect(_frame(tester).starProgress[2], 0);
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('rainbow-rings-win-modal-interaction')),
            )
            .ignoring,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Next Level'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(_frame(tester).starProgress[2], greaterThan(0));
    },
  );

  testWidgets('an early durable receipt still waits through the 600ms drop', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);
    await _prepareFinalMove(tester);
    feedback.clear();

    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () =>
          harness
              .repository
              .durableState
              .activeProfile!
              .gameProgress[GameId.rainbowRings]!
              .currentLevel ==
          2,
    );
    expect(_frame(tester).completedPegs, isNot(contains(1)));
    expect(_frame(tester).confetti, isEmpty);
    expect(feedback.audioEffects, ['move', 'move']);

    await tester.pump(const Duration(milliseconds: 599));
    expect(_frame(tester).completedPegs, isNot(contains(1)));
    expect(_frame(tester).confetti, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_frame(tester).completedPegs, contains(1));
    expect(_frame(tester).confetti, hasLength(80));
    expect(feedback.audioEffects, ['move', 'move', 'pop']);
    expect(feedback.hapticTypes.last, 'HapticFeedbackType.mediumImpact');

    await tester.pump(const Duration(milliseconds: 799));
    expect(feedback.audioEffects, ['move', 'move', 'pop']);
    expect(find.byKey(const ValueKey('rainbow-rings-win-modal')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(feedback.audioEffects, ['move', 'move', 'pop', 'win']);
    expect(
      find.byKey(const ValueKey('rainbow-rings-win-modal')),
      findsOneWidget,
    );
  });

  testWidgets('enabling reduced motion during C-to-M still opens the modal', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);
    await _prepareFinalMove(tester);
    feedback.clear();

    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () =>
          harness
              .repository
              .durableState
              .activeProfile!
              .gameProgress[GameId.rainbowRings]!
              .currentLevel ==
          2,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(_frame(tester).confetti, hasLength(80));
    expect(find.byKey(const ValueKey('rainbow-rings-win-modal')), findsNothing);

    await harness.repump(
      tester,
      launch: harness.fixture.launch,
      reducedMotion: true,
    );
    await _pumpWithoutTimeUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );

    expect(_frame(tester).modalOpacity, 1);
    expect(_frame(tester).confetti, isEmpty);
    expect(find.byKey(const ValueKey('rainbow-rings-confetti')), findsNothing);
    expect(feedback.audioEffects, ['move', 'move', 'pop', 'win']);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  testWidgets('enabling reduced motion during selected hint preserves hint', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    await _tapPeg(tester, 0);
    await tester.tap(find.byKey(_hintKey));
    await tester.pump();
    expect(_frame(tester).inputLocked, isTrue);

    await harness.repump(
      tester,
      launch: harness.fixture.launch,
      reducedMotion: true,
    );
    await tester.pump();

    expect(_frame(tester).inputLocked, isFalse);
    expect(_overlayCommands(tester), isEmpty);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('rainbow-rings-live-announcement')),
          )
          .label,
      'Hint: move from peg 1 to peg 4.',
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_movesText(tester), '0');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('profile switch during C-to-M cancels stale celebration', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);
    await _prepareFinalMove(tester);
    feedback.clear();

    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () =>
          harness
              .repository
              .durableState
              .activeProfile!
              .gameProgress[GameId.rainbowRings]!
              .currentLevel ==
          2,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.byKey(const ValueKey('rainbow-rings-confetti')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 400));

    final guest = await harness.container
        .read(gameProfilesProvider.notifier)
        .createProfile(name: 'Guest');
    await tester.pump();
    expect(harness.repository.durableState.activeProfileId, guest.id);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('This attempt is no longer active.'), findsOneWidget);
    expect(find.byKey(const ValueKey('rainbow-rings-win-modal')), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(find.byKey(const ValueKey('rainbow-rings-confetti')), findsNothing);
    expect(feedback.audioEffects, ['move', 'move', 'pop']);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  testWidgets('replacement before dialog build cannot surface a stale modal', (
    tester,
  ) async {
    late _Harness harness;
    var routePushes = 0;
    final observer = _DialogPushObserver(() {
      routePushes++;
      harness.replaceLaunchSynchronously(
        harness.fixture.launchForAttempt('replacement'),
      );
    });
    harness = await _pumpHarness(tester, navigatorObserver: observer);
    addTearDown(harness.dispose);
    await _finishIntro(tester);
    await _prepareFinalMove(tester);

    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () =>
          harness
              .repository
              .durableState
              .activeProfile!
              .gameProgress[GameId.rainbowRings]!
              .currentLevel ==
          2,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await tester.pump();

    expect(routePushes, 1);
    expect(find.byKey(const ValueKey('rainbow-rings-win-modal')), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(_movesText(tester), '0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile switch at dialog push cannot surface a stale modal', (
    tester,
  ) async {
    late _Harness harness;
    late PlayerProfile guest;
    Future<PlayerProfile>? profileSwitch;
    final observer = _DialogPushObserver(() {
      profileSwitch = harness.container
          .read(gameProfilesProvider.notifier)
          .setActiveProfile(profileId: guest.id);
    });
    harness = await _pumpHarness(tester, navigatorObserver: observer);
    addTearDown(harness.dispose);
    guest = await harness.container
        .read(gameProfilesProvider.notifier)
        .createProfile(name: 'Guest');
    await harness.container
        .read(gameProfilesProvider.notifier)
        .setActiveProfile(profileId: harness.fixture.launch.profileId);
    await tester.pump();
    await _finishIntro(tester);
    await _prepareFinalMove(tester);

    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () =>
          harness
              .repository
              .durableState
              .profiles[harness.fixture.launch.profileId]!
              .gameProgress[GameId.rainbowRings]!
              .currentLevel ==
          2,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 800));
    expect(profileSwitch, isNotNull);
    await profileSwitch;
    await tester.pump();
    await tester.pump();

    expect(harness.repository.durableState.activeProfileId, guest.id);
    expect(find.byKey(const ValueKey('rainbow-rings-win-modal')), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(find.text('This attempt is no longer active.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save never starts the final reward celebration', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester, reducedMotion: true);
    addTearDown(harness.dispose);

    await _move(tester, 0, 3);
    await _move(tester, 1, 4);
    await _move(tester, 2, 0);
    await _move(tester, 4, 2);
    feedback.clear();
    harness.repository.failWrite = true;
    await _move(tester, 3, 1);
    await _pumpUntil(
      tester,
      () => find.text('Retry save').evaluate().isNotEmpty,
    );

    final frame = _frame(tester);
    expect(frame.completedPegs, isNot(contains(1)));
    expect(frame.confetti, isEmpty);
    expect(frame.modalOpacity, 0);
    expect(find.byKey(const ValueKey('rainbow-rings-win-modal')), findsNothing);
    expect(
      harness
          .repository
          .durableState
          .activeProfile!
          .gameProgress[GameId.rainbowRings]!
          .currentLevel,
      1,
    );
    expect(harness.repository.durableState.activeProfile!.coins, 0);
    expect(feedback.audioEffects, ['move', 'move']);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
  });

  testWidgets('reduced-motion win mutes stack and modal sounds, not haptics', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester, reducedMotion: true);
    addTearDown(harness.dispose);
    await tester.tap(find.byTooltip('Mute game sounds'));
    await tester.pump();

    await _move(tester, 0, 3);
    await _move(tester, 1, 4);
    await _move(tester, 2, 0);
    await _move(tester, 4, 2);
    feedback.clear();
    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );

    expect(feedback.audioEffects, isEmpty);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);
    expect(_frame(tester).confetti, isEmpty);
    expect(_frame(tester).modalOpacity, 1);
    expect(
      find.byKey(const ValueKey('rainbow-rings-win-modal')),
      findsOneWidget,
    );
  });

  testWidgets('an already-applied win acknowledges without reward feedback', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(
      tester,
      reducedMotion: true,
      alreadyCompleted: true,
    );
    addTearDown(harness.dispose);
    final writesBefore = harness.repository.writeAttempts;

    await _move(tester, 0, 3);
    await _move(tester, 1, 4);
    await _move(tester, 2, 0);
    await _move(tester, 4, 2);
    feedback.clear();
    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () => find.text('Level already saved').evaluate().isNotEmpty,
    );

    expect(harness.repository.writeAttempts, writesBefore);
    expect(feedback.audioEffects, ['move', 'move']);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
    expect(find.byKey(const ValueKey('rainbow-rings-confetti')), findsNothing);
    expect(_frame(tester).confetti, isEmpty);
  });

  testWidgets('a replacement launch dismisses an active win modal', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester, reducedMotion: true);
    addTearDown(harness.dispose);

    await _move(tester, 0, 3);
    await _move(tester, 1, 4);
    await _move(tester, 2, 0);
    await _move(tester, 4, 2);
    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );

    final replacement = harness.fixture.launchForAttempt('replacement');
    await harness.repump(tester, launch: replacement, reducedMotion: true);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('rainbow-rings-win-modal')), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(_movesText(tester), '0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion is immediate and mute gates only audio', (
    tester,
  ) async {
    final feedback = _installFeedbackSpies(tester);
    final harness = await _pumpHarness(tester, reducedMotion: true);
    addTearDown(harness.dispose);

    expect(_frame(tester).inputLocked, isFalse);
    expect(_frame(tester).bokeh, isEmpty);
    await tester.tap(find.byTooltip('Mute game sounds'));
    await tester.pump();
    await _tapPeg(tester, 3);
    expect(feedback.audioEffects, isEmpty);
    expect(feedback.hapticTypes, ['HapticFeedbackType.lightImpact']);

    await _move(tester, 0, 3);
    await _move(tester, 1, 4);
    await _move(tester, 2, 0);
    expect(_movesText(tester), '3');
    expect(_progressValue(tester), closeTo(1 / 3, 0.000001));
    expect(_overlayCommands(tester), isEmpty);
    expect(feedback.audioEffects, isEmpty);
    expect(feedback.hapticTypes, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);
    final stoppedClock = _painter(tester).clock.value;
    await tester.pump(const Duration(seconds: 2));
    expect(_painter(tester).clock.value, stoppedClock);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('background pauses travel and resumes its remaining duration', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await _finishIntro(tester);

    await _move(tester, 0, 3);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_frame(tester).inputLocked, isTrue);
    final pausedAt = _painter(tester).clock.value;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(_painter(tester).clock.value, pausedAt);
    expect(_frame(tester).inputLocked, isTrue);
    expect(_overlayCommands(tester), hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 399));
    expect(_frame(tester).inputLocked, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_frame(tester).inputLocked, isFalse);
    expect(_overlayCommands(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restart and a replacement launch invalidate stale callbacks', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    await _tapPeg(tester, 0);
    await tester.tap(find.byKey(_restartKey));
    await _pumpUntil(
      tester,
      () =>
          harness
              .repository
              .durableState
              .activeProfile!
              .gameProgress[GameId.rainbowRings]!
              .attempts >
          1,
    );
    expect(_movesText(tester), '0');
    expect(_frame(tester).inputLocked, isTrue);

    await tester.pump(const Duration(milliseconds: 1305));
    await _move(tester, 0, 3);
    final replacement = harness.fixture.launchForAttempt('replacement');
    await harness.repump(tester, launch: replacement);
    expect(_movesText(tester), '0');
    await tester.pump(const Duration(milliseconds: 900));
    expect(_movesText(tester), '0');
    expect(_frame(tester).inputLocked, isTrue);
    expect(_buttonEnabled<OutlinedButton>(tester, _undoKey), isFalse);
    expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isFalse);
    expect(_buttonEnabled<FilledButton>(tester, _restartKey), isFalse);
    expect(
      tester.widget<GestureDetector>(find.byKey(_boardKey)).onTapUp,
      isNull,
    );
    await _tapPeg(tester, 0);
    expect(_movesText(tester), '0');
    expect(_overlayCommands(tester), isEmpty);

    await tester.pump(const Duration(milliseconds: 404));
    expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_frame(tester).inputLocked, isFalse);
    expect(_buttonEnabled<OutlinedButton>(tester, _undoKey), isFalse);
    expect(_buttonEnabled<OutlinedButton>(tester, _hintKey), isTrue);
    expect(_buttonEnabled<FilledButton>(tester, _restartKey), isTrue);
    expect(
      tester.widget<GestureDetector>(find.byKey(_boardKey)).onTapUp,
      isNotNull,
    );
    await _move(tester, 0, 3);
    expect(_movesText(tester), '1');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('restart clears unlocked landing and hint phases', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    await _moveAndFinish(tester, 0, 3);
    expect(
      _frame(tester).ringTransforms.values.any(
        (transform) => transform.kind == RainbowRingsRingEffectKind.landing,
      ),
      isTrue,
    );
    await tester.tap(find.byKey(_restartKey));
    await _pumpUntil(
      tester,
      () =>
          harness
              .repository
              .durableState
              .activeProfile!
              .gameProgress[GameId.rainbowRings]!
              .attempts >
          1,
    );
    expect(
      _frame(tester).ringTransforms.values.any(
        (transform) => transform.kind == RainbowRingsRingEffectKind.landing,
      ),
      isFalse,
    );

    await _finishIntro(tester);
    await tester.tap(find.byKey(_hintKey));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_hintPegs(tester), {0, 3});
    await tester.tap(find.byKey(_restartKey));
    await _pumpUntil(
      tester,
      () =>
          harness
              .repository
              .durableState
              .activeProfile!
              .gameProgress[GameId.rainbowRings]!
              .attempts >
          2,
    );
    expect(_hintPegs(tester), isEmpty);
    expect(_frame(tester).inputLocked, isTrue);
  });

  testWidgets('resize during travel reprojects the active ring safely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _finishIntro(tester);

    await _move(tester, 0, 3);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_overlayCommands(tester), hasLength(1));

    tester.view.physicalSize = const Size(360, 800);
    await tester.pump();
    final boardSize = tester.getSize(find.byKey(_boardKey));
    final overlay = _overlayCommands(tester).single;
    expect(overlay.bounds, isNotNull);
    expect(overlay.bounds!.left, greaterThanOrEqualTo(0));
    expect(overlay.bounds!.top, greaterThanOrEqualTo(0));
    expect(overlay.bounds!.right, lessThanOrEqualTo(boardSize.width));
    expect(overlay.bounds!.bottom, lessThanOrEqualTo(boardSize.height));

    await tester.pump(const Duration(milliseconds: 350));
    expect(_frame(tester).inputLocked, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final themeCase in [
    (name: 'light', theme: AppTheme.light),
    (name: 'dark', theme: AppTheme.dark),
  ]) {
    testWidgets(
      '360dp portrait at 2x uses ${themeCase.name} theme and safe insets',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const safePadding = EdgeInsets.fromLTRB(12, 24, 8, 34);
        final harness = await _pumpHarness(
          tester,
          reducedMotion: true,
          textScaler: const TextScaler.linear(2),
          theme: themeCase.theme,
          safePadding: safePadding,
        );
        addTearDown(harness.dispose);

        final board = find.byKey(_boardKey);
        final boardRect = tester.getRect(board);
        expect(
          Theme.of(tester.element(board)).brightness,
          themeCase.theme.brightness,
        );
        expect(boardRect.left, greaterThanOrEqualTo(safePadding.left));
        expect(boardRect.right, lessThanOrEqualTo(360 - safePadding.right));
        expect(boardRect.bottom, lessThanOrEqualTo(800 - safePadding.bottom));

        await _move(tester, 0, 3);
        await _move(tester, 1, 4);
        await _move(tester, 2, 0);
        await _move(tester, 4, 2);
        await _move(tester, 3, 1);
        await _pumpWithoutTimeUntil(
          tester,
          () => find.text('Next Level').evaluate().isNotEmpty,
        );
        final modalRect = tester.getRect(
          find.byKey(const ValueKey('rainbow-rings-win-modal')),
        );
        expect(modalRect.left, greaterThanOrEqualTo(safePadding.left));
        expect(modalRect.right, lessThanOrEqualTo(360 - safePadding.right));
        expect(modalRect.top, greaterThanOrEqualTo(safePadding.top));
        expect(modalRect.bottom, lessThanOrEqualTo(800 - safePadding.bottom));
        expect(find.semantics.byLabel('3 of 3 stars').evaluate(), hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('640x360 landscape at 2x keeps board and modal laid out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await _pumpHarness(
      tester,
      reducedMotion: true,
      textScaler: const TextScaler.linear(2),
    );
    addTearDown(harness.dispose);

    expect(find.byKey(_boardKey), findsOneWidget);
    expect(find.byKey(_hintKey), findsOneWidget);
    await _move(tester, 0, 3);
    await _move(tester, 1, 4);
    await _move(tester, 2, 0);
    await _move(tester, 4, 2);
    await _move(tester, 3, 1);
    await _pumpWithoutTimeUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    expect(
      find.byKey(const ValueKey('rainbow-rings-win-modal')),
      findsOneWidget,
    );
    expect(find.text('Next Level'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _FeedbackSpy {
  final List<String> audioEffects = [];
  final List<String> hapticTypes = [];

  void clear() {
    audioEffects.clear();
    hapticTypes.clear();
  }
}

_FeedbackSpy _installFeedbackSpies(WidgetTester tester) {
  final spy = _FeedbackSpy();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_audioChannel, (call) async {
    if (call.method == 'play') {
      spy.audioEffects.add((call.arguments as Map)['effect'] as String);
    }
    return null;
  });
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      spy.hapticTypes.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(() async {
    messenger.setMockMethodCallHandler(_audioChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return spy;
}

final class _Fixture {
  const _Fixture({required this.state, required this.launch});

  final GameProfilesState state;
  final GameLaunch launch;

  GameLaunch launchForAttempt(String attemptId) => GameLaunch(
    profileId: launch.profileId,
    gameId: launch.gameId,
    descriptor: launch.descriptor,
    attemptId: attemptId,
    playKind: launch.playKind,
  );
}

_Fixture _fixture({bool alreadyCompleted = false}) {
  final descriptor = GameLevelDescriptor(
    gameId: GameId.rainbowRings,
    level: 1,
    seed: 0xabc001,
    generatorVersion: 1,
    retrySalt: 0,
    fingerprint: '1'.padLeft(64, '0'),
    tier: GameTier.easy,
    levelPressure: 0,
  );
  final attempt = ActiveGameAttempt(
    attemptId: 'profile-1:rainbowRings:1',
    sequence: 1,
    level: 1,
    playKind: GamePlayKind.current,
    descriptorFingerprint: descriptor.fingerprint,
    startedAt: DateTime.utc(2026, 10, 24, 9),
  );
  final progress = PlayerGameProgress(
    gameId: GameId.rainbowRings,
    currentLevel: 1,
    generatedThrough: 1,
    descriptors: {1: descriptor},
    fingerprints: {descriptor.fingerprint},
    clearedLevels: const {},
    bestScores: const {},
    attempts: 1,
    wins: 0,
    attemptSequence: 1,
    activeAttempt: attempt,
    highestCompletedLevel: 0,
  );
  final profile = PlayerProfile(
    id: 'profile-1',
    name: 'Player',
    createdAt: DateTime.utc(2026, 10, 24, 8),
    updatedAt: DateTime.utc(2026, 10, 24, 9),
    gamesPlayed: 1,
    gamesWon: 0,
    bestScore: 0,
    gameProgress: {GameId.rainbowRings: progress},
  );
  var state = GameProfilesState(
    activeProfileId: profile.id,
    profiles: {profile.id: profile},
    legacyMigrationComplete: true,
  );
  final launch = GameLaunch(
    profileId: profile.id,
    gameId: GameId.rainbowRings,
    descriptor: descriptor,
    attemptId: attempt.attemptId,
    playKind: GamePlayKind.current,
  );
  if (alreadyCompleted) {
    state =
        GameProgressionEngine(
              catalog: GameLevelCatalog(
                registry: _Registry(_FixedRainbowAdapter()),
              ),
            )
            .completeLevel(
              state: state,
              launch: launch,
              normalizedScore: 100,
              completedAt: DateTime.utc(2026, 10, 24, 10),
            )
            .state;
  }
  return _Fixture(state: state, launch: launch);
}

final class _Harness {
  _Harness({
    required this.container,
    required this.repository,
    required this.fixture,
    required this.adapter,
    required this.mediaQueryData,
    required this.theme,
    required this.navigatorObserver,
    required this.launchHostKey,
  });

  final ProviderContainer container;
  final InMemoryGameProfilesRepository repository;
  final _Fixture fixture;
  final _FixedRainbowAdapter adapter;
  final MediaQueryData mediaQueryData;
  final ThemeData theme;
  final NavigatorObserver? navigatorObserver;
  final GlobalKey<_LaunchHostState>? launchHostKey;

  void replaceLaunchSynchronously(GameLaunch launch) {
    final state = launchHostKey?.currentState;
    if (state == null) throw StateError('No launch host is mounted.');
    state.replace(launch);
  }

  Future<void> repump(
    WidgetTester tester, {
    required GameLaunch launch,
    bool? reducedMotion,
  }) => tester.pumpWidget(_app(launch, reducedMotion: reducedMotion));

  Widget _app(GameLaunch launch, {bool? reducedMotion}) {
    final mediaQuery = mediaQueryData.copyWith(
      disableAnimations: reducedMotion,
    );
    final hostKey = launchHostKey;
    final home = hostKey == null
        ? MediaQuery(
            data: mediaQuery,
            child: RainbowRingsScreen(launch: launch),
          )
        : _LaunchHost(
            key: hostKey,
            initialLaunch: launch,
            mediaQueryData: mediaQuery,
          );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        navigatorObservers: [?navigatorObserver],
        builder: (context, child) =>
            MediaQuery(data: mediaQuery, child: child!),
        home: home,
      ),
    );
  }

  void dispose() => container.dispose();
}

Future<_Harness> _pumpHarness(
  WidgetTester tester, {
  bool reducedMotion = false,
  TextScaler textScaler = TextScaler.noScaling,
  ThemeData? theme,
  EdgeInsets safePadding = EdgeInsets.zero,
  bool alreadyCompleted = false,
  NavigatorObserver? navigatorObserver,
}) async {
  final fixture = _fixture(alreadyCompleted: alreadyCompleted);
  final repository = InMemoryGameProfilesRepository(
    initialState: fixture.state,
  );
  final adapter = _FixedRainbowAdapter();
  var tick = 0;
  final container = ProviderContainer(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      gameAdapterRegistryProvider.overrideWithValue(_Registry(adapter)),
      gameProfilesClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 24, 11).add(Duration(seconds: tick++)),
      ),
    ],
  );
  await container.read(gameProfilesProvider.future);
  final harness = _Harness(
    container: container,
    repository: repository,
    fixture: fixture,
    adapter: adapter,
    mediaQueryData: MediaQueryData.fromView(tester.view).copyWith(
      disableAnimations: reducedMotion,
      textScaler: textScaler,
      padding: safePadding,
      viewPadding: safePadding,
    ),
    theme: theme ?? AppTheme.light,
    navigatorObserver: navigatorObserver,
    launchHostKey: navigatorObserver == null
        ? null
        : GlobalKey<_LaunchHostState>(),
  );
  await tester.pumpWidget(harness._app(fixture.launch));
  await tester.pump();
  return harness;
}

final class _DialogPushObserver extends NavigatorObserver {
  _DialogPushObserver(this.onDialogPush);

  final VoidCallback onDialogPush;
  bool _handled = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_handled || route is! RawDialogRoute<dynamic>) return;
    _handled = true;
    onDialogPush();
  }
}

class _LaunchHost extends StatefulWidget {
  const _LaunchHost({
    super.key,
    required this.initialLaunch,
    required this.mediaQueryData,
  });

  final GameLaunch initialLaunch;
  final MediaQueryData mediaQueryData;

  @override
  State<_LaunchHost> createState() => _LaunchHostState();
}

class _LaunchHostState extends State<_LaunchHost> {
  late GameLaunch _launch = widget.initialLaunch;

  void replace(GameLaunch launch) => setState(() => _launch = launch);

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: widget.mediaQueryData,
    child: RainbowRingsScreen(launch: _launch),
  );
}

final class _Registry implements GameLevelAdapterRegistry {
  const _Registry(this.adapter);

  final _FixedRainbowAdapter adapter;

  @override
  GameLevelAdapter adapterFor(GameId gameId) {
    if (gameId != GameId.rainbowRings) throw StateError('$gameId');
    return adapter;
  }
}

final class _FixedRainbowAdapter implements GameLevelAdapter {
  @override
  GameId get gameId => GameId.rainbowRings;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  RainbowRingsLevelLayout build(GameLevelDescriptor descriptor) =>
      RainbowRingsLevelLayout(
        level: descriptor.level,
        colorCount: 3,
        capacity: 4,
        scrambleDepth: 5,
        ringColors: const [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2],
        stacks: const [
          [0, 1, 2, 4],
          [5, 6, 7, 8],
          [9, 10, 11, 3],
          [],
          [],
        ],
        inverseSolution: const [
          RainbowRingsMove(
            ringId: 4,
            sourcePeg: 0,
            sourceSlot: 3,
            destinationPeg: 3,
            destinationSlot: 0,
          ),
          RainbowRingsMove(
            ringId: 8,
            sourcePeg: 1,
            sourceSlot: 3,
            destinationPeg: 4,
            destinationSlot: 0,
          ),
          RainbowRingsMove(
            ringId: 3,
            sourcePeg: 2,
            sourceSlot: 3,
            destinationPeg: 0,
            destinationSlot: 3,
          ),
          RainbowRingsMove(
            ringId: 8,
            sourcePeg: 4,
            sourceSlot: 0,
            destinationPeg: 2,
            destinationSlot: 3,
          ),
          RainbowRingsMove(
            ringId: 4,
            sourcePeg: 3,
            sourceSlot: 0,
            destinationPeg: 1,
            destinationSlot: 3,
          ),
        ],
        parMoves: 14,
        candidateAttempts: 1,
      );

  @override
  int normalizeScore(GameLevelOutcome outcome) => 80;
}

Future<void> _finishIntro(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 1305));

Future<void> _tapPeg(WidgetTester tester, int peg) async {
  final board = find.byKey(_boardKey);
  final rect = tester.getRect(board);
  await tester.tapAt(
    Offset(rect.left + rect.width * (peg + .5) / 5, rect.center.dy),
  );
  await tester.pump();
}

Future<void> _move(WidgetTester tester, int source, int destination) async {
  await _tapPeg(tester, source);
  await _tapPeg(tester, destination);
}

Future<void> _moveAndFinish(
  WidgetTester tester,
  int source,
  int destination,
) async {
  await _move(tester, source, destination);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _prepareFinalMove(WidgetTester tester) async {
  await _moveAndFinish(tester, 0, 3);
  await _moveAndFinish(tester, 1, 4);
  await _moveAndFinish(tester, 2, 0);
  await tester.pump(const Duration(milliseconds: 1000));
  await _moveAndFinish(tester, 4, 2);
  await tester.pump(const Duration(milliseconds: 1000));
}

RainbowRingsPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byKey(const ValueKey('rainbow-rings-repaint-boundary')),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as RainbowRingsPainter;
}

RainbowRingsFrame _frame(WidgetTester tester) {
  final painter = _painter(tester);
  return painter.timeline.sample(painter.clock.value);
}

List<RainbowRingsPaintCommand> _overlayCommands(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byKey(const ValueKey('rainbow-rings-repaint-boundary')),
    matching: find.byType(CustomPaint),
  );
  return _painter(tester)
      .debugPaintCommands(tester.getSize(finder))
      .where((command) => command.layer == RainbowRingsPaintLayer.overlayRing)
      .toList();
}

Set<int> _completedGlowPegs(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byKey(const ValueKey('rainbow-rings-repaint-boundary')),
    matching: find.byType(CustomPaint),
  );
  return _painter(tester)
      .debugPaintCommands(tester.getSize(finder))
      .where((command) => command.layer == RainbowRingsPaintLayer.completedGlow)
      .map((command) => command.peg!)
      .toSet();
}

Set<int> _hintPegs(WidgetTester tester) => _frame(tester).pegEffects.entries
    .where(
      (entry) => entry.value.kinds.contains(RainbowRingsPegEffectKind.hint),
    )
    .map((entry) => entry.key)
    .toSet();

bool _buttonEnabled<T extends ButtonStyleButton>(
  WidgetTester tester,
  ValueKey<String> key,
) => tester.widget<T>(find.byKey(key)).onPressed != null;

IconButton _soundButton(WidgetTester tester) => tester.widget<IconButton>(
  find
      .ancestor(
        of: find.byTooltip('Mute game sounds'),
        matching: find.byType(IconButton),
      )
      .first,
);

String _movesText(WidgetTester tester) {
  final text = tester.widget<Text>(
    find
        .descendant(
          of: find.byKey(const ValueKey('rainbow-rings-moves')),
          matching: find.byType(Text),
        )
        .last,
  );
  return text.data!;
}

double _progressValue(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byKey(_progressKey)).value!;

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

Future<void> _pumpWithoutTimeUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.pump();
  }
  expect(condition(), isTrue);
}
